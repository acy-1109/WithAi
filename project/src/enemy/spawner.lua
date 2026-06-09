-- ============================================================================
-- spawner.lua — 적 스폰, 이동 AI, 피격 충돌 감지 및 처리 모듈
-- ============================================================================

local Collision = require("combat.collision")
local Enemy = {}

-- 적에게 피해를 입히고 체력이 0 이하가 되면 처치 및 경험치 구슬 생성 처리
function Enemy.damage(game, index, damage)
    local enemy = game.enemies[index]
    if not enemy then return false end

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
        -- 스테이지에 따라 다른 보스 정보 설정
        local bossName = "Void Overlord"
        local bossColor = {0.6, 0.1, 0.9} -- 보라
        local bossSize = 64
        local bossSpeed = 60
        local baseHealth = 12000 -- 1스테이지 보스 기본 체력
        local pointsVal = 500
        
        if (game.stage or 1) >= 2 then
            bossName = "Infernus Leviathan"
            bossColor = {1.0, 0.2, 0.1} -- 강렬한 빨강/주황
            bossSize = 80
            bossSpeed = 70
            baseHealth = 20000 -- 2스테이지 보스 기본 체력
            pointsVal = 1000
        end

        -- 보스 스폰 (플레이어 주변 화면 밖 450px 정도 위치에 스폰)
        local angle = math.random() * 2 * math.pi
        local spawnDist = 450
        local ex = player.x + player.width / 2 + math.cos(angle) * spawnDist - bossSize / 2
        local ey = player.y + player.height / 2 + math.sin(angle) * spawnDist - bossSize / 2
        
        -- 보스가 월드 경계 밖으로 나가지 않도록 킵
        ex = math.max(100, math.min(game.world.width - 200, ex))
        ey = math.max(100, math.min(game.world.height - 200, ey))
        
        local isStage2 = (game.stage or 1) >= 2
        local bBurstTimer = 5.0
        local bPetalTimer = nil
        local bRushTimer = 8.0
        if isStage2 then
            bPetalTimer = 6.0
            bRushTimer = 9.0
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
            stateTimer = 0,
            trailHistory = {}
        }
        table.insert(game.enemies, boss)
        game.bossActive = true
        game.bossMinionTimer = 0
        
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
                color = {1.0, 0.3, 0.3},
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
                local color = {1.0, 0.3, 0.3} -- 기본 빨강 (Normal)
                local points = 10
                local shootCooldown, shootTimer, shootRange = nil, nil, nil
                
                if enemyType == "charger" then
                    width, height = 22, 22
                    speed = 75 + math.random(0, 15)
                    maxHealth = (35 + (wave - 1) * 7) * stageMultiplier
                    hp = maxHealth
                    color = {0.1, 0.8, 1.0} -- 하늘색 (Charger)
                    points = 25
                elseif enemyType == "fast" then
                    width, height = 18, 18
                    speed = 130 + math.random(0, 30)
                    maxHealth = (20 + (wave - 1) * 4) * stageMultiplier
                    hp = maxHealth
                    color = {1.0, 0.6, 0.2} -- 주황 (Fast)
                    points = 15
                elseif enemyType == "tank" then
                    width, height = 36, 36
                    speed = 50 + math.random(0, 15)
                    maxHealth = (80 + (wave - 1) * 15) * stageMultiplier
                    hp = maxHealth
                    color = {0.8, 0.2, 0.6} -- 마젠타/자주 (Tank)
                    points = 30
                elseif enemyType == "ranged" then
                    width, height = 20, 20
                    speed = 70 + math.random(0, 20)
                    maxHealth = (25 + (wave - 1) * 6) * stageMultiplier
                    hp = maxHealth
                    color = {0.2, 0.8, 0.4} -- 녹색/청록 (Ranged)
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
            local col = {1.0, 0.3, 0.3}
            local pts = 10
            local sc, st, sr
            
            if minionType == "fast" then
                w, h = 18, 18
                spd = 140
                maxHp = 25
                col = {1.0, 0.6, 0.2}
                pts = 15
            elseif minionType == "ranged" then
                w, h = 20, 20
                spd = 80
                maxHp = 30
                col = {0.2, 0.8, 0.4}
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
        
        -- 플레이어 추적 및 뭉침 방지 (Separation)
        local dx = player.x - enemy.x
        local dy = player.y - enemy.y
        local dist = math.sqrt(dx * dx + dy * dy)

        local targetVelX = 0
        local targetVelY = 0

        if enemy.type == "boss" then
            local isStage2 = (game.stage or 1) >= 2
            enemy.bossState = enemy.bossState or "normal"
            enemy.stateTimer = enemy.stateTimer or 0
            enemy.trailHistory = enemy.trailHistory or {}

            if not isStage2 then
                -- ==========================================
                -- BOSS 1 (Void Overlord)
                -- ==========================================
                enemy.burstTimer = enemy.burstTimer or 5.0
                enemy.rushTimer = enemy.rushTimer or 8.0

                if enemy.bossState == "normal" then
                    enemy.burstTimer = enemy.burstTimer - dt
                    enemy.rushTimer = enemy.rushTimer - dt

                    if enemy.rushTimer <= 0 then
                        enemy.bossState = "charging_rush"
                        enemy.stateTimer = 0.6
                        local pCenterX, pCenterY = player.x + player.width/2, player.y + player.height/2
                        local bCenterX, bCenterY = enemy.x + enemy.width/2, enemy.y + enemy.height/2
                        local ldx, ldy = pCenterX - bCenterX, pCenterY - bCenterY
                        local ldist = math.sqrt(ldx * ldx + ldy * ldy)
                        if ldist > 0 then
                            enemy.rushDirX, enemy.rushDirY = ldx / ldist, ldy / ldist
                        else
                            enemy.rushDirX, enemy.rushDirY = 1, 0
                        end
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

                elseif enemy.bossState == "charging_rush" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    
                    local pCenterX, pCenterY = player.x + player.width/2, player.y + player.height/2
                    local bCenterX, bCenterY = enemy.x + enemy.width/2, enemy.y + enemy.height/2
                    local ldx, ldy = pCenterX - bCenterX, pCenterY - bCenterY
                    local ldist = math.sqrt(ldx * ldx + ldy * ldy)
                    if ldist > 0 then
                        enemy.rushDirX, enemy.rushDirY = ldx / ldist, ldy / ldist
                    end

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "rushing"
                        enemy.stateTimer = 1.2
                        enemy.mineTimer = 0
                    end

                elseif enemy.bossState == "rushing" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    local rushSpeed = 210
                    targetVelX = enemy.rushDirX * rushSpeed
                    targetVelY = enemy.rushDirY * rushSpeed

                    -- Periodically drop void mines
                    enemy.mineTimer = (enemy.mineTimer or 0) + dt
                    if enemy.mineTimer >= 0.08 then
                        enemy.mineTimer = 0
                        local bCenterX = enemy.x + enemy.width / 2
                        local bCenterY = enemy.y + enemy.height / 2
                        table.insert(game.enemyBullets, {
                            x = bCenterX,
                            y = bCenterY,
                            dirX = 0,
                            dirY = 0,
                            speed = 0,
                            damage = 0,
                            size = 14, -- larger rift bullet
                            maxDist = 9999,
                            distTraveled = 0,
                            type = "void_mine",
                            timer = 0.8
                        })
                    end

                    -- Record trail
                    enemy.trailTimer = (enemy.trailTimer or 0) + dt
                    if enemy.trailTimer >= 0.05 then
                        enemy.trailTimer = 0
                        table.insert(enemy.trailHistory, 1, {x = enemy.x, y = enemy.y})
                        if #enemy.trailHistory > 3 then table.remove(enemy.trailHistory) end
                    end

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "normal"
                        enemy.rushTimer = 8.0
                    end
                end
            else
                -- ==========================================
                -- BOSS 2 (Infernus Leviathan / Petal Boss)
                -- ==========================================
                enemy.petalTimer = enemy.petalTimer or 6.0
                enemy.rushTimer = enemy.rushTimer or 9.0

                if enemy.bossState == "normal" then
                    enemy.petalTimer = enemy.petalTimer - dt
                    enemy.rushTimer = enemy.rushTimer - dt

                    if enemy.rushTimer <= 0 then
                        enemy.bossState = "charging_rush"
                        enemy.stateTimer = 0.6
                        local pCenterX, pCenterY = player.x + player.width/2, player.y + player.height/2
                        local bCenterX, bCenterY = enemy.x + enemy.width/2, enemy.y + enemy.height/2
                        local ldx, ldy = pCenterX - bCenterX, pCenterY - bCenterY
                        local ldist = math.sqrt(ldx * ldx + ldy * ldy)
                        if ldist > 0 then
                            enemy.rushDirX, enemy.rushDirY = ldx / ldist, ldy / ldist
                        else
                            enemy.rushDirX, enemy.rushDirY = 1, 0
                        end
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
                        local pCenterX, pCenterY = player.x + player.width/2, player.y + player.height/2
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

                elseif enemy.bossState == "charging_rush" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    targetVelX, targetVelY = 0, 0
                    
                    local pCenterX, pCenterY = player.x + player.width/2, player.y + player.height/2
                    local bCenterX, bCenterY = enemy.x + enemy.width/2, enemy.y + enemy.height/2
                    local ldx, ldy = pCenterX - bCenterX, pCenterY - bCenterY
                    local ldist = math.sqrt(ldx * ldx + ldy * ldy)
                    if ldist > 0 then
                        enemy.rushDirX, enemy.rushDirY = ldx / ldist, ldy / ldist
                    end

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "rushing"
                        enemy.stateTimer = 1.2
                        enemy.patchTimer = 0
                    end

                elseif enemy.bossState == "rushing" then
                    enemy.stateTimer = enemy.stateTimer - dt
                    local rushSpeed = 280 -- faster dash for boss 2
                    targetVelX = enemy.rushDirX * rushSpeed
                    targetVelY = enemy.rushDirY * rushSpeed

                    -- Drop burning fire patches
                    enemy.patchTimer = (enemy.patchTimer or 0) + dt
                    if enemy.patchTimer >= 0.08 then
                        enemy.patchTimer = 0
                        local bCenterX = enemy.x + enemy.width / 2
                        local bCenterY = enemy.y + enemy.height / 2
                        table.insert(game.bossFirePatches, {
                            x = bCenterX,
                            y = bCenterY,
                            radius = 45,
                            duration = 3.5,
                            timer = 0,
                            tickTimer = 0
                        })
                    end

                    -- Record trail
                    enemy.trailTimer = (enemy.trailTimer or 0) + dt
                    if enemy.trailTimer >= 0.05 then
                        enemy.trailTimer = 0
                        table.insert(enemy.trailHistory, 1, {x = enemy.x, y = enemy.y})
                        if #enemy.trailHistory > 3 then table.remove(enemy.trailHistory) end
                    end

                    if enemy.stateTimer <= 0 then
                        enemy.bossState = "normal"
                        enemy.rushTimer = 9.0
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
                    
                    local pCenterX = player.x + player.width/2
                    local pCenterY = player.y + player.height/2
                    local eCenterX = enemy.x + enemy.width/2
                    local eCenterY = enemy.y + enemy.height/2
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
                    enemy.stateTimer = 0.6 -- Dash duration
                end
            elseif enemy.chargerState == "rushing" then
                enemy.stateTimer = enemy.stateTimer - dt
                local dashSpeed = 320
                targetVelX = enemy.rushDirX * dashSpeed
                targetVelY = enemy.rushDirY * dashSpeed
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
        
        if enemy.type ~= "boss" then
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
            else
                maxAllowedSpeed = enemy.speed * 1.3
            end
        elseif enemy.type == "charger" then
            if enemy.chargerState == "rushing" then
                maxAllowedSpeed = 320
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
        enemy.velX = enemy.velX + (targetVelX - enemy.velX) * turnSpeed * dt
        enemy.velY = enemy.velY + (targetVelY - enemy.velY) * turnSpeed * dt

        -- 위치 갱신
        enemy.x = enemy.x + enemy.velX * dt
        enemy.y = enemy.y + enemy.velY * dt

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

        -- 보스 사격 타이머 업데이트 및 부채꼴(3방향) 탄환 발사 (normal 상태일 때만)
        if enemy.type == "boss" and enemy.bossState == "normal" and dist <= (enemy.shootRange or 400) then
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
                elseif enemy.type == "charger" and enemy.chargerState == "rushing" then
                    dmg = 3  -- 돌격하는 돌진병 대미지 3!
                end
                player.health = player.health - dmg
                player.invincibleTime = player.maxInvincibleTime
                -- 체력 재생 타이머 리셋
                player.regenTimer = 0
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
            local pdx = (player.x + player.width/2) - patch.x
            local pdy = (player.y + player.height/2) - patch.y
            local distToPlayer = math.sqrt(pdx*pdx + pdy*pdy)
            
            if distToPlayer <= (patch.radius + player.width/2) then
                if player.invincibleTime <= 0 then
                    player.health = player.health - 6 -- 6 damage
                    player.invincibleTime = player.maxInvincibleTime
                    player.regenTimer = 0
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
                local angles = { 0, math.pi/2, math.pi, math.pi*1.5 }
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
            end
        else
            local moveDist = bullet.speed * dt
            bullet.x = bullet.x + bullet.dirX * moveDist
            bullet.y = bullet.y + bullet.dirY * moveDist
            bullet.distTraveled = bullet.distTraveled + moveDist
        end

        -- 플레이어 충돌 검사 (지뢰는 직접 충돌하지 않고 폭발로만 피해)
        if bullet.type ~= "void_mine" then
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
                    if player.health <= 0 then
                        game.running = false
                        game.state = "gameover"
                    end
                end
                if bullet.type ~= "petal" and bullet.type ~= "void_bullet" then
                    -- Petal and void bullets don't self-destruct on hit (or they can, but let's make them disappear)
                    table.remove(game.enemyBullets, i)
                else
                    -- For petals/void bullets, they dissolve on player contact
                    table.remove(game.enemyBullets, i)
                end
            elseif bullet.distTraveled >= bullet.maxDist then
                table.remove(game.enemyBullets, i)
            end
        end
    end
end

-- 적들의 렌더링
function Enemy.draw(game)
    for _, enemy in ipairs(game.enemies) do
        local col = enemy.color or {1.0, 0.3, 0.3}

        if enemy.type == "boss" then
            local isStage2 = (game.stage or 1) >= 2
            local cx = enemy.x + enemy.width / 2
            local cy = enemy.y + enemy.height / 2
            local halfW = enemy.width / 2
            local pulse = 1 + math.sin(game.time * 8) * 0.08

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
                    love.graphics.setColor(0.7, 0.1, 1.0, 0.75 + math.sin(game.time * 20) * 0.25) -- Void purple
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
                    love.graphics.circle("line", p.x + p.width/2, p.y + p.height/2, 16 + math.sin(game.time * 15) * 4)
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
            love.graphics.setColor(col[1]*1.2, col[2]*1.2, col[3]*1.2, 0.95)
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
            love.graphics.setColor(col[1]*1.2, col[2]*1.2, col[3]*1.2, 0.95)
            love.graphics.setLineWidth(1.8)
            love.graphics.polygon("line", 
                0, -r_tri, 
                r_tri * 0.866, r_tri * 0.5, 
                -r_tri * 0.866, r_tri * 0.5
            )
            love.graphics.pop()

            -- 7. Glowing nucleus eye in the center (synced with boss col)
            local eyePulse = 1 + math.sin(game.time * 12) * 0.15
            local eyeCol = {col[1]*1.2, col[2]*1.2, col[3]*1.2} -- Default synced eye color
            if enemy.bossState == "charging_rush" or enemy.bossState == "charging_burst" or enemy.bossState == "charging_petal" then
                eyeCol = {1.0, 0.4, 0.1} -- High-glow orange-yellow
                eyePulse = 1.2 + math.sin(game.time * 24) * 0.25
            elseif enemy.bossState == "rushing" then
                eyeCol = {1.0, 0.1, 0.1} -- Red during rush
            elseif enemy.bossState == "petalling" then
                eyeCol = {1.0, 0.25, 0.6} -- Bright pink/magenta eye during petal blizzard
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
            
            -- Reset color & line width just in case
            love.graphics.setColor(1.0, 1.0, 1.0)
            love.graphics.setLineWidth(1)
            
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
                    local laserLength = 500
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
                    love.graphics.polygon("fill", -halfW * 0.4, 0, -halfW * 1.5 * flamePulse, -halfW * 0.3, -halfW * 1.5 * flamePulse, halfW * 0.3)
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
                love.graphics.line(cx + math.sin(angle) * 3, cy - math.cos(angle) * 3, cx - math.cos(angle) * trailLen + math.sin(angle) * 3, cy - math.sin(angle) * trailLen - math.cos(angle) * 3)
                
                -- Arrowhead body
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(angle)
                
                love.graphics.setColor(0.14, 0.12, 0.16, 0.95)
                love.graphics.polygon("fill", halfW * 1.3, 0, -halfW * 0.9, halfW * 0.7, -halfW * 0.5, 0, -halfW * 0.9, -halfW * 0.7)
                
                love.graphics.setColor(col[1], col[2], col[3], 0.9)
                love.graphics.setLineWidth(1.5)
                love.graphics.polygon("line", halfW * 1.3, 0, -halfW * 0.9, halfW * 0.7, -halfW * 0.5, 0, -halfW * 0.9, -halfW * 0.7)
                
                -- Small thruster flame
                local flamePulse = 1 + math.sin(game.time * 25) * 0.25
                love.graphics.setColor(1.0, 0.85, 0.2, 0.8)
                love.graphics.polygon("fill", -halfW * 0.5, 0, -halfW * 1.1 * flamePulse, -halfW * 0.25, -halfW * 1.1 * flamePulse, halfW * 0.25)
                
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
