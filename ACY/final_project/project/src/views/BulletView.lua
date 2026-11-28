-- BulletView.lua
-- 플레이어/적 총알을 종류별 네온 벡터 도형으로 그린다. Model 을 읽기만 한다.

local BulletView = {}

local atan2 = math.atan2
local min, max = math.min, math.max
local HALF_PI = math.pi * 0.5

local PLAYER_OUTER_COLOR = { 1.0, 0.92, 0.25 }
local PLAYER_CORE_COLOR = { 1.0, 1.0, 0.9 }

local MISSILE_BODY_COLOR = { 0.3, 1.0, 0.55 }
local MISSILE_TIP_COLOR = { 0.85, 1.0, 0.92 }
local MISSILE_THRUST_COLOR = { 1.0, 0.9, 0.35 }

local ENEMY_OUTER_COLOR = { 1.0, 0.45, 0.15 }
local ENEMY_RING_COLOR = { 1.0, 0.78, 0.38 }
local ENEMY_CORE_COLOR = { 1.0, 0.95, 0.75 }

local SNIPER_FILL_COLOR = { 0.82, 0.38, 1.0 }
local SNIPER_EDGE_COLOR = { 0.95, 0.72, 1.0 }
local SNIPER_CORE_COLOR = { 1.0, 0.92, 1.0 }

local function setColor(gfx, c)
  gfx.setColor(c[1], c[2], c[3])
end

local function drawPlayerBolt(gfx, hw, hh)
  setColor(gfx, PLAYER_OUTER_COLOR)
  gfx.polygon(
    "fill",
    0, -hh,
    hw, -hh * 0.15,
    hw * 0.7, hh,
    -hw * 0.7, hh,
    -hw, -hh * 0.15
  )

  setColor(gfx, PLAYER_CORE_COLOR)
  gfx.polygon(
    "fill",
    0, -hh * 0.75,
    hw * 0.45, 0,
    0, hh * 0.75,
    -hw * 0.45, 0
  )
end

local function drawMissile(gfx, hw, hh)
  setColor(gfx, MISSILE_BODY_COLOR)
  gfx.polygon(
    "fill",
    0, -hh,
    hw * 0.75, -hh * 0.25,
    hw * 0.75, hh * 0.45,
    hw, hh * 0.85,
    hw * 0.45, hh * 0.72,
    -hw * 0.45, hh * 0.72,
    -hw, hh * 0.85,
    -hw * 0.75, hh * 0.45,
    -hw * 0.75, -hh * 0.25
  )

  setColor(gfx, MISSILE_TIP_COLOR)
  gfx.polygon(
    "fill",
    0, -hh,
    hw * 0.45, -hh * 0.35,
    -hw * 0.45, -hh * 0.35
  )

  setColor(gfx, MISSILE_THRUST_COLOR)
  gfx.circle("fill", 0, hh * 0.82, max(1.3, hw * 0.45))
end

local function drawEnemyDart(gfx, hw, hh)
  setColor(gfx, ENEMY_OUTER_COLOR)
  gfx.polygon(
    "fill",
    0, -hh,
    hw, -hh * 0.2,
    hw * 0.55, hh * 0.55,
    0, hh,
    -hw * 0.55, hh * 0.55,
    -hw, -hh * 0.2
  )

  setColor(gfx, ENEMY_CORE_COLOR)
  gfx.circle("fill", 0, -hh * 0.1, max(1.0, hw * 0.45))
end

local function drawEnemyOrb(gfx, cx, cy, r)
  setColor(gfx, ENEMY_OUTER_COLOR)
  gfx.circle("fill", cx, cy, r)
  setColor(gfx, ENEMY_RING_COLOR)
  gfx.circle("line", cx, cy, r)
  setColor(gfx, ENEMY_CORE_COLOR)
  gfx.circle("fill", cx, cy, max(1.0, r * 0.48))
end

local function drawSniperNeedle(gfx, hw, hh)
  setColor(gfx, SNIPER_FILL_COLOR)
  gfx.polygon(
    "fill",
    0, -hh,
    hw, -hh * 0.1,
    0, hh,
    -hw, -hh * 0.1
  )

  setColor(gfx, SNIPER_EDGE_COLOR)
  gfx.polygon(
    "line",
    0, -hh,
    hw, -hh * 0.1,
    0, hh,
    -hw, -hh * 0.1
  )

  setColor(gfx, SNIPER_CORE_COLOR)
  gfx.circle("fill", 0, -hh * 0.15, max(1.2, hw * 0.42))
end

local DIRECTIONAL_DRAWERS = {
  player = drawPlayerBolt,
  missile = drawMissile,
  enemy = drawEnemyDart,
  enemy_sniper = drawSniperNeedle,
}

local function resolveAngle(b, defaultVy)
  local vx = b.vx or 0
  local vy = b.vy or defaultVy
  if vx == 0 and vy == 0 then
    vy = defaultVy
  end
  return atan2(vy, vx) + HALF_PI
end

local function drawAll(gfx, list, defaultKind, defaultVy)
  if not list then
    return
  end
  for i = 1, #list do
    local b = list[i]
    local w = b.w or 4
    local h = b.h or 12
    local cx = b.x + w * 0.5
    local cy = b.y + h * 0.5
    local kind = b.kind or defaultKind

    if kind == "enemy" and w == h then
      drawEnemyOrb(gfx, cx, cy, min(w, h) * 0.5)
    else
      local drawer = DIRECTIONAL_DRAWERS[kind] or DIRECTIONAL_DRAWERS[defaultKind]
      local angle = resolveAngle(b, defaultVy)
      gfx.push()
      gfx.translate(cx, cy)
      if angle ~= 0 then
        gfx.rotate(angle)
      end
      drawer(gfx, w * 0.5, h * 0.5)
      gfx.pop()
    end
  end
end

--- @param gfx          table      love.graphics 또는 가짜 gfx
--- @param bullets      table|nil  플레이어 BulletModel 배열 (읽기 전용)
--- @param enemyBullets table|nil  적 BulletModel 배열 (읽기 전용)
function BulletView.draw(gfx, bullets, enemyBullets)
  drawAll(gfx, bullets, "player", -1)
  drawAll(gfx, enemyBullets, "enemy", 1)
end

return BulletView
