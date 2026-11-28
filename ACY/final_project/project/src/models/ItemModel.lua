-- ItemModel.lua
-- 드랍 아이템의 상태와 타입별 효과(Registry/Strategy 패턴)를 담당한다. love 비의존.

local class = require("class")

local ItemModel = class()

local DEFAULT_SPEED = 140
local DEFAULT_SIZE = 18
local DEFAULT_MIN_COOLDOWN = 0.10
local DEFAULT_BASE_COOLDOWN = 0.25
local DEFAULT_SPEED_UP_MUL = 0.85
local DEFAULT_TRIPLE_SHOT_DURATION = 6.0

local function alwaysCollect()
  return true
end

--- 아이템 타입 레지스트리.
-- 새 아이템 추가 시 여기에 테이블 항목(또는 ItemModel.registerType)만 등록한다.
local TYPES = {
  life = {
    w = DEFAULT_SIZE,
    h = DEFAULT_SIZE,
    speed = DEFAULT_SPEED,
    canCollect = function(game)
      return game.lives < game.maxLives
    end,
    apply = function(game)
      game.lives = math.min(game.maxLives, game.lives + 1)
    end,
  },
  attack_up = {
    w = DEFAULT_SIZE,
    h = DEFAULT_SIZE,
    speed = DEFAULT_SPEED,
    canCollect = alwaysCollect,
    apply = function(game)
      game.playerDamage = (game.playerDamage or 1) + 1
    end,
  },
  speed_up = {
    w = DEFAULT_SIZE,
    h = DEFAULT_SIZE,
    speed = DEFAULT_SPEED,
    canCollect = alwaysCollect,
    apply = function(game)
      if game.applySpeedUp then
        game:applySpeedUp()
      else
        local cd = (game.fireCooldown or DEFAULT_BASE_COOLDOWN) * DEFAULT_SPEED_UP_MUL
        game.fireCooldown = math.max(DEFAULT_MIN_COOLDOWN, cd)
      end
    end,
  },
  triple_shot = {
    w = DEFAULT_SIZE,
    h = DEFAULT_SIZE,
    speed = DEFAULT_SPEED,
    canCollect = alwaysCollect,
    apply = function(game)
      if game.activateTripleShot then
        game:activateTripleShot()
      else
        game.tripleShotTimer = DEFAULT_TRIPLE_SHOT_DURATION
      end
    end,
  },
}

ItemModel.TYPES = TYPES

--- 새 아이템 타입을 등록한다.
-- @param kind string
-- @param spec table  { w?, h?, speed?, canCollect?(game, item), apply?(game, item) }
function ItemModel.registerType(kind, spec)
  TYPES[kind] = spec
end

--- 중심 좌표(cx, cy) 기준으로 아이템을 생성한다.
function ItemModel.create(kind, cx, cy, opts)
  local spec = assert(TYPES[kind], "unknown item kind: " .. tostring(kind))
  local w = (opts and opts.w) or spec.w or DEFAULT_SIZE
  local h = (opts and opts.h) or spec.h or DEFAULT_SIZE
  return ItemModel(kind, cx - w * 0.5, cy - h * 0.5, opts)
end

--- 좌상단 좌표(x, y) 기준으로 아이템을 초기화한다.
function ItemModel:init(kind, x, y, opts)
  local spec = assert(TYPES[kind], "unknown item kind: " .. tostring(kind))
  self.kind = kind
  self.x = x
  self.y = y
  self.w = (opts and opts.w) or spec.w or DEFAULT_SIZE
  self.h = (opts and opts.h) or spec.h or DEFAULT_SIZE
  self.speed = (opts and opts.speed) or spec.speed or DEFAULT_SPEED
  self.vx = (opts and opts.vx) or 0
  self.vy = (opts and opts.vy) or self.speed
end

function ItemModel:update(dt)
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt
end

function ItemModel:isOffscreen(width, height)
  return self.x + self.w < 0 or self.x > width or self.y + self.h < 0 or self.y > height
end

function ItemModel:canCollect(game)
  local spec = TYPES[self.kind]
  if spec and spec.canCollect then
    return spec.canCollect(game, self)
  end
  return true
end

function ItemModel:apply(game)
  local spec = TYPES[self.kind]
  if spec and spec.apply then
    spec.apply(game, self)
  end
end

return ItemModel
