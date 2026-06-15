-- ============================================================================
-- spawner.lua — 적 스폰, 이동 AI, 피격 충돌 감지 및 처리 모듈
-- ============================================================================

local Collision = require("combat.collision")
local BossUpdate = require("enemy.boss_update")
local BossDraw = require("enemy.boss_draw")

local Enemy = {}

-- 적에게 피해를 입히고 체력이 0 이하가 되면 처치 및 경험치 구슬 생성 처리
function Enemy.damage(game, index, damage)
    local enemy = game.enemies[index]
    if not enemy then return false end

    if enemy.invulnerable then
        return false
    end

    if enemy.type == "boss" and enemy.bossState == "exhausted" then
        damage = damage * 2
    elseif enemy.type == "boss" and enemy.bossState == "recharging" then
        damage = damage * 1.5
    end

    enemy.health = enemy.health - damage
    if enemy.health <= 0 then
        -- 적 처치 효과음 재생
        local Sound = require("game.sound")
        Sound.play("explosion")

        game.score = game.score + (enemy.points or 10)
        local Exp = require("progression.exp")
        Exp.spawn(game, enemy.x + enemy.width / 2, enemy.y + enemy.height / 2)
        table.remove(game.enemies, index)
        return true
    end
    return false
end

-- 단일 보스 생성 헬퍼 함수
function Enemy.createSingleBoss(game, bossStageNum, angle, waveMultiplier)
    local player = game.player
    if not player then return nil end

    local bossName = "Void Overlord"
    local bossColor = { 0.6, 0.1, 0.9 }
    local bossSize = 64
    local bossSpeed = 60
    local baseHealth = 60000
    local pointsVal = 500

    if bossStageNum == 2 then
        bossName = "Infernus Leviathan"
        bossColor = { 1.0, 0.2, 0.1 }
        bossSize = 80
        bossSpeed = 70
        baseHealth = 100000
        pointsVal = 1000
    elseif bossStageNum == 3 then
        bossName = "Phantom Stalker"
        bossColor = { 0.25, 0.95, 0.75 }
        bossSize = 60
        bossSpeed = 110
        baseHealth = 120000
        pointsVal = 2000
    elseif bossStageNum == 4 then
        bossName = "Tesla Archon"
        bossColor = { 0.5, 0.4, 1.0 }
        bossSize = 70
        bossSpeed = 55
        baseHealth = 160000
        pointsVal = 3000
    elseif bossStageNum == 5 then
        bossName = "Orbital Aegis"
        bossColor = { 1.0, 0.8, 0.1 }
        bossSize = 80
        bossSpeed = 40
        baseHealth = 220000
        pointsVal = 4000
    elseif bossStageNum == 6 then
        bossName = "Chronos Weaver"
        bossColor = { 0.1, 0.9, 0.6 }
        bossSize = 75
        bossSpeed = 50
        baseHealth = 300000
        pointsVal = 5000
    elseif bossStageNum == 7 then
        bossName = "Glitch Overlord"
        bossColor = { 1.0, 0.0, 0.4 }
        bossSize = 70
        bossSpeed = 65
        baseHealth = 400000
        pointsVal = 8000
    elseif bossStageNum == 8 then
        bossName = "Singularity Nexus"
        bossColor = { 0.5, 0.1, 0.95 }
        bossSize = 72
        bossSpeed = 60
        baseHealth = 520000
        pointsVal = 10000
    elseif bossStageNum >= 9 then
        bossName = "Nebula Seraph"
        bossColor = { 1.0, 0.85, 0.15 }
        bossSize = 75
        bossSpeed = 70
        baseHealth = 650000
        pointsVal = 15000
    end

    local spawnDist = 450
    local ex = player.x + player.width / 2 + math.cos(angle) * spawnDist - bossSize / 2
    local ey = player.y + player.height / 2 + math.sin(angle) * spawnDist - bossSize / 2

    ex = math.max(100, math.min(game.world.width - 200, ex))
    ey = math.max(100, math.min(game.world.height - 200, ey))

    local bBurstTimer = 5.0
    local bPetalTimer = nil
    local bRushTimer = 8.0
    local patternTimer = nil
    local nextPattern = nil

    if bossStageNum == 2 then
        bPetalTimer = 6.0
        bRushTimer = 9.0
    elseif bossStageNum == 3 then
        bBurstTimer = nil
        bRushTimer = nil
        patternTimer = 3.5
        nextPattern = "dash"
    elseif bossStageNum == 4 then
        bBurstTimer = nil
        bRushTimer = nil
        patternTimer = 4.0
        nextPattern = "pylons"
    elseif bossStageNum == 5 then
        bBurstTimer = nil
        bRushTimer = nil
        patternTimer = 5.0
        nextPattern = "laser_grid"
    elseif bossStageNum == 6 then
        bBurstTimer = nil
        bRushTimer = nil
        patternTimer = 6.0
        nextPattern = "time_burst"
    elseif bossStageNum == 7 then
        bBurstTimer = nil
        bRushTimer = nil
        patternTimer = 5.0
        nextPattern = "system_hack"
    elseif bossStageNum == 8 then
        bBurstTimer = nil
        bRushTimer = nil
        patternTimer = 5.0
        nextPattern = "gravity_well"
    elseif bossStageNum >= 9 then
        bBurstTimer = nil
        bRushTimer = nil
        patternTimer = 5.0
        nextPattern = "supernova"
    end

    local stageMultiplier = 1.0 + ((game.stage or 1) - 1) * 0.5
    local finalMultiplier = stageMultiplier * waveMultiplier

    local boss = {
        x = ex,
        y = ey,
        width = bossSize,
        height = bossSize,
        speed = bossSpeed,
        health = baseHealth * finalMultiplier,
        maxHealth = baseHealth * finalMultiplier,
        type = "boss",
        color = bossColor,
        name = bossName,
        points = pointsVal,
        shootCooldown = 2.0,
        shootTimer = 1.0,
        shootRange = 450,
        velX = 0,
        velY = 0,
        bossState = "normal",
        burstTimer = bBurstTimer,
        petalTimer = bPetalTimer,
        rushTimer = bRushTimer,
        patternTimer = patternTimer,
        nextPattern = nextPattern,
        dashCount = 0,
        stateTimer = 0,
        trailHistory = {},
        shieldAngle = 0,
        laserAngle = 0,
        bossStageNum = bossStageNum
    }
    table.insert(game.enemies, boss)

    if bossStageNum == 5 then
        for i = 1, 4 do
            local sAngle = (i - 1) * (math.pi / 2)
            local bCenterX = ex + bossSize / 2
            local bCenterY = ey + bossSize / 2
            local sx = bCenterX + math.cos(sAngle) * 120 - 12
            local sy = bCenterY + math.sin(sAngle) * 120 - 12
            table.insert(game.enemies, {
                x = sx,
                y = sy,
                width = 24,
                height = 24,
                speed = 0,
                health = 11250 * finalMultiplier,
                maxHealth = 11250 * finalMultiplier,
                type = "aegis_shield",
                color = { 1.0, 0.8, 0.1 },
                points = 150,
                velX = 0,
                velY = 0,
                shieldIndex = i,
                parentBoss = boss
            })
        end
    end

    return boss
end

-- 웨이브 적 전체 스폰
function Enemy.spawnWave(game, wave)
    local player = game.player
    if not player then return end

    -- 기존 적 리스트 비우기
    game.enemies = {}

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local camX = game.camera.x
    local camY = game.camera.y
    local padding = 50 -- 화면 가장자리 50px 여유 공간

    local stageMultiplier = 1.0 + ((game.stage or 1) - 1) * 0.5
    local isBossWave = (not game.endlessMode and wave == 7) or (game.endlessMode and wave % 5 == 0)
    if isBossWave then
        local waveMultiplier = 1.0
        if game.endlessMode then
            waveMultiplier = 1.12 ^ (math.floor(wave / 5) - 1)
        end

        local spawnedBosses = {}
        local angle = math.random() * 2 * math.pi

        if game.endlessMode and wave % 10 == 0 then
            -- 10, 20, 30... waves: spawn 2 distinct random bosses
            local b1 = math.random(1, 9)
            local b2 = math.random(1, 8)
            if b2 >= b1 then b2 = b2 + 1 end

            local boss1 = Enemy.createSingleBoss(game, b1, angle, waveMultiplier)
            local boss2 = Enemy.createSingleBoss(game, b2, angle + math.pi, waveMultiplier)
            if boss1 then table.insert(spawnedBosses, boss1) end
            if boss2 then table.insert(spawnedBosses, boss2) end
        else
            -- 5, 15, 25... waves or normal mode wave 7: spawn 1 boss
            local bossStageNum = game.stage or 1
            if game.endlessMode then
                bossStageNum = math.random(1, 9)
            end
            local boss = Enemy.createSingleBoss(game, bossStageNum, angle, waveMultiplier)
            if boss then table.insert(spawnedBosses, boss) end
        end

        -- Spawn 4 initial normal minions near the first spawned boss
        if #spawnedBosses > 0 then
            local mainBoss = spawnedBosses[1]
            local ex = mainBoss.x
            local ey = mainBoss.y
            for i = 1, 4 do
                local mx = ex + math.random(-150, 150)
                local my = ey + math.random(-150, 150)
                mx = math.max(10, math.min(game.world.width - 34, mx))
                my = math.max(10, math.min(game.world.height - 34, my))
                table.insert(game.enemies, {
                    x = mx,
                    y = my,
                    width = 24,
                    height = 24,
                    speed = 90,
                    health = 78 * stageMultiplier,
                    maxHealth = 78 * stageMultiplier,
                    type = "normal",
                    color = { 1.0, 0.3, 0.3 },
                    points = 10,
                    velX = 0,
                    velY = 0
                })
            end
        end
        game.bossActive = true
        game.bossMinionTimer = 0
        game.bannerText = "BOSS WAVE START"
        game.bannerTimer = 3.0
    else
        local enemyCount = math.floor(20 * (1.2 ^ (wave - 1))) -- 첫 웨이브 20마리 시작, 매 웨이브 1.2배 복리 증가
        if game.endlessMode then
            enemyCount = math.min(150, math.floor(20 * (1.12 ^ (wave - 1))))
        end
        local spawned = 0

        -- 적 스폰 루프
        while spawned < enemyCount do
            local ex = math.random(0, game.world.width)
            local ey = math.random(0, game.world.height)

            local dx = ex - player.x
            local dy = ey - player.y
            local dist = math.sqrt(dx * dx + dy * dy)

            -- 카메라 뷰포트 내부에 있는지 확인
            local insideCam = ex >= camX - padding and ex <= camX + screenWidth + padding and
                ey >= camY - padding and ey <= camY + screenHeight + padding

            -- 카메라 화면 바깥쪽이고, 너무 멀리 떨어져 있지 않은(800px 이하) 영역에 스폰
            if not insideCam and dist < 800 then
                -- 웨이브 진행에 따라 다른 유형의 적 출현
                local enemyType = "normal"
                local rand = math.random()
                local isStage2 = (game.stage or 1) >= 2

                if wave >= 5 then
                    if rand < 0.15 then
                        enemyType = "fast"
                    elseif rand < 0.30 then
                        enemyType = "ranged"
                    elseif rand < 0.45 then
                        enemyType = "tank"
                    elseif isStage2 and rand < 0.60 then
                        enemyType = "charger"
                    end
                elseif wave >= 4 then
                    if rand < 0.15 then
                        enemyType = "fast"
                    elseif rand < 0.30 then
                        enemyType = "ranged"
                    elseif isStage2 and rand < 0.45 then
                        enemyType = "charger"
                    end
                elseif wave >= 3 then
                    if rand < 0.20 then
                        enemyType = "fast"
                    elseif isStage2 and rand < 0.35 then
                        enemyType = "charger"
                    end
                elseif isStage2 and wave >= 1 then
                    if rand < 0.15 then
                        enemyType = "charger"
                    end
                end

                local width, height = 24, 24
                local speed = 80 + math.random(0, 40)
                local maxHealth = (30 + (wave - 1) * 8) * stageMultiplier
                local hp = maxHealth
                local color = { 1.0, 0.3, 0.3 } -- 기본 빨강 (Normal)
                local points = 10
                local shootCooldown, shootTimer, shootRange = nil, nil, nil
                local dashSpeed, dashRange = nil, nil

                if enemyType == "charger" then
                    width, height = 22, 22
                    speed = 75 + math.random(0, 15)
                    maxHealth = (35 + (wave - 1) * 7) * stageMultiplier
                    hp = maxHealth
                    color = { 0.1, 0.8, 1.0 } -- 하늘색 (Charger)
                    points = 25
                    dashSpeed = 600
                    dashRange = 500
                elseif enemyType == "fast" then
                    width, height = 18, 18
                    speed = 130 + math.random(0, 30)
                    maxHealth = (20 + (wave - 1) * 4) * stageMultiplier
                    hp = maxHealth
                    color = { 1.0, 0.6, 0.2 } -- 주황 (Fast)
                    points = 15
                elseif enemyType == "tank" then
                    width, height = 36, 36
                    speed = 50 + math.random(0, 15)
                    maxHealth = (80 + (wave - 1) * 15) * stageMultiplier
                    hp = maxHealth
                    color = { 0.8, 0.2, 0.6 } -- 마젠타/자주 (Tank)
                    points = 30
                elseif enemyType == "ranged" then
                    width, height = 20, 20
                    speed = 70 + math.random(0, 20)
                    maxHealth = (25 + (wave - 1) * 6) * stageMultiplier
                    hp = maxHealth
                    color = { 0.2, 0.8, 0.4 } -- 녹색/청록 (Ranged)
                    points = 20
                    shootCooldown = 2.5
                    shootTimer = math.random() * 2.5
                    shootRange = 250
                end

                local enemy = {
                    x = ex,
                    y = ey,
                    width = width,
                    height = height,
                    speed = speed,
                    health = hp,
                    maxHealth = maxHealth,
                    type = enemyType,
                    color = color,
                    points = points,
                    shootCooldown = shootCooldown,
                    shootTimer = shootTimer,
                    shootRange = shootRange,
                    dashSpeed = dashSpeed,
                    dashRange = dashRange,
                    velX = 0,
                    velY = 0
                }

                table.insert(game.enemies, enemy)
                spawned = spawned + 1
            end
        end

        -- 웨이브 중앙 안내 배너 설정
        game.bannerText = "WAVE " .. wave
        game.bannerTimer = 2.0
    end
end

-- 적들의 위치 이동 및 모든 무기 스킬과의 피격 판정 처리
function Enemy.update(game, dt)
    local player = game.player
    if not player then return end

    -- [NEW] 텔레포트 잔상(Echoes) 업데이트
    if game.teleportEchoes then
        for i = #game.teleportEchoes, 1, -1 do
            local echo = game.teleportEchoes[i]
            echo.life = echo.life - dt
            if echo.life <= 0 then
                table.remove(game.teleportEchoes, i)
            else
                echo.alpha = (echo.life / echo.maxLife) * 0.8
            end
        end
    end

    -- [NEW] 텔레포트 파티클 업데이트
    if game.teleportParticles then
        for i = #game.teleportParticles, 1, -1 do
            local p = game.teleportParticles[i]
            p.life = p.life - dt
            if p.life <= 0 then
                table.remove(game.teleportParticles, i)
            else
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
            end
        end
    end

    local isBossWave = (not game.endlessMode and game.wave == 7) or (game.endlessMode and game.wave % 5 == 0)

    -- Reset temporary speed debuffs (or apply timeSlowTimer if active)
    if player.timeSlowTimer and player.timeSlowTimer > 0 then
        player.timeSlowTimer = player.timeSlowTimer - dt
        player.speedMultiplier = 0.4
    else
        player.speedMultiplier = 1.0
    end

    -- 웨이브 전환 상태 관리
    if game.waveState == "playing" then
        if isBossWave then
            -- 보스전인 경우: 보스가 살아있는지 검사
            local bossAlive = false
            for _, enemy in ipairs(game.enemies) do
                if enemy.type == "boss" then
                    bossAlive = true
                    break
                end
            end

            if game.bossActive and not bossAlive then
                -- 보스가 격퇴됨 -> 모든 적 및 탄환 자동 청소
                game.enemies = {}
                game.enemyBullets = {}
                game.bossActive = false

                if game.endlessMode then
                    game.waveState = "cleared"
                    game.waveTransitionTimer = 3.0
                    game.bannerText = "WAVE " .. (game.wave or 1) .. " CLEAR!"
                    game.bannerTimer = 3.0
                else
                    game.waveState = "stage_cleared"
                    game.waveTransitionTimer = 4.0
                    game.bannerText = "STAGE " .. (game.stage or 1) .. " CLEAR!"
                    game.bannerTimer = 4.0
                end
            end
        else
            -- 일반 웨이브인 경우: 적 전멸 시 클리어
            if #game.enemies == 0 then
                game.waveState = "cleared"
                game.waveTransitionTimer = 2.5
                game.bannerText = "WAVE " .. (game.wave or 1) .. " CLEAR!"
                game.bannerTimer = 2.5
            end
        end
    elseif game.waveState == "cleared" then
        game.waveTransitionTimer = game.waveTransitionTimer - dt
        if game.waveTransitionTimer <= 0 then
            game.wave = (game.wave or 1) + 1
            game.waveState = "playing"
            Enemy.spawnWave(game, game.wave)
        end
    elseif game.waveState == "stage_cleared" then
        game.waveTransitionTimer = game.waveTransitionTimer - dt
        if game.waveTransitionTimer <= 0 then
            -- 스테이지 클리어 화면으로 진입 (자동 전향 중단)
            game.state = "stage_clear"
            game.running = false
        end
    end

    -- 보스전인 경우 주기적으로 잡몹 소환 (화면 외곽)
    if isBossWave and game.waveState == "playing" and game.bossActive then
        game.bossMinionTimer = (game.bossMinionTimer or 0) + dt
        if game.bossMinionTimer >= 4.0 then
            game.bossMinionTimer = 0

            -- 화면 바깥의 스폰 위치 계산
            local screenWidth = love.graphics.getWidth()
            local screenHeight = love.graphics.getHeight()
            local camX = game.camera.x
            local camY = game.camera.y
            local padding = 50

            local mx, my
            local insideCam = true
            local attempts = 0
            while insideCam and attempts < 100 do
                mx = math.random(0, game.world.width)
                my = math.random(0, game.world.height)
                insideCam = mx >= camX - padding and mx <= camX + screenWidth + padding and
                    my >= camY - padding and my <= camY + screenHeight + padding
                attempts = attempts + 1
            end

            -- 소환할 잡몹 유형 결정 (normal, fast, ranged)
            local minionType = "normal"
            local rand = math.random()
            if rand < 0.33 then
                minionType = "fast"
            elseif rand < 0.66 then
                minionType = "ranged"
            end

            local w, h = 24, 24
            local spd = 90
            local maxHp = 40
            local col = { 1.0, 0.3, 0.3 }
            local pts = 10
            local sc, st, sr

            if minionType == "fast" then
                w, h = 18, 18
                spd = 140
                maxHp = 25
                col = { 1.0, 0.6, 0.2 }
                pts = 15
            elseif minionType == "ranged" then
                w, h = 20, 20
                spd = 80
                maxHp = 30
                col = { 0.2, 0.8, 0.4 }
                pts = 20
                sc = 2.5
                st = math.random() * 2.5
                sr = 250
            end

            table.insert(game.enemies, {
                x = mx,
                y = my,
                width = w,
                height = h,
                speed = spd,
                maxHealth = maxHp,
                health = maxHp,
                type = minionType,
                color = col,
                points = pts,
                shootCooldown = sc,
                shootTimer = st,
                shootRange = sr,
                velX = 0,
                velY = 0
            })
        end
    end

    -- 배너 타이머 차감
    if game.bannerTimer and game.bannerTimer > 0 then
        game.bannerTimer = game.bannerTimer - dt
    end

    -- 순환 의존성(Circular Dependency) 방지를 위해 필요할 때 로컬에 로드
    local Exp = require("progression.exp")

    -- 수명이 다한 glitch_clone 제거 처리
    for i = #game.enemies, 1, -1 do
        local enemy = game.enemies[i]
        if enemy.type == "glitch_clone" then
            enemy.lifeTimer = (enemy.lifeTimer or 3.0) - dt
            if enemy.lifeTimer <= 0 then
                table.remove(game.enemies, i)
            end
        end
    end

    -- 적 이동 및 충돌
    for i = #game.enemies, 1, -1 do
        local enemy = game.enemies[i]

        -- 커터 피격 쿨다운 차감
        if enemy.cutterHitCooldown and enemy.cutterHitCooldown > 0 then
            enemy.cutterHitCooldown = enemy.cutterHitCooldown - dt
        end

        -- [NEW] 텔레포트 페이드 타이머 차감
        if enemy.teleportFade and enemy.teleportFade > 0 then
            enemy.teleportFade = enemy.teleportFade - dt
        end

        -- 플레이어 추적 및 뭉침 방지 (Separation)
        local isRooted = (enemy.rootedTimer and enemy.rootedTimer > 0)
        if isRooted then
            enemy.rootedTimer = enemy.rootedTimer - dt
        end

        local isSlowed = (enemy.slowTimer and enemy.slowTimer > 0)
        if isSlowed then
            enemy.slowTimer = enemy.slowTimer - dt
            if enemy.slowTimer <= 0 then
                enemy.slowMultiplier = nil
            end
        end

        local dx = player.x - enemy.x
        local dy = player.y - enemy.y
        local dist = math.sqrt(dx * dx + dy * dy)

        local targetVelX = 0
        local targetVelY = 0

        if isRooted then
            -- 속박 상태: 물리 속도 및 타겟 속도 0 고정
            targetVelX = 0
            targetVelY = 0
            enemy.velX = 0
            enemy.velY = 0
        elseif enemy.type == "boss" then
            targetVelX, targetVelY = BossUpdate.update(game, enemy, dt, dx, dy, dist, player)
        elseif enemy.type == "charger" then
            -- Charger state machine
            enemy.chargerState = enemy.chargerState or "normal"
            enemy.chargeTimer = enemy.chargeTimer or (math.random() * 3.0 + 2.0)

            if enemy.chargerState == "normal" then
                enemy.chargeTimer = enemy.chargeTimer - dt
                if enemy.chargeTimer <= 0 then
                    enemy.chargerState = "charging"
                    enemy.stateTimer = 0.8 -- Aiming duration

                    local pCenterX = player.x + player.width / 2
                    local pCenterY = player.y + player.height / 2
                    local eCenterX = enemy.x + enemy.width / 2
                    local eCenterY = enemy.y + enemy.height / 2
                    local ldx = pCenterX - eCenterX
                    local ldy = pCenterY - eCenterY
                    local ldist = math.sqrt(ldx * ldx + ldy * ldy)
                    if ldist > 0 then
                        enemy.rushDirX, enemy.rushDirY = ldx / ldist, ldy / ldist
                    else
                        enemy.rushDirX, enemy.rushDirY = 1, 0
                    end
                end

                -- Move towards player normally
                if dist > 0 then
                    targetVelX = (dx / dist) * enemy.speed
                    targetVelY = (dy / dist) * enemy.speed
                end
            elseif enemy.chargerState == "charging" then
                enemy.stateTimer = enemy.stateTimer - dt
                targetVelX, targetVelY = 0, 0
                if enemy.stateTimer <= 0 then
                    enemy.chargerState = "rushing"
                    local chargerDashSpeed = enemy.dashSpeed or 320
                    local chargerDashRange = enemy.dashRange or 500
                    local duration = 0.6
                    if chargerDashSpeed > 0 then
                        duration = chargerDashRange / chargerDashSpeed
                    end
                    enemy.stateTimer = duration
                    -- Start dash instantly to avoid delay from turnSpeed lerp acceleration
                    enemy.velX = enemy.rushDirX * chargerDashSpeed
                    enemy.velY = enemy.rushDirY * chargerDashSpeed
                end
            elseif enemy.chargerState == "rushing" then
                enemy.stateTimer = enemy.stateTimer - dt
                local chargerDashSpeed = enemy.dashSpeed or 320
                targetVelX = enemy.rushDirX * chargerDashSpeed
                targetVelY = enemy.rushDirY * chargerDashSpeed
                if enemy.stateTimer <= 0 then
                    enemy.chargerState = "normal"
                    enemy.chargeTimer = math.random() * 2.5 + 2.5
                end
            end
        else
            -- 원거리 적의 경우, 사거리 내에 들어오면 멈춰서 사격
            if dist > 0 then
                if enemy.type == "boss_clone" and (enemy.bossState == "charging_crossfire" or enemy.bossState == "crossfire_firing") then
                    targetVelX = 0
                    targetVelY = 0
                    enemy.velX = 0
                    enemy.velY = 0
                elseif enemy.type == "ranged" and dist <= (enemy.shootRange or 250) then
                    targetVelX = 0
                    targetVelY = 0
                else
                    targetVelX = (dx / dist) * enemy.speed
                    targetVelY = (dy / dist) * enemy.speed
                end
            end
        end

        -- 몬스터 간 뭉침 방지 (Separation Force 계산) - 보스는 무겁기 때문에 밀려나지 않음
        local sepForceX = 0
        local sepForceY = 0
        local sepRadius = 32 -- 서로 밀쳐낼 임계 거리

        if enemy.type ~= "boss" and enemy.type ~= "boss_clone" and enemy.type ~= "tesla_pylon" and enemy.type ~= "aegis_shield" and enemy.type ~= "glitch_clone" and not isRooted then
            for j = 1, #game.enemies do
                if i ~= j then
                    local other = game.enemies[j]
                    local sdx = enemy.x - other.x
                    local sdy = enemy.y - other.y
                    local sdist = math.sqrt(sdx * sdx + sdy * sdy)

                    if sdist > 0 and sdist < sepRadius then
                        -- 거리가 가까울수록 강하게 밀어내기 (0에서 1사이 비율)
                        local force = (sepRadius - sdist) / sepRadius
                        -- 밀어내는 방향의 벡터 축적
                        sepForceX = sepForceX + (sdx / sdist) * force * 150
                        sepForceY = sepForceY + (sdy / sdist) * force * 150
                    end
                end
            end
        end

        -- 목표 추적 속도에 밀쳐내는 힘 결합
        targetVelX = targetVelX + sepForceX
        targetVelY = targetVelY + sepForceY

        -- 최종 목표 속도 제한 (밀쳐내는 힘 합산 시 과속 방지)
        local targetSpeed = math.sqrt(targetVelX * targetVelX + targetVelY * targetVelY)
        local maxAllowedSpeed = enemy.speed * 1.3
        if enemy.type == "boss" then
            if enemy.bossState == "rushing" then
                maxAllowedSpeed = 280
            elseif enemy.bossState == "dashing" then
                maxAllowedSpeed = 1200
            else
                maxAllowedSpeed = enemy.speed * 1.3
            end
        elseif enemy.type == "charger" then
            if enemy.chargerState == "rushing" then
                maxAllowedSpeed = enemy.dashSpeed or 320
            else
                maxAllowedSpeed = enemy.speed * 1.3
            end
        end

        if targetSpeed > maxAllowedSpeed and targetSpeed > 0 then
            targetVelX = (targetVelX / targetSpeed) * maxAllowedSpeed
            targetVelY = (targetVelY / targetSpeed) * maxAllowedSpeed
        end

        -- 방향 부드럽게 변경 (lerp)
        local turnSpeed = 3.0
        if isRooted or enemy.type == "tesla_pylon" or enemy.type == "aegis_shield" or enemy.type == "glitch_clone" or (enemy.type == "boss_clone" and (enemy.bossState == "charging_crossfire" or enemy.bossState == "crossfire_firing")) then
            enemy.velX = 0
            enemy.velY = 0
        else
            enemy.velX = enemy.velX + (targetVelX - enemy.velX) * turnSpeed * dt
            enemy.velY = enemy.velY + (targetVelY - enemy.velY) * turnSpeed * dt
        end

        -- 위치 갱신 (슬로우 상태인 경우 이동 속도 임시 감속 적용)
        local vx = enemy.velX
        local vy = enemy.velY
        if isSlowed then
            local mult = enemy.slowMultiplier or 0.5
            vx = vx * mult
            vy = vy * mult
        end
        enemy.x = enemy.x + vx * dt
        enemy.y = enemy.y + vy * dt

        -- 월드 경계 제한 (적들이 맵 밖으로 나가지 않도록 설정)
        enemy.x = math.max(0, math.min(game.world.width - enemy.width, enemy.x))
        enemy.y = math.max(0, math.min(game.world.height - enemy.height, enemy.y))

        -- 원거리 적 사격 타이머 업데이트 및 탄환 발사
        if enemy.type == "ranged" and dist <= (enemy.shootRange or 250) then
            enemy.shootTimer = (enemy.shootTimer or 0) - dt
            if enemy.shootTimer <= 0 then
                enemy.shootTimer = enemy.shootCooldown or 2.5
                -- 플레이어 방향으로 탄환 발사
                local bdx = player.x + player.width / 2 - (enemy.x + enemy.width / 2)
                local bdy = player.y + player.height / 2 - (enemy.y + enemy.height / 2)
                local bdist = math.sqrt(bdx * bdx + bdy * bdy)
                if bdist > 0 then
                    game.enemyBullets = game.enemyBullets or {}
                    table.insert(game.enemyBullets, {
                        x = enemy.x + enemy.width / 2,
                        y = enemy.y + enemy.height / 2,
                        dirX = bdx / bdist,
                        dirY = bdy / bdist,
                        speed = 180,
                        damage = 6 + math.floor((game.wave or 1) * 0.5), -- 데미지 웨이브 비례 증가
                        size = 6,
                        maxDist = 450,
                        distTraveled = 0
                    })
                end
            end
        end

        -- 글리치 분신 사격 처리 (0.4초마다 8방향 error_code 투사체 발사)
        if enemy.type == "glitch_clone" then
            enemy.shootTimer = (enemy.shootTimer or 0.4) - dt
            if enemy.shootTimer <= 0 then
                enemy.shootTimer = 0.4
                local bCenterX = enemy.x + enemy.width / 2
                local bCenterY = enemy.y + enemy.height / 2
                local texts = { "404", "FATAL", "ERROR", "NULL", "VOID", "CRASH" }

                game.enemyBullets = game.enemyBullets or {}
                for k = 1, 8 do
                    local angle = (k - 1) * (2 * math.pi / 8)
                    table.insert(game.enemyBullets, {
                        x = bCenterX,
                        y = bCenterY,
                        dirX = math.cos(angle),
                        dirY = math.sin(angle),
                        speed = 180,
                        damage = 10,
                        size = 8,
                        maxDist = 500,
                        distTraveled = 0,
                        type = "error_code",
                        text = texts[math.random(1, #texts)],
                        colorIndex = math.random(0, 2)
                    })
                end
            end
        end

        -- 보스 사격 타이머 업데이트 및 부채꼴(3방향) 탄환 발사 (normal 상태일 때만, 1/2스테이지 보스만 사격)
        if enemy.type == "boss" and enemy.bossState == "normal" and (enemy.bossStageNum or game.stage or 1) < 3 and dist <= (enemy.shootRange or 400) then
            enemy.shootTimer = (enemy.shootTimer or 0) - dt
            if enemy.shootTimer <= 0 then
                enemy.shootTimer = enemy.shootCooldown or 2.0
                -- 플레이어 방향으로 3방향 탄환 발사
                local bdx = player.x + player.width / 2 - (enemy.x + enemy.width / 2)
                local bdy = player.y + player.height / 2 - (enemy.y + enemy.height / 2)
                local bdist = math.sqrt(bdx * bdx + bdy * bdy)
                if bdist > 0 then
                    game.enemyBullets = game.enemyBullets or {}
                    local baseAngle = math.atan2(bdy, bdx)
                    for angleOffset = -0.3, 0.3, 0.3 do
                        local angle = baseAngle + angleOffset
                        table.insert(game.enemyBullets, {
                            x = enemy.x + enemy.width / 2,
                            y = enemy.y + enemy.height / 2,
                            dirX = math.cos(angle),
                            dirY = math.sin(angle),
                            speed = 160,
                            damage = 15, -- 보스 탄환 대미지
                            size = 8,    -- 탄환 크기
                            maxDist = 550,
                            distTraveled = 0
                        })
                    end
                end
            end
        end

        -- 플레이어와 충돌 (피격 판정 처리, 겹침 해소는 생략하여 겹칠 수 있도록 함)
        if Collision.check(enemy, player) then
            if player.invincibleTime <= 0 then
                -- 적 종류별 기본 대미지
                local baseDamage = 1
                if enemy.type == "boss" then
                    -- 보스 대미지는 플레이어 최대 체력의 5%로 고정
                    baseDamage = player.maxHealth * 0.05
                elseif enemy.type == "boss_clone" then
                    -- 보스 분신 대미지도 플레이어 최대 체력의 5%로 고정
                    baseDamage = player.maxHealth * 0.05
                elseif enemy.type == "tank" then
                    baseDamage = 2
                elseif enemy.type == "fast" then
                    baseDamage = 1.5
                elseif enemy.type == "ranged" then
                    baseDamage = 1.2
                elseif enemy.type == "charger" then
                    baseDamage = enemy.chargerState == "rushing" and 2.5 or 1.8
                elseif enemy.type == "aegis_shield" then
                    baseDamage = 1.5
                elseif enemy.type == "tesla_pylon" then
                    baseDamage = 0.5
                end

                -- 웨이브별 대미지 배수 (웨이브 1: 1.0, 웨이브 2: 1.1, ...)
                local waveMultiplier = 1.0 + (game.wave - 1) * 0.1

                -- 스테이지별 대미지 배수
                local stageMultiplier = 1.0 + ((game.stage or 1) - 1) * 0.5

                -- 최종 대미지 계산
                local dmg
                if enemy.type == "boss" or enemy.type == "boss_clone" then
                    -- 보스와 보스 분신은 체력 비율로 고정, 배수 미적용
                    dmg = baseDamage
                else
                    -- 일반 적은 웨이브/스테이지 배수 적용
                    dmg = baseDamage * waveMultiplier * stageMultiplier
                end
                dmg = math.floor(dmg * 10) / 10 -- 소수점 한 자리까지 반올림

                player.health = player.health - dmg
                player.invincibleTime = player.maxInvincibleTime
                -- 체력 재생 타이머 리셋
                player.regenTimer = 0
                -- 가시 특성 트리거 예약
                game.pendingThornsAttackers = game.pendingThornsAttackers or {}
                table.insert(game.pendingThornsAttackers, enemy or "none")
                if player.health <= 0 then
                    game.running = false
                    game.state = "gameover"
                end
            end
        end

        -- 구체 충돌 (Orbiting Orb)
        local enemyRemoved = false
        for _, orb in ipairs(game.orbs) do
            local orbRect = { x = orb.x, y = orb.y, width = orb.size, height = orb.size }
            if Collision.check(enemy, orbRect) then
                if Enemy.damage(game, i, orb.damage) then
                    enemyRemoved = true
                    break
                end
            end
        end

        -- 벼락 충돌 (Thunder)
        if not enemyRemoved then
            for _, thunder in ipairs(game.thunders) do
                local thunderRect = {
                    x = thunder.x - thunder.size / 2,
                    y = thunder.y - thunder.size / 2,
                    width = thunder.size,
                    height = thunder.size
                }
                if Collision.check(enemy, thunderRect) then
                    if Enemy.damage(game, i, thunder.damage) then
                        enemyRemoved = true
                        break
                    end
                end
            end
        end

        -- 칼날 충돌 (Blade)
        if not enemyRemoved then
            for _, blade in ipairs(game.blades) do
                local bladeRect = {
                    x = blade.x - blade.size / 2,
                    y = blade.y - blade.size / 2,
                    width = blade.size,
                    height = blade.size
                }
                if Collision.check(enemy, bladeRect) then
                    if Enemy.damage(game, i, blade.damage) then
                        enemyRemoved = true
                        break
                    end
                end
            end
        end

        -- 총알 충돌 (Bullet)
        if not enemyRemoved then
            for _, bullet in ipairs(game.bullets) do
                local bulletRect = {
                    x = bullet.x - bullet.size / 2,
                    y = bullet.y - bullet.size / 2,
                    width = bullet.size,
                    height = bullet.size
                }

                -- 이미 해당 적을 타격했는지 중복 검사 (다중 피격 방지) 및 관통 처리를 위한 제거 마크
                if not bullet.toRemove and not bullet.hitEnemies[enemy] and Collision.check(enemy, bulletRect) then
                    bullet.hitEnemies[enemy] = true
                    if not bullet.pierce then
                        bullet.toRemove = true
                    end
                    if Enemy.damage(game, i, bullet.damage) then
                        enemyRemoved = true
                        break
                    end
                end
            end
        end
    end

    -- 보스 전용 불장판 업데이트 및 플레이어 피격 판정
    game.bossFirePatches = game.bossFirePatches or {}
    for i = #game.bossFirePatches, 1, -1 do
        local patch = game.bossFirePatches[i]
        patch.timer = patch.timer + dt
        patch.tickTimer = (patch.tickTimer or 0) + dt

        if patch.tickTimer >= 0.4 then
            patch.tickTimer = 0
            local pdx = (player.x + player.width / 2) - patch.x
            local pdy = (player.y + player.height / 2) - patch.y
            local distToPlayer = math.sqrt(pdx * pdx + pdy * pdy)

            if distToPlayer <= (patch.radius + player.width / 2) then
                if player.invincibleTime <= 0 then
                    player.health = player.health - 6 -- 6 damage
                    player.invincibleTime = player.maxInvincibleTime
                    player.regenTimer = 0
                    -- 가시 특성 트리거 예약
                    game.pendingThornsAttackers = game.pendingThornsAttackers or {}
                    table.insert(game.pendingThornsAttackers, "none")
                    if player.health <= 0 then
                        game.running = false
                        game.state = "gameover"
                    end
                end
            end
        end

        if patch.timer >= patch.duration then
            table.remove(game.bossFirePatches, i)
        end
    end

    -- 코스믹 유성 업데이트
    game.cosmicMeteors = game.cosmicMeteors or {}
    for i = #game.cosmicMeteors, 1, -1 do
        local met = game.cosmicMeteors[i]
        met.timer = met.timer - dt
        if met.timer <= 0 then
            if not met.exploded then
                met.exploded = true
                -- 폭발 데미지 판정
                local px = player.x + player.width / 2
                local py = player.y + player.height / 2
                local dx = px - met.x
                local dy = py - met.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist <= met.radius + player.width / 2 then
                    if player.invincibleTime <= 0 then
                        player.health = player.health - 15
                        player.invincibleTime = player.maxInvincibleTime
                        player.regenTimer = 0
                        game.pendingThornsAttackers = game.pendingThornsAttackers or {}
                        table.insert(game.pendingThornsAttackers, "none")
                        if player.health <= 0 then
                            game.running = false
                            game.state = "gameover"
                        end
                    end
                end
                -- 화면 흔들림
                game.shakeTimer = 0.25
                game.shakeIntensity = 8
                -- 바닥에 불꽃 생성
                game.bossFirePatches = game.bossFirePatches or {}
                table.insert(game.bossFirePatches, {
                    x = met.x,
                    y = met.y,
                    radius = met.radius,
                    timer = 0,
                    duration = 3.0
                })
            end
            table.remove(game.cosmicMeteors, i)
        end
    end

    -- 적 탄환 투사체 업데이트
    game.enemyBullets = game.enemyBullets or {}
    for i = #game.enemyBullets, 1, -1 do
        local bullet = game.enemyBullets[i]
        local bulletRemoved = false

        if bullet.type == "petal" then
            bullet.timeActive = (bullet.timeActive or 0) + dt
            local perpX = -bullet.dirY
            local perpY = bullet.dirX
            local waveSpeed = 8
            local waveAmp = 100 -- amplitude of perpendicular velocity
            local moveX = bullet.dirX * bullet.speed + perpX * math.sin(bullet.timeActive * waveSpeed) * waveAmp
            local moveY = bullet.dirY * bullet.speed + perpY * math.sin(bullet.timeActive * waveSpeed) * waveAmp
            bullet.x = bullet.x + moveX * dt
            bullet.y = bullet.y + moveY * dt
            bullet.distTraveled = bullet.distTraveled + bullet.speed * dt
            bullet.angle = (bullet.angle or 0) + 4 * dt
        elseif bullet.type == "void_mine" then
            bullet.timer = (bullet.timer or 0.8) - dt
            if bullet.timer <= 0 then
                -- Explode into 4-way cross bullets
                local bulletSpeed = 160
                local angles = { 0, math.pi / 2, math.pi, math.pi * 1.5 }
                for _, angle in ipairs(angles) do
                    table.insert(game.enemyBullets, {
                        x = bullet.x,
                        y = bullet.y,
                        dirX = math.cos(angle),
                        dirY = math.sin(angle),
                        speed = bulletSpeed,
                        damage = 10,
                        size = 6,
                        maxDist = 500,
                        distTraveled = 0,
                        type = "void_bullet"
                    })
                end
                table.remove(game.enemyBullets, i)
                bulletRemoved = true
            end
        elseif bullet.type == "tesla_spark" then
            -- Homing on player
            local targetX = player.x + player.width / 2
            local targetY = player.y + player.height / 2
            local dx = targetX - bullet.x
            local dy = targetY - bullet.y
            local distToPlayer = math.sqrt(dx * dx + dy * dy)
            if distToPlayer > 0 then
                local targetDirX = dx / distToPlayer
                local targetDirY = dy / distToPlayer

                local homingStrength = 2.5 * dt
                bullet.dirX = bullet.dirX + (targetDirX - bullet.dirX) * homingStrength
                bullet.dirY = bullet.dirY + (targetDirY - bullet.dirY) * homingStrength

                local newLen = math.sqrt(bullet.dirX * bullet.dirX + bullet.dirY * bullet.dirY)
                if newLen > 0 then
                    bullet.dirX = bullet.dirX / newLen
                    bullet.dirY = bullet.dirY / newLen
                end
            end

            local moveDist = bullet.speed * dt
            bullet.x = bullet.x + bullet.dirX * moveDist
            bullet.y = bullet.y + bullet.dirY * moveDist
            bullet.distTraveled = bullet.distTraveled + moveDist
        elseif bullet.type == "temporal" then
            bullet.timer = (bullet.timer or 0) + dt
            if bullet.state == "forward" then
                if bullet.timer >= 1.5 then
                    bullet.state = "drift"
                    bullet.timer = 0
                    bullet.speed = 360
                    bullet.distTraveled = 0
                    -- Aim at player's current position for the drift phase
                    local px = player.x + player.width / 2
                    local py = player.y + player.height / 2
                    local tdx = px - bullet.x
                    local tdy = py - bullet.y
                    local tdist = math.sqrt(tdx * tdx + tdy * tdy)
                    if tdist > 0 then
                        bullet.dirX = tdx / tdist
                        bullet.dirY = tdy / tdist
                    end
                else
                    local factor = 1.0 - bullet.timer / 1.5
                    local currentSpeed = bullet.speed * factor
                    local moveDist = currentSpeed * dt
                    bullet.x = bullet.x + bullet.dirX * moveDist
                    bullet.y = bullet.y + bullet.dirY * moveDist
                    bullet.distTraveled = bullet.distTraveled + moveDist
                end
            elseif bullet.state == "drift" then
                if bullet.timer >= 1.5 then
                    bullet.state = "rewind"
                    bullet.timer = 0
                    bullet.speed = 0
                    bullet.distTraveled = 0
                else
                    local factor = 1.0 - bullet.timer / 1.5
                    local currentSpeed = bullet.speed * factor
                    local moveDist = currentSpeed * dt
                    bullet.x = bullet.x + bullet.dirX * moveDist
                    bullet.y = bullet.y + bullet.dirY * moveDist
                    bullet.distTraveled = bullet.distTraveled + moveDist
                end
            elseif bullet.state == "rewind" then
                local ownerAlive = false
                for _, e in ipairs(game.enemies) do
                    if e == bullet.owner then
                        ownerAlive = true
                        break
                    end
                end

                if ownerAlive then
                    local ox = bullet.owner.x + bullet.owner.width / 2
                    local oy = bullet.owner.y + bullet.owner.height / 2
                    local dx = ox - bullet.x
                    local dy = oy - bullet.y
                    local dist = math.sqrt(dx * dx + dy * dy)

                    if dist < 20 then
                        table.remove(game.enemyBullets, i)
                        bulletRemoved = true
                    else
                        bullet.speed = math.min(450, bullet.speed + 400 * dt)
                        local tx = dx / dist
                        local ty = dy / dist
                        local steerStrength = 8.0 * dt
                        bullet.dirX = bullet.dirX + (tx - bullet.dirX) * steerStrength
                        bullet.dirY = bullet.dirY + (ty - bullet.dirY) * steerStrength
                        local len = math.sqrt(bullet.dirX * bullet.dirX + bullet.dirY * bullet.dirY)
                        if len > 0 then
                            bullet.dirX = bullet.dirX / len
                            bullet.dirY = bullet.dirY / len
                        end
                        local moveDist = bullet.speed * dt
                        bullet.x = bullet.x + bullet.dirX * moveDist
                        bullet.y = bullet.y + bullet.dirY * moveDist
                        bullet.distTraveled = bullet.distTraveled + moveDist
                    end
                else
                    bullet.speed = math.max(0, bullet.speed - 300 * dt)
                    if bullet.speed <= 0 then
                        table.remove(game.enemyBullets, i)
                        bulletRemoved = true
                    else
                        local moveDist = bullet.speed * dt
                        bullet.x = bullet.x + bullet.dirX * moveDist
                        bullet.y = bullet.y + bullet.dirY * moveDist
                    end
                end
            end
        else
            local moveDist = bullet.speed * dt
            bullet.x = bullet.x + bullet.dirX * moveDist
            bullet.y = bullet.y + bullet.dirY * moveDist
            bullet.distTraveled = bullet.distTraveled + moveDist
        end

        -- 플레이어 충돌 검사
        if not bulletRemoved and bullet.type ~= "void_mine" then
            local bulletRect = {
                x = bullet.x - bullet.size / 2,
                y = bullet.y - bullet.size / 2,
                width = bullet.size,
                height = bullet.size
            }

            if Collision.check(bulletRect, player) then
                if player.invincibleTime <= 0 then
                    player.health = player.health - bullet.damage
                    player.invincibleTime = player.maxInvincibleTime
                    player.regenTimer = 0
                    -- 가시 특성 트리거 예약
                    game.pendingThornsAttackers = game.pendingThornsAttackers or {}
                    table.insert(game.pendingThornsAttackers, "none")
                    if player.health <= 0 then
                        game.running = false
                        game.state = "gameover"
                    end
                end
                table.remove(game.enemyBullets, i)
            elseif bullet.distTraveled >= bullet.maxDist then
                table.remove(game.enemyBullets, i)
            end
        end
    end

    -- 대미지 피격 시 예약된 가시(Thorns) 반사 처리 (이터레이터 충돌 및 인덱스 누락 방지용 후처리)
    if game.pendingThornsAttackers and #game.pendingThornsAttackers > 0 then
        local SkillsModule = require("progression.skills")
        for _, attacker in ipairs(game.pendingThornsAttackers) do
            local actualAttacker = (attacker ~= "none") and attacker or nil
            SkillsModule.triggerThorns(game, actualAttacker)
        end
        game.pendingThornsAttackers = {}
    end
end

-- 적들의 렌더링
function Enemy.draw(game)
    -- [NEW] 텔레포트 잔상(Echoes) 그리기
    if game.teleportEchoes then
        for _, echo in ipairs(game.teleportEchoes) do
            local col = echo.color or { 0.25, 0.95, 0.75 }
            local alpha = echo.alpha or 0.8
            love.graphics.setColor(col[1], col[2], col[3], alpha * 0.5)

            local cx = echo.x + echo.width / 2
            local cy = echo.y + echo.height / 2
            local progress = echo.life / echo.maxLife
            local pulse = 1.0 - (1.0 - progress) * 0.3 -- 점점 작아지는 연출

            love.graphics.circle("fill", cx, cy, (echo.width / 2) * pulse)
            love.graphics.rectangle("line", echo.x + echo.width * (1 - pulse) / 2, echo.y + echo.height * (1 - pulse) / 2,
                echo.width * pulse, echo.height * pulse)
        end
    end

    -- [NEW] 텔레포트 파티클 그리기
    if game.teleportParticles then
        for _, p in ipairs(game.teleportParticles) do
            local col = p.color or { 0.25, 0.95, 0.75 }
            local alpha = math.max(0, p.life / p.maxLife)
            love.graphics.setColor(col[1], col[2], col[3], alpha * 0.8)
            love.graphics.circle("fill", p.x, p.y, p.size)
        end
    end

    for _, enemy in ipairs(game.enemies) do
        local col = enemy.color or { 1.0, 0.3, 0.3 }

        if enemy.type == "boss" or enemy.type == "boss_clone" or enemy.type == "tesla_pylon" or enemy.type == "aegis_shield" or enemy.type == "glitch_clone" or enemy.type == "void_anchor" then
            local currentStage = enemy.bossStageNum or game.stage or 1
            local cx = enemy.x + enemy.width / 2
            local cy = enemy.y + enemy.height / 2
            local halfW = enemy.width / 2
            local pulse = 1 + math.sin(game.time * 8) * 0.08

            BossDraw.draw(game, enemy, currentStage, cx, cy, halfW, pulse)
        else
            -- Standard enemy drawing
            local cx = enemy.x + enemy.width / 2
            local cy = enemy.y + enemy.height / 2
            local halfW = enemy.width / 2

            if enemy.type == "charger" then
                -- 5) Delta Wing (Charger - Cyan wedge shape with back boosters)
                local vx = enemy.velX or 0
                local vy = enemy.velY or 0
                local angle = math.atan2(vy, vx)
                if enemy.chargerState == "charging" then
                    angle = math.atan2(enemy.rushDirY or 0, enemy.rushDirX or 0)
                elseif vx == 0 and vy == 0 and game.player then
                    angle = math.atan2(game.player.y - enemy.y, game.player.x - enemy.x)
                end

                -- Warning laser line
                if enemy.chargerState == "charging" then
                    local laserLength = enemy.dashRange or 500
                    local lx = cx + (enemy.rushDirX or 0) * laserLength
                    local ly = cy + (enemy.rushDirY or 0) * laserLength
                    love.graphics.setColor(0.1, 0.8, 1.0, 0.45 + math.sin(game.time * 20) * 0.15)
                    love.graphics.setLineWidth(1.5)
                    love.graphics.line(cx, cy, lx, ly)
                end

                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(angle)

                love.graphics.setColor(0.08, 0.14, 0.18, 0.95)
                love.graphics.polygon("fill", halfW * 1.4, 0, -halfW, halfW * 0.8, -halfW * 0.4, 0, -halfW, -halfW * 0.8)

                if enemy.chargerState == "charging" then
                    if math.floor(game.time * 15) % 2 == 0 then
                        love.graphics.setColor(1.0, 0.3, 0.3, 0.95)
                    else
                        love.graphics.setColor(0.1, 0.8, 1.0, 0.95)
                    end
                elseif enemy.chargerState == "rushing" then
                    love.graphics.setColor(0.3, 0.9, 1.0, 0.95)
                else
                    love.graphics.setColor(col[1], col[2], col[3], 0.9)
                end
                love.graphics.setLineWidth(1.8)
                love.graphics.polygon("line", halfW * 1.4, 0, -halfW, halfW * 0.8, -halfW * 0.4, 0, -halfW, -halfW * 0.8)

                -- Engine flame
                if enemy.chargerState == "rushing" then
                    local flamePulse = 1.3 + math.sin(game.time * 30) * 0.3
                    love.graphics.setColor(0.2, 0.8, 1.0, 0.85)
                    love.graphics.polygon("fill", -halfW * 0.4, 0, -halfW * 1.5 * flamePulse, -halfW * 0.3,
                        -halfW * 1.5 * flamePulse, halfW * 0.3)
                end

                love.graphics.pop()
            elseif enemy.type == "fast" then
                -- 1) Shadow Beetle (Fast - Orange arrowhead with engine thruster & speed lines)
                local vx = enemy.velX or 0
                local vy = enemy.velY or 0
                local angle = math.atan2(vy, vx)
                if vx == 0 and vy == 0 and game.player then
                    angle = math.atan2(game.player.y - enemy.y, game.player.x - enemy.x)
                end

                -- Motion trail line
                love.graphics.setLineWidth(1)
                love.graphics.setColor(col[1], col[2], col[3], 0.35)
                local trailLen = 22
                love.graphics.line(cx, cy, cx - math.cos(angle) * trailLen, cy - math.sin(angle) * trailLen)
                love.graphics.line(cx + math.sin(angle) * 3, cy - math.cos(angle) * 3,
                    cx - math.cos(angle) * trailLen + math.sin(angle) * 3,
                    cy - math.sin(angle) * trailLen - math.cos(angle) * 3)

                -- Arrowhead body
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(angle)

                love.graphics.setColor(0.14, 0.12, 0.16, 0.95)
                love.graphics.polygon("fill", halfW * 1.3, 0, -halfW * 0.9, halfW * 0.7, -halfW * 0.5, 0, -halfW * 0.9,
                    -halfW * 0.7)

                love.graphics.setColor(col[1], col[2], col[3], 0.9)
                love.graphics.setLineWidth(1.5)
                love.graphics.polygon("line", halfW * 1.3, 0, -halfW * 0.9, halfW * 0.7, -halfW * 0.5, 0, -halfW * 0.9,
                    -halfW * 0.7)

                -- Small thruster flame
                local flamePulse = 1 + math.sin(game.time * 25) * 0.25
                love.graphics.setColor(1.0, 0.85, 0.2, 0.8)
                love.graphics.polygon("fill", -halfW * 0.5, 0, -halfW * 1.1 * flamePulse, -halfW * 0.25,
                    -halfW * 1.1 * flamePulse, halfW * 0.25)

                love.graphics.pop()
            elseif enemy.type == "tank" then
                -- 2) Crystal Bastion (Tank - Magenta octagonal fortress with crossed power pipes)
                local pulse = 1 + math.sin(game.time * 4.5 + enemy.y) * 0.04
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(game.time * 0.6)

                love.graphics.setColor(0.15, 0.08, 0.18, 0.95)
                local pts = {}
                for k = 1, 8 do
                    local a = (k - 1) * (math.pi / 4)
                    local r_dist = halfW * 1.1 * pulse
                    table.insert(pts, math.cos(a) * r_dist)
                    table.insert(pts, math.sin(a) * r_dist)
                end
                love.graphics.polygon("fill", pts)

                love.graphics.setColor(col[1], col[2], col[3], 0.95)
                love.graphics.setLineWidth(2)
                love.graphics.polygon("line", pts)

                -- Cross reactor pipes
                love.graphics.setColor(col[1] * 1.2, col[2] * 0.8, col[3] * 1.2, 0.65)
                love.graphics.setLineWidth(1.5)
                love.graphics.line(-halfW * 0.7, -halfW * 0.7, halfW * 0.7, halfW * 0.7)
                love.graphics.line(-halfW * 0.7, halfW * 0.7, halfW * 0.7, -halfW * 0.7)

                love.graphics.pop()

                -- Bright crystal core
                love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
                love.graphics.circle("fill", cx, cy, halfW * 0.35)
            elseif enemy.type == "ranged" then
                -- 3) Sentry Node (Ranged - Green hexagon with orbiting weapon satellites)
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(game.time * 0.8)

                love.graphics.setColor(0.08, 0.16, 0.12, 0.95)
                local hexPts = {}
                for k = 1, 6 do
                    local a = (k - 1) * (math.pi / 3)
                    table.insert(hexPts, math.cos(a) * halfW * 0.95)
                    table.insert(hexPts, math.sin(a) * halfW * 0.95)
                end
                love.graphics.polygon("fill", hexPts)

                love.graphics.setColor(col[1], col[2], col[3], 0.9)
                love.graphics.setLineWidth(1.5)
                love.graphics.polygon("line", hexPts)
                love.graphics.pop()

                -- 3 Orbiting Satellites (Triangular alignment)
                local orbitR = halfW * 1.55
                local rotA = -game.time * 2.0
                for s = 1, 3 do
                    local a = rotA + (s - 1) * (2 * math.pi / 3)
                    local sx = cx + math.cos(a) * orbitR
                    local sy = cy + math.sin(a) * orbitR

                    love.graphics.push()
                    love.graphics.translate(sx, sy)
                    love.graphics.rotate(a + math.pi / 2)

                    love.graphics.setColor(col[1] * 1.2, col[2] * 1.2, col[3], 0.9)
                    love.graphics.polygon("fill", 0, -3, 3, 3, -3, 3)

                    love.graphics.pop()
                end

                -- Center core
                love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
                love.graphics.circle("fill", cx, cy, halfW * 0.25)
            else
                -- 4) Scrap Drone (Normal - Red core with rotating orbital rings)
                local pulse = 1 + math.sin(game.time * 6 + enemy.x) * 0.05

                -- Circular ring
                love.graphics.setLineWidth(1)
                love.graphics.setColor(col[1], col[2], col[3], 0.45)
                love.graphics.circle("line", cx, cy, halfW * 1.25 * pulse)

                -- Elliptic rotating ring
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(game.time * 1.8)
                love.graphics.ellipse("line", 0, 0, halfW * 1.35 * pulse, halfW * 0.5)
                love.graphics.pop()

                -- Diamond eye core
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(-game.time * 1.2)

                love.graphics.setColor(0.12, 0.12, 0.16, 0.95)
                love.graphics.polygon("fill", 0, -halfW * 0.7, halfW * 0.7, 0, 0, halfW * 0.7, -halfW * 0.7, 0)

                love.graphics.setColor(col[1], col[2], col[3], 0.9)
                love.graphics.setLineWidth(1.5)
                love.graphics.polygon("line", 0, -halfW * 0.7, halfW * 0.7, 0, 0, halfW * 0.7, -halfW * 0.7, 0)

                love.graphics.pop()

                -- Glowing eye center
                love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                love.graphics.circle("fill", cx, cy, halfW * 0.25)
            end

            -- Restore default drawing colors and thickness
            love.graphics.setColor(1.0, 1.0, 1.0)
            love.graphics.setLineWidth(1)
        end

        -- 체력이 닳았을 때만 머리 위에 체력바 표시 (보스는 제외)
        if enemy.type ~= "boss" and enemy.health and enemy.maxHealth and enemy.health < enemy.maxHealth then
            local barWidth = enemy.width
            local barHeight = 4
            local barX = enemy.x
            local barY = enemy.y - 8

            -- 체력바 배경 (어두운 회색)
            love.graphics.setColor(0.12, 0.12, 0.16, 0.8)
            love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)

            -- 체력바 전경 (체력 비율에 따라 초록색 -> 빨간색 그라데이션 시각화)
            local hpRatio = math.max(0, enemy.health / enemy.maxHealth)
            love.graphics.setColor(1.0 - hpRatio, hpRatio, 0.2)
            love.graphics.rectangle("fill", barX, barY, barWidth * hpRatio, barHeight)
        end
    end

    -- 보스 전용 불장판 그리기
    if game.bossFirePatches then
        for _, patch in ipairs(game.bossFirePatches) do
            local alpha = 0.4 * (1 - patch.timer / patch.duration)
            local pulse1 = 1 + math.sin(game.time * 8) * 0.07
            local pulse2 = 1 + math.cos(game.time * 12) * 0.09

            -- 외곽 열기 (진한 오렌지/레드)
            love.graphics.setColor(0.9, 0.25, 0.0, alpha * 0.25)
            love.graphics.circle("fill", patch.x, patch.y, patch.radius * 1.15 * pulse1)

            -- 중간 불타는 코어 (황금빛 노랑)
            love.graphics.setColor(1.0, 0.65, 0.1, alpha * 0.45)
            love.graphics.circle("fill", patch.x, patch.y, patch.radius * 0.75 * pulse2)

            -- 안쪽 중심부 (백색광)
            love.graphics.setColor(1.0, 0.9, 0.4, alpha * 0.65)
            love.graphics.circle("fill", patch.x, patch.y, patch.radius * 0.4)
        end
    end

    -- 적 탄환 투사체 그리기
    if game.enemyBullets then
        for _, bullet in ipairs(game.enemyBullets) do
            if bullet.type == "petal" then
                -- 꽃잎 투사체 그리기 (분홍/오렌지 빛나는 타원형 꽃잎 형태)
                love.graphics.push()
                love.graphics.translate(bullet.x, bullet.y)
                love.graphics.rotate(bullet.angle or 0)

                -- 외곽 아우라
                love.graphics.setColor(1.0, 0.45, 0.6, 0.25)
                love.graphics.ellipse("fill", 0, 0, bullet.size * 2.2, bullet.size * 1.3)

                -- 본체
                love.graphics.setColor(1.0, 0.25, 0.45, 0.95)
                love.graphics.ellipse("fill", 0, 0, bullet.size * 1.6, bullet.size * 0.85)

                -- 화이트/옐로우 코어 하이라이트
                love.graphics.setColor(1.0, 0.9, 0.85, 0.95)
                love.graphics.ellipse("fill", -bullet.size * 0.3, 0, bullet.size * 0.65, bullet.size * 0.3)

                love.graphics.pop()
            elseif bullet.type == "void_mine" then
                -- 보이드 지뢰 (보라색 중력 균열 리프트 연출)
                local pulse = 1 + math.sin(game.time * 15) * 0.15
                love.graphics.setColor(0.5, 0.1, 0.8, 0.2)
                love.graphics.circle("fill", bullet.x, bullet.y, bullet.size * 1.6 * pulse)

                love.graphics.setColor(0.6, 0.2, 0.9, 0.8)
                love.graphics.setLineWidth(1.5)
                love.graphics.circle("line", bullet.x, bullet.y, bullet.size * pulse)

                -- 중심 검은 코어
                love.graphics.setColor(0.05, 0.05, 0.1, 0.95)
                love.graphics.circle("fill", bullet.x, bullet.y, bullet.size * 0.45)
            elseif bullet.type == "void_bullet" then
                -- 보라색 보이드 탄환
                love.graphics.setColor(0.6, 0.1, 0.9, 0.3)
                love.graphics.circle("fill", bullet.x, bullet.y, bullet.size * 1.5)
                love.graphics.setColor(0.7, 0.2, 1.0, 0.9)
                love.graphics.circle("fill", bullet.x, bullet.y, bullet.size / 2)
                love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                love.graphics.circle("fill", bullet.x, bullet.y, bullet.size * 0.25)
            elseif bullet.type == "tesla_spark" then
                -- Homing Lightning Sparks: drawing glowing neon blue/violet stars
                local pulse = 1.0 + math.sin(game.time * 20) * 0.15
                love.graphics.setColor(0.5, 0.4, 1.0, 0.35)
                love.graphics.circle("fill", bullet.x, bullet.y, bullet.size * 2.0 * pulse)

                love.graphics.setColor(0.7, 0.6, 1.0, 0.9)
                love.graphics.circle("fill", bullet.x, bullet.y, bullet.size / 2)

                love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                love.graphics.circle("fill", bullet.x, bullet.y, bullet.size * 0.25)
            elseif bullet.type == "blade_wave" then
                -- Crescent slash blade wave drawing (mint green)
                love.graphics.push()
                love.graphics.translate(bullet.x, bullet.y)
                local angle = math.atan2(bullet.dirY, bullet.dirX)
                love.graphics.rotate(angle)

                -- Crescent arc
                love.graphics.setColor(0.25, 0.95, 0.75, 0.35)
                love.graphics.arc("fill", 0, 0, bullet.size * 2.2, -math.pi / 3, math.pi / 3)

                love.graphics.setColor(0.25, 0.95, 0.75, 0.95)
                love.graphics.setLineWidth(2.2)
                love.graphics.arc("line", 0, 0, bullet.size * 2.2, -math.pi / 3, math.pi / 3)

                -- Bright core highlight
                love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                love.graphics.circle("fill", bullet.size * 0.5, 0, bullet.size * 0.4)

                love.graphics.pop()
            elseif bullet.type == "temporal" then
                -- Emerald glowing time bullet
                local pulse = 1.0 + math.sin(game.time * 15) * 0.12
                -- Outer glow
                love.graphics.setColor(0.1, 0.9, 0.6, 0.35)
                love.graphics.circle("fill", bullet.x, bullet.y, bullet.size * 2.0 * pulse)

                -- Main body
                love.graphics.setColor(0.1, 0.9, 0.6, 0.9)
                love.graphics.circle("fill", bullet.x, bullet.y, bullet.size / 2)

                -- Bright core
                love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                love.graphics.circle("fill", bullet.x, bullet.y, bullet.size * 0.25)

                -- Collapsing ring during rewind phase
                if bullet.state == "rewind" then
                    love.graphics.setColor(0.1, 0.9, 0.6, 0.85)
                    love.graphics.setLineWidth(1.5)
                    local ringProgress = (game.time * 2.5) % 1.0
                    local ringRadius = bullet.size * 2.5 * (1.0 - ringProgress)
                    love.graphics.circle("line", bullet.x, bullet.y, ringRadius)
                end
            elseif bullet.type == "error_code" then
                -- Draw text glitch bullets (cyber green/magenta/cyan colors)
                local txt = bullet.text or "404"
                love.graphics.push()
                love.graphics.translate(bullet.x, bullet.y)

                -- Outer glitch aura
                local r, g, b = 0.9, 0.1, 0.4 -- Magenta
                if bullet.colorIndex == 1 then
                    r, g, b = 0.1, 0.9, 0.9   -- Cyan
                elseif bullet.colorIndex == 2 then
                    r, g, b = 0.9, 0.9, 0.1   -- Yellow/Green
                end

                local jx = math.random(-2, 2)
                local jy = math.random(-2, 2)

                love.graphics.setColor(r, g, b, 0.35)
                love.graphics.print(txt, -15 + jx, -6 + jy)

                -- Main text
                love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
                love.graphics.print(txt, -15, -6)
                love.graphics.pop()
            else
                -- 일반 붉은색 탄환
                love.graphics.setColor(0.9, 0.1, 0.1, 0.3)
                love.graphics.circle("fill", bullet.x, bullet.y, bullet.size * 1.5)
                love.graphics.setColor(1.0, 0.3, 0.3)
                love.graphics.circle("fill", bullet.x, bullet.y, bullet.size / 2)
                love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
                love.graphics.circle("fill", bullet.x, bullet.y, bullet.size * 0.2)
            end
        end
    end
end

return Enemy
