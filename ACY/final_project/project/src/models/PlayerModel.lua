-- PlayerModel.lua
-- 플레이어의 "상태 + 규칙"만 담는다. love 비의존(그리기/입력읽기 없음).

local class = require("class")

local PlayerModel = class()

--- 플레이어 상태
-- @field x,y    number  좌상단 좌표
-- @field w,h    number  크기
-- @field cooldown number 다음 발사까지 남은 시간(초)
function PlayerModel:init(x, y)
  self.x = x
  self.y = y
  self.w = 40
  self.h = 24
  self.cooldown = 0
  self.hasShield = false
  self.invincibleTimer = 0
  self.maxBombs = 3
  self.bombs = 1
end

-- move: -1(왼) | 0 | 1(오). 화면 경계는 바깥(GameModel)이 width 로 클램프.
function PlayerModel:move(dt, dir, speed)
  self.x = self.x + dir * speed * dt
end

function PlayerModel:clamp(minX, maxX)
  if self.x < minX then
    self.x = minX
  elseif self.x > maxX - self.w then
    self.x = maxX - self.w
  end
end

function PlayerModel:tickCooldown(dt)
  if self.cooldown > 0 then
    self.cooldown = self.cooldown - dt
  end
end

function PlayerModel:canFire()
  return self.cooldown <= 0
end

function PlayerModel:resetCooldown(seconds)
  self.cooldown = seconds
end

function PlayerModel:activateShield()
  self.hasShield = true
end

function PlayerModel:consumeShield(invincibleSeconds)
  self.hasShield = false
  self.invincibleTimer = invincibleSeconds or 0
end

function PlayerModel:isInvincible()
  return self.invincibleTimer > 0
end

function PlayerModel:tickInvincibility(dt)
  if self.invincibleTimer > 0 then
    self.invincibleTimer = math.max(0, self.invincibleTimer - dt)
  end
end

function PlayerModel:addBomb()
  if self.bombs < self.maxBombs then
    self.bombs = self.bombs + 1
    return true
  end
  return false
end

function PlayerModel:canUseBomb()
  return self.bombs > 0
end

function PlayerModel:useBomb()
  if self.bombs <= 0 then
    return false
  end
  self.bombs = self.bombs - 1
  return true
end

return PlayerModel
