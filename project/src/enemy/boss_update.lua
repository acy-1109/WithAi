-- ============================================================================
-- boss_update.lua ??蹂댁뒪 AI ?곹깭 ?낅뜲?댄듃 紐⑤뱢 (spawner.lua?먯꽌 遺꾨━)
-- ============================================================================

local Collision = require("combat.collision")

local BossUpdate = {}

-- 媛??ㅽ뀒?댁?蹂?蹂댁뒪 ?낅뜲?댄듃 ?⑦꽩 ?ㅽ뻾
function BossUpdate.update(game, enemy, dt, dx, dy, dist, player)
    local targetVelX = 0
    local targetVelY = 0

    local currentStage = enemy.bossStageNum or game.stage or 1
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

                    -- Check which clone slots are already occupied by alive clones
                    local slotOccupied = { [1] = false, [2] = false, [3] = false }
                    for _, other in ipairs(game.enemies) do
                        if other.type == "boss_clone" and other.parentBoss == enemy then
                            if other.cloneSlot and slotOccupied[other.cloneSlot] ~= nil then
                                slotOccupied[other.cloneSlot] = true
                            end
                        end
                    end

                    -- Spawn missing phantom clones radially in empty slots
                    local bCenterX = enemy.x + enemy.width / 2
                    local bCenterY = enemy.y + enemy.height / 2
                    local spawnRadius = 100
                    for slot = 1, 3 do
                        if not slotOccupied[slot] then
                            local angle = (slot - 1) * (2 * math.pi / 3) + math.random() * 0.5
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
                                health = 3000 * stageMultiplier,
                                maxHealth = 3000 * stageMultiplier,
                                type = "boss_clone",
                                color = { 0.25, 0.95, 0.75 },
                                points = 50,
                                velX = 0,
                                velY = 0,
                                parentBoss = enemy,
                                cloneSlot = slot
                            })
                        end
                    end
                elseif enemy.nextPattern == "crossfire" then
                    enemy.bossState = "charging_crossfire"
                    enemy.stateTimer = 1.0

                    -- Position main boss and all alive clones in 4 quadrants around player
                    local pCenterX = player.x + player.width / 2
                    local pCenterY = player.y + player.height / 2
                    local group = { enemy }
                    for _, other in ipairs(game.enemies) do
                        if other.type == "boss_clone" and other.parentBoss == enemy then
                            table.insert(group, other)
                        end
                    end

                    -- [NEW] 원래 위치 잔상(Echoes) 생성
                    game.teleportEchoes = game.teleportEchoes or {}
                    for _, member in ipairs(group) do
                        table.insert(game.teleportEchoes, {
                            x = member.x,
                            y = member.y,
                            width = member.width,
                            height = member.height,
                            color = member.color or { 0.25, 0.95, 0.75 },
                            alpha = 0.8,
                            life = 0.4,
                            maxLife = 0.4,
                            type = member.type
                        })
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

                        -- [NEW] 목적지 글리치 파티클 생성 및 페이드 타이머 설정
                        member.teleportFade = 0.3
                        game.teleportParticles = game.teleportParticles or {}
                        local mCenterX = member.x + member.width / 2
                        local mCenterY = member.y + member.height / 2
                        local pCount = 12
                        for k = 1, pCount do
                            local pAngle = (k - 1) * (2 * math.pi / pCount) + math.random() * 0.3
                            local pSpeed = 80 + math.random() * 100
                            table.insert(game.teleportParticles, {
                                x = mCenterX,
                                y = mCenterY,
                                vx = math.cos(pAngle) * pSpeed,
                                vy = math.sin(pAngle) * pSpeed,
                                life = 0.4 + math.random() * 0.2,
                                maxLife = 0.6,
                                size = 3 + math.random() * 4,
                                color = member.color or { 0.25, 0.95, 0.75 }
                            })
                        end

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
                if other.type == "boss_clone" and other.parentBoss == enemy then
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
                    if other.type == "boss_clone" and other.parentBoss == enemy then
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
                        pylonIndex = pIdx,
                        parentBoss = enemy
                    })
                end
                enemy.bossState = "tesla_pylons_active"
                enemy.pylonAngle = angle
            end
        elseif enemy.bossState == "tesla_pylons_active" then
            -- Count active pylons
            local activePylons = 0
            for _, other in ipairs(game.enemies) do
                if other.type == "tesla_pylon" and other.parentBoss == enemy then
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
                local rotationSpeed = 1.5
                for _, other in ipairs(game.enemies) do
                    if other.type == "tesla_pylon" and other.parentBoss == enemy then
                        if other.slowTimer and other.slowTimer > 0 then
                            rotationSpeed = 1.5 * (other.slowMultiplier or 0.5)
                        end
                        break
                    end
                end
                enemy.pylonAngle = (enemy.pylonAngle or 0) + rotationSpeed * dt
                local bCenterX = enemy.x + enemy.width / 2
                local bCenterY = enemy.y + enemy.height / 2
                for _, other in ipairs(game.enemies) do
                    if other.type == "tesla_pylon" and other.parentBoss == enemy then
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
                            if Collision.checkLineCircle(bCenterX, bCenterY, pyCenterX, pyCenterY, pCenterX, pCenterY, player.width / 2 + 6) then
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
        local shieldRotationSpeed = 0.9
        for _, other in ipairs(game.enemies) do
            if other.type == "aegis_shield" and other.parentBoss == enemy then
                if other.slowTimer and other.slowTimer > 0 then
                    shieldRotationSpeed = 0.9 * (other.slowMultiplier or 0.5)
                end
                break
            end
        end
        enemy.shieldAngle = (enemy.shieldAngle or 0) + shieldRotationSpeed * dt
        enemy.laserAngle = enemy.laserAngle or 0

        -- Calculate center of the boss
        local bCenterX = enemy.x + enemy.width / 2
        local bCenterY = enemy.y + enemy.height / 2

        -- Count active shields
        local activeShields = 0
        for _, other in ipairs(game.enemies) do
            if other.type == "aegis_shield" and other.parentBoss == enemy then
                activeShields = activeShields + 1
            end
        end

        -- Transition immediately to recharging if all shields are destroyed and we are not recharging
        if activeShields == 0 and enemy.bossState ~= "recharging" then
            enemy.bossState = "recharging"
            enemy.stateTimer = 3.0
            enemy.speed = 0
            enemy.shieldStartPos = nil
            enemy.shieldStrikePhase = nil
        end

        if enemy.bossState == "normal" then
            enemy.patternTimer = enemy.patternTimer - dt
            if enemy.patternTimer <= 0 then
                if enemy.nextPattern == "laser_grid" then
                    enemy.bossState = "laser_grid"
                    enemy.stateTimer = 6.0
                elseif enemy.nextPattern == "shield_strike" then
                    enemy.bossState = "shield_strike"
                    enemy.stateTimer = 3.5
                    enemy.shieldStrikePhase = "charge"
                    enemy.shieldStrikeTimer = 0
                    enemy.shieldStartPos = nil
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
                    if Collision.checkLineCircle(bCenterX, bCenterY, lx2, ly2, pCenterX, pCenterY, player.width / 2 + 4) then
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
                enemy.nextPattern = "shield_strike"
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
        elseif enemy.bossState == "shield_strike" then
            enemy.stateTimer = enemy.stateTimer - dt
            targetVelX, targetVelY = 0, 0
            enemy.velX, enemy.velY = 0, 0

            enemy.shieldStrikeTimer = (enemy.shieldStrikeTimer or 0) + dt

            -- 1. Charge Phase (0.0s to 1.0s)
            if enemy.shieldStrikeTimer < 1.0 then
                enemy.shieldStrikePhase = "charge"
                enemy.strikeTargetX = player.x + player.width / 2
                enemy.strikeTargetY = player.y + player.height / 2

                -- 2. Strike Phase (1.0s to 2.0s)
            elseif enemy.shieldStrikeTimer < 2.0 then
                enemy.shieldStrikePhase = "strike"
                if not enemy.shieldStartPos then
                    enemy.shieldStartPos = {}
                    for _, other in ipairs(game.enemies) do
                        if other.type == "aegis_shield" and other.parentBoss == enemy then
                            local idx = other.shieldIndex or 1
                            enemy.shieldStartPos[idx] = { x = other.x, y = other.y }
                        end
                    end
                end

                -- 3. Return Phase (2.0s to 3.2s)
            elseif enemy.shieldStrikeTimer < 3.2 then
                enemy.shieldStrikePhase = "return"

                -- 4. End State
            else
                enemy.shieldStartPos = nil
                enemy.shieldStrikePhase = nil
                enemy.bossState = "normal"
                enemy.patternTimer = 5.0
                enemy.nextPattern = "orbital_strike"
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
                        health = 800 * stageMultiplier,
                        maxHealth = 800 * stageMultiplier,
                        type = "aegis_shield",
                        color = { 1.0, 0.8, 0.1 },
                        points = 150,
                        velX = 0,
                        velY = 0,
                        shieldIndex = i,
                        parentBoss = enemy
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
        local shieldPhase = enemy.shieldStrikePhase or "normal"
        local strikeTimer = enemy.shieldStrikeTimer or 0
        local targetX = (enemy.strikeTargetX or 0) - 12
        local targetY = (enemy.strikeTargetY or 0) - 12

        for _, other in ipairs(game.enemies) do
            if other.type == "aegis_shield" and other.parentBoss == enemy then
                local idx = other.shieldIndex or 1
                local angle = enemy.shieldAngle + (idx - 1) * (math.pi / 2)
                local ox = bCenterX + math.cos(angle) * 120 - 12
                local oy = bCenterY + math.sin(angle) * 120 - 12

                if enemy.bossState == "shield_strike" then
                    if shieldPhase == "charge" then
                        other.x = ox
                        other.y = oy
                    elseif shieldPhase == "strike" then
                        local t = math.max(0, math.min(1, strikeTimer - 1.0))
                        local startPos = (enemy.shieldStartPos and enemy.shieldStartPos[idx]) or { x = ox, y = oy }
                        other.x = startPos.x + (targetX - startPos.x) * t
                        other.y = startPos.y + (targetY - startPos.y) * t
                    elseif shieldPhase == "return" then
                        local t = math.max(0, math.min(1, (strikeTimer - 2.0) / 1.2))
                        other.x = targetX + (ox - targetX) * t
                        other.y = targetY + (oy - targetY) * t
                    else
                        other.x = ox
                        other.y = oy
                    end
                else
                    other.x = ox
                    other.y = oy
                end
            end
        end
    elseif currentStage == 6 then
        -- ==========================================
        -- BOSS 6 (Chronos Weaver)
        -- ==========================================
        enemy.patternTimer = enemy.patternTimer or 6.0
        enemy.nextPattern = enemy.nextPattern or "time_burst"
        enemy.timeTrail = enemy.timeTrail or {}
        enemy.timeStopBullets = enemy.timeStopBullets or {}

        local bCenterX = enemy.x + enemy.width / 2
        local bCenterY = enemy.y + enemy.height / 2

        if enemy.bossState == "normal" then
            enemy.patternTimer = enemy.patternTimer - dt

            -- Record history coordinates and health (up to 180 entries = 3 seconds at 60fps)
            table.insert(enemy.timeTrail, 1, { x = enemy.x, y = enemy.y, health = enemy.health })
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
                elseif enemy.nextPattern == "time_stop" then
                    enemy.bossState = "time_stop"
                    enemy.stateTimer = 3.5
                    enemy.timeStopPhase = "charging"
                    enemy.timeStopTimer = 0
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

            -- Minute hand laser (sweeps faster) - Slows player upon contact
            local minuteAngle = (game.time * 5.0) - math.pi / 2
            local mx2 = bCenterX + math.cos(minuteAngle) * 900
            local my2 = bCenterY + math.sin(minuteAngle) * 900

            if Collision.checkLineCircle(bCenterX, bCenterY, mx2, my2, pCenterX, pCenterY, player.width / 2 + 8) then
                player.timeSlowTimer = 2.0   -- 2 seconds time slow debuff
                player.speedMultiplier = 0.4 -- instant slow
            end

            -- Hour hand laser (sweeps slowly) - Deals heavy damage
            local hourAngle = (game.time * 1.5) - math.pi / 2
            local hx2 = bCenterX + math.cos(hourAngle) * 900
            local hy2 = bCenterY + math.sin(hourAngle) * 900
            if Collision.checkLineCircle(bCenterX, bCenterY, hx2, hy2, pCenterX, pCenterY, player.width / 2 + 12) then
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
                enemy.nextPattern = "time_stop"
            end
        elseif enemy.bossState == "time_stop" then
            enemy.stateTimer = enemy.stateTimer - dt
            enemy.timeStopTimer = (enemy.timeStopTimer or 0) + dt
            targetVelX, targetVelY = 0, 0
            enemy.velX, enemy.velY = 0, 0

            local pCenterX = player.x + player.width / 2
            local pCenterY = player.y + player.height / 2

            -- Phase 1: Charging (0.0s to 1.0s) - 시간 정지 시전
            if enemy.timeStopTimer < 1.0 then
                enemy.timeStopPhase = "charging"
                -- 시간 정지 경고 효과

                -- Phase 2: Time Stop Active (1.0s to 2.5s) - 플레이어 정지 및 탄환 생성
            elseif enemy.timeStopTimer < 2.5 then
                enemy.timeStopPhase = "active"

                -- 플레이어 완전 정지
                player.speedMultiplier = 0
                player.timeStopActive = true

                -- 플레이어 근처에 탄환 위치만 저장 (0.5초 후부터)
                if enemy.timeStopTimer > 1.5 and not enemy.timeStopBulletsSpawned then
                    enemy.timeStopBulletsSpawned = true
                    enemy.timeStopBullets = {}

                    local bulletCount = 12
                    local skipIndex = math.random(1, bulletCount)             -- 랜덤하게 하나 건너뜀
                    local oppositeIndex = ((skipIndex + 5) % bulletCount) + 1 -- 마주보는 탄환 인덱스
                    local spawnRadius = 150
                    for i = 1, bulletCount do
                        if i ~= skipIndex and i ~= oppositeIndex then -- 하나와 마주보는 탄환은 생성하지 않음
                            local angle = (i - 1) * (2 * math.pi / bulletCount)
                            local bx = pCenterX + math.cos(angle) * spawnRadius
                            local by = pCenterY + math.sin(angle) * spawnRadius

                            -- 위치만 저장, 실제 탄환은 release 단계에서 생성
                            table.insert(enemy.timeStopBullets, {
                                x = bx,
                                y = by,
                                targetX = pCenterX,
                                targetY = pCenterY,
                                speed = 350,
                                damage = 18,
                                size = 10,
                                maxDist = 600
                            })
                        end
                    end
                end

                -- Phase 3: Release (2.5s to 3.5s) - 시간 정지 해제 및 탄환 발사
            else
                enemy.timeStopPhase = "release"

                -- 시간 정지 해제
                player.speedMultiplier = 1.0
                player.timeStopActive = false

                -- 저장된 위치 정보를 사용하여 실제 탄환 생성
                if enemy.timeStopBulletsSpawned and enemy.timeStopBullets then
                    for _, bulletData in ipairs(enemy.timeStopBullets) do
                        local dx = bulletData.targetX - bulletData.x
                        local dy = bulletData.targetY - bulletData.y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        local dirX = dx / dist
                        local dirY = dy / dist

                        table.insert(game.enemyBullets, {
                            x = bulletData.x,
                            y = bulletData.y,
                            dirX = dirX,
                            dirY = dirY,
                            speed = bulletData.speed,
                            damage = bulletData.damage,
                            size = bulletData.size,
                            maxDist = bulletData.maxDist,
                            distTraveled = 0,
                            type = "time_stop_bullet"
                        })
                    end
                    enemy.timeStopBullets = {}
                    enemy.timeStopBulletsSpawned = false
                end
            end

            if enemy.stateTimer <= 0 then
                enemy.bossState = "normal"
                enemy.patternTimer = 6.0
                enemy.nextPattern = "time_burst"
                enemy.timeStopPhase = nil
                enemy.timeStopTimer = nil
                enemy.timeStopBullets = nil
                enemy.timeStopBulletsSpawned = nil
                -- 플레이어 상태 복구
                player.speedMultiplier = 1.0
                player.timeStopActive = false
            end
        end
    elseif currentStage == 7 then
        -- ==========================================
        -- BOSS 7 (Glitch Overlord)
        -- ==========================================
        local stageMultiplier = 1.0 + ((game.stage or 1) - 1) * 0.5
        enemy.patternTimer = enemy.patternTimer or 5.0
        enemy.nextPattern = enemy.nextPattern or "system_hack"

        local bCenterX = enemy.x + enemy.width / 2
        local bCenterY = enemy.y + enemy.height / 2

        if enemy.bossState == "normal" then
            enemy.patternTimer = enemy.patternTimer - dt

            if enemy.patternTimer <= 0 then
                if enemy.nextPattern == "system_hack" then
                    enemy.bossState = "system_hack"
                    enemy.stateTimer = 1.2
                elseif enemy.nextPattern == "corrupt_clone" then
                    enemy.bossState = "corrupt_clone"
                    enemy.stateTimer = 1.0
                elseif enemy.nextPattern == "memory_overflow" then
                    enemy.bossState = "memory_overflow"
                    enemy.stateTimer = 1.5
                end
            end

            -- Chase player
            if dist > 0 then
                targetVelX = (dx / dist) * enemy.speed
                targetVelY = (dy / dist) * enemy.speed
            end
        elseif enemy.bossState == "system_hack" then
            enemy.stateTimer = enemy.stateTimer - dt
            targetVelX, targetVelY = 0, 0
            enemy.velX, enemy.velY = 0, 0

            if enemy.stateTimer <= 0 then
                -- 플레이어 위치 판정 (400px 이내)
                if dist <= 400 then
                    player.controlsInvertedTimer = 2.5
                    if player.invincibleTime <= 0 then
                        player.health = player.health - 5
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
                enemy.bossState = "normal"
                enemy.patternTimer = 4.0
                enemy.nextPattern = "corrupt_clone"
            end
        elseif enemy.bossState == "corrupt_clone" then
            enemy.stateTimer = enemy.stateTimer - dt
            targetVelX, targetVelY = 0, 0
            enemy.velX, enemy.velY = 0, 0

            if enemy.stateTimer <= 0 then
                -- 플레이어 위치에 분신 스폰
                table.insert(game.enemies, {
                    x = player.x + player.width / 2 - 24,
                    y = player.y + player.height / 2 - 24,
                    width = 48,
                    height = 48,
                    speed = 0,
                    health = 4000 * stageMultiplier,
                    maxHealth = 4000 * stageMultiplier,
                    type = "glitch_clone",
                    color = { 0.1, 0.9, 0.9 },
                    points = 100,
                    shootCooldown = 0.4,
                    shootTimer = 0.2,
                    shootRange = 500,
                    lifeTimer = 3.0,
                    velX = 0,
                    velY = 0
                })
                enemy.bossState = "normal"
                enemy.patternTimer = 4.0
                enemy.nextPattern = "memory_overflow"
            end
        elseif enemy.bossState == "memory_overflow" then
            enemy.stateTimer = enemy.stateTimer - dt
            targetVelX, targetVelY = 0, 0
            enemy.velX, enemy.velY = 0, 0

            if enemy.stateTimer <= 0 then
                enemy.bossState = "overflow_firing"
                enemy.stateTimer = 4.0
                enemy.fireTimer = 0
            end
        elseif enemy.bossState == "overflow_firing" then
            enemy.stateTimer = enemy.stateTimer - dt
            targetVelX, targetVelY = 0, 0
            enemy.velX, enemy.velY = 0, 0

            enemy.fireTimer = (enemy.fireTimer or 0) - dt
            if enemy.fireTimer <= 0 then
                enemy.fireTimer = 0.12
                game.enemyBullets = game.enemyBullets or {}
                local baseAngle = game.time * 6.5
                local texts = { "ERROR", "FATAL", "404", "NULL", "VOID" }
                for k = 1, 4 do
                    local angle = baseAngle + (k - 1) * (math.pi / 2)
                    table.insert(game.enemyBullets, {
                        x = bCenterX,
                        y = bCenterY,
                        dirX = math.cos(angle),
                        dirY = math.sin(angle),
                        speed = 200,
                        damage = 12,
                        size = 8,
                        maxDist = 600,
                        distTraveled = 0,
                        type = "error_code",
                        text = texts[math.random(1, #texts)],
                        colorIndex = math.random(0, 2)
                    })
                end
            end

            if enemy.stateTimer <= 0 then
                enemy.bossState = "normal"
                enemy.patternTimer = 5.0
                enemy.nextPattern = "system_hack"
            end
        end
    elseif currentStage == 8 then
        -- ==========================================
        -- BOSS 8 (Singularity Nexus)
        -- ==========================================
        local stageMultiplier = 1.0 + ((game.stage or 1) - 1) * 0.5
        enemy.patternTimer = enemy.patternTimer or 5.0
        enemy.nextPattern = enemy.nextPattern or "gravity_well"

        local bCenterX = enemy.x + enemy.width / 2
        local bCenterY = enemy.y + enemy.height / 2

        if enemy.bossState == "normal" then
            enemy.patternTimer = enemy.patternTimer - dt

            if enemy.patternTimer <= 0 then
                if enemy.nextPattern == "gravity_well" then
                    enemy.bossState = "gravity_well"
                    enemy.stateTimer = 1.5
                elseif enemy.nextPattern == "event_horizon" then
                    enemy.bossState = "event_horizon"
                    enemy.stateTimer = 1.2
                elseif enemy.nextPattern == "phase_shift" then
                    enemy.bossState = "phase_shift"
                    enemy.stateTimer = 1.0
                end
            end

            -- Chase player
            if dist > 0 then
                targetVelX = (dx / dist) * enemy.speed
                targetVelY = (dy / dist) * enemy.speed
            end
        elseif enemy.bossState == "gravity_well" then
            enemy.stateTimer = enemy.stateTimer - dt
            targetVelX, targetVelY = 0, 0
            enemy.velX, enemy.velY = 0, 0

            if enemy.stateTimer <= 0 then
                enemy.bossState = "gravity_pulling"
                enemy.stateTimer = 4.0
            end
        elseif enemy.bossState == "gravity_pulling" then
            enemy.stateTimer = enemy.stateTimer - dt

            -- Move slowly
            if dist > 0 then
                targetVelX = (dx / dist) * 30
                targetVelY = (dy / dist) * 30
            end

            -- Pull player towards boss center at 150 px/s
            local pCenterX = player.x + player.width / 2
            local pCenterY = player.y + player.height / 2
            local pdx = bCenterX - pCenterX
            local pdy = bCenterY - pCenterY
            local pdist = math.sqrt(pdx * pdx + pdy * pdy)
            if pdist > 15 then
                player.x = player.x + (pdx / pdist) * 150 * dt
                player.y = player.y + (pdy / pdist) * 150 * dt
            end

            -- Curve player's bullets/projectiles towards the boss
            local pullStrength = 350 * dt
            if game.bullets then
                for _, bullet in ipairs(game.bullets) do
                    local bdx = bCenterX - bullet.x
                    local bdy = bCenterY - bullet.y
                    local bdist = math.sqrt(bdx * bdx + bdy * bdy)
                    if bdist > 10 then
                        local pullX = (bdx / bdist) * pullStrength
                        local pullY = (bdy / bdist) * pullStrength
                        bullet.dirX = bullet.dirX + pullX
                        bullet.dirY = bullet.dirY + pullY
                        local len = math.sqrt(bullet.dirX * bullet.dirX + bullet.dirY * bullet.dirY)
                        if len > 0 then
                            bullet.dirX = bullet.dirX / len
                            bullet.dirY = bullet.dirY / len
                        end
                    end
                end
            end

            if enemy.stateTimer <= 0 then
                enemy.bossState = "normal"
                enemy.patternTimer = 5.0
                enemy.nextPattern = "event_horizon"
            end
        elseif enemy.bossState == "event_horizon" then
            enemy.stateTimer = enemy.stateTimer - dt
            targetVelX, targetVelY = 0, 0
            enemy.velX, enemy.velY = 0, 0

            if enemy.stateTimer <= 0 then
                enemy.bossState = "horizon_contracting"
                enemy.stateTimer = 3.0
                enemy.ringsPassed = { false, false, false }
            end
        elseif enemy.bossState == "horizon_contracting" then
            enemy.stateTimer = enemy.stateTimer - dt
            targetVelX, targetVelY = 0, 0
            enemy.velX, enemy.velY = 0, 0

            local pCenterX = player.x + player.width / 2
            local pCenterY = player.y + player.height / 2
            local pdx = pCenterX - bCenterX
            local pdy = pCenterY - bCenterY
            local pdist = math.sqrt(pdx * pdx + pdy * pdy)

            local ringStartRadii = { 1000, 1300, 1600 }
            for k = 1, 3 do
                local ringRadius = ringStartRadii[k] * (enemy.stateTimer / 3.0)
                if ringRadius < pdist and not enemy.ringsPassed[k] then
                    enemy.ringsPassed[k] = true
                    local playerAngle = math.atan2(pCenterY - bCenterY, pCenterX - bCenterX)
                    local gapAngle = (game.time * 1.5) % (2 * math.pi)
                    local diff = math.abs((playerAngle - gapAngle + math.pi) % (2 * math.pi) - math.pi)
                    if diff > 0.4 then -- player is NOT in the gap!
                        if player.invincibleTime <= 0 then
                            player.health = player.health - 12
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
                end
            end

            if enemy.stateTimer <= 0 then
                enemy.bossState = "normal"
                enemy.patternTimer = 5.0
                enemy.nextPattern = "phase_shift"
                enemy.ringsPassed = nil
            end
        elseif enemy.bossState == "phase_shift" then
            enemy.stateTimer = enemy.stateTimer - dt
            targetVelX, targetVelY = 0, 0
            enemy.velX, enemy.velY = 0, 0

            if enemy.stateTimer <= 0 then
                enemy.bossState = "shifting_invulnerable"
                enemy.invulnerable = true

                -- Spawn 3 void anchors in a triangle around the boss
                local numAnchors = 3
                local spawnRadius = 200
                for aIdx = 1, numAnchors do
                    local angle = (aIdx - 1) * (2 * math.pi / numAnchors)
                    local ax = bCenterX + math.cos(angle) * spawnRadius - 16
                    local ay = bCenterY + math.sin(angle) * spawnRadius - 16
                    table.insert(game.enemies, {
                        x = ax,
                        y = ay,
                        width = 32,
                        height = 32,
                        speed = 0,
                        health = 3000 * stageMultiplier,
                        maxHealth = 3000 * stageMultiplier,
                        type = "void_anchor",
                        color = { 0.8, 0.2, 0.9 },
                        points = 200,
                        velX = 0,
                        velY = 0,
                        parentBoss = enemy
                    })
                end
            end
        elseif enemy.bossState == "shifting_invulnerable" then
            targetVelX, targetVelY = 0, 0
            enemy.velX, enemy.velY = 0, 0

            -- Count active anchors
            local activeAnchors = 0
            for _, other in ipairs(game.enemies) do
                if other.type == "void_anchor" and other.parentBoss == enemy then
                    activeAnchors = activeAnchors + 1
                end
            end

            if activeAnchors == 0 then
                enemy.invulnerable = false
                enemy.bossState = "normal"
                enemy.patternTimer = 5.0
                enemy.nextPattern = "gravity_well"
            end
        end
    elseif currentStage >= 9 then
        -- ==========================================
        -- BOSS 9 (Nebula Seraph)
        -- ==========================================
        local stageMultiplier = 1.0 + ((game.stage or 1) - 1) * 0.5
        enemy.patternTimer = enemy.patternTimer or 5.0
        enemy.nextPattern = enemy.nextPattern or "supernova"

        if enemy.supernovaExplodeTimer then
            enemy.supernovaExplodeTimer = enemy.supernovaExplodeTimer - dt
            if enemy.supernovaExplodeTimer <= 0 then
                enemy.supernovaExplodeTimer = nil
            end
        end

        local bCenterX = enemy.x + enemy.width / 2
        local bCenterY = enemy.y + enemy.height / 2

        if enemy.bossState == "normal" then
            enemy.patternTimer = enemy.patternTimer - dt

            if enemy.patternTimer <= 0 then
                if enemy.nextPattern == "supernova" then
                    enemy.bossState = "supernova"
                    enemy.stateTimer = 3.0
                    -- Spawn shelter circle at random position
                    local angle = math.random() * 2 * math.pi
                    local shelterDist = math.random(150, 300)
                    enemy.shelterX = bCenterX + math.cos(angle) * shelterDist
                    enemy.shelterY = bCenterY + math.sin(angle) * shelterDist
                    enemy.shelterRadius = 90
                elseif enemy.nextPattern == "binary_star" then
                    enemy.bossState = "binary_star"
                    enemy.stateTimer = 1.2
                elseif enemy.nextPattern == "meteor_storm" then
                    enemy.bossState = "meteor_storm"
                    enemy.stateTimer = 1.5
                end
            end

            -- Chase player
            if dist > 0 then
                targetVelX = (dx / dist) * enemy.speed
                targetVelY = (dy / dist) * enemy.speed
            end
        elseif enemy.bossState == "supernova" then
            enemy.stateTimer = enemy.stateTimer - dt
            targetVelX, targetVelY = 0, 0
            enemy.velX, enemy.velY = 0, 0

            if enemy.stateTimer <= 0 then
                -- Supernova blast detonation!
                local pCenterX = player.x + player.width / 2
                local pCenterY = player.y + player.height / 2
                local pdx = pCenterX - (enemy.shelterX or 0)
                local pdy = pCenterY - (enemy.shelterY or 0)
                local distToShelter = math.sqrt(pdx * pdx + pdy * pdy)

                if distToShelter > (enemy.shelterRadius or 90) then
                    if player.invincibleTime <= 0 then
                        player.health = player.health - 70
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

                -- Huge screen shake & explosion effect trigger
                game.shakeTimer = 0.6
                game.shakeIntensity = 15
                enemy.supernovaExplodeTimer = 0.5
                enemy.supernovaExplodeX = bCenterX
                enemy.supernovaExplodeY = bCenterY

                enemy.shelterX = nil
                enemy.shelterY = nil

                enemy.bossState = "normal"
                enemy.patternTimer = 5.0
                enemy.nextPattern = "binary_star"
            end
        elseif enemy.bossState == "binary_star" then
            enemy.stateTimer = enemy.stateTimer - dt
            targetVelX, targetVelY = 0, 0
            enemy.velX, enemy.velY = 0, 0

            if enemy.stateTimer <= 0 then
                enemy.bossState = "binary_laser"
                enemy.stateTimer = 5.0
                enemy.binaryAngle = 0
            end
        elseif enemy.bossState == "binary_laser" then
            enemy.stateTimer = enemy.stateTimer - dt

            -- Move slowly
            if dist > 0 then
                targetVelX = (dx / dist) * 35
                targetVelY = (dy / dist) * 35
            end

            enemy.binaryAngle = (enemy.binaryAngle or 0) + 1.2 * dt

            -- Laser collision check: revolve line laser passing through boss center
            if player.invincibleTime <= 0 then
                local pCenterX = player.x + player.width / 2
                local pCenterY = player.y + player.height / 2
                local lx1 = bCenterX - math.cos(enemy.binaryAngle) * 900
                local ly1 = bCenterY - math.sin(enemy.binaryAngle) * 900
                local lx2 = bCenterX + math.cos(enemy.binaryAngle) * 900
                local ly2 = bCenterY + math.sin(enemy.binaryAngle) * 900

                if Collision.checkLineCircle(lx1, ly1, lx2, ly2, pCenterX, pCenterY, player.width / 2 + 8) then
                    player.health = player.health - 15
                    player.invincibleTime = 0.25
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
                enemy.nextPattern = "meteor_storm"
                enemy.binaryAngle = nil
            end
        elseif enemy.bossState == "meteor_storm" then
            enemy.stateTimer = enemy.stateTimer - dt
            targetVelX, targetVelY = 0, 0
            enemy.velX, enemy.velY = 0, 0

            if enemy.stateTimer <= 0 then
                enemy.bossState = "meteor_falling"
                enemy.stateTimer = 4.0
                enemy.meteorSpawnTimer = 0.0
            end
        elseif enemy.bossState == "meteor_falling" then
            enemy.stateTimer = enemy.stateTimer - dt

            -- Move slowly
            if dist > 0 then
                targetVelX = (dx / dist) * 40
                targetVelY = (dy / dist) * 40
            end

            -- Spawning meteors every 0.25s
            enemy.meteorSpawnTimer = (enemy.meteorSpawnTimer or 0) - dt
            if enemy.meteorSpawnTimer <= 0 then
                enemy.meteorSpawnTimer = 0.25
                local offsetAngle = math.random() * 2 * math.pi
                local offsetDist = math.random(0, 120)
                local targetX = player.x + player.width / 2 + math.cos(offsetAngle) * offsetDist
                local targetY = player.y + player.height / 2 + math.sin(offsetAngle) * offsetDist

                table.insert(game.cosmicMeteors, {
                    x = targetX,
                    y = targetY,
                    timer = 1.2,
                    radius = 70,
                    exploded = false
                })
            end

            if enemy.stateTimer <= 0 then
                enemy.bossState = "normal"
                enemy.patternTimer = 5.0
                enemy.nextPattern = "supernova"
            end
        end
    end

    return targetVelX, targetVelY
end

return BossUpdate
