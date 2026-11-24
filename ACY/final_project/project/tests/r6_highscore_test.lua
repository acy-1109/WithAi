-- r6_highscore_test.lua
-- R6(HighScoreModel 직렬화·역직렬화 + 깨진 문자열 기본값 복구 + ResultScene/View 연동) 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local HighScoreModel = require("HighScoreModel")

h.test("R6: 정상 직렬화 -> 역직렬화 왕복 및 최고점수 갱신", function()
  local hs = HighScoreModel(0)
  local changed1 = hs:submit(1500)
  local changed2 = hs:submit(800)
  local saved = hs:serialize()
  local loaded = HighScoreModel.deserialize(saved)

  return changed1 == true
    and changed2 == false
    and saved == "highscore=1500"
    and loaded.best == 1500
end)

h.test("R6: 깨진 파일 문자열 입력 시 죽지 않고 기본값(0)으로 복구", function()
  local cases = {
    nil,
    "",
    "   \n  ",
    "highscore=abc",
    "highscore=-999",
    "corrupted\0binary!@#",
    "score=1200",
    "highscore=100\nextra=200",
  }

  for i = 1, #cases do
    local ok, res = pcall(HighScoreModel.deserialize, cases[i])
    if not ok or res.best ~= 0 then
      return false
    end
  end
  return true
end)

h.test("R6: ResultScene 에서 신기록 갱신 시 ctx.saveHighScore 호출 및 ResultView 표시", function()
  local ctx = h.fakeCtx()
  local savedCount = 0
  ctx.highScore = HighScoreModel.deserialize("highscore=500")
  ctx.saveHighScore = function()
    savedCount = savedCount + 1
  end

  local res1 = ctx.scenes.Result(ctx, { state = "gameover", score = 300 })
  local res2 = ctx.scenes.Result(ctx, { state = "won", score = 1200 })

  local printed = {}
  local fakeGfx = {
    setColor = function() end,
    rectangle = function() end,
    printf = function(msg) printed[#printed + 1] = tostring(msg) end,
  }
  res2:draw(fakeGfx)

  local sawNewBest = false
  for i = 1, #printed do
    if printed[i]:find("NEW BEST! 1200", 1, true) then
      sawNewBest = true
      break
    end
  end

  return savedCount == 1
    and res1.isNewBest == false
    and res2.isNewBest == true
    and ctx.highScore.best == 1200
    and sawNewBest
end)

h.finish()
