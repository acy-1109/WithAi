-- boss_turret_test.lua
-- tier 1~3 포탑 미생성, tier 4(20웨이브+) 좌우 서브 포탑 생성·피격·파괴·보너스 500점·패턴 약화 검증.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local GameModel = require("GameModel")
local BulletModel = require("BulletModel")
local BossView = require("BossView")

local function enterBossWave(wave)
  local g = GameModel({ width = 600, height = 800, seed = 42 })
  g.enemies = {}
  g.wave = wave
  g:update(1 / 60, { move = 0, fire = false })
  g:drainEvents()
  return g
end

h.test("tier 1~3(5, 10, 15웨이브) 보스는 서브 포탑을 생성하지 않는다", function()
  for _, wave in ipairs({ 5, 10, 15 }) do
    local g = enterBossWave(wave)
    local boss = g.boss
    if not (boss and boss.turrets and #boss.turrets == 0) then
      return false
    end
  end
  return true
end)

h.test("tier 4(20웨이브) 보스는 HP 10 인 좌우 서브 포탑 2기를 본체 바깥에 분리 생성한다", function()
  local g = enterBossWave(20)
  local boss = g.boss
  if not (boss and boss.tier == 4 and boss.turrets and #boss.turrets == 2) then
    return false
  end
  local left, right = boss.turrets[1], boss.turrets[2]
  local lx, _, lw, _ = boss:getTurretRect(left)
  local rx, _, _, _ = boss:getTurretRect(right)
  local separated = (lx + lw <= boss.x) and (rx >= boss.x + boss.w)
  return separated
    and left.id == "left" and left.hp == 10 and left.maxHp == 10 and left.alive
    and right.id == "right" and right.hp == 10 and right.maxHp == 10 and right.alive
end)

h.test("포탑 명중 시 본체 HP는 유지되고 파괴 시 보너스 점수 500과 이벤트가 발행된다", function()
  local g = enterBossWave(20)
  local boss = g.boss
  local initialBossHp = boss.hp
  local left = boss.turrets[1]
  local tx, ty, tw, th = boss:getTurretRect(left)

  -- 포탑 중앙에 데미지 10 탄환 1발 명중
  g.bullets[#g.bullets + 1] = BulletModel(tx + tw * 0.5 - 2, ty + th * 0.5 - 2, 0, -520, 4, 12, "player", { damage = 10 })
  g.phase:resolveCollisions(g)

  if boss.hp ~= initialBossHp then
    return false
  end
  if left.alive or left.hp ~= 0 then
    return false
  end
  if g.score ~= 500 or #g.bullets ~= 0 then
    return false
  end

  local events = g:drainEvents()
  local sawDestroyed = false
  for _, ev in ipairs(events) do
    if ev.type == "boss_turret_destroyed" and ev.side == "left" then
      sawDestroyed = true
    end
  end
  return sawDestroyed
end)

h.test("왼쪽 포탑 파괴 시 PatrolState 원형 탄막 수가 약화된다(18->10, 광폭화 24->14)", function()
  local g = enterBossWave(20)
  local boss = g.boss
  local outBefore = {}
  boss.fireTimer = 0.01
  boss:update(0.02, g.width, outBefore, g.player)
  if #outBefore ~= 18 then
    return false
  end

  boss:damageTurret("left", 10)
  local outAfter = {}
  boss.fireTimer = 0.01
  boss:update(0.02, g.width, outAfter, g.player)
  if #outAfter ~= 10 then
    return false
  end

  boss.enraged = true
  local outEnraged = {}
  boss.fireTimer = 0.01
  boss:update(0.02, g.width, outEnraged, g.player)
  return #outEnraged == 14
end)

h.test("오른쪽 포탑 파괴 시 AimedState 조준 탄막 수가 약화된다(5->3, 광폭화 7->5)", function()
  local g = enterBossWave(20)
  local boss = g.boss
  boss.aiState = "aimed"
  -- AimedState 로 전환
  boss.stateTimer = 0.01
  boss:update(0.02, g.width, {}, g.player)
  if boss.aiState ~= "aimed" then
    return false
  end

  local outBefore = {}
  boss.fireTimer = 0.01
  boss:update(0.02, g.width, outBefore, g.player)
  if #outBefore ~= 5 then
    return false
  end

  boss:damageTurret("right", 10)
  local outAfter = {}
  boss.fireTimer = 0.01
  boss:update(0.02, g.width, outAfter, g.player)
  if #outAfter ~= 3 then
    return false
  end

  boss.enraged = true
  local outEnraged = {}
  boss.fireTimer = 0.01
  boss:update(0.02, g.width, outEnraged, g.player)
  return #outEnraged == 5
end)

h.test("살아있는 좌우 포탑은 독립적으로 탄환을 발사하고, 파괴된 포탑은 발사하지 않는다", function()
  local g = enterBossWave(20)
  local boss = g.boss
  -- 본체 발사를 막고 포탑 발사만 확인
  boss.fireTimer = 99
  boss.stateTimer = 99
  boss.turrets[1].fireTimer = 0.01
  boss.turrets[2].fireTimer = 0.01

  local out = {}
  boss:update(0.02, g.width, out, g.player)
  if #out ~= 2 then
    return false
  end

  -- 왼쪽 포탑 파괴 후에는 오른쪽 포탑에서만 1발 발사
  boss:damageTurret("left", 10)
  boss.turrets[2].fireTimer = 0.01
  local outAfter = {}
  boss:update(0.02, g.width, outAfter, g.player)
  if #outAfter ~= 1 then
    return false
  end
  local rx, _, rw, _ = boss:getTurretRect(boss.turrets[2])
  return math.abs((outAfter[1].x + 3) - (rx + rw * 0.5)) < 1e-6
end)

h.test("BossView: tier 4 포탑 생존/파손 상태를 그려도 모델을 변경하지 않는다", function()
  local g = enterBossWave(20)
  g.boss:damageTurret("left", 10)
  local gfx = h.fakeGfx()
  local before = h.snapshot(g.boss)
  BossView.draw(gfx, g.boss, 600)
  local after = h.snapshot(g.boss)
  return h.same(before, after) == true and h.count(gfx, "rectangle") == 4
end)

h.finish()

