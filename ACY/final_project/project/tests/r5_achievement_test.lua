-- r5_achievement_test.lua
-- R5(AchievementModel 이벤트 구독 + 중복 방지 + View 알림 렌더링) 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local AchievementModel = require("AchievementModel")
local BulletModel = require("BulletModel")
local SceneStack = require("SceneStack")

h.test("R5: 10연속 무피격 격추(streak_10) 리셋·해금·중복 방지", function()
  local ach = AchievementModel()

  -- 첫 격추 시 first_blood 해금, 9연속 격추 후 피격 → 리셋
  local first = ach:onEvent({ type = "enemy_destroyed", x = 0, y = 0 })
  if #first ~= 1 or first[1].id ~= "first_blood" then
    return false
  end
  for _ = 2, 9 do
    local newly = ach:onEvent({ type = "enemy_destroyed", x = 0, y = 0 })
    if #newly ~= 0 then
      return false
    end
  end
  ach:onEvent({ type = "player_hit" })
  if ach.streak ~= 0 or ach:isUnlocked("streak_10") then
    return false
  end

  -- 다시 10연속 격추 → 10번째에 streak_10 해금
  for i = 1, 10 do
    local newly = ach:onEvent({ type = "enemy_destroyed", x = 0, y = 0 })
    if i < 10 and #newly ~= 0 then
      return false
    end
    if i == 10 and (#newly ~= 1 or newly[1].id ~= "streak_10") then
      return false
    end
  end

  -- 추가 격추해도 중복 해금 안 됨
  local dup = ach:onEvent({ type = "enemy_destroyed", x = 0, y = 0 })
  return ach:isUnlocked("streak_10") and #dup == 0 and ach:count() == 2
end)

h.test("R5: 무피격 웨이브 클리어(flawless_wave) 실패 후 다음 웨이브에서 해금", function()
  local ach = AchievementModel()

  -- 1웨이브 피격 후 클리어 → 미해금 (waveHit 리셋)
  ach:onEvent({ type = "player_hit" })
  local fail = ach:onEvent({ type = "formation_cleared" })
  if #fail ~= 0 or ach:isUnlocked("flawless_wave") then
    return false
  end

  -- 2웨이브 무피격 클리어 → 해금
  local ok = ach:onEvent({ type = "formation_cleared" })
  if #ok ~= 1 or ok[1].id ~= "flawless_wave" then
    return false
  end

  -- 3웨이브 클리어 시 중복 해금 안 됨
  local dup = ach:onEvent({ type = "formation_cleared" })
  return ach:isUnlocked("flawless_wave") and #dup == 0 and ach:count() == 1
end)

h.test("R5: 보스 첫 처치(boss_slayer) 해금 및 중복 방지", function()
  local ach = AchievementModel()
  local first = ach:onEvent({ type = "boss_destroyed", x = 300, y = 100 })
  local second = ach:onEvent({ type = "boss_destroyed", x = 300, y = 100 })
  return #first == 1
    and first[1].id == "boss_slayer"
    and #second == 0
    and ach:isUnlocked("boss_slayer")
end)

h.test("R5: 사격 100회 누적(trigger_happy) 해금 및 중복 방지", function()
  local ach = AchievementModel()
  for i = 1, 99 do
    if #ach:onEvent({ type = "fire" }) ~= 0 then
      return false
    end
  end
  local at100 = ach:onEvent({ type = "fire" })
  local at101 = ach:onEvent({ type = "fire" })
  return #at100 == 1
    and at100[1].id == "trigger_happy"
    and #at101 == 0
    and ach:isUnlocked("trigger_happy")
end)

h.test("R5: PlayScene drainEvents 구독으로 GameModel 수정 없이 업적 해금 및 View 알림", function()
  local ctx = h.fakeCtx()
  local stack = SceneStack()
  local play = ctx.scenes.Play(ctx)
  stack:push(play)
  local g = play.game

  -- 1웨이브 적 전멸(피격 없음) → formation_cleared 발생 → flawless_wave 해금
  for i = 2, #g.enemies do
    g.enemies[i].alive = false
  end
  local target = g.enemies[1]
  target.entering = false
  target.x = target.entryTargetX
  target.y = target.entryTargetY
  target.hp = 1
  g.bullets[#g.bullets + 1] = BulletModel(target.x + 2, target.y + 2, 0, 0, 4, 12, "player")

  play:update(1 / 60)

  local printed = {}
  local fakeGfx = {
    push = function() end,
    pop = function() end,
    translate = function() end,
    setColor = function() end,
    rectangle = function() end,
    circle = function() end,
    polygon = function() end,
    print = function(msg) printed[#printed + 1] = tostring(msg) end,
    printf = function(msg) printed[#printed + 1] = tostring(msg) end,
  }
  play:draw(fakeGfx)

  local sawNotice = false
  for i = 1, #printed do
    if printed[i]:find("ACHIEVEMENT: ", 1, true) then
      sawNotice = true
      break
    end
  end

  return play.achievements:isUnlocked("first_blood")
    and play.achievements:isUnlocked("flawless_wave")
    and sawNotice
end)

h.finish()
