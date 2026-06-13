-- ============================================================================
-- collision.lua — AABB 충돌 감지 모듈
-- ============================================================================

local Collision = {}

-- 두 사각형 객체 간의 충돌 감지
function Collision.check(a, b)
    if (a and a.dying) or (b and b.dying) then return false end
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

-- 선분과 원 간의 충돌 감지
function Collision.checkLineCircle(ax, ay, bx, by, cx, cy, r)
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

return Collision
