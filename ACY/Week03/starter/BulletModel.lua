-- BulletModel.lua  (STARTER — 본문을 채운다)
-- 투사체 1발의 "상태 + 등속 이동". print / io / love 금지.
-- 플레이어/적 총알을 같은 모델로 쓴다(kind 로 구분).

local class = require("class")

local BulletModel = class()

--- 투사체 상태
-- @field x,y    number
-- @field w,h    number
-- @field vx,vy  number  속도(px/s). 위로 가면 vy < 0
-- @field kind   string  "player" | "enemy"
-- @field homing boolean 유도 미사일 여부
function BulletModel:init(x, y, vx, vy, w, h, kind, homing)
  self.x = x
  self.y = y
  self.vx = vx
  self.vy = vy
  self.w = w
  self.h = h
  self.kind = kind
  self.homing = homing or false
end

--- 목표 좌표 (tx, ty) 방향으로 속도를 부드럽게 회전한다.
function BulletModel:steerToward(tx, ty, speed, turn)
  local dx = tx - self.x
  local dy = ty - self.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist <= 0 then
    return
  end

  local desiredVx = (dx / dist) * speed
  local desiredVy = (dy / dist) * speed

  self.vx = self.vx + (desiredVx - self.vx) * turn
  self.vy = self.vy + (desiredVy - self.vy) * turn

  local currentSpeed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
  if currentSpeed > 0 then
    self.vx = (self.vx / currentSpeed) * speed
    self.vy = (self.vy / currentSpeed) * speed
  end
end

function BulletModel:update(dt)
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt
end

--- 월드 경계(+margin)를 벗어났는가
function BulletModel:isOffscreen(width, height, margin)
  margin = margin or 24
  return self.x + self.w < -margin
    or self.x > width + margin
    or self.y + self.h < -margin
    or self.y > height + margin
end

return BulletModel
