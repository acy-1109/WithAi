-- PlayerModel.lua  (STARTER — 본문을 채운다)
-- 플레이어의 "상태 + 규칙"만 담는다. print / io / love 금지.
-- 참고: 2주차 galaga_monolith/main.lua 의 "플레이어 입력 + 이동", "발사(쿨다운)" 블록.

local class = require("class")

local PlayerModel = class()

--- 플레이어 상태
-- @field x,y       number  좌상단 좌표
-- @field w,h       number  크기 (40, 24)
-- @field cooldown  number  다음 일반 발사까지 남은 시간(초)
-- @field missileCd number  다음 유도 미사일 발사까지 남은 시간(초)
function PlayerModel:init(x, y)
  self.x = x
  self.y = y
  self.w = 40
  self.h = 24
  self.cooldown = 0
  self.missileCd = 0
end

--- dir(-1|0|1) 방향으로 speed(px/s) 만큼 이동한다.
function PlayerModel:move(dt, dir, speed)
  self.x = self.x + dir * speed * dt
end

--- x 를 [minX, maxX - w] 범위로 제한한다.
function PlayerModel:clamp(minX, maxX)
  if self.x < minX then
    self.x = minX
  elseif self.x > maxX - self.w then
    self.x = maxX - self.w
  end
end

function PlayerModel:tickCooldown(dt)
  if self.cooldown > 0 then
    self.cooldown = math.max(0, self.cooldown - dt)
  end
  if self.missileCd > 0 then
    self.missileCd = math.max(0, self.missileCd - dt)
  end
end

function PlayerModel:canFire()
  return self.cooldown <= 0
end

function PlayerModel:resetCooldown(seconds)
  self.cooldown = seconds
end

function PlayerModel:canFireMissile()
  return self.missileCd <= 0
end

function PlayerModel:resetMissileCooldown(seconds)
  self.missileCd = seconds
end

return PlayerModel
