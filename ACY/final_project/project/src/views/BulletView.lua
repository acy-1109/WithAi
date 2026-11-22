-- BulletView.lua
-- 플레이어/적 총알을 그린다. Model 을 읽기만 한다.

local BulletView = {}

local PLAYER_COLOR = { 1, 1, 0.3 }
local MISSILE_COLOR = { 0.4, 1, 0.6 }
local ENEMY_COLOR = { 1, 0.6, 0.2 }
local SNIPER_ENEMY_COLOR = { 0.85, 0.5, 1.0 }

local KIND_COLORS = {
  missile = MISSILE_COLOR,
  enemy_sniper = SNIPER_ENEMY_COLOR,
}

local function drawAll(gfx, list, defaultColor)
  for i = 1, #list do
    local b = list[i]
    local c = KIND_COLORS[b.kind] or defaultColor
    gfx.setColor(c[1], c[2], c[3])
    gfx.rectangle("fill", b.x, b.y, b.w, b.h)
  end
end

--- @param bullets      table  플레이어 BulletModel 배열 (읽기 전용)
--- @param enemyBullets table  적 BulletModel 배열 (읽기 전용)
function BulletView.draw(gfx, bullets, enemyBullets)
  drawAll(gfx, bullets, PLAYER_COLOR)
  drawAll(gfx, enemyBullets, ENEMY_COLOR)
end

return BulletView
