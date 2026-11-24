-- HudView.lua
-- 점수·라이프. Model 을 읽기만 한다.
-- 5주차: "GAME OVER / YOU WIN" 문구는 결과 씬(ResultView)으로 옮겼다.

local HudView = {}

--- @param game      table      GameModel (읽기 전용: score, wave, lives)
--- @param highScore table|nil  HighScoreModel (읽기 전용: best)
function HudView.draw(gfx, game, width, height, highScore)
  local best = highScore and highScore.best or 0
  gfx.setColor(1, 0.9, 0.3)
  gfx.print("BEST " .. best, 10, 10)
  gfx.setColor(1, 1, 1)
  gfx.print("SCORE " .. game.score, 10, 28)
  gfx.printf("WAVE " .. (game.wave or 1), 0, 10, width, "center")
  gfx.print("LIVES " .. game.lives, width - 100, 10)
end

return HudView
