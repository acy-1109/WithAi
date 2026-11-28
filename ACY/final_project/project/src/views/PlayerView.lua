-- PlayerView.lua
-- 플레이어를 날카로운 네온 벡터 전투기로 그린다. Model 을 읽기만 한다(쓰기 금지).

local PlayerView = {}

local PALETTES = {
  balanced = {
    fill = { 0.08, 0.36, 0.62 },
    edge = { 0.35, 0.95, 1.0 },
  },
  rapid = {
    fill = { 0.58, 0.14, 0.16 },
    edge = { 1.0, 0.42, 0.28 },
  },
  emp = {
    fill = { 0.10, 0.44, 0.34 },
    edge = { 0.32, 1.0, 0.72 },
  },
}
local FRAME_COLOR = { 0.18, 0.68, 0.90 }
local CANOPY_COLOR = { 0.75, 0.98, 1.0 }
local CORE_COLOR = { 1.0, 1.0, 1.0 }
local WINGTIP_COLOR = { 0.55, 1.0, 1.0 }
local THRUSTER_COLOR = { 1.0, 0.92, 0.55 }
local SHIELD_INNER_COLOR = { 0.20, 0.75, 1.0, 0.18 }
local SHIELD_OUTER_COLOR = { 0.35, 0.92, 1.0, 0.85 }
local INVINCIBLE_RING_COLOR = { 1.0, 1.0, 1.0, 0.60 }

local max = math.max

local function setColor(gfx, color)
  if color[4] then
    gfx.setColor(color[1], color[2], color[3], color[4])
  else
    gfx.setColor(color[1], color[2], color[3])
  end
end

local function drawHullPolygon(gfx, mode, x, y, w, h, cx)
  gfx.polygon(
    mode,
    cx, y,
    x + w * 0.62, y + h * 0.34,
    x + w, y + h * 0.78,
    x + w * 0.68, y + h * 0.88,
    x + w * 0.58, y + h,
    x + w * 0.42, y + h,
    x + w * 0.32, y + h * 0.88,
    x, y + h * 0.78,
    x + w * 0.38, y + h * 0.34
  )
end

local function drawHull(gfx, x, y, w, h, cx, pal)
  setColor(gfx, pal.fill)
  drawHullPolygon(gfx, "fill", x, y, w, h, cx)
  setColor(gfx, pal.edge)
  drawHullPolygon(gfx, "line", x, y, w, h, cx)
end

local function drawDetails(gfx, x, y, w, h, cx)
  setColor(gfx, FRAME_COLOR)
  gfx.polygon(
    "fill",
    cx, y + h * 0.12,
    x + w * 0.60, y + h * 0.68,
    cx, y + h * 0.84,
    x + w * 0.40, y + h * 0.68
  )

  setColor(gfx, CANOPY_COLOR)
  gfx.polygon(
    "fill",
    cx, y + h * 0.24,
    x + w * 0.58, y + h * 0.46,
    cx, y + h * 0.66,
    x + w * 0.42, y + h * 0.46
  )

  setColor(gfx, CORE_COLOR)
  gfx.circle("fill", cx, y + h * 0.45, 1.8)

  setColor(gfx, WINGTIP_COLOR)
  gfx.circle("fill", x + w * 0.08, y + h * 0.75, 1.6)
  gfx.circle("fill", x + w * 0.92, y + h * 0.75, 1.6)

  setColor(gfx, THRUSTER_COLOR)
  gfx.polygon(
    "fill",
    x + w * 0.44, y + h * 0.88,
    x + w * 0.56, y + h * 0.88,
    cx, y + h
  )
end

local function drawShieldAura(gfx, x, y, w, h, cx)
  local cy = y + h * 0.5
  local r = max(w, h) * 0.65
  setColor(gfx, SHIELD_INNER_COLOR)
  gfx.circle("fill", cx, cy, r)
  setColor(gfx, SHIELD_OUTER_COLOR)
  gfx.circle("line", cx, cy, r)
end

local function drawInvincibleRing(gfx, x, y, w, h, cx)
  local cy = y + h * 0.5
  local r = max(w, h) * 0.58
  setColor(gfx, INVINCIBLE_RING_COLOR)
  gfx.circle("line", cx, cy, r)
end

--- @param gfx    table      love.graphics 또는 같은 함수를 가진 가짜(테스트용)
--- @param player table|nil  PlayerModel (읽기 전용)
function PlayerView.draw(gfx, player)
  if not player then
    return
  end

  local x, y, w, h = player.x, player.y, player.w, player.h
  local cx = x + w * 0.5

  local pal = PALETTES[player.shipId] or PALETTES.balanced
  drawHull(gfx, x, y, w, h, cx, pal)
  drawDetails(gfx, x, y, w, h, cx)

  if player.hasShield then
    drawShieldAura(gfx, x, y, w, h, cx)
  elseif player.invincibleTimer and player.invincibleTimer > 0 then
    drawInvincibleRing(gfx, x, y, w, h, cx)
  end
end

return PlayerView
