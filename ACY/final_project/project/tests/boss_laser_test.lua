-- boss_laser_test.lua
-- 보스 tier 1(5웨이브) 기존 패턴 유지, tier 2(15웨이브+) 레이저 차징/발사 FSM, 피격 판정 및 렌더링 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local BossModel = require("BossModel")
local BossView = require("BossView")
local GameModel = require("GameModel")

h.test("tier 1 보스는 레이저 상태로 전이하지 않고 기존 3상태만 순환", function()
  local boss = BossModel(240, 70, 40, 1)
  local bullets = {}
  local player = { x = 280, y = 740, w = 40, h = 24 }

  local sawLaser = false
  local sawSpiral = false
  local returnedPatrol = false

  for _ = 1, 700 do
    boss:update(1 / 60, 600, bullets, player)
    if boss.aiState == "laser_charge" or boss.aiState == "laser" then
      sawLaser = true
    elseif boss.aiState == "spiral" then
      sawSpiral = true
    elseif sawSpiral and boss.aiState == "patrol" then
      returnedPatrol = true
      break
    end
  end

  return (not sawLaser) and sawSpiral and returnedPatrol
end)

h.test("tier 2 보스는 spiral -> laser_charge -> laser -> patrol 전이 및 느린 이동", function()
  local boss = BossModel(240, 70, 60, 2)
  local bullets = {}
  local player = { x = 280, y = 740, w = 40, h = 24 }

  local sawCharge = false
  local sawLaser = false
  local returnedPatrol = false
  local chargeStartX, chargeEndX
  local laserStartX, laserEndX

  for _ = 1, 1000 do
    boss:update(1 / 60, 600, bullets, player)
    if boss.aiState == "laser_charge" then
      if not sawCharge then
        sawCharge = true
        chargeStartX = boss.x
      end
      chargeEndX = boss.x
    elseif sawCharge and boss.aiState == "laser" then
      if not sawLaser then
        sawLaser = true
        laserStartX = boss.x
      end
      laserEndX = boss.x
    elseif sawLaser and boss.aiState == "patrol" then
      returnedPatrol = true
      break
    end
  end

  local movedDuringCharge = chargeStartX ~= nil and chargeEndX ~= nil and chargeEndX ~= chargeStartX
  local movedDuringLaser = laserStartX ~= nil and laserEndX ~= nil and laserEndX ~= laserStartX

  return sawCharge and sawLaser and returnedPatrol and movedDuringCharge and movedDuringLaser
end)

h.test("10웨이브 보스 레이저 피격 판정 및 1회 발사당 중복 피격 방지", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.enemies = {}
  g.wave = 10
  g:update(1 / 60, { move = 0, fire = false })
  g:drainEvents()

  local boss = g.boss
  if not (boss and boss.tier == 2) then
    return false
  end

  -- 레이저 발사 상태까지 진행 (대기 중 일반 탄막으로 인한 게임오버 방지)
  for _ = 1, 800 do
    g.player.invincibleTimer = 1
    g.enemyBullets = {}
    g:update(1 / 60, { move = 0, fire = false })
    if boss.aiState == "laser" then
      break
    end
  end
  if boss.aiState ~= "laser" then
    return false
  end

  -- 플레이어를 보스 레이저 바로 아래로 이동
  local startLives = g.lives
  g.player.x = boss:centerX() - g.player.w * 0.5
  g.player.invincibleTimer = 0
  g.player.hasShield = false

  g:update(1 / 60, { move = 0, fire = false })
  local hitOnce = (g.lives == startLives - 1) and (boss.laserHit == true)

  -- 같은 레이저 발사 중 무적이 풀려도 중복 피격되지 않아야 함
  g.player.invincibleTimer = 0
  g:update(1 / 60, { move = 0, fire = false })
  local noDoubleHit = (g.lives == startLives - 1)

  return hitOnce and noDoubleHit
end)

h.test("BossView: laser_charge 및 laser 상태 렌더링", function()
  local boss = BossModel(240, 70, 60, 2)
  local lineCalls = 0
  local rectCalls = 0
  local fakeGfx = {
    setColor = function() end,
    polygon = function() end,
    circle = function() end,
    rectangle = function() rectCalls = rectCalls + 1 end,
    line = function() lineCalls = lineCalls + 1 end,
  }

  boss.aiState = "laser_charge"
  boss.chargeTimer = 0.5
  BossView.draw(fakeGfx, boss, 600)
  local drewChargeLine = lineCalls >= 1

  local rectsBefore = rectCalls
  boss.aiState = "laser"
  boss.laserTimer = 0.4
  BossView.draw(fakeGfx, boss, 600)
  local drewLaserBeam = (rectCalls - rectsBefore) >= 2

  return drewChargeLine and drewLaserBeam
end)

h.test("디버그 치트 F1(debugClearPhase): 편대전 및 보스전 즉시 클리어", function()
  local PlayScene = require("PlayScene")
  local scene = PlayScene({
    width = 600,
    height = 800,
    seed = function() return 1 end,
    isDown = function() return false end,
    rand = function() return 0.5 end,
  })
  local g = scene.game

  -- 1~4웨이브 편대전 F1 클리어 → 5웨이브 도달
  for expected = 2, 5 do
    scene:keypressed("f1")
    if g.wave ~= expected or g.phase.name ~= "formation" then
      return false
    end
  end

  -- 5웨이브 편대전 F1 클리어 → 1차 보스(tier 1) 등장
  scene:keypressed("f1")
  if g.phase.name ~= "boss" or not g.boss or g.boss.tier ~= 1 then
    return false
  end

  -- 1차 보스 F1 클리어 → 6웨이브 편대전 복귀
  scene:keypressed("f1")
  if g.phase.name ~= "formation" or g.boss ~= nil or g.wave ~= 6 then
    return false
  end

  -- 6~10웨이브 F1 클리어 → 10웨이브 2차 보스(tier 2) 등장
  for _ = 1, 5 do
    scene:keypressed("f1")
  end
  return g.phase.name == "boss" and g.boss ~= nil and g.boss.tier == 2 and g.wave == 10
end)

h.finish()
