-- item_model_test.lua
-- ItemModel(레지스트리 확장) 및 GameModel 아이템 드랍/이동/소멸/획득 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local GameModel = require("GameModel")
local ItemModel = require("ItemModel")

h.test("ItemModel: 수직 이동(140 px/s) 및 화면 밖 소멸 판정", function()
  local item = ItemModel.create("life", 100, 100)
  if item.vx ~= 0 or item.vy ~= 140 then
    return false
  end
  local startY = item.y
  item:update(0.5)
  if math.abs((item.y - startY) - 70) > 1e-6 then
    return false
  end
  if item:isOffscreen(600, 800) then
    return false
  end
  item.y = 801
  return item:isOffscreen(600, 800) == true
end)

h.test("GameModel: 적 처치 시 5% 확률(< 0.05)일 때만 아이템 드랍", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  local target = g.enemies[1]
  target.hp = 1

  -- 0.05 이상이면 드랍 안 됨
  g.rng.nextFloat = function()
    return 0.05
  end
  g.bullets[#g.bullets + 1] = { x = target.x + 2, y = target.y + 2, w = 4, h = 12, update = function() end, isOffscreen = function() return false end }
  g:update(0.016, {})
  if #g.items ~= 0 then
    return false
  end

  -- 0.05 미만이면 드랍됨
  local target2 = g.enemies[2]
  target2.hp = 1
  g.rng.nextFloat = function()
    return 0.049
  end
  g.bullets[#g.bullets + 1] = { x = target2.x + 2, y = target2.y + 2, w = 4, h = 12, update = function() end, isOffscreen = function() return false end }
  g:update(0.016, {})
  return #g.items == 1 and g.items[1].kind == "life"
end)

h.test("GameModel: HP가 MAX 미만이면 아이템 획득 시 라이프 +1 및 제거", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.lives = 2
  g.items[1] = ItemModel("life", g.player.x + 4, g.player.y - 1)
  g:update(0.016, {})
  local evts = g:drainEvents()
  local collected = false
  for _, e in ipairs(evts) do
    if e.type == "item_collected" and e.kind == "life" then
      collected = true
    end
  end
  return g.lives == 3 and #g.items == 0 and collected
end)

h.test("GameModel: HP가 이미 MAX면 아이템이 먹어지지 않고 통과", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.lives = g.maxLives
  g.items[1] = ItemModel("life", g.player.x + 4, g.player.y)
  g:update(0.016, {})
  return g.lives == g.maxLives and #g.items == 1
end)

h.test("GameModel: 아이템이 화면 밖으로 벗어나면 자동 제거", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.items[1] = ItemModel("life", 100, g.height - 1)
  g:update(0.1, {})
  return #g.items == 0
end)

h.test("ItemModel: registerType 으로 새 아이템 타입을 확장 가능", function()
  ItemModel.registerType("bonus_score", {
    w = 16,
    h = 16,
    speed = 140,
    canCollect = function()
      return true
    end,
    apply = function(game)
      game.score = game.score + 500
    end,
  })
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.items[1] = ItemModel("bonus_score", g.player.x + 4, g.player.y)
  g:update(0.016, {})
  return g.score == 500 and #g.items == 0
end)

h.finish()
