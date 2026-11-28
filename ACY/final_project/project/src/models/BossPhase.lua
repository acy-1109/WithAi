-- BossPhase.lua
-- 진행 단계(State) ②: 보스전. 보스 등장·이동·탄막·피격·격파 후 편대전 복귀를 맡는다.
-- 남은 편대는 계속 움직이고 쏘지만(공통 규칙), 전멸해도 새 편대는 나오지 않는다.

local class = require("class")
local BossModel = require("BossModel")

local BossPhase = class()

local FIRST_BOSS_WAVE = 5
local BOSS_WAVE_INTERVAL = 5
local BASE_BOSS_HP = 40
local BOSS_HP_STEP = 20
local BASE_BOSS_REWARD = 2000
local BOSS_REWARD_STEP = 1000

BossPhase.name = "boss"

local function bossTier(wave)
  local w = wave or FIRST_BOSS_WAVE
  if w < FIRST_BOSS_WAVE then
    return 1
  end
  return math.floor((w - FIRST_BOSS_WAVE) / BOSS_WAVE_INTERVAL) + 1
end

-- AABB 겹침
local function overlaps(a, b)
  return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function BossPhase:enter(game)
  local tier = bossTier(game.wave)
  local hp = BASE_BOSS_HP + (tier - 1) * BOSS_HP_STEP
  self.reward = BASE_BOSS_REWARD + (tier - 1) * BOSS_REWARD_STEP
  game.boss = BossModel(game.width * 0.5 - 60, 70, hp, tier)
  game:_emit({ type = "boss_appeared" })
end

function BossPhase:update(game, dt)
  local boss = game.boss
  if boss and boss.alive then
    boss:update(dt, game.width, game.enemyBullets, game.player)
  end
end

function BossPhase:damageBoss(game, amount, hitX, hitY)
  local boss = game.boss
  if not (boss and boss.alive) then
    return false
  end
  game:_emit({ type = "boss_hit", x = hitX or boss:centerX(), y = hitY or boss:centerY() })
  local killed = boss:takeDamage(amount)
  if boss.justEnraged then
    boss.justEnraged = false
    game:_emit({ type = "boss_enraged", x = boss:centerX(), y = boss:centerY() })
  end
  if killed then
    local bx, by = boss:centerX(), boss:centerY()
    game:addScore(self.reward or BASE_BOSS_REWARD)
    game.boss = nil
    game:_emit({ type = "boss_destroyed", x = bx, y = by })
    if game.onBossDefeated then
      game:onBossDefeated(bx, by)
    end
    game:spawnFormation()
    local FormationPhase = require("FormationPhase")
    game:changePhase(FormationPhase())
  end
  return killed
end

function BossPhase:resolveCollisions(game)
  local boss = game.boss
  if not (boss and boss.alive) then
    return
  end
  for bi = #game.bullets, 1, -1 do
    local b = game.bullets[bi]
    if overlaps(b, boss) then
      table.remove(game.bullets, bi)
      if self:damageBoss(game, b.damage or 1, b.x, b.y) then
        break
      end
    end
  end

  if boss.alive and boss.aiState == "laser" and not boss.laserHit and game.player then
    local lw = boss.laserWidth or 24
    local muzzleY = boss.y + boss.h
    local laserBox = {
      x = boss:centerX() - lw * 0.5,
      y = muzzleY,
      w = lw,
      h = (game.height or 800) - muzzleY,
    }
    if overlaps(laserBox, game.player) then
      boss.laserHit = true
      game:_damagePlayer()
    end
  end
end

function BossPhase:afterStep(game) end

return BossPhase
