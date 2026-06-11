-- ============================================================================
-- spawner.lua — 적 스폰, 이동 AI, 피격 충돌 감지 및 처리 모듈
-- ============================================================================

local Collision = require("combat.collision")

local function checkLineCircleCollision(ax, ay, bx, by, cx, cy, r)
    local abx = bx - ax
    local aby = by - ay
    local acx = cx - ax
    local acy = cy - ay
    
    local ab_len_sq = abx * abx + aby * aby
    if ab_len_sq == 0 then
        local dx = cx - ax
        local dy = cy - ay
        return math.sqrt(dx * dx + dy * dy) < r
    end
    
    local t = (acx * abx + acy * aby) / ab_len_sq
    t = math.max(0, math.min(1, t))
    
    local closestX = ax + t * abx
    local closestY = ay + t * aby
    
    local dx = cx - closestX
    local dy = cy - closestY
    return math.sqrt(dx * dx + dy * dy) < r
end

local function drawLightningBeam(x1, y1, x2, y2, segments, displacement)
    local dx = x2 - x1
    local dy = y2 - y1
    local totalDist = math.sqrt(dx * dx + dy * dy)
    if totalDist == 0 then return end
    local dirX, dirY = dx / totalDist, dy / totalDist
    local perpX, perpY = -dirY, dirX
    
    local pts = {x1, y1}
    for k = 1, segments - 1 do
        local ratio = k / segments
        local baseX = x1 + dx * ratio
        local baseY = y1 + dy * ratio
        local disp = (math.random() - 0.5) * displacement
        table.insert(pts, baseX + perpX * disp)
        table.insert(pts, baseY + perpY * disp)
    end
    table.insert(pts, x2)
    table.insert(pts, y2)
    
    love.graphics.line(pts)
end

local Enemy = {}

-- 적에게 피해를 입히고 체력이 0 이하가 되면 처치 및 경험치 구슬 생성 처리
function Enemy.damage(game, index, damage)
    local enemy = game.enemies[index]
    if not enemy then return false end

    if enemy.type == "boss" and enemy.bossState == "exhausted" then
        damage = damage * 2
    elseif enemy.type == "boss" and enemy.bossState == "recharging" then
        damage = damage * 1.5
    end

    enemy.health = enemy.health - damage
    if enemy.health <= 0 then
        game.score = game.score + (enemy.points or 10)
        local Exp = require("progression.exp")
        Exp.spawn(game, enemy.x + enemy.width / 2, enemy.y + enemy.height / 2)
        table.remove(game.enemies, index)
        return true
    end
    return false
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
    if wave == 7 then
        local currentStage = game.stage or 1
        local bossName = "Void Overlord"
        local bossColor = { 0.6, 0.1, 0.9 } -- 보라
        local bossSize = 64
        local bossSpeed = 60
        local baseHealth = 12000 -- 1스테이지 보스 기본 체력
        local pointsVal = 500

        if currentStage == 2 then
            bossName = "Infernus Leviathan"
            bossColor = { 1.0, 0.2, 0.1 } -- 강렬한 빨강/주황
            bossSize = 80
            bossSpeed = 70
            baseHealth = 20000 -- 2스테이지 보스 기본 체력
            pointsVal = 1000
        elseif currentStage == 3 then
            bossName = "Phantom Stalker"
            bossColor = { 0.25, 0.95, 0.75 } -- 네온 사이언/민트
            bossSize = 60
            bossSpeed = 110
            baseHealth = 32000 -- 3스테이지 보스 기본 체력
            pointsVal = 2000
        elseif currentStage == 4 then
            bossName = "Tesla Archon"
            bossColor = { 0.5, 0.4, 1.0 } -- 전자기 바이올렛/블루
            bossSize = 70
            bossSpeed = 55 -- 느리지만 자기 인력을 씀
            baseHealth = 48000 -- 4스테이지 보스 기본 체력
            pointsVal = 3000
        elseif currentStage == 5 then
            bossName = "Orbital Aegis"
            bossColor = { 1.0, 0.8, 0.1 } -- Golden Yellow
            bossSize = 80
            bossSpeed = 40
            baseHealth = 72000
            pointsVal = 4000
        elseif currentStage >= 6 then
            bossName = "Chronos Weaver"
            bossColor = { 0.1, 0.9, 0.6 } -- 시간의 균열 에메랄드/그린
            bossSize = 75
            bossSpeed = 50
            baseHealth = 100000 -- 6스테이지 보스 기본 체력
            pointsVal = 5000
        end

        -- 보스 스폰 (플레이어 주변 화면 밖 450px 정도 위치에 스폰)
        local angle = math.random() * 2 * math.pi
        local spawnDist = 450
        local ex = player.x + player.width / 2 + math.cos(angle) * spawnDist - bossSize / 2
        local ey = player.y + player.height / 2 + math.sin(angle) * spawnDist - bossSize / 2

        -- 보스가 월드 경계 밖으로 나가지 않도록 킵
        ex = math.max(100, math.min(game.world.width - 200, ex))
        ey = math.max(100, math.min(game.world.height - 200, ey))

        local bBurstTimer = 5.0
        local bPetalTimer = nil
        local bRushTimer = 8.0
        local patternTimer = nil
        local nextPattern = nil
        if currentStage == 2 then
            bPetalTimer = 6.0
            bRushTimer = 9.0
        elseif currentStage == 3 then
            bBurstTimer = nil
            bRushTimer = nil
            patternTimer = 3.5
            nextPattern = "dash"
        elseif currentStage == 4 then
            bBurstTimer = nil
            bRushTimer = nil
            patternTimer = 4.0
            nextPattern = "pylons"
        elseif currentStage == 5 then
            bBurstTimer = nil
            bRushTimer = nil
            patternTimer = 5.0
            nextPattern = "laser_grid"
        elseif currentStage >= 6 then
            bBurstTimer = nil
            bRushTimer = nil
            patternTimer = 6.0
            nextPattern = "time_burst"
        end

        local boss = {
            x = ex,
            y = ey,
            width = bossSize,
            height = bossSize,
            speed = bossSpeed,
            health = baseHealth * stageMultiplier,
            maxHealth = baseHealth * stageMultiplier,
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
            laserAngle = 0
        }
        table.insert(game.enemies, boss)
        game.bossActive = true
        game.bossMinionTimer = 0

        if currentStage == 5 then
            for i = 1, 4 do
                local angle = (i - 1) * (math.pi / 2)
                local bCenterX = ex + bossSize / 2
                local bCenterY = ey + bossSize / 2
                local sx = bCenterX + math.cos(angle) * 120 - 12
                local sy = bCenterY + math.sin(angle) * 120 - 12
                table.insert(game.enemies, {
                    x = sx,
                    y = sy,
                    width = 24,
                    height = 24,
                    speed = 0,
                    health = 1500 * stageMultiplier,
                    maxHealth = 1500 * stageMultiplier,
                    type = "aegis_shield",
                    color = { 1.0, 0.8, 0.1 },
                    points = 150,
                    velX = 0,
                    velY = 0,
                    shieldIndex = i
                })
            end
        end

        -- 초기 잡몹 4마리 같이 스폰
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

        -- 보스전 중앙 안내 배너 설정
        game.bannerText = "BOSS WAVE START"
        game.bannerTimer = 3.0
    else
        local enemyCount = math.floor(20 * (1.2 ^ (wave - 1))) -- 첫 웨이브 20마리 시작, 매 웨이브 1.2배 복리 증가
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

    -- Reset temporary speed debuffs
    player.speedMultiplier = 1.0

    -- 웨이브 전환 상태 관리
    if game.waveState == "playing" then
        if game.wave == 7 then
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

                game.waveState = "stage_cleared"
                game.waveTransitionTimer = 4.0
                game.bannerText = "STAGE " .. (game.stage or 1) .. " CLEAR!"
                game.bannerTimer = 4.0
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
    if game.wave == 7 and game.waveState == "playing" and game.bossActive then
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

    -- 적 이동 및 충돌
    for i = #game.enemies, 1, -1 do
        local enemy = game.enemies[i]

        -- 커터 피격 쿨다운 차감
        if enemy.cutterHitCooldown and enemy.cutterHitCooldown > 0 then
            enemy.cutterHitCooldown = enemy.cutterHitCooldown - dt
        end

        -- 플레이어 추적 및 뭉침 방지 (Separation)
        local isRooted = (enemy.rootedTimer and enemy.rootedTimer > 0)
        if isRooted then
            enemy.rootedTimer = enemy.rootedTimer - dt
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
            local currentStage = game.stage or 1
            enemy.bossState = enemy.bossState or "normal"
            enemy.stateTimer = enemy.stateTimer or 0
            enemy.trailHistory = enemy.trailHistory or {}

            if currentStage == 1 then
                -- ==========================================
                -- BOSS 1 (Void Overlord)
                -- ==========================================
                enemy.burstTimer = enemy.burstTimer or 5.0
                enemy.rushTimer = enemy.rushTimer or 8.0

                if enemy.bossState == "normal" then
                    enemy.burstTimer = enemy.burstTimer - dt
                    enemy.rushTimer = enemy.rushTimer - dt

                    if enemy.rushTimer <= 0 then
                        enemy.bossState = "charging_teleport"
                        enemy.stateTimer = 0.8
                        enemy.teleportCount = 0
                    elseif enemy.burstTimer <= 0 then
                        enemy.bossState = "charging_burst"
                        enemy.stateTimer = 0.8
                    end

                    -- Chase player
                    if dist > 0 then
                        targetVelX = (dx / dist) * enemy.speed
                        targetVelY = (dy / dist) * enemy.speed
                    end
                    if #enemy.trailHistory > 0 then enemy.trailHistory = {} end
                elseif enemy.bossState == "charging_burst" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "spiral_burst"
                        enemy.stateTimer = 1.5 -- 1.5 seconds of spiral firing
                        enemy.spiralAngle = 0
                        enemy.fireTimer = 0
                    end
                elseif enemy.bossState == "spiral_burst" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0

                    enemy.fireTimer = (enemy.fireTimer or 0) + dt
                    if enemy.fireTimer >= 0.08 then
                        enemy.fireTimer = 0
                        enemy.spiralAngle = (enemy.spiralAngle or 0) + 0.25
                        local bCenterX = enemy.x + enemy.width / 2
                        local bCenterY = enemy.y + enemy.height / 2
                        local bulletSpeed = 160

                        -- Fire in 2 opposite directions
                        for k = 0, 1 do
                            local angle = enemy.spiralAngle + k * math.pi
                            table.insert(game.enemyBullets, {
                                x = bCenterX,
                                y = bCenterY,
                                dirX = math.cos(angle),
                                dirY = math.sin(angle),
                                speed = bulletSpeed,
                                damage = 14,
                                size = 8,
                                maxDist = 600,
                                distTraveled = 0,
                                type = "void_bullet"
                            })
                        end
                    end

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "normal"
                        enemy.burstTimer = 5.0
                    end
                elseif enemy.bossState == "charging_teleport" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    if enemy.stateTimer <= 0 then
                        -- Teleport close to player
                        local pCenterX = player.x + player.width / 2
                        local pCenterY = player.y + player.height / 2
                        local teleAngle = math.random() * 2 * math.pi
                        local teleDist = 240
                        
                        enemy.x = pCenterX + math.cos(teleAngle) * teleDist - enemy.width / 2
                        enemy.y = pCenterY + math.sin(teleAngle) * teleDist - enemy.height / 2
                        
                        -- Keep inside world
                        enemy.x = math.max(50, math.min(game.world.width - enemy.width - 50, enemy.x))
                        enemy.y = math.max(50, math.min(game.world.height - enemy.height - 50, enemy.y))

                        -- Shoot 16-way radial void bullets instantly
                        local bCenterX = enemy.x + enemy.width / 2
                        local bCenterY = enemy.y + enemy.height / 2
                        for k = 1, 16 do
                            local angle = (k - 1) * (2 * math.pi / 16)
                            table.insert(game.enemyBullets, {
                                x = bCenterX,
                                y = bCenterY,
                                dirX = math.cos(angle),
                                dirY = math.sin(angle),
                                speed = 180,
                                damage = 14,
                                size = 8,
                                maxDist = 550,
                                distTraveled = 0,
                                type = "void_bullet"
                            })
                        end

                        enemy.bossState = "teleport_firing"
                        enemy.stateTimer = 0.4
                    end
                elseif enemy.bossState == "teleport_firing" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    if enemy.stateTimer <= 0 then
                        enemy.teleportCount = (enemy.teleportCount or 0) + 1
                        if enemy.teleportCount < 2 then
                            enemy.bossState = "charging_teleport"
                            enemy.stateTimer = 0.5
                        else
                            enemy.bossState = "normal"
                            enemy.rushTimer = 7.0
                            enemy.teleportCount = 0
                        end
                    end
                end
            elseif currentStage == 2 then
                -- ==========================================
                -- BOSS 2 (Infernus Leviathan / Petal Boss)
                -- ==========================================
                enemy.petalTimer = enemy.petalTimer or 6.0
                enemy.rushTimer = enemy.rushTimer or 9.0

                if enemy.bossState == "normal" then
                    enemy.petalTimer = enemy.petalTimer - dt
                    enemy.rushTimer = enemy.rushTimer - dt

                    if enemy.rushTimer <= 0 then
                        enemy.bossState = "charging_geyser"
                        enemy.stateTimer = 2.5
                        enemy.geyserCount = 0
                        enemy.geyserSpawnTimer = 0.0
                    elseif enemy.petalTimer <= 0 then
                        enemy.bossState = "charging_petal"
                        enemy.stateTimer = 0.8
                    end

                    -- Chase player
                    if dist > 0 then
                        targetVelX = (dx / dist) * enemy.speed
                        targetVelY = (dy / dist) * enemy.speed
                    end
                    if #enemy.trailHistory > 0 then enemy.trailHistory = {} end
                elseif enemy.bossState == "charging_petal" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "petalling"
                        enemy.stateTimer = 2.0 -- 2 seconds of petal blizzard
                        enemy.fireTimer = 0
                    end
                elseif enemy.bossState == "petalling" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0

                    enemy.fireTimer = (enemy.fireTimer or 0) + dt
                    if enemy.fireTimer >= 0.12 then
                        enemy.fireTimer = 0
                        local bCenterX = enemy.x + enemy.width / 2
                        local bCenterY = enemy.y + enemy.height / 2

                        -- Target direction to player
                        local pCenterX, pCenterY = player.x + player.width / 2, player.y + player.height / 2
                        local pAngle = math.atan2(pCenterY - bCenterY, pCenterX - bCenterX)

                        -- Sweep fan wave of 5 petals
                        local sweepAngle = math.sin(game.time * 6) * 0.8
                        local centerAngle = pAngle + sweepAngle
                        local petalCount = 5
                        local bulletSpeed = 150

                        for k = 1, petalCount do
                            local offset = (k - (petalCount + 1) / 2) * 0.22 -- spacing
                            local angle = centerAngle + offset
                            table.insert(game.enemyBullets, {
                                x = bCenterX,
                                y = bCenterY,
                                dirX = math.cos(angle),
                                dirY = math.sin(angle),
                                speed = bulletSpeed,
                                damage = 16,
                                size = 7,
                                maxDist = 550,
                                distTraveled = 0,
                                type = "petal",
                                angle = angle
                            })
                        end
                    end

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "normal"
                        enemy.petalTimer = 6.0
                    end
                elseif enemy.bossState == "charging_geyser" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    enemy.geyserSpawnTimer = (enemy.geyserSpawnTimer or 0) - dt
                    if enemy.geyserSpawnTimer <= 0 and enemy.geyserCount < 3 then
                        local pCenterX = player.x + player.width / 2
                        local pCenterY = player.y + player.height / 2
                        game.pendingGeysers = game.pendingGeysers or {}
                        table.insert(game.pendingGeysers, { x = pCenterX, y = pCenterY, timer = 0.7 })
                        enemy.geyserCount = enemy.geyserCount + 1
                        enemy.geyserSpawnTimer = 0.7
                    end

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "normal"
                        enemy.rushTimer = 9.0
                    end
                end
            elseif currentStage == 3 then
                -- ==========================================
                -- BOSS 3 (Phantom Stalker)
                -- ==========================================
                local stageMultiplier = 1.0 + ((game.stage or 1) - 1) * 0.5
                enemy.patternTimer = enemy.patternTimer or 3.5
                enemy.nextPattern = enemy.nextPattern or "dash"

                if enemy.bossState == "normal" then
                    enemy.patternTimer = enemy.patternTimer - dt
                    if enemy.patternTimer <= 0 then
                        if enemy.nextPattern == "dash" then
                            enemy.bossState = "charging_dash"
                            enemy.stateTimer = 0.8
                            enemy.dashCount = 0
                            -- Aim at player
                            local pCenterX, pCenterY = player.x + player.width / 2, player.y + player.height / 2
                            local bCenterX, bCenterY = enemy.x + enemy.width / 2, enemy.y + enemy.height / 2
                            local ldx, ldy = pCenterX - bCenterX, pCenterY - bCenterY
                            local ldist = math.sqrt(ldx * ldx + ldy * ldy)
                            if ldist > 0 then
                                enemy.rushDirX, enemy.rushDirY = ldx / ldist, ldy / ldist
                            else
                                enemy.rushDirX, enemy.rushDirY = 1, 0
                            end
                        elseif enemy.nextPattern == "summon" then
                            enemy.bossState = "summoning"
                            enemy.stateTimer = 1.0

                            -- Spawn 3 phantom clones radially
                            local bCenterX = enemy.x + enemy.width / 2
                            local bCenterY = enemy.y + enemy.height / 2
                            local numClones = 3
                            local spawnRadius = 100
                            for c = 1, numClones do
                                local angle = (c - 1) * (2 * math.pi / numClones) + math.random() * 0.5
                                local cx = bCenterX + math.cos(angle) * spawnRadius - 20
                                local cy = bCenterY + math.sin(angle) * spawnRadius - 20
                                cx = math.max(10, math.min(game.world.width - 50, cx))
                                cy = math.max(10, math.min(game.world.height - 50, cy))
                                table.insert(game.enemies, {
                                    x = cx,
                                    y = cy,
                                    width = 40,
                                    height = 40,
                                    speed = 150,
                                    health = 250 * stageMultiplier,
                                    maxHealth = 250 * stageMultiplier,
                                    type = "boss_clone",
                                    color = { 0.25, 0.95, 0.75 },
                                    points = 50,
                                    velX = 0,
                                    velY = 0
                                })
                            end
                        elseif enemy.nextPattern == "crossfire" then
                            enemy.bossState = "charging_crossfire"
                            enemy.stateTimer = 1.0
                            
                            -- Position main boss and all alive clones in 4 quadrants around player
                            local pCenterX = player.x + player.width / 2
                            local pCenterY = player.y + player.height / 2
                            local group = { enemy }
                            for _, other in ipairs(game.enemies) do
                                if other.type == "boss_clone" then
                                    table.insert(group, other)
                                end
                            end
                            local angles = { math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4 }
                            local radius = 240
                            for idx, member in ipairs(group) do
                                local angle = angles[((idx - 1) % 4) + 1]
                                member.x = pCenterX + math.cos(angle) * radius - member.width / 2
                                member.y = pCenterY + math.sin(angle) * radius - member.height / 2
                                member.x = math.max(20, math.min(game.world.width - member.width - 20, member.x))
                                member.y = math.max(20, math.min(game.world.height - member.height - 20, member.y))
                                member.velX = 0
                                member.velY = 0
                                
                                local mCenterX = member.x + member.width / 2
                                local mCenterY = member.y + member.height / 2
                                local mdx = pCenterX - mCenterX
                                local mdy = pCenterY - mCenterY
                                local mdist = math.sqrt(mdx * mdx + mdy * mdy)
                                if mdist > 0 then
                                    member.rushDirX = mdx / mdist
                                    member.rushDirY = mdy / mdist
                                end
                                if member.type == "boss_clone" then
                                    member.bossState = "charging_crossfire"
                                    member.stateTimer = 1.0
                                end
                            end
                        end
                    end

                    -- Move towards player
                    if dist > 0 then
                        targetVelX = (dx / dist) * enemy.speed
                        targetVelY = (dy / dist) * enemy.speed
                    end
                    if #enemy.trailHistory > 0 then enemy.trailHistory = {} end

                elseif enemy.bossState == "charging_dash" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    -- Continuously aim at player during charge
                    local pCenterX, pCenterY = player.x + player.width / 2, player.y + player.height / 2
                    local bCenterX, bCenterY = enemy.x + enemy.width / 2, enemy.y + enemy.height / 2
                    local ldx, ldy = pCenterX - bCenterX, pCenterY - bCenterY
                    local ldist = math.sqrt(ldx * ldx + ldy * ldy)
                    if ldist > 0 then
                        enemy.rushDirX, enemy.rushDirY = ldx / ldist, ldy / ldist
                    end

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "dashing"
                        enemy.stateTimer = 0.8
                        -- Start dash instantly to avoid delay
                        enemy.velX = enemy.rushDirX * 1200
                        enemy.velY = enemy.rushDirY * 1200
                    end

                elseif enemy.bossState == "dashing" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX = enemy.rushDirX * 1200
                    targetVelY = enemy.rushDirY * 1200

                    -- Record trail
                    enemy.trailTimer = (enemy.trailTimer or 0) + dt
                    if enemy.trailTimer >= 0.04 then
                        enemy.trailTimer = 0
                        table.insert(enemy.trailHistory, 1, { x = enemy.x, y = enemy.y })
                        if #enemy.trailHistory > 5 then table.remove(enemy.trailHistory) end
                    end

                    if enemy.stateTimer <= 0 then
                        enemy.dashCount = enemy.dashCount + 1
                        if enemy.dashCount < 3 then
                            -- Next consecutive dash
                            enemy.bossState = "charging_dash"
                            enemy.stateTimer = 0.5 -- slightly faster charge for subsequent dashes
                            
                            -- Face player
                            local pCenterX, pCenterY = player.x + player.width / 2, player.y + player.height / 2
                            local bCenterX, bCenterY = enemy.x + enemy.width / 2, enemy.y + enemy.height / 2
                            local ldx, ldy = pCenterX - bCenterX, pCenterY - bCenterY
                            local ldist = math.sqrt(ldx * ldx + ldy * ldy)
                            if ldist > 0 then
                                enemy.rushDirX, enemy.rushDirY = ldx / ldist, ldy / ldist
                            end
                        else
                            -- Done with 3 dashes, enter exhausted state
                            enemy.bossState = "exhausted"
                            enemy.stateTimer = 2.5
                        end
                    end

                elseif enemy.bossState == "exhausted" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0
                    if #enemy.trailHistory > 0 then enemy.trailHistory = {} end

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "normal"
                        enemy.patternTimer = 3.5
                        enemy.nextPattern = "summon"
                    end

                elseif enemy.bossState == "summoning" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0
                    if #enemy.trailHistory > 0 then enemy.trailHistory = {} end

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "normal"
                        enemy.patternTimer = 3.5
                        enemy.nextPattern = "crossfire"
                    end

                elseif enemy.bossState == "charging_crossfire" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    local pCenterX = player.x + player.width / 2
                    local pCenterY = player.y + player.height / 2

                    -- Maintain locking onto player
                    local bCenterX = enemy.x + enemy.width / 2
                    local bCenterY = enemy.y + enemy.height / 2
                    local bdx = pCenterX - bCenterX
                    local bdy = pCenterY - bCenterY
                    local bdist = math.sqrt(bdx * bdx + bdy * bdy)
                    if bdist > 0 then
                        enemy.rushDirX = bdx / bdist
                        enemy.rushDirY = bdy / bdist
                    end

                    for _, other in ipairs(game.enemies) do
                        if other.type == "boss_clone" then
                            other.bossState = "charging_crossfire"
                            other.stateTimer = enemy.stateTimer
                            local oCenterX = other.x + other.width / 2
                            local oCenterY = other.y + other.height / 2
                            local odx = pCenterX - oCenterX
                            local ody = pCenterY - oCenterY
                            local odist = math.sqrt(odx * odx + ody * ody)
                            if odist > 0 then
                                other.rushDirX = odx / odist
                                other.rushDirY = ody / odist
                            end
                        end
                    end

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "crossfire_firing"
                        enemy.stateTimer = 0.4

                        local shootBlade = function(member)
                            local mCenterX = member.x + member.width / 2
                            local mCenterY = member.y + member.height / 2
                            game.enemyBullets = game.enemyBullets or {}
                            table.insert(game.enemyBullets, {
                                x = mCenterX,
                                y = mCenterY,
                                dirX = member.rushDirX or 1,
                                dirY = member.rushDirY or 0,
                                speed = 420,
                                damage = 18,
                                size = 10,
                                maxDist = 750,
                                distTraveled = 0,
                                type = "blade_wave"
                            })
                        end

                        shootBlade(enemy)
                        for _, other in ipairs(game.enemies) do
                            if other.type == "boss_clone" then
                                shootBlade(other)
                                other.bossState = "normal"
                            end
                        end
                    end

                elseif enemy.bossState == "crossfire_firing" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "normal"
                        enemy.patternTimer = 3.5
                        enemy.nextPattern = "dash"
                    end
                end
            elseif currentStage == 4 then
                -- ==========================================
                -- BOSS 4 (Tesla Archon)
                -- ==========================================
                local stageMultiplier = 1.0 + ((game.stage or 1) - 1) * 0.5
                enemy.patternTimer = enemy.patternTimer or 4.0
                enemy.nextPattern = enemy.nextPattern or "pylons"

                if enemy.bossState == "normal" then
                    enemy.patternTimer = enemy.patternTimer - dt
                    if enemy.patternTimer <= 0 then
                        if enemy.nextPattern == "pylons" then
                            enemy.bossState = "tesla_pylons"
                            enemy.stateTimer = 1.2
                        elseif enemy.nextPattern == "magnetic_pull" then
                            enemy.bossState = "magnetic_pull"
                            enemy.stateTimer = 3.5
                        elseif enemy.nextPattern == "volt_discharge" then
                            enemy.bossState = "volt_discharge"
                            enemy.stateTimer = 1.0
                        elseif enemy.nextPattern == "emp_storm" then
                            enemy.bossState = "emp_storm"
                            enemy.stateTimer = 3.0
                            enemy.fireTimer = 0
                            enemy.empAngle = 0
                        end
                    end

                    -- Move towards player
                    if dist > 0 then
                        targetVelX = (dx / dist) * enemy.speed
                        targetVelY = (dy / dist) * enemy.speed
                    end

                elseif enemy.bossState == "tesla_pylons" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    if enemy.stateTimer <= 0 then
                        -- Spawn two pylons
                        local bCenterX = enemy.x + enemy.width / 2
                        local bCenterY = enemy.y + enemy.height / 2
                        local angle = math.random() * 2 * math.pi
                        local spawnDist = 220
                        for pIdx = 1, 2 do
                            local pAngle = angle + (pIdx - 1) * math.pi + (math.random() - 0.5) * 0.3
                            local px = bCenterX + math.cos(pAngle) * spawnDist - 12
                            local py = bCenterY + math.sin(pAngle) * spawnDist - 12
                            px = math.max(10, math.min(game.world.width - 34, px))
                            py = math.max(10, math.min(game.world.height - 34, py))
                            table.insert(game.enemies, {
                                x = px,
                                y = py,
                                width = 24,
                                height = 24,
                                speed = 0,
                                health = 800 * stageMultiplier,
                                maxHealth = 800 * stageMultiplier,
                                type = "tesla_pylon",
                                color = { 0.6, 0.5, 1.0 },
                                points = 100,
                                velX = 0,
                                velY = 0,
                                pylonIndex = pIdx
                            })
                        end
                        enemy.bossState = "tesla_pylons_active"
                        enemy.pylonAngle = angle
                    end

                elseif enemy.bossState == "tesla_pylons_active" then
                    -- Count active pylons
                    local activePylons = 0
                    for _, other in ipairs(game.enemies) do
                        if other.type == "tesla_pylon" then
                            activePylons = activePylons + 1
                        end
                    end

                    if activePylons == 0 then
                        enemy.bossState = "normal"
                        enemy.patternTimer = 4.0
                        enemy.nextPattern = "magnetic_pull"
                    else
                        -- Move very slowly towards player
                        if dist > 0 then
                            targetVelX = (dx / dist) * 35
                            targetVelY = (dy / dist) * 35
                        end

                        -- Orbiting pylons around the boss (1.5 rad/s rotation speed, distance oscillating between 180 and 260px)
                        enemy.pylonAngle = (enemy.pylonAngle or 0) + 1.5 * dt
                        local bCenterX = enemy.x + enemy.width / 2
                        local bCenterY = enemy.y + enemy.height / 2
                        for _, other in ipairs(game.enemies) do
                            if other.type == "tesla_pylon" then
                                local pIdx = other.pylonIndex or 1
                                local angle = enemy.pylonAngle + (pIdx - 1) * math.pi
                                local orbitDist = 220 + math.sin(game.time * 3.5) * 45
                                other.x = bCenterX + math.cos(angle) * orbitDist - other.width / 2
                                other.y = bCenterY + math.sin(angle) * orbitDist - other.height / 2
                                -- Clamp position inside world
                                other.x = math.max(10, math.min(game.world.width - other.width - 10, other.x))
                                other.y = math.max(10, math.min(game.world.height - other.height - 10, other.y))
                            end
                        end

                        -- Check collision with electric fences
                        if player.invincibleTime <= 0 then
                            local pCenterX = player.x + player.width / 2
                            local pCenterY = player.y + player.height / 2
                            
                            for _, other in ipairs(game.enemies) do
                                if other.type == "tesla_pylon" then
                                    local pyCenterX = other.x + other.width / 2
                                    local pyCenterY = other.y + other.height / 2
                                    if checkLineCircleCollision(bCenterX, bCenterY, pyCenterX, pyCenterY, pCenterX, pCenterY, player.width / 2 + 6) then
                                        player.health = player.health - 6 -- 6 damage
                                        player.invincibleTime = player.maxInvincibleTime
                                        player.regenTimer = 0
                                        game.pendingThornsAttackers = game.pendingThornsAttackers or {}
                                        table.insert(game.pendingThornsAttackers, "none")
                                        if player.health <= 0 then
                                            game.running = false
                                            game.state = "gameover"
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end

                elseif enemy.bossState == "magnetic_pull" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    -- Pull player (expanded magnetic range to 550px, pull force to 180)
                    local pCenterX = player.x + player.width / 2
                    local pCenterY = player.y + player.height / 2
                    local bCenterX = enemy.x + enemy.width / 2
                    local bCenterY = enemy.y + enemy.height / 2
                    local pdx = bCenterX - pCenterX
                    local pdy = bCenterY - pCenterY
                    local pdist = math.sqrt(pdx * pdx + pdy * pdy)
                    
                    local magneticRadius = 550
                    if pdist < magneticRadius and pdist > 20 then
                        local pullForce = 180
                        player.x = player.x + (pdx / pdist) * pullForce * dt
                        player.y = player.y + (pdy / pdist) * pullForce * dt
                    end

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "normal"
                        enemy.patternTimer = 4.0
                        enemy.nextPattern = "volt_discharge"
                    end

                elseif enemy.bossState == "volt_discharge" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    if enemy.stateTimer <= 0 then
                        -- Discharge 3 homing lightning sparks
                        local bCenterX = enemy.x + enemy.width / 2
                        local bCenterY = enemy.y + enemy.height / 2
                        local bdx = player.x + player.width / 2 - bCenterX
                        local bdy = player.y + player.height / 2 - bCenterY
                        local bdist = math.sqrt(bdx * bdx + bdy * bdy)
                        if bdist > 0 then
                            game.enemyBullets = game.enemyBullets or {}
                            local baseAngle = math.atan2(bdy, bdx)
                            for angleOffset = -0.25, 0.25, 0.25 do
                                relativeAngle = baseAngle + angleOffset
                                table.insert(game.enemyBullets, {
                                    x = bCenterX,
                                    y = bCenterY,
                                    dirX = math.cos(relativeAngle),
                                    dirY = math.sin(relativeAngle),
                                    speed = 220,
                                    damage = 18,
                                    size = 8,
                                    maxDist = 650,
                                    distTraveled = 0,
                                    type = "tesla_spark"
                                })
                            end
                        end
                        enemy.bossState = "normal"
                        enemy.patternTimer = 4.0
                        enemy.nextPattern = "emp_storm"
                    end

                elseif enemy.bossState == "emp_storm" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    -- Set speedMultiplier to slow player down by 40% (multiplier = 0.6)
                    player.speedMultiplier = 0.6

                    -- Double spiral bolt firing: 24 bullets total over 3.0 seconds (0.25s interval, 2 bullets per tick)
                    enemy.fireTimer = (enemy.fireTimer or 0) + dt
                    if enemy.fireTimer >= 0.25 then
                        enemy.fireTimer = 0
                        enemy.empAngle = (enemy.empAngle or 0) + 0.523 -- approx 30 degrees rotation
                        local bCenterX = enemy.x + enemy.width / 2
                        local bCenterY = enemy.y + enemy.height / 2
                        for k = 0, 1 do
                            local angle = enemy.empAngle + k * math.pi
                            table.insert(game.enemyBullets, {
                                x = bCenterX,
                                y = bCenterY,
                                dirX = math.cos(angle),
                                dirY = math.sin(angle),
                                speed = 180,
                                damage = 15,
                                size = 8,
                                maxDist = 600,
                                distTraveled = 0,
                                type = "tesla_spark"
                            })
                        end
                    end

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "normal"
                        enemy.patternTimer = 4.0
                        enemy.nextPattern = "pylons"
                    end
                end
            elseif currentStage == 5 then
                -- ==========================================
                -- BOSS 5 (Orbital Aegis)
                -- ==========================================
                local stageMultiplier = 1.0 + ((game.stage or 1) - 1) * 0.5
                enemy.patternTimer = enemy.patternTimer or 5.0
                enemy.nextPattern = enemy.nextPattern or "laser_grid"
                enemy.shieldAngle = (enemy.shieldAngle or 0) + 0.9 * dt
                enemy.laserAngle = enemy.laserAngle or 0

                -- Calculate center of the boss
                local bCenterX = enemy.x + enemy.width / 2
                local bCenterY = enemy.y + enemy.height / 2

                -- Count active shields
                local activeShields = 0
                for _, other in ipairs(game.enemies) do
                    if other.type == "aegis_shield" then
                        activeShields = activeShields + 1
                    end
                end

                -- Transition immediately to recharging if all shields are destroyed and we are not recharging
                if activeShields == 0 and enemy.bossState ~= "recharging" then
                    enemy.bossState = "recharging"
                    enemy.stateTimer = 3.0
                    enemy.speed = 0
                end

                if enemy.bossState == "normal" then
                    enemy.patternTimer = enemy.patternTimer - dt
                    if enemy.patternTimer <= 0 then
                        if enemy.nextPattern == "laser_grid" then
                            enemy.bossState = "laser_grid"
                            enemy.stateTimer = 6.0
                        else
                            enemy.bossState = "orbital_strike"
                            enemy.stateTimer = 2.7
                            enemy.strikeTargetX = player.x + player.width / 2
                            enemy.strikeTargetY = player.y + player.height / 2
                            enemy.strikeLockTimer = 1.5
                            enemy.strikeDamageTimer = 0
                        end
                    end

                    -- Chase player
                    if dist > 0 then
                        targetVelX = (dx / dist) * enemy.speed
                        targetVelY = (dy / dist) * enemy.speed
                    end

                elseif enemy.bossState == "laser_grid" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    enemy.laserAngle = enemy.laserAngle + 0.5 * dt

                    -- Move slowly (speed = 25)
                    local gridSpeed = 25
                    if dist > 0 then
                        targetVelX = (dx / dist) * gridSpeed
                        targetVelY = (dy / dist) * gridSpeed
                    end

                    -- Check line-circle collision for all 4 rotating laser lines of length 800px
                    if player.invincibleTime <= 0 then
                        local pCenterX = player.x + player.width / 2
                        local pCenterY = player.y + player.height / 2
                        local hit = false
                        for i = 1, 4 do
                            local angle = enemy.laserAngle + (i - 1) * (math.pi / 2)
                            local lx2 = bCenterX + math.cos(angle) * 800
                            local ly2 = bCenterY + math.sin(angle) * 800
                            if checkLineCircleCollision(bCenterX, bCenterY, lx2, ly2, pCenterX, pCenterY, player.width / 2 + 4) then
                                hit = true
                                break
                            end
                        end
                        if hit then
                            player.health = player.health - 10 -- 10 damage
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

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "normal"
                        enemy.patternTimer = 5.0
                        enemy.nextPattern = "orbital_strike"
                    end

                elseif enemy.bossState == "orbital_strike" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    enemy.strikeLockTimer = (enemy.strikeLockTimer or 1.5) - dt
                    if enemy.strikeLockTimer > 0 then
                        enemy.strikeTargetX = player.x + player.width / 2
                        enemy.strikeTargetY = player.y + player.height / 2
                    else
                        -- Fusion beam damage tick: 0.15s interval, 4 damage
                        enemy.strikeDamageTimer = (enemy.strikeDamageTimer or 0) - dt
                        if enemy.strikeDamageTimer <= 0 then
                            enemy.strikeDamageTimer = 0.15
                            local pCenterX = player.x + player.width / 2
                            local pCenterY = player.y + player.height / 2
                            local pdx = pCenterX - (enemy.strikeTargetX or 0)
                            local pdy = pCenterY - (enemy.strikeTargetY or 0)
                            local pdist = math.sqrt(pdx * pdx + pdy * pdy)
                            if pdist <= 60 then
                                if player.invincibleTime <= 0 then
                                    player.health = player.health - 4
                                    player.invincibleTime = 0.2
                                    player.regenTimer = 0
                                    game.pendingThornsAttackers = game.pendingThornsAttackers or {}
                                    table.insert(game.pendingThornsAttackers, "none")
                                    if player.health <= 0 then
                                        game.running = false
                                        game.state = "gameover"
                                    end
                                end
                            end
                        end
                    end

                    if enemy.stateTimer <= 0 then
                        -- Explode at end of strike (180px radius, 15 damage)
                        local pCenterX = player.x + player.width / 2
                        local pCenterY = player.y + player.height / 2
                        local pdx = pCenterX - (enemy.strikeTargetX or 0)
                        local pdy = pCenterY - (enemy.strikeTargetY or 0)
                        local pdist = math.sqrt(pdx * pdx + pdy * pdy)
                        if pdist <= 180 then
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

                        enemy.strikeExplodeX = enemy.strikeTargetX
                        enemy.strikeExplodeY = enemy.strikeTargetY
                        enemy.strikeExplodeTimer = 0.4

                        enemy.bossState = "normal"
                        enemy.patternTimer = 5.0
                        enemy.nextPattern = "laser_grid"
                    end

                elseif enemy.bossState == "recharging" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    if enemy.stateTimer <= 0 then
                        -- Recovery: emit shockwave
                        local pCenterX = player.x + player.width / 2
                        local pCenterY = player.y + player.height / 2
                        local pdx = pCenterX - bCenterX
                        local pdy = pCenterY - bCenterY
                        local pdist = math.sqrt(pdx * pdx + pdy * pdy)
                        
                        -- Shockwave recoil push player back by 150px if within 300px
                        if pdist < 300 then
                            local pushDist = 150
                            local pushDirX, pushDirY = 1, 0
                            if pdist > 0 then
                                pushDirX, pushDirY = pdx / pdist, pdy / pdist
                            end
                            player.x = player.x + pushDirX * pushDist
                            player.y = player.y + pushDirY * pushDist
                            
                            -- Clamp player position inside world
                            player.x = math.max(0, math.min(game.world.width - player.width, player.x))
                            player.y = math.max(0, math.min(game.world.height - player.height, player.y))
                        end

                        -- Trigger visual shockwave effect
                        enemy.shockwaveRadius = 10 -- starts expanding
                        enemy.shockwaveDuration = 0.5
                        enemy.shockwaveTimer = 0

                        -- Regenerate 4 shield guardians
                        for i = 1, 4 do
                            local angle = enemy.shieldAngle + (i - 1) * (math.pi / 2)
                            local sx = bCenterX + math.cos(angle) * 120 - 12
                            local sy = bCenterY + math.sin(angle) * 120 - 12
                            table.insert(game.enemies, {
                                x = sx,
                                y = sy,
                                width = 24,
                                height = 24,
                                speed = 0,
                                health = 1500 * stageMultiplier,
                                maxHealth = 1500 * stageMultiplier,
                                type = "aegis_shield",
                                color = { 1.0, 0.8, 0.1 },
                                points = 150,
                                velX = 0,
                                velY = 0,
                                shieldIndex = i
                            })
                        end

                        enemy.bossState = "normal"
                        enemy.patternTimer = 5.0
                        enemy.nextPattern = "laser_grid"
                        enemy.speed = 40 -- Restore original speed
                    end
                end

                -- Shockwave effect expansion inside update
                if enemy.shockwaveTimer then
                    enemy.shockwaveTimer = enemy.shockwaveTimer + dt
                    if enemy.shockwaveTimer >= enemy.shockwaveDuration then
                        enemy.shockwaveTimer = nil
                        enemy.shockwaveRadius = nil
                    else
                        enemy.shockwaveRadius = 300 * (enemy.shockwaveTimer / enemy.shockwaveDuration)
                    end
                end

                -- Explode timer countdown
                if enemy.strikeExplodeTimer then
                    enemy.strikeExplodeTimer = enemy.strikeExplodeTimer - dt
                    if enemy.strikeExplodeTimer <= 0 then
                        enemy.strikeExplodeTimer = nil
                        enemy.strikeExplodeX = nil
                        enemy.strikeExplodeY = nil
                    end
                end

                -- Orbit active shields coordinates relative to boss center
                for _, other in ipairs(game.enemies) do
                    if other.type == "aegis_shield" then
                        local i = other.shieldIndex or 1
                        local angle = enemy.shieldAngle + (i - 1) * (math.pi / 2)
                        other.x = bCenterX + math.cos(angle) * 120 - 12
                        other.y = bCenterY + math.sin(angle) * 120 - 12
                    end
                end

            elseif currentStage >= 6 then
                -- ==========================================
                -- BOSS 6 (Chronos Weaver)
                -- ==========================================
                enemy.patternTimer = enemy.patternTimer or 6.0
                enemy.nextPattern = enemy.nextPattern or "time_burst"
                enemy.timeTrail = enemy.timeTrail or {}

                local bCenterX = enemy.x + enemy.width / 2
                local bCenterY = enemy.y + enemy.height / 2

                if enemy.bossState == "normal" then
                    enemy.patternTimer = enemy.patternTimer - dt
                    
                    -- Record history coordinates (up to 180 entries = 3 seconds at 60fps)
                    table.insert(enemy.timeTrail, 1, { x = enemy.x, y = enemy.y })
                    if #enemy.timeTrail > 180 then
                        table.remove(enemy.timeTrail)
                    end

                    if enemy.patternTimer <= 0 then
                        if enemy.nextPattern == "time_burst" then
                            enemy.bossState = "time_burst"
                            enemy.stateTimer = 1.0
                            enemy.firedBurst = false
                        elseif enemy.nextPattern == "time_rewind" then
                            enemy.bossState = "time_rewind"
                            enemy.stateTimer = 2.0
                        elseif enemy.nextPattern == "time_sweep" then
                            enemy.bossState = "time_sweep"
                            enemy.stateTimer = 5.0
                        end
                    end

                    -- Chase player
                    if dist > 0 then
                        targetVelX = (dx / dist) * enemy.speed
                        targetVelY = (dy / dist) * enemy.speed
                    end

                elseif enemy.bossState == "time_burst" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    if not enemy.firedBurst then
                        enemy.firedBurst = true
                        game.enemyBullets = game.enemyBullets or {}
                        local bulletSpeed = 220
                        for i = 1, 24 do
                            local angle = (i - 1) * (2 * math.pi / 24)
                            table.insert(game.enemyBullets, {
                                x = bCenterX,
                                y = bCenterY,
                                dirX = math.cos(angle),
                                dirY = math.sin(angle),
                                speed = bulletSpeed,
                                damage = 15,
                                size = 10,
                                maxDist = 800,
                                distTraveled = 0,
                                timer = 0,
                                state = "forward",
                                owner = enemy,
                                type = "temporal"
                            })
                        end
                    end

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "normal"
                        enemy.firedBurst = nil
                        enemy.patternTimer = 6.0
                        enemy.nextPattern = "time_rewind"
                    end

                elseif enemy.bossState == "time_rewind" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    -- Backtrack historical positions at 3x speed (pop 3 elements per frame)
                    local popped = nil
                    if enemy.timeTrail then
                        for step = 1, 3 do
                            if #enemy.timeTrail > 0 then
                                popped = table.remove(enemy.timeTrail, 1)
                            end
                        end
                    end
                    if popped then
                        enemy.x = popped.x
                        enemy.y = popped.y
                    end

                    -- Heal boss slightly during rewind (200 HP per frame/second)
                    enemy.health = math.min(enemy.maxHealth, enemy.health + 200 * dt)

                    if enemy.stateTimer <= 0 or not enemy.timeTrail or #enemy.timeTrail == 0 then
                        enemy.bossState = "normal"
                        enemy.patternTimer = 5.0
                        enemy.nextPattern = "time_sweep"
                    end

                elseif enemy.bossState == "time_sweep" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    enemy.velX, enemy.velY = 0, 0

                    -- Collision check with player
                    local pCenterX = player.x + player.width / 2
                    local pCenterY = player.y + player.height / 2

                    -- Minute hand laser (sweeps faster) - Slows player upon contact (and deals damage)
                    local minuteAngle = (game.time * 5.0) - math.pi / 2
                    local mx2 = bCenterX + math.cos(minuteAngle) * 900
                    local my2 = bCenterY + math.sin(minuteAngle) * 900
                    
                    if checkLineCircleCollision(bCenterX, bCenterY, mx2, my2, pCenterX, pCenterY, player.width / 2 + 8) then
                        player.speedMultiplier = 0.4 -- Slow down by 60%
                        
                        if player.invincibleTime <= 0 then
                            player.health = player.health - 6
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

                    -- Hour hand laser (sweeps slowly) - Deals heavy damage
                    local hourAngle = (game.time * 1.5) - math.pi / 2
                    local hx2 = bCenterX + math.cos(hourAngle) * 900
                    local hy2 = bCenterY + math.sin(hourAngle) * 900
                    if checkLineCircleCollision(bCenterX, bCenterY, hx2, hy2, pCenterX, pCenterY, player.width / 2 + 12) then
                        if player.invincibleTime <= 0 then
                            player.health = player.health - 12 -- 12 damage
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

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "normal"
                        enemy.patternTimer = 6.0
                        enemy.nextPattern = "time_burst"
                    end
                end
            end

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
                if enemy.type == "ranged" and dist <= (enemy.shootRange or 250) then
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

        if enemy.type ~= "boss" and enemy.type ~= "tesla_pylon" and enemy.type ~= "aegis_shield" and not isRooted then
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
        if isRooted or enemy.type == "tesla_pylon" or enemy.type == "aegis_shield" then
            enemy.velX = 0
            enemy.velY = 0
        else
            enemy.velX = enemy.velX + (targetVelX - enemy.velX) * turnSpeed * dt
            enemy.velY = enemy.velY + (targetVelY - enemy.velY) * turnSpeed * dt
        end

        -- 위치 갱신
        enemy.x = enemy.x + enemy.velX * dt
        enemy.y = enemy.y + enemy.velY * dt

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

        -- 보스 사격 타이머 업데이트 및 부채꼴(3방향) 탄환 발사 (normal 상태일 때만, 1/2스테이지 보스만 사격)
        if enemy.type == "boss" and enemy.bossState == "normal" and (game.stage or 1) < 3 and dist <= (enemy.shootRange or 400) then
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
                local dmg = 1
                if enemy.type == "boss" then
                    dmg = 20 -- 보스의 몸박 데미지는 강력하게 20!
                elseif enemy.type == "boss_clone" then
                    dmg = 4  -- 분신의 몸박 데미지 4!
                elseif enemy.type == "charger" and enemy.chargerState == "rushing" then
                    dmg = 3  -- 돌격하는 돌진병 대미지 3!
                end
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
    for _, enemy in ipairs(game.enemies) do
        local col = enemy.color or { 1.0, 0.3, 0.3 }

        if enemy.type == "boss" or enemy.type == "boss_clone" or enemy.type == "tesla_pylon" or enemy.type == "aegis_shield" then
            local currentStage = game.stage or 1
            local cx = enemy.x + enemy.width / 2
            local cy = enemy.y + enemy.height / 2
            local halfW = enemy.width / 2
            local pulse = 1 + math.sin(game.time * 8) * 0.08

            if currentStage < 3 and enemy.type == "boss" then
                local isStage2 = (game.stage or 1) >= 2
                -- 1. Motion blur trails (rushing state)
                if enemy.bossState == "rushing" and enemy.trailHistory then
                    for idx, pos in ipairs(enemy.trailHistory) do
                        local alpha = 0.4 * (1 - idx / #enemy.trailHistory)
                        love.graphics.setColor(col[1], col[2], col[3], alpha)

                        love.graphics.push()
                        love.graphics.translate(pos.x + halfW, pos.y + halfW)
                        love.graphics.rotate(game.time * 1.5 + idx * 0.2)

                        -- Draw simplified trail spikes
                        local outerR = halfW * 1.1
                        local innerR = halfW * 0.5
                        for k = 1, 6 do
                            local angle = (k * math.pi / 3)
                            love.graphics.push()
                            love.graphics.rotate(angle)
                            love.graphics.polygon("fill",
                                -4, -innerR,
                                4, -innerR,
                                6, -outerR * 0.7,
                                0, -outerR,
                                -6, -outerR * 0.7
                            )
                            love.graphics.pop()
                        end
                        love.graphics.pop()
                    end
                end

                -- 2. Warning indicator rings (charging_burst & charging_petal state)
                if enemy.bossState == "charging_burst" or enemy.bossState == "charging_petal" then
                    -- Collapsing indicator ring
                    local progress = enemy.stateTimer / 0.8
                    if enemy.bossState == "charging_petal" then
                        love.graphics.setColor(1.0, 0.4, 0.6, 0.6) -- Pink for petal
                        love.graphics.setLineWidth(2)
                        love.graphics.circle("line", cx, cy, enemy.width * 1.5 * progress)
                        -- Glowing outer ring
                        love.graphics.setColor(1.0, 0.6, 0.7, 0.2)
                        love.graphics.circle("fill", cx, cy, enemy.width * 1.5)
                    else
                        love.graphics.setColor(1.0, 0.3, 0.3, 0.6) -- Red for void burst
                        love.graphics.setLineWidth(2)
                        love.graphics.circle("line", cx, cy, enemy.width * 1.5 * progress)
                        -- Glowing outer ring
                        love.graphics.setColor(1.0, 0.5, 0.5, 0.2)
                        love.graphics.circle("fill", cx, cy, enemy.width * 1.5)
                    end
                end

                -- 3. Targeting laser beam line (charging_rush state)
                if enemy.bossState == "charging_rush" then
                    if isStage2 then
                        love.graphics.setColor(1.0, 0.45, 0.1, 0.75 + math.sin(game.time * 20) * 0.25) -- Solar orange
                    else
                        love.graphics.setColor(0.7, 0.1, 1.0, 0.75 + math.sin(game.time * 20) * 0.25)  -- Void purple
                    end
                    love.graphics.setLineWidth(3)
                    -- Draw a long laser line from boss center towards player
                    local laserLength = 1000
                    local lx = cx + (enemy.rushDirX or 0) * laserLength
                    local ly = cy + (enemy.rushDirY or 0) * laserLength
                    love.graphics.line(cx, cy, lx, ly)

                    -- Add a small targeting reticle/indicator at the player location
                    local p = game.player
                    if p then
                        love.graphics.circle("line", p.x + p.width / 2, p.y + p.height / 2, 16 + math.sin(game.time * 15) * 4)
                    end
                end

                -- 4. Boss glow aura (outer/inner glow)
                love.graphics.setColor(col[1], col[2], col[3], 0.15)
                love.graphics.circle("fill", cx, cy, enemy.width * 0.75 * pulse)
                love.graphics.setColor(col[1], col[2], col[3], 0.3)
                love.graphics.circle("fill", cx, cy, enemy.width * 0.55 * pulse)

                -- 5. Rotating Outer Spiked Claws/Wings (6 claws)
                local rotationAngle = game.time * 1.5
                local innerR = halfW * 0.4
                local outerR = halfW * 1.1

                if enemy.bossState == "charging_rush" or enemy.bossState == "charging_burst" or enemy.bossState == "charging_petal" then
                    -- Claws expand and vibrate while charging
                    innerR = halfW * 0.5 + math.sin(game.time * 30) * 2
                    outerR = halfW * 1.35 + math.sin(game.time * 30) * 4
                    rotationAngle = game.time * 4.0 + (math.random() - 0.5) * 0.08
                elseif enemy.bossState == "petalling" then
                    -- Claws flare wide and slow rotate when spraying petals
                    innerR = halfW * 0.65
                    outerR = halfW * 1.45
                    rotationAngle = game.time * 0.5
                elseif enemy.bossState == "rushing" then
                    -- Spins like a lethal saw blade when dashing
                    innerR = halfW * 0.35
                    outerR = halfW * 1.15
                    rotationAngle = game.time * 6.0
                end

                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(rotationAngle)
                for k = 1, 6 do
                    local angle = (k * math.pi / 3)
                    love.graphics.push()
                    love.graphics.rotate(angle)

                    -- Spiked Claw fill (dark metal color)
                    love.graphics.setColor(0.12, 0.08, 0.2, 0.95)
                    love.graphics.polygon("fill",
                        -8, -innerR,
                        8, -innerR,
                        12, -outerR * 0.7,
                        0, -outerR,
                        -12, -outerR * 0.7
                    )

                    -- Neon border for the spikes (glow effect)
                    love.graphics.setColor(col[1], col[2], col[3], 0.9)
                    love.graphics.setLineWidth(1.8)
                    love.graphics.polygon("line",
                        -8, -innerR,
                        8, -innerR,
                        12, -outerR * 0.7,
                        0, -outerR,
                        -12, -outerR * 0.7
                    )

                    love.graphics.pop()
                end
                love.graphics.pop()

                -- 6. Counter-rotating dual-triangle (creates a shifting Star of David hexagram body)
                local r_tri = halfW * 0.58
                local innerRot = -game.time * 1.5
                if enemy.bossState == "charging_rush" or enemy.bossState == "charging_burst" or enemy.bossState == "charging_petal" then
                    innerRot = -game.time * 3.0
                elseif enemy.bossState == "rushing" or enemy.bossState == "petalling" then
                    innerRot = -game.time * 4.0
                end

                -- Triangle 1
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(innerRot)
                love.graphics.setColor(0.15, 0.08, 0.22, 0.85)
                love.graphics.polygon("fill",
                    0, -r_tri,
                    r_tri * 0.866, r_tri * 0.5,
                    -r_tri * 0.866, r_tri * 0.5
                )
                love.graphics.setColor(col[1] * 1.2, col[2] * 1.2, col[3] * 1.2, 0.95)
                love.graphics.setLineWidth(1.8)
                love.graphics.polygon("line",
                    0, -r_tri,
                    r_tri * 0.866, r_tri * 0.5,
                    -r_tri * 0.866, r_tri * 0.5
                )
                love.graphics.pop()

                -- Triangle 2 (Offset by 180 degrees)
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(-innerRot + math.pi)
                love.graphics.setColor(0.15, 0.08, 0.22, 0.75)
                love.graphics.polygon("fill",
                    0, -r_tri,
                    r_tri * 0.866, r_tri * 0.5,
                    -r_tri * 0.866, r_tri * 0.5
                )
                love.graphics.setColor(col[1] * 1.2, col[2] * 1.2, col[3] * 1.2, 0.95)
                love.graphics.setLineWidth(1.8)
                love.graphics.polygon("line",
                    0, -r_tri,
                    r_tri * 0.866, r_tri * 0.5,
                    -r_tri * 0.866, r_tri * 0.5
                )
                love.graphics.pop()

                -- 7. Glowing nucleus eye in the center (synced with boss col)
                local eyePulse = 1 + math.sin(game.time * 12) * 0.15
                local eyeCol = { col[1] * 1.2, col[2] * 1.2, col[3] * 1.2 }
                if enemy.bossState == "charging_rush" or enemy.bossState == "charging_burst" or enemy.bossState == "charging_petal" then
                    eyeCol = { 1.0, 0.4, 0.1 }
                    eyePulse = 1.2 + math.sin(game.time * 24) * 0.25
                elseif enemy.bossState == "rushing" then
                    eyeCol = { 1.0, 0.1, 0.1 }
                elseif enemy.bossState == "petalling" then
                    eyeCol = { 1.0, 0.25, 0.6 }
                    eyePulse = 1.1 + math.sin(game.time * 18) * 0.15
                end

                love.graphics.setColor(eyeCol[1], eyeCol[2], eyeCol[3], 0.35)
                love.graphics.circle("fill", cx, cy, 18 * eyePulse)
                love.graphics.setColor(0.05, 0.05, 0.1, 0.9)
                love.graphics.circle("fill", cx, cy, 10 * eyePulse)
                love.graphics.setColor(eyeCol[1], eyeCol[2], eyeCol[3], 0.95)
                love.graphics.circle("fill", cx, cy, 5 * eyePulse)
                love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
                love.graphics.circle("fill", cx - 2 * eyePulse, cy - 2 * eyePulse, 2 * eyePulse)

                love.graphics.setColor(1.0, 1.0, 1.0)
                love.graphics.setLineWidth(1)
            elseif currentStage == 3 or enemy.type == "boss_clone" then
                -- Stage 3 Boss & Holographic Clones drawing
                local isClone = (enemy.type == "boss_clone")
                local baseAlpha = isClone and (0.55 + math.sin(game.time * 20) * 0.1) or 1.0

                -- 1. Motion blur trails (dashing state)
                if enemy.bossState == "dashing" and enemy.trailHistory then
                    for idx, pos in ipairs(enemy.trailHistory) do
                        local alpha = 0.35 * (1 - idx / #enemy.trailHistory) * baseAlpha
                        love.graphics.setColor(col[1], col[2], col[3], alpha)
                        love.graphics.push()
                        love.graphics.translate(pos.x + halfW, pos.y + halfW)
                        love.graphics.rotate(game.time * 8.0 - idx * 0.3)
                        
                        -- Draw simplified trail (4 blades)
                        local outerR = halfW * 1.15
                        local innerR = halfW * 0.35
                        for k = 1, 4 do
                            local angle = (k * math.pi / 2)
                            love.graphics.push()
                            love.graphics.rotate(angle)
                            love.graphics.polygon("fill",
                                -5, -innerR,
                                5, -innerR,
                                7, -outerR * 0.6,
                                0, -outerR,
                                -7, -outerR * 0.6
                            )
                            love.graphics.pop()
                        end
                        love.graphics.pop()
                    end
                end

                -- 2. Warning lines & Target Lock Crosshairs (charging_dash & charging_crossfire state)
                if enemy.bossState == "charging_dash" or enemy.bossState == "charging_crossfire" then
                    love.graphics.setColor(0.25, 0.95, 0.75, (0.75 + math.sin(game.time * 25) * 0.2) * baseAlpha)
                    if enemy.bossState == "charging_crossfire" then
                        love.graphics.setLineWidth(1.5) -- Thinner target line for crossfire
                    else
                        love.graphics.setLineWidth(2.5)
                    end
                    local laserLength = 1000
                    local lx = cx + (enemy.rushDirX or 0) * laserLength
                    local ly = cy + (enemy.rushDirY or 0) * laserLength
                    love.graphics.line(cx, cy, lx, ly)

                    local p = game.player
                    if p then
                        local px, py = p.x + p.width / 2, p.y + p.height / 2
                        local crosshairR = 15 + math.sin(game.time * 20) * 3
                        love.graphics.circle("line", px, py, crosshairR)
                        if enemy.bossState == "charging_dash" then
                            love.graphics.line(px - crosshairR - 5, py, px - crosshairR + 5, py)
                            love.graphics.line(px + crosshairR - 5, py, px + crosshairR + 5, py)
                            love.graphics.line(px, py - crosshairR - 5, px, py - crosshairR + 5)
                            love.graphics.line(px, py + crosshairR - 5, px, py + crosshairR + 5)
                        end
                    end
                end

                -- 3. Exhausted State / Vulnerable Indicator
                if enemy.bossState == "exhausted" then
                    local vulPulse = 1.0 + math.sin(game.time * 15) * 0.1
                    love.graphics.setColor(1.0, 0.1, 0.1, (0.6 + math.sin(game.time * 15) * 0.25) * baseAlpha)
                    love.graphics.setLineWidth(3)
                    love.graphics.circle("line", cx, cy, enemy.width * 1.0 * vulPulse)
                    
                    love.graphics.setColor(1.0, 0.1, 0.1, baseAlpha)
                    love.graphics.printf("VULNERABLE", cx - 100, enemy.y - 25, 200, "center")
                end

                -- 4. Outer Glow Aura
                love.graphics.setColor(col[1], col[2], col[3], 0.15 * baseAlpha)
                love.graphics.circle("fill", cx, cy, enemy.width * 0.75 * pulse)
                love.graphics.setColor(col[1], col[2], col[3], 0.3 * baseAlpha)
                love.graphics.circle("fill", cx, cy, enemy.width * 0.55 * pulse)

                -- 5. 4 Rotating Razor-sharp Blades (Shuriken Wings)
                local rotationAngle = game.time * 3.0
                local innerR = halfW * 0.45
                local outerR = halfW * 1.25
                if enemy.bossState == "dashing" then
                    rotationAngle = game.time * 15.0
                    innerR = halfW * 0.35
                    outerR = halfW * 1.3
                elseif enemy.bossState == "charging_dash" or enemy.bossState == "charging_crossfire" then
                    rotationAngle = game.time * 8.0 + math.sin(game.time * 35) * 0.1
                    innerR = halfW * 0.5
                    outerR = halfW * 1.4
                elseif enemy.bossState == "exhausted" then
                    rotationAngle = game.time * 0.3
                    innerR = halfW * 0.4
                    outerR = halfW * 1.0
                end

                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(rotationAngle)
                for k = 1, 4 do
                    local angle = (k * math.pi / 2)
                    love.graphics.push()
                    love.graphics.rotate(angle)

                    -- Shuriken blade fill
                    love.graphics.setColor(0.08, 0.12, 0.15, 0.95 * baseAlpha)
                    love.graphics.polygon("fill",
                        -7, -innerR,
                        7, -innerR,
                        9, -outerR * 0.6,
                        0, -outerR,
                        -9, -outerR * 0.6
                    )

                    -- Glowing edge
                    local edgeCol = { col[1], col[2], col[3] }
                    if enemy.bossState == "exhausted" then
                        edgeCol = { 0.5, 0.5, 0.5 }
                    end
                    love.graphics.setColor(edgeCol[1], edgeCol[2], edgeCol[3], 0.9 * baseAlpha)
                    love.graphics.setLineWidth(2)
                    love.graphics.polygon("line",
                        -7, -innerR,
                        7, -innerR,
                        9, -outerR * 0.6,
                        0, -outerR,
                        -9, -outerR * 0.6
                    )
                    love.graphics.pop()
                end
                love.graphics.pop()

                -- 6. Sharp Diamond Assassin Body Frame
                love.graphics.push()
                love.graphics.translate(cx, cy)
                local diamondRot = -rotationAngle * 0.5
                love.graphics.rotate(diamondRot)
                
                local dW = halfW * 0.7
                local dH = halfW * 0.7
                
                love.graphics.setColor(0.1, 0.15, 0.18, 0.9 * baseAlpha)
                love.graphics.polygon("fill", 0, -dH, dW, 0, 0, dH, -dW, 0)
                
                local dBorderCol = { col[1] * 1.2, col[2] * 1.2, col[3] * 1.2 }
                if enemy.bossState == "exhausted" then
                    dBorderCol = { 0.6, 0.6, 0.6 }
                end
                love.graphics.setColor(dBorderCol[1], dBorderCol[2], dBorderCol[3], 0.95 * baseAlpha)
                love.graphics.setLineWidth(2.2)
                love.graphics.polygon("line", 0, -dH, dW, 0, 0, dH, -dW, 0)
                love.graphics.pop()

                -- 7. Glowing Nucleus Eye Core
                local eyePulse = 1.0
                local eyeCol = { col[1], col[2], col[3] }
                if enemy.bossState == "dashing" then
                    eyeCol = { 1.0, 0.2, 0.2 }
                    eyePulse = 1.25 + math.sin(game.time * 25) * 0.2
                elseif enemy.bossState == "charging_dash" or enemy.bossState == "charging_crossfire" then
                    eyeCol = { 0.25, 0.95, 0.75 }
                    eyePulse = 1.2 + math.sin(game.time * 20) * 0.2
                elseif enemy.bossState == "exhausted" then
                    eyeCol = { 0.4, 0.4, 0.4 }
                    eyePulse = 0.8
                else
                    eyePulse = 1.0 + math.sin(game.time * 10) * 0.1
                end

                love.graphics.setColor(eyeCol[1], eyeCol[2], eyeCol[3], 0.35 * baseAlpha)
                love.graphics.circle("fill", cx, cy, 14 * eyePulse)
                love.graphics.setColor(0.04, 0.05, 0.08, 0.9 * baseAlpha)
                love.graphics.circle("fill", cx, cy, 8 * eyePulse)
                love.graphics.setColor(eyeCol[1], eyeCol[2], eyeCol[3], 0.95 * baseAlpha)
                love.graphics.circle("fill", cx, cy, 4 * eyePulse)
                love.graphics.setColor(1.0, 1.0, 1.0, 0.9 * baseAlpha)
                love.graphics.circle("fill", cx - 1.5 * eyePulse, cy - 1.5 * eyePulse, 1.5 * eyePulse)

                love.graphics.setColor(1.0, 1.0, 1.0)
                love.graphics.setLineWidth(1)
            elseif currentStage == 4 or enemy.type == "tesla_pylon" then
                -- Stage 4 Boss & Pylons drawing
                if enemy.type == "tesla_pylon" then
                    -- 1. Draw Tesla Pylon
                    love.graphics.push()
                    love.graphics.translate(cx, cy)
                    love.graphics.rotate(game.time * 2.0)
                    
                    -- Outer glowing diamond
                    love.graphics.setColor(0.6, 0.5, 1.0, 0.35 + math.sin(game.time * 15) * 0.15)
                    love.graphics.polygon("fill", 0, -18, 12, 0, 0, 18, -12, 0)
                    
                    -- Inner core
                    love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                    love.graphics.polygon("fill", 0, -8, 5, 0, 0, 8, -5, 0)
                    
                    -- Edge line
                    love.graphics.setColor(0.7, 0.6, 1.0, 0.9)
                    love.graphics.setLineWidth(1.8)
                    love.graphics.polygon("line", 0, -18, 12, 0, 0, 18, -12, 0)
                    love.graphics.pop()
                    
                    love.graphics.setColor(1.0, 1.0, 1.0)
                    love.graphics.setLineWidth(1)
                else
                    -- 2. Draw Tesla Archon Boss
                    -- A. Draw magnetic pull field collapsed rings if state is magnetic_pull
                    if enemy.bossState == "magnetic_pull" then
                        love.graphics.setLineWidth(2.5)
                        local maxRadius = 550
                        for rIdx = 1, 3 do
                            local rPulse = ((game.time * 1.8 + rIdx / 3) % 1.0)
                            local ringRadius = maxRadius * (1.0 - rPulse)
                            love.graphics.setColor(0.6, 0.4, 1.0, rPulse * 0.45)
                            love.graphics.circle("line", cx, cy, ringRadius)
                        end
                        -- Glow region
                        love.graphics.setColor(0.5, 0.3, 0.9, 0.05)
                        love.graphics.circle("fill", cx, cy, maxRadius)
                    end

                    -- B. Draw electric fences connecting Boss and Pylons
                    if enemy.bossState == "tesla_pylons_active" then
                        for _, other in ipairs(game.enemies) do
                            if other.type == "tesla_pylon" then
                                local pycx = other.x + other.width / 2
                                local pycy = other.y + other.height / 2
                                
                                -- 3-layer glowing lightning beam
                                -- 1) Base glow (purple)
                                love.graphics.setColor(0.5, 0.2, 0.8, 0.3)
                                love.graphics.setLineWidth(8)
                                drawLightningBeam(cx, cy, pycx, pycy, 8, 16)
                                
                                -- 2) Mid glow (violet)
                                love.graphics.setColor(0.7, 0.4, 1.0, 0.75)
                                love.graphics.setLineWidth(4)
                                drawLightningBeam(cx, cy, pycx, pycy, 8, 12)
                                
                                -- 3) Core (bright white)
                                love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                                love.graphics.setLineWidth(1.5)
                                drawLightningBeam(cx, cy, pycx, pycy, 8, 6)
                            end
                        end
                    end

                    -- C. Draw electric charging indicators / EMP Storm Dome
                    if enemy.bossState == "tesla_pylons" or enemy.bossState == "volt_discharge" then
                        local scale = 1.0 + math.sin(game.time * 25) * 0.1
                        love.graphics.setColor(0.7, 0.5, 1.0, 0.25)
                        love.graphics.circle("fill", cx, cy, enemy.width * 1.3 * scale)
                        
                        -- Collapsing ring
                        local progress = enemy.stateTimer / (enemy.bossState == "tesla_pylons" and 1.2 or 1.0)
                        love.graphics.setColor(0.6, 0.5, 1.0, 0.7)
                        love.graphics.setLineWidth(2)
                        love.graphics.circle("line", cx, cy, enemy.width * 1.6 * progress)
                    elseif enemy.bossState == "emp_storm" then
                        -- Large electromagnetic dome
                        local scale = 1.0 + math.sin(game.time * 20) * 0.15
                        love.graphics.setColor(0.5, 0.3, 0.9, 0.12)
                        love.graphics.circle("fill", cx, cy, enemy.width * 2.2 * scale)
                        
                        love.graphics.setColor(0.6, 0.4, 1.0, 0.5 + math.sin(game.time * 30) * 0.2)
                        love.graphics.setLineWidth(2.5)
                        love.graphics.circle("line", cx, cy, enemy.width * 2.2 * scale)

                        -- Radiating sparks
                        love.graphics.setColor(0.8, 0.6, 1.0, 0.85)
                        for s = 1, 4 do
                            local sa = (s - 1) * (math.pi / 2) + game.time * 2.0 + (math.random() - 0.5) * 0.2
                            local sd1 = enemy.width * 0.3
                            local sd2 = enemy.width * 2.2 * scale
                            local sx1 = cx + math.cos(sa) * sd1
                            local sy1 = cy + math.sin(sa) * sd1
                            local sx2 = cx + math.cos(sa) * sd2
                            local sy2 = cy + math.sin(sa) * sd2
                            drawLightningBeam(sx1, sy1, sx2, sy2, 5, 8)
                        end
                    end

                    -- D. Archon Outer Glow Aura
                    love.graphics.setColor(col[1], col[2], col[3], 0.15)
                    love.graphics.circle("fill", cx, cy, enemy.width * 0.8 * pulse)
                    love.graphics.setColor(col[1], col[2], col[3], 0.3)
                    love.graphics.circle("fill", cx, cy, enemy.width * 0.6 * pulse)

                    -- E. Three Concentric Triangle Vectors Spinning in Opposite Directions
                    -- Outer Triangle (spins clockwise)
                    love.graphics.push()
                    love.graphics.translate(cx, cy)
                    love.graphics.rotate(game.time * 1.2)
                    love.graphics.setColor(col[1], col[2], col[3], 0.85)
                    love.graphics.setLineWidth(2.2)
                    local rOuter = halfW * 1.2
                    love.graphics.polygon("line",
                        0, -rOuter,
                        rOuter * 0.866, rOuter * 0.5,
                        -rOuter * 0.866, rOuter * 0.5
                    )
                    -- small spikes on outer vertices
                    for v = 0, 2 do
                        local vAngle = v * (2 * math.pi / 3)
                        love.graphics.circle("fill", math.cos(vAngle - math.pi/2) * rOuter, math.sin(vAngle - math.pi/2) * rOuter, 4)
                    end
                    love.graphics.pop()

                    -- Middle Triangle (spins counter-clockwise, offset angle)
                    love.graphics.push()
                    love.graphics.translate(cx, cy)
                    love.graphics.rotate(-game.time * 1.8 + math.pi / 3)
                    love.graphics.setColor(col[1] * 1.2, col[2] * 0.8, col[3] * 1.3, 0.9)
                    love.graphics.setLineWidth(1.8)
                    local rMid = halfW * 0.85
                    love.graphics.polygon("line",
                        0, -rMid,
                        rMid * 0.866, rMid * 0.5,
                        -rMid * 0.866, rMid * 0.5
                    )
                    love.graphics.pop()

                    -- Inner Triangle (spins clockwise, faster)
                    love.graphics.push()
                    love.graphics.translate(cx, cy)
                    love.graphics.rotate(game.time * 2.8)
                    love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                    love.graphics.setLineWidth(1.5)
                    local rInner = halfW * 0.55
                    love.graphics.polygon("line",
                        0, -rInner,
                        rInner * 0.866, rInner * 0.5,
                        -rInner * 0.866, rInner * 0.5
                    )
                    love.graphics.pop()

                    -- F. Center Core (Glowing high voltage eye sphere)
                    local eyePulse = 1.0 + math.sin(game.time * 15) * 0.12
                    local eyeCol = { 0.8, 0.7, 1.0 } -- violet-white
                    if enemy.bossState == "magnetic_pull" then
                        eyeCol = { 0.9, 0.4, 1.0 }
                        eyePulse = 1.25 + math.sin(game.time * 22) * 0.18
                    elseif enemy.bossState == "tesla_pylons" or enemy.bossState == "volt_discharge" or enemy.bossState == "emp_storm" then
                        eyeCol = { 1.0, 1.0, 1.0 }
                        eyePulse = 1.3 + math.sin(game.time * 30) * 0.25
                    end

                    love.graphics.setColor(eyeCol[1], eyeCol[2], eyeCol[3], 0.35)
                    love.graphics.circle("fill", cx, cy, 15 * eyePulse)
                    love.graphics.setColor(0.04, 0.05, 0.08, 0.95)
                    love.graphics.circle("fill", cx, cy, 8 * eyePulse)
                    love.graphics.setColor(eyeCol[1], eyeCol[2], eyeCol[3], 0.95)
                    love.graphics.circle("fill", cx, cy, 4 * eyePulse)
                    love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
                    love.graphics.circle("fill", cx - 1.5 * eyePulse, cy - 1.5 * eyePulse, 1.5 * eyePulse)

                    love.graphics.setColor(1.0, 1.0, 1.0)
                    love.graphics.setLineWidth(1)
                end
        elseif currentStage == 5 or enemy.type == "aegis_shield" then
            if enemy.type == "aegis_shield" then
                -- Draw Aegis Shield
                love.graphics.push()
                love.graphics.translate(cx, cy)
                -- Find boss center to rotate shield to face outwards from boss
                local bCenterX, bCenterY = cx, cy
                for _, other in ipairs(game.enemies) do
                    if other.type == "boss" then
                        bCenterX = other.x + other.width / 2
                        bCenterY = other.y + other.height / 2
                        break
                    end
                end
                local angle = math.atan2(cy - bCenterY, cx - bCenterX)
                love.graphics.rotate(angle)

                -- Draw a beautiful curved or hexagonal plate shield
                love.graphics.setColor(1.0, 0.8, 0.1, 0.25)
                love.graphics.rectangle("fill", -6, -16, 12, 32, 4, 4)
                love.graphics.setColor(1.0, 0.8, 0.1, 0.9)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", -6, -16, 12, 32, 4, 4)

                -- Add a glowing center highlight
                love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                love.graphics.circle("fill", 0, 0, 4)
                love.graphics.pop()
            else
                -- Draw Orbital Aegis Boss
                -- Draw outer rotating ring/halo (Aegis ring)
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(enemy.shieldAngle or 0)
                love.graphics.setColor(1.0, 0.8, 0.1, 0.15)
                love.graphics.circle("fill", 0, 0, halfW * 1.3)
                love.graphics.setColor(1.0, 0.8, 0.1, 0.8)
                love.graphics.setLineWidth(2.5)
                love.graphics.circle("line", 0, 0, halfW * 1.3)
                
                -- Draw 4 spikes on the rotating outer ring
                for k = 1, 4 do
                    local angle = (k - 1) * (math.pi / 2)
                    love.graphics.push()
                    love.graphics.rotate(angle)
                    love.graphics.polygon("fill", -6, -halfW * 1.3, 6, -halfW * 1.3, 0, -halfW * 1.5)
                    love.graphics.pop()
                end
                love.graphics.pop()

                -- Draw main gear body (mechanical style)
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(-enemy.shieldAngle * 0.5)
                love.graphics.setColor(0.12, 0.10, 0.05, 0.95)
                local gearPts = {}
                local numTeeth = 12
                for t = 1, numTeeth * 2 do
                    local r = (t % 2 == 0) and (halfW * 0.9) or (halfW * 0.7)
                    local angle = (t - 1) * (math.pi / numTeeth)
                    table.insert(gearPts, math.cos(angle) * r)
                    table.insert(gearPts, math.sin(angle) * r)
                end
                love.graphics.polygon("fill", gearPts)
                love.graphics.setColor(col[1], col[2], col[3], 0.9)
                love.graphics.setLineWidth(2.2)
                love.graphics.polygon("line", gearPts)
                love.graphics.pop()

                -- Central reactor core
                local corePulse = 1.0 + math.sin(game.time * 10) * 0.1
                if enemy.bossState == "recharging" then
                    corePulse = 0.7 + math.sin(game.time * 30) * 0.15
                elseif enemy.bossState == "laser_grid" or enemy.bossState == "orbital_strike" then
                    corePulse = 1.3 + math.sin(game.time * 25) * 0.2
                end
                love.graphics.setColor(1.0, 0.8, 0.1, 0.35)
                love.graphics.circle("fill", cx, cy, halfW * 0.5 * corePulse)
                love.graphics.setColor(1.0, 0.9, 0.5, 0.95)
                love.graphics.circle("fill", cx, cy, halfW * 0.3 * corePulse)
                love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                love.graphics.circle("fill", cx, cy, halfW * 0.15 * corePulse)

                -- Draw rotating cross lasers if in laser_grid state
                if enemy.bossState == "laser_grid" then
                    for i = 1, 4 do
                        local angle = enemy.laserAngle + (i - 1) * (math.pi / 2)
                        local lx2 = cx + math.cos(angle) * 800
                        local ly2 = cy + math.sin(angle) * 800
                        
                        -- Outer thick glow
                        love.graphics.setColor(1.0, 0.7, 0.1, 0.35)
                        love.graphics.setLineWidth(12)
                        love.graphics.line(cx, cy, lx2, ly2)
                        
                        -- Mid line
                        love.graphics.setColor(1.0, 0.85, 0.2, 0.8)
                        love.graphics.setLineWidth(6)
                        love.graphics.line(cx, cy, lx2, ly2)
                        
                        -- Core white line
                        love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                        love.graphics.setLineWidth(2)
                        love.graphics.line(cx, cy, lx2, ly2)
                    end
                end

                -- Draw Orbital Strike targeting lock / Fusion Beam
                if enemy.bossState == "orbital_strike" and enemy.strikeTargetX then
                    local tx = enemy.strikeTargetX
                    local ty = enemy.strikeTargetY
                    if enemy.strikeLockTimer and enemy.strikeLockTimer > 0 then
                        -- Targeting Crosshair & Collapsing target rings
                        local progress = enemy.strikeLockTimer / 1.5
                        love.graphics.setColor(1.0, 0.8, 0.1, 0.6 + math.sin(game.time * 15) * 0.2)
                        love.graphics.setLineWidth(2)
                        love.graphics.circle("line", tx, ty, 60 * (1 + progress * 2))
                        love.graphics.circle("line", tx, ty, 8)
                        love.graphics.line(tx - 20, ty, tx - 5, ty)
                        love.graphics.line(tx + 5, ty, tx + 20, ty)
                        love.graphics.line(tx, ty - 20, tx, ty - 5)
                        love.graphics.line(tx, ty + 5, tx, ty + 20)
                    else
                        -- Fusion beam firing from space (down to target y)
                        local beamAlpha = 0.75 + math.sin(game.time * 25) * 0.15
                        -- Outer glow
                        love.graphics.setColor(1.0, 0.8, 0.1, beamAlpha * 0.25)
                        love.graphics.rectangle("fill", tx - 60, 0, 120, ty)
                        love.graphics.circle("fill", tx, ty, 60)
                        -- Mid beam
                        love.graphics.setColor(1.0, 0.9, 0.3, beamAlpha * 0.6)
                        love.graphics.rectangle("fill", tx - 30, 0, 60, ty)
                        love.graphics.circle("fill", tx, ty, 30)
                        -- Core white beam
                        love.graphics.setColor(1.0, 1.0, 1.0, beamAlpha * 0.9)
                        love.graphics.rectangle("fill", tx - 10, 0, 20, ty)
                        love.graphics.circle("fill", tx, ty, 10)
                    end
                end

                -- Draw Orbital Strike final explosion shockwave
                if enemy.strikeExplodeTimer and enemy.strikeExplodeX then
                    local tx = enemy.strikeExplodeX
                    local ty = enemy.strikeExplodeY
                    local progress = (0.4 - enemy.strikeExplodeTimer) / 0.4
                    local alpha = enemy.strikeExplodeTimer / 0.4
                    local radius = 180 * progress
                    love.graphics.setColor(1.0, 0.8, 0.1, alpha * 0.4)
                    love.graphics.circle("fill", tx, ty, radius)
                    love.graphics.setColor(1.0, 0.9, 0.5, alpha * 0.7)
                    love.graphics.setLineWidth(3)
                    love.graphics.circle("line", tx, ty, radius)
                end

                -- Draw shockwave ring expanding
                if enemy.shockwaveRadius then
                    love.graphics.setColor(1.0, 0.8, 0.1, 0.6 * (1 - enemy.shockwaveTimer / enemy.shockwaveDuration))
                    love.graphics.setLineWidth(4)
                    love.graphics.circle("line", cx, cy, enemy.shockwaveRadius)
                end

                -- Vulnerable / Overloaded state visual effects
                if enemy.bossState == "recharging" then
                    local vulPulse = 1.0 + math.sin(game.time * 20) * 0.12
                    love.graphics.setColor(1.0, 0.8, 0.1, 0.5 + math.sin(game.time * 20) * 0.25)
                    love.graphics.setLineWidth(3)
                    love.graphics.circle("line", cx, cy, enemy.width * 0.9 * vulPulse)

                    -- "OVERLOADED" text
                    love.graphics.setColor(1.0, 0.8, 0.1, 0.95)
                    love.graphics.printf("OVERLOADED", cx - 100, enemy.y - 25, 200, "center")
                end
            end
        elseif currentStage >= 6 then
            -- ==========================================
            -- BOSS 6 (Chronos Weaver) drawing
            -- ==========================================
            -- 1. Draw "TIME REWIND" or "TEMPORAL LASERS" warning / info text
            if enemy.bossState == "time_rewind" then
                love.graphics.setColor(0.1, 0.9, 0.6, 0.85 + math.sin(game.time * 20) * 0.15)
                love.graphics.printf("TIME REWIND", cx - 100, enemy.y - 25, 200, "center")
            elseif enemy.bossState == "time_sweep" then
                love.graphics.setColor(1.0, 0.9, 0.4, 0.85 + math.sin(game.time * 20) * 0.15)
                love.graphics.printf("TEMPORAL LASERS", cx - 100, enemy.y - 25, 200, "center")
            end

            -- 2. Draw warning indicator ring for charging time_burst
            if enemy.bossState == "time_burst" and enemy.stateTimer then
                local progress = enemy.stateTimer / 1.0
                love.graphics.setColor(0.1, 0.9, 0.6, 0.6)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", cx, cy, enemy.width * 2.0 * progress)
                love.graphics.setColor(0.1, 0.9, 0.6, 0.15)
                love.graphics.circle("fill", cx, cy, enemy.width * 2.0)
            end

            -- 3. Draw neon green/emerald time trails (Time Ghosts) when rewinding
            if enemy.bossState == "time_rewind" and enemy.timeTrail then
                -- Draw a semi-transparent ghost at every 15th position in history
                for j = 1, #enemy.timeTrail, 15 do
                    local pos = enemy.timeTrail[j]
                    local alpha = 0.35 * (1.0 - j / #enemy.timeTrail)
                    love.graphics.setColor(0.1, 0.9, 0.6, alpha)
                    
                    -- Draw the ghost dial outline
                    love.graphics.circle("line", pos.x + halfW, pos.y + halfW, halfW * 0.95)
                end
            end

            -- 3b. Draw ticking lasers if in time_sweep state
            if enemy.bossState == "time_sweep" then
                -- Hour hand laser (Emerald/Green)
                local hourAngle = (game.time * 1.5) - math.pi / 2
                local hx2 = cx + math.cos(hourAngle) * 900
                local hy2 = cy + math.sin(hourAngle) * 900
                -- Outer glow
                love.graphics.setColor(0.1, 0.9, 0.6, 0.3)
                love.graphics.setLineWidth(12)
                love.graphics.line(cx, cy, hx2, hy2)
                -- Mid line
                love.graphics.setColor(0.1, 0.9, 0.6, 0.75)
                love.graphics.setLineWidth(5)
                love.graphics.line(cx, cy, hx2, hy2)
                -- Core white line
                love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                love.graphics.setLineWidth(1.5)
                love.graphics.line(cx, cy, hx2, hy2)

                -- Minute hand laser (Gold/Yellow)
                local minuteAngle = (game.time * 5.0) - math.pi / 2
                local mx2 = cx + math.cos(minuteAngle) * 900
                local my2 = cy + math.sin(minuteAngle) * 900
                -- Outer glow
                love.graphics.setColor(1.0, 0.9, 0.4, 0.3)
                love.graphics.setLineWidth(8)
                love.graphics.line(cx, cy, mx2, my2)
                -- Mid line
                love.graphics.setColor(1.0, 0.9, 0.4, 0.75)
                love.graphics.setLineWidth(3.5)
                love.graphics.line(cx, cy, mx2, my2)
                -- Core white line
                love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                love.graphics.setLineWidth(1.2)
                love.graphics.line(cx, cy, mx2, my2)
            end

            -- 4. Draw clock dial face
            love.graphics.setColor(0.08, 0.15, 0.12, 0.95)
            love.graphics.circle("fill", cx, cy, halfW * 0.95)

            -- 5. Draw 12 clock ticks (tick lines on dial edge)
            love.graphics.setLineWidth(1.8)
            love.graphics.setColor(col[1], col[2], col[3], 0.95)
            love.graphics.circle("line", cx, cy, halfW * 0.95)
            for tick = 1, 12 do
                local angle = (tick - 1) * (2 * math.pi / 12)
                local x1 = cx + math.cos(angle) * (halfW * 0.8)
                local y1 = cy + math.sin(angle) * (halfW * 0.8)
                local x2 = cx + math.cos(angle) * (halfW * 0.95)
                local y2 = cy + math.sin(angle) * (halfW * 0.95)
                love.graphics.line(x1, y1, x2, y2)
            end

            -- 6. Draw hour and minute hands revolving at different speeds
            -- Hour hand (slower)
            local hourAngle = game.time * 0.5
            if enemy.bossState == "time_sweep" then
                hourAngle = game.time * 1.5
            end
            local hx = cx + math.cos(hourAngle - math.pi / 2) * (halfW * 0.5)
            local hy = cy + math.sin(hourAngle - math.pi / 2) * (halfW * 0.5)
            love.graphics.setColor(col[1] * 0.8, col[2] * 1.2, col[3] * 0.9, 0.9)
            love.graphics.setLineWidth(3.0)
            love.graphics.line(cx, cy, hx, hy)

            -- Minute hand (faster)
            local minuteAngle = game.time * 4.0
            if enemy.bossState == "time_sweep" then
                minuteAngle = game.time * 5.0
            end
            local mx = cx + math.cos(minuteAngle - math.pi / 2) * (halfW * 0.75)
            local my = cy + math.sin(minuteAngle - math.pi / 2) * (halfW * 0.75)
            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.setLineWidth(1.8)
            love.graphics.line(cx, cy, mx, my)

            -- Center clock pin/pivot
            love.graphics.setColor(col[1], col[2], col[3], 0.95)
            love.graphics.circle("fill", cx, cy, 6)
            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.circle("fill", cx, cy, 2)

            love.graphics.setColor(1.0, 1.0, 1.0)
            love.graphics.setLineWidth(1)
        end
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
                love.graphics.arc("fill", 0, 0, bullet.size * 2.2, -math.pi/3, math.pi/3)
                
                love.graphics.setColor(0.25, 0.95, 0.75, 0.95)
                love.graphics.setLineWidth(2.2)
                love.graphics.arc("line", 0, 0, bullet.size * 2.2, -math.pi/3, math.pi/3)
                
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
