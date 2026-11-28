-- DifficultyView.lua
-- 난이도 선택 화면을 그린다. Model/Scene 상태를 바꾸지 않고 읽기만 한다.

local DifficultyView = {}

function DifficultyView.draw(gfx, width, height, options, selected)
  gfx.setColor(0.4, 0.9, 1)
  gfx.printf("SELECT SHIP", 0, height * 0.25, width, "center")

  for i = 1, #options do
    local ship = options[i]
    local label = string.format("%d. %s [%s] - %s", i, ship.name, ship.role, ship.desc)
    local y = height * 0.38 + (i - 1) * 40
    if i == selected then
      gfx.setColor(1, 0.9, 0.3)
      gfx.printf("> " .. label .. " <", 0, y, width, "center")
    else
      gfx.setColor(0.8, 0.8, 0.85)
      gfx.printf(label, 0, y, width, "center")
    end
  end

  gfx.setColor(0.7, 0.7, 0.8)
  gfx.printf("Arrow / WASD / 1-3 : Select   |   Enter/Space : Start   |   Esc : Back", 0, height * 0.68, width, "center")
end

return DifficultyView

