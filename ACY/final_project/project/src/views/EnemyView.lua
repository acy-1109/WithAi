-- EnemyView.lua
-- 살아있는 적을 종류별 색상으로 그린다. Model 을 읽기만 한다.

local EnemyView = {}

local DEFAULT_COLOR = { 1, 0.4, 0.4 }
local KIND_COLORS = {
  grunt = { 1, 0.4, 0.4 },
  tank = { 0.35, 0.7, 1.0 },
  sprinter = { 1.0, 0.85, 0.25 },
  sniper = { 0.8, 0.45, 1.0 },
}

--- @param enemies table  EnemyModel 배열 (읽기 전용)
function EnemyView.draw(gfx, enemies)
  for i = 1, #enemies do
    local e = enemies[i]
    if e.alive then
      local c = KIND_COLORS[e.kind] or DEFAULT_COLOR
      gfx.setColor(c[1], c[2], c[3])
      gfx.rectangle("fill", e.x, e.y, e.w, e.h)

      if e.maxHp and e.maxHp > 1 then
        gfx.setColor(0.2, 0.2, 0.2)
        gfx.rectangle("fill", e.x, e.y - 6, e.w, 4)
        gfx.setColor(0.3, 0.95, 0.5)
        gfx.rectangle("fill", e.x, e.y - 6, e.w * (e.hp / e.maxHp), 4)
      end
    end
  end
end

return EnemyView
