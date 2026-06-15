-- ============================================================================
-- hud.lua — 게임 UI, 스킬/특성 선택 박스 및 각종 상태 화면 렌더링 모듈
-- ============================================================================

local HUD = {}

local fontCache = {}
local function getFont(size)
    if not fontCache[size] then
        fontCache[size] = love.graphics.newFont(size)
    end
    return fontCache[size]
end

-- Detailed lookup table for skill descriptions by level
local skillLevelDescriptions = {
    [1] = { -- Orbiting Orb
        "Spawn orbiting orb",
        "Add 1 orb",
        "Add orb & increase speed",
        "Add orb & increase damage",
        "Add orb & increase speed further",
    },
    [2] = { -- Thunder
        "Strike lightning",
        "Reduce cooldown & increase damage",
        "Increase lightning count",
        "Reduce cooldown & increase damage",
        "Increase lightning count more",
    },
    [3] = { -- Blade
        "Fire tracking blade",
        "Reduce cooldown & increase damage",
        "Fire 2 blades",
        "Reduce cooldown",
        "Fire 3 blades & increase size",
    },
    [4] = { -- Bullet
        "Fire bullet",
        "Add piercing & reduce cooldown",
        "Fire triple shot",
        "Reduce cooldown",
        "Increase damage & reduce cooldown",
    },
    [5] = { -- Laser
        "Fire laser beam",
        "Increase damage & duration",
        "Increase thickness & damage",
        "Reduce cooldown",
        "Hyper laser: max damage",
    },
    [6] = { -- Magnetic Field
        "Deploy magnetic field",
        "Increase damage & reduce cooldown",
        "Increase duration",
        "Increase radius & damage",
        "Reduce cooldown",
    },
    [7] = { -- Meteor
        "Call down meteor",
        "Reduce cooldown & increase damage",
        "Increase meteor count",
        "Leave fire patches",
        "Increase meteor count more",
    },
    [8] = { -- Cutter
        "Extend energy blade",
        "Add blade & increase damage",
        "Add blade & increase speed",
        "Add blade & increase damage",
        "Add blade & increase speed"
    },
    [9] = { -- Chain
        "Fire chain to lock enemy",
        "Increase lock duration",
        "Chain cascades to nearby enemy",
        "Fire 2 chains",
        "Reduce cooldown significantly"
    },
    [10] = { -- Seeker Orb
        "Spawn charging orb",
        "Increase orb count to 2",
        "Reduce cooldown & increase damage",
        "Increase orb count to 3",
        "Add explosion on impact"
    }
}

-- Detailed lookup table for upgrade descriptions by level
local upgradeLevelDescriptions = {
    [1] = { -- Magnet
        "Pull experience orbs",
        "Increase attraction range",
        "Increase range further"
    },
    [3] = { -- Speed Boost
        "Increase movement speed",
        "Increase speed more",
        "Increase speed even more"
    },
    [5] = { -- Health Regen
        "Regenerate health",
        "Regenerate more health",
        "Regenerate even more health"
    },
    [6] = { -- EXP Boost
        "Increase experience gained",
        "Increase experience more",
        "Increase experience even more"
    },
    [7] = { -- Thorns
        "Retaliate when hit",
        "Retaliate more often",
        "Retaliate most often"
    },
    [8] = { -- Energy Shield
        "Generate block shield",
        "Generate shield faster",
        "Generate shield fastest"
    }
}

-- 카드 내에 심볼/아이콘을 그리는 함수 (인게임 비주얼 반영)
function HUD.drawCardIcon(option, cx, cy, size)
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)

    local r = size / 2
    local time = love.timer.getTime()

    if option.type == "skill" then
        if option.index == 1 then
            -- Orbiting Orb
            local rotAngle = time * 2.5
            love.graphics.setColor(1.0, 0.75, 0.2, 0.4)
            love.graphics.setLineWidth(1.5)
            love.graphics.circle("line", cx, cy, r * 1.3)

            for k = 0, 3 do
                local dotAngle = rotAngle + k * (math.pi / 2)
                local dx = cx + math.cos(dotAngle) * (r * 1.3)
                local dy = cy + math.sin(dotAngle) * (r * 1.3)
                love.graphics.circle("fill", dx, dy, 2.5)
            end

            local pulse = 1 + math.sin(time * 6) * 0.08
            love.graphics.setColor(1.0, 0.5, 0.0, 0.25)
            love.graphics.circle("fill", cx, cy, r * 1.0 * pulse)

            love.graphics.setColor(1.0, 0.8, 0.1, 0.5)
            love.graphics.circle("fill", cx, cy, r * 0.7 * pulse)

            love.graphics.setColor(1.0, 0.95, 0.3, 0.85)
            love.graphics.circle("fill", cx, cy, r * 0.45)

            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.circle("fill", cx, cy, r * 0.22)

        elseif option.index == 2 then
            -- Thunder
            love.graphics.setColor(0.3, 0.4, 1.0, 0.3)
            love.graphics.setLineWidth(8)
            local pts = {
                cx - r * 0.2, cy - r * 0.8,
                cx + r * 0.3, cy - r * 0.1,
                cx - r * 0.3, cy + r * 0.1,
                cx + r * 0.1, cy + r * 0.8
            }
            love.graphics.line(pts)

            love.graphics.setColor(0.2, 0.8, 1.0, 0.6)
            love.graphics.setLineWidth(4)
            love.graphics.line(pts)

            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.setLineWidth(1.5)
            love.graphics.line(pts)

            love.graphics.setColor(0.6, 0.9, 1.0, 0.8)
            love.graphics.circle("fill", cx - r * 0.5, cy - r * 0.3, 2.5)
            love.graphics.circle("fill", cx + r * 0.6, cy + r * 0.3, 2.5)

        elseif option.index == 3 then
            -- Blade (Glaive)
            local spinAngle = time * 4
            love.graphics.setColor(0.5, 0.5, 0.5, 0.9)
            love.graphics.circle("fill", cx, cy, r * 0.3)

            for k = 0, 3 do
                local theta = spinAngle + k * (math.pi / 2)
                local tipX = cx + math.cos(theta) * (r * 1.1)
                local tipY = cy + math.sin(theta) * (r * 1.1)

                local leftAngle = theta + 0.4
                local leftX = cx + math.cos(leftAngle) * (r * 0.35)
                local leftY = cy + math.sin(leftAngle) * (r * 0.35)

                local rightAngle = theta - 0.4
                local rightX = cx + math.cos(rightAngle) * (r * 0.35)
                local rightY = cy + math.sin(rightAngle) * (r * 0.35)

                love.graphics.setColor(0.9, 0.9, 0.95, 0.95)
                love.graphics.polygon("fill", cx, cy, leftX, leftY, tipX, tipY)

                love.graphics.setColor(0.5, 0.5, 0.55, 0.95)
                love.graphics.polygon("fill", cx, cy, rightX, rightY, tipX, tipY)

                love.graphics.setColor(0.2, 1.0, 0.4, 0.9)
                love.graphics.setLineWidth(1.5)
                love.graphics.line(leftX, leftY, tipX, tipY)
            end
            love.graphics.setColor(1.0, 1.0, 1.0)
            love.graphics.circle("fill", cx, cy, r * 0.15)

        elseif option.index == 4 then
            -- Bullet
            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.rotate(-math.pi / 4)

            -- 1. Speed tail/lines (drawn behind, extending to the left: negative x)
            -- Main center tail
            love.graphics.setLineWidth(r * 0.15)
            love.graphics.setColor(0.3, 0.5, 1.0, 0.3)
            love.graphics.line(-r * 0.2, 0, -r * 0.9, 0)
            love.graphics.setColor(0.5, 0.7, 1.0, 0.6)
            love.graphics.setLineWidth(r * 0.06)
            love.graphics.line(-r * 0.2, 0, -r * 0.85, 0)

            -- Upper & lower speed trails
            love.graphics.setLineWidth(r * 0.04)
            love.graphics.setColor(0.4, 0.6, 1.0, 0.4)
            love.graphics.line(-r * 0.1, -r * 0.15, -r * 0.7, -r * 0.15)
            love.graphics.line(-r * 0.1, r * 0.15, -r * 0.7, r * 0.15)

            -- 2. Bullet body (sleek capsule/pointed energy projectile)
            -- Outer glow
            love.graphics.setColor(0.3, 0.6, 1.0, 0.25)
            love.graphics.circle("fill", r * 0.15, 0, r * 0.25)
            love.graphics.rectangle("fill", -r * 0.35, -r * 0.25, r * 0.5, r * 0.5, r * 0.1, r * 0.1)

            -- Bullet metal casing / energy body
            love.graphics.setColor(0.5, 0.75, 1.0, 0.9)
            love.graphics.rectangle("fill", -r * 0.35, -r * 0.15, r * 0.5, r * 0.3, r * 0.08, r * 0.08)
            -- Bullet nose cone
            local nose = {
                r * 0.15, -r * 0.15,
                r * 0.45, 0,
                r * 0.15, r * 0.15
            }
            love.graphics.polygon("fill", nose)

            -- Inner hot core (bright white/cyan)
            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.rectangle("fill", -r * 0.2, -r * 0.06, r * 0.3, r * 0.12, r * 0.04, r * 0.04)
            local coreNose = {
                r * 0.1, -r * 0.06,
                r * 0.28, 0,
                r * 0.1, r * 0.06
            }
            love.graphics.polygon("fill", coreNose)

            love.graphics.pop()

        elseif option.index == 5 then
            -- Laser
            love.graphics.setColor(1.0, 0.1, 0.4, 0.25)
            love.graphics.setLineWidth(r * 0.5)
            love.graphics.line(cx - r, cy + r * 0.4, cx + r, cy - r * 0.4)

            love.graphics.setColor(1.0, 0.2, 0.2, 0.55)
            love.graphics.setLineWidth(r * 0.25)
            love.graphics.line(cx - r, cy + r * 0.4, cx + r, cy - r * 0.4)

            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.setLineWidth(r * 0.08)
            love.graphics.line(cx - r, cy + r * 0.4, cx + r, cy - r * 0.4)

            love.graphics.setColor(1.0, 0.8, 0.9, 0.8)
            love.graphics.circle("fill", cx - r, cy + r * 0.4, r * 0.2)
            love.graphics.circle("fill", cx + r, cy - r * 0.4, r * 0.2)

        elseif option.index == 6 then
            -- Magnetic Field
            love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
            love.graphics.circle("fill", cx, cy, 4)

            love.graphics.setColor(0.1, 0.6, 1.0, 0.1)
            love.graphics.circle("fill", cx, cy, r * 1.0)
            love.graphics.setColor(0.2, 0.7, 1.0, 0.2)
            love.graphics.circle("fill", cx, cy, r * 0.75)

            love.graphics.setLineWidth(2)
            love.graphics.setColor(0.3, 0.8, 1.0, 0.7)
            love.graphics.circle("line", cx, cy, r * 1.0)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", cx, cy, r * 0.85)

            local numSparks = 6
            local rotAngle = time * 3
            for k = 1, numSparks do
                local angle = rotAngle + (k - 1) * (2 * math.pi / numSparks)
                local sx = cx + math.cos(angle) * r
                local sy = cy + math.sin(angle) * r
                love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
                love.graphics.circle("fill", sx, sy, 2)
            end

        elseif option.index == 7 then
            -- Meteor
            love.graphics.setColor(1.0, 0.15, 0.15, 0.4)
            love.graphics.setLineWidth(1.5)
            love.graphics.circle("line", cx + r * 0.2, cy + r * 0.3, r * 0.65)
            love.graphics.circle("fill", cx + r * 0.2, cy + r * 0.3, 2.5)

            local mx = cx - r * 0.2
            local my = cy - r * 0.3
            love.graphics.setColor(1.0, 0.35, 0.0, 0.3)
            love.graphics.circle("fill", mx - r * 0.3, my - r * 0.3, r * 0.45)
            love.graphics.circle("fill", mx - r * 0.15, my - r * 0.15, r * 0.5)

            love.graphics.setColor(1.0, 0.45, 0.05, 0.85)
            love.graphics.circle("fill", mx, my, r * 0.4)
            love.graphics.setColor(1.0, 0.95, 0.2, 0.95)
            love.graphics.circle("fill", mx, my, r * 0.2)

        elseif option.index == 8 then
            -- Cutter (Center-anchored curved blade that rotates)
            local angle = time * 3
            local drawPoints = {}
            local segments = 16
            local length = r * 0.95
            local cutterCurvature = 0.7
            for s = 0, segments do
                local t = s / segments
                local currAngle = angle - cutterCurvature * t
                local cx_point = cx + math.cos(currAngle) * (length * t)
                local cy_point = cy + math.sin(currAngle) * (length * t)
                table.insert(drawPoints, cx_point)
                table.insert(drawPoints, cy_point)
            end

            -- Layer 1: Ambient steel slash reflection
            love.graphics.setColor(0.85, 0.85, 0.9, 0.1)
            love.graphics.setLineWidth(r * 0.5)
            love.graphics.line(drawPoints)

            -- Layer 2: Dark steel blade backbone
            love.graphics.setColor(0.12, 0.12, 0.15, 0.65)
            love.graphics.setLineWidth(r * 0.25)
            love.graphics.line(drawPoints)

            -- Layer 3: Silver blade body
            love.graphics.setColor(0.65, 0.65, 0.7, 0.8)
            love.graphics.setLineWidth(r * 0.16)
            love.graphics.line(drawPoints)

            -- Layer 4: White razor edge
            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.setLineWidth(r * 0.06)
            love.graphics.line(drawPoints)

            -- Tip coordinates and angle calculation
            local tx = drawPoints[#drawPoints - 1]
            local ty = drawPoints[#drawPoints]
            local ptx = drawPoints[#drawPoints - 3]
            local pty = drawPoints[#drawPoints - 2]
            local tangentAngle = math.atan2(ty - pty, tx - ptx)

            love.graphics.push()
            love.graphics.translate(tx, ty)
            love.graphics.rotate(tangentAngle)

            -- Scaled diamond tip
            local ts = r * 0.4
            love.graphics.setColor(0.2, 0.2, 0.22, 0.9)
            love.graphics.polygon("fill", 0, 0, -ts * 0.6, -ts * 0.35, -ts, 0, -ts * 0.6, ts * 0.35)
            love.graphics.setColor(0.9, 0.9, 0.95, 0.95)
            love.graphics.polygon("line", 0, 0, -ts * 0.6, -ts * 0.35, -ts, 0, -ts * 0.6, ts * 0.35)
            love.graphics.pop()

            -- Center spark core
            love.graphics.setColor(0.7, 0.7, 0.75, 0.4)
            love.graphics.circle("fill", cx, cy, r * 0.3 + math.sin(time * 15) * (r * 0.05))

        elseif option.index == 9 then
            -- Chain
            love.graphics.setColor(0.1, 0.8, 1.0, 0.25)
            love.graphics.setLineWidth(8)
            love.graphics.line(cx - r * 0.8, cy + r * 0.8, cx + r * 0.8, cy - r * 0.8)

            local dx = r * 1.6
            local dy = -r * 1.6
            local dist = math.sqrt(dx*dx + dy*dy)
            local ux, uy = dx/dist, dy/dist
            local linkSpacing = r * 0.48
            local numLinks = 4
            love.graphics.setLineWidth(1.5)
            local angle = math.atan2(dy, dx)

            for k = 0, numLinks - 1 do
                local t = k * linkSpacing - r * 0.72
                local lx = cx + ux * t
                local ly = cy + uy * t

                love.graphics.push()
                love.graphics.translate(lx, ly)
                love.graphics.rotate(angle + (k % 2 == 0 and 0 or math.pi / 2))

                love.graphics.setColor(0.4, 0.85, 1.0, 0.85)
                love.graphics.ellipse("line", 0, 0, 6, 3)
                love.graphics.setColor(0.1, 0.1, 0.15, 0.5)
                love.graphics.ellipse("fill", 0, 0, 4, 1.5)

                love.graphics.pop()
            end

        elseif option.index == 10 then
            -- Seeker Orb
            local pulse = 1.0 + math.sin(time * 10) * 0.1
            love.graphics.setColor(0.7, 0.1, 0.9, 0.12)
            love.graphics.circle("fill", cx, cy, r * 1.25 * pulse)
            love.graphics.setColor(0.9, 0.1, 0.7, 0.3)
            love.graphics.circle("fill", cx, cy, r * 0.75 * pulse)

            love.graphics.setLineWidth(1.2)
            love.graphics.setColor(1.0, 0.3, 0.8, 0.4)
            love.graphics.circle("line", cx, cy, r * 0.95)

            love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
            love.graphics.circle("fill", cx, cy, r * 0.32)
        end

    elseif option.type == "upgrade" then
        if option.index == 1 then
            -- Magnet (U-shaped horseshoe magnet with field lines and N/S labels)
            local lw = r * 0.22

            -- Faint magnetic field lines arching between the poles
            love.graphics.setLineWidth(1.5)
            for i = 1, 3 do
                local f_rad = r * (0.2 + i * 0.15)
                love.graphics.setColor(0.3, 0.8, 1.0, 0.3 * (1 - i * 0.25) * (0.7 + 0.3 * math.sin(time * 8)))
                love.graphics.arc("line", "open", cx, cy - r * 0.3, f_rad, -math.pi, 0, 20)
            end

            -- Left leg: Red (North)
            love.graphics.setLineWidth(lw)
            love.graphics.setColor(0.8, 0.2, 0.2)
            love.graphics.line(cx - r * 0.38, cy + r * 0.1, cx - r * 0.38, cy - r * 0.3)
            love.graphics.arc("line", "open", cx, cy + r * 0.1, r * 0.38, math.pi / 2, math.pi, 20)

            -- Right leg: Blue (South)
            love.graphics.setColor(0.2, 0.4, 0.8)
            love.graphics.line(cx + r * 0.38, cy + r * 0.1, cx + r * 0.38, cy - r * 0.3)
            love.graphics.arc("line", "open", cx, cy + r * 0.1, r * 0.38, 0, math.pi / 2, 20)

            -- Silver tips at the poles
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.rectangle("fill", cx - r * 0.38 - lw / 2, cy - r * 0.32, lw, lw * 0.5)
            love.graphics.rectangle("fill", cx + r * 0.38 - lw / 2, cy - r * 0.32, lw, lw * 0.5)

            -- N and S letter drawings on the legs
            love.graphics.setLineWidth(1.5)
            love.graphics.setColor(1, 1, 1, 0.9)

            -- Left leg: N
            local nx, ny = cx - r * 0.38, cy - r * 0.05
            local nw, nh = r * 0.08, r * 0.14
            love.graphics.line(nx - nw, ny + nh, nx - nw, ny - nh)
            love.graphics.line(nx - nw, ny - nh, nx + nw, ny + nh)
            love.graphics.line(nx + nw, ny + nh, nx + nw, ny - nh)

            -- Right leg: S
            local sx, sy = cx + r * 0.38, cy - r * 0.05
            local sw, sh = r * 0.08, r * 0.14
            love.graphics.line(
                sx + sw, sy - sh,
                sx - sw, sy - sh,
                sx - sw, sy,
                sx + sw, sy,
                sx + sw, sy + sh,
                sx - sw, sy + sh
            )

        elseif option.index == 2 then
            -- Health Boost (Heart)
            love.graphics.setColor(0.95, 0.15, 0.15, 0.9)
            local points = {}
            local numPoints = 24
            local hScale = r * 0.05
            for step = 0, numPoints - 1 do
                local theta = step * (2 * math.pi / numPoints)
                local x = 16 * math.sin(theta)^3
                local y = -(13 * math.cos(theta) - 5 * math.cos(2 * theta) - 2 * math.cos(3 * theta) - math.cos(4 * theta))
                table.insert(points, cx + x * hScale)
                table.insert(points, cy + y * hScale)
            end
            love.graphics.polygon("fill", points)

            love.graphics.setColor(1.0, 1.0, 1.0, 0.35)
            love.graphics.circle("fill", cx - r * 0.2, cy - r * 0.2, r * 0.12)

        elseif option.index == 3 then
            -- Speed Boost (Arrows / Wings)
            love.graphics.setLineWidth(4)
            love.graphics.setColor(0.3, 0.8, 1.0)
            for offset = -14, 14, 14 do
                love.graphics.line(cx + offset - 6, cy - r * 0.35, cx + offset + 6, cy, cx + offset - 6, cy + r * 0.35)
            end
            love.graphics.setLineWidth(2)
            love.graphics.setColor(1.0, 1.0, 1.0, 0.65)
            love.graphics.line(cx - r * 0.5, cy - r * 0.1, cx + r * 0.5, cy - r * 0.1)
            love.graphics.line(cx - r * 0.3, cy + r * 0.2, cx + r * 0.3, cy + r * 0.2)

        elseif option.index == 4 then
            -- Damage Boost (Sword)
            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.rotate(math.pi / 4)

            love.graphics.setColor(0.85, 0.85, 0.9)
            love.graphics.polygon("fill", -3, -r * 0.8, 3, -r * 0.8, 4, r * 0.2, -4, r * 0.2)
            love.graphics.setColor(1.0, 1.0, 1.0)
            love.graphics.line(0, -r * 0.8, 0, r * 0.2)

            love.graphics.setColor(1.0, 0.75, 0.1)
            love.graphics.rectangle("fill", -9, r * 0.2, 18, 4, 1, 1)

            love.graphics.setColor(0.5, 0.35, 0.15)
            love.graphics.rectangle("fill", -2, r * 0.2 + 4, 4, r * 0.35)

            love.graphics.setColor(1.0, 0.75, 0.1)
            love.graphics.circle("fill", 0, r * 0.2 + 4 + r * 0.35, 3)

            love.graphics.pop()

        elseif option.index == 5 then
            -- Health Regen (Green Heart with +)
            love.graphics.setColor(0.15, 0.85, 0.15, 0.9)
            local points = {}
            local numPoints = 24
            local hScale = r * 0.05
            for step = 0, numPoints - 1 do
                local theta = step * (2 * math.pi / numPoints)
                local x = 16 * math.sin(theta)^3
                local y = -(13 * math.cos(theta) - 5 * math.cos(2 * theta) - 2 * math.cos(3 * theta) - math.cos(4 * theta))
                table.insert(points, cx + x * hScale)
                table.insert(points, cy + y * hScale)
            end
            love.graphics.polygon("fill", points)

            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.setLineWidth(3)
            love.graphics.line(cx - r * 0.18, cy, cx + r * 0.18, cy)
            love.graphics.line(cx, cy - r * 0.18, cx, cy + r * 0.18)

        elseif option.index == 6 then
            -- EXP Boost (Star)
            love.graphics.setColor(1.0, 0.85, 0.15, 0.9)
            local points = {}
            local outerR = r * 0.95
            local innerR = r * 0.36
            for k = 0, 9 do
                local angle = -math.pi / 2 + k * (2 * math.pi / 10)
                local rad = (k % 2 == 0) and outerR or innerR
                table.insert(points, cx + math.cos(angle) * rad)
                table.insert(points, cy + math.sin(angle) * rad)
            end
            love.graphics.polygon("fill", points)

            love.graphics.setColor(1.0, 1.0, 1.0, 0.6)
            love.graphics.circle("fill", cx - r * 0.85, cy - r * 0.85, 2)
            love.graphics.circle("fill", cx + r * 0.85, cy + r * 0.75, 2.5)

        elseif option.index == 7 then
            -- Thorns (Spike ball)
            love.graphics.setColor(0.0, 1.0, 0.6, 0.25)
            love.graphics.circle("fill", cx, cy, r * 0.5)

            love.graphics.setColor(0.3, 1.0, 0.8)
            love.graphics.setLineWidth(1.5)
            love.graphics.circle("line", cx, cy, r * 0.5)

            local numSpikes = 10
            for s = 1, numSpikes do
                local angle = (s - 1) * (2 * math.pi / numSpikes) + time
                local ex = cx + math.cos(angle) * r * 0.95
                local ey = cy + math.sin(angle) * r * 0.95

                local angleLeft = angle + 0.15
                local angleRight = angle - 0.15
                local lx = cx + math.cos(angleLeft) * r * 0.48
                local ly = cy + math.sin(angleLeft) * r * 0.48
                local rx = cx + math.cos(angleRight) * r * 0.48
                local ry = cy + math.sin(angleRight) * r * 0.48

                love.graphics.setColor(0.0, 1.0, 0.6, 0.4)
                love.graphics.polygon("fill", lx, ly, rx, ry, ex, ey)
                love.graphics.setColor(0.3, 1.0, 0.8)
                love.graphics.polygon("line", lx, ly, rx, ry, ex, ey)
            end

        elseif option.index == 8 then
            -- Energy Shield
            love.graphics.setColor(0.3, 0.6, 1.0, 0.22)
            love.graphics.circle("fill", cx, cy, r * 1.0)
            love.graphics.setLineWidth(1.5)
            love.graphics.setColor(0.5, 0.8, 1.0, 0.75)
            love.graphics.circle("line", cx, cy, r * 1.0)

            love.graphics.setColor(0.4, 0.6, 0.9, 0.9)
            local shW = r * 0.45
            local shH = r * 0.5
            local shPoints = {
                cx - shW, cy - shH,
                cx + shW, cy - shH,
                cx + shW, cy,
                cx, cy + shH,
                cx - shW, cy
            }
            love.graphics.polygon("fill", shPoints)
            love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
            love.graphics.setLineWidth(1.5)
            love.graphics.polygon("line", shPoints)

        elseif option.index == 9 then
            -- Defense Boost (Heavy Shield)
            local shW = r * 0.5
            local shH = r * 0.6
            local shPoints = {
                cx - shW, cy - shH,
                cx + shW, cy - shH,
                cx + shW, cy * 0.95 + shH * 0.1,
                cx, cy + shH,
                cx - shW, cy * 0.95 + shH * 0.1
            }

            love.graphics.setColor(0.3, 0.35, 0.4, 0.9)
            love.graphics.polygon("fill", shPoints)

            love.graphics.setColor(0.5, 0.55, 0.6, 0.9)
            love.graphics.polygon("fill", cx - shW, cy - shH, cx, cy - shH, cx, cy + shH, cx - shW, cy * 0.95 + shH * 0.1)

            love.graphics.setColor(1.0, 0.8, 0.2)
            love.graphics.setLineWidth(2.5)
            love.graphics.polygon("line", shPoints)

            love.graphics.setColor(1.0, 0.8, 0.2)
            love.graphics.polygon("fill", cx, cy - 8, cx + 5, cy, cx, cy + 8, cx - 5, cy)
        end
    end

    love.graphics.pop()
end

-- 스킬 선택 박스 레이아웃 계산 (3등분)
function HUD.calculateSkillBoxes(game)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local boxWidth = screenWidth / 3
    local boxHeight = screenHeight

    game.skillBoxes = {}
    for i = 1, 3 do
        game.skillBoxes[i] = {
            x = (i - 1) * boxWidth,
            y = 0,
            width = boxWidth,
            height = boxHeight
        }
    end
end

-- 랜덤 3개 스킬/특성 선택 및 셔플 (MAX 레벨 스킬은 시작 선택지에서 제외)
function HUD.shuffleSkills(game)
    game.skillOptions = {}

    -- 1. 모든 액티브 스킬 만렙 여부 검사
    local allSkillsMax = true
    local skillPool = {}
    for i = 1, #game.skills do
        local lv = 0
        if game.metaUpgrades and game.metaUpgrades.skills then
            lv = game.metaUpgrades.skills[i] or 0
        end
        if lv < 5 then
            allSkillsMax = false
            table.insert(skillPool, i)
        end
    end

    if not allSkillsMax then
        -- 아직 만렙이 아닌 액티브 스킬이 있는 경우 -> 액티브 스킬들 중에서만 셔플하여 출력
        -- Fisher-Yates shuffle
        for i = #skillPool, 2, -1 do
            local j = math.random(i)
            skillPool[i], skillPool[j] = skillPool[j], skillPool[i]
        end
        for i = 1, math.min(3, #skillPool) do
            table.insert(game.skillOptions, { type = "skill", index = skillPool[i] })
        end
        return
    end

    -- 2. 모든 액티브 스킬이 만렙인 경우 -> 패시브(업그레이드) 검사
    -- 제한이 있는 패시브: 1(Magnet, max 3), 3(Speed Boost, max 3), 5(Health Regen, max 3), 6(EXP Boost, max 3), 7(Thorns, max 3), 8(Energy Shield, max 3)
    -- 제한이 없는 패시브: 2(Health Boost), 4(Damage Boost), 9(Defense Boost)
    local limitedIndices = { 1, 3, 5, 6, 7, 8 }

    local allLimitedPassivesMax = true
    local limitedPassivePool = {}
    for _, idx in ipairs(limitedIndices) do
        local lv = 0
        if game.metaUpgrades and game.metaUpgrades.upgrades then
            lv = game.metaUpgrades.upgrades[idx] or 0
        end
        if lv < 3 then
            allLimitedPassivesMax = false
            table.insert(limitedPassivePool, idx)
        end
    end

    if not allLimitedPassivesMax then
        -- 제한 있는 패시브 중 만렙이 아닌 것이 있을 때 -> 셔플하여 출력
        for i = #limitedPassivePool, 2, -1 do
            local j = math.random(i)
            limitedPassivePool[i], limitedPassivePool[j] = limitedPassivePool[j], limitedPassivePool[i]
        end

        -- 최대 3개를 선택하되, 부족하면 제한 없는 패시브로 채움
        local selected = {}
        for i = 1, math.min(3, #limitedPassivePool) do
            table.insert(selected, limitedPassivePool[i])
        end

        if #selected < 3 then
            -- 무한 패시브 셔플 후 빈자리 채우기
            local tempUnlimited = { 2, 4, 9 }
            for i = #tempUnlimited, 2, -1 do
                local j = math.random(i)
                tempUnlimited[i], tempUnlimited[j] = tempUnlimited[j], tempUnlimited[i]
            end
            for _, idx in ipairs(tempUnlimited) do
                if #selected >= 3 then break end
                table.insert(selected, idx)
            end
        end

        for _, idx in ipairs(selected) do
            table.insert(game.skillOptions, { type = "upgrade", index = idx })
        end
    else
        -- 모든 스킬과 제한 있는 패시브가 전부 만렙인 경우 -> 무한 특성(HP, Damage, Defense)만 등장
        -- 무작위 순서로 3개 배치
        local unlimitedPool = { 2, 4, 9 }
        for i = #unlimitedPool, 2, -1 do
            local j = math.random(i)
            unlimitedPool[i], unlimitedPool[j] = unlimitedPool[j], unlimitedPool[i]
        end
        for i = 1, 3 do
            table.insert(game.skillOptions, { type = "upgrade", index = unlimitedPool[i] })
        end
    end
end

-- 특성 선택 박스 레이아웃 계산 (3등분)
function HUD.calculateUpgradeBoxes(game)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local boxWidth = screenWidth / 3
    local boxHeight = screenHeight

    game.upgradeBoxes = {}
    for i = 1, 3 do
        game.upgradeBoxes[i] = {
            x = (i - 1) * boxWidth,
            y = 0,
            width = boxWidth,
            height = boxHeight
        }
    end
end

-- 시작 스킬 선택 메뉴 렌더링
function HUD.drawMenu(game)
    love.graphics.clear(0.1, 0.1, 0.1)

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- Draw skill/upgrade selection boxes
    for i, box in ipairs(game.skillBoxes) do
        local option = game.skillOptions[i]
        if option then
            -- Box background and hover effect
            local mouseX, mouseY = love.mouse.getPosition()
            local isHovered = mouseX >= box.x and mouseX <= box.x + box.width and
                mouseY >= box.y and mouseY <= box.y + box.height

            if option.type == "skill" then
                if isHovered then
                    love.graphics.setColor(0.4, 0.4, 0.6)
                else
                    love.graphics.setColor(0.3, 0.3, 0.5)
                end
            else
                if isHovered then
                    love.graphics.setColor(0.4, 0.6, 0.4)
                else
                    love.graphics.setColor(0.3, 0.5, 0.3)
                end
            end
            love.graphics.rectangle("fill", box.x, box.y, box.width, box.height)

            -- Box borders
            if option.type == "skill" then
                love.graphics.setColor(0.6, 0.6, 0.8)
            else
                love.graphics.setColor(0.6, 0.8, 0.6)
            end
            love.graphics.rectangle("line", box.x, box.y, box.width, box.height)

            -- Name & Description fetching
            local nameText, descText
            if option.type == "skill" then
                local skill = game.skills[option.index]
                nameText = skill.name
                descText = skill.description
            else
                local upgrade = game.upgrades[option.index]
                nameText = upgrade.name
                descText = upgrade.description
            end

            -- Draw icon/symbol
            local iconCx = box.x + box.width / 2
            local iconCy = box.y + box.height * 0.30
            local iconSize = 80
            HUD.drawCardIcon(option, iconCx, iconCy, iconSize)

            -- Title Name
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(28))
            love.graphics.printf(nameText, box.x, box.y + box.height * 0.44, box.width, "center")

            -- Description (wrapped with font size 13 to avoid overflow)
            love.graphics.setFont(getFont(13))
            love.graphics.printf(descText, box.x + 20, box.y + box.height * 0.54, box.width - 40, "center")
        end
    end

    -- Main title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(48))
    love.graphics.printf("Roguelike Survivor", 0, 50, screenWidth, "center")

    -- Footer guidance
    local footerText = "Select a starting skill"
    if game.skillOptions and game.skillOptions[1] and game.skillOptions[1].type == "upgrade" then
        footerText = "Select a starting upgrade"
    end
    love.graphics.setFont(getFont(24))
    love.graphics.printf(footerText, 0, screenHeight - 50, screenWidth, "center")
end

-- 특성 및 스킬 선택(업그레이드) 화면 렌더링
function HUD.drawUpgrade(game)
    love.graphics.clear(0.1, 0.1, 0.1)

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- 3분할된 레이아웃 박스 렌더링
    for i, box in ipairs(game.upgradeBoxes) do
        local option = game.upgradeOptions[i]
        if option then
            -- 박스 배경 및 마우스 호버 효과
            local mouseX, mouseY = love.mouse.getPosition()
            local isHovered = mouseX >= box.x and mouseX <= box.x + box.width and
                mouseY >= box.y and mouseY <= box.y + box.height

            if option.type == "skill" then
                -- Skill card styling
                if isHovered then
                    love.graphics.setColor(0.4, 0.4, 0.6)
                else
                    love.graphics.setColor(0.3, 0.3, 0.5)
                end
            else
                -- Trait card styling
                if isHovered then
                    love.graphics.setColor(0.4, 0.6, 0.4)
                else
                    love.graphics.setColor(0.3, 0.5, 0.3)
                end
            end
            love.graphics.rectangle("fill", box.x, box.y, box.width, box.height)

            -- Draw card borders
            if option.type == "skill" then
                love.graphics.setColor(0.6, 0.6, 0.8)
            else
                love.graphics.setColor(0.6, 0.8, 0.6)
            end
            love.graphics.rectangle("line", box.x, box.y, box.width, box.height)

            -- Prepare text rendering
            love.graphics.setColor(1, 1, 1)
            local nameText, descText = "", ""
            local levelText = ""

            if option.type == "skill" then
                local skill = game.skills[option.index]
                nameText = skill.name

                local currentLevel = game.player.skillLevels[option.index] or 0
                if currentLevel == 0 then
                    levelText = "NEW SKILL"
                else
                    levelText = "Level: " .. currentLevel .. " -> " .. (currentLevel + 1)
                end

                local nextLevel = currentLevel + 1
                local descList = skillLevelDescriptions[option.index]
                if descList and descList[nextLevel] then
                    descText = descList[nextLevel]
                else
                    descText = skill.description
                end
            else
                local upgrade = game.upgrades[option.index]
                nameText = upgrade.name

                local currentLevel = game.player.upgradeLevels[option.index] or 0
                local nextLevel = currentLevel + 1
                local descList = upgradeLevelDescriptions[option.index]
                if descList and descList[nextLevel] then
                    descText = descList[nextLevel]
                else
                    descText = upgrade.description
                end
            end

            -- Draw icon/symbol
            local iconCx = box.x + box.width / 2
            local iconCy = box.y + box.height * 0.30
            local iconSize = 80
            HUD.drawCardIcon(option, iconCx, iconCy, iconSize)

            -- Draw card name
            love.graphics.setFont(getFont(28))
            love.graphics.printf(nameText, box.x, box.y + box.height * 0.44, box.width, "center")

            -- Draw card description (wrapped, font size 13 to prevent box overflow)
            love.graphics.setFont(getFont(13))
            love.graphics.printf(descText, box.x + 20, box.y + box.height * 0.54, box.width - 40, "center")

            -- Draw card footer info
            if option.type == "skill" then
                -- Skills: Render level text
                love.graphics.setColor(0.9, 0.9, 0.9)
                love.graphics.setFont(getFont(16))
                love.graphics.printf(levelText, box.x, box.y + box.height * 0.76, box.width, "center")
            else
                -- Traits: Renders level diamonds or level text if infinite
                local player = game.player
                if player then
                    local upgradeLevel = player.upgradeLevels[option.index] or 0
                    local isInfinite = (option.index == 2 or option.index == 4 or option.index == 9)

                    if isInfinite then
                        local levelText = "Level: " .. upgradeLevel .. " -> " .. (upgradeLevel + 1)
                        love.graphics.setColor(0.9, 0.9, 0.9)
                        love.graphics.setFont(getFont(16))
                        love.graphics.printf(levelText, box.x, box.y + box.height * 0.76, box.width, "center")
                    else
                        local starSize = 15
                        local starSpacing = 18
                        local totalWidth = 2 * starSpacing + starSize
                        local startX = box.x + (box.width - totalWidth) / 2
                        local starY = box.y + box.height * 0.76

                        for j = 1, 3 do
                            local x = startX + (j - 1) * starSpacing
                            if j <= upgradeLevel then
                                love.graphics.setColor(1.0, 0.8, 0.0) -- Gold
                            else
                                love.graphics.setColor(0.5, 0.5, 0.5) -- Grey
                            end

                            love.graphics.polygon("fill",
                                x, starY - starSize / 2,
                                x + starSize / 2, starY,
                                x, starY + starSize / 2,
                                x - starSize / 2, starY
                            )
                        end
                    end
                end
            end
        end
    end

    -- 상단 제목
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(48))
    love.graphics.printf("Level Up!", 0, 50, screenWidth, "center")

    -- 하단 선택 가이드라인
    love.graphics.setFont(getFont(24))
    love.graphics.printf("Select a skill or upgrade", 0, screenHeight - 50, screenWidth, "center")
end

-- 게임오버 화면 렌더링
function HUD.drawGameOver(game)
    love.graphics.clear(0.05, 0.05, 0.07) -- Deep space dark color

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mx, my = love.mouse.getPosition()

    -- Game Over 제목 (부드러운 적색 네온 발광)
    local titleGlow = 0.85 + math.sin(love.timer.getTime() * 4) * 0.1
    love.graphics.setColor(1.0, 0.2, 0.2, titleGlow)
    love.graphics.setFont(getFont(54))
    love.graphics.printf("GAME OVER", 0, screenHeight / 3 - 40, screenWidth, "center")

    -- 최종 점수
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(24))
    love.graphics.printf("Score: " .. game.score, 0, screenHeight / 2 - 30, screenWidth, "center")

    -- 버튼 위치 설정
    local btnY = screenHeight / 2 + 50
    local btnHeight = 50
    local btn1Width = 240
    local btn1X = screenWidth / 2 - 250
    local btn2Width = 240
    local btn2X = screenWidth / 2 + 10

    game.gameOverButtons = {
        { x = btn1X, y = btnY, w = btn1Width, h = btnHeight, action = "menu" },
        { x = btn2X, y = btnY, w = btn2Width, h = btnHeight, action = "exit" }
    }

    -- 1. 시작화면으로 (MAIN MENU) 버튼 그리기
    local isHovered1 = mx >= btn1X and mx <= btn1X + btn1Width and my >= btnY and my <= btnY + btnHeight
    if isHovered1 then
        love.graphics.setColor(0.12, 0.25, 0.45, 0.95)
    else
        love.graphics.setColor(0.08, 0.15, 0.25, 0.85)
    end
    love.graphics.rectangle("fill", btn1X, btnY, btn1Width, btnHeight, 6, 6)

    if isHovered1 then
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.3, 0.7, 1.0, 0.95)
    else
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.2, 0.4, 0.6, 0.7)
    end
    love.graphics.rectangle("line", btn1X, btnY, btn1Width, btnHeight, 6, 6)

    love.graphics.setFont(getFont(18))
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("MAIN MENU", btn1X, btnY + 14, btn1Width, "center")

    -- 2. 게임종료 (EXIT GAME) 버튼 그리기
    local isHovered2 = mx >= btn2X and mx <= btn2X + btn2Width and my >= btnY and my <= btnY + btnHeight
    if isHovered2 then
        love.graphics.setColor(0.35, 0.12, 0.12, 0.95)
    else
        love.graphics.setColor(0.2, 0.08, 0.08, 0.85)
    end
    love.graphics.rectangle("fill", btn2X, btnY, btn2Width, btnHeight, 6, 6)

    if isHovered2 then
        love.graphics.setLineWidth(2)
        love.graphics.setColor(1.0, 0.3, 0.3, 0.95)
    else
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.6, 0.2, 0.2, 0.7)
    end
    love.graphics.rectangle("line", btn2X, btnY, btn2Width, btnHeight, 6, 6)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("EXIT GAME", btn2X, btnY + 14, btn2Width, "center")

    love.graphics.setLineWidth(1)
end

-- 스테이지 클리어 또는 게임 승리 화면 렌더링
function HUD.drawStageClear(game)
    -- 반투명 어두운 배경으로 덮기 (인게임 상태가 살짝 비치도록 함)
    love.graphics.setColor(0.04, 0.04, 0.06, 0.85)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    if game.stage == 9 then
        -- VICTORY: SYSTEM RESTORED!
        local goldPulse = 0.8 + 0.2 * math.sin(love.timer.getTime() * 4)
        love.graphics.setColor(1.0, 0.8, 0.2, goldPulse)
        love.graphics.setFont(getFont(44))
        love.graphics.printf("VICTORY: SYSTEM RESTORED!", 0, screenHeight / 3 - 60, screenWidth, "center")

        love.graphics.setColor(0.9, 0.9, 1.0)
        love.graphics.setFont(getFont(20))
        love.graphics.printf("You have defeated the Nebula Seraph and saved the system core!", 0, screenHeight / 3 + 10,
            screenWidth, "center")
    else
        -- STAGE CLEARED 제목 (그린 네온 느낌)
        love.graphics.setColor(0.2, 0.9, 0.4)
        love.graphics.setFont(getFont(48))
        love.graphics.printf("STAGE " .. (game.stage or 1) .. " CLEARED!", 0, screenHeight / 3 - 50, screenWidth,
            "center")
    end

    -- 스코어 표시
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(24))
    love.graphics.printf("Score: " .. game.score, 0, screenHeight / 3 + 60, screenWidth, "center")

    -- Next Stage / Back to Main Menu 버튼 그리기 (네온 스타일 및 마우스 호버 효과)
    local mouseX, mouseY = love.mouse.getPosition()

    if game.stage == 9 and not game.endlessMode then
        local centerX = screenWidth / 2
        local btn1Width = 260
        local btn1Height = 60
        local btn1X = centerX - 275
        local btnY = screenHeight / 2 + 50

        local btn2Width = 260
        local btn2Height = 60
        local btn2X = centerX + 15

        local isHovered1 = mouseX >= btn1X and mouseX <= btn1X + btn1Width and
            mouseY >= btnY and mouseY <= btnY + btn1Height
        local isHovered2 = mouseX >= btn2X and mouseX <= btn2X + btn2Width and
            mouseY >= btnY and mouseY <= btnY + btn2Height

        -- Button 1: Start Endless Mode
        if isHovered1 then
            love.graphics.setColor(0.12, 0.55, 0.3, 0.95) -- 녹색 호버
        else
            love.graphics.setColor(0.08, 0.4, 0.2, 0.85)  -- 녹색 기본
        end
        love.graphics.rectangle("fill", btn1X, btnY, btn1Width, btn1Height, 8, 8)
        love.graphics.setColor(0.4, 1.0, 0.6, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", btn1X, btnY, btn1Width, btn1Height, 8, 8)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(20))
        love.graphics.printf("Start Endless Mode", btn1X, btnY + 18, btn1Width, "center")

        -- Button 2: Back to Main Menu
        if isHovered2 then
            love.graphics.setColor(0.12, 0.3, 0.55, 0.95) -- 파란색 호버
        else
            love.graphics.setColor(0.08, 0.2, 0.4, 0.85)  -- 파란색 기본
        end
        love.graphics.rectangle("fill", btn2X, btnY, btn2Width, btn2Height, 8, 8)
        love.graphics.setColor(0.4, 0.75, 1.0, 0.9)
        love.graphics.rectangle("line", btn2X, btnY, btn2Width, btn2Height, 8, 8)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(20))
        love.graphics.printf("Back to Main Menu", btn2X, btnY + 18, btn2Width, "center")
    else
        local btnWidth = 280
        local btnHeight = 60
        local btnX = (screenWidth - btnWidth) / 2
        local btnY = screenHeight / 2 + 50

        local isHovered = mouseX >= btnX and mouseX <= btnX + btnWidth and
            mouseY >= btnY and mouseY <= btnY + btnHeight

        if game.stage == 9 then
            if isHovered then
                love.graphics.setColor(0.12, 0.3, 0.55, 0.95) -- 파란색 호버
            else
                love.graphics.setColor(0.08, 0.2, 0.4, 0.85)  -- 파란색 기본
            end
        else
            if isHovered then
                love.graphics.setColor(0.3, 0.8, 0.5, 0.95) -- 밝은 녹색 호버
            else
                love.graphics.setColor(0.2, 0.6, 0.3, 0.85) -- 녹색 기본
            end
        end
        love.graphics.rectangle("fill", btnX, btnY, btnWidth, btnHeight, 8, 8)

        if game.stage == 9 then
            love.graphics.setColor(0.4, 0.75, 1.0, 0.9)
        else
            love.graphics.setColor(0.6, 1.0, 0.7, 0.9)
        end
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", btnX, btnY, btnWidth, btnHeight, 8, 8)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(22))
        if game.stage == 9 then
            love.graphics.printf("Back to Main Menu", btnX, btnY + 16, btnWidth, "center")
        else
            love.graphics.printf("Next Stage", btnX, btnY + 16, btnWidth, "center")
        end
    end
end

-- 인게임 좌상단 기본 HUD 스탯 표시
function HUD.drawUI(game)
    local player = game.player

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(14)) -- 기본 폰트 크기 재지정 (폰트 오버라이드 방지)

    love.graphics.print("Score: " .. game.score, 10, 10)

    if player then
        love.graphics.print("Level: " .. player.level, 10, 30)
    end

    love.graphics.print("Time: " .. string.format("%.1f", game.time), 10, 50)
    love.graphics.print("Wave: " .. (game.wave or 1), 10, 70)
    if game.endlessMode then
        love.graphics.print("Stage: Endless", 10, 90)
    else
        love.graphics.print("Stage: " .. (game.stage or 1), 10, 90)
    end
    if game.enemies then
        love.graphics.print("Enemies: " .. #game.enemies, 10, 110)
    end

    -- Draw wave banner
    if game.bannerText and game.bannerTimer and game.bannerTimer > 0 then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()

        local alpha = 1.0
        if game.bannerTimer < 0.5 then
            alpha = game.bannerTimer / 0.5
        end

        -- Dark background band
        love.graphics.setColor(0.04, 0.05, 0.08, alpha * 0.75)
        love.graphics.rectangle("fill", 0, screenHeight / 2 - 60, screenWidth, 120)

        -- Border lines on the band (top/bottom)
        love.graphics.setColor(0.2, 0.4, 0.8, alpha * 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.line(0, screenHeight / 2 - 60, screenWidth, screenHeight / 2 - 60)
        love.graphics.line(0, screenHeight / 2 + 60, screenWidth, screenHeight / 2 + 60)

        -- Font configuration
        love.graphics.setFont(getFont(40))

        -- Drop shadow
        love.graphics.setColor(0, 0, 0, alpha * 0.8)
        love.graphics.printf(game.bannerText, 2, screenHeight / 2 - 23, screenWidth, "center")

        -- Main text color
        if string.find(game.bannerText, "CLEAR") then
            love.graphics.setColor(0.2, 0.9, 0.4, alpha)  -- Vibrant green
        else
            love.graphics.setColor(1.0, 0.75, 0.1, alpha) -- Golden
        end
        love.graphics.printf(game.bannerText, 0, screenHeight / 2 - 25, screenWidth, "center")
    end

    -- 보스 HP바 그리기 (보스가 존재하는 경우)
    local bosses = {}
    if game.enemies then
        for _, enemy in ipairs(game.enemies) do
            if enemy.type == "boss" then
                table.insert(bosses, enemy)
            end
        end
    end

    if #bosses > 0 then
        local screenWidth = love.graphics.getWidth()
        local barWidth = 450
        local barHeight = 16
        local barX = (screenWidth - barWidth) / 2

        for idx, boss in ipairs(bosses) do
            local barY = 40 + (idx - 1) * 50

            -- 보스 이름 출력
            love.graphics.setFont(getFont(18))
            love.graphics.setColor(0.9, 0.2, 0.9) -- 보라색 네온 컬러 느낌
            love.graphics.printf(boss.name or "BOSS", 0, barY - 24, screenWidth, "center")

            -- HP바 배경
            love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
            love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 4, 4)

            -- HP바 내용물
            local hpRatio = math.max(0, boss.health / boss.maxHealth)
            love.graphics.setColor(0.8, 0.15, 0.15, 0.9)
            love.graphics.rectangle("fill", barX, barY, barWidth * hpRatio, barHeight, 4, 4)

            -- HP바 광택 효과
            love.graphics.setColor(1.0, 1.0, 1.0, 0.15)
            love.graphics.rectangle("fill", barX, barY, barWidth * hpRatio, barHeight / 2, 4, 4)

            -- HP바 테두리 (네온 파란색/보라색 글로우 테두리)
            love.graphics.setLineWidth(2)
            love.graphics.setColor(0.5, 0.2, 0.9, 0.8)
            love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 4, 4)

            -- HP 수치 텍스트
            love.graphics.setFont(getFont(12))
            love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
            local displayHp = math.max(0, math.ceil(boss.health))
            local displayMaxHp = math.max(1, math.ceil(boss.maxHealth))
            love.graphics.printf(displayHp .. " / " .. displayMaxHp, barX, barY + 1, barWidth, "center")
        end
    end
end

-- ============================================================================
-- Main Menu
-- ============================================================================
function HUD.drawMainMenu(game)
    love.graphics.clear(0.05, 0.05, 0.07) -- Deep space dark color

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mx, my = love.mouse.getPosition()

    -- Futuristic title rendering
    local titleGlow = 0.85 + math.sin(love.timer.getTime() * 4) * 0.1
    love.graphics.setFont(getFont(54))
    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.printf("ROGUELIKE SURVIVOR", 4, screenHeight / 2 - 216, screenWidth, "center")
    -- Main neon logo
    love.graphics.setColor(0.3, 0.7, 1.0, titleGlow)
    love.graphics.printf("ROGUELIKE SURVIVOR", 0, screenHeight / 2 - 220, screenWidth, "center")

    -- 4 menu navigation buttons
    local buttons = {
        { label = "START GAME", state = "menu" },
        { label = "UPGRADES",   state = "meta_upgrade" },
        { label = "OPTIONS",    state = "settings" },
        { label = "EXIT GAME",  action = "exit" }
    }

    local btnW = 320
    local btnH = 50
    local startY = screenHeight / 2 - 80
    local gap = 70

    game.mainMenuButtons = {}

    for i, btn in ipairs(buttons) do
        local bx = (screenWidth - btnW) / 2
        local by = startY + (i - 1) * gap

        table.insert(game.mainMenuButtons, {
            x = bx,
            y = by,
            w = btnW,
            h = btnH,
            state = btn.state,
            action = btn.action
        })

        local isHovered = mx >= bx and mx <= bx + btnW and my >= by and my <= by + btnH

        if isHovered then
            love.graphics.setColor(0.12, 0.2, 0.35, 0.95)
        else
            love.graphics.setColor(0.08, 0.1, 0.15, 0.85)
        end
        love.graphics.rectangle("fill", bx, by, btnW, btnH, 6, 6)

        if isHovered then
            love.graphics.setLineWidth(2)
            love.graphics.setColor(0.3, 0.8, 1.0, 0.95)
        else
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.2, 0.4, 0.6, 0.7)
        end
        love.graphics.rectangle("line", bx, by, btnW, btnH, 6, 6)

        love.graphics.setFont(getFont(18))
        if isHovered then
            love.graphics.setColor(1.0, 1.0, 1.0)
        else
            love.graphics.setColor(0.7, 0.8, 0.9)
        end
        love.graphics.printf(btn.label, bx, by + 14, btnW, "center")
    end

    -- Accumulated Persistent Score
    love.graphics.setFont(getFont(16))
    love.graphics.setColor(1.0, 0.75, 0.2, 0.85)
    love.graphics.printf("TOTAL SCORE: " .. (game.totalScore or 0) .. " PTS", 0, screenHeight - 60, screenWidth, "center")

    love.graphics.setLineWidth(1)
end

-- ============================================================================
-- Settings View
-- ============================================================================
function HUD.drawSettings(game)
    love.graphics.clear(0.05, 0.05, 0.07)

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mx, my = love.mouse.getPosition()

    -- Title
    love.graphics.setFont(getFont(36))
    love.graphics.setColor(0.3, 0.7, 1.0)
    love.graphics.printf("OPTIONS", 0, screenHeight / 2 - 200, screenWidth, "center")

    local cboxSize = 24
    local startY = screenHeight / 2 - 80
    local gap = 60

    local options = {
        { key = "showStars", label = "Enable Background Star Dust" },
        { key = "muted",     label = "Mute Background Sound" }
    }

    game.settingsCheckboxes = {}

    for i, opt in ipairs(options) do
        local bx = screenWidth / 2 - 220
        local by = startY + (i - 1) * gap

        table.insert(game.settingsCheckboxes, {
            x = bx, y = by, w = cboxSize, h = cboxSize, key = opt.key
        })

        local isHovered = mx >= bx and mx <= bx + 450 and my >= by and my <= by + cboxSize

        if isHovered then
            love.graphics.setColor(0.15, 0.25, 0.4)
        else
            love.graphics.setColor(0.08, 0.1, 0.15)
        end
        love.graphics.rectangle("fill", bx, by, cboxSize, cboxSize, 4, 4)

        love.graphics.setColor(0.3, 0.7, 1.0, 0.8)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", bx, by, cboxSize, cboxSize, 4, 4)

        if game[opt.key] then
            love.graphics.setColor(0.3, 1.0, 0.5)
            love.graphics.rectangle("fill", bx + 5, by + 5, cboxSize - 10, cboxSize - 10, 2, 2)
        end

        love.graphics.setFont(getFont(16))
        love.graphics.setColor(0.85, 0.9, 0.95)
        love.graphics.print(opt.label, bx + 40, by + 2)
    end

    -- BACK button
    local btnW = 180
    local btnH = 46
    local btnX = (screenWidth - btnW) / 2
    local btnY = screenHeight / 2 + 120

    game.settingsBackBtn = { x = btnX, y = btnY, w = btnW, h = btnH }

    local isBackHovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

    if isBackHovered then
        love.graphics.setColor(0.12, 0.2, 0.35, 0.95)
    else
        love.graphics.setColor(0.08, 0.1, 0.15, 0.85)
    end
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 6, 6)

    if isBackHovered then
        love.graphics.setColor(0.3, 0.8, 1.0, 0.95)
    else
        love.graphics.setColor(0.2, 0.4, 0.6, 0.7)
    end
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 6, 6)

    love.graphics.setFont(getFont(16))
    love.graphics.setColor(1.0, 1.0, 1.0)
    love.graphics.printf("BACK", btnX, btnY + 12, btnW, "center")

    love.graphics.setLineWidth(1)
end

-- ============================================================================
-- Meta Upgrades (2-Column Grid Layout Shop)
-- ============================================================================
function HUD.drawMetaUpgrade(game)
    love.graphics.clear(0.05, 0.05, 0.07)

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mx, my = love.mouse.getPosition()
    local page = game.metaUpgradePage or 1

    -- Title
    love.graphics.setFont(getFont(32))
    love.graphics.setColor(0.3, 0.7, 1.0)
    love.graphics.printf("META UPGRADES", 0, 35, screenWidth, "center")

    -- Available score PTS
    love.graphics.setFont(getFont(18))
    love.graphics.setColor(1.0, 0.75, 0.2)
    love.graphics.printf("AVAILABLE SCORE: " .. (game.totalScore or 0) .. " PTS", 0, 85, screenWidth, "center")

    -- Tabs Navigation
    local tabW = 200
    local tabH = 36
    local tabY = 120
    local centerX = screenWidth / 2

    game.metaUpgradeTabs = {
        { x = centerX - tabW - 10, y = tabY, w = tabW, h = tabH, page = 1, label = "ACTIVE SKILLS" },
        { x = centerX + 10,        y = tabY, w = tabW, h = tabH, page = 2, label = "PASSIVE STATS" }
    }

    for _, tab in ipairs(game.metaUpgradeTabs) do
        local isHovered = mx >= tab.x and mx <= tab.x + tab.w and my >= tab.y and my <= tab.y + tab.h
        local isActive = (page == tab.page)

        -- Tab background
        if isActive then
            love.graphics.setColor(0.12, 0.22, 0.4, 0.95)
        elseif isHovered then
            love.graphics.setColor(0.08, 0.14, 0.25, 0.8)
        else
            love.graphics.setColor(0.05, 0.07, 0.1, 0.6)
        end
        love.graphics.rectangle("fill", tab.x, tab.y, tab.w, tab.h, 6, 6)

        -- Tab border
        if isActive then
            love.graphics.setLineWidth(2)
            love.graphics.setColor(0.3, 0.8, 1.0, 0.95)
        else
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.2, 0.4, 0.6, 0.7)
        end
        love.graphics.rectangle("line", tab.x, tab.y, tab.w, tab.h, 6, 6)

        -- Tab label
        love.graphics.setFont(getFont(15))
        if isActive then
            love.graphics.setColor(1.0, 1.0, 1.0)
        else
            love.graphics.setColor(0.6, 0.7, 0.8)
        end
        love.graphics.printf(tab.label, tab.x, tab.y + 9, tab.w, "center")
    end

    -- Upgradable items lists
    local activeUpgrades = {
        { index = 1,  name = "Orbiting Orb",   baseCost = 1000, scale = 500, max = 5, desc = "Orbiting damage aura." },
        { index = 2,  name = "Thunder",        baseCost = 1000, scale = 500, max = 5, desc = "Strike lightning periodically." },
        { index = 3,  name = "Blade",          baseCost = 1000, scale = 500, max = 5, desc = "Fire homing glaives." },
        { index = 4,  name = "Bullet",         baseCost = 1000, scale = 500, max = 5, desc = "Fire rapid projectiles." },
        { index = 5,  name = "Laser",          baseCost = 1200, scale = 600, max = 5, desc = "Fire plasma beam." },
        { index = 6,  name = "Magnetic Field", baseCost = 1200, scale = 600, max = 5, desc = "Deploy electric field." },
        { index = 7,  name = "Meteor",         baseCost = 1500, scale = 700, max = 5, desc = "Call meteors from sky." },
        { index = 8,  name = "Cutter",         baseCost = 1200, scale = 600, max = 5, desc = "Rotate energy blades." },
        { index = 9,  name = "Chain",          baseCost = 1200, scale = 600, max = 5, desc = "Lock enemies with chains." },
        { index = 10, name = "Seeker Orb",     baseCost = 1200, scale = 600, max = 5, desc = "Spawn homing orbs." }
    }

    local passiveUpgrades = {
        { index = 1, name = "Magnet",        baseCost = 800,  scale = 400, max = 3,   desc = "Pull experience from far." },
        { index = 2, name = "Health Boost",  baseCost = 1000, scale = 500, max = 999, desc = "Permanent starting HP +10%." },
        { index = 3, name = "Speed Boost",   baseCost = 1000, scale = 500, max = 3,   desc = "Permanent speed boost +5%." },
        { index = 4, name = "Damage Boost",  baseCost = 1200, scale = 600, max = 999, desc = "Permanent weapon damage +10%." },
        { index = 5, name = "Health Regen",  baseCost = 1000, scale = 500, max = 3,   desc = "Permanent starting regen +5%." },
        { index = 6, name = "EXP Boost",     baseCost = 1200, scale = 600, max = 3,   desc = "Permanent EXP collection +25%." },
        { index = 8, name = "Energy Shield", baseCost = 1500, scale = 700, max = 3,   desc = "Block 1 hit unconditionally every 12/9/6s." },
        { index = 9, name = "Defense Boost", baseCost = 1200, scale = 600, max = 999, desc = "Reduce damage taken by 5% per level." }
    }

    local itemsToShow = {}
    local itemType = ""
    if page == 1 then
        itemsToShow = activeUpgrades
        itemType = "skill"
    else
        itemsToShow = passiveUpgrades
        itemType = "upgrade"
    end

    local colCount = 4
    local colWidth = 270
    local colSpacing = 16
    local itemH = 74
    local startY = 180
    local gapY = 84

    game.upgradeStoreButtons = {}

    for i, up in ipairs(itemsToShow) do
        local lv = 0
        if itemType == "skill" then
            lv = game.metaUpgrades.skills[up.index] or 0
        else
            lv = game.metaUpgrades.upgrades[up.index] or 0
        end

        local cost = up.baseCost + lv * up.scale
        local isMax = lv >= up.max

        local row = math.ceil(i / colCount)
        local col = (i - 1) % colCount + 1

        local totalW = colCount * colWidth + (colCount - 1) * colSpacing
        local rx = (screenWidth - totalW) / 2 + (col - 1) * (colWidth + colSpacing)
        local ry = startY + (row - 1) * gapY

        -- Item Box Body
        love.graphics.setColor(0.07, 0.08, 0.12, 0.95)
        love.graphics.rectangle("fill", rx, ry, colWidth, itemH, 6, 6)

        -- Border
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.2, 0.35, 0.5, 0.6)
        love.graphics.rectangle("line", rx, ry, colWidth, itemH, 6, 6)

        -- Title (Name)
        love.graphics.setFont(getFont(15))
        love.graphics.setColor(0.9, 0.95, 1.0)
        love.graphics.print(up.name, rx + 12, ry + 8)

        -- Level Info (Lv. X/Y) - 우측 상단으로 이동배치하여 BUY 버튼 및 긴 텍스트와 겹침 방지
        love.graphics.setFont(getFont(11))
        love.graphics.setColor(0.3, 0.8, 1.0)
        if up.max >= 999 then
            love.graphics.printf("Lv. " .. lv, rx, ry + 12, colWidth - 100, "right")
        else
            love.graphics.printf("Lv. " .. lv .. "/" .. up.max, rx, ry + 12, colWidth - 100, "right")
        end

        -- BUY Button dimensions & coordinates
        local btnW = 80
        local btnH = 34
        local btnX = rx + colWidth - btnW - 12
        local btnY = ry + (itemH - btnH) / 2

        -- Get level-specific description dynamically
        local displayDesc = up.desc
        local nextLevel = lv + 1
        if isMax then
            nextLevel = lv
        end

        if itemType == "skill" then
            local descList = skillLevelDescriptions[up.index]
            if descList and descList[nextLevel] then
                displayDesc = descList[nextLevel]
            end
        else
            local descList = upgradeLevelDescriptions[up.index]
            if descList and descList[nextLevel] then
                displayDesc = descList[nextLevel]
            end
        end

        -- Description (2-line layout, wrapped to avoid overlap with BUY button)
        love.graphics.setColor(0.65, 0.7, 0.75)
        love.graphics.setFont(getFont(11))
        local maxDescWidth = btnX - rx - 24
        love.graphics.printf(displayDesc, rx + 12, ry + 32, maxDescWidth, "left")

        table.insert(game.upgradeStoreButtons, {
            x = btnX, y = btnY, w = btnW, h = btnH, type = itemType, index = up.index, cost = cost, max = up.max, lv = lv
        })

        local isHovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
        local canAfford = (game.totalScore or 0) >= cost

        if isMax then
            love.graphics.setColor(0.15, 0.15, 0.15, 0.8)
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 4, 4)
            love.graphics.setColor(0.4, 0.4, 0.4)
            love.graphics.printf("MAXED", btnX, btnY + 10, btnW, "center")
        elseif not canAfford then
            love.graphics.setColor(0.12, 0.12, 0.14, 0.8)
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 4, 4)
            love.graphics.setColor(0.55, 0.35, 0.35)
            love.graphics.printf(cost .. "P", btnX, btnY + 10, btnW, "center")
        else
            if isHovered then
                love.graphics.setColor(0.1, 0.35, 0.2)
            else
                love.graphics.setColor(0.08, 0.25, 0.15)
            end
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 4, 4)

            if isHovered then
                love.graphics.setColor(0.3, 1.0, 0.5)
            else
                love.graphics.setColor(0.2, 0.8, 0.4)
            end
            love.graphics.setLineWidth(1.2)
            love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 4, 4)

            love.graphics.setColor(1.0, 1.0, 1.0)
            love.graphics.printf("BUY " .. cost, btnX, btnY + 10, btnW, "center")
        end
    end

    -- BACK and RESET ALL buttons (side by side, centered)
    local btnW = 180
    local btnH = 46
    local gap = 20
    local backX = centerX - btnW - gap / 2
    local resetX = centerX + gap / 2
    local btnY = screenHeight - 65

    game.upgradeBackBtn = { x = backX, y = btnY, w = btnW, h = btnH }
    game.upgradeResetBtn = { x = resetX, y = btnY, w = btnW, h = btnH }

    -- Draw BACK button
    local isBackHovered = mx >= backX and mx <= backX + btnW and my >= btnY and my <= btnY + btnH
    if isBackHovered then
        love.graphics.setColor(0.12, 0.2, 0.35, 0.95)
    else
        love.graphics.setColor(0.08, 0.1, 0.15, 0.85)
    end
    love.graphics.rectangle("fill", backX, btnY, btnW, btnH, 6, 6)

    if isBackHovered then
        love.graphics.setColor(0.3, 0.8, 1.0, 0.95)
    else
        love.graphics.setColor(0.2, 0.4, 0.6, 0.7)
    end
    love.graphics.rectangle("line", backX, btnY, btnW, btnH, 6, 6)

    love.graphics.setFont(getFont(16))
    love.graphics.setColor(1.0, 1.0, 1.0)
    love.graphics.printf("BACK", backX, btnY + 12, btnW, "center")

    -- Draw RESET ALL button
    local isResetHovered = mx >= resetX and mx <= resetX + btnW and my >= btnY and my <= btnY + btnH
    if isResetHovered then
        love.graphics.setColor(0.35, 0.12, 0.12, 0.95)
    else
        love.graphics.setColor(0.15, 0.08, 0.08, 0.85)
    end
    love.graphics.rectangle("fill", resetX, btnY, btnW, btnH, 6, 6)

    if isResetHovered then
        love.graphics.setColor(1.0, 0.3, 0.3, 0.95)
    else
        love.graphics.setColor(0.6, 0.2, 0.2, 0.7)
    end
    love.graphics.rectangle("line", resetX, btnY, btnW, btnH, 6, 6)

    love.graphics.setFont(getFont(16))
    if isResetHovered then
        love.graphics.setColor(1.0, 1.0, 1.0)
    else
        love.graphics.setColor(0.9, 0.7, 0.7)
    end
    love.graphics.printf("RESET ALL", resetX, btnY + 12, btnW, "center")

    love.graphics.setLineWidth(1)
end

function HUD.resetMetaUpgrades(game)
    local activeUpgrades = {
        { index = 1,  name = "Orbiting Orb",   baseCost = 1000, scale = 500, max = 5, desc = "Orbiting damage aura." },
        { index = 2,  name = "Thunder",        baseCost = 1000, scale = 500, max = 5, desc = "Strike lightning periodically." },
        { index = 3,  name = "Blade",          baseCost = 1000, scale = 500, max = 5, desc = "Fire homing glaives." },
        { index = 4,  name = "Bullet",         baseCost = 1000, scale = 500, max = 5, desc = "Fire rapid projectiles." },
        { index = 5,  name = "Laser",          baseCost = 1200, scale = 600, max = 5, desc = "Fire plasma beam." },
        { index = 6,  name = "Magnetic Field", baseCost = 1200, scale = 600, max = 5, desc = "Deploy electric field." },
        { index = 7,  name = "Meteor",         baseCost = 1500, scale = 700, max = 5, desc = "Call meteors from sky." },
        { index = 8,  name = "Cutter",         baseCost = 1200, scale = 600, max = 5, desc = "Rotate energy blades." },
        { index = 9,  name = "Chain",          baseCost = 1200, scale = 600, max = 5, desc = "Lock enemies with chains." },
        { index = 10, name = "Seeker Orb",     baseCost = 1200, scale = 600, max = 5, desc = "Spawn homing orbs." }
    }

    local passiveUpgrades = {
        { index = 1, name = "Magnet",        baseCost = 800,  scale = 400, max = 3,   desc = "Attract experience from far." },
        { index = 2, name = "Health Boost",  baseCost = 1000, scale = 500, max = 999, desc = "Permanent starting HP +10%." },
        { index = 3, name = "Speed Boost",   baseCost = 1000, scale = 500, max = 3,   desc = "Permanent speed boost +5%." },
        { index = 4, name = "Damage Boost",  baseCost = 1200, scale = 600, max = 999, desc = "Permanent weapon damage +10%." },
        { index = 5, name = "Health Regen",  baseCost = 1000, scale = 500, max = 3,   desc = "Permanent starting regen +5%." },
        { index = 6, name = "EXP Boost",     baseCost = 1200, scale = 600, max = 3,   desc = "Permanent EXP collection +25%." },
        { index = 8, name = "Energy Shield", baseCost = 1500, scale = 700, max = 3,   desc = "Block 1 hit unconditionally every 12/9/6s." },
        { index = 9, name = "Defense Boost", baseCost = 1200, scale = 600, max = 999, desc = "Reduce damage taken by 5% per level." }
    }

    local refundPoints = 0

    -- Calculate active skills refund
    for _, up in ipairs(activeUpgrades) do
        local lv = game.metaUpgrades.skills[up.index] or 0
        if lv > 0 then
            for currentLv = 0, lv - 1 do
                refundPoints = refundPoints + (up.baseCost + currentLv * up.scale)
            end
            game.metaUpgrades.skills[up.index] = 0
        end
    end

    -- Calculate passive upgrades refund
    for _, up in ipairs(passiveUpgrades) do
        local lv = game.metaUpgrades.upgrades[up.index] or 0
        if lv > 0 then
            for currentLv = 0, lv - 1 do
                refundPoints = refundPoints + (up.baseCost + currentLv * up.scale)
            end
            game.metaUpgrades.upgrades[up.index] = 0
        end
    end

    game.totalScore = (game.totalScore or 0) + refundPoints
    game.saveGame()
end

-- ============================================================================
-- Pause Menu Screen (Premium Glassmorphism Overlay)
-- ============================================================================
function HUD.drawPause(game)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mx, my = love.mouse.getPosition()

    -- 1. Dark semi-transparent background overlay
    love.graphics.setColor(0.02, 0.02, 0.03, 0.65)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- 2. Glassmorphism popup container (340px width, 420px height)
    local w, h = 340, 420
    local px = (screenWidth - w) / 2
    local py = (screenHeight - h) / 2

    -- Soft neon glow shadow layer behind popup
    love.graphics.setColor(0.1, 0.4, 0.8, 0.12)
    love.graphics.rectangle("fill", px - 6, py - 6, w + 12, h + 12, 16, 16)

    -- Main container panel body
    love.graphics.setColor(0.06, 0.08, 0.12, 0.92)
    love.graphics.rectangle("fill", px, py, w, h, 12, 12)

    -- Container neon border
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.2, 0.45, 0.75, 0.65)
    love.graphics.rectangle("line", px, py, w, h, 12, 12)

    -- 3. Title: "GAME PAUSED" with pulsing aura
    love.graphics.setFont(getFont(28))
    local titleGlow = 0.8 + math.sin(love.timer.getTime() * 3) * 0.15

    -- Drop shadow for readability
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.printf("GAME PAUSED", px + 2, py + 37, w, "center")

    -- Main cyan glowing title
    love.graphics.setColor(0.3, 0.75, 1.0, titleGlow)
    love.graphics.printf("GAME PAUSED", px, py + 35, w, "center")

    -- Elegant separator line
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.2, 0.35, 0.5, 0.4)
    love.graphics.line(px + 40, py + 85, px + w - 40, py + 85)

    -- 4. Four Menu Buttons (Resume, Options, Title Menu, Exit Game)
    local buttons = {
        { label = "RESUME",     action = "resume" },
        { label = "OPTIONS",    action = "settings" },
        { label = "TITLE MENU", action = "title" },
        { label = "EXIT GAME",  action = "exit" }
    }

    local btnW = 260
    local btnH = 50
    local startY = py + 110
    local gap = 68

    game.pauseButtons = {}

    for i, btn in ipairs(buttons) do
        local bx = px + (w - btnW) / 2
        local by = startY + (i - 1) * gap

        -- Store coordinates for collision check in love.mousepressed
        table.insert(game.pauseButtons, {
            x = bx, y = by, w = btnW, h = btnH, action = btn.action
        })

        local isHovered = mx >= bx and mx <= bx + btnW and my >= by and my <= by + btnH

        -- Micro-animation: Hover scale and coordinate adjustments
        local scale = isHovered and 1.03 or 1.0
        local drawW = btnW * scale
        local drawH = btnH * scale
        local drawX = bx - (drawW - btnW) / 2
        local drawY = by - (drawH - btnH) / 2

        -- Draw button background & outline
        if isHovered then
            -- Cyan-blue hover glow background
            love.graphics.setColor(0.12, 0.22, 0.4, 0.95)
            love.graphics.rectangle("fill", drawX, drawY, drawW, drawH, 6, 6)

            -- Pulsing border
            local borderPulse = 0.8 + math.sin(love.timer.getTime() * 8) * 0.2
            love.graphics.setLineWidth(2)
            love.graphics.setColor(0.3, 0.8, 1.0, borderPulse)
            love.graphics.rectangle("line", drawX, drawY, drawW, drawH, 6, 6)
        else
            -- Semi-transparent default background
            love.graphics.setColor(0.08, 0.1, 0.15, 0.8)
            love.graphics.rectangle("fill", drawX, drawY, drawW, drawH, 6, 6)

            -- Normal border
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.2, 0.35, 0.5, 0.6)
            love.graphics.rectangle("line", drawX, drawY, drawW, drawH, 6, 6)
        end

        -- Text rendering (main label)
        love.graphics.setFont(getFont(15))
        if isHovered then
            love.graphics.setColor(1.0, 1.0, 1.0)
        else
            love.graphics.setColor(0.8, 0.85, 0.95)
        end

        -- Draw text centered within the button
        local displayText = btn.label
        love.graphics.printf(displayText, drawX, drawY + 16, drawW, "center")
    end

    love.graphics.setLineWidth(1)
end

-- ============================================================================
-- Help & Cheat Codes Overlay (F1 Window)
-- ============================================================================
function HUD.drawHelp(game)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mx, my = love.mouse.getPosition()

    -- 1. Dark semi-transparent background overlay
    love.graphics.setColor(0.02, 0.02, 0.03, 0.75)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- 2. Glassmorphism popup container (560px width, 480px height)
    local w, h = 560, 480
    local px = (screenWidth - w) / 2
    local py = (screenHeight - h) / 2

    -- Soft neon glow shadow layer behind popup
    love.graphics.setColor(0.1, 0.5, 0.9, 0.15)
    love.graphics.rectangle("fill", px - 6, py - 6, w + 12, h + 12, 16, 16)

    -- Main container panel body
    love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", px, py, w, h, 12, 12)

    -- Container neon border
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.2, 0.5, 0.85, 0.8)
    love.graphics.rectangle("line", px, py, w, h, 12, 12)

    -- 3. Title: "GAME INFO & CHEATS" with pulsing aura
    love.graphics.setFont(getFont(26))
    local titleGlow = 0.85 + math.sin(love.timer.getTime() * 4) * 0.15

    -- Drop shadow for readability
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.printf("HELP AND CHEAT CODES", px + 2, py + 32, w, "center")

    -- Main cyan glowing title
    love.graphics.setColor(0.3, 0.8, 1.0, titleGlow)
    love.graphics.printf("HELP AND CHEAT CODES", px, py + 30, w, "center")

    -- Elegant separator line
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.2, 0.35, 0.5, 0.4)
    love.graphics.line(px + 40, py + 75, px + w - 40, py + 75)

    -- 4. Left Column: CONTROLS
    local colW = 220
    local lx = px + 40
    local ly = py + 95

    love.graphics.setFont(getFont(18))
    love.graphics.setColor(0.3, 1.0, 0.5) -- Neon Green
    love.graphics.print("CONTROLS", lx, ly)

    love.graphics.setFont(getFont(13))
    love.graphics.setColor(0.85, 0.9, 0.95)
    local controls = {
        { key = "W, A, S, D",  desc = "Move character" },
        { key = "Arrow Keys",  desc = "Move character" },
        { key = "ESC Key",     desc = "Pause / Go Back" },
        { key = "F1 Key",      desc = "Toggle Help Overlay" },
        { key = "Auto Attack", desc = "All weapons fire automatically at regular intervals." }
    }

    local textY = ly + 30
    for _, ctrl in ipairs(controls) do
        love.graphics.setColor(0.4, 0.75, 1.0) -- Key color (cyan)
        love.graphics.print(ctrl.key, lx, textY)
        love.graphics.setColor(0.8, 0.85, 0.9) -- Desc color

        if ctrl.key == "Auto Attack" then
            love.graphics.printf(ctrl.desc, lx, textY + 18, colW, "left")
            textY = textY + 50
        else
            love.graphics.print(" : " .. ctrl.desc, lx + 105, textY)
            textY = textY + 22
        end
    end

    -- 5. Right Column: CHEAT CODES
    local rx = px + w - colW - 40
    local ry = py + 95

    love.graphics.setFont(getFont(18))
    love.graphics.setColor(1.0, 0.4, 0.4) -- Neon Red
    love.graphics.print("CHEAT CODES", rx, ry)

    love.graphics.setFont(getFont(13))
    love.graphics.setColor(0.85, 0.9, 0.95)
    local cheats = {
        { key = "O Key", desc = "Instant Level Up (grants EXP)" },
        { key = "K Key", desc = "Force Skip to Next Stage" },
        { key = "I Key", desc = "Spawn Boss Wave (Wave 7 / Next 5th Wave)" },
        { key = "P Key", desc = "Clear All Enemies & Bullets" }
    }

    textY = ry + 30
    for _, cheat in ipairs(cheats) do
        love.graphics.setColor(1.0, 0.75, 0.2) -- Cheat key color (golden)
        love.graphics.print(cheat.key, rx, textY)
        love.graphics.setColor(0.8, 0.85, 0.9) -- Desc color
        love.graphics.printf(cheat.desc, rx, textY + 18, colW, "left")
        textY = textY + 52
    end

    -- Elegant separator line before Close Button
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.2, 0.35, 0.5, 0.4)
    love.graphics.line(px + 40, py + h - 75, px + w - 40, py + h - 75)

    -- 6. CLOSE Button
    local btnW = 180
    local btnH = 40
    local btnX = px + (w - btnW) / 2
    local btnY = py + h - 55

    game.helpCloseBtn = { x = btnX, y = btnY, w = btnW, h = btnH }

    local isHovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

    -- Scale micro-animation on hover
    local scale = isHovered and 1.03 or 1.0
    local drawW = btnW * scale
    local drawH = btnH * scale
    local drawX = btnX - (drawW - btnW) / 2
    local drawY = btnY - (drawH - btnH) / 2

    if isHovered then
        love.graphics.setColor(0.12, 0.22, 0.4, 0.95)
        love.graphics.rectangle("fill", drawX, drawY, drawW, drawH, 6, 6)

        local borderPulse = 0.8 + math.sin(love.timer.getTime() * 8) * 0.2
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.3, 0.8, 1.0, borderPulse)
        love.graphics.rectangle("line", drawX, drawY, drawW, drawH, 6, 6)
    else
        love.graphics.setColor(0.08, 0.1, 0.15, 0.8)
        love.graphics.rectangle("fill", drawX, drawY, drawW, drawH, 6, 6)

        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.2, 0.35, 0.5, 0.6)
        love.graphics.rectangle("line", drawX, drawY, drawW, drawH, 6, 6)
    end

    love.graphics.setFont(getFont(14))
    if isHovered then
        love.graphics.setColor(1.0, 1.0, 1.0)
    else
        love.graphics.setColor(0.8, 0.85, 0.95)
    end
    love.graphics.printf("CLOSE", drawX, drawY + 11, drawW, "center")

    love.graphics.setLineWidth(1)
end

return HUD
