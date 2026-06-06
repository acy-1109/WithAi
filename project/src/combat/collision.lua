-- ============================================================================
-- collision.lua — AABB 충돌 감지 모듈
-- ============================================================================

local Collision = {}

-- 두 사각형 객체 간의 충돌 감지
function Collision.check(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

return Collision
