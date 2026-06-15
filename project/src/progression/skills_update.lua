-- ============================================================================
-- skills_update.lua — 액티브 스킬 업데이트 모듈 (skills.lua에서 분리)
-- ============================================================================

local SkillsUpdate = {}

function SkillsUpdate.update(game, dt, Skills)
    local player = game.player
    if not player then return end

    -- 1. 회전 구체 업데이트 (레벨 > 0 일 때 구체 회전 동작)
    if (player.skillLevels[1] or 0) > 0 then
        local px = player.x + player.width / 2
        local py = player.y + player.height / 2
        for _, orb in ipairs(game.orbs) do
            orb.angle = orb.angle + orb.speed * dt
            orb.x = px + math.cos(orb.angle) * orb.radius - orb.size / 2
            orb.y = py + math.sin(orb.angle) * orb.radius - orb.size / 2

            -- 잔상(트레일) 기록 - 플레이어 중심 기준 상대 오프셋으로 기록하여 캐릭터 이동 시 궤도 왜곡 방지
            if not orb.trail then orb.trail = {} end
            local relX = (orb.x + orb.size / 2) - px
            local relY = (orb.y + orb.size / 2) - py
            table.insert(orb.trail, 1, { dx = relX, dy = relY })
            if #orb.trail > 12 then
                table.remove(orb.trail)
            end
        end
    end

    -- 2. 벼락 스킬 업데이트 (레벨 > 0 일 때 가동)
    if (player.skillLevels[2] or 0) > 0 then
        game.thunderTimer = game.thunderTimer + dt

        local level = player.skillLevels[2] or 0
        local spec = Skills.thunderLevels[math.min(level, #Skills.thunderLevels)]
        local cooldown = spec.cooldown
        local damage = spec.damage
        local count = spec.count

        if game.thunderTimer >= cooldown then
            game.thunderTimer = 0
            local targets = Skills.findClosestEnemies(game, count)
            for _, targetEnemy in ipairs(targets) do
                local tx = targetEnemy.x + targetEnemy.width / 2
                local ty = targetEnemy.y + targetEnemy.height / 2

                -- 진짜 번개 경로 생성 (하늘에서 내리꽂는 지그재그)
                local startX = tx + math.random(-40, 40)
                local startY = ty - 600
                local segments = 12
                local points = {}

                -- 주 줄기 (Main branch)
                local currentX = startX
                local currentY = startY
                table.insert(points, startX)
                table.insert(points, startY)
                for j = 1, segments do
                    local t = j / segments
                    local targetY = startY + (ty - startY) * t
                    local targetX = startX + (tx - startX) * t
                    local rx = 0
                    if j < segments then
                        rx = (math.random() - 0.5) * 35
                    end
                    currentX = targetX + rx
                    currentY = targetY
                    table.insert(points, currentX)
                    table.insert(points, currentY)
                end

                -- 곁가지 (Side forks)
                local forks = {}
                for j = 3, segments - 3, 3 do
                    if math.random() < 0.5 then
                        local forkPoints = {}
                        local px = points[2 * j - 1]
                        local py = points[2 * j]
                        local forkEndX = px + (math.random() > 0.5 and 1 or -1) * math.random(30, 80)
                        local forkEndY = py + math.random(60, 150)
                        local forkSegs = 5

                        table.insert(forkPoints, px)
                        table.insert(forkPoints, py)
                        local cx = px
                        local cy = py
                        for k = 1, forkSegs do
                            local t = k / forkSegs
                            local ty_f = py + (forkEndY - py) * t
                            local tx_f = px + (forkEndX - px) * t
                            local rx = (math.random() - 0.5) * 15
                            cx = tx_f + rx
                            cy = ty_f
                            table.insert(forkPoints, cx)
                            table.insert(forkPoints, cy)
                        end
                        table.insert(forks, forkPoints)
                    end
                end

                -- 사방으로 튀는 스파크
                local sparks = {}
                for s = 1, 8 do
                    local angle = math.random() * 2 * math.pi
                    local speed = math.random(80, 200)
                    local length = math.random(6, 18)
                    table.insert(sparks, {
                        angle = angle,
                        speed = speed,
                        length = length
                    })
                end

                table.insert(game.thunders, {
                    x = tx,
                    y = ty,
                    points = points,
                    forks = forks,
                    sparks = sparks,
                    size = 20,
                    damage = damage,
                    duration = 0.25,
                    timer = 0
                })
            end
        end
    end
    for i = #game.thunders, 1, -1 do
        local thunder = game.thunders[i]
        thunder.timer = thunder.timer + dt
        if thunder.timer >= thunder.duration then
            table.remove(game.thunders, i)
        end
    end

    -- 3. 칼날 스킬 업데이트 (레벨 > 0 일 때 가동)
    if (player.skillLevels[3] or 0) > 0 then
        -- 대기 중인(순차 발사) 칼날 업데이트
        game.pendingBlades = game.pendingBlades or {}
        for k = #game.pendingBlades, 1, -1 do
            local pb = game.pendingBlades[k]
            pb.delay = pb.delay - dt
            if pb.delay <= 0 then
                local targetEnemy = Skills.findClosestEnemy(game)
                if targetEnemy then
                    Skills.spawnBlade(game, targetEnemy, pb.damage, pb.size)
                end
                table.remove(game.pendingBlades, k)
            end
        end

        game.bladeTimer = game.bladeTimer + dt

        local level = player.skillLevels[3] or 0
        local spec = Skills.bladeLevels[math.min(level, #Skills.bladeLevels)]
        local cooldown = spec.cooldown
        local damage = spec.damage
        local count = spec.count
        local size = spec.size

        if game.bladeTimer >= cooldown then
            game.bladeTimer = 0
            local targetEnemy = Skills.findClosestEnemy(game)
            if targetEnemy then
                -- 첫 번째 칼날은 즉시 발사
                Skills.spawnBlade(game, targetEnemy, damage, size)

                -- 나머지 칼날은 순차적으로 대기열에 등록 (0.2초 간격)
                for b = 2, count do
                    table.insert(game.pendingBlades, {
                        delay = (b - 1) * 0.2,
                        damage = damage,
                        size = size
                    })
                end
            end
        end
    end
    for i = #game.blades, 1, -1 do
        local blade = game.blades[i]

        blade.progress = blade.progress + (blade.speed * dt) / blade.totalDistance

        if blade.progress >= 1 then
            table.remove(game.blades, i)
        else
            local px = player.x + player.width / 2
            local py = player.y + player.height / 2

            local playerRefX = blade.startX
            local playerRefY = blade.startY
            if blade.progress > 0.5 then
                local u = (blade.progress - 0.5) * 2
                playerRefX = blade.startX + (px - blade.startX) * u
                playerRefY = blade.startY + (py - blade.startY) * u
            end

            local theta = blade.progress * 2 * math.pi

            -- 조화 조절된 단일 타원 부메랑 복귀 궤적 적용
            blade.x = playerRefX + (blade.targetX - playerRefX) * 0.5 * (1 - math.cos(theta)) +
                blade.perpX * math.sin(theta)
            blade.y = playerRefY + (blade.targetY - playerRefY) * 0.5 * (1 - math.cos(theta)) +
                blade.perpY * math.sin(theta)

            -- 잔상(트레일) 기록
            table.insert(blade.trail, 1, { x = blade.x, y = blade.y })
            if #blade.trail > 10 then
                table.remove(blade.trail)
            end
        end
    end

    -- 4. 총알 스킬 업데이트 (레벨 > 0 일 때 가동)
    if (player.skillLevels[4] or 0) > 0 then
        game.bulletTimer = game.bulletTimer + dt

        local level = player.skillLevels[4] or 0
        local spec = Skills.bulletLevels[math.min(level, #Skills.bulletLevels)]
        local cooldown = spec.cooldown
        local pierce = spec.pierce
        local count = spec.count
        local damage = spec.damage

        if game.bulletTimer >= cooldown then
            game.bulletTimer = 0
            local targetEnemy = Skills.findClosestEnemy(game)
            if targetEnemy then
                local Sound = require("game.sound")
                Sound.play("shoot")
                local startX = player.x + player.width / 2
                local startY = player.y + player.height / 2
                local targetX = targetEnemy.x + targetEnemy.width / 2
                local targetY = targetEnemy.y + targetEnemy.height / 2

                local dx = targetX - startX
                local dy = targetY - startY
                local dist = math.sqrt(dx * dx + dy * dy)

                if dist > 0 then
                    local baseAngle = math.atan2(dy, dx)
                    for b = 1, count do
                        local offset = 0
                        if count == 3 then
                            if b == 2 then
                                offset = -15 * math.pi / 180
                            elseif b == 3 then
                                offset = 15 * math.pi / 180
                            end
                        end
                        local angle = baseAngle + offset
                        table.insert(game.bullets, {
                            x = startX,
                            y = startY,
                            dirX = math.cos(angle),
                            dirY = math.sin(angle),
                            speed = 500,
                            damage = damage,
                            size = 5,
                            distanceTraveled = 0,
                            maxDistance = 1000,
                            hitEnemies = {},
                            pierce = pierce,
                            toRemove = false
                        })
                    end
                end
            end
        end
    end
    for i = #game.bullets, 1, -1 do
        local bullet = game.bullets[i]

        local moveDist = bullet.speed * dt
        bullet.x = bullet.x + bullet.dirX * moveDist
        bullet.y = bullet.y + bullet.dirY * moveDist
        bullet.distanceTraveled = bullet.distanceTraveled + moveDist

        if bullet.distanceTraveled >= bullet.maxDistance or bullet.toRemove then
            table.remove(game.bullets, i)
        end
    end

    -- 5. 레이저 스킬 업데이트 (레벨 > 0 일 때 가동)
    if (player.skillLevels[5] or 0) > 0 then
        game.laserTimer = game.laserTimer + dt

        local level = player.skillLevels[5] or 0
        local spec = Skills.laserLevels[math.min(level, #Skills.laserLevels)]
        local cooldown = spec.cooldown
        local damage = spec.damage
        local thickness = spec.thickness
        local duration = spec.duration

        if game.laserTimer >= cooldown then
            game.laserTimer = 0
            local targetEnemy = Skills.findClosestEnemy(game)
            if targetEnemy then
                local px = player.x + player.width / 2
                local py = player.y + player.height / 2
                local tx = targetEnemy.x + targetEnemy.width / 2
                local ty = targetEnemy.y + targetEnemy.height / 2

                local dx = tx - px
                local dy = ty - py
                local dist = math.sqrt(dx * dx + dy * dy)

                if dist > 0 then
                    local ux = dx / dist
                    local uy = dy / dist
                    local L = 1200 -- 매우 긴 길이
                    local bx = px + ux * L
                    local by = py + uy * L

                    -- 레이저 이펙트 추가 (플레이어를 따라다니는 구조)
                    table.insert(game.lasers, {
                        x1 = px,
                        y1 = py,
                        x2 = bx,
                        y2 = by,
                        ux = ux,
                        uy = uy,
                        length = L,
                        thickness = thickness,
                        damage = damage,
                        timer = 0,
                        duration = duration,
                        hitEnemies = {} -- 중복 타격 방지용 테이블
                    })
                end
            end
        end
    end

    -- 레이저 이펙트 타이머 업데이트, 위치 추적 및 실시간 충돌 체크
    game.lasers = game.lasers or {}
    for i = #game.lasers, 1, -1 do
        local laser = game.lasers[i]
        laser.timer = laser.timer + dt

        -- 플레이어 위치 실시간 추적 및 좌표 동기화
        local px = player.x + player.width / 2
        local py = player.y + player.height / 2
        laser.x1 = px
        laser.y1 = py
        laser.x2 = px + laser.ux * laser.length
        laser.y2 = py + laser.uy * laser.length

        -- 실시간 선분 AABB 충돌 체크 및 피해 적용
        for j = #game.enemies, 1, -1 do
            local enemy = game.enemies[j]
            if not laser.hitEnemies[enemy] then
                local ecx = enemy.x + enemy.width / 2
                local ecy = enemy.y + enemy.height / 2

                -- 투영거리 계산
                local apx = ecx - px
                local apy = ecy - py
                local proj = apx * laser.ux + apy * laser.uy
                local t = math.max(0, math.min(laser.length, proj))

                -- 선분 위의 가장 가까운 점
                local cx = px + laser.ux * t
                local cy = py + laser.uy * t

                -- 최단 거리 계산
                local cdx = ecx - cx
                local cdy = ecy - cy
                local distToLine = math.sqrt(cdx * cdx + cdy * cdy)

                -- 충돌 판정 (적 절반 폭 + 레이저 절반 두께)
                if distToLine < (enemy.width / 2 + laser.thickness / 2) then
                    laser.hitEnemies[enemy] = true
                    local EnemyModule = require("enemy.spawner")
                    EnemyModule.damage(game, j, laser.damage)
                end
            end
        end

        if laser.timer >= laser.duration then
            table.remove(game.lasers, i)
        end
    end

    -- 6. 자기장 스킬 업데이트 (레벨 > 0 일 때 가동)
    if (player.skillLevels[6] or 0) > 0 then
        game.magneticFieldTimer = game.magneticFieldTimer + dt

        local level = player.skillLevels[6] or 0
        local spec = Skills.magneticFieldLevels[math.min(level, #Skills.magneticFieldLevels)]
        local cooldown = spec.cooldown
        local radius = spec.radius
        local duration = spec.duration
        local damage = spec.damage
        local tickInterval = spec.tickInterval

        if game.magneticFieldTimer >= cooldown then
            game.magneticFieldTimer = 0
            -- 새로운 자기장 활성화
            game.activeMagneticField = {
                timer = 0,
                duration = duration,
                radius = radius,
                damage = damage,
                tickInterval = tickInterval,
                tickTimer = 0
            }
        end
    end

    if game.activeMagneticField then
        local field = game.activeMagneticField
        field.timer = field.timer + dt
        field.tickTimer = field.tickTimer + dt

        -- 플레이어 중심 좌표
        local px = player.x + player.width / 2
        local py = player.y + player.height / 2

        -- 틱 타이머 도달 시 대미지 적용
        if field.tickTimer >= field.tickInterval then
            field.tickTimer = field.tickTimer - field.tickInterval

            for j = #game.enemies, 1, -1 do
                local enemy = game.enemies[j]
                local ecx = enemy.x + enemy.width / 2
                local ecy = enemy.y + enemy.height / 2

                local dx = ecx - px
                local dy = ecy - py
                local dist = math.sqrt(dx * dx + dy * dy)

                -- 적의 크기(절반) + 자기장 반지름 비교
                if dist <= (field.radius + enemy.width / 2) then
                    local EnemyModule = require("enemy.spawner")
                    EnemyModule.damage(game, j, field.damage)
                end
            end
        end

        if field.timer >= field.duration then
            game.activeMagneticField = nil
        end
    end

    -- 7. 운석 스킬 업데이트 (레벨 > 0 일 때 가동)
    if (player.skillLevels[7] or 0) > 0 then
        game.meteorTimer = game.meteorTimer + dt

        local level = player.skillLevels[7] or 0
        local spec = Skills.meteorLevels[math.min(level, #Skills.meteorLevels)]

        if game.meteorTimer >= spec.cooldown then
            game.meteorTimer = 0

            -- 가장 가까운 적 N마리 구함
            local targets = Skills.findClosestEnemies(game, spec.count)

            if #targets == 0 then
                -- 타겟이 없으면 플레이어 주변 임의 위치 타격
                for c = 1, spec.count do
                    local tx = player.x + math.random(-250, 250)
                    local ty = player.y + math.random(-250, 250)
                    table.insert(game.meteors, {
                        targetX = tx,
                        targetY = ty,
                        startX = tx - 200,
                        startY = ty - 600,
                        currentX = tx - 200,
                        currentY = ty - 600,
                        progress = 0,
                        speed = 450,
                        damage = spec.damage,
                        hasFire = spec.hasFire,
                        radius = 60,
                        trail = {}
                    })
                end
            else
                for _, targetEnemy in ipairs(targets) do
                    local tx = targetEnemy.x + targetEnemy.width / 2
                    local ty = targetEnemy.y + targetEnemy.height / 2
                    table.insert(game.meteors, {
                        targetX = tx,
                        targetY = ty,
                        startX = tx - 200,
                        startY = ty - 600,
                        currentX = tx - 200,
                        currentY = ty - 600,
                        progress = 0,
                        speed = 450,
                        damage = spec.damage,
                        hasFire = spec.hasFire,
                        radius = 60,
                        trail = {}
                    })
                end
            end
        end
    end

    -- 운석 낙하 처리
    game.meteors = game.meteors or {}
    for i = #game.meteors, 1, -1 do
        local met = game.meteors[i]
        local dx = met.targetX - met.startX
        local dy = met.targetY - met.startY
        local totalDist = math.sqrt(dx * dx + dy * dy)

        met.progress = met.progress + (met.speed * dt) / totalDist

        if met.progress >= 1 then
            -- 지면 낙하 완료!
            -- 1) 카메라 쉐이크 트리거
            if game.triggerShake then
                game.triggerShake(0.35, 12)
            end

            -- 2) 범위 대미지 적용
            for j = #game.enemies, 1, -1 do
                local enemy = game.enemies[j]
                local ecx = enemy.x + enemy.width / 2
                local ecy = enemy.y + enemy.height / 2
                local edx = ecx - met.targetX
                local edy = ecy - met.targetY
                local distToExplosion = math.sqrt(edx * edx + edy * edy)

                if distToExplosion <= (met.radius + enemy.width / 2) then
                    local EnemyModule = require("enemy.spawner")
                    EnemyModule.damage(game, j, met.damage)
                end
            end

            -- 3) 불장판 생성 (4레벨 이상)
            if met.hasFire then
                table.insert(game.firePatches, {
                    x = met.targetX,
                    y = met.targetY,
                    radius = 50,
                    duration = 4.0,
                    timer = 0,
                    damage = 12,
                    tickInterval = 0.5,
                    tickTimer = 0
                })
            end

            table.remove(game.meteors, i)
        else
            met.currentX = met.startX + dx * met.progress
            met.currentY = met.startY + dy * met.progress

            -- 잔상 트레일 기록
            table.insert(met.trail, 1, { x = met.currentX, y = met.currentY })
            if #met.trail > 10 then
                table.remove(met.trail)
            end
        end
    end

    -- 불장판 틱 대미지 및 타이머 처리
    game.firePatches = game.firePatches or {}
    for i = #game.firePatches, 1, -1 do
        local patch = game.firePatches[i]
        patch.timer = patch.timer + dt
        patch.tickTimer = patch.tickTimer + dt

        if patch.tickTimer >= patch.tickInterval then
            patch.tickTimer = patch.tickTimer - patch.tickInterval

            for j = #game.enemies, 1, -1 do
                local enemy = game.enemies[j]
                local ecx = enemy.x + enemy.width / 2
                local ecy = enemy.y + enemy.height / 2
                local pdx = ecx - patch.x
                local pdy = ecy - patch.y
                local distToPatch = math.sqrt(pdx * pdx + pdy * pdy)

                if distToPatch <= (patch.radius + enemy.width / 2) then
                    local EnemyModule = require("enemy.spawner")
                    EnemyModule.damage(game, j, patch.damage)
                end
            end
        end

        if patch.timer >= patch.duration then
            table.remove(game.firePatches, i)
        end
    end

    -- 9. 커터 스킬 업데이트 (레벨 > 0 일 때 가동)
    if (player.skillLevels[8] or 0) > 0 then
        local level = player.skillLevels[8] or 0
        local spec = Skills.cutterLevels[math.min(level, #Skills.cutterLevels)]
        local count = spec.count
        local damage = spec.damage
        local speed = spec.speed
        local length = spec.length

        -- Update base rotation angle
        game.cutterAngle = (game.cutterAngle or 0) + speed * dt

        -- Player center coordinates
        local px = player.x + player.width / 2
        local py = player.y + player.height / 2

        -- Reset cutters table
        game.cutters = game.cutters or {}

        -- We will check collision for each cutter blade
        for c = 1, count do
            local offset = (c - 1) * (2 * math.pi / count)
            local angle = game.cutterAngle + offset

            -- We want to store points for rendering (16 points for smooth curve)
            local drawPoints = {}
            local segments = 16
            for s = 0, segments do
                local t = s / segments
                local currAngle = angle - Skills.cutterCurvature * t
                local cx_point = px + math.cos(currAngle) * (length * t)
                local cy_point = py + math.sin(currAngle) * (length * t)
                table.insert(drawPoints, cx_point)
                table.insert(drawPoints, cy_point)
            end

            game.cutters[c] = {
                drawPoints = drawPoints,
                angle = angle,
                length = length
            }

            -- Collision check: 8 segments
            local prevX, prevY = px, py
            local collSegments = 8
            local hitEnemyThisBlade = {}

            for s = 1, collSegments do
                local t = s / collSegments
                local currAngle = angle - Skills.cutterCurvature * t
                local cx_point = px + math.cos(currAngle) * (length * t)
                local cy_point = py + math.sin(currAngle) * (length * t)

                local ux_seg = cx_point - prevX
                local uy_seg = cy_point - prevY
                local seg_len = math.sqrt(ux_seg * ux_seg + uy_seg * uy_seg)

                if seg_len > 0 then
                    local dx_seg = ux_seg / seg_len
                    local dy_seg = uy_seg / seg_len

                    for j = #game.enemies, 1, -1 do
                        local enemy = game.enemies[j]

                        if enemy and not hitEnemyThisBlade[enemy] then
                            enemy.cutterHitCooldown = enemy.cutterHitCooldown or 0
                            if enemy.cutterHitCooldown <= 0 then
                                local ecx = enemy.x + enemy.width / 2
                                local ecy = enemy.y + enemy.height / 2

                                local apx = ecx - prevX
                                local apy = ecy - prevY
                                local proj = apx * dx_seg + apy * dy_seg
                                local clamped_proj = math.max(0, math.min(seg_len, proj))

                                local nearestX = prevX + dx_seg * clamped_proj
                                local nearestY = prevY + dy_seg * clamped_proj

                                local distDX = ecx - nearestX
                                local distDY = ecy - nearestY
                                local dist = math.sqrt(distDX * distDX + distDY * distDY)

                                -- Hit check (half of enemy width + cutter thickness, say 16 for extra thick blade)
                                if dist < (enemy.width / 2 + 16) then
                                    hitEnemyThisBlade[enemy] = true
                                    local EnemyModule = require("enemy.spawner")
                                    if EnemyModule.damage(game, j, damage) then
                                        -- Enemy died
                                    else
                                        -- Set hit cooldown
                                        enemy.cutterHitCooldown = 0.25
                                    end
                                end
                            end
                        end
                    end
                end

                prevX, prevY = cx_point, cy_point
            end
        end

        -- Clean up extra cutter visual references
        for c = count + 1, #game.cutters do
            game.cutters[c] = nil
        end
    else
        game.cutters = nil
    end

    -- 10. 가시 이펙트 업데이트
    game.thornsVisuals = game.thornsVisuals or {}
    for i = #game.thornsVisuals, 1, -1 do
        local tv = game.thornsVisuals[i]
        tv.timer = tv.timer - dt
        if tv.timer <= 0 then
            table.remove(game.thornsVisuals, i)
        end
    end

    -- 11. 체인 스킬 업데이트 (레벨 > 0 일 때 가동)
    if (player.skillLevels[9] or 0) > 0 then
        local level = player.skillLevels[9] or 0
        local spec = Skills.chainLevels[math.min(level, #Skills.chainLevels)]

        game.chainTimer = (game.chainTimer or 0) + dt
        if game.chainTimer >= spec.cooldown then
            game.chainTimer = game.chainTimer - spec.cooldown

            -- Find the spec.count closest enemies (including boss)
            local targets = Skills.findClosestEnemies(game, spec.count, false)
            for _, targetEnemy in ipairs(targets) do
                local excludeSet = {}
                excludeSet[targetEnemy] = true

                table.insert(game.chains, {
                    type = "primary",
                    sourceType = "player",
                    source = player,
                    target = targetEnemy,
                    state = "extending",
                    progress = 0,
                    speed = 600,
                    damage = spec.damage,
                    rootDuration = spec.rootDuration,
                    depth = 1,
                    maxDepth = spec.maxChains,
                    excludeSet = excludeSet,
                    timer = 0,
                    fadeDuration = 0.3
                })
            end
        end
    end

    -- 액티브 체인 업데이트
    game.chains = game.chains or {}
    for i = #game.chains, 1, -1 do
        local chain = game.chains[i]

        -- 부모 체인이 속박 해제/제거/fading인 경우 자식 체인도 동기화하여 fading 전향
        if chain.parent and (chain.parent.state == "fading" or chain.parent.toRemove) then
            if chain.state ~= "fading" then
                chain.state = "fading"
                chain.timer = chain.parent.timer or chain.fadeDuration
            end
        end

        -- Source 좌표 결정
        local sx, sy
        if chain.sourceType == "player" then
            sx = player.x + player.width / 2
            sy = player.y + player.height / 2
        else
            if Skills.isEnemyAlive(game, chain.source) then
                chain.sourceX = chain.source.x + chain.source.width / 2
                chain.sourceY = chain.source.y + chain.source.height / 2
            end
            sx = chain.sourceX or 0
            sy = chain.sourceY or 0
        end

        if chain.state == "extending" then
            if not Skills.isEnemyAlive(game, chain.target) then
                chain.state = "fading"
                chain.timer = chain.fadeDuration
            else
                local tx = chain.target.x + chain.target.width / 2
                local ty = chain.target.y + chain.target.height / 2
                local dx = tx - sx
                local dy = ty - sy
                local distance = math.sqrt(dx * dx + dy * dy)

                if distance > 0 then
                    chain.progress = chain.progress + (chain.speed * dt) / distance
                    if chain.progress >= 1 then
                        chain.progress = 1
                        chain.state = "active"
                        chain.timer = chain.rootDuration

                        -- 속박 및 데미지 적용
                        local targetIdx = nil
                        for idx, enemy in ipairs(game.enemies) do
                            if enemy == chain.target then
                                targetIdx = idx
                                break
                            end
                        end
                        if targetIdx then
                            if chain.target.type == "boss" or chain.target.type == "tesla_pylon" or chain.target.type == "aegis_shield" then
                                chain.target.slowTimer = chain.rootDuration
                                chain.target.slowMultiplier = 0.5
                            else
                                chain.target.rootedTimer = chain.rootDuration
                            end
                            local EnemyModule = require("enemy.spawner")
                            EnemyModule.damage(game, targetIdx, chain.damage)
                        end

                        -- 연쇄 반응 (다음 대상 탐색)
                        if chain.depth < chain.maxDepth then
                            local tx_loc = chain.target.x + chain.target.width / 2
                            local ty_loc = chain.target.y + chain.target.height / 2
                            local nextEnemy = Skills.findClosestEnemyFrom(game, tx_loc, ty_loc, chain.excludeSet)
                            if nextEnemy then
                                local newExcludeSet = {}
                                for k, v in pairs(chain.excludeSet) do
                                    newExcludeSet[k] = v
                                end
                                newExcludeSet[nextEnemy] = true

                                table.insert(game.chains, {
                                    type = "secondary",
                                    sourceType = "enemy",
                                    source = chain.target,
                                    sourceX = tx_loc,
                                    sourceY = ty_loc,
                                    target = nextEnemy,
                                    state = "extending",
                                    progress = 0,
                                    speed = 600,
                                    damage = chain.damage,
                                    rootDuration = chain.rootDuration,
                                    depth = chain.depth + 1,
                                    maxDepth = chain.maxDepth,
                                    excludeSet = newExcludeSet,
                                    parent = chain, -- 부모 체인 링크 기록
                                    timer = 0,
                                    fadeDuration = 0.3
                                })
                            end
                        end
                    end
                else
                    chain.progress = 1
                    chain.state = "active"
                    chain.timer = chain.rootDuration
                end
            end
        elseif chain.state == "active" then
            chain.timer = chain.timer - dt
            if chain.timer <= 0 or not Skills.isEnemyAlive(game, chain.target) then
                chain.state = "fading"
                chain.timer = chain.fadeDuration
            end
        elseif chain.state == "fading" then
            chain.timer = chain.timer - dt
            if chain.timer <= 0 then
                chain.toRemove = true
                table.remove(game.chains, i)
            end
        end
    end

    -- 12. 추적 구체 (Seeker Orb) 스킬 업데이트
    if (player.skillLevels[10] or 0) > 0 then
        game.seekerOrbTimer = (game.seekerOrbTimer or 0) + dt

        local level = player.skillLevels[10] or 0
        local spec = Skills.seekerOrbLevels[math.min(level, #Skills.seekerOrbLevels)]
        local cooldown = spec.cooldown
        local count = spec.count
        local damage = spec.damage
        local chargeTime = spec.chargeTime
        local speed = spec.speed
        local explode = spec.explode

        if game.seekerOrbTimer >= cooldown then
            game.seekerOrbTimer = 0

            -- Spawn 'count' orbs around the player
            for c = 1, count do
                local angle = (c - 1) * (2 * math.pi / count) + math.random() * 0.2
                local dist = 50
                table.insert(game.seekerOrbs, {
                    state = "charging",
                    relativeAngle = angle,
                    distance = dist,
                    x = player.x + player.width / 2 + math.cos(angle) * dist,
                    y = player.y + player.height / 2 + math.sin(angle) * dist,
                    timer = 0,
                    chargeTime = chargeTime,
                    speed = speed,
                    damage = damage,
                    explode = explode,
                    size = 14,
                    targetEnemy = nil,
                    dirX = 0,
                    dirY = 0,
                    trail = {}
                })
            end
        end
    end

    game.seekerOrbs = game.seekerOrbs or {}
    local px_seeker = player.x + player.width / 2
    local py_seeker = player.y + player.height / 2

    for i = #game.seekerOrbs, 1, -1 do
        local orb = game.seekerOrbs[i]

        if orb.state == "charging" then
            orb.timer = orb.timer + dt
            -- Rotate slowly around player
            orb.relativeAngle = orb.relativeAngle + 2.0 * dt
            orb.x = px_seeker + math.cos(orb.relativeAngle) * orb.distance
            orb.y = py_seeker + math.sin(orb.relativeAngle) * orb.distance

            -- Record trail
            table.insert(orb.trail, 1, { x = orb.x, y = orb.y })
            if #orb.trail > 6 then table.remove(orb.trail) end

            -- If charging finishes, transition to launched state
            if orb.timer >= orb.chargeTime then
                local target = Skills.findClosestEnemy(game)
                if target then
                    orb.state = "launched"
                    orb.targetEnemy = target
                    -- Calculate launch direction
                    local tx = target.x + target.width / 2
                    local ty = target.y + target.height / 2
                    local dx = tx - orb.x
                    local dy = ty - orb.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist > 0 then
                        orb.dirX = dx / dist
                        orb.dirY = dy / dist
                    else
                        orb.dirX = 1
                        orb.dirY = 0
                    end
                else
                    -- No enemies? Discard
                    table.remove(game.seekerOrbs, i)
                end
            end
        elseif orb.state == "launched" then
            -- Fly towards target with homing tracking
            if Skills.isEnemyAlive(game, orb.targetEnemy) then
                local tx = orb.targetEnemy.x + orb.targetEnemy.width / 2
                local ty = orb.targetEnemy.y + orb.targetEnemy.height / 2
                local dx = tx - orb.x
                local dy = ty - orb.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist > 0 then
                    local targetDirX = dx / dist
                    local targetDirY = dy / dist
                    orb.dirX = orb.dirX + (targetDirX - orb.dirX) * 5.0 * dt
                    orb.dirY = orb.dirY + (targetDirY - orb.dirY) * 5.0 * dt
                    local dlen = math.sqrt(orb.dirX * orb.dirX + orb.dirY * orb.dirY)
                    if dlen > 0 then
                        orb.dirX = orb.dirX / dlen
                        orb.dirY = orb.dirY / dlen
                    end
                end
            end

            orb.x = orb.x + orb.dirX * orb.speed * dt
            orb.y = orb.y + orb.dirY * orb.speed * dt

            -- Record trail
            table.insert(orb.trail, 1, { x = orb.x, y = orb.y })
            if #orb.trail > 10 then table.remove(orb.trail) end

            -- Check boundary collision
            if orb.x < -100 or orb.x > game.world.width + 100 or orb.y < -100 or orb.y > game.world.height + 100 then
                table.remove(game.seekerOrbs, i)
            else
                -- Check collision with enemies
                local hit = false
                for j = #game.enemies, 1, -1 do
                    local enemy = game.enemies[j]
                    local ecx = enemy.x + enemy.width / 2
                    local ecy = enemy.y + enemy.height / 2
                    local dx = ecx - orb.x
                    local dy = ecy - orb.y
                    local dist = math.sqrt(dx * dx + dy * dy)

                    if dist <= (orb.size / 2 + enemy.width / 2) then
                        hit = true

                        if orb.explode then
                            -- AoE Damage
                            local explRadius = 80
                            local explDamage = orb.damage

                            for k = #game.enemies, 1, -1 do
                                local targetEnemy = game.enemies[k]
                                local tcx = targetEnemy.x + targetEnemy.width / 2
                                local tcy = targetEnemy.y + targetEnemy.height / 2
                                local tdx = tcx - orb.x
                                local tdy = tcy - orb.y
                                local tdist = math.sqrt(tdx * tdx + tdy * tdy)
                                if tdist <= (explRadius + targetEnemy.width / 2) then
                                    local EnemyModule = require("enemy.spawner")
                                    EnemyModule.damage(game, k, explDamage)
                                end
                            end

                            if game.triggerShake then
                                game.triggerShake(0.15, 4)
                            end

                            game.seekerExplosions = game.seekerExplosions or {}
                            table.insert(game.seekerExplosions, {
                                x = orb.x,
                                y = orb.y,
                                radius = explRadius,
                                timer = 0,
                                duration = 0.3
                            })
                        else
                            -- Single Target Damage
                            local EnemyModule = require("enemy.spawner")
                            EnemyModule.damage(game, j, orb.damage)
                        end
                        break
                    end
                end

                if hit then
                    table.remove(game.seekerOrbs, i)
                end
            end
        end
    end

    -- Seeker Explosions Update
    game.seekerExplosions = game.seekerExplosions or {}
    for i = #game.seekerExplosions, 1, -1 do
        local expl = game.seekerExplosions[i]
        expl.timer = expl.timer + dt
        if expl.timer >= expl.duration then
            table.remove(game.seekerExplosions, i)
        end
    end
end

return SkillsUpdate
