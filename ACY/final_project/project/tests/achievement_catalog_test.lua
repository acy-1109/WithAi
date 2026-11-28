-- achievement_catalog_test.lua
-- 신규 6종 업적(노미사일 첫 보스, 회복 아이템 3/10회, 1만/3만/5만점)과 카테고리 정렬·GameModel 이벤트·직렬화 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local AchievementModel = require("AchievementModel")
local GameModel = require("GameModel")

h.test("카탈로그가 카테고리(전투->보스->생존->점수) 순으로 15개 정렬되어 있다", function()
  local ach = AchievementModel()
  local entries = ach:getCatalogEntries()
  local expected = {
    "first_blood",
    "streak_10",
    "run_kills_50",
    "total_kills_100",
    "trigger_happy",
    "flawless_wave",
    "boss_slayer",
    "boss_hunter_5",
    "pure_gunner",
    "field_medic",
    "nine_lives",
    "score_10k",
    "score_30k",
    "score_50k",
    "total_score_100k",
  }
  if #entries ~= #expected then
    return false
  end
  for i = 1, #expected do
    if entries[i].id ~= expected[i] then
      return false
    end
  end
  return true
end)

h.test("pure_gunner: 유도탄 미사용으로 첫 보스 처치 시 해금되고 일반 사격은 허용된다", function()
  local ach = AchievementModel()
  ach:onEvent({ type = "fire" })
  ach:onEvent({ type = "boss_appeared" })
  ach:onEvent({ type = "boss_destroyed", x = 300, y = 100 })
  return ach:isUnlocked("boss_slayer") and ach:isUnlocked("pure_gunner")
end)

h.test("pure_gunner: 유도탄을 1발이라도 썼거나 두 번째 보스에서만 조건을 만족하면 미해금", function()
  -- 1) 유도탄 사용 후 첫 보스 처치 -> 미해금
  local ach1 = AchievementModel()
  ach1:onEvent({ type = "missile_fired" })
  ach1:onEvent({ type = "boss_appeared" })
  ach1:onEvent({ type = "boss_destroyed", x = 300, y = 100 })
  if ach1:isUnlocked("pure_gunner") then
    return false
  end

  -- 2) 새 판(resetRun)에서 유도탄 없이 첫 보스 처치 시 정상 해금
  ach1:resetRun()
  ach1:onEvent({ type = "boss_appeared" })
  ach1:onEvent({ type = "boss_destroyed", x = 300, y = 100 })
  if not ach1:isUnlocked("pure_gunner") then
    return false
  end

  -- 3) 한 판에서 첫 보스에 유도탄을 쓴 뒤 두 번째 보스를 처치해도 첫 보스 전용이므로 미해금
  local ach2 = AchievementModel()
  ach2:onEvent({ type = "missile_fired" })
  ach2:onEvent({ type = "boss_appeared" })
  ach2:onEvent({ type = "boss_destroyed", x = 300, y = 100 })
  ach2:onEvent({ type = "boss_appeared" })
  ach2:onEvent({ type = "boss_destroyed", x = 300, y = 100 })
  return not ach2:isUnlocked("pure_gunner")
end)

h.test("회복 아이템 3회/10회 업적은 한 판 내 누적 기준이며 resetRun 시 카운터가 초기화된다", function()
  local ach = AchievementModel()
  for i = 1, 2 do
    ach:onEvent({ type = "item_collected", kind = "life" })
  end
  if ach:isUnlocked("field_medic") then
    return false
  end

  -- 다른 종류 아이템은 카운트되지 않음
  ach:onEvent({ type = "item_collected", kind = "shield" })
  if ach:isUnlocked("field_medic") then
    return false
  end

  -- 3회 도달 -> field_medic 해금
  ach:onEvent({ type = "item_collected", kind = "life" })
  if not ach:isUnlocked("field_medic") or ach:isUnlocked("nine_lives") then
    return false
  end

  -- 새 판 시작 시 카운터 초기화 -> 2회 더 먹어도 nine_lives(10회) 미해금
  ach:resetRun()
  for _ = 1, 9 do
    ach:onEvent({ type = "item_collected", kind = "life" })
  end
  if ach:isUnlocked("nine_lives") then
    return false
  end

  ach:onEvent({ type = "item_collected", kind = "life" })
  return ach:isUnlocked("nine_lives")
end)

h.test("점수 10000/30000/50000 돌파 경계값에 따라 업적이 순차 해금된다", function()
  local ach = AchievementModel()
  ach:onEvent({ type = "score_changed", score = 9999 })
  if ach:isUnlocked("score_10k") then
    return false
  end

  ach:onEvent({ type = "score_changed", score = 10000 })
  if not ach:isUnlocked("score_10k") or ach:isUnlocked("score_30k") then
    return false
  end

  ach:onEvent({ type = "score_changed", score = 29999 })
  if ach:isUnlocked("score_30k") then
    return false
  end

  ach:onEvent({ type = "score_changed", score = 30000 })
  if not ach:isUnlocked("score_30k") or ach:isUnlocked("score_50k") then
    return false
  end

  ach:onEvent({ type = "score_changed", score = 50000 })
  return ach:isUnlocked("score_50k")
end)

h.test("GameModel 이 유도탄 발사 시 missile_fired, 점수 증가 시 score_changed 이벤트를 발행한다", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g:update(0.016, { missile = true })
  g:addScore(10000)

  local evts = g:drainEvents()
  local sawFire, sawMissile, sawScore = false, false, false
  for i = 1, #evts do
    local e = evts[i]
    if e.type == "fire" then
      sawFire = true
    elseif e.type == "missile_fired" then
      sawMissile = true
    elseif e.type == "score_changed" and e.score == 10000 then
      sawScore = true
    end
  end
  return sawFire and sawMissile and sawScore
end)

h.test("신규 6종 업적도 직렬화·역직렬화 왕복이 유지된다", function()
  local ach = AchievementModel({
    "pure_gunner",
    "field_medic",
    "nine_lives",
    "score_10k",
    "score_30k",
    "score_50k",
  })
  local loaded = AchievementModel.deserialize(ach:serialize())
  return loaded:count() == 6
    and loaded:isUnlocked("pure_gunner")
    and loaded:isUnlocked("field_medic")
    and loaded:isUnlocked("nine_lives")
    and loaded:isUnlocked("score_10k")
    and loaded:isUnlocked("score_30k")
    and loaded:isUnlocked("score_50k")
end)

h.test("한판 킬 50킬(run_kills_50)과 누적 킬 100킬(total_kills_100) 구분이 동작한다", function()
  local ach = AchievementModel()
  -- 1판째: 49킬 -> run_kills_50 미해금
  for _ = 1, 49 do
    ach:onEvent({ type = "enemy_destroyed", x = 0, y = 0 })
  end
  if ach:isUnlocked("run_kills_50") or ach:isUnlocked("total_kills_100") then
    return false
  end

  -- 50킬 도달 -> run_kills_50 해금, totalKills=50
  ach:onEvent({ type = "enemy_destroyed", x = 0, y = 0 })
  if not ach:isUnlocked("run_kills_50") or ach.totalKills ~= 50 then
    return false
  end

  -- 직렬화/복구 + 새 판 시작 후 49킬 더 -> 누적 99킬이라 total_kills_100 미해금
  local loaded = AchievementModel.deserialize(ach:serialize())
  loaded:resetRun()
  for _ = 1, 49 do
    loaded:onEvent({ type = "enemy_destroyed", x = 0, y = 0 })
  end
  if loaded:isUnlocked("total_kills_100") or loaded.totalKills ~= 99 then
    return false
  end

  -- 100킬째 도달 -> total_kills_100 해금
  loaded:onEvent({ type = "enemy_destroyed", x = 0, y = 0 })
  return loaded:isUnlocked("total_kills_100") and loaded.totalKills == 100
end)

h.test("누적 보스 5회 처치(boss_hunter_5)가 여러 판을 거쳐 직렬화 후에도 해금된다", function()
  local ach = AchievementModel()
  for _ = 1, 4 do
    ach:resetRun()
    ach:onEvent({ type = "boss_appeared" })
    ach:onEvent({ type = "boss_destroyed", x = 0, y = 0 })
  end
  if ach:isUnlocked("boss_hunter_5") or ach.totalBosses ~= 4 then
    return false
  end

  local loaded = AchievementModel.deserialize(ach:serialize())
  loaded:resetRun()
  loaded:onEvent({ type = "boss_appeared" })
  loaded:onEvent({ type = "boss_destroyed", x = 0, y = 0 })
  return loaded:isUnlocked("boss_hunter_5") and loaded.totalBosses == 5
end)

h.test("누적 점수 10만점 돌파(total_score_100k)가 여러 판 점수를 합산해 해금된다", function()
  local ach = AchievementModel()
  ach:onEvent({ type = "score_changed", score = 45000, delta = 45000 })
  ach:resetRun()
  ach:onEvent({ type = "score_changed", score = 45000, delta = 45000 })
  if ach:isUnlocked("total_score_100k") or ach.totalScore ~= 90000 then
    return false
  end

  local loaded = AchievementModel.deserialize(ach:serialize())
  loaded:resetRun()
  loaded:onEvent({ type = "score_changed", score = 9999, delta = 9999 })
  if loaded:isUnlocked("total_score_100k") or loaded.totalScore ~= 99999 then
    return false
  end

  loaded:onEvent({ type = "score_changed", score = 10000, delta = 1 })
  return loaded:isUnlocked("total_score_100k") and loaded.totalScore == 100000
end)

h.finish()
