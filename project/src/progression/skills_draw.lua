-- ============================================================================
-- skills_draw.lua — 액티브 스킬 그리기 모듈 (skills.lua에서 분리)
-- ============================================================================

local SkillsDraw = {}

function SkillsDraw.draw(game, Skills)
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
                love.graphics.setColor(1.0, 0.6 - (t / trailCount) * 0.4, 0.1, alpha)
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

    -- 6. 자기장 (Magnetic Field) 그리기
    if game.activeMagneticField then
        local field = game.activeMagneticField
        local px = game.player and (game.player.x + game.player.width / 2) or 0
        local py = game.player and (game.player.y + game.player.height / 2) or 0

        local radius = field.radius

        -- 외부 연한 오라 그리기
        love.graphics.setColor(0.1, 0.6, 1.0, 0.08)
        love.graphics.circle("fill", px, py, radius)

        -- 중간 전기 필드 느낌
        love.graphics.setColor(0.2, 0.7, 1.0, 0.15)
        love.graphics.circle("fill", px, py, radius * 0.8)

        -- 바깥쪽 테두리 고리
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.3, 0.8, 1.0, 0.6)
        love.graphics.circle("line", px, py, radius)

        -- 안쪽 얇은 고리
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.4, 0.9, 1.0, 0.3)
        love.graphics.circle("line", px, py, radius * 0.9)

        -- 테두리를 따라 돌아가는 전기 스파크/도트 효과 그리기
        local sparkCount = 8
        local rotAngle = game.time * 4
        for k = 1, sparkCount do
            local angle = rotAngle + (k - 1) * (2 * math.pi / sparkCount)
            local sx = px + math.cos(angle) * radius
            local sy = py + math.sin(angle) * radius

            -- 미세 스파크
            love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
            love.graphics.circle("fill", sx, sy, 3)

            -- 스파크 잔상 아우라
            love.graphics.setColor(0.3, 0.8, 1.0, 0.4)
            love.graphics.circle("fill", sx, sy, 6)
        end
    end

    -- 7. 불장판 (Fire Patch) 그리기
    game.firePatches = game.firePatches or {}
    for _, patch in ipairs(game.firePatches) do
        local alpha = 0.45 * (1 - patch.timer / patch.duration)

        -- 이글거리는 불장판 열기 표현 (회전하지 않고, 다중 레이어가 각각 다른 주기로 일렁임)
        local pulse1 = 1 + math.sin(game.time * 7) * 0.06
        local pulse2 = 1 + math.cos(game.time * 11) * 0.08
        local pulse3 = 1 + math.sin(game.time * 16) * 0.1

        -- 1) 가장자리 옅은 열기 (적색)
        love.graphics.setColor(0.9, 0.15, 0.0, alpha * 0.25)
        love.graphics.circle("fill", patch.x, patch.y, patch.radius * 1.15 * pulse1)

        -- 2) 중간 열기 영역 (주황색)
        love.graphics.setColor(1.0, 0.45, 0.0, alpha * 0.45)
        love.graphics.circle("fill", patch.x, patch.y, patch.radius * 0.85 * pulse2)

        -- 3) 내부 가장 뜨거운 코어 (황금색)
        love.graphics.setColor(1.0, 0.75, 0.1, alpha * 0.7)
        love.graphics.circle("fill", patch.x, patch.y, patch.radius * 0.5 * pulse3)

        -- 4) 불꽃 일렁임 도트 (회전하지 않고 안팎으로 일렁이며 깜빡임)
        love.graphics.setColor(1.0, 0.95, 0.3, alpha * 0.95)
        for k = 1, 6 do
            local baseAngle = (k - 1) * (2 * math.pi / 6)
            -- k에 따라 서로 다른 오프셋 주기로 일렁임
            local flicker = math.sin(game.time * 10 + k * 2.3) * 0.2
            local dist = patch.radius * (0.3 + 0.45 * (1 + flicker))
            local sx = patch.x + math.cos(baseAngle) * dist
            -- 열기는 위쪽으로 살짝 올라가는 경향을 주어 입체감 부여 (-4 * (1 + math.sin(...)) 오프셋)
            local sy = patch.y + math.sin(baseAngle) * dist - 4 * (1 + math.sin(game.time * 5 + k))

            local sz = 2.0 + math.sin(game.time * 14 + k) * 1.2
            love.graphics.circle("fill", sx, sy, sz)
        end
    end

    -- 8. 운석 (Meteor) 그리기
    game.meteors = game.meteors or {}
    for _, met in ipairs(game.meteors) do
        local r = 18

        -- 1) 화염 트레일 잔상
        if met.trail then
            local trailCount = #met.trail
            for t = 1, trailCount do
                local pos = met.trail[t]
                local alpha = (1 - t / (trailCount + 1)) * 0.45
                love.graphics.setColor(1.0, 0.35, 0.0, alpha)
                love.graphics.circle("fill", pos.x, pos.y, r * (1.1 - t / trailCount))
            end
        end

        -- 2) 낙하지점 경고 데칼
        love.graphics.setColor(1.0, 0.15, 0.15, 0.45 * met.progress)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", met.targetX, met.targetY, met.radius * (2 - met.progress))
        love.graphics.circle("fill", met.targetX, met.targetY, 7)

        -- 3) 운석 불타는 본체
        love.graphics.setColor(1.0, 0.45, 0.05, 0.9)
        love.graphics.circle("fill", met.currentX, met.currentY, r)

        -- 4) 노란색 화염 코어
        love.graphics.setColor(1.0, 0.95, 0.2, 0.95)
        love.graphics.circle("fill", met.currentX, met.currentY, r * 0.5)
    end

    -- 9. 가시 특성 (Thorns Visuals) 그리기
    game.thornsVisuals = game.thornsVisuals or {}
    for _, tv in ipairs(game.thornsVisuals) do
        local progress = tv.timer / tv.maxTimer
        local alpha = math.max(0, tv.timer / tv.maxTimer)
        local radius = tv.radius * (0.3 + 0.7 * (1 - progress)) -- expands outward

        -- Draw 12 sharp spikes pointing outward
        local numSpikes = 12 + tv.level * 2
        love.graphics.setLineWidth(2)
        for s = 1, numSpikes do
            local angle = (s - 1) * (2 * math.pi / numSpikes) + game.time * 2
            local startDist = radius * 0.4
            local endDist = radius

            local sx = tv.x + math.cos(angle) * startDist
            local sy = tv.y + math.sin(angle) * startDist
            local ex = tv.x + math.cos(angle) * endDist
            local ey = tv.y + math.sin(angle) * endDist

            -- Draw a sharp triangle spike
            local angleLeft = angle + 0.12
            local angleRight = angle - 0.12
            local lx = tv.x + math.cos(angleLeft) * startDist
            local ly = tv.y + math.sin(angleLeft) * startDist
            local rx = tv.x + math.cos(angleRight) * startDist
            local ry = tv.y + math.sin(angleRight) * startDist

            -- Neon green/cyan spike color
            love.graphics.setColor(0.0, 1.0, 0.6, alpha * 0.3)
            love.graphics.polygon("fill", lx, ly, rx, ry, ex, ey)

            love.graphics.setColor(0.3, 1.0, 0.8, alpha * 0.8)
            love.graphics.polygon("line", lx, ly, rx, ry, ex, ey)
        end
    end

    -- 10. 커터 (Cutter) 그리기
    if game.cutters and #game.cutters > 0 then
        local player = game.player
        if player then
            local px = player.x + player.width / 2
            local py = player.y + player.height / 2

            for c, cutter in ipairs(game.cutters) do
                local drawPoints = cutter.drawPoints
                if drawPoints and #drawPoints >= 4 then
                    -- Draw 4 layers of metal blade segments
                    -- Layer 1: Ambient steel slash reflection (wide faint grey glow)
                    love.graphics.setColor(0.85, 0.85, 0.9, 0.1)
                    love.graphics.setLineWidth(26)
                    love.graphics.line(drawPoints)

                    -- Layer 2: Dark steel blade backbone (contrast backing)
                    love.graphics.setColor(0.12, 0.12, 0.15, 0.65)
                    love.graphics.setLineWidth(12)
                    love.graphics.line(drawPoints)

                    -- Layer 3: Silver blade body (sharp metal feel)
                    love.graphics.setColor(0.65, 0.65, 0.7, 0.8)
                    love.graphics.setLineWidth(8)
                    love.graphics.line(drawPoints)

                    -- Layer 4: White razor edge (extremely sharp core)
                    love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
                    love.graphics.setLineWidth(3)
                    love.graphics.line(drawPoints)

                    -- Draw a sharp wedge blade at the cutter tip
                    local tx = drawPoints[#drawPoints - 1]
                    local ty = drawPoints[#drawPoints]

                    -- The tangent angle at the tip can be calculated using the last segment
                    local ptx = drawPoints[#drawPoints - 3]
                    local pty = drawPoints[#drawPoints - 2]
                    local tangentAngle = math.atan2(ty - pty, tx - ptx)

                    love.graphics.push()
                    love.graphics.translate(tx, ty)
                    love.graphics.rotate(tangentAngle)

                    -- Draw steel diamond tip (scaled up to match thicker blade)
                    love.graphics.setColor(0.2, 0.2, 0.22, 0.9)
                    love.graphics.polygon("fill", 0, 0, -18, -10, -28, 0, -18, 10)
                    love.graphics.setColor(0.9, 0.9, 0.95, 0.95)
                    love.graphics.polygon("line", 0, 0, -18, -10, -28, 0, -18, 10)

                    love.graphics.pop()
                end
            end

            -- Draw a rotating spark core at the player center (silver/grey)
            love.graphics.setColor(0.7, 0.7, 0.75, 0.2)
            love.graphics.circle("fill", px, py, 18 + math.sin(game.time * 15) * 3)
        end
    end

    -- 11. 체인 (Chain) 그리기
    game.chains = game.chains or {}
    for _, chain in ipairs(game.chains) do
        local sx, sy
        if chain.sourceType == "player" then
            local player = game.player
            if player then
                sx = player.x + player.width / 2
                sy = player.y + player.height / 2
            end
        else
            sx = chain.sourceX
            sy = chain.sourceY
        end

        -- Target coordinates
        local tx, ty
        if Skills.isEnemyAlive(game, chain.target) then
            tx = chain.target.x + chain.target.width / 2
            ty = chain.target.y + chain.target.height / 2
            chain.lastTargetX = tx
            chain.lastTargetY = ty
        else
            tx = chain.lastTargetX or sx
            ty = chain.lastTargetY or sy
        end

        if sx and sy and tx and ty then
            -- Determine transparency based on state
            local alpha = 0.85
            if chain.state == "fading" then
                alpha = 0.85 * math.max(0, chain.timer / chain.fadeDuration)
            end

            -- Current tip position based on progress
            local cx = sx + (tx - sx) * chain.progress
            local cy = sy + (ty - sy) * chain.progress

            local dx = cx - sx
            local dy = cy - sy
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist > 0 then
                local ux = dx / dist
                local uy = dy / dist

                -- Draw neon cyan glow (wide/faint)
                love.graphics.setColor(0.1, 0.8, 1.0, alpha * 0.25)
                love.graphics.setLineWidth(10)
                love.graphics.line(sx, sy, cx, cy)

                -- Draw neon cyan main core
                love.graphics.setColor(0.2, 0.7, 0.95, alpha * 0.7)
                love.graphics.setLineWidth(4)
                love.graphics.line(sx, sy, cx, cy)

                -- Draw interlocking chain links
                local linkSpacing = 16
                local numLinks = math.floor(dist / linkSpacing)
                love.graphics.setLineWidth(1.5)
                local angle = math.atan2(dy, dx)

                for k = 0, numLinks do
                    local t = k * linkSpacing
                    local lx = sx + ux * t
                    local ly = sy + uy * t

                    love.graphics.push()
                    love.graphics.translate(lx, ly)
                    -- Alternate links orientation to simulate 3D chain structure
                    love.graphics.rotate(angle + (k % 2 == 0 and 0 or math.pi / 2))

                    -- Steel grey / glowing cyan linked capsule
                    love.graphics.setColor(0.4, 0.85, 1.0, alpha * 0.85)
                    love.graphics.ellipse("line", 0, 0, 7, 3.5)

                    -- Draw link inner color
                    love.graphics.setColor(0.1, 0.1, 0.15, alpha * 0.5)
                    love.graphics.ellipse("fill", 0, 0, 5, 2)

                    love.graphics.pop()
                end

                -- Draw target lock animation for active state
                if chain.state == "active" and Skills.isEnemyAlive(game, chain.target) then
                    local pulse = 1 + math.sin(game.time * 12) * 0.15
                    local r_lock = 14 * pulse

                    -- Glowing neon circle around target
                    love.graphics.setLineWidth(1.5)
                    love.graphics.setColor(0.2, 0.9, 1.0, alpha * 0.3)
                    love.graphics.circle("fill", tx, ty, r_lock)

                    love.graphics.setColor(0.4, 1.0, 1.0, alpha * 0.8)
                    love.graphics.circle("line", tx, ty, r_lock)

                    -- Draw lock pointers (crosshairs)
                    for k = 0, 3 do
                        local rotA = game.time * 2 + k * (math.pi / 2)
                        local px1 = tx + math.cos(rotA) * (r_lock - 4)
                        local py1 = ty + math.sin(rotA) * (r_lock - 4)
                        local px2 = tx + math.cos(rotA) * (r_lock + 4)
                        local py2 = ty + math.sin(rotA) * (r_lock + 4)
                        love.graphics.line(px1, py1, px2, py2)
                    end
                end
            end
        end
    end

    -- 12. 추적 구체 (Seeker Orb) 그리기
    game.seekerOrbs = game.seekerOrbs or {}
    for _, orb in ipairs(game.seekerOrbs) do
        local r = orb.size / 2

        -- Draw trail (Magenta/pink glowing trail)
        if orb.trail then
            local trailCount = #orb.trail
            for t = 1, trailCount do
                local p = orb.trail[t]
                local alpha = (1 - t / (trailCount + 1)) * 0.3
                local trailR = r * (1 - t / (trailCount + 2))

                love.graphics.setColor(0.9, 0.1, 0.6, alpha)
                love.graphics.circle("fill", p.x, p.y, trailR)
            end
        end

        -- Orb Core & Aura
        local pulse = 1.0 + math.sin(game.time * 12) * 0.1
        if orb.state == "charging" then
            -- Pulsing charge aura
            love.graphics.setColor(0.7, 0.1, 0.9, 0.15)
            love.graphics.circle("fill", orb.x, orb.y, r * 2.0 * pulse)
            love.graphics.setColor(0.9, 0.1, 0.7, 0.4)
            love.graphics.circle("fill", orb.x, orb.y, r * 1.3 * pulse)

            -- Floating ring
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1.0, 0.3, 0.8, 0.3)
            love.graphics.circle("line", orb.x, orb.y, r * 1.8)
        else
            -- Launched aura
            love.graphics.setColor(0.9, 0.1, 0.7, 0.25)
            love.graphics.circle("fill", orb.x, orb.y, r * 1.6)
            love.graphics.setColor(1.0, 0.2, 0.8, 0.5)
            love.graphics.circle("fill", orb.x, orb.y, r * 1.1)
        end

        -- White hot core
        love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
        love.graphics.circle("fill", orb.x, orb.y, r * 0.5)
    end

    -- Draw explosions
    game.seekerExplosions = game.seekerExplosions or {}
    for _, expl in ipairs(game.seekerExplosions) do
        local progress = expl.timer / expl.duration
        local alpha = 1.0 - progress
        local currentR = expl.radius * (0.3 + 0.7 * progress)

        -- Main explosion ring
        love.graphics.setColor(0.9, 0.1, 0.7, alpha * 0.4)
        love.graphics.circle("fill", expl.x, expl.y, currentR)

        -- Inner bright core
        love.graphics.setColor(1.0, 0.6, 0.9, alpha * 0.6)
        love.graphics.circle("fill", expl.x, expl.y, currentR * 0.6)

        -- Outer line border
        love.graphics.setLineWidth(2)
        love.graphics.setColor(1.0, 0.2, 0.8, alpha)
        love.graphics.circle("line", expl.x, expl.y, currentR)
    end
end

return SkillsDraw
