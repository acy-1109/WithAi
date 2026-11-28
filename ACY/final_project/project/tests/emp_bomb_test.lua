-- emp_bomb_test.lua
-- EMP 폭탄(bomb) 획득, 상한(3개), Q 키 에지 발동, 적 탄환 전량 소거, 적/보스 광역 피해, HUD/ItemView 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local GameModel = require("GameModel")
local ItemModel = require("ItemModel")
local BulletModel = require("BulletModel")
local BossPhase = require("BossPhase")
local InputController = require("InputController")
local ItemView = require("ItemView")
local HudView = require("HudView")

h.test("bomb: 시작 시 1개 기본 보유, 획득 시 증가 및 최대 3개 상한 초과 시 미획득", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  if g.player.bombs ~= 1 then
    return false
  end
  for i = 2, 3 do
    g.items[1] = ItemModel("bomb", g.player.x + 4, g.player.y - 1)
    g:update(0.016, {})
    if g.player.bombs ~= i or #g.items ~= 0 then
      return false
    end
  end

  -- 이미 3개 보유 시 통과
  g.items[1] = ItemModel("bomb", g.player.x + 4, g.player.y)
  g:update(0.016, {})
  return g.player.bombs == 3 and #g.items == 1
end)

h.test("InputController: Q 키를 누르고 있어도 상승 에지 1회만 bomb=true 로 전달된다", function()
  local qDown = false
  local ctrl = InputController(function(key)
    return key == "q" and qDown
  end)

  local firstBomb = ctrl:read().bomb
  if firstBomb then
    return false
  end

  qDown = true
  local pressedBomb = ctrl:read().bomb
  local heldBomb = ctrl:read().bomb
  qDown = false
  local releasedBomb = ctrl:read().bomb

  return pressedBomb == true and heldBomb == false and releasedBomb == false
end)

h.test("bomb: Q 발동 시 적 탄환 전량 소거, 일반 적 광역 피해, 보유 수 감소 및 이벤트 발행", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.player:addBomb()

  g.enemyBullets[1] = BulletModel(50, 50, 0, 100, 4, 12, "enemy")
  g.enemyBullets[2] = BulletModel(500, 700, 0, 100, 4, 12, "enemy")

  local e1 = g.enemies[1]
  e1.hp = 2
  local e2 = g.enemies[2]
  e2.hp = 8

  g:update(0.016, { bomb = true })
  local evts = g:drainEvents()
  local detonated = false
  for _, ev in ipairs(evts) do
    if ev.type == "emp_detonated" and ev.clearedBullets == 2 then
      detonated = true
    end
  end

  return g.player.bombs == 1
    and #g.enemyBullets == 0
    and not e1.alive
    and e2.alive and e2.hp == 3
    and detonated
end)

h.test("bomb: 보스전 중 발동 시 보스에게 광역 피해(5)를 입힌다", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.enemies = {}
  g:changePhase(BossPhase())
  local boss = g.boss
  local startHp = boss.hp

  g:update(0.016, { bomb = true })
  return boss.hp == startHp - 5 and g.player.bombs == 0
end)

h.test("ItemView / HudView: bomb 아이템 및 좌측 EMP 보유 수 표시가 모델을 변경하지 않는다", function()
  local itemGfx = h.fakeGfx()
  ItemView.draw(itemGfx, { ItemModel.create("bomb", 120, 120) })
  if h.count(itemGfx, "circle") ~= 4 then
    return false
  end

  local g = GameModel({ width = 600, height = 800, seed = 1 })
  local hudGfx = h.fakeGfx()
  local before = h.snapshot(g)
  HudView.draw(hudGfx, g, 600, 800)
  local after = h.snapshot(g)

  local hasEmpText = false
  for _, c in ipairs(hudGfx.calls) do
    if c.name == "print" and c.args[1] == "EMP 1/3 [Q]" and c.args[2] == 10 and c.args[3] == 82 then
      hasEmpText = true
      break
    end
  end
  return h.same(before, after) == true and hasEmpText
end)

h.finish()
