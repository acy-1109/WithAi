-- EnemyView.lua
-- 살아있는 적을 종류별 네온 벡터 기체로 그린다. Model 을 읽기만 한다.

local EnemyView = {}

local GRUNT_FILL = { 0.48, 0.12, 0.15 }
local GRUNT_EDGE = { 1.0, 0.4, 0.4 }
local GRUNT_CORE = { 1.0, 0.85, 0.85 }

local TANK_FILL = { 0.12, 0.28, 0.48 }
local TANK_EDGE = { 0.35, 0.7, 1.0 }
local TANK_ARMOR = { 0.55, 0.82, 1.0 }
local TANK_CORE = { 0.85, 0.96, 1.0 }

local SPRINTER_FILL = { 0.48, 0.36, 0.06 }
local SPRINTER_EDGE = { 1.0, 0.85, 0.25 }
local SPRINTER_CORE = { 1.0, 0.96, 0.7 }

local SNIPER_FILL = { 0.32, 0.14, 0.48 }
local SNIPER_EDGE = { 0.8, 0.45, 1.0 }
local SNIPER_SCOPE = { 0.95, 0.78, 1.0 }
local SNIPER_AIM_CORE = { 1.0, 0.35, 0.75 }

local WEAVER_FILL = { 0.08, 0.40, 0.30 }
local WEAVER_EDGE = { 0.3, 1.0, 0.75 }
local WEAVER_CORE = { 0.8, 1.0, 0.92 }
local WEAVER_LASER_OUTER = { 0.25, 0.95, 0.72 }
local WEAVER_LASER_CORE = { 0.88, 1.0, 0.96 }
local WEAVER_LASER_LENGTH = 1000

local HP_BG_COLOR = { 0.2, 0.2, 0.2 }
local HP_FILL_COLOR = { 0.3, 0.95, 0.5 }
local TANK_SEG_FILL_COLOR = { 0.95, 0.97, 1.0 }
local TANK_SEG_EMPTY_COLOR = { 0.22, 0.24, 0.28 }
local TANK_SEG_GAP = 2

local function setColor(gfx, c)
  gfx.setColor(c[1], c[2], c[3])
end

local function drawOutlinedPoly(gfx, fillColor, edgeColor, ...)
  setColor(gfx, fillColor)
  gfx.polygon("fill", ...)
  setColor(gfx, edgeColor)
  gfx.polygon("line", ...)
end

local function drawGrunt(gfx, e)
  local x, y, w, h = e.x, e.y, e.w, e.h
  local cx = x + w * 0.5
  drawOutlinedPoly(
    gfx,
    GRUNT_FILL,
    GRUNT_EDGE,
    x + w * 0.12, y + h * 0.14,
    cx, y + h * 0.30,
    x + w * 0.88, y + h * 0.14,
    x + w, y + h * 0.56,
    x + w * 0.70, y + h * 0.92,
    cx, y + h,
    x + w * 0.30, y + h * 0.92,
    x, y + h * 0.56
  )
  setColor(gfx, GRUNT_CORE)
  gfx.circle("fill", cx, y + h * 0.56, 3.0)
end

local function drawTank(gfx, e)
  local x, y, w, h = e.x, e.y, e.w, e.h
  local cx = x + w * 0.5
  drawOutlinedPoly(
    gfx,
    TANK_FILL,
    TANK_EDGE,
    x + w * 0.18, y,
    x + w * 0.82, y,
    x + w, y + h * 0.36,
    x + w * 0.90, y + h * 0.88,
    x + w * 0.64, y + h,
    x + w * 0.36, y + h,
    x + w * 0.10, y + h * 0.88,
    x, y + h * 0.36
  )
  setColor(gfx, TANK_ARMOR)
  gfx.polygon(
    "fill",
    cx, y + h * 0.22,
    x + w * 0.72, y + h * 0.52,
    cx, y + h * 0.82,
    x + w * 0.28, y + h * 0.52
  )
  setColor(gfx, TANK_CORE)
  gfx.circle("fill", cx, y + h * 0.52, 3.2)
end

local function drawSprinter(gfx, e)
  local x, y, w, h = e.x, e.y, e.w, e.h
  local cx = x + w * 0.5
  drawOutlinedPoly(
    gfx,
    SPRINTER_FILL,
    SPRINTER_EDGE,
    x + w * 0.08, y,
    cx, y + h * 0.28,
    x + w * 0.92, y,
    x + w, y + h * 0.42,
    cx, y + h,
    x, y + h * 0.42
  )
  setColor(gfx, SPRINTER_CORE)
  gfx.polygon(
    "fill",
    cx, y + h * 0.34,
    x + w * 0.70, y + h * 0.46,
    cx, y + h * 0.84,
    x + w * 0.30, y + h * 0.46
  )
  gfx.circle("fill", cx, y + h * 0.50, 2.4)
end

local function drawSniper(gfx, e)
  local x, y, w, h = e.x, e.y, e.w, e.h
  local cx = x + w * 0.5
  local cy = y + h * 0.42
  drawOutlinedPoly(
    gfx,
    SNIPER_FILL,
    SNIPER_EDGE,
    x + w * 0.22, y + h * 0.08,
    x + w * 0.78, y + h * 0.08,
    x + w * 0.94, y + h * 0.48,
    x + w * 0.60, y + h * 0.66,
    cx, y + h,
    x + w * 0.40, y + h * 0.66,
    x + w * 0.06, y + h * 0.48
  )
  setColor(gfx, SNIPER_SCOPE)
  gfx.circle("line", cx, cy, 4.5)
  setColor(gfx, e.aiState == "aim" and SNIPER_AIM_CORE or SNIPER_SCOPE)
  gfx.circle("fill", cx, cy, 2.0)
end

local function drawWeaver(gfx, e)
  local x, y, w, h = e.x, e.y, e.w, e.h
  local cx = x + w * 0.5
  drawOutlinedPoly(
    gfx,
    WEAVER_FILL,
    WEAVER_EDGE,
    cx, y + h * 0.06,
    x + w * 0.72, y + h * 0.28,
    x + w, y + h * 0.62,
    x + w * 0.66, y + h * 0.72,
    cx, y + h,
    x + w * 0.34, y + h * 0.72,
    x, y + h * 0.62,
    x + w * 0.28, y + h * 0.28
  )
  setColor(gfx, WEAVER_EDGE)
  gfx.circle("fill", x + w * 0.14, y + h * 0.58, 1.6)
  gfx.circle("fill", x + w * 0.86, y + h * 0.58, 1.6)
  setColor(gfx, WEAVER_CORE)
  gfx.circle("fill", cx, y + h * 0.50, 2.8)

  local muzzleY = y + h
  if e.aiState == "charge" then
    local duration = e.chargeDuration or 1.0
    local progress = 1 - (e.chargeTimer or 0) / duration
    if progress < 0 then
      progress = 0
    elseif progress > 1 then
      progress = 1
    end
    setColor(gfx, WEAVER_EDGE)
    if gfx.line then
      gfx.line(cx, muzzleY, cx, muzzleY + WEAVER_LASER_LENGTH)
    end
    gfx.circle("line", cx, muzzleY, 12 * (1 - progress * 0.65))
    setColor(gfx, WEAVER_CORE)
    gfx.circle("fill", cx, muzzleY, 2 + progress * 4)
  elseif e.aiState == "laser" then
    local lw = e.laserWidth or 8
    local coreW = lw * 0.4
    setColor(gfx, WEAVER_LASER_OUTER)
    gfx.rectangle("fill", cx - lw * 0.5, muzzleY, lw, WEAVER_LASER_LENGTH)
    setColor(gfx, WEAVER_LASER_CORE)
    gfx.rectangle("fill", cx - coreW * 0.5, muzzleY, coreW, WEAVER_LASER_LENGTH)
    gfx.circle("fill", cx, muzzleY, lw * 0.65)
  end
end

local KIND_DRAWERS = {
  grunt = drawGrunt,
  tank = drawTank,
  sprinter = drawSprinter,
  sniper = drawSniper,
  weaver = drawWeaver,
}

local function drawTankSegments(gfx, e)
  local segments = e.maxHp or 3
  local segW = (e.w - TANK_SEG_GAP * (segments - 1)) / segments
  local y = e.y - 6
  for k = 1, segments do
    local sx = e.x + (k - 1) * (segW + TANK_SEG_GAP)
    local c = (k <= (e.hp or 0)) and TANK_SEG_FILL_COLOR or TANK_SEG_EMPTY_COLOR
    setColor(gfx, c)
    gfx.rectangle("fill", sx, y, segW, 4)
  end
end

local function drawEnemyHpBar(gfx, e)
  if e.kind == "tank" then
    drawTankSegments(gfx, e)
  elseif e.maxHp and e.maxHp > 1 then
    setColor(gfx, HP_BG_COLOR)
    gfx.rectangle("fill", e.x, e.y - 6, e.w, 4)
    setColor(gfx, HP_FILL_COLOR)
    gfx.rectangle("fill", e.x, e.y - 6, e.w * (e.hp / e.maxHp), 4)
  end
end

--- @param gfx     table      love.graphics 또는 가짜 gfx
--- @param enemies table|nil  EnemyModel 배열 (읽기 전용)
function EnemyView.draw(gfx, enemies)
  if not enemies then
    return
  end
  for i = 1, #enemies do
    local e = enemies[i]
    if e.alive then
      local drawer = KIND_DRAWERS[e.kind] or drawGrunt
      drawer(gfx, e)
      drawEnemyHpBar(gfx, e)
    end
  end
end

return EnemyView
