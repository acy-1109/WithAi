-- BossModel.lua
-- 보스 1기의 "상태 + 이동/피격 규칙"을 담는다. print / io / love 금지.

local class = require("class")

local BossModel = class()

local BOSS_SPEED = 70
local BOSS_FIRE_INTERVAL = 1.2

--- 보스 상태
-- @field x,y        number  좌상단 좌표
-- @field w,h        number  크기 (120, 60)
-- @field hp,maxhp   number  체력
-- @field alive      boolean 생존 여부
-- @field dir        number  이동 방향 (-1 | 1)
-- @field shootTimer number  다음 탄막 발사까지 남은 시간(초)
function BossModel:init(x, y, hp)
  self.x = x or 240
  self.y = y or 70
  self.w = 120
  self.h = 60
  self.hp = hp or 40
  self.maxhp = self.hp
  self.alive = true
  self.dir = 1
  self.shootTimer = 1.0
end

function BossModel:centerX()
  return self.x + self.w * 0.5
end

function BossModel:centerY()
  return self.y + self.h * 0.5
end

--- 좌우 경계 [margin, width - margin - w] 안에서 왕복 이동한다.
function BossModel:move(dt, width, margin)
  margin = margin or 10
  self.x = self.x + self.dir * BOSS_SPEED * dt
  if self.x < margin then
    self.x = margin
    self.dir = 1
  elseif self.x > width - margin - self.w then
    self.x = width - margin - self.w
    self.dir = -1
  end
end

--- 발사 타이머를 갱신하고, 발사 시점이 되면 true 를 반환한다.
function BossModel:tickFire(dt)
  self.shootTimer = self.shootTimer - dt
  if self.shootTimer <= 0 then
    self.shootTimer = BOSS_FIRE_INTERVAL
    return true
  end
  return false
end

--- 피해를 입고 사망 여부를 반환한다.
function BossModel:takeDamage(amount)
  self.hp = self.hp - (amount or 1)
  if self.hp <= 0 then
    self.hp = 0
    self.alive = false
    return true
  end
  return false
end

return BossModel

