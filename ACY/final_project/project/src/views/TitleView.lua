-- TitleView.lua
-- 타이틀 화면을 그린다.

local TitleView = {}

local BUTTONS = {
  { id = "start", label = "START" },
  { id = "achievements", label = "ACHIEVEMENTS" },
  { id = "quit", label = "QUIT" },
}

local BUTTON_W = 220
local BUTTON_H = 42
local BUTTON_GAP = 14
local TITLE_FONT_SIZE = 52

local titleFont

local function drawTitleText(gfx, width, height)
  local prevFont
  if gfx.newFont and gfx.getFont and gfx.setFont then
    if not titleFont then
      titleFont = gfx.newFont(TITLE_FONT_SIZE)
    end
    prevFont = gfx.getFont()
    if titleFont then
      gfx.setFont(titleFont)
    end
  end

  gfx.setColor(0.4, 0.9, 1)
  gfx.printf("GALAGA", 0, height * 0.29, width, "center")

  if prevFont and gfx.setFont then
    gfx.setFont(prevFont)
  end
end

--- 타이틀 화면 버튼 목록(위치·크기·라벨)을 위에서 아래 순서로 반환한다.
function TitleView.getButtons(width, height)
  local x = (width - BUTTON_W) * 0.5
  local startY = height * 0.5
  local pitch = BUTTON_H + BUTTON_GAP
  local list = {}
  for i = 1, #BUTTONS do
    local item = BUTTONS[i]
    list[i] = {
      id = item.id,
      label = item.label,
      x = x,
      y = startY + (i - 1) * pitch,
      w = BUTTON_W,
      h = BUTTON_H,
    }
  end
  return list
end

--- 타이틀 화면의 업적 버튼 사각형 영역을 반환한다.
function TitleView.getAchievementButtonRect(width, height)
  local buttons = TitleView.getButtons(width, height)
  for i = 1, #buttons do
    if buttons[i].id == "achievements" then
      return buttons[i]
    end
  end
end

local function drawButton(gfx, btn, hovered)
  if gfx.polygon then
    if hovered then
      gfx.setColor(0.18, 0.28, 0.44, 0.95)
    else
      gfx.setColor(0.10, 0.14, 0.24, 0.9)
    end
    gfx.polygon(
      "fill",
      btn.x, btn.y,
      btn.x + btn.w, btn.y,
      btn.x + btn.w, btn.y + btn.h,
      btn.x, btn.y + btn.h
    )
    if hovered then
      gfx.setColor(0.5, 0.95, 1)
    else
      gfx.setColor(0.4, 0.75, 0.9)
    end
    gfx.polygon(
      "line",
      btn.x, btn.y,
      btn.x + btn.w, btn.y,
      btn.x + btn.w, btn.y + btn.h,
      btn.x, btn.y + btn.h
    )
  end

  if hovered then
    gfx.setColor(1, 0.95, 0.5)
  else
    gfx.setColor(0.9, 0.95, 1)
  end
  gfx.printf(btn.label, btn.x, btn.y + 13, btn.w, "center")
end

function TitleView.draw(gfx, width, height, best, hoveredId)
  drawTitleText(gfx, width, height)
  gfx.setColor(1, 0.9, 0.3)
  gfx.printf("BEST " .. (best or 0), 0, height * 0.43, width, "center")

  local buttons = TitleView.getButtons(width, height)
  for i = 1, #buttons do
    local btn = buttons[i]
    drawButton(gfx, btn, hoveredId == btn.id)
  end
end

return TitleView
