-- achievement_overlay_test.lua
-- 업적 마스킹/직렬화(Model), 타이틀 버튼/모달 오버레이/스크롤/닫기(Scene/View) 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local AchievementModel = require("AchievementModel")
local AchievementScene = require("AchievementScene")
local AchievementView = require("AchievementView")
local BulletModel = require("BulletModel")
local SceneStack = require("SceneStack")
local TitleView = require("TitleView")

local function newTitleApp(achievements)
  local ctx = h.fakeCtx()
  ctx.achievements = achievements or AchievementModel()
  ctx.scenes.Achievements = AchievementScene
  local stack = SceneStack()
  stack:push(ctx.scenes.Title(ctx))
  return stack, ctx
end

local function hasPrinted(gfx, needle)
  for i = 1, #gfx.calls do
    local c = gfx.calls[i]
    if (c.name == "print" or c.name == "printf") and tostring(c.args[1]):find(needle, 1, true) then
      return true
    end
  end
  return false
end

h.test("0개 달성 시 전체 업적 목록의 이름은 ???, 조건은 ??????? 로 마스킹된다", function()
  local ach = AchievementModel()
  local entries = ach:getCatalogEntries()
  if #entries ~= ach:totalCount() or #entries == 0 then
    return false
  end
  for i = 1, #entries do
    if entries[i].unlocked ~= false or entries[i].title ~= "???" or entries[i].desc ~= "???????" then
      return false
    end
  end
  return true
end)

h.test("달성한 업적만 이름과 조건이 표시되고 미달성 업적은 ??? / ??????? 로 유지된다", function()
  local ach = AchievementModel()
  ach:onEvent({ type = "enemy_destroyed", x = 0, y = 0 })

  local entries = ach:getCatalogEntries()
  local sawUnlocked, sawLocked = false, false
  for i = 1, #entries do
    local e = entries[i]
    if e.id == "first_blood" then
      if not e.unlocked or e.title ~= "FIRST BLOOD" or e.desc == "???????" or e.desc == "" then
        return false
      end
      sawUnlocked = true
    else
      if e.unlocked or e.title ~= "???" or e.desc ~= "???????" then
        return false
      end
      sawLocked = true
    end
  end
  return sawUnlocked and sawLocked
end)

h.test("직렬화·역직렬화 왕복과 깨진 입력 복구 및 resetRun 카운터 초기화가 동작한다", function()
  local ach = AchievementModel()
  ach:onEvent({ type = "enemy_destroyed", x = 0, y = 0 })
  ach:onEvent({ type = "boss_destroyed", x = 0, y = 0 })
  local saved = ach:serialize()

  local loaded = AchievementModel.deserialize(saved)
  if not loaded:isUnlocked("first_blood") or not loaded:isUnlocked("boss_slayer") or loaded:count() ~= 2 then
    return false
  end

  loaded:onEvent({ type = "fire" })
  loaded:resetRun()
  if loaded.streak ~= 0 or loaded.shots ~= 0 or loaded.waveHit ~= false or loaded:count() ~= 2 then
    return false
  end

  local broken = { nil, "", "invalid=1", "achievements=unknown_id,first_blood,??" }
  for i = 1, #broken do
    local ok, res = pcall(AchievementModel.deserialize, broken[i])
    if not ok or not res then
      return false
    end
  end
  local partial = AchievementModel.deserialize("achievements=unknown_id,first_blood")
  return partial:count() == 1 and partial:isUnlocked("first_blood")
end)

h.test("타이틀에서 업적 버튼 클릭 시 오버레이가 열리고 바깥 클릭은 무시된다", function()
  local stack, ctx = newTitleApp()
  local btn = TitleView.getAchievementButtonRect(ctx.width, ctx.height)

  -- 버튼 바깥 클릭
  stack:mousepressed(10, 10, 1)
  if stack:size() ~= 1 then
    return false
  end

  -- 버튼 내부 클릭
  stack:mousepressed(btn.x + btn.w * 0.5, btn.y + btn.h * 0.5, 1)
  return stack:size() == 2 and stack:top().transparent == true
end)

h.test("업적 오버레이에서 마우스 휠과 스크롤바 드래그가 상·하단 경계 내로 동작한다", function()
  local stack, ctx = newTitleApp()
  local btn = TitleView.getAchievementButtonRect(ctx.width, ctx.height)
  stack:mousepressed(btn.x + 10, btn.y + 10, 1)

  local overlay = stack:top()
  local layout = AchievementView.getLayout(ctx.width, ctx.height)
  local metrics = AchievementView.getScrollMetrics(layout, #overlay.entries, 0)
  if metrics.maxScroll <= 0 then
    return false
  end

  -- 위로 올려도 0 미만 불가
  stack:wheelmoved(0, 5)
  if overlay.scrollOffset ~= 0 then
    return false
  end

  -- 아래로 크게 내려도 maxScroll 초과 불가
  stack:wheelmoved(0, -100)
  if overlay.scrollOffset ~= metrics.maxScroll then
    return false
  end

  -- 썸을 위로 드래그하면 다시 0으로 이동
  local topMetrics = AchievementView.getScrollMetrics(layout, #overlay.entries, overlay.scrollOffset)
  stack:mousepressed(layout.track.x + 4, topMetrics.thumbY + 4, 1)
  stack:mousemoved(layout.track.x + 4, topMetrics.thumbY - 500, 0, -500)
  stack:mousereleased(layout.track.x + 4, topMetrics.thumbY - 500, 1)
  return overlay.scrollOffset == 0 and overlay.dragging == false
end)

h.test("업적 오버레이는 닫기 버튼 클릭 또는 Esc 로만 닫히고 다른 키는 무시한다", function()
  local stack, ctx = newTitleApp()
  local btn = TitleView.getAchievementButtonRect(ctx.width, ctx.height)
  local layout = AchievementView.getLayout(ctx.width, ctx.height)

  -- 열기 -> Enter 무시 -> 닫기 버튼 클릭
  stack:mousepressed(btn.x + 10, btn.y + 10, 1)
  stack:keypressed("return")
  if stack:size() ~= 2 then
    return false
  end
  stack:mousepressed(layout.closeBtn.x + 10, layout.closeBtn.y + 10, 1)
  if stack:size() ~= 1 then
    return false
  end

  -- 다시 열기 -> Esc 로 닫기
  stack:mousepressed(btn.x + 10, btn.y + 10, 1)
  stack:keypressed("escape")
  return stack:size() == 1
end)

h.test("AchievementView.draw 가 달성·미달성 텍스트를 올바르게 그리고 데이터를 변조하지 않는다", function()
  local ach = AchievementModel({ "first_blood" })
  local entries = ach:getCatalogEntries()
  local before = h.snapshot(entries)
  local gfx = h.fakeGfx()

  AchievementView.draw(gfx, 600, 800, entries, 0, { closeHovered = true })

  return h.same(before, h.snapshot(entries))
    and hasPrinted(gfx, "FIRST BLOOD")
    and hasPrinted(gfx, "Destroy your first enemy.")
    and hasPrinted(gfx, "???")
    and hasPrinted(gfx, "???????")
    and hasPrinted(gfx, "CLOSE")
end)

h.test("PlayScene 에서 업적 해금 시 ctx.saveAchievements 가 호출되어 영구 저장된다", function()
  local ach = AchievementModel()
  local savedCount = 0
  local ctx = h.fakeCtx()
  ctx.achievements = ach
  ctx.saveAchievements = function()
    savedCount = savedCount + 1
  end

  local stack = SceneStack()
  local play = ctx.scenes.Play(ctx)
  stack:push(play)

  local g = play.game
  local target = g.enemies[1]
  target.hp = 1
  g.bullets[#g.bullets + 1] = BulletModel(target.x + 2, target.y + 2, 0, 0, 4, 12, "player")
  play:update(1 / 60)

  return savedCount >= 1 and ach:isUnlocked("first_blood")
end)

h.finish()

