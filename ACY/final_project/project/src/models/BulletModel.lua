-- BulletModel.lua
-- 투사체 1발의 "상태 + 등속 이동"만 담는다. love 비의존.
-- 플레이어/적 총알을 같은 모델로 쓴다(kind 로 구분).

local class = require("class")

local BulletModel = class()

--- 투사체 상태
-- @field x,y   number
-- @field w,h   number
-- @field vx,vy number  속도(px/s)
-- @field kind  string  "player" | "enemy" | "missile"
function BulletModel:init(x, y, vx, vy, w, h, kind, opts)
  self.x = x
  self.y = y
  self.vx = vx
  self.vy = vy
  self.w = w
  self.h = h
  self.kind = kind
  if opts then
    self.splitAfter = opts.splitAfter
    self.splitSpread = opts.splitSpread or 0.32
    self.splitTimer = 0
    self.hasSplit = false
  end
end

function BulletModel:update(dt)
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt
  if self.splitAfter and not self.hasSplit then
    self.splitTimer = (self.splitTimer or 0) + dt
  end
end

function BulletModel:shouldSplit()
  return self.splitAfter ~= nil and not self.hasSplit and (self.splitTimer or 0) >= self.splitAfter
end

function BulletModel:spawnSplitBullets()
  self.hasSplit = true
  local baseAngle = math.atan2(self.vy, self.vx)
  local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
  local spread = self.splitSpread or 0.32
  local angles = { baseAngle - spread, baseAngle, baseAngle + spread }
  local children = {}
  for i = 1, #angles do
    local a = angles[i]
    children[i] = BulletModel(
      self.x,
      self.y,
      math.cos(a) * speed,
      math.sin(a) * speed,
      4,
      12,
      self.kind
    )
  end
  return children
end

-- 월드 경계를 벗어났는가(여유 margin 포함)
function BulletModel:isOffscreen(width, height, margin)
  margin = margin or 24
  return self.y + self.h < -margin
    or self.y > height + margin
    or self.x + self.w < -margin
    or self.x > width + margin
end

return BulletModel
