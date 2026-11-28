-- EnemyView.lua
-- 살아있는 적을 종류별 색상으로 그린다. Model 을 읽기만 한다.

local EnemyView = {}

local DEFAULT_COLOR = { 1, 0.4, 0.4 }
local KIND_COLORS = {
  grunt = { 1, 0.4, 0.4 },
  tank = { 0.35, 0.7, 1.0 },
  sprinter = { 1.0, 0.85, 0.25 },
  sniper = { 0.8, 0.45, 1.0 },
  weaver = { 0.3, 1.0, 0.75 },
}

local HP_BG_COLOR = { 0.2, 0.2, 0.2 }
local HP_FILL_COLOR = { 0.3, 0.95, 0.5 }
local TANK_SEG_FILL_COLOR = { 0.95, 0.97, 1.0 }
local TANK_SEG_EMPTY_COLOR = { 0.22, 0.24, 0.28 }
local TANK_SEG_GAP = 2

local function drawTankSegments(gfx, e)
  local segments = e.maxHp or 3
  local segW = (e.w - TANK_SEG_GAP * (segments - 1)) / segments
  local y = e.y - 6
  for k = 1, segments do
    local sx = e.x + (k - 1) * (segW + TANK_SEG_GAP)
    local c = (k <= (e.hp or 0)) and TANK_SEG_FILL_COLOR or TANK_SEG_EMPTY_COLOR
    gfx.setColor(c[1], c[2], c[3])
    gfx.rectangle("fill", sx, y, segW, 4)
  end
end

local function drawEnemyHpBar(gfx, e)
  if e.kind == "tank" then
    drawTankSegments(gfx, e)
  elseif e.maxHp and e.maxHp > 1 then
    gfx.setColor(HP_BG_COLOR[1], HP_BG_COLOR[2], HP_BG_COLOR[3])
    gfx.rectangle("fill", e.x, e.y - 6, e.w, 4)
    gfx.setColor(HP_FILL_COLOR[1], HP_FILL_COLOR[2], HP_FILL_COLOR[3])
    gfx.rectangle("fill", e.x, e.y - 6, e.w * (e.hp / e.maxHp), 4)
  end
end

--- @param enemies table  EnemyModel 배열 (읽기 전용)
function EnemyView.draw(gfx, enemies)
  for i = 1, #enemies do
    local e = enemies[i]
    if e.alive then
      local c = KIND_COLORS[e.kind] or DEFAULT_COLOR
      gfx.setColor(c[1], c[2], c[3])
      gfx.rectangle("fill", e.x, e.y, e.w, e.h)
      drawEnemyHpBar(gfx, e)
    end
  end
end

return EnemyView
