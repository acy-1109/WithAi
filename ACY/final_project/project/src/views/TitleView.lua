-- TitleView.lua
-- 타이틀 화면을 그린다.

local TitleView = {}

--- 타이틀 화면의 업적 버튼 사각형 영역을 반환한다.
function TitleView.getAchievementButtonRect(width, height)
  local w, h = 220, 42
  return {
    x = (width - w) * 0.5,
    y = height * 0.64,
    w = w,
    h = h,
  }
end

function TitleView.draw(gfx, width, height, best, hovered)
  gfx.setColor(0.4, 0.9, 1)
  gfx.printf("GALAGA", 0, height * 0.35, width, "center")
  gfx.setColor(1, 0.9, 0.3)
  gfx.printf("BEST " .. (best or 0), 0, height * 0.43, width, "center")
  gfx.setColor(1, 1, 1)
  gfx.printf("Enter / Space : START\nD : DIFFICULTY\nEsc : QUIT", 0, height * 0.5, width, "center")

  local btn = TitleView.getAchievementButtonRect(width, height)
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
  gfx.printf("ACHIEVEMENTS", btn.x, btn.y + 13, btn.w, "center")
end

return TitleView
