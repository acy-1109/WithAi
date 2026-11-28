-- SpaceBackgroundView.lua
-- 심우주 성운과 3단 패럴랙스 별빛 스크롤을 그리는 배경 View. love 를 직접 부르지 않는다.

local class = require("class")

local SpaceBackgroundView = class()

local min = math.min
local sin = math.sin
local random = math.random
local TWO_PI = math.pi * 2

local STAR_COLORS = {
  { 0.75, 0.85, 1.0 },
  { 0.85, 0.80, 1.0 },
  { 1.0, 0.94, 0.78 },
  { 0.65, 0.95, 1.0 },
}

local LAYER_SPECS = {
  { count = 24, speed = 18, radius = 0.9, alpha = 0.35, twinkle = false },
  { count = 16, speed = 45, radius = 1.4, alpha = 0.60, twinkle = false },
  { count = 10, speed = 95, radius = 2.0, alpha = 0.90, twinkle = true },
}

local NEBULAE = {
  { nx = 0.22, ny = 0.26, nr = 0.34, r = 0.14, g = 0.10, b = 0.42, a = 0.06 },
  { nx = 0.76, ny = 0.48, nr = 0.30, r = 0.06, g = 0.26, b = 0.40, a = 0.05 },
  { nx = 0.38, ny = 0.78, nr = 0.36, r = 0.18, g = 0.08, b = 0.36, a = 0.05 },
  { nx = 0.65, ny = 0.15, nr = 0.22, r = 0.08, g = 0.20, b = 0.45, a = 0.04 },
}

--- @param width  number|nil
--- @param height number|nil
--- @param rand   function|nil  0~1 난수 함수(테스트 결정성용)
function SpaceBackgroundView:init(width, height, rand)
  self.width = width or 600
  self.height = height or 800
  self.time = 0
  self.stars = {}

  local r = rand or random
  local stars = self.stars
  local colorCount = #STAR_COLORS

  for layerIdx = 1, #LAYER_SPECS do
    local spec = LAYER_SPECS[layerIdx]
    for i = 1, spec.count do
      local colorIdx = ((layerIdx + i) % colorCount) + 1
      stars[#stars + 1] = {
        x = r() * self.width,
        y = r() * self.height,
        speed = spec.speed,
        radius = spec.radius,
        alpha = spec.alpha,
        twinkle = spec.twinkle,
        phase = r() * TWO_PI,
        color = STAR_COLORS[colorIdx],
      }
    end
  end
end

function SpaceBackgroundView:update(dt)
  if not dt or dt <= 0 then
    return
  end
  self.time = self.time + dt
  local h = self.height
  local stars = self.stars
  for i = 1, #stars do
    local s = stars[i]
    s.y = s.y + s.speed * dt
    if s.y > h and h > 0 then
      s.y = s.y % h
    end
  end
end

function SpaceBackgroundView:draw(gfx)
  local w, h = self.width, self.height
  local baseR = min(w, h)

  for i = 1, #NEBULAE do
    local n = NEBULAE[i]
    gfx.setColor(n.r, n.g, n.b, n.a)
    gfx.circle("fill", n.nx * w, n.ny * h, n.nr * baseR)
  end

  local stars = self.stars
  local t = self.time
  for i = 1, #stars do
    local s = stars[i]
    local c = s.color
    local alpha = s.twinkle and (s.alpha * (0.65 + 0.35 * sin(t * 3.5 + s.phase))) or s.alpha
    gfx.setColor(c[1], c[2], c[3], alpha)
    gfx.circle("fill", s.x, s.y, s.radius)
  end
end

return SpaceBackgroundView

