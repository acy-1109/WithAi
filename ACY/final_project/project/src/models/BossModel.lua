-- BossModel.lua
-- 보스 1기의 상태 + 이동 + 원형 탄막 발사. love 비의존.
-- 탄막은 기존 BulletModel(vx, vy 보유) 그대로 쓴다 → 총알 자료구조를 바꿀 필요가 없다.

local class = require("class")
local BulletModel = require("BulletModel")

local BossModel = class()

local SPEED = 70
local ENRAGED_SPEED_MUL = 1.45
local BULLET_SPEED = 180
local ENRAGED_BULLET_MUL = 1.25
local LASER_CHARGE_TIME = 1.0
local LASER_FIRE_TIME = 0.8
local LASER_WIDTH = 24
local LASER_CHARGE_SPEED_MUL = 0.35
local LASER_FIRE_SPEED_MUL = 0.25
local TURRET_TIER = 4
local TURRET_HP = 10
local TURRET_SIZE = 24
local TURRET_GAP = 14
local TURRET_FIRE_INTERVAL = 1.6
local ENRAGED_TURRET_FIRE_INTERVAL = 1.1
local TURRET_BULLET_SPEED = 200

local PatrolState, AimedState, SpiralState, LaserChargeState, LaserFireState

PatrolState = { name = "patrol" }
AimedState = { name = "aimed" }
SpiralState = { name = "spiral" }
LaserChargeState = { name = "laser_charge" }
LaserFireState = { name = "laser" }

local function moveHorizontal(boss, dt, width, speedMul)
  local spd = SPEED * (speedMul or 1) * (boss.enraged and ENRAGED_SPEED_MUL or 1)
  local margin = (boss.turrets and #boss.turrets > 0) and (10 + TURRET_SIZE + TURRET_GAP) or 10
  boss.x = boss.x + boss.dir * spd * dt
  if boss.x < margin then
    boss.x, boss.dir = margin, 1
  elseif boss.x > width - margin - boss.w then
    boss.x, boss.dir = width - margin - boss.w, -1
  end
end

function PatrolState.enter(boss)
  boss.stateTimer = boss.enraged and 2.6 or 3.5
  boss.fireTimer = boss.enraged and 0.45 or 0.6
end

function PatrolState.update(boss, dt, width, out)
  moveHorizontal(boss, dt, width, 1.0)
  boss.fireTimer = boss.fireTimer - dt
  if boss.fireTimer <= 0 then
    boss.fireTimer = boss.enraged and 0.9 or 1.2
    local count
    if boss:isTurretAlive("left") then
      count = boss.enraged and 24 or 18
    else
      count = boss.enraged and 14 or 10
    end
    local spd = BULLET_SPEED * (boss.enraged and ENRAGED_BULLET_MUL or 1)
    local cx, cy = boss:centerX(), boss:centerY()
    for k = 0, count - 1 do
      local a = (k / count) * math.pi * 2
      out[#out + 1] = BulletModel(cx, cy, math.cos(a) * spd, math.sin(a) * spd, 6, 6, "enemy")
    end
  end
  boss.stateTimer = boss.stateTimer - dt
  if boss.stateTimer <= 0 then
    boss:changeState(AimedState)
  end
end

function AimedState.enter(boss)
  boss.stateTimer = boss.enraged and 2.0 or 2.5
  boss.fireTimer = 0.2
end

function AimedState.update(boss, dt, width, out, player)
  boss.fireTimer = boss.fireTimer - dt
  if boss.fireTimer <= 0 then
    boss.fireTimer = boss.enraged and 0.45 or 0.65
    local cx, cy = boss:centerX(), boss:centerY()
    local tx = player and (player.x + (player.w or 0) * 0.5) or (width * 0.5)
    local ty = player and (player.y + (player.h or 0) * 0.5) or 740
    local baseAngle = math.atan2(ty - cy, tx - cx)
    local ways
    if boss:isTurretAlive("right") then
      ways = boss.enraged and 7 or 5
    else
      ways = boss.enraged and 5 or 3
    end
    local half = math.floor(ways * 0.5)
    local step = 0.16
    local spd = BULLET_SPEED * 1.35 * (boss.enraged and ENRAGED_BULLET_MUL or 1)
    for idx = -half, half do
      local a = baseAngle + idx * step
      out[#out + 1] = BulletModel(cx, cy, math.cos(a) * spd, math.sin(a) * spd, 6, 6, "enemy")
    end
  end
  boss.stateTimer = boss.stateTimer - dt
  if boss.stateTimer <= 0 then
    boss:changeState(SpiralState)
  end
end

function SpiralState.enter(boss)
  boss.stateTimer = boss.enraged and 2.4 or 3.0
  boss.fireTimer = 0.1
end

function SpiralState.update(boss, dt, width, out)
  moveHorizontal(boss, dt, width, 0.55)
  boss.fireTimer = boss.fireTimer - dt
  if boss.fireTimer <= 0 then
    boss.fireTimer = boss.enraged and 0.13 or 0.18
    local cx, cy = boss:centerX(), boss:centerY()
    local spd = BULLET_SPEED * (boss.enraged and ENRAGED_BULLET_MUL or 1)
    local arms = 3
    for i = 0, arms - 1 do
      local a = boss.spiralAngle + (i * math.pi * 2 / arms)
      out[#out + 1] = BulletModel(cx, cy, math.cos(a) * spd, math.sin(a) * spd, 6, 6, "enemy")
    end
    boss.spiralAngle = boss.spiralAngle + 0.35
  end
  boss.stateTimer = boss.stateTimer - dt
  if boss.stateTimer <= 0 then
    if (boss.tier or 1) >= 2 then
      boss:changeState(LaserChargeState)
    else
      boss:changeState(PatrolState)
    end
  end
end

function LaserChargeState.enter(boss)
  boss.chargeTimer = boss.chargeDuration or LASER_CHARGE_TIME
end

function LaserChargeState.update(boss, dt, width)
  moveHorizontal(boss, dt, width, LASER_CHARGE_SPEED_MUL)
  boss.chargeTimer = boss.chargeTimer - dt
  if boss.chargeTimer <= 0 then
    boss:changeState(LaserFireState)
  end
end

function LaserFireState.enter(boss)
  boss.laserTimer = LASER_FIRE_TIME
  boss.laserHit = false
end

function LaserFireState.update(boss, dt, width)
  moveHorizontal(boss, dt, width, LASER_FIRE_SPEED_MUL)
  boss.laserTimer = boss.laserTimer - dt
  if boss.laserTimer <= 0 then
    boss:changeState(PatrolState)
  end
end

--- 보스 상태
-- @field x,y,w,h     number
-- @field hp,maxHp    number
-- @field alive       boolean
-- @field dir         number  -1 | 1
-- @field tier        number  보스 티어 (1: 5웨이브, 2: 15웨이브+)
-- @field aiState     string  "patrol" | "aimed" | "spiral" | "laser_charge" | "laser"
-- @field enraged     boolean HP 50% 이하 광폭화 여부
function BossModel:init(x, y, hp, tier)
  self.x, self.y = x, y
  self.w, self.h = 120, 60
  self.hp, self.maxHp = hp, hp
  self.tier = tier or 1
  self.alive = true
  self.dir = 1
  self.enraged = false
  self.justEnraged = false
  self.escortSummoned = false
  self.spiralAngle = 0
  self.laserWidth = LASER_WIDTH
  self.chargeDuration = LASER_CHARGE_TIME
  self.chargeTimer = 0
  self.laserTimer = 0
  self.laserHit = false
  self.turrets = {}
  if self.tier >= TURRET_TIER then
    local halfT = TURRET_SIZE * 0.5
    local cyOff = self.h * 0.50 - halfT
    self.turrets[1] = {
      id = "left",
      ox = -TURRET_SIZE - TURRET_GAP,
      oy = cyOff,
      w = TURRET_SIZE,
      h = TURRET_SIZE,
      hp = TURRET_HP,
      maxHp = TURRET_HP,
      alive = true,
      fireTimer = TURRET_FIRE_INTERVAL * 0.75,
    }
    self.turrets[2] = {
      id = "right",
      ox = self.w + TURRET_GAP,
      oy = cyOff,
      w = TURRET_SIZE,
      h = TURRET_SIZE,
      hp = TURRET_HP,
      maxHp = TURRET_HP,
      alive = true,
      fireTimer = TURRET_FIRE_INTERVAL,
    }
  end
  self.stateObj = nil
  self.aiState = PatrolState.name
  self:changeState(PatrolState)
end

function BossModel:changeState(nextState)
  self.stateObj = nextState
  self.aiState = nextState.name
  if nextState.enter then
    nextState.enter(self)
  end
end

function BossModel:centerX()
  return self.x + self.w * 0.5
end

function BossModel:centerY()
  return self.y + self.h * 0.5
end

--- 서브 포탑의 현재 월드 AABB(x, y, w, h)를 반환한다.
function BossModel:getTurretRect(turret)
  return self.x + turret.ox, self.y + turret.oy, turret.w, turret.h
end

--- 지정 id("left" | "right") 포탑이 살아있는지 반환한다. 포탑이 없는 티어는 true 를 반환한다.
function BossModel:isTurretAlive(id)
  if not self.turrets or #self.turrets == 0 then
    return true
  end
  for i = 1, #self.turrets do
    if self.turrets[i].id == id then
      return self.turrets[i].alive
    end
  end
  return true
end

--- 서브 포탑에 피해를 입힌다. @return boolean 이번 피해로 파괴되었는가
function BossModel:damageTurret(target, amount)
  local t = target
  if type(target) == "string" then
    for i = 1, #self.turrets do
      if self.turrets[i].id == target then
        t = self.turrets[i]
        break
      end
    end
  elseif type(target) == "number" then
    t = self.turrets[target]
  end
  if not (t and t.alive) then
    return false
  end
  t.hp = t.hp - (amount or 1)
  if t.hp <= 0 then
    t.hp = 0
    t.alive = false
    return true
  end
  return false
end

local function updateTurrets(boss, dt, width, out, player)
  if not (boss.turrets and #boss.turrets > 0 and out) then
    return
  end
  local ptx = player and (player.x + (player.w or 0) * 0.5) or (width * 0.5)
  local pty = player and (player.y + (player.h or 0) * 0.5) or 740
  local interval = boss.enraged and ENRAGED_TURRET_FIRE_INTERVAL or TURRET_FIRE_INTERVAL
  local spd = TURRET_BULLET_SPEED * (boss.enraged and ENRAGED_BULLET_MUL or 1)
  for i = 1, #boss.turrets do
    local t = boss.turrets[i]
    if t.alive then
      t.fireTimer = (t.fireTimer or interval) - dt
      if t.fireTimer <= 0 then
        t.fireTimer = interval
        local tx, ty, tw, th = boss:getTurretRect(t)
        local cx, cy = tx + tw * 0.5, ty + th * 0.5
        local a = math.atan2(pty - cy, ptx - cx)
        out[#out + 1] = BulletModel(cx - 3, cy - 3, math.cos(a) * spd, math.sin(a) * spd, 6, 6, "enemy")
      end
    end
  end
end

--- 상태 패턴 FSM 기반 이동 + 탄막 발사. 새 총알은 out 배열에 추가한다.
function BossModel:update(dt, width, out, player)
  if not self.alive then
    return
  end
  self.stateObj.update(self, dt, width, out, player)
  updateTurrets(self, dt, width, out, player)
end

--- 피해를 받는다. @return boolean  이번 피해로 쓰러졌는가
function BossModel:takeDamage(amount)
  self.hp = self.hp - amount
  if self.hp <= 0 then
    self.hp = 0
    self.alive = false
    return true
  end
  if not self.enraged and self.hp <= self.maxHp * 0.5 then
    self.enraged = true
    self.justEnraged = true
  end
  return false
end

return BossModel
