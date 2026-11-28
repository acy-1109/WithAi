-- item_view_test.lua
-- ItemView(붉은 원형 + '+' 렌더링, kind별 확장) 및 GameView 비오염 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local GameModel = require("GameModel")
local ItemModel = require("ItemModel")
local ItemView = require("ItemView")
local GameView = require("GameView")

h.test("ItemView: life 아이템을 붉은 원형과 '+' 기호로 그린다", function()
  local gfx = h.fakeGfx()
  local items = { ItemModel.create("life", 200, 300) }
  ItemView.draw(gfx, items)

  local circleCount = h.count(gfx, "circle")
  local rectCount = h.count(gfx, "rectangle")
  local hasRedFill = false
  for _, c in ipairs(gfx.calls) do
    if c.name == "setColor" and c.args[1] and c.args[1] > 0.7 and (c.args[2] or 1) < 0.3 then
      hasRedFill = true
      break
    end
  end
  return circleCount == 2 and rectCount == 2 and hasRedFill
end)

h.test("GameView:draw 는 아이템이 있어도 GameModel 을 전혀 변경하지 않는다", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.items[1] = ItemModel.create("life", 250, 400)
  local view = GameView({ width = 600, height = 800 })
  local gfx = h.fakeGfx()

  local before = h.snapshot(g)
  view:draw(gfx, g)
  local after = h.snapshot(g)

  local ok = h.same(before, after)
  return ok == true and h.count(gfx, "circle") >= 2
end)

h.test("ItemView: registerDrawer 로 새 아이템 타입 렌더러를 확장할 수 있다", function()
  local called = false
  ItemView.registerDrawer("custom_test", function(gfx, item)
    called = true
    gfx.rectangle("fill", item.x, item.y, item.w, item.h)
  end)
  ItemModel.registerType("custom_test", { w = 12, h = 12, speed = 100 })
  local gfx = h.fakeGfx()
  ItemView.draw(gfx, { ItemModel.create("custom_test", 50, 60) })
  return called and h.count(gfx, "rectangle") == 1
end)

h.test("ItemView: attack_up, speed_up, triple_shot 아이템이 고유 아이콘으로 그려진다", function()
  local gfxAtk = h.fakeGfx()
  ItemView.draw(gfxAtk, { ItemModel.create("attack_up", 100, 100) })
  local okAtk = h.count(gfxAtk, "circle") == 2 and h.count(gfxAtk, "polygon") == 1 and h.count(gfxAtk, "rectangle") == 1

  local gfxSpd = h.fakeGfx()
  ItemView.draw(gfxSpd, { ItemModel.create("speed_up", 100, 100) })
  local okSpd = h.count(gfxSpd, "circle") == 2 and h.count(gfxSpd, "polygon") == 2

  local gfxTrp = h.fakeGfx()
  ItemView.draw(gfxTrp, { ItemModel.create("triple_shot", 100, 100) })
  local okTrp = h.count(gfxTrp, "circle") == 5

  return okAtk and okSpd and okTrp
end)

h.finish()
