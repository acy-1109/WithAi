-- r2_wave_parser_test.lua
-- R2(웨이브 데이터 파서 + GameModel 연동) 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local WaveParser = require("WaveParser")
local GameModel = require("GameModel")
local HudView = require("HudView")

local function raises(fn, pattern)
  local ok, err = pcall(fn)
  return not ok and tostring(err):find(pattern, 1, true) ~= nil
end

h.test("R2: 정상 다중 웨이브 파싱", function()
  local waves = WaveParser.parse([[
wave 1
enemy grunt 60 60
enemy grunt 120 60
wave 2
enemy diver 100 80
]])
  return #waves == 2
    and #waves[1].enemies == 2
    and waves[1].enemies[1].kind == "grunt"
    and waves[1].enemies[1].x == 60
    and waves[1].enemies[2].x == 120
    and #waves[2].enemies == 1
    and waves[2].enemies[1].kind == "diver"
end)

h.test("R2: 경계 — 주석(#), 빈 줄, 앞뒤 공백, CRLF 허용", function()
  local text = "# comment\r\n\r\n   # indented\r\n  wave   1  \r\n  enemy  grunt   40   50  \r\n"
  local waves = WaveParser.parse(text)
  return #waves == 1 and waves[1].id == 1 and waves[1].enemies[1].x == 40 and waves[1].enemies[1].y == 50
end)

h.test("R2: 오류 — 잘못된 좌표(숫자 아님) 시 줄 번호 포함 에러", function()
  local text = "wave 1\nenemy grunt 60 60\nenemy grunt 120 abc\n"
  return raises(function()
    WaveParser.parse(text)
  end, "line 3:")
end)

h.test("R2: 오류 — 토큰 부족 또는 알 수 없는 명령 시 줄 번호 포함 에러", function()
  local text1 = "wave 1\nenemy grunt 60\n"
  local text2 = "wave 1\nunknown_cmd 1 2\n"
  return raises(function() WaveParser.parse(text1) end, "line 2:")
    and raises(function() WaveParser.parse(text2) end, "line 2:")
end)

h.test("R2: 오류 — wave 선언 전에 enemy 등장 시 줄 번호 포함 에러", function()
  local text = "# header\nenemy grunt 60 60\n"
  return raises(function()
    WaveParser.parse(text)
  end, "line 2:")
end)

h.test("R2: GameModel 이 wavesText 를 파싱해 웨이브별 적을 생성한다", function()
  local text = "wave 1\nenemy grunt 60 60\nwave 2\nenemy grunt 200 90\n"
  local g = GameModel({ width = 600, height = 800, seed = 1, wavesText = text })
  local ok1 = (#g.enemies == 1 and g.enemies[1].x == 60 and g.enemies[1].y == 60)
  g.enemies[1].alive = false
  g.phase:afterStep(g)
  local ok2 = (#g.enemies == 1 and g.enemies[1].x == 200 and g.enemies[1].y == 90)
  return ok1 and ok2
end)

h.test("웨이브: 1~4웨이브 동안 편대전 유지 후 5웨이브부터 보스전 전환 및 HUD WAVE 표시", function()
  local text = "wave 1\nenemy grunt 100 100\nwave 2\nenemy tank 200 100\n"
  local g = GameModel({ width = 600, height = 800, seed = 1, wavesText = text })

  -- 초기 wave == 1, score가 높아도 5웨이브 전엔 보스 등장 안 함
  g.score = 5000
  g:update(1 / 60, { move = 0, fire = false })
  if g.wave ~= 1 or g.phase.name ~= "formation" or g.boss ~= nil then
    return false
  end

  -- 1~4웨이브 전멸을 거쳐 5웨이브 도달
  for expectedWave = 2, 5 do
    for _, e in ipairs(g.enemies) do
      e.alive = false
    end
    g:update(1 / 60, { move = 0, fire = false })
    if g.wave ~= expectedWave then
      return false
    end
    if expectedWave < 5 and g.phase.name ~= "formation" then
      return false
    end
  end

  -- 5웨이브 업데이트 시 BossPhase 전환 확인
  g:update(1 / 60, { move = 0, fire = false })
  local okBoss = (g.phase.name == "boss" and g.boss ~= nil)

  -- HudView 에 "WAVE 5" 표시 확인
  local printed = {}
  local fakeGfx = {
    setColor = function() end,
    print = function(msg) printed[#printed + 1] = tostring(msg) end,
    printf = function(msg) printed[#printed + 1] = tostring(msg) end,
  }
  HudView.draw(fakeGfx, g, 600, 800)
  local sawWaveHud = false
  for i = 1, #printed do
    if printed[i] == "WAVE 5" then
      sawWaveHud = true
      break
    end
  end

  return okBoss and sawWaveHud
end)

h.finish()

