-- ItemView.lua
-- 드랍 아이템을 그린다. Model 을 읽기만 하며, love 를 직접 부르지 않고 주입받은 gfx 만 사용한다.

local ItemView = {}

local LIFE_BG_COLOR = { 0.9, 0.18, 0.22 }
local LIFE_BORDER_COLOR = { 1, 0.55, 0.55 }
local ATTACK_BG_COLOR = { 0.96, 0.48, 0.1 }
local ATTACK_BORDER_COLOR = { 1, 0.78, 0.42 }
local SPEED_BG_COLOR = { 0.92, 0.78, 0.1 }
local SPEED_BORDER_COLOR = { 1, 0.96, 0.55 }
local TRIPLE_BG_COLOR = { 0.62, 0.25, 0.94 }
local TRIPLE_BORDER_COLOR = { 0.88, 0.62, 1 }
local SHIELD_BG_COLOR = { 0.14, 0.65, 0.92 }
local SHIELD_BORDER_COLOR = { 0.58, 0.95, 1 }
local BOMB_BG_COLOR = { 0.32, 0.22, 0.88 }
local BOMB_BORDER_COLOR = { 0.65, 0.55, 1 }
local SYMBOL_COLOR = { 1, 1, 1 }
local DEFAULT_COLOR = { 0.8, 0.8, 0.8 }

local min, max = math.min, math.max

local function drawBadge(gfx, item, bgColor, borderColor)
  local cx = item.x + item.w * 0.5
  local cy = item.y + item.h * 0.5
  local r = min(item.w, item.h) * 0.5

  gfx.setColor(bgColor[1], bgColor[2], bgColor[3])
  gfx.circle("fill", cx, cy, r)

  gfx.setColor(borderColor[1], borderColor[2], borderColor[3])
  gfx.circle("line", cx, cy, r)

  return cx, cy, r
end

local function drawLife(gfx, item)
  local cx, cy, r = drawBadge(gfx, item, LIFE_BG_COLOR, LIFE_BORDER_COLOR)
  local arm = r * 0.55
  local thick = max(2, r * 0.25)
  gfx.setColor(SYMBOL_COLOR[1], SYMBOL_COLOR[2], SYMBOL_COLOR[3])
  gfx.rectangle("fill", cx - arm, cy - thick * 0.5, arm * 2, thick)
  gfx.rectangle("fill", cx - thick * 0.5, cy - arm, thick, arm * 2)
end

local function drawAttackUp(gfx, item)
  local cx, cy, r = drawBadge(gfx, item, ATTACK_BG_COLOR, ATTACK_BORDER_COLOR)
  gfx.setColor(SYMBOL_COLOR[1], SYMBOL_COLOR[2], SYMBOL_COLOR[3])
  gfx.polygon(
    "fill",
    cx, cy - r * 0.65,
    cx + r * 0.5, cy - r * 0.05,
    cx - r * 0.5, cy - r * 0.05
  )
  local shaftW = max(2, r * 0.3)
  gfx.rectangle("fill", cx - shaftW * 0.5, cy - r * 0.05, shaftW, r * 0.65)
end

local function drawSpeedUp(gfx, item)
  local cx, cy, r = drawBadge(gfx, item, SPEED_BG_COLOR, SPEED_BORDER_COLOR)
  gfx.setColor(SYMBOL_COLOR[1], SYMBOL_COLOR[2], SYMBOL_COLOR[3])
  gfx.polygon(
    "fill",
    cx + r * 0.12, cy - r * 0.65,
    cx - r * 0.45, cy + r * 0.1,
    cx + r * 0.12, cy + r * 0.1
  )
  gfx.polygon(
    "fill",
    cx - r * 0.12, cy - r * 0.1,
    cx + r * 0.45, cy - r * 0.1,
    cx - r * 0.12, cy + r * 0.65
  )
end

local function drawTripleShot(gfx, item)
  local cx, cy, r = drawBadge(gfx, item, TRIPLE_BG_COLOR, TRIPLE_BORDER_COLOR)
  local dotR = max(1.5, r * 0.19)
  gfx.setColor(SYMBOL_COLOR[1], SYMBOL_COLOR[2], SYMBOL_COLOR[3])
  gfx.circle("fill", cx, cy - r * 0.36, dotR)
  gfx.circle("fill", cx - r * 0.36, cy + r * 0.3, dotR)
  gfx.circle("fill", cx + r * 0.36, cy + r * 0.3, dotR)
end

local function drawShield(gfx, item)
  local cx, cy, r = drawBadge(gfx, item, SHIELD_BG_COLOR, SHIELD_BORDER_COLOR)
  gfx.setColor(SYMBOL_COLOR[1], SYMBOL_COLOR[2], SYMBOL_COLOR[3])
  gfx.polygon(
    "line",
    cx, cy - r * 0.58,
    cx + r * 0.48, cy - r * 0.32,
    cx + r * 0.38, cy + r * 0.25,
    cx, cy + r * 0.62,
    cx - r * 0.38, cy + r * 0.25,
    cx - r * 0.48, cy - r * 0.32
  )
end

local function drawBomb(gfx, item)
  local cx, cy, r = drawBadge(gfx, item, BOMB_BG_COLOR, BOMB_BORDER_COLOR)
  gfx.setColor(SYMBOL_COLOR[1], SYMBOL_COLOR[2], SYMBOL_COLOR[3])
  gfx.circle("fill", cx, cy, r * 0.34)
  gfx.circle("line", cx, cy, r * 0.62)
end

local function drawDefault(gfx, item)
  gfx.setColor(DEFAULT_COLOR[1], DEFAULT_COLOR[2], DEFAULT_COLOR[3])
  gfx.rectangle("fill", item.x, item.y, item.w, item.h)
end

--- 아이템 kind 별 그리기 함수 테이블.
local KIND_DRAWERS = {
  life = drawLife,
  attack_up = drawAttackUp,
  speed_up = drawSpeedUp,
  triple_shot = drawTripleShot,
  shield = drawShield,
  bomb = drawBomb,
}

--- 새 아이템 타입의 그리기 함수를 등록한다.
-- @param kind   string
-- @param drawer function(gfx, item)
function ItemView.registerDrawer(kind, drawer)
  KIND_DRAWERS[kind] = drawer
end

--- @param gfx   table  love.graphics 또는 가짜 gfx
--- @param items table|nil  ItemModel 배열 (읽기 전용)
function ItemView.draw(gfx, items)
  if not items then
    return
  end
  for i = 1, #items do
    local item = items[i]
    local drawer = KIND_DRAWERS[item.kind] or drawDefault
    drawer(gfx, item)
  end
end

return ItemView
