-- r3_enemy_factory_test.lua
-- R3(EnemyModel 상속 + 문자열 기반 Factory + 미등록 종류 에러) 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local EnemyModel = require("EnemyModel")
local GameModel = require("GameModel")
local BulletModel = require("BulletModel")

local function raises(fn, pattern)
  local ok, err = pcall(fn)
  return not ok and tostring(err):find(pattern, 1, true) ~= nil
end

h.test("R3: Factory 로 4종(grunt, tank, sprinter, sniper) 생성 및 상속 확인", function()
  local grunt = EnemyModel.create("grunt", 10, 20)
  local tank = EnemyModel.create("tank", 30, 40)
  local sprinter = EnemyModel.create("sprinter", 50, 60)
  local sniper = EnemyModel.create("sniper", 70, 80)

  return grunt.kind == "grunt" and grunt:isA(EnemyModel.Grunt) and grunt:isA(EnemyModel)
    and tank.kind == "tank" and tank:isA(EnemyModel.Tank) and tank:isA(EnemyModel)
    and sprinter.kind == "sprinter" and sprinter:isA(EnemyModel.Sprinter) and sprinter:isA(EnemyModel)
    and sniper.kind == "sniper" and sniper:isA(EnemyModel.Sniper) and sniper:isA(EnemyModel)
    and tank.x == 30 and tank.y == 40
    and tank:centerX() == 48 and tank:centerY() == 54
end)

h.test("R3: 각 적 타입 고유 스탯(Tank 고체력, Sprinter 고속, Sniper 원거리 특화)", function()
  local tank = EnemyModel.create("tank", 0, 0)
  local sprinter = EnemyModel.create("sprinter", 0, 0)
  local sniper = EnemyModel.create("sniper", 0, 0)

  local tankSurvivedOneHit = tank:takeDamage(1)
  local tankHpAfterOne = tank.hp
  local tankSurvivedThreeHits = tank:takeDamage(2)

  return tankSurvivedOneHit == true
    and tankHpAfterOne == 2
    and tankSurvivedThreeHits == false
    and tank.alive == false
    and sprinter.speedMul > 1.0
    and sniper.bulletSpeedMul > 1.0
    and sniper.fireCooldownMul < 1.0
end)

h.test("R3: 미등록 종류 또는 비문자열 전달 시 에러 발생", function()
  return raises(function()
    EnemyModel.create("unknown", 0, 0)
  end, "unknown enemy kind")
    and raises(function()
      EnemyModel.create("", 0, 0)
    end, "unknown enemy kind")
    and raises(function()
      EnemyModel.create(nil, 0, 0)
    end, "unknown enemy kind")
    and raises(function()
      EnemyModel.create(123, 0, 0)
    end, "unknown enemy kind")
end)

h.test("R3: GameModel 이 Factory 로 적을 스폰하고 Tank 다단 히트·점수를 반영한다", function()
  local text = "wave 1\nenemy tank 100 100\nenemy sprinter 200 100\nenemy sniper 300 100\n"
  local g = GameModel({ width = 600, height = 800, seed = 1, wavesText = text })
  local tank = g.enemies[1]
  local okSpawn = (#g.enemies == 3
    and tank:isA(EnemyModel.Tank)
    and g.enemies[2]:isA(EnemyModel.Sprinter)
    and g.enemies[3]:isA(EnemyModel.Sniper))

  -- Tank 1발 피격: 생존(hp 2), 점수 0
  g.bullets[1] = BulletModel(105, 105, 0, 0, 4, 12, "player")
  g:_resolveCollisions()
  local okHit1 = (tank.alive == true and tank.hp == 2 and g.score == 0)

  -- 추가 2발 피격: 격추(hp 0), 점수 300
  g.bullets[1] = BulletModel(105, 105, 0, 0, 4, 12, "player")
  g:_resolveCollisions()
  g.bullets[1] = BulletModel(105, 105, 0, 0, 4, 12, "player")
  g:_resolveCollisions()

  return okSpawn and okHit1 and tank.alive == false and g.score == 300
end)

h.test("R3: GameModel 에 미등록 적 종류가 들어오면 에러 발생", function()
  return raises(function()
    GameModel({ width = 600, height = 800, seed = 1, wavesText = "wave 1\nenemy ghost 50 50\n" })
  end, "unknown enemy kind")
end)

h.finish()

