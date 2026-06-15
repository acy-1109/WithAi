-- ============================================================================
-- boss_draw.lua — 보스 렌더링 및 연출 모듈 (spawner.lua에서 분리)
-- ============================================================================

local BossDraw = {}

-- 3단계 번개 빔 그리기 헬퍼 함수
local function drawLightningBeam(x1, y1, x2, y2, segments, displacement)
    local dx = x2 - x1
    local dy = y2 - y1
    local totalDist = math.sqrt(dx * dx + dy * dy)
    if totalDist == 0 then return end
    local dirX, dirY = dx / totalDist, dy / totalDist
    local perpX, perpY = -dirY, dirX

    local pts = { x1, y1 }
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

-- 보스 및 관련 개체 그리기 함수
function BossDraw.draw(game, enemy, currentStage, cx, cy, halfW, pulse)
    local col = enemy.color or { 1.0, 0.3, 0.3 }

    if currentStage < 3 and enemy.type == "boss" then
        local isStage2 = currentStage >= 2
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
                love.graphics.circle("line", p.x + p.width / 2, p.y + p.height / 2,
                    16 + math.sin(game.time * 15) * 4)
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

        -- 텔레포트 시 페이드 인 및 확장 연출 적용
        local eyeSizeMult = 1.0
        local fadeProgress = 1.0
        if enemy.teleportFade and enemy.teleportFade > 0 then
            fadeProgress = 1 - (enemy.teleportFade / 0.3)
            baseAlpha = baseAlpha * fadeProgress
            pulse = pulse * (0.5 + 0.5 * fadeProgress)
            halfW = halfW * (0.5 + 0.5 * fadeProgress)
            eyeSizeMult = 0.5 + 0.5 * fadeProgress
        end

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
            innerR = math.max(1, halfW * 0.35)
            outerR = halfW * 1.3
        elseif enemy.bossState == "charging_dash" or enemy.bossState == "charging_crossfire" then
            rotationAngle = game.time * 8.0 + math.sin(game.time * 35) * 0.1
            innerR = math.max(1, halfW * 0.5)
            outerR = halfW * 1.4
        elseif enemy.bossState == "exhausted" then
            rotationAngle = game.time * 0.3
            innerR = math.max(1, halfW * 0.4)
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
        love.graphics.circle("fill", cx, cy, 14 * eyePulse * eyeSizeMult)
        love.graphics.setColor(0.04, 0.05, 0.08, 0.9 * baseAlpha)
        love.graphics.circle("fill", cx, cy, 8 * eyePulse * eyeSizeMult)
        love.graphics.setColor(eyeCol[1], eyeCol[2], eyeCol[3], 0.95 * baseAlpha)
        love.graphics.circle("fill", cx, cy, 4 * eyePulse * eyeSizeMult)
        love.graphics.setColor(1.0, 1.0, 1.0, 0.9 * baseAlpha)
        love.graphics.circle("fill", cx - 1.5 * eyePulse * eyeSizeMult, cy - 1.5 * eyePulse * eyeSizeMult,
            1.5 * eyePulse * eyeSizeMult)

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
                    if other.type == "tesla_pylon" and other.parentBoss == enemy then
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
                love.graphics.circle("fill", math.cos(vAngle - math.pi / 2) * rOuter,
                    math.sin(vAngle - math.pi / 2) * rOuter, 4)
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
            local parent = enemy.parentBoss
            if not parent then
                for _, other in ipairs(game.enemies) do
                    if other.type == "boss" then
                        parent = other
                        break
                    end
                end
            end
            if parent then
                bCenterX = parent.x + parent.width / 2
                bCenterY = parent.y + parent.height / 2
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

            -- Draw Shield Strike warning indicator / lines
            if enemy.bossState == "shield_strike" and enemy.shieldStrikePhase == "charge" then
                for _, other in ipairs(game.enemies) do
                    if other.type == "aegis_shield" and other.parentBoss == enemy then
                        local ocx = other.x + other.width / 2
                        local ocy = other.y + other.height / 2
                        local tx = enemy.strikeTargetX or cx
                        local ty = enemy.strikeTargetY or cy

                        -- Glowing red-orange laser line
                        love.graphics.setLineWidth(1.5)
                        love.graphics.setColor(1.0, 0.35, 0.1, 0.4 + math.sin(game.time * 25) * 0.2)
                        love.graphics.line(ocx, ocy, tx, ty)

                        -- Target lock circle at target location
                        love.graphics.circle("line", tx, ty, 8 + math.sin(game.time * 15) * 2)
                    end
                end
            end
        end
    elseif currentStage == 6 and enemy.type == "boss" then
        -- ==========================================
        -- BOSS 6 (Chronos Weaver) drawing
        -- ==========================================
        -- 1. Draw "TIME REWIND", "TIME STOP", or "TEMPORAL LASERS" warning / info text
        if enemy.bossState == "time_rewind" then
            love.graphics.setColor(0.1, 0.9, 0.6, 0.85 + math.sin(game.time * 20) * 0.15)
            love.graphics.printf("TIME REWIND", cx - 100, enemy.y - 25, 200, "center")
        elseif enemy.bossState == "time_stop" then
            love.graphics.setColor(0.8, 0.2, 1.0, 0.85 + math.sin(game.time * 20) * 0.15)
            love.graphics.printf("TIME STOP", cx - 100, enemy.y - 25, 200, "center")
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

        -- 2b. Draw time stop visual effects
        if enemy.bossState == "time_stop" then
            local phase = enemy.timeStopPhase or "charging"
            local timer = enemy.timeStopTimer or 0

            if phase == "charging" then
                -- Expanding purple warning ring
                local progress = timer / 1.0
                love.graphics.setColor(0.8, 0.2, 1.0, 0.6)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", cx, cy, enemy.width * 2.5 * (1 - progress))
                love.graphics.setColor(0.8, 0.2, 1.0, 0.2)
                love.graphics.circle("fill", cx, cy, enemy.width * 2.5)
            elseif phase == "active" then
                -- Frozen time effect - purple overlay
                love.graphics.setColor(0.6, 0.1, 0.9, 0.15)
                love.graphics.rectangle("fill", 0, 0, game.world.width, game.world.height)

                -- Draw frozen bullets around player
                if enemy.timeStopBullets then
                    for _, bullet in ipairs(enemy.timeStopBullets) do
                        love.graphics.setColor(0.8, 0.2, 1.0, 0.8)
                        love.graphics.circle("fill", bullet.x, bullet.y, bullet.size)
                        love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
                        love.graphics.circle("fill", bullet.x, bullet.y, bullet.size * 0.4)
                    end
                end
            elseif phase == "release" then
                -- Release shockwave effect
                local progress = (timer - 2.5) / 1.0
                love.graphics.setColor(0.8, 0.2, 1.0, 0.6 * (1 - progress))
                love.graphics.setLineWidth(4)
                love.graphics.circle("line", cx, cy, enemy.width * 3.0 * progress)
            end
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
    elseif currentStage == 7 or enemy.type == "glitch_clone" then
        -- ==========================================
        -- BOSS 7 (Glitch Overlord) & Glitch Clone drawing
        -- ==========================================
        local isClone = (enemy.type == "glitch_clone")
        local baseAlpha = isClone and (0.5 + math.sin(game.time * 25) * 0.15) or 1.0

        -- Draw status text above boss/clone
        if enemy.bossState == "system_hack" then
            love.graphics.setColor(1.0, 0.1, 0.4, baseAlpha * (0.85 + math.sin(game.time * 20) * 0.15))
            love.graphics.printf("SYSTEM HACKING", cx - 100, enemy.y - 25, 200, "center")
        elseif enemy.bossState == "corrupt_clone" then
            love.graphics.setColor(0.1, 0.9, 0.9, baseAlpha * (0.85 + math.sin(game.time * 20) * 0.15))
            love.graphics.printf("CORRUPTING SYS", cx - 100, enemy.y - 25, 200, "center")
        elseif enemy.bossState == "overflow_firing" or enemy.bossState == "memory_overflow" then
            love.graphics.setColor(0.9, 0.9, 0.1, baseAlpha * (0.85 + math.sin(game.time * 20) * 0.15))
            love.graphics.printf("MEMORY OVERFLOW", cx - 100, enemy.y - 25, 200, "center")
        end

        if isClone then
            love.graphics.setColor(0.1, 0.9, 0.9, baseAlpha * 0.75)
            love.graphics.printf("GLITCH CLONE", cx - 100, enemy.y - 20, 200, "center")
        end

        -- Warning indicator ring for system_hack channeling
        if enemy.bossState == "system_hack" and enemy.stateTimer then
            local progress = (1.2 - enemy.stateTimer) / 1.2
            love.graphics.setColor(1.0, 0.1, 0.4, 0.4 * baseAlpha)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", cx, cy, 400 * progress)
            love.graphics.circle("line", cx, cy, 400)
        end

        -- 1. Draw three jittering overlapping cubes to simulate chromatic aberration
        local jitterRange = 4
        local rOffsetX = math.random(-jitterRange, jitterRange)
        local rOffsetY = math.random(-jitterRange, jitterRange)
        local cOffsetX = math.random(-jitterRange, jitterRange)
        local cOffsetY = math.random(-jitterRange, jitterRange)

        local sizeMult = pulse
        local currentW = enemy.width * sizeMult

        -- Red layer
        love.graphics.setColor(1.0, 0.0, 0.3, baseAlpha * 0.7)
        love.graphics.rectangle("fill", cx - currentW / 2 + rOffsetX, cy - currentW / 2 + rOffsetY, currentW,
            currentW)

        -- Cyan layer
        love.graphics.setColor(0.0, 1.0, 1.0, baseAlpha * 0.7)
        love.graphics.rectangle("fill", cx - currentW / 2 + cOffsetX, cy - currentW / 2 + cOffsetY, currentW,
            currentW)

        -- Main white/magenta core layer
        if isClone then
            love.graphics.setColor(0.2, 0.8, 0.8, baseAlpha * 0.9)
        else
            love.graphics.setColor(1.0, 1.0, 1.0, baseAlpha * 0.85)
        end
        love.graphics.rectangle("fill", cx - currentW / 2, cy - currentW / 2, currentW, currentW)
        love.graphics.setColor(1.0, 1.0, 1.0)
        love.graphics.setLineWidth(1)

        -- 2. Draw random numeric glitch glyphs floating around the boss
        love.graphics.setColor(0.1, 0.9, 0.5, baseAlpha * 0.6)
        local glyphs = { "0", "1", "4", "A", "F", "X", "Y", "9", "3", "E" }
        for k = 1, 6 do
            local angle = k * (2 * math.pi / 6) + game.time * 2.0
            local distOff = halfW * (1.2 + 0.3 * math.sin(game.time * 5 + k))
            local gx = cx + math.cos(angle) * distOff
            local gy = cy + math.sin(angle) * distOff
            local glyphIndex = math.floor((game.time * 12 + k * 4) % #glyphs) + 1
            local glyph = glyphs[glyphIndex]
            love.graphics.print(glyph, gx - 4, gy - 6)
        end
    elseif enemy.type == "void_anchor" then
        -- Stationary pulsing violet crystal shape
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.rotate(game.time * 1.5)
        local anchorPulse = 1.0 + math.sin(game.time * 10) * 0.12

        -- Outer pulsing glow
        love.graphics.setColor(0.7, 0.2, 0.9, 0.25)
        love.graphics.polygon("fill", 0, -18 * anchorPulse, 12 * anchorPulse, 0, 0, 18 * anchorPulse,
            -12 * anchorPulse, 0)

        -- Inner crystal core
        love.graphics.setColor(0.9, 0.3, 1.0, 0.9)
        love.graphics.polygon("fill", 0, -12 * anchorPulse, 8 * anchorPulse, 0, 0, 12 * anchorPulse,
            -8 * anchorPulse, 0)

        love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
        love.graphics.circle("fill", 0, 0, 3 * anchorPulse)

        love.graphics.setColor(0.8, 0.2, 0.9, 0.8)
        love.graphics.setLineWidth(1.8)
        love.graphics.polygon("line", 0, -18 * anchorPulse, 12 * anchorPulse, 0, 0, 18 * anchorPulse,
            -12 * anchorPulse, 0)
        love.graphics.pop()
    elseif currentStage == 8 and enemy.type == "boss" then
        -- ==========================================
        -- BOSS 8 (Singularity Nexus) drawing
        -- ==========================================
        love.graphics.setLineWidth(1.5)
        for rIdx = 1, 3 do
            local ringPulse = ((game.time * 0.8 + rIdx / 3) % 1.0)
            local ringRadius = halfW * 1.8 * (1.0 - ringPulse)
            love.graphics.setColor(0.5, 0.2, 0.9, ringPulse * 0.45)
            love.graphics.circle("line", cx, cy, ringRadius)
        end

        -- If event horizon contracts, draw contracting rings
        if enemy.bossState == "horizon_contracting" and enemy.ringsPassed then
            local ringStartRadii = { 1000, 1300, 1600 }
            local gapAngle = (game.time * 1.5) % (2 * math.pi)
            for k = 1, 3 do
                if not enemy.ringsPassed[k] then
                    local r = ringStartRadii[k] * (enemy.stateTimer / 3.0)
                    love.graphics.setLineWidth(3)
                    love.graphics.setColor(0.6, 0.1, 0.9, 0.75)
                    love.graphics.arc("line", cx, cy, r, gapAngle + 0.4, gapAngle - 0.4 + 2 * math.pi)

                    love.graphics.setColor(0.2, 0.5, 1.0, 0.8)
                    love.graphics.circle("fill", cx + math.cos(gapAngle) * r, cy + math.sin(gapAngle) * r, 8)
                end
            end
        end

        -- Accretion Disk (spinning dust/gas with colorful HSL-tailored particles)
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.rotate(game.time * 3.5)

        -- Swirling dust layers
        for dIdx = 1, 4 do
            local sizeScale = 1.0 + dIdx * 0.15
            local rotAngle = (dIdx - 1) * (math.pi / 4)
            love.graphics.push()
            love.graphics.rotate(rotAngle)
            love.graphics.setColor(0.4, 0.1, 0.8, 0.1)
            love.graphics.ellipse("fill", 0, 0, halfW * 1.6 * sizeScale, halfW * 0.9 * sizeScale)
            love.graphics.setColor(0.6, 0.2, 0.9, 0.75)
            love.graphics.setLineWidth(1.5)
            love.graphics.ellipse("line", 0, 0, halfW * 1.6 * sizeScale, halfW * 0.9 * sizeScale)
            love.graphics.pop()
        end
        love.graphics.pop()

        -- Event Horizon (Pitch black center core)
        local eventHorizonRadius = halfW * 0.65
        love.graphics.setColor(0.0, 0.0, 0.0, 1.0)
        love.graphics.circle("fill", cx, cy, eventHorizonRadius)

        -- Glowing accretion rim (intense violet/blue highlight)
        love.graphics.setColor(0.7, 0.2, 1.0, 0.9)
        love.graphics.setLineWidth(3.0)
        love.graphics.circle("line", cx, cy, eventHorizonRadius)

        -- Warning indicators / status texts
        if enemy.bossState == "gravity_well" then
            love.graphics.setColor(0.5, 0.2, 0.9, 0.85 + math.sin(game.time * 20) * 0.15)
            love.graphics.printf("GRAVITY WELL CHARGING", cx - 120, enemy.y - 25, 240, "center")
        elseif enemy.bossState == "gravity_pulling" then
            love.graphics.setColor(0.2, 0.6, 1.0, 0.85 + math.sin(game.time * 20) * 0.15)
            love.graphics.printf("GRAVITATIONAL PULL", cx - 120, enemy.y - 25, 240, "center")
        elseif enemy.bossState == "event_horizon" then
            love.graphics.setColor(0.8, 0.1, 0.8, 0.85 + math.sin(game.time * 20) * 0.15)
            love.graphics.printf("EVENT HORIZON INCOMING", cx - 120, enemy.y - 25, 240, "center")
        elseif enemy.bossState == "horizon_contracting" then
            love.graphics.setColor(1.0, 0.1, 0.1, 0.85 + math.sin(game.time * 20) * 0.15)
            love.graphics.printf("HORIZON CONTRACTING", cx - 120, enemy.y - 25, 240, "center")
        elseif enemy.bossState == "phase_shift" or enemy.bossState == "shifting_invulnerable" then
            love.graphics.setColor(0.9, 0.2, 0.9, 0.85 + math.sin(game.time * 20) * 0.15)
            love.graphics.printf("PHASE SHIFT: INVULNERABLE", cx - 120, enemy.y - 25, 240, "center")
        end
    elseif currentStage >= 9 and enemy.type == "boss" then
        -- ==========================================
        -- BOSS 9 (Nebula Seraph) drawing
        -- ==========================================
        if enemy.bossState == "supernova" then
            love.graphics.setColor(1.0, 0.8, 0.2, 0.85 + math.sin(game.time * 20) * 0.15)
            love.graphics.printf("SUPERNOVA INCOMING", cx - 120, enemy.y - 25, 240, "center")
        elseif enemy.bossState == "binary_star" then
            love.graphics.setColor(1.0, 0.9, 0.5, 0.85 + math.sin(game.time * 20) * 0.15)
            love.graphics.printf("BINARY SUNS IGNITING", cx - 120, enemy.y - 25, 240, "center")
        elseif enemy.bossState == "binary_laser" then
            love.graphics.setColor(1.0, 0.5, 0.1, 0.85 + math.sin(game.time * 20) * 0.15)
            love.graphics.printf("BINARY SOLAR LASERS", cx - 120, enemy.y - 25, 240, "center")
        elseif enemy.bossState == "meteor_storm" or enemy.bossState == "meteor_falling" then
            love.graphics.setColor(1.0, 0.3, 0.1, 0.85 + math.sin(game.time * 20) * 0.15)
            love.graphics.printf("METEOR STORM CALLED", cx - 120, enemy.y - 25, 240, "center")
        end

        -- A. Supernova warning / charging shelter zone
        if enemy.bossState == "supernova" then
            if enemy.shelterX and enemy.shelterY then
                local sx, sy, sr = enemy.shelterX, enemy.shelterY, enemy.shelterRadius
                local pulseRate = 0.8 + 0.2 * math.sin(game.time * 12)

                love.graphics.setColor(1.0, 0.85, 0.3, 0.15 * pulseRate)
                love.graphics.circle("fill", sx, sy, sr)

                love.graphics.setColor(1.0, 0.9, 0.5, 0.8 * pulseRate)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", sx, sy, sr)

                love.graphics.setColor(1.0, 0.9, 0.6, 0.9)
                love.graphics.printf("SHELTER", sx - 60, sy - 8, 120, "center")
            end

            local progress = (3.0 - enemy.stateTimer) / 3.0
            love.graphics.setColor(1.0, 0.75, 0.1, 0.35 * progress)
            love.graphics.setLineWidth(5)
            love.graphics.circle("line", cx, cy, 750 * (1.0 - progress))
        end

        -- Supernova Explosion Ring Flash
        if enemy.supernovaExplodeTimer then
            local progress = (0.5 - enemy.supernovaExplodeTimer) / 0.5
            local alpha = enemy.supernovaExplodeTimer / 0.5
            love.graphics.setColor(1.0, 0.9, 0.4, alpha * 0.55)
            love.graphics.circle("fill", cx, cy, 900 * progress)
            love.graphics.setColor(1.0, 1.0, 1.0, alpha * 0.9)
            love.graphics.setLineWidth(5)
            love.graphics.circle("line", cx, cy, 900 * progress)
        end

        -- B. Binary Suns & Lasers
        if enemy.bossState == "binary_laser" and enemy.binaryAngle then
            local orbitRadius = 185
            local s1x = cx + math.cos(enemy.binaryAngle) * orbitRadius
            local s1y = cy + math.sin(enemy.binaryAngle) * orbitRadius
            local s2x = cx + math.cos(enemy.binaryAngle + math.pi) * orbitRadius
            local s2y = cy + math.sin(enemy.binaryAngle + math.pi) * orbitRadius

            local lx1 = cx - math.cos(enemy.binaryAngle) * 900
            local ly1 = cy - math.sin(enemy.binaryAngle) * 900
            local lx2 = cx + math.cos(enemy.binaryAngle) * 900
            local ly2 = cy + math.sin(enemy.binaryAngle) * 900

            love.graphics.setColor(1.0, 0.5, 0.1, 0.3)
            love.graphics.setLineWidth(14)
            love.graphics.line(lx1, ly1, lx2, ly2)

            love.graphics.setColor(1.0, 0.85, 0.3, 0.75)
            love.graphics.setLineWidth(6)
            love.graphics.line(lx1, ly1, lx2, ly2)

            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.setLineWidth(1.8)
            love.graphics.line(lx1, ly1, lx2, ly2)

            for _, sunPos in ipairs({ { x = s1x, y = s1y }, { x = s2x, y = s2y } }) do
                local sunPulse = 1.0 + math.sin(game.time * 15) * 0.15
                love.graphics.setColor(1.0, 0.85, 0.2, 0.4)
                love.graphics.circle("fill", sunPos.x, sunPos.y, 22 * sunPulse)
                love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
                love.graphics.circle("fill", sunPos.x, sunPos.y, 12 * sunPulse)
            end
        elseif enemy.bossState == "binary_star" then
            local progress = (1.2 - enemy.stateTimer) / 1.2
            local orbitRadius = 185
            local s1x = cx + math.cos(0) * orbitRadius
            local s1y = cy + math.sin(0) * orbitRadius
            local s2x = cx + math.cos(math.pi) * orbitRadius
            local s2y = cy + math.sin(math.pi) * orbitRadius

            for _, sunPos in ipairs({ { x = s1x, y = s1y }, { x = s2x, y = s2y } }) do
                love.graphics.setColor(1.0, 0.8, 0.2, 0.5 * progress)
                love.graphics.setLineWidth(1.5)
                love.graphics.circle("line", sunPos.x, sunPos.y, 30 * (1.0 - progress))
                love.graphics.circle("fill", sunPos.x, sunPos.y, 10 * progress)
            end
        end

        -- C. Draw Meteor falling indicators
        if game.cosmicMeteors then
            for _, met in ipairs(game.cosmicMeteors) do
                if not met.exploded then
                    local progress = (1.2 - met.timer) / 1.2
                    love.graphics.setColor(1.0, 0.35, 0.1, 0.65 * (0.3 + 0.7 * progress))
                    love.graphics.setLineWidth(2)
                    love.graphics.circle("line", met.x, met.y, met.radius)

                    love.graphics.setColor(1.0, 0.5, 0.15, 0.15 * progress)
                    love.graphics.circle("fill", met.x, met.y, met.radius * progress)
                end
            end
        end

        -- D. Main Celestial Wing Body (Seraph wing shapes)
        love.graphics.push()
        love.graphics.translate(cx, cy)

        love.graphics.rotate(game.time * 0.8)
        love.graphics.setColor(1.0, 0.85, 0.15, 0.12)
        love.graphics.circle("fill", 0, 0, halfW * 1.25)
        love.graphics.setColor(1.0, 0.85, 0.15, 0.75)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, halfW * 1.25)
        love.graphics.pop()

        -- Draw Angel Wings (6 radiating wings)
        love.graphics.push()
        love.graphics.translate(cx, cy)
        local wingRot = game.time * 0.4
        love.graphics.rotate(wingRot)
        for wIdx = 1, 6 do
            local angle = (wIdx - 1) * (2 * math.pi / 6)
            love.graphics.push()
            love.graphics.rotate(angle)

            love.graphics.setColor(1.0, 0.95, 0.7, 0.95)
            love.graphics.polygon("fill",
                0, 0,
                -10, -halfW * 1.3,
                0, -halfW * 1.6,
                10, -halfW * 1.3
            )

            love.graphics.setColor(1.0, 0.8, 0.1, 0.9)
            love.graphics.setLineWidth(2)
            love.graphics.polygon("line",
                0, 0,
                -10, -halfW * 1.3,
                0, -halfW * 1.6,
                10, -halfW * 1.3
            )
            love.graphics.pop()
        end
        love.graphics.pop()

        -- E. Golden Sun Halo nucleus core
        local coreSize = halfW * 0.65
        love.graphics.setColor(1.0, 0.9, 0.5, 0.35)
        love.graphics.circle("fill", cx, cy, coreSize)
        love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
        love.graphics.circle("fill", cx, cy, coreSize * 0.6)

        love.graphics.setColor(1.0, 0.85, 0.15, 0.8)
        love.graphics.setLineWidth(2.5)
        love.graphics.circle("line", cx, cy, coreSize)
    end
end

return BossDraw
