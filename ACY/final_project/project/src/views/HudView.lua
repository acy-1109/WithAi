-- HudView.lua
-- 점수·라이프. Model 을 읽기만 한다.
-- 5주차: "GAME OVER / YOU WIN" 문구는 결과 씬(ResultView)으로 옮겼다.

local HudView = {}

local NEON_COLOR = { 0.2, 1.0, 0.75 }
local BUFF_COLOR = { 0.95, 0.8, 0.35 }
local TRIPLE_COLOR = { 0.85, 0.5, 1.0 }
local BASE_FIRE_COOLDOWN = 0.25
local BOX_SIZE = 12
local BOX_GAP = 6

--- @param game      table      GameModel (읽기 전용: score, wave, lives, missiles, playerDamage, fireCooldown, tripleShotTimer)
--- @param highScore table|nil  HighScoreModel (읽기 전용: best)
function HudView.draw(gfx, game, width, height, highScore)
  local best = highScore and highScore.best or 0
  gfx.setColor(1, 0.9, 0.3)
  gfx.print("BEST " .. best, 10, 10)
  gfx.setColor(1, 1, 1)
  gfx.print("SCORE " .. game.score, 10, 28)

  local dmg = game.playerDamage or 1
  local cd = game.fireCooldown or BASE_FIRE_COOLDOWN
  local spdMul = BASE_FIRE_COOLDOWN / cd
  gfx.setColor(BUFF_COLOR[1], BUFF_COLOR[2], BUFF_COLOR[3])
  gfx.print(string.format("ATK %d  SPD %.2fx", dmg, spdMul), 10, 46)

  if (game.tripleShotTimer or 0) > 0 then
    gfx.setColor(TRIPLE_COLOR[1], TRIPLE_COLOR[2], TRIPLE_COLOR[3])
    gfx.print(string.format("TRIPLE %.1fs", game.tripleShotTimer), 10, 64)
  end

  gfx.setColor(1, 1, 1)
  gfx.printf("WAVE " .. (game.wave or 1), 0, 10, width, "center")
  gfx.print("LIVES " .. game.lives, width - 100, 10)

  local missiles = game.missiles or 0
  if missiles > 0 then
    local startX = width - 100
    local startY = 30
    gfx.setColor(NEON_COLOR[1], NEON_COLOR[2], NEON_COLOR[3])
    for i = 1, missiles do
      gfx.rectangle("fill", startX + (i - 1) * (BOX_SIZE + BOX_GAP), startY, BOX_SIZE, BOX_SIZE)
    end
  end
end

return HudView
