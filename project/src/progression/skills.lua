-- ============================================================================
-- skills.lua — 스킬들(구체, 벼락, 칼날, 총알)의 업데이트, 그리기 및 특성/레벨업 처리
-- ============================================================================

local Skills = {}

-- 플레이어와 가장 가까운 적 찾기
function Skills.findClosestEnemy(game)
    local player = game.player
    if not player or #game.enemies == 0 then return nil end

    local closestEnemy = nil
    local closestDistance = math.huge

    for _, enemy in ipairs(game.enemies) do
        local dx = enemy.x + enemy.width / 2 - (player.x + player.width / 2)
        local dy = enemy.y + enemy.height / 2 - (player.y + player.height / 2)
        local distance = math.sqrt(dx * dx + dy * dy)

        if distance < closestDistance then
            closestDistance = distance
            closestEnemy = enemy
        end
    end

    return closestEnemy
end

-- 플레이어와 가까운 순서대로 최대 N개의 적 찾기
function Skills.findClosestEnemies(game, n)
    local player = game.player
    if not player or #game.enemies == 0 then return {} end

    local candidates = {}
    for _, enemy in ipairs(game.enemies) do
        local dx = enemy.x + enemy.width / 2 - (player.x + player.width / 2)
        local dy = enemy.y + enemy.height / 2 - (player.y + player.height / 2)
        local distance = math.sqrt(dx * dx + dy * dy)
        table.insert(candidates, { enemy = enemy, distance = distance })
    end

    table.sort(candidates, function(a, b)
        return a.distance < b.distance
    end)

    local result = {}
    for i = 1, math.min(n, #candidates) do
        table.insert(result, candidates[i].enemy)
    end
    return result
end

-- 칼날 투사체 인스턴스 생성 및 리스트 삽입
function Skills.spawnBlade(game, targetEnemy, damage, size)
    local player = game.player
    if not player or not targetEnemy then return end

    local startX = player.x + player.width / 2
    local startY = player.y + player.height / 2
    local targetX = targetEnemy.x + targetEnemy.width / 2
    local targetY = targetEnemy.y + targetEnemy.height / 2

    local dx = targetX - startX
    local dy = targetY - startY
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 0 then
        local offsetScale = math.min(100, dist * 0.3)
        local perpX = -dy / dist * offsetScale
        local perpY = dx / dist * offsetScale

        table.insert(game.blades, {
            x = startX,
            y = startY,
            startX = startX,
            startY = startY,
            targetX = targetX,
            targetY = targetY,
            perpX = perpX,
            perpY = perpY,
            speed = 220, -- 등속 비행 속도 (220)
            damage = damage,
            size = size,
            progress = 0,
            totalDistance = dist * 2,
            trail = {} -- 궤적 트레일 초기화
        })
    end
end

-- 회전 구체(Orbiting Orb) 개수 동기화 및 생성 (레벨에 비례하여 개수 증가 및 등간격 배치)
function Skills.syncOrbs(game)
    local player = game.player
    if not player then return end

    local level = player.skillLevels[1] or 0
    game.orbs = {}
    
    -- 레벨별 능력치 스케일링 설정
    -- 기본 속도: 3.0, 3레벨: 4.5, 5레벨: 6.0
    local speed = 3.0
    if level == 3 or level == 4 then
        speed = 4.5
    elseif level >= 5 then
        speed = 6.0
    end

    -- 기본 대미지: player.damage, 4레벨 이상: player.damage * 1.5
    local damage = player.damage
    if level >= 4 then
        damage = player.damage * 1.5
    end

    for i = 1, level do
        table.insert(game.orbs, {
            angle = (i - 1) * (2 * math.pi / level), -- 각 구체의 시작 각도를 균등 분할
            radius = 60,
            speed = speed,
            damage = damage,
            size = 18, -- 크기를 8에서 18로 확대 (유저 요청 반영)
            trail = {} -- 궤적 트레일 초기화
        })
    end
end

-- 모든 액티브 스킬들의 투사체 물리 상태 업데이트
function Skills.update(game, dt)
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
        local cooldown = 3.0
        local damage = 20
        local count = 1

        if level == 2 then
            cooldown = 2.2
            damage = 30
        elseif level == 3 then
            cooldown = 2.2
            damage = 30
            count = 2
        elseif level == 4 then
            cooldown = 1.4
            damage = 45
            count = 2
        elseif level >= 5 then
            cooldown = 1.4
            damage = 45
            count = 3
        end
        
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
        local cooldown = 2.0
        local damage = 15
        local count = 1
        local size = 10

        if level == 2 then
            cooldown = 1.5
            damage = 25
        elseif level == 3 then
            cooldown = 1.5
            damage = 25
            count = 2
        elseif level == 4 then
            cooldown = 1.0
            damage = 25
            count = 2
        elseif level >= 5 then
            cooldown = 1.0
            damage = 25
            count = 3
            size = 18
        end
        
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
            blade.x = playerRefX + (blade.targetX - playerRefX) * 0.5 * (1 - math.cos(theta)) + blade.perpX * math.sin(theta)
            blade.y = playerRefY + (blade.targetY - playerRefY) * 0.5 * (1 - math.cos(theta)) + blade.perpY * math.sin(theta)

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
        local cooldown = 1.5
        local pierce = false
        local count = 1
        local damage = 15

        if level == 2 then
            cooldown = 1.2
            pierce = true
        elseif level == 3 then
            cooldown = 0.9
            pierce = true
            count = 3
            damage = 25
        elseif level == 4 then
            cooldown = 0.7
            pierce = true
            count = 3
            damage = 25
        elseif level >= 5 then
            cooldown = 0.5
            pierce = true
            count = 3
            damage = 40
        end
        
        if game.bulletTimer >= cooldown then
            game.bulletTimer = 0
            local targetEnemy = Skills.findClosestEnemy(game)
            if targetEnemy then
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
                            if b == 2 then offset = -15 * math.pi / 180
                            elseif b == 3 then offset = 15 * math.pi / 180
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
        local cooldown = 6.0
        local damage = 40
        local thickness = 10
        local duration = 0.6

        if level == 2 then
            cooldown = 5.5
            damage = 70
            thickness = 14
            duration = 0.7
        elseif level == 3 then
            cooldown = 5.0
            damage = 110
            thickness = 18
            duration = 0.8
        elseif level == 4 then
            cooldown = 4.5
            damage = 160
            thickness = 18
            duration = 0.8
        elseif level >= 5 then
            cooldown = 4.0
            damage = 250
            thickness = 26
            duration = 1.0
        end
        
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
                    enemy.health = enemy.health - laser.damage
                    if enemy.health <= 0 then
                        game.score = game.score + 10
                        local Exp = require("progression.exp")
                        Exp.spawn(game, enemy.x + enemy.width / 2, enemy.y + enemy.height / 2)
                        table.remove(game.enemies, j)
                    end
                end
            end
        end
        
        if laser.timer >= laser.duration then
            table.remove(game.lasers, i)
        end
    end
end

-- 스킬 투사체 렌더링
function Skills.draw(game)
    -- 구체 (Orbiting Orb) - 마법 구슬 비주얼 적용 (네온 글로우, 코어, 회전 룬 서클 및 잔상)
    local pCenterX = game.player and (game.player.x + game.player.width / 2) or 0
    local pCenterY = game.player and (game.player.y + game.player.height / 2) or 0
    for _, orb in ipairs(game.orbs) do
        local cx = orb.x + orb.size / 2
        local cy = orb.y + orb.size / 2
        local r = orb.size / 2
        
        -- 1. 잔상(마법 스패터/트레일) 그리기
        if orb.trail then
            local trailCount = #orb.trail
            for t = 1, trailCount do
                local p = orb.trail[t]
                local alpha = (1 - t / (trailCount + 1)) * 0.25
                local trailR = r * (1 - t / (trailCount + 3))
                -- 플레이어의 실시간 중심 좌표를 기준으로 절대 좌표 복원
                local tx = pCenterX + p.dx
                local ty = pCenterY + p.dy
                -- 점점 노란색에서 붉은빛 오렌지색으로 변하는 스펙트럼
                love.graphics.setColor(1.0, 0.6 - (t/trailCount)*0.4, 0.1, alpha)
                love.graphics.circle("fill", tx, ty, trailR)
            end
        end

        -- 2. 회전하는 마법 룬 서클 그리기 (바깥 원 + 4개의 교차 도트)
        local rotAngle = game.time * 2.5
        love.graphics.setColor(1.0, 0.75, 0.2, 0.4)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", cx, cy, r * 1.5)
        
        for k = 0, 3 do
            local dotAngle = rotAngle + k * (math.pi / 2)
            local dx = cx + math.cos(dotAngle) * (r * 1.5)
            local dy = cy + math.sin(dotAngle) * (r * 1.5)
            love.graphics.circle("fill", dx, dy, 1.5)
        end

        -- 3. 마법 구체 본체 및 중첩 빛무리 그리기
        -- 1단계: 외부 대형 아우라 (연한 오렌지/옐로우)
        local pulse = 1 + math.sin(game.time * 8) * 0.08
        love.graphics.setColor(1.0, 0.5, 0.0, 0.12)
        love.graphics.circle("fill", cx, cy, r * 1.7 * pulse)

        -- 2단계: 중간 아우라 (빛나는 금색)
        love.graphics.setColor(1.0, 0.8, 0.1, 0.35)
        love.graphics.circle("fill", cx, cy, r * 1.2 * pulse)

        -- 3단계: 구체 코어 본체
        love.graphics.setColor(1.0, 0.95, 0.3, 0.8)
        love.graphics.circle("fill", cx, cy, r * 0.8)

        -- 4단계: 중심 화이트 코어 (눈부신 마법 핵)
        love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
        love.graphics.circle("fill", cx, cy, r * 0.4)
    end

    -- 벼락 (Thunder) - 진짜 번개 비주얼 적용 (빛무리, 곁가지, 타격 섬광, 충격파 및 스파크)
    for _, thunder in ipairs(game.thunders) do
        local progress = thunder.timer / thunder.duration
        local alpha = math.max(0, 1 - progress)
        local flicker = (math.random() < 0.15) and 0.2 or 1.0
        local currentAlpha = alpha * flicker

        -- 1. 곁가지 그리기 (옅고 얇은 비주얼)
        for _, fork in ipairs(thunder.forks) do
            if #fork >= 4 then
                -- 곁가지 외부 빛무리
                love.graphics.setColor(0.2, 0.5, 1.0, currentAlpha * 0.3)
                love.graphics.setLineWidth(4)
                love.graphics.line(fork)
                
                -- 곁가지 내부 코어
                love.graphics.setColor(1.0, 1.0, 1.0, currentAlpha * 0.8)
                love.graphics.setLineWidth(1.5)
                love.graphics.line(fork)
            end
        end

        -- 2. 주 줄기 그리기
        if #thunder.points >= 4 then
            -- 외부 빛무리 (굵은 네온 블루)
            love.graphics.setColor(0.3, 0.4, 1.0, currentAlpha * 0.2)
            love.graphics.setLineWidth(14)
            love.graphics.line(thunder.points)

            -- 내부 빛무리 (중간 청록)
            love.graphics.setColor(0.2, 0.8, 1.0, currentAlpha * 0.5)
            love.graphics.setLineWidth(6)
            love.graphics.line(thunder.points)

            -- 화이트 코어 (얇은 중앙선)
            love.graphics.setColor(1.0, 1.0, 1.0, currentAlpha * 0.95)
            love.graphics.setLineWidth(2)
            love.graphics.line(thunder.points)
        end

        -- 3. 지면 타격 충격파 그리기 (확장되는 원)
        love.graphics.setColor(0.4, 0.8, 1.0, currentAlpha * 0.6)
        love.graphics.setLineWidth(2)
        local waveRadius = progress * 40
        love.graphics.circle("line", thunder.x, thunder.y, waveRadius)

        -- 4. 지면 타격 섬광 그리기 (서서히 작아지는 섬광)
        love.graphics.setColor(1.0, 1.0, 1.0, currentAlpha)
        love.graphics.circle("fill", thunder.x, thunder.y, (1 - progress) * 12)

        -- 5. 사방으로 튀는 번개 스파크 그리기
        for _, spark in ipairs(thunder.sparks) do
            local sparkDist = spark.speed * thunder.timer
            local sx1 = thunder.x + math.cos(spark.angle) * sparkDist
            local sy1 = thunder.y + math.sin(spark.angle) * sparkDist
            local sx2 = thunder.x + math.cos(spark.angle) * (sparkDist + spark.length)
            local sy2 = thunder.y + math.sin(spark.angle) * (sparkDist + spark.length)
            love.graphics.setColor(0.6, 0.9, 1.0, currentAlpha)
            love.graphics.setLineWidth(2)
            love.graphics.line(sx1, sy1, sx2, sy2)
        end
    end

    -- 칼날 (Blade) - 4방향 회전하는 날카로운 메탈 글레이브(수리검) 및 잔상 효과
    for _, blade in ipairs(game.blades) do
        local bladeSize = blade.size or 10
        -- 1. 잔상(트레일) 그리기 - 연해지면서 가늘어지는 슬래시 궤적
        if blade.trail and #blade.trail >= 2 then
            local trailCount = #blade.trail
            for t = 1, trailCount - 1 do
                local p1 = blade.trail[t]
                local p2 = blade.trail[t + 1]
                local alpha = (1 - t / trailCount) * 0.4
                love.graphics.setColor(0.3, 1.0, 0.5, alpha)
                love.graphics.setLineWidth((1 - t / trailCount) * (bladeSize * 0.8))
                love.graphics.line(p1.x, p1.y, p2.x, p2.y)
            end
        end

        -- 2. 회전하는 메탈 글레이브 그리기
        local bx = blade.x
        local by = blade.y
        local spinAngle = blade.progress * 30 -- 고속 회전 각도
        
        -- 중심 축 원형 베어링
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.circle("fill", bx, by, bladeSize * 0.3)

        -- 4개의 칼날 날개 조형
        for k = 0, 3 do
            local theta = spinAngle + k * (math.pi / 2)
            
            -- 칼날 끝점 및 양쪽 밑변 오프셋 계산
            local tipX = bx + math.cos(theta) * (bladeSize * 1.5)
            local tipY = by + math.sin(theta) * (bladeSize * 1.5)
            
            local leftAngle = theta + 0.4
            local leftX = bx + math.cos(leftAngle) * (bladeSize * 0.4)
            local leftY = by + math.sin(leftAngle) * (bladeSize * 0.4)
            
            local rightAngle = theta - 0.4
            local rightX = bx + math.cos(rightAngle) * (bladeSize * 0.4)
            local rightY = by + math.sin(rightAngle) * (bladeSize * 0.4)
            
            -- 입체감을 주는 명암 분할 채색: 왼쪽은 은백색 반사광, 오른쪽은 어두운 메탈 회색
            love.graphics.setColor(0.9, 0.9, 0.95)
            love.graphics.polygon("fill", bx, by, leftX, leftY, tipX, tipY)
            
            love.graphics.setColor(0.5, 0.5, 0.55)
            love.graphics.polygon("fill", bx, by, rightX, rightY, tipX, tipY)
            
            -- 칼날 날개 외곽의 날카로운 녹색 광선 베기 엣지선
            love.graphics.setColor(0.2, 1.0, 0.4, 0.85)
            love.graphics.setLineWidth(1.5)
            love.graphics.line(leftX, leftY, tipX, tipY)
        end
        
        -- 중심 코어 하이라이트
        love.graphics.setColor(1.0, 1.0, 1.0)
        love.graphics.circle("fill", bx, by, bladeSize * 0.15)
    end

    -- 총알 (Bullet)
    for _, bullet in ipairs(game.bullets) do
        love.graphics.setColor(0.5, 0.5, 1.0)
        love.graphics.circle("fill", bullet.x, bullet.y, bullet.size / 2)
    end

    -- 5. 레이저 (Laser) 그리기
    game.lasers = game.lasers or {}
    for _, laser in ipairs(game.lasers) do
        local progress = laser.timer / laser.duration
        local alpha = 1 - progress
        
        -- 레이저 두께가 서서히 얇아지는 페이드 아웃 연출
        local drawThickness = laser.thickness * (1 - progress * 0.5)
        
        -- 외부 아우라 (밝은 빨간색/마젠타 네온)
        love.graphics.setColor(1.0, 0.1, 0.4, alpha * 0.3)
        love.graphics.setLineWidth(drawThickness * 2.5)
        love.graphics.line(laser.x1, laser.y1, laser.x2, laser.y2)

        -- 중간 빛무리 (주황/네온 핑크)
        love.graphics.setColor(1.0, 0.2, 0.2, alpha * 0.6)
        love.graphics.setLineWidth(drawThickness * 1.2)
        love.graphics.line(laser.x1, laser.y1, laser.x2, laser.y2)

        -- 화이트 코어 (흰색 레이저 심지)
        love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.95)
        love.graphics.setLineWidth(drawThickness * 0.3)
        love.graphics.line(laser.x1, laser.y1, laser.x2, laser.y2)

        -- 발사구 플래시 이펙트 (시작점에 그리는 작은 원형 섬광)
        love.graphics.setColor(1.0, 0.8, 0.9, alpha * 0.8)
        love.graphics.circle("fill", laser.x1, laser.y1, drawThickness * 1.5)
    end
end

-- 통합 레벨업 선택창(스킬 또는 특성)에서 카드 클릭 시 업그레이드 적용
function Skills.applyUpgrade(game, boxIndex)
    local player = game.player
    if not player then return end

    local option = game.upgradeOptions[boxIndex]
    if not option then return end

    if option.type == "skill" then
        -- 스킬 해제 및 레벨업
        local skillIndex = option.index
        player.skillLevels[skillIndex] = (player.skillLevels[skillIndex] or 0) + 1
        
        -- 구체형 스킬의 경우 배치 상태 동기화
        if skillIndex == 1 then
            Skills.syncOrbs(game)
        end
    elseif option.type == "upgrade" then
        -- 특성 레벨업
        local upgradeIndex = option.index
        local upgrade = game.upgrades[upgradeIndex]

        if player.upgradeLevels[upgradeIndex] < 3 then
            player.upgradeLevels[upgradeIndex] = player.upgradeLevels[upgradeIndex] + 1
        end

        if upgrade.name == "Magnet" then
            player.hasMagnet = true
            player.magnetRange = player.magnetRange * 1.03
        elseif upgrade.name == "Health Boost" then
            player.maxHealth = player.maxHealth + 20
            player.health = player.health + 20
        elseif upgrade.name == "Speed Boost" then
            player.speed = player.speed * 1.05
        elseif upgrade.name == "Damage Boost" then
            player.damage = player.damage * 1.1
            -- 활성화된 구체 상태 동기화 (데미지 및 스케일링 재설정)
            Skills.syncOrbs(game)
        elseif upgrade.name == "Health Regen" then
            player.regenRate = player.regenRate + 5
        end
    end

    -- 게임 재개
    game.state = "playing"
    game.running = true
end

return Skills
