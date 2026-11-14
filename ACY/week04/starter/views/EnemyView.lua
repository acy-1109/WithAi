-- EnemyView.lua  (STARTER)
-- 살아있는 적을 그린다. Model 을 읽기만 한다. 참고: PlayerView.lua (완성 예시)

local EnemyView = {}

local COLOR = { 1, 0.4, 0.4 }

--- @param enemies table  EnemyModel 배열 (읽기 전용)
function EnemyView.draw(gfx, enemies)
  -- TODO: 색을 정하고, alive 인 적만 gfx.rectangle("fill", x, y, w, h)
  --       ⚠️ e.alive = ... 처럼 쓰는 순간 view_test 의 "읽기 전용" 검사가 잡아낸다.
  gfx.setColor(COLOR[1], COLOR[2], COLOR[3])
  for i = 1, #enemies do
    local e = enemies[i]
    if e.alive then
      gfx.rectangle("fill", e.x, e.y, e.w, e.h)
    end
  end
end

return EnemyView
