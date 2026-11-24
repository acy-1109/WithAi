-- TitleView.lua
-- 타이틀 화면을 그린다.

local TitleView = {}

function TitleView.draw(gfx, width, height, best)
  gfx.setColor(0.4, 0.9, 1)
  gfx.printf("GALAGA", 0, height * 0.35, width, "center")
  gfx.setColor(1, 0.9, 0.3)
  gfx.printf("BEST " .. (best or 0), 0, height * 0.43, width, "center")
  gfx.setColor(1, 1, 1)
  gfx.printf("Enter / Space : START\nD : DIFFICULTY\nEsc : QUIT", 0, height * 0.5, width, "center")
end

return TitleView
