-- ShipCatalog.lua
-- 플레이어 기체 3종 정의 및 조회 모듈. love 비의존 순수 데이터.

local ShipCatalog = {}

local SHIPS = {
  {
    id = "balanced",
    name = "AEGIS-V",
    role = "BALANCED",
    desc = "STD SPEED / 3 LIVES / 1 EMP",
    speed = 320,
    fireCooldown = 0.25,
    minFireCooldown = 0.10,
    lives = 3,
    hasShield = false,
    bombs = 1,
    maxBombs = 3,
    empDamage = 5,
  },
  {
    id = "rapid",
    name = "VIPER-R",
    role = "RAPID FIRE",
    desc = "FAST / HIGH ROF / 2 LIVES",
    speed = 380,
    fireCooldown = 0.17,
    minFireCooldown = 0.08,
    lives = 2,
    hasShield = false,
    bombs = 1,
    maxBombs = 2,
    empDamage = 5,
  },
  {
    id = "emp",
    name = "PULSE-X",
    role = "EMP SPECIAL",
    desc = "START SHIELD / 2 EMP (DMG 8)",
    speed = 275,
    fireCooldown = 0.30,
    minFireCooldown = 0.12,
    lives = 3,
    hasShield = true,
    bombs = 2,
    maxBombs = 4,
    empDamage = 8,
  },
}

local BY_ID = {}
for i = 1, #SHIPS do
  BY_ID[SHIPS[i].id] = SHIPS[i]
end

function ShipCatalog.list()
  return SHIPS
end

function ShipCatalog.get(id)
  return BY_ID[id] or SHIPS[1]
end

function ShipCatalog.indexOf(id)
  for i = 1, #SHIPS do
    if SHIPS[i].id == id then
      return i
    end
  end
  return 1
end

return ShipCatalog

