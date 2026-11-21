-- DifficultyView.lua
-- 난이도 선택 화면을 그린다. Model/Scene 상태를 바꾸지 않고 읽기만 한다.

local DifficultyView = {}

local LABELS = {
  easy = "1. EASY   (Slow bullets / Relaxed enemies)",
  normal = "2. NORMAL (Standard balance)",
  hard = "3. HARD   (Fast bullets / Aggressive enemies)",
}

function DifficultyView.draw(gfx, width, height, options, selected)
  gfx.setColor(0.4, 0.9, 1)
  gfx.printf("SELECT DIFFICULTY", 0, height * 0.28, width, "center")

  for i = 1, #options do
    local key = options[i]
    local text = LABELS[key] or key
    local y = height * 0.40 + (i - 1) * 36
    if i == selected then
      gfx.setColor(1, 0.9, 0.3)
      gfx.printf("> " .. text .. " <", 0, y, width, "center")
    else
      gfx.setColor(0.8, 0.8, 0.85)
      gfx.printf(text, 0, y, width, "center")
    end
  end

  gfx.setColor(0.7, 0.7, 0.8)
  gfx.printf("Up/Down or 1-3 : Select\nEnter/Space : Start   |   Esc : Back", 0, height * 0.65, width, "center")
end

return DifficultyView

