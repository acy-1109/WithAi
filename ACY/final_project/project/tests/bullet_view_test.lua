-- bullet_view_test.lua
-- BulletView(종류별 벡터 도형 렌더링, 진행 방향 회전, 원형 탄막, nil 가드) 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local GameModel = require("GameModel")
local BulletModel = require("BulletModel")
local BulletView = require("BulletView")
local GameView = require("GameView")

h.test("BulletView: 빈 목록이나 nil 이어도 오류 없이 아무것도 그리지 않는다", function()
  local gfx = h.fakeGfx()
  BulletView.draw(gfx, nil, nil)
  BulletView.draw(gfx, {}, {})
  return #gfx.calls == 0
end)

h.test("BulletView: 플레이어 일반탄과 미사일을 사각형 없이 다각형/원으로 구분해 그린다", function()
  local gfxPlayer = h.fakeGfx()
  local playerBullet = BulletModel(100, 200, 0, -450, 4, 12, "player")
  BulletView.draw(gfxPlayer, { playerBullet }, {})

  local gfxMissile = h.fakeGfx()
  local missile = BulletModel(100, 200, 120, -300, 6, 14, "missile")
  BulletView.draw(gfxMissile, { missile }, {})

  return h.count(gfxPlayer, "polygon") == 2
    and h.count(gfxPlayer, "rectangle") == 0
    and h.count(gfxPlayer, "rotate") == 0
    and h.count(gfxMissile, "polygon") == 2
    and h.count(gfxMissile, "circle") == 1
    and h.count(gfxMissile, "rotate") == 1
end)

h.test("BulletView: 정사각형 보스 탄막은 원형 오브로, 저격탄은 회전된 다각형 창날로 그린다", function()
  local gfxOrb = h.fakeGfx()
  local orb = BulletModel(200, 300, 80, 140, 6, 6, "enemy")
  BulletView.draw(gfxOrb, {}, { orb })

  local gfxSniper = h.fakeGfx()
  local sniper = BulletModel(200, 300, -100, 320, 6, 12, "enemy_sniper")
  BulletView.draw(gfxSniper, {}, { sniper })

  return h.count(gfxOrb, "circle") == 3
    and h.count(gfxOrb, "polygon") == 0
    and h.count(gfxSniper, "polygon") == 2
    and h.count(gfxSniper, "circle") == 1
    and h.count(gfxSniper, "rotate") == 1
end)

h.test("GameView:draw 는 탄환이 있어도 GameModel 을 전혀 변경하지 않는다", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.bullets[1] = BulletModel(100, 400, 0, -450, 4, 12, "player")
  g.bullets[2] = BulletModel(120, 400, 40, -320, 6, 14, "missile")
  g.enemyBullets[1] = BulletModel(200, 200, 0, 220, 6, 6, "enemy")
  g.enemyBullets[2] = BulletModel(240, 200, 80, 260, 6, 12, "enemy_sniper")

  local view = GameView({ width = 600, height = 800 })
  local gfx = h.fakeGfx()

  local before = h.snapshot(g)
  view:draw(gfx, g)
  local after = h.snapshot(g)

  return h.same(before, after) == true
end)

h.finish()

