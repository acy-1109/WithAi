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

--- 기본 편대 적 ("grunt")
local GruntEnemy = class(EnemyModel)

function GruntEnemy:init(x, y)
  EnemyModel.init(self, x, y)
  self.kind = "grunt"
end

--- 고체력 적 ("tank")
local TankEnemy = class(EnemyModel)

function TankEnemy:init(x, y)
  EnemyModel.init(self, x, y)
  self.kind = "tank"
  self.hp = 3
  self.maxHp = 3
  self.score = 300
  self.speedMul = 0.7
  self.fireCooldownMul = 1.2
end

--- 돌진하는 적 ("sprinter")
local SprinterEnemy = class(EnemyModel)

function SprinterEnemy:init(x, y)
  EnemyModel.init(self, x, y)
  self.kind = "sprinter"
  self.score = 150
  self.speedMul = 1.8
end

--- 원거리 특화 적 ("sniper")
local SniperEnemy = class(EnemyModel)

function SniperEnemy:init(x, y)
  EnemyModel.init(self, x, y)
  self.kind = "sniper"
  self.score = 200
  self.speedMul = 0.9
  self.fireCooldownMul = 0.6
  self.bulletSpeedMul = 1.5
end

local FACTORY = {
  grunt = GruntEnemy,
  tank = TankEnemy,
  sprinter = SprinterEnemy,
  sniper = SniperEnemy,
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

return EnemyModel
