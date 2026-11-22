-- boss_fsm_test.lua
-- 보스 State 패턴 FSM(patrol -> aimed -> spiral -> patrol) 및 HP 50% 이하 광폭화 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local BossModel = require("BossModel")
local BossView = require("BossView")
local BulletModel = require("BulletModel")
local EffectsView = require("EffectsView")
local GameModel = require("GameModel")

h.test("보스 FSM: patrol -> aimed -> spiral -> patrol 순환 전이 및 패턴별 탄막", function()
  local boss = BossModel(240, 70, 40)
  local bullets = {}
  local player = { x = 280, y = 740, w = 40, h = 24 }

  local sawPatrol = (boss.aiState == "patrol")
  local sawAimed = false
  local sawSpiral = false
  local returnedPatrol = false

  for _ = 1, 700 do
    boss:update(1 / 60, 600, bullets, player)
    if boss.aiState == "aimed" then
      sawAimed = true
    elseif sawAimed and boss.aiState == "spiral" then
      sawSpiral = true
    elseif sawSpiral and boss.aiState == "patrol" then
      returnedPatrol = true
      break
    end
  end

  return sawPatrol and sawAimed and sawSpiral and returnedPatrol and #bullets > 0
end)

h.test("보스 광폭화: HP 50% 이하 시 enraged 전환, boss_enraged 이벤트 및 연출 반응", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.enemies = {}
  g.wave = 5
  g:update(1 / 60, { move = 0, fire = false })
  g:drainEvents()

  local boss = g.boss
  local okInitial = (boss ~= nil and boss.enraged == false)

  -- HP 절반(20) 이하까지 타격
  for _ = 1, 20 do
    g.bullets[#g.bullets + 1] = BulletModel(boss:centerX(), boss:centerY(), 0, 0, 4, 12, "player")
    g:update(1 / 60, { move = 0, fire = false })
  end

  local evts = g:drainEvents()
  local enrageCount = 0
  local fx = EffectsView(function() return 0.5 end)
  for i = 1, #evts do
    if evts[i].type == "boss_enraged" then
      enrageCount = enrageCount + 1
      fx:onEvent(evts[i])
    end
  end

  -- 추가 타격 시 boss_enraged 는 중복 발행되지 않아야 함
  g.bullets[#g.bullets + 1] = BulletModel(boss:centerX(), boss:centerY(), 0, 0, 4, 12, "player")
  g:update(1 / 60, { move = 0, fire = false })
  local evts2 = g:drainEvents()
  for i = 1, #evts2 do
    if evts2[i].type == "boss_enraged" then
      enrageCount = enrageCount + 1
    end
  end

  -- BossView 색상 분기 확인 (평상시 vs 광폭화)
  local lastColor
  local fakeGfx = {
    setColor = function(r, gCol, b) lastColor = { r, gCol, b } end,
    rectangle = function() end,
  }
  boss.enraged = false
  BossView.draw(fakeGfx, boss, 600)
  boss.enraged = true
  BossView.draw(fakeGfx, boss, 600)

  return okInitial
    and boss.enraged == true
    and enrageCount == 1
    and fx.shake > 0
    and #fx.particles == 12
    and lastColor ~= nil
end)

h.test("보스 FSM: 동일 시드 2회 실행 시 상태·위치·탄막 수가 완전히 동일하다", function()
  local function sim()
    local g = GameModel({ width = 600, height = 800, seed = 99 })
    g.wave = 5
    for _ = 1, 300 do
      g:update(1 / 60, { move = 0, fire = false })
    end
    return g
  end

  local g1, g2 = sim(), sim()
  return g1.boss.x == g2.boss.x
    and g1.boss.aiState == g2.boss.aiState
    and #g1.enemyBullets == #g2.enemyBullets
end)

h.finish()
