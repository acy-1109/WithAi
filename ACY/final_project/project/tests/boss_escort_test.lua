-- boss_escort_test.lua
-- tier 1·2 미소환, tier 3(15웨이브+) enraged 진입 시 호위 적 소환(동일 2체 + 다른 1체), 중복 방지, 보스 격파 후 유지 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local GameModel = require("GameModel")

local function enterBossWave(wave)
  local g = GameModel({ width = 600, height = 800, seed = 42 })
  g.enemies = {}
  g.wave = wave
  g:update(1 / 60, { move = 0, fire = false })
  g:drainEvents()
  return g
end

h.test("tier 1(5웨이브) 및 tier 2(10웨이브) 보스는 enraged 시 호위 적을 소환하지 않는다", function()
  for _, wave in ipairs({ 5, 10 }) do
    local g = enterBossWave(wave)
    local boss = g.boss
    if not boss then
      return false
    end
    g.phase:damageBoss(g, math.ceil(boss.maxHp * 0.6))
    if not boss.enraged or #g.enemies ~= 0 then
      return false
    end
  end
  return true
end)

h.test("tier 3(15웨이브) 보스는 enraged 진입 시 동일 2체 + 다른 1체(총 3체)를 1회만 소환한다", function()
  local g = enterBossWave(15)
  local boss = g.boss
  if not (boss and boss.tier == 3) then
    return false
  end

  -- HP 50% 이상 유지 중에는 미소환
  g.phase:damageBoss(g, 5)
  if boss.enraged or #g.enemies ~= 0 then
    return false
  end

  -- HP 50% 이하 진입 시 3체 소환
  g.phase:damageBoss(g, math.ceil(boss.maxHp * 0.5))
  if not (boss.enraged and boss.escortSummoned and #g.enemies == 3) then
    return false
  end

  local counts = {}
  for _, e in ipairs(g.enemies) do
    counts[e.kind] = (counts[e.kind] or 0) + 1
  end
  local kinds, hasTwo, hasOne = 0, false, false
  for _, c in pairs(counts) do
    kinds = kinds + 1
    if c == 2 then
      hasTwo = true
    elseif c == 1 then
      hasOne = true
    end
  end

  -- 추가 피격 시 중복 소환되지 않아야 함
  g.phase:damageBoss(g, 2)
  local noDuplicate = (#g.enemies == 3)

  return kinds == 2 and hasTwo and hasOne and noDuplicate
end)

h.test("보스 격파 후에도 살아남은 호위 적은 유지된다", function()
  local g = enterBossWave(15)
  local boss = g.boss
  g.phase:damageBoss(g, math.ceil(boss.maxHp * 0.6))
  if #g.enemies ~= 3 then
    return false
  end

  local escorts = {}
  for _, e in ipairs(g.enemies) do
    escorts[e] = true
  end

  -- 보스 격파
  g.phase:damageBoss(g, boss.hp)
  if g.phase.name ~= "formation" or g.boss ~= nil then
    return false
  end

  -- 기존 호위 적 3체가 새 편대와 함께 g.enemies 에 남아있어야 함
  local kept = 0
  for _, e in ipairs(g.enemies) do
    if escorts[e] and e.alive then
      kept = kept + 1
    end
  end
  return kept == 3 and #g.enemies > 3
end)

h.finish()

