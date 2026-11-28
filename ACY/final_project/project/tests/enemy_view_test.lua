-- enemy_view_test.lua
-- EnemyView(적 5종 네온 벡터 기체, 히트박스 경계, dead 스킵, sniper 조준 강조) 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local GameModel = require("GameModel")
local EnemyModel = require("EnemyModel")
local EnemyView = require("EnemyView")
local GameView = require("GameView")

local function allPolygonsInBounds(gfx, e)
  local eps = 1e-6
  for i = 1, #gfx.calls do
    local c = gfx.calls[i]
    if c.name == "polygon" then
      for j = 2, #c.args, 2 do
        local px = c.args[j]
        local py = c.args[j + 1]
        if px < e.x - eps or px > e.x + e.w + eps then
          return false
        end
        if py < e.y - eps or py > e.y + e.h + eps then
          return false
        end
      end
    end
  end
  return true
end

h.test("EnemyView: nil 이거나 죽은 적은 그리지 않는다", function()
  local gfx = h.fakeGfx()
  EnemyView.draw(gfx, nil)
  local dead = EnemyModel.create("grunt", 100, 100)
  dead.alive = false
  EnemyView.draw(gfx, { dead })
  return #gfx.calls == 0
end)

h.test("EnemyView: 적 5종 모두 히트박스 범위 내 벡터 도형으로 그려진다", function()
  local kinds = { "grunt", "tank", "sprinter", "sniper", "weaver" }
  for i = 1, #kinds do
    local gfx = h.fakeGfx()
    local e = EnemyModel.create(kinds[i], 120, 160)
    EnemyView.draw(gfx, { e })
    if h.count(gfx, "polygon") < 2 or h.count(gfx, "circle") < 1 then
      return false
    end
    if not allPolygonsInBounds(gfx, e) then
      return false
    end
    if kinds[i] ~= "tank" and h.count(gfx, "rectangle") ~= 0 then
      return false
    end
  end
  return true
end)

h.test("EnemyView: sniper 는 aim 상태에서 조준 코어 색상이 강조된다", function()
  local sniperWait = EnemyModel.create("sniper", 100, 100)
  sniperWait.aiState = "wait"
  local gfxWait = h.fakeGfx()
  EnemyView.draw(gfxWait, { sniperWait })

  local sniperAim = EnemyModel.create("sniper", 100, 100)
  sniperAim.aiState = "aim"
  local gfxAim = h.fakeGfx()
  EnemyView.draw(gfxAim, { sniperAim })

  local sawAimCore = false
  for _, c in ipairs(gfxAim.calls) do
    if c.name == "setColor" and c.args[1] == 1.0 and c.args[2] == 0.35 and c.args[3] == 0.75 then
      sawAimCore = true
      break
    end
  end
  local sawInWait = false
  for _, c in ipairs(gfxWait.calls) do
    if c.name == "setColor" and c.args[1] == 1.0 and c.args[2] == 0.35 and c.args[3] == 0.75 then
      sawInWait = true
      break
    end
  end
  return sawAimCore and not sawInWait
end)

h.test("GameView:draw 는 적 5종을 그려도 GameModel 을 전혀 변경하지 않는다", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.enemies = {
    EnemyModel.create("grunt", 50, 80),
    EnemyModel.create("tank", 110, 80),
    EnemyModel.create("sprinter", 170, 80),
    EnemyModel.create("sniper", 230, 80),
    EnemyModel.create("weaver", 290, 80),
  }
  local view = GameView({ width = 600, height = 800 })
  local gfx = h.fakeGfx()

  local before = h.snapshot(g)
  view:draw(gfx, g)
  local after = h.snapshot(g)

  return h.same(before, after) == true
end)

h.finish()

