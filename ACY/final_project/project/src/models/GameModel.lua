-- GameModel.lua
-- 겔러그의 "상태 + 규칙"을 조율한다. love 비의존, 결정적.
-- 5주차: 단계마다 다른 규칙(편대 재생성, 보스 등장·피격·승리)은 진행 단계 State(self.phase)에 맡긴다.
-- 여기에는 모든 단계에 공통인 규칙만 남는다.

local class = require("class")
local Rng = require("rng")
local PlayerModel = require("PlayerModel")
local EnemyModel = require("EnemyModel")
local BulletModel = require("BulletModel")
local ItemModel = require("ItemModel")
local homing = require("homing")
local FormationPhase = require("FormationPhase")
local WaveParser = require("WaveParser")

local GameModel = class()

-- 규칙 상수(설정). love 와 무관한 월드 수치.
local PLAYER_SPEED = 320
local BULLET_SPEED = 520
local ENEMY_BULLET_SPEED = 240
local FIRE_COOLDOWN = 0.25
local MIN_FIRE_COOLDOWN = 0.10
local SPEED_UP_COOLDOWN_MUL = 0.85
local BASE_PLAYER_DAMAGE = 1
local TRIPLE_SHOT_DURATION = 6.0
local TRIPLE_SHOT_SPLIT_AFTER = 0.45
local TRIPLE_SHOT_SPLIT_SPREAD = 0.32
local ENEMY_FIRE_INTERVAL = 0.6
local FORMATION_SPEED = 40
local FORMATION_DESCEND = 16
local MISSILE_SPEED = 520
local MISSILE_TURN = 0.16
local MISSILE_COOLDOWN = 0.6
local MAX_MISSILES = 3
local MISSILE_RECHARGE_SCORE = 500
local ITEM_DROP_CHANCE = 0.08
local DROP_KINDS = { "life", "speed_up", "triple_shot" }

-- AABB 겹침
local function overlaps(a, b)
  return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

--- @param opts table  { width=number, height=number, seed=number, wavesText=string|nil }
function GameModel:init(opts)
  opts = opts or {}
  self.width = opts.width or 600
  self.height = opts.height or 800
  self.maxLives = opts.maxLives or 3
  self.rng = Rng(opts.seed or 1)
  self.waves = opts.wavesText and WaveParser.parse(opts.wavesText) or nil
  self:reset()
end

function GameModel:reset()
  self.player = PlayerModel(self.width * 0.5 - 20, self.height - 60)
  self.bullets = {}
  self.enemyBullets = {}
  self.enemies = {}
  self.items = {}
  self.score = 0
  self.lives = self.maxLives
  self.state = "playing" -- 결과: "playing" | "gameover" | "won"
  self.formationDir = 1
  self.enemyFireTimer = ENEMY_FIRE_INTERVAL
  self.missileCooldown = 0
  self.maxMissiles = MAX_MISSILES
  self.missiles = MAX_MISSILES
  self.nextMissileScore = MISSILE_RECHARGE_SCORE
  self.boss = nil -- BossPhase 가 채운다 (View 가 읽는다)
  self.events = {} -- 스텝마다 쌓이고, 소비자(View)가 drainEvents() 로 비운다
  self.wave = 0
  self.waveIndex = 0
  self.bossDefeatedCount = 0
  self.playerDamage = BASE_PLAYER_DAMAGE
  self.fireCooldown = FIRE_COOLDOWN
  self.tripleShotTimer = 0
  self:spawnFormation()
  self.phase = nil
  self:changePhase(FormationPhase())
end

function GameModel:_spawnEnemy(kind, x, y)
  local e = EnemyModel.create(kind, x, y)
  if e.kind ~= "tank" then
    local scaledHp = 1 + (self.bossDefeatedCount or 0)
    e.hp = scaledHp
    e.maxHp = scaledHp
  end
  self.enemies[#self.enemies + 1] = e
  return e
end

--- 진행 단계를 바꾼다. 새 단계의 enter 가 곧바로 호출된다.
function GameModel:changePhase(phase)
  self.phase = phase
  phase:enter(self)
end

function GameModel:spawnFormation()
  self.wave = (self.wave or 0) + 1
  if self.waves and #self.waves > 0 then
    local nWaves = #self.waves
    if self.wave == 1 or nWaves == 1 then
      self.waveIndex = 1
    elseif nWaves == 2 then
      self.waveIndex = 2
    else
      local candidates = {}
      for i = 2, nWaves do
        if i ~= self.waveIndex then
          candidates[#candidates + 1] = i
        end
      end
      self.waveIndex = candidates[self.rng:range(#candidates)]
    end
    local wave = self.waves[self.waveIndex]
    for i = 1, #wave.enemies do
      local spec = wave.enemies[i]
      self:_spawnEnemy(spec.kind, spec.x, spec.y)
    end
    return
  end

  for row = 0, 3 do
    for col = 0, 7 do
      self:_spawnEnemy("grunt", 60 + col * 60, 60 + row * 50)
    end
  end
end

function GameModel:_emit(evt)
  self.events[#self.events + 1] = evt
end

--- 쌓인 이벤트를 넘기고 비운다. 프레임당 1회(모든 고정 스텝이 끝난 뒤) 호출한다.
function GameModel:drainEvents()
  local out = self.events
  self.events = {}
  return out
end

--- 고정 스텝 1회. 모든 상태 변경은 여기서(그리고 여기서 부르는 단계 State 에서)만.
-- @param input table  { move = -1|0|1, fire = boolean, missile = boolean }
--
-- 이벤트 계약 (GameModel → View):
--   { type = "fire" }
--   { type = "missile_fired" }
--   { type = "score_changed", score = number, delta = number }
--   { type = "enemy_destroyed", x = number, y = number }
--   { type = "bullet_split", x = number, y = number, kind = string }
--   { type = "player_hit" }
--   { type = "game_over" }
--   { type = "formation_cleared" }
--   { type = "boss_appeared" }
--   { type = "boss_hit", x = number, y = number }
--   { type = "boss_destroyed", x = number, y = number }
-- 탄환 배열을 이동·분열(Sniper/트리플샷)·화면 밖 제거까지 일괄 갱신한다.
local function updateBulletList(list, dt, width, height, game)
  for i = #list, 1, -1 do
    local b = list[i]
    b:update(dt)
    if b.shouldSplit and b:shouldSplit() then
      game:_emit({ type = "bullet_split", x = b.x + b.w * 0.5, y = b.y + b.h * 0.5, kind = b.kind })
      local children = b:spawnSplitBullets()
      table.remove(list, i)
      for j = 1, #children do
        list[#list + 1] = children[j]
      end
    elseif b:isOffscreen(width, height) then
      table.remove(list, i)
    end
  end
end

function GameModel:update(dt, input)
  if self.state ~= "playing" then
    return
  end

  if self.tripleShotTimer > 0 then
    self.tripleShotTimer = math.max(0, self.tripleShotTimer - dt)
  end

  local move = input.move or 0
  local fire = input.fire or false

  -- 플레이어
  self.player:move(dt, move, PLAYER_SPEED)
  self.player:clamp(0, self.width)
  self.player:tickCooldown(dt)
  if fire and self.player:canFire() then
    local p = self.player
    local bulletOpts = { damage = self.playerDamage }
    if self.tripleShotTimer > 0 then
      bulletOpts.splitAfter = TRIPLE_SHOT_SPLIT_AFTER
      bulletOpts.splitSpread = TRIPLE_SHOT_SPLIT_SPREAD
    end
    self.bullets[#self.bullets + 1] =
      BulletModel(p.x + p.w * 0.5 - 2, p.y, 0, -BULLET_SPEED, 4, 12, "player", bulletOpts)
    self.player:resetCooldown(self.fireCooldown)
    self:_emit({ type = "fire" })
  end

  -- 유도 미사일 발사(별도 쿨다운 + 탄수 제한). 기존 BulletModel 을 kind="missile" 로 재사용한다.
  self.missileCooldown = self.missileCooldown - dt
  if input.missile and self.missileCooldown <= 0 and self.missiles > 0 then
    local p = self.player
    self.bullets[#self.bullets + 1] =
      BulletModel(p.x + p.w * 0.5 - 3, p.y, 0, -MISSILE_SPEED, 6, 14, "missile")
    self.missiles = self.missiles - 1
    self.missileCooldown = MISSILE_COOLDOWN
    self:_emit({ type = "fire" })
    self:_emit({ type = "missile_fired" })
  end
  self:_steerMissiles()

  -- 플레이어 총알 이동/분열/제거
  updateBulletList(self.bullets, dt, self.width, self.height, self)

  self:_updateFormation(dt)
  local aiCtx = {
    rng = self.rng,
    player = self.player,
    width = self.width,
    height = self.height,
    spawnEnemyBullet = function(x, y, vx, vy, w, h, opts)
      self.enemyBullets[#self.enemyBullets + 1] =
        BulletModel(x, y, vx, vy, w or 4, h or 12, (opts and opts.kind) or "enemy", opts)
    end,
  }
  for _, e in ipairs(self.enemies) do
    if e.alive then
      e:updateAI(dt, aiCtx)
    end
  end
  self:_updateEnemyFire(dt)
  self.phase:update(self, dt)

  -- 적 총알 이동/분열/제거
  updateBulletList(self.enemyBullets, dt, self.width, self.height, self)

  self:_resolveCollisions()
  self:_updateItems(dt)
  self.phase:resolveCollisions(self)
  self.phase:afterStep(self)
end

function GameModel:_updateFormation(dt)
  local minx, maxx = math.huge, -math.huge
  for _, e in ipairs(self.enemies) do
    if e.alive and e:inFormation() then
      minx = math.min(minx, e.x)
      maxx = math.max(maxx, e.x + e.w)
    end
  end
  if minx == math.huge then
    return
  end
  local dx = self.formationDir * FORMATION_SPEED * dt
  local prevDir = self.formationDir
  if maxx + dx > self.width - 10 then
    self.formationDir = -1
  elseif minx + dx < 10 then
    self.formationDir = 1
  end
  if self.formationDir ~= prevDir then
    for _, e in ipairs(self.enemies) do
      if e:inFormation() then
        e.y = e.y + FORMATION_DESCEND
      else
        e:shiftHome(0, FORMATION_DESCEND)
      end
    end
  else
    local moveDx = self.formationDir * FORMATION_SPEED * dt
    for _, e in ipairs(self.enemies) do
      if e:inFormation() then
        e.x = e.x + moveDx
      else
        e:shiftHome(moveDx, 0)
      end
    end
  end
end

function GameModel:_updateEnemyFire(dt)
  self.enemyFireTimer = self.enemyFireTimer - dt
  if self.enemyFireTimer > 0 then
    return
  end

  local alive = {}
  for _, e in ipairs(self.enemies) do
    if e.alive and e.kind ~= "sniper" and e.kind ~= "weaver" then
      alive[#alive + 1] = e
    end
  end
  if #alive == 0 then
    self.enemyFireTimer = ENEMY_FIRE_INTERVAL
    return
  end
  local e = alive[self.rng:range(#alive)]
  self.enemyFireTimer = ENEMY_FIRE_INTERVAL * (e.fireCooldownMul or 1)
  local bulletSpeed = ENEMY_BULLET_SPEED * (e.bulletSpeedMul or 1)
  self.enemyBullets[#self.enemyBullets + 1] =
    BulletModel(e:centerX() - 2, e.y + e.h, 0, bulletSpeed, 4, 12, "enemy")
end

-- 모든 단계에 공통인 충돌. 단계 고유 충돌(보스)은 phase:resolveCollisions 가 맡는다.
function GameModel:_resolveCollisions()
  -- 플레이어 총알 × 적
  for bi = #self.bullets, 1, -1 do
    local b = self.bullets[bi]
    for _, e in ipairs(self.enemies) do
      if e.alive and overlaps(b, e) then
        local stillAlive = e:takeDamage(b.damage or 1)
        if not stillAlive then
          self:addScore(e.score or 100)
          self:_emit({ type = "enemy_destroyed", x = e:centerX(), y = e:centerY() })
          self:_tryDropItem(e:centerX(), e:centerY())
        end
        table.remove(self.bullets, bi)
        break
      end
    end
  end

  -- 적(돌진 중) × 플레이어 몸통 충돌: 플레이어 피격 후 적은 소멸하지 않고 복귀
  local aiCtx = {
    rng = self.rng,
    player = self.player,
    width = self.width,
    height = self.height,
  }
  for _, e in ipairs(self.enemies) do
    if e.alive and e.aiState == "charge" and overlaps(e, self.player) then
      self.lives = self.lives - 1
      self:_emit({ type = "player_hit" })
      e:onPlayerCollision(aiCtx)
      if self.lives <= 0 then
        self.state = "gameover"
        self:_emit({ type = "game_over" })
        break
      end
    end
  end

  -- 적 총알 × 플레이어
  for i = #self.enemyBullets, 1, -1 do
    if overlaps(self.enemyBullets[i], self.player) then
      table.remove(self.enemyBullets, i)
      self.lives = self.lives - 1
      self:_emit({ type = "player_hit" })
      if self.lives <= 0 then
        self.state = "gameover"
        self:_emit({ type = "game_over" })
      end
    end
  end

  -- Weaver 레이저 × 플레이어 (발사 1회당 최대 1회 피격)
  for _, e in ipairs(self.enemies) do
    if e.alive and e.kind == "weaver" and e.aiState == "laser" and not e.laserHit then
      local lw = e.laserWidth or 8
      local laserBox = {
        x = e:centerX() - lw * 0.5,
        y = e.y + e.h,
        w = lw,
        h = self.height - (e.y + e.h),
      }
      if overlaps(laserBox, self.player) then
        e.laserHit = true
        self.lives = self.lives - 1
        self:_emit({ type = "player_hit" })
        if self.lives <= 0 then
          self.state = "gameover"
          self:_emit({ type = "game_over" })
        end
      end
    end
  end
end

--- 점수를 더하고 500점 단위를 넘길 때마다 유도탄을 1발 충전한다(상한 maxMissiles).
function GameModel:addScore(points)
  local delta = points or 0
  self.score = self.score + delta
  while self.score >= self.nextMissileScore do
    if self.missiles < self.maxMissiles then
      self.missiles = self.missiles + 1
    end
    self.nextMissileScore = self.nextMissileScore + MISSILE_RECHARGE_SCORE
  end
  self:_emit({ type = "score_changed", score = self.score, delta = delta })
end

function GameModel:applySpeedUp()
  self.fireCooldown = math.max(MIN_FIRE_COOLDOWN, self.fireCooldown * SPEED_UP_COOLDOWN_MUL)
end

function GameModel:activateTripleShot(duration)
  self.tripleShotTimer = duration or TRIPLE_SHOT_DURATION
end

function GameModel:_spawnItem(kind, cx, cy)
  local item = ItemModel.create(kind, cx, cy)
  self.items[#self.items + 1] = item
  self:_emit({ type = "item_spawned", kind = item.kind, x = cx, y = cy })
  return item
end

--- 보스 처치 시 처치 횟수를 증가시키고 attack_up 을 확정 드랍한다.
function GameModel:onBossDefeated(bx, by)
  self.bossDefeatedCount = (self.bossDefeatedCount or 0) + 1
  self:_spawnItem("attack_up", bx, by)
end

-- 적 처치 시 8% 확률로 일반 드랍 풀(life, speed_up, triple_shot)에서 균등 드랍한다.
function GameModel:_tryDropItem(cx, cy)
  if self.rng:nextFloat() < ITEM_DROP_CHANCE then
    local kind = DROP_KINDS[self.rng:range(#DROP_KINDS)]
    self:_spawnItem(kind, cx, cy)
  end
end

-- 아이템 수직 이동, 화면 밖 이탈 제거, 플레이어 획득 처리
function GameModel:_updateItems(dt)
  for i = #self.items, 1, -1 do
    local item = self.items[i]
    item:update(dt)
    if item:isOffscreen(self.width, self.height) then
      table.remove(self.items, i)
    elseif overlaps(item, self.player) and item:canCollect(self) then
      item:apply(self)
      self:_emit({
        type = "item_collected",
        kind = item.kind,
        x = item.x + item.w * 0.5,
        y = item.y + item.h * 0.5,
      })
      table.remove(self.items, i)
    end
  end
end

-- 살아있는 적·보스 중 가장 가까운 쪽으로 미사일을 꺾는다.
function GameModel:_steerMissiles()
  local targets
  for i = 1, #self.bullets do
    local b = self.bullets[i]
    if b.kind == "missile" then
      if not targets then
        targets = {}
        for _, e in ipairs(self.enemies) do
          if e.alive then
            targets[#targets + 1] = { x = e:centerX(), y = e:centerY() }
          end
        end
        if self.boss and self.boss.alive then
          targets[#targets + 1] = { x = self.boss:centerX(), y = self.boss:centerY() }
        end
      end
      local tx, ty = homing.nearest(targets, b.x, b.y)
      if tx then
        homing.steer(b, tx, ty, MISSILE_SPEED, MISSILE_TURN)
      end
    end
  end
end

return GameModel
