-- GameModel.lua  (STARTER — TODO 를 채운다)
-- 겔러그의 "상태 + 규칙" 전체를 조율한다. print / io / love 금지, 결정적.
-- 진행: tests/ 에서 `luajit model_test.lua starter` 를 돌리며 FAIL 을 하나씩 ok 로 바꾼다.
-- 원본: 2주차 galaga_monolith/main.lua 의 love.update 블록들.

local class = require("class")
local Rng = require("rng")
local PlayerModel = require("PlayerModel")
local EnemyModel = require("EnemyModel")
local BulletModel = require("BulletModel")
local BossModel = require("BossModel")

local GameModel = class()

-- 모놀리식에 흩어져 있던 매직 넘버를 한곳에 모은다.
local PLAYER_SPEED = 320
local BULLET_SPEED = 520
local ENEMY_BULLET_SPEED = 240
local FIRE_COOLDOWN = 0.25
local ENEMY_FIRE_INTERVAL = 0.6
local FORMATION_SPEED = 40
local FORMATION_DESCEND = 16

local MAX_MISSILES = 3
local MISSILE_RECHARGE_STEP = 500
local HOMING_SPEED = 480
local HOMING_TURN = 0.16
local MISSILE_COOLDOWN = 0.45

local BOSS_BULLET_SPEED = 180
local BOSS_SCORE_TRIGGER = 1000
local BOSS_BARRAGE_COUNT = 18

local function overlaps(a, b)
  return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

--- @param opts table  { width=number, height=number, seed=number }
function GameModel:init(opts)
  opts = opts or {}
  self.width = opts.width or 600
  self.height = opts.height or 800
  -- 디커플링 ③: math.randomseed(os.time()) 대신 주입 RNG
  self.rng = Rng(opts.seed or 1)
  self:reset()
end

function GameModel:reset()
  self.player = PlayerModel(self.width * 0.5 - 20, self.height - 60)
  self.bullets = {}
  self.enemyBullets = {}
  self.enemies = {}
  self.score = 0
  self.lives = 3
  self.missiles = MAX_MISSILES
  self.nextMissileScore = MISSILE_RECHARGE_STEP
  self.state = "playing" -- "playing" | "gameover"
  self.won = false
  self.boss = nil
  self.bossSpawned = false
  self.formationDir = 1
  self.enemyFireTimer = ENEMY_FIRE_INTERVAL
  self.events = {}
  self:spawnFormation()
end

function GameModel:_addScore(points)
  self.score = self.score + points
  while self.score >= self.nextMissileScore do
    if self.missiles < MAX_MISSILES then
      self.missiles = self.missiles + 1
    end
    self.nextMissileScore = self.nextMissileScore + MISSILE_RECHARGE_STEP
  end
end

function GameModel:_nearestTarget(x, y)
  local tx, ty, bestDist = nil, nil, math.huge

  for _, e in ipairs(self.enemies) do
    if e.alive then
      local cx, cy = e:centerX(), e:centerY()
      local distSq = (cx - x) * (cx - x) + (cy - y) * (cy - y)
      if distSq < bestDist then
        bestDist = distSq
        tx, ty = cx, cy
      end
    end
  end

  if self.boss and self.boss.alive then
    local cx, cy = self.boss:centerX(), self.boss:centerY()
    local distSq = (cx - x) * (cx - x) + (cy - y) * (cy - y)
    if distSq < bestDist then
      tx, ty = cx, cy
    end
  end

  return tx, ty
end

--- 4행 × 8열 편대를 만든다. 위치: x = 60 + col*60, y = 60 + row*50
function GameModel:spawnFormation()
  self.enemies = {}
  for row = 0, 3 do
    for col = 0, 7 do
      local x = 60 + col * 60
      local y = 60 + row * 50
      self.enemies[#self.enemies + 1] = EnemyModel(x, y)
    end
  end
end

-- 디커플링 ②: 연출을 직접 만들지 않고 "사실"만 기록한다.
function GameModel:_emit(evt)
  self.events[#self.events + 1] = evt
end

--- 쌓인 이벤트를 넘기고 비운다. 프레임당 1회 호출.
function GameModel:drainEvents()
  local events = self.events
  self.events = {}
  return events
end

--- 매 고정 스텝 1회.
-- @param input table  { move = -1|0|1, fire = boolean, homing = boolean }   ← 디커플링 ①
--
-- 이벤트 계약: fire / homing_fire / enemy_destroyed{x,y} / boss_spawned /
--              boss_destroyed{x,y} / player_hit / game_over{won} / formation_cleared
function GameModel:update(dt, input)
  if self.state == "gameover" then
    return
  end

  input = input or {}
  local move = input.move or 0
  local fire = input.fire or false
  local homing = input.homing or false

  self.player:move(dt, move, PLAYER_SPEED)
  self.player:clamp(0, self.width)
  self.player:tickCooldown(dt)

  if fire and self.player:canFire() then
    local bx = self.player.x + self.player.w * 0.5 - 2
    local by = self.player.y
    self.bullets[#self.bullets + 1] = BulletModel(bx, by, 0, -BULLET_SPEED, 4, 12, "player", false)
    self.player:resetCooldown(FIRE_COOLDOWN)
    self:_emit({ type = "fire" })
  end

  if homing and self.player:canFireMissile() and self.missiles > 0 then
    self.missiles = self.missiles - 1
    local spread = (self.rng:nextFloat() - 0.5) * 360
    local bx = self.player.x + self.player.w * 0.5 - 4
    local by = self.player.y
    self.bullets[#self.bullets + 1] = BulletModel(bx, by, spread, -260, 8, 14, "player", true)
    self.player:resetMissileCooldown(MISSILE_COOLDOWN)
    self:_emit({ type = "homing_fire" })
  end

  for i = #self.bullets, 1, -1 do
    local b = self.bullets[i]
    if b.homing then
      local tx, ty = self:_nearestTarget(b.x, b.y)
      if tx and ty then
        b:steerToward(tx, ty, HOMING_SPEED, HOMING_TURN)
      end
    end
    b:update(dt)
    if b:isOffscreen(self.width, self.height, 30) then
      table.remove(self.bullets, i)
    end
  end

  self:_updateFormation(dt)
  self:_updateEnemyFire(dt)
  self:_updateBoss(dt)

  for i = #self.enemyBullets, 1, -1 do
    local b = self.enemyBullets[i]
    b:update(dt)
    if b:isOffscreen(self.width, self.height) then
      table.remove(self.enemyBullets, i)
    end
  end

  self:_resolveCollisions()
  self:_respawnIfCleared()
end

function GameModel:_updateFormation(dt)
  local minx, maxx = math.huge, -math.huge
  for _, e in ipairs(self.enemies) do
    if e.alive then
      if e.x < minx then minx = e.x end
      if e.x + e.w > maxx then maxx = e.x + e.w end
    end
  end

  if minx == math.huge then
    return
  end

  local dx = self.formationDir * FORMATION_SPEED * dt
  if (maxx + dx > self.width - 10) or (minx + dx < 10) then
    self.formationDir = -self.formationDir
    for _, e in ipairs(self.enemies) do
      if e.alive then
        e.y = e.y + FORMATION_DESCEND
      end
    end
  else
    for _, e in ipairs(self.enemies) do
      if e.alive then
        e.x = e.x + dx
      end
    end
  end
end

function GameModel:_updateEnemyFire(dt)
  self.enemyFireTimer = self.enemyFireTimer - dt
  if self.enemyFireTimer > 0 then
    return
  end
  self.enemyFireTimer = ENEMY_FIRE_INTERVAL

  local alive = {}
  for _, e in ipairs(self.enemies) do
    if e.alive then
      alive[#alive + 1] = e
    end
  end

  if #alive > 0 then
    local shooter = alive[self.rng:range(#alive)]
    local bx = shooter:centerX() - 2
    local by = shooter.y + shooter.h
    self.enemyBullets[#self.enemyBullets + 1] = BulletModel(bx, by, 0, ENEMY_BULLET_SPEED, 4, 12, "enemy")
  end
end

function GameModel:_updateBoss(dt)
  if not self.bossSpawned and self.score >= BOSS_SCORE_TRIGGER then
    self.boss = BossModel(240, 70, 40)
    self.bossSpawned = true
    self:_emit({ type = "boss_spawned" })
  end

  if not (self.boss and self.boss.alive) then
    return
  end

  self.boss:move(dt, self.width, 10)
  if self.boss:tickFire(dt) then
    local cx, cy = self.boss:centerX(), self.boss:centerY()
    for k = 0, BOSS_BARRAGE_COUNT - 1 do
      local angle = (k / BOSS_BARRAGE_COUNT) * math.pi * 2
      local vx = math.cos(angle) * BOSS_BULLET_SPEED
      local vy = math.sin(angle) * BOSS_BULLET_SPEED
      self.enemyBullets[#self.enemyBullets + 1] = BulletModel(cx, cy, vx, vy, 6, 6, "enemy")
    end
  end
end

function GameModel:_resolveCollisions()
  for bi = #self.bullets, 1, -1 do
    local b = self.bullets[bi]
    local hitEnemy = false
    for _, e in ipairs(self.enemies) do
      if e.alive and overlaps(b, e) then
        e.alive = false
        self:_addScore(100)
        self:_emit({ type = "enemy_destroyed", x = e:centerX(), y = e:centerY() })
        table.remove(self.bullets, bi)
        hitEnemy = true
        break
      end
    end

    if not hitEnemy and self.boss and self.boss.alive and overlaps(b, self.boss) then
      table.remove(self.bullets, bi)
      if self.boss:takeDamage(1) then
        self:_addScore(2000)
        self:_emit({ type = "boss_destroyed", x = self.boss:centerX(), y = self.boss:centerY() })
        self.won = true
        self.state = "gameover"
        self:_emit({ type = "game_over", won = true })
      end
    end
  end

  for bi = #self.enemyBullets, 1, -1 do
    local b = self.enemyBullets[bi]
    if overlaps(b, self.player) then
      table.remove(self.enemyBullets, bi)
      self.lives = self.lives - 1
      self:_emit({ type = "player_hit" })
      if self.lives <= 0 then
        self.state = "gameover"
        self:_emit({ type = "game_over", won = false })
      end
    end
  end
end

function GameModel:_respawnIfCleared()
  for _, e in ipairs(self.enemies) do
    if e.alive then
      return
    end
  end
  if not self.bossSpawned then
    self:spawnFormation()
    self:_emit({ type = "formation_cleared" })
  end
end

return GameModel
