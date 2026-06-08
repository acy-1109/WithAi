-- ============================================================================
-- spawner.lua — 적 스폰, 이동 AI, 피격 충돌 감지 및 처리 모듈
-- ============================================================================

local Collision = require("combat.collision")
local Enemy = {}

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

    if wave == 7 then
        -- 보스 스폰 (플레이어 주변 화면 밖 450px 정도 위치에 스폰)
        local angle = math.random() * 2 * math.pi
        local spawnDist = 450
        local ex = player.x + player.width / 2 + math.cos(angle) * spawnDist - 32
        local ey = player.y + player.height / 2 + math.sin(angle) * spawnDist - 32
        
        -- 보스가 월드 경계 밖으로 나가지 않도록 킵
        ex = math.max(100, math.min(game.world.width - 200, ex))
        ey = math.max(100, math.min(game.world.height - 200, ey))
        
        local boss = {
            x = ex,
            y = ey,
            width = 64,
            height = 64,
            speed = 60,
            health = 2500,
            maxHealth = 2500,
            type = "boss",
            color = {0.6, 0.1, 0.9}, -- 보랏빛 네온 아우라
            name = "Void Overlord",
            points = 500,
            shootCooldown = 2.0,
            shootTimer = 1.0,
            shootRange = 400,
            velX = 0,
            velY = 0,
            bossState = "normal",
            burstTimer = 6.0,
            rushTimer = 9.0,
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
                health = 78,
                maxHealth = 78,
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
                if wave >= 5 then
                    if rand < 0.20 then
                        enemyType = "fast"
                    elseif rand < 0.40 then
                        enemyType = "ranged"
                    elseif rand < 0.60 then
                        enemyType = "tank"
                    end
                elseif wave >= 4 then
                    if rand < 0.20 then
                        enemyType = "fast"
                    elseif rand < 0.40 then
                        enemyType = "ranged"
                    end
                elseif wave >= 3 then
                    if rand < 0.25 then
                        enemyType = "fast"
                    end
                end
                
                local width, height = 24, 24
                local speed = 80 + math.random(0, 40)
                local maxHealth = 30 + (wave - 1) * 8
                local hp = maxHealth
                local color = {1.0, 0.3, 0.3} -- 기본 빨강 (Normal)
                local points = 10
                local shootCooldown, shootTimer, shootRange = nil, nil, nil
                
                if enemyType == "fast" then
                    width, height = 18, 18
                    speed = 130 + math.random(0, 30)
                    maxHealth = 20 + (wave - 1) * 4
                    hp = maxHealth
                    color = {1.0, 0.6, 0.2} -- 주황 (Fast)
                    points = 15
                elseif enemyType == "tank" then
                    width, height = 36, 36
                    speed = 50 + math.random(0, 15)
                    maxHealth = 80 + (wave - 1) * 15
                    hp = maxHealth
                    color = {0.8, 0.2, 0.6} -- 마젠타/자주 (Tank)
                    points = 30
                elseif enemyType == "ranged" then
                    width, height = 20, 20
                    speed = 70 + math.random(0, 20)
                    maxHealth = 25 + (wave - 1) * 6
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
                game.waveState = "cleared"
                game.waveTransitionTimer = 3.0
                game.bannerText = "BOSS DEFEATED! WAVE 7 CLEAR!"
                game.bannerTimer = 3.0
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
                health = maxHp,
                maxHealth = maxHp,
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
            -- Initialize state variables if not present
            enemy.bossState = enemy.bossState or "normal"
            enemy.burstTimer = enemy.burstTimer or 6.0
            enemy.rushTimer = enemy.rushTimer or 9.0
            enemy.stateTimer = enemy.stateTimer or 0
            enemy.trailHistory = enemy.trailHistory or {}
            
            -- State transitions and behaviors
            if enemy.bossState == "normal" then
                -- Reduce cooldown timers
                enemy.burstTimer = enemy.burstTimer - dt
                enemy.rushTimer = enemy.rushTimer - dt
                
                -- Check for transitions (Locked Rush takes priority if both ready)
                if enemy.rushTimer <= 0 then
                    enemy.bossState = "charging_rush"
                    enemy.stateTimer = 0.6 -- 0.6 seconds charge time
                    -- Lock laser direction to player center
                    local pCenterX = player.x + player.width / 2
                    local pCenterY = player.y + player.height / 2
                    local bCenterX = enemy.x + enemy.width / 2
                    local bCenterY = enemy.y + enemy.height / 2
                    local ldx = pCenterX - bCenterX
                    local ldy = pCenterY - bCenterY
                    local ldist = math.sqrt(ldx * ldx + ldy * ldy)
                    if ldist > 0 then
                        enemy.rushDirX = ldx / ldist
                        enemy.rushDirY = ldy / ldist
                    else
                        enemy.rushDirX = 1
                        enemy.rushDirY = 0
                    end
                elseif enemy.burstTimer <= 0 then
                    enemy.bossState = "charging_burst"
                    enemy.stateTimer = 0.8 -- 0.8 seconds charge time
                end
                
                -- Target velocity when normal: chase player
                if dist > 0 then
                    targetVelX = (dx / dist) * enemy.speed
                    targetVelY = (dy / dist) * enemy.speed
                end
                
                -- Clear trail history since not rushing
                if #enemy.trailHistory > 0 then
                    enemy.trailHistory = {}
                end
                
            elseif enemy.bossState == "charging_burst" then
                enemy.stateTimer = enemy.stateTimer - dt
                targetVelX = 0
                targetVelY = 0
                if enemy.stateTimer <= 0 then
                    -- Trigger Radial Burst: 12-way bullet ring
                    game.enemyBullets = game.enemyBullets or {}
                    local bCenterX = enemy.x + enemy.width / 2
                    local bCenterY = enemy.y + enemy.height / 2
                    for k = 0, 11 do
                        local angle = (k * 2 * math.pi) / 12
                        table.insert(game.enemyBullets, {
                            x = bCenterX,
                            y = bCenterY,
                            dirX = math.cos(angle),
                            dirY = math.sin(angle),
                            speed = 150,
                            damage = 18, -- Radial burst damage
                            size = 8,
                            maxDist = 600,
                            distTraveled = 0
                        })
                    end
                    enemy.bossState = "normal"
                    enemy.burstTimer = 6.0
                end
                
            elseif enemy.bossState == "charging_rush" then
                enemy.stateTimer = enemy.stateTimer - dt
                targetVelX = 0
                targetVelY = 0
                
                -- Keep locking laser to player position during charge for dynamic warning
                local pCenterX = player.x + player.width / 2
                local pCenterY = player.y + player.height / 2
                local bCenterX = enemy.x + enemy.width / 2
                local bCenterY = enemy.y + enemy.height / 2
                local ldx = pCenterX - bCenterX
                local ldy = pCenterY - bCenterY
                local ldist = math.sqrt(ldx * ldx + ldy * ldy)
                if ldist > 0 then
                    enemy.rushDirX = ldx / ldist
                    enemy.rushDirY = ldy / ldist
                end
                
                if enemy.stateTimer <= 0 then
                    enemy.bossState = "rushing"
                    enemy.stateTimer = 1.2 -- 1.2 seconds dash time
                end
                
            elseif enemy.bossState == "rushing" then
                enemy.stateTimer = enemy.stateTimer - dt
                -- Dash at high speed
                targetVelX = enemy.rushDirX * 210
                targetVelY = enemy.rushDirY * 210
                
                -- Record trail history for motion blur
                enemy.trailTimer = (enemy.trailTimer or 0) + dt
                if enemy.trailTimer >= 0.05 then
                    enemy.trailTimer = 0
                    table.insert(enemy.trailHistory, 1, {x = enemy.x, y = enemy.y})
                    if #enemy.trailHistory > 3 then
                        table.remove(enemy.trailHistory)
                    end
                end
                
                if enemy.stateTimer <= 0 then
                    enemy.bossState = "normal"
                    enemy.rushTimer = 9.0
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
                maxAllowedSpeed = 210
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
                enemy.health = enemy.health - orb.damage
                if enemy.health <= 0 then
                    game.score = game.score + (enemy.points or 10)
                    Exp.spawn(game, enemy.x + enemy.width / 2, enemy.y + enemy.height / 2)
                    table.remove(game.enemies, i)
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
                    enemy.health = enemy.health - thunder.damage
                    if enemy.health <= 0 then
                        game.score = game.score + (enemy.points or 10)
                        Exp.spawn(game, enemy.x + enemy.width / 2, enemy.y + enemy.height / 2)
                        table.remove(game.enemies, i)
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
                    enemy.health = enemy.health - blade.damage
                    if enemy.health <= 0 then
                        game.score = game.score + (enemy.points or 10)
                        Exp.spawn(game, enemy.x + enemy.width / 2, enemy.y + enemy.height / 2)
                        table.remove(game.enemies, i)
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
                    enemy.health = enemy.health - bullet.damage
                    
                    if not bullet.pierce then
                        bullet.toRemove = true
                    end
                    
                    if enemy.health <= 0 then
                        game.score = game.score + (enemy.points or 10)
                        Exp.spawn(game, enemy.x + enemy.width / 2, enemy.y + enemy.height / 2)
                        table.remove(game.enemies, i)
                        enemyRemoved = true
                        break
                    end
                end
            end
        end
    end

    -- 적 탄환 투사체 업데이트
    game.enemyBullets = game.enemyBullets or {}
    for i = #game.enemyBullets, 1, -1 do
        local bullet = game.enemyBullets[i]
        local moveDist = bullet.speed * dt
        bullet.x = bullet.x + bullet.dirX * moveDist
        bullet.y = bullet.y + bullet.dirY * moveDist
        bullet.distTraveled = bullet.distTraveled + moveDist

        -- 플레이어 충돌 검사
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
            table.remove(game.enemyBullets, i)
        elseif bullet.distTraveled >= bullet.maxDist then
            table.remove(game.enemyBullets, i)
        end
    end
end

-- 적들의 렌더링
function Enemy.draw(game)
    for _, enemy in ipairs(game.enemies) do
        local col = enemy.color or {1.0, 0.3, 0.3}

        if enemy.type == "boss" then
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
                    love.graphics.rotate(game.time * 2 + idx * 0.2)
                    -- Outer plates at trail position
                    for k = 1, 4 do
                        local angle = (k * math.pi / 2)
                        love.graphics.push()
                        love.graphics.rotate(angle)
                        love.graphics.rectangle("fill", -10, -halfW - 5, 20, 10, 2, 2)
                        love.graphics.pop()
                    end
                    -- Diamond core at trail position
                    love.graphics.rotate(-game.time * 4)
                    love.graphics.polygon("fill", 0, -halfW * 0.6, halfW * 0.6, 0, 0, halfW * 0.6, -halfW * 0.6, 0)
                    love.graphics.pop()
                end
            end

            -- 2. Warning indicator rings (charging_burst state)
            if enemy.bossState == "charging_burst" then
                -- Collapsing indicator ring
                local progress = enemy.stateTimer / 0.8
                love.graphics.setColor(1.0, 0.3, 0.3, 0.6)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", cx, cy, enemy.width * 1.5 * progress)
                -- Glowing outer ring
                love.graphics.setColor(1.0, 0.5, 0.5, 0.2)
                love.graphics.circle("fill", cx, cy, enemy.width * 1.5)
            end

            -- 3. Targeting laser beam line (charging_rush state)
            if enemy.bossState == "charging_rush" then
                love.graphics.setColor(1.0, 0.1, 0.1, 0.7 + math.sin(game.time * 20) * 0.2)
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

            -- 5. Rotating Outer Armor Plates (4 plates)
            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.rotate(game.time * 2) -- Clockwise rotation
            for k = 1, 4 do
                local angle = (k * math.pi / 2)
                love.graphics.push()
                love.graphics.rotate(angle)
                
                -- Plate fill
                love.graphics.setColor(0.15, 0.08, 0.25, 0.95)
                love.graphics.rectangle("fill", -12, -halfW - 6, 24, 12, 3, 3)
                
                -- Neon border for the plates
                love.graphics.setColor(col[1], col[2], col[3], 0.9)
                love.graphics.setLineWidth(1.5)
                love.graphics.rectangle("line", -12, -halfW - 6, 24, 12, 3, 3)
                
                love.graphics.pop()
            end
            love.graphics.pop()

            -- 6. Counter-rotating diamond body
            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.rotate(-game.time * 3) -- Counter-clockwise rotation
            
            -- Diamond body shape
            love.graphics.setColor(0.25, 0.12, 0.4, 0.9)
            love.graphics.polygon("fill", 0, -halfW * 0.65, halfW * 0.65, 0, 0, halfW * 0.65, -halfW * 0.65, 0)
            
            -- Neon border for diamond
            love.graphics.setColor(0.8, 0.3, 1.0, 0.95)
            love.graphics.setLineWidth(2)
            love.graphics.polygon("line", 0, -halfW * 0.65, halfW * 0.65, 0, 0, halfW * 0.65, -halfW * 0.65, 0)
            
            love.graphics.pop()

            -- 7. Glowing nucleus eye in the center
            local eyePulse = 1 + math.sin(game.time * 12) * 0.15
            -- Eye color changes to warning color when charging
            local eyeCol = {0.9, 0.2, 0.9} -- Default magenta/purple
            if enemy.bossState == "charging_rush" or enemy.bossState == "charging_burst" then
                eyeCol = {1.0, 0.4, 0.1} -- High-glow orange-yellow
                eyePulse = 1.2 + math.sin(game.time * 24) * 0.25
            elseif enemy.bossState == "rushing" then
                eyeCol = {1.0, 0.1, 0.1} -- Red during rush
            end
            
            love.graphics.setColor(eyeCol[1], eyeCol[2], eyeCol[3], 0.4)
            love.graphics.circle("fill", cx, cy, 14 * eyePulse)
            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.circle("fill", cx, cy, 6 * eyePulse)
            
            -- Reset color & line width just in case
            love.graphics.setColor(1.0, 1.0, 1.0)
            love.graphics.setLineWidth(1)
            
        else
            -- Standard enemy drawing
            love.graphics.setColor(col[1], col[2], col[3])
            love.graphics.rectangle("fill", enemy.x, enemy.y, enemy.width, enemy.height)
            
            -- 테두리 선 (가시성/입체감 증대)
            love.graphics.setColor(0.06, 0.06, 0.08, 0.8)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", enemy.x, enemy.y, enemy.width, enemy.height)
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

    -- 적 탄환 투사체 그리기 (빛나는 붉은 플라즈마 구체 효과)
    if game.enemyBullets then
        for _, bullet in ipairs(game.enemyBullets) do
            -- 외곽 오라 효과
            love.graphics.setColor(0.9, 0.1, 0.1, 0.3)
            love.graphics.circle("fill", bullet.x, bullet.y, bullet.size * 1.5)
            
            -- 내부 탄두 코어
            love.graphics.setColor(1.0, 0.3, 0.3)
            love.graphics.circle("fill", bullet.x, bullet.y, bullet.size / 2)
            
            -- 눈부신 백색 중심부
            love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
            love.graphics.circle("fill", bullet.x, bullet.y, bullet.size * 0.2)
        end
    end
end

return Enemy
