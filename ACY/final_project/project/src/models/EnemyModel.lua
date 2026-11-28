-- EnemyModel.lua
-- 적 1기의 "상태"와 R3 적 타입 상속/팩토리를 담당한다. love 비의존.

local class = require("class")

local EnemyModel = class()

--- 기본 적 상태 초기화
-- @field x,y   number  좌상단 좌표
-- @field w,h   number  크기
-- @field alive boolean 생존 여부
function EnemyModel:init(x, y)
  self.x = x
  self.y = y
  self.w = 36
  self.h = 28
  self.alive = true
  self.kind = "base"
  self.hp = 1
  self.maxHp = 1
  self.score = 100
  self.speedMul = 1.0
  self.fireCooldownMul = 1.0
  self.bulletSpeedMul = 1.0
  self.entering = false
  self.entryDelay = 0
  self.entryElapsed = 0
  self.entryDuration = 0
  self.entryStartX = x
  self.entryStartY = y
  self.entryTargetX = x
  self.entryTargetY = y
end

function EnemyModel:centerX()
  return self.x + self.w * 0.5
end

function EnemyModel:centerY()
  return self.y + self.h * 0.5
end

function EnemyModel:takeDamage(amount)
  local dmg = amount or 1
  self.hp = self.hp - dmg
  if self.hp <= 0 then
    self.hp = 0
    self.alive = false
  end
  return self.alive
end

function EnemyModel:isA(targetClass)
  local mt = getmetatable(self)
  while mt do
    if mt == targetClass then
      return true
    end
    local clsMt = getmetatable(mt)
    mt = clsMt and clsMt.__index or nil
  end
  return false
end

function EnemyModel:inFormation()
  return not self.entering
end

function EnemyModel:shiftHome(dx, dy)
  if self.entering then
    self.entryStartX = self.entryStartX + dx
    self.entryTargetX = self.entryTargetX + dx
    self.entryTargetY = self.entryTargetY + dy
  end
end

function EnemyModel:startEntry(startX, startY, targetX, targetY, duration, delay)
  self.entering = true
  self.entryStartX = startX
  self.entryStartY = startY
  self.entryTargetX = targetX
  self.entryTargetY = targetY
  self.entryDuration = duration or 0.55
  self.entryDelay = delay or 0
  self.entryElapsed = 0
  self.x = startX
  self.y = startY
  if self.homeX ~= nil then
    self.homeX = targetX
    self.homeY = targetY
  end
end

function EnemyModel:updateEntry(dt)
  if not self.entering then
    return true
  end
  if self.entryDelay > 0 then
    self.entryDelay = self.entryDelay - dt
    if self.entryDelay > 0 then
      return false
    end
    dt = -self.entryDelay
    self.entryDelay = 0
  end
  self.entryElapsed = self.entryElapsed + dt
  local dur = self.entryDuration
  local t = dur > 0 and (self.entryElapsed / dur) or 1
  if t >= 1 then
    self.entering = false
    self.x = self.entryTargetX
    self.y = self.entryTargetY
    if self.homeX ~= nil then
      self.homeX = self.entryTargetX
      self.homeY = self.entryTargetY
    end
    return true
  end
  local inv = 1 - t
  local ease = 1 - inv * inv * inv
  self.x = self.entryStartX + (self.entryTargetX - self.entryStartX) * ease
  self.y = self.entryStartY + (self.entryTargetY - self.entryStartY) * ease
  return false
end

function EnemyModel:updateAI(dt, ctx)
end

function EnemyModel:onPlayerCollision(ctx)
end

--- 기본 편대 적 ("grunt")
local GruntEnemy = class(EnemyModel)

function GruntEnemy:init(x, y)
  EnemyModel.init(self, x, y)
  self.kind = "grunt"
end

local TANK_STAGE_STATS = {
  [3] = { bulletSpeedMul = 0.45, fireCooldownMul = 2.0 },
  [2] = { bulletSpeedMul = 0.72, fireCooldownMul = 1.5 },
  [1] = { bulletSpeedMul = 1.0, fireCooldownMul = 1.0 },
}

--- 고체력 적 ("tank") — 공격력과 무관하게 피격 횟수(1타격 = -1)로 HP/단계가 줄어든다
local TankEnemy = class(EnemyModel)

function TankEnemy:init(x, y)
  EnemyModel.init(self, x, y)
  self.kind = "tank"
  self.hp = 3
  self.maxHp = 3
  self.score = 300
  self.speedMul = 0.7
  self:_syncCombatStats()
end

function TankEnemy:_syncCombatStats()
  local key = self.hp >= 3 and 3 or (self.hp <= 1 and 1 or 2)
  local st = TANK_STAGE_STATS[key]
  self.bulletSpeedMul = st.bulletSpeedMul
  self.fireCooldownMul = st.fireCooldownMul
end

function TankEnemy:takeDamage(_amount)
  local alive = EnemyModel.takeDamage(self, 1)
  self:_syncCombatStats()
  return alive
end

local CHARGE_SPEED = 440
local RETURN_SPEED = 280
local CHARGE_MAX_TIME = 5.0
local CHARGE_CHANCE = 0.7

local WaitState, ChargeState, ReturnState

WaitState = { name = "wait" }
ChargeState = { name = "charge" }
ReturnState = { name = "return" }

function WaitState.enter(e, ctx)
  e.vx = 0
  e.vy = 0
  if ctx and ctx.rng then
    e.waitTimer = 1.2 + ctx.rng:nextFloat() * 1.5
  else
    e.waitTimer = nil
  end
end

function WaitState.update(e, dt, ctx)
  if e.waitTimer == nil then
    e.waitTimer = 1.2 + ctx.rng:nextFloat() * 1.5
  end
  e.waitTimer = e.waitTimer - dt
  if e.waitTimer <= 0 then
    if ctx.rng:nextFloat() < CHARGE_CHANCE then
      e:changeAIState(ChargeState, ctx)
    else
      e.waitTimer = 0.6
    end
  end
end

function ChargeState.enter(e, ctx)
  e.homeX = e.x
  e.homeY = e.y
  e.chargeTimer = 0
  local p = ctx.player
  local tx = p and (p.centerX and p:centerX() or (p.x + (p.w or 0) * 0.5)) or e:centerX()
  local ty = p and (p.centerY and p:centerY() or (p.y + (p.h or 0) * 0.5)) or (ctx.height or 800)
  local dx = tx - e:centerX()
  local dy = ty - e:centerY()
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist > 0 then
    e.vx = (dx / dist) * CHARGE_SPEED
    e.vy = (dy / dist) * CHARGE_SPEED
  else
    e.vx = 0
    e.vy = CHARGE_SPEED
  end
end

function ChargeState.update(e, dt, ctx)
  e.chargeTimer = e.chargeTimer + dt
  e.x = e.x + e.vx * dt
  e.y = e.y + e.vy * dt
  local limitX = ctx.width or 600
  local limitY = ctx.height or 800
  if e.y > limitY or e.x + e.w < 0 or e.x > limitX or e.chargeTimer >= CHARGE_MAX_TIME then
    e:changeAIState(ReturnState, ctx)
  end
end

function ReturnState.enter(e)
  e.vx = 0
  e.vy = 0
  e.x = e.homeX
  e.y = -e.h
end

function ReturnState.update(e, dt, ctx)
  local dx = e.homeX - e.x
  local dy = e.homeY - e.y
  local dist = math.sqrt(dx * dx + dy * dy)
  local step = RETURN_SPEED * dt
  if dist <= step or dist <= 1e-6 then
    e.x = e.homeX
    e.y = e.homeY
    e:changeAIState(WaitState, ctx)
  else
    e.x = e.x + (dx / dist) * step
    e.y = e.y + (dy / dist) * step
  end
end

--- 돌진하는 근접형 적 ("sprinter") — State 패턴 FSM(wait -> charge -> return)
local SprinterEnemy = class(EnemyModel)

function SprinterEnemy:init(x, y)
  EnemyModel.init(self, x, y)
  self.kind = "sprinter"
  self.score = 150
  self.speedMul = 1.8
  self.homeX = x
  self.homeY = y
  self.aiState = WaitState.name
  self.stateObj = WaitState
  self.waitTimer = nil
  self.chargeTimer = 0
  self.vx = 0
  self.vy = 0
end

function SprinterEnemy:inFormation()
  return (not self.entering) and self.aiState == "wait"
end

function SprinterEnemy:shiftHome(dx, dy)
  EnemyModel.shiftHome(self, dx, dy)
  self.homeX = self.homeX + dx
  self.homeY = self.homeY + dy
end

function SprinterEnemy:changeAIState(nextState, ctx)
  if self.stateObj and self.stateObj.exit then
    self.stateObj.exit(self, ctx)
  end
  self.stateObj = nextState
  self.aiState = nextState.name
  if nextState.enter then
    nextState.enter(self, ctx)
  end
end

function SprinterEnemy:updateAI(dt, ctx)
  if not self.alive then
    return
  end
  self.stateObj.update(self, dt, ctx)
end

function SprinterEnemy:onPlayerCollision(ctx)
  if self.aiState == "charge" then
    self:changeAIState(ReturnState, ctx)
  end
end

local SNIPER_BULLET_BASE_SPEED = 240
local SNIPER_AIM_TIME = 0.45
local SNIPER_FIRE_PAUSE = 0.1
local SNIPER_SPLIT_AFTER = 0.45
local SNIPER_SPLIT_SPREAD = 0.32

local SniperWaitState, SniperAimState, SniperFireState

SniperWaitState = { name = "wait" }
SniperAimState = { name = "aim" }
SniperFireState = { name = "fire" }

function SniperWaitState.enter(e, ctx)
  if ctx and ctx.rng then
    e.waitTimer = 1.6 + ctx.rng:nextFloat() * 1.4
  else
    e.waitTimer = nil
  end
end

function SniperWaitState.update(e, dt, ctx)
  if e.waitTimer == nil then
    e.waitTimer = 1.6 + ctx.rng:nextFloat() * 1.4
  end
  e.waitTimer = e.waitTimer - dt
  if e.waitTimer <= 0 then
    e:changeAIState(SniperAimState, ctx)
  end
end

function SniperAimState.enter(e, ctx)
  e.aimTimer = SNIPER_AIM_TIME
  local p = ctx.player
  e.aimX = p and (p.centerX and p:centerX() or (p.x + (p.w or 0) * 0.5)) or e:centerX()
  e.aimY = p and (p.centerY and p:centerY() or (p.y + (p.h or 0) * 0.5)) or (ctx.height or 800)
end

function SniperAimState.update(e, dt, ctx)
  local p = ctx.player
  if p then
    e.aimX = p.centerX and p:centerX() or (p.x + (p.w or 0) * 0.5)
    e.aimY = p.centerY and p:centerY() or (p.y + (p.h or 0) * 0.5)
  end
  e.aimTimer = e.aimTimer - dt
  if e.aimTimer <= 0 then
    e:changeAIState(SniperFireState, ctx)
  end
end

function SniperFireState.enter(e, ctx)
  e.firePause = SNIPER_FIRE_PAUSE
  if ctx and ctx.spawnEnemyBullet then
    local sx = e:centerX() - 3
    local sy = e.y + e.h
    local dx = (e.aimX or sx) - e:centerX()
    local dy = (e.aimY or (sy + 100)) - sy
    local dist = math.sqrt(dx * dx + dy * dy)
    local speed = SNIPER_BULLET_BASE_SPEED * (e.bulletSpeedMul or 1)
    local vx, vy
    if dist > 0 then
      vx = (dx / dist) * speed
      vy = (dy / dist) * speed
    else
      vx = 0
      vy = speed
    end
    ctx.spawnEnemyBullet(sx, sy, vx, vy, 6, 12, {
      kind = "enemy_sniper",
      splitAfter = SNIPER_SPLIT_AFTER,
      splitSpread = SNIPER_SPLIT_SPREAD,
    })
  end
end

function SniperFireState.update(e, dt, ctx)
  e.firePause = e.firePause - dt
  if e.firePause <= 0 then
    e:changeAIState(SniperWaitState, ctx)
  end
end

--- 원거리 특화 적 ("sniper") — 자리 이동 없이 State 패턴 FSM(wait -> aim -> fire)
local SniperEnemy = class(EnemyModel)

function SniperEnemy:init(x, y)
  EnemyModel.init(self, x, y)
  self.kind = "sniper"
  self.score = 200
  self.speedMul = 0.9
  self.fireCooldownMul = 0.6
  self.bulletSpeedMul = 1.5
  self.aiState = SniperWaitState.name
  self.stateObj = SniperWaitState
  self.waitTimer = nil
  self.aimTimer = 0
  self.firePause = 0
  self.aimX = x
  self.aimY = y
end

function SniperEnemy:changeAIState(nextState, ctx)
  if self.stateObj and self.stateObj.exit then
    self.stateObj.exit(self, ctx)
  end
  self.stateObj = nextState
  self.aiState = nextState.name
  if nextState.enter then
    nextState.enter(self, ctx)
  end
end

function SniperEnemy:updateAI(dt, ctx)
  if not self.alive then
    return
  end
  self.stateObj.update(self, dt, ctx)
end

local WEAVER_COOLDOWN = 3.5
local WEAVER_CHARGE_TIME = 1.0
local WEAVER_LASER_TIME = 0.6
local WEAVER_LASER_WIDTH = 8

local function updateWeave(e, dt)
  local prevOffset = math.sin(e.weavePhase) * e.weaveAmp
  e.weavePhase = e.weavePhase + dt * e.weaveFreq
  local nextOffset = math.sin(e.weavePhase) * e.weaveAmp
  e.x = e.x + (nextOffset - prevOffset)
end

local WeaverWaitState, WeaverChargeState, WeaverLaserState

WeaverWaitState = { name = "wait" }
WeaverChargeState = { name = "charge" }
WeaverLaserState = { name = "laser" }

function WeaverWaitState.enter(e)
  e.waitTimer = WEAVER_COOLDOWN
end

function WeaverWaitState.update(e, dt, ctx)
  updateWeave(e, dt)
  e.waitTimer = e.waitTimer - dt
  if e.waitTimer <= 0 then
    e:changeAIState(WeaverChargeState, ctx)
  end
end

function WeaverChargeState.enter(e)
  e.chargeTimer = WEAVER_CHARGE_TIME
end

function WeaverChargeState.update(e, dt, ctx)
  updateWeave(e, dt)
  e.chargeTimer = e.chargeTimer - dt
  if e.chargeTimer <= 0 then
    e:changeAIState(WeaverLaserState, ctx)
  end
end

function WeaverLaserState.enter(e)
  e.laserTimer = WEAVER_LASER_TIME
  e.laserHit = false
end

function WeaverLaserState.update(e, dt, ctx)
  e.laserTimer = e.laserTimer - dt
  if e.laserTimer <= 0 then
    e:changeAIState(WeaverWaitState, ctx)
  end
end

--- 지그재그로 흔들리며 이동하고 차징 후 수직 레이저를 쏘는 적 ("weaver")
local WeaverEnemy = class(EnemyModel)

function WeaverEnemy:init(x, y)
  EnemyModel.init(self, x, y)
  self.kind = "weaver"
  self.score = 180
  self.weavePhase = 0
  self.weaveAmp = 24
  self.weaveFreq = 3.2
  self.aiState = WeaverWaitState.name
  self.stateObj = WeaverWaitState
  self.waitTimer = WEAVER_COOLDOWN
  self.chargeTimer = 0
  self.chargeDuration = WEAVER_CHARGE_TIME
  self.laserTimer = 0
  self.laserWidth = WEAVER_LASER_WIDTH
  self.laserHit = false
end

function WeaverEnemy:inFormation()
  return (not self.entering) and self.aiState ~= "laser"
end

function WeaverEnemy:changeAIState(nextState, ctx)
  if self.stateObj and self.stateObj.exit then
    self.stateObj.exit(self, ctx)
  end
  self.stateObj = nextState
  self.aiState = nextState.name
  if nextState.enter then
    nextState.enter(self, ctx)
  end
end

function WeaverEnemy:updateAI(dt, ctx)
  if not self.alive then
    return
  end
  self.stateObj.update(self, dt, ctx)
end

local FACTORY = {
  grunt = GruntEnemy,
  tank = TankEnemy,
  sprinter = SprinterEnemy,
  sniper = SniperEnemy,
  weaver = WeaverEnemy,
}

--- 문자열 키로 적 인스턴스를 생성한다. 미등록 종류면 에러를 발생시킨다.
function EnemyModel.create(kind, x, y)
  local cls = type(kind) == "string" and FACTORY[kind] or nil
  if not cls then
    error(string.format("unknown enemy kind: '%s'", tostring(kind)), 2)
  end
  return cls(x, y)
end

EnemyModel.Grunt = GruntEnemy
EnemyModel.Tank = TankEnemy
EnemyModel.Sprinter = SprinterEnemy
EnemyModel.Sniper = SniperEnemy
EnemyModel.Weaver = WeaverEnemy

return EnemyModel
