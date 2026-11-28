-- r7_weaver_enemy_test.lua
-- R7(새 적 종류 WeaverEnemy 추가) 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local EnemyModel = require("EnemyModel")
local EnemyView = require("EnemyView")
local GameModel = require("GameModel")

h.test("R7: Factory 로 weaver 생성 및 지그재그 이동 확인", function()
  local w = EnemyModel.create("weaver", 200, 100)
  local okType = (w.kind == "weaver" and w:isA(EnemyModel.Weaver) and w:isA(EnemyModel))

  local minX, maxX = w.x, w.x
  for _ = 1, 120 do
    w:updateAI(1 / 60)
    if w.x < minX then minX = w.x end
    if w.x > maxX then maxX = w.x end
  end

  return okType and minX < 200 and maxX > 200
end)

h.test("R7: GameModel 웨이브 파싱으로 weaver 스폰 및 EnemyView 렌더링", function()
  local g = GameModel({
    width = 600,
    height = 800,
    seed = 1,
    wavesText = "wave 1\nenemy weaver 180 115\n",
  })
  local w = g.enemies[1]

  local sawWeaverEdge = false
  local fakeGfx = {
    setColor = function(r, gCol, b)
      if r == 0.3 and gCol == 1.0 and b == 0.75 then
        sawWeaverEdge = true
      end
    end,
    polygon = function() end,
    circle = function() end,
    rectangle = function() end,
  }
  EnemyView.draw(fakeGfx, g.enemies)

  return #g.enemies == 1
    and w:isA(EnemyModel.Weaver)
    and sawWeaverEdge
end)

h.test("R7: weaver 경계 접촉 시 편대가 연속 하강(낙하)하지 않고 반전 이동한다", function()
  local g = GameModel({
    width = 600,
    height = 800,
    seed = 1,
    wavesText = "wave 1\nenemy weaver 545 60\n",
  })
  local w = g.enemies[1]
  local startY = w.y

  for _ = 1, 180 do
    g:update(1 / 60, { move = 0, fire = false })
  end

  -- 3초(180프레임) 동안 오른쪽 벽 1회 반전 수준(16~32px)만 하강해야 하며 화면 아래로 낙하하지 않아야 함
  return w.y >= startY and (w.y - startY) <= 32
end)

h.finish()
