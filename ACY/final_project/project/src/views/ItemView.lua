-- ItemView.lua
-- 드랍 아이템을 그린다. Model 을 읽기만 하며, love 를 직접 부르지 않고 주입받은 gfx 만 사용한다.

local ItemView = {}

local LIFE_BG_COLOR = { 0.9, 0.18, 0.22 }
local LIFE_BORDER_COLOR = { 1, 0.55, 0.55 }
local LIFE_PLUS_COLOR = { 1, 1, 1 }
local DEFAULT_COLOR = { 0.8, 0.8, 0.8 }

local min, max = math.min, math.max

local function drawLife(gfx, item)
  local cx = item.x + item.w * 0.5
  local cy = item.y + item.h * 0.5
  local r = min(item.w, item.h) * 0.5

  gfx.setColor(LIFE_BG_COLOR[1], LIFE_BG_COLOR[2], LIFE_BG_COLOR[3])
  gfx.circle("fill", cx, cy, r)

  gfx.setColor(LIFE_BORDER_COLOR[1], LIFE_BORDER_COLOR[2], LIFE_BORDER_COLOR[3])
  gfx.circle("line", cx, cy, r)

  local arm = r * 0.55
  local thick = max(2, r * 0.25)
  gfx.setColor(LIFE_PLUS_COLOR[1], LIFE_PLUS_COLOR[2], LIFE_PLUS_COLOR[3])
  gfx.rectangle("fill", cx - arm, cy - thick * 0.5, arm * 2, thick)
  gfx.rectangle("fill", cx - thick * 0.5, cy - arm, thick, arm * 2)
end

local function drawDefault(gfx, item)
  gfx.setColor(DEFAULT_COLOR[1], DEFAULT_COLOR[2], DEFAULT_COLOR[3])
  gfx.rectangle("fill", item.x, item.y, item.w, item.h)
end

--- 아이템 kind 별 그리기 함수 테이블.
local KIND_DRAWERS = {
  life = drawLife,
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
