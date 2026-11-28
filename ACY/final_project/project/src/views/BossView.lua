-- BossView.lua
-- 보스를 대형 네온 드레드노트 기함으로 그리고 상단 HP 바를 표시한다. Model 을 읽기만 한다.

local BossView = {}

local cos, sin = math.cos, math.sin
local SPIRAL_STEP = (math.pi * 2) / 3

local NORMAL_PALETTE = {
  fill = { 0.24, 0.08, 0.36 },
  edge = { 0.92, 0.35, 1.0 },
  panel = { 0.42, 0.16, 0.58 },
  core = { 1.0, 0.80, 1.0 },
}

local ENRAGED_PALETTE = {
  fill = { 0.40, 0.06, 0.08 },
  edge = { 1.0, 0.25, 0.25 },
  panel = { 0.65, 0.12, 0.14 },
  core = { 1.0, 0.92, 0.45 },
}

local HP_BG_COLOR = { 0.2, 0.2, 0.2 }
local HP_FILL_COLOR = { 1, 0.2, 0.2 }

local function setColor(gfx, c)
  gfx.setColor(c[1], c[2], c[3])
end

local function drawOutlinedPoly(gfx, fillColor, edgeColor, ...)
  setColor(gfx, fillColor)
  gfx.polygon("fill", ...)
  setColor(gfx, edgeColor)
  gfx.polygon("line", ...)
end

local function drawTurret(gfx, pal, tx, ty)
  setColor(gfx, pal.panel)
  gfx.circle("fill", tx, ty, 5)
  setColor(gfx, pal.edge)
  gfx.circle("line", tx, ty, 5)
  setColor(gfx, pal.core)
  gfx.circle("fill", tx, ty, 2)
end

local function drawHull(gfx, pal, x, y, w, h, cx)
  drawOutlinedPoly(
    gfx,
    pal.fill,
    pal.edge,
    x + w * 0.22, y,
    x + w * 0.78, y,
    x + w * 0.92, y + h * 0.18,
    x + w, y + h * 0.48,
    x + w * 0.86, y + h * 0.78,
    x + w * 0.66, y + h * 0.72,
    x + w * 0.58, y + h,
    cx, y + h * 0.88,
    x + w * 0.42, y + h,
    x + w * 0.34, y + h * 0.72,
    x + w * 0.14, y + h * 0.78,
    x, y + h * 0.48,
    x + w * 0.08, y + h * 0.18
  )
end

local function drawReactorAndCore(gfx, pal, boss, x, y, w, h, cx)
  drawOutlinedPoly(
    gfx,
    pal.panel,
    pal.edge,
    x + w * 0.34, y + h * 0.22,
    x + w * 0.66, y + h * 0.22,
    x + w * 0.70, y + h * 0.52,
    cx, y + h * 0.76,
    x + w * 0.30, y + h * 0.52
  )

  drawTurret(gfx, pal, x + w * 0.20, y + h * 0.50)
  drawTurret(gfx, pal, x + w * 0.80, y + h * 0.50)

  local coreY = y + h * 0.48
  setColor(gfx, pal.edge)
  gfx.circle("line", cx, coreY, 10)
  setColor(gfx, pal.core)
  gfx.circle("fill", cx, coreY, 6)

  if boss.aiState == "aimed" then
    gfx.circle("fill", cx, y + h * 0.88, 3.2)
  elseif boss.aiState == "spiral" then
    local baseAngle = boss.spiralAngle or 0
    for i = 0, 2 do
      local a = baseAngle + i * SPIRAL_STEP
      gfx.circle("fill", cx + cos(a) * 13, coreY + sin(a) * 13, 2.2)
    end
  end
end

local function drawHpBar(gfx, boss, width)
  local barW = (width or 600) - 200
  if barW <= 0 then
    return
  end
  local ratio = (boss.maxHp and boss.maxHp > 0) and (boss.hp / boss.maxHp) or 0
  setColor(gfx, HP_BG_COLOR)
  gfx.rectangle("fill", 100, 40, barW, 10)
  setColor(gfx, HP_FILL_COLOR)
  gfx.rectangle("fill", 100, 40, barW * ratio, 10)
end

--- @param gfx   table      love.graphics 또는 가짜 gfx
--- @param boss  table|nil  BossModel (읽기 전용). 없으면 아무것도 그리지 않는다
--- @param width number     화면 폭
function BossView.draw(gfx, boss, width)
  if not (boss and boss.alive) then
    return
  end

  local pal = boss.enraged and ENRAGED_PALETTE or NORMAL_PALETTE
  local x, y, w, h = boss.x, boss.y, boss.w, boss.h
  local cx = x + w * 0.5

  drawHull(gfx, pal, x, y, w, h, cx)
  drawReactorAndCore(gfx, pal, boss, x, y, w, h, cx)
  drawHpBar(gfx, boss, width)
end

return BossView
