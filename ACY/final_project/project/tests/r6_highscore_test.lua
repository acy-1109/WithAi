-- r6_highscore_test.lua
-- R6(HighScoreModel 직렬화·역직렬화 + 깨진 문자열 기본값 복구 + ResultScene/View 연동) 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local HighScoreModel = require("HighScoreModel")
local TitleView = require("TitleView")
local HudView = require("HudView")

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

h.test("R6: TitleView 와 HudView 에 기존 하이스코어가 지정된 위치에 표시된다", function()
  local calls = {}
  local fakeGfx = {
    setColor = function() end,
    print = function(msg, x, y)
      calls[#calls + 1] = { msg = tostring(msg), x = x, y = y }
    end,
    printf = function(msg, x, y)
      calls[#calls + 1] = { msg = tostring(msg), x = x, y = y }
    end,
  }

  -- TitleView: 제목(0.35*800=280)과 가이드(0.5*800=400) 사이에 BEST 900 표시
  TitleView.draw(fakeGfx, 600, 800, 900)
  local titleBestOk = false
  for i = 1, #calls do
    local c = calls[i]
    if c.msg == "BEST 900" and c.y > 800 * 0.35 and c.y < 800 * 0.5 then
      titleBestOk = true
      break
    end
  end

  -- HudView: score(1500)가 best(900)를 넘어도 BEST 는 기존 900 유지, SCORE 는 한 칸 아래(y=28)
  calls = {}
  local hs = HighScoreModel(900)
  HudView.draw(fakeGfx, { score = 1500, wave = 2, lives = 3 }, 600, 800, hs)
  local hudBestOk, hudScoreOk = false, false
  for i = 1, #calls do
    local c = calls[i]
    if c.msg == "BEST 900" and c.x == 10 and c.y == 10 then
      hudBestOk = true
    elseif c.msg == "SCORE 1500" and c.x == 10 and c.y == 28 then
      hudScoreOk = true
    end
  end

  return titleBestOk and hudBestOk and hudScoreOk
end)

h.finish()
