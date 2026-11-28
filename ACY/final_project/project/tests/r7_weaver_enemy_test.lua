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
  while w.entering do
    g:update(1 / 60, { move = 0, fire = false })
  end
  local startY = w.y

  for _ = 1, 180 do
    g:update(1 / 60, { move = 0, fire = false })
  end

  -- 3초(180프레임) 동안 오른쪽 벽 1회 반전 수준(16~32px)만 하강해야 하며 화면 아래로 낙하하지 않아야 함
  return w.y >= startY and (w.y - startY) <= 32
end)

h.test("R7: weaver 상태 전이(wait->charge->laser->wait) 및 차징 이동 유지·레이저 발사 정지", function()
  local w = EnemyModel.create("weaver", 200, 100)
  if w.aiState ~= "wait" then
    return false
  end

  -- 3.5초 대기 후 charge 진입
  for _ = 1, 211 do
    w:updateAI(1 / 60)
  end
  if w.aiState ~= "charge" then
    return false
  end

  -- charge 중에는 지그재그 이동 유지
  local chargeX0 = w.x
  for _ = 1, 30 do
    w:updateAI(1 / 60)
  end
  local movedInCharge = (w.x ~= chargeX0)
  if not movedInCharge or w.aiState ~= "charge" then
    return false
  end

  -- 나머지 0.5초 경과 후 laser 진입
  for _ = 1, 31 do
    w:updateAI(1 / 60)
  end
  if w.aiState ~= "laser" or w:inFormation() ~= false then
    return false
  end

  -- laser 중에는 이동 정지
  local laserX0 = w.x
  for _ = 1, 15 do
    w:updateAI(1 / 60)
  end
  if w.x ~= laserX0 or w.aiState ~= "laser" then
    return false
  end

  -- 0.6초 레이저 종료 후 wait 복귀
  for _ = 1, 25 do
    w:updateAI(1 / 60)
  end
  return w.aiState == "wait" and w:inFormation() == true
end)

h.test("R7: weaver 는 일반 탄환을 쏘지 않고 차징 후 레이저로 플레이어를 1회 피격한다", function()
  local g = GameModel({
    width = 600,
    height = 800,
    seed = 7,
    wavesText = "wave 1\nenemy weaver 280 100\n",
  })
  local w = g.enemies[1]
  -- 편대 이동을 0으로 두고 플레이어를 레이저 경로에 배치
  g.formationDir = 0
  g.player.x = w:centerX() - g.player.w * 0.5
  local startLives = g.lives

  local sawCharge = false
  local sawLaser = false
  local hitEvents = 0
  for _ = 1, 320 do
    g:update(1 / 60, { move = 0, fire = false })
    if w.aiState == "charge" then
      sawCharge = true
      g.player.x = w:centerX() - g.player.w * 0.5
    elseif w.aiState == "laser" then
      sawLaser = true
    end
    local evts = g:drainEvents()
    for i = 1, #evts do
      if evts[i].type == "player_hit" then
        hitEvents = hitEvents + 1
      end
    end
  end

  return sawCharge and sawLaser and #g.enemyBullets == 0 and hitEvents == 1 and g.lives == startLives - 1
end)

h.test("R7: EnemyView 가 weaver 의 charge 및 laser 연출을 그린다", function()
  local w = EnemyModel.create("weaver", 200, 100)
  w.aiState = "charge"
  w.chargeTimer = 0.5

  local gfxCharge = h.fakeGfx()
  EnemyView.draw(gfxCharge, { w })
  if h.count(gfxCharge, "line") < 1 or h.count(gfxCharge, "circle") < 4 then
    return false
  end

  w.aiState = "laser"
  local gfxLaser = h.fakeGfx()
  EnemyView.draw(gfxLaser, { w })
  return h.count(gfxLaser, "rectangle") >= 2
end)

h.finish()
