-- ResultView.lua
-- 결과 오버레이: GAME OVER 또는 YOU WIN + 최종 점수.

local ResultView = {}

function ResultView.draw(gfx, width, height, won, score, best, isNewBest)
  gfx.setColor(0, 0, 0, 0.5)
  gfx.rectangle("fill", 0, 0, width, height)
  if won then
    gfx.setColor(0.6, 1, 0.6)
  else
    gfx.setColor(1, 0.5, 0.5)
  end
  local text = (won and "YOU WIN!" or "GAME OVER") .. "\nSCORE " .. score
  if best ~= nil then
    text = text .. "\n" .. (isNewBest and "NEW BEST! " or "BEST ") .. best
  end
  gfx.printf(text, 0, height * 0.36, width, "center")
  gfx.setColor(1, 1, 1)
  gfx.printf("R : RETRY\nEnter : TITLE", 0, height * 0.56, width, "center")
end

return ResultView
