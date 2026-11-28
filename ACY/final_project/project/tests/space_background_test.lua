-- space_background_test.lua
-- SpaceBackgroundView(3단 패럴랙스 별빛 스크롤, 하단 순환 래핑, 성운+별 렌더링) 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local SpaceBackgroundView = require("SpaceBackgroundView")

h.test("SpaceBackgroundView: 초기화 시 50개 별이 화면 영역 안에 생성된다", function()
  local bg = SpaceBackgroundView(600, 800, h.fixedRand())
  if #bg.stars ~= 50 then
    return false
  end
  for i = 1, #bg.stars do
    local s = bg.stars[i]
    if s.x < 0 or s.x > 600 or s.y < 0 or s.y > 800 then
      return false
    end
  end
  return true
end)

h.test("SpaceBackgroundView: update(dt) 로 별이 아래로 이동하고 하단을 넘으면 상단으로 순환한다", function()
  local bg = SpaceBackgroundView(600, 800, h.fixedRand())
  local firstY = bg.stars[1].y
  local speed = bg.stars[1].speed

  bg:update(1.0)
  local expected = firstY + speed
  if expected > 800 then
    expected = expected % 800
  end
  if math.abs(bg.stars[1].y - expected) > 1e-6 then
    return false
  end

  -- 충분히 긴 시간을 진행해도 별 개수와 [0, 800] 범위가 유지된다
  bg:update(20.0)
  if #bg.stars ~= 50 then
    return false
  end
  for i = 1, #bg.stars do
    local s = bg.stars[i]
    if s.y < 0 or s.y > 800 then
      return false
    end
  end
  return true
end)

h.test("SpaceBackgroundView: dt 가 0 이하이면 위치와 시간이 변하지 않는다", function()
  local bg = SpaceBackgroundView(600, 800, h.fixedRand())
  local beforeY = bg.stars[1].y
  bg:update(0)
  bg:update(-0.5)
  return bg.time == 0 and bg.stars[1].y == beforeY
end)

h.test("SpaceBackgroundView: draw(gfx) 는 성운(4개)과 별(50개)을 circle 로 그린다", function()
  local bg = SpaceBackgroundView(600, 800, h.fixedRand())
  local gfx = h.fakeGfx()
  bg:draw(gfx)
  return h.count(gfx, "circle") == 54 and h.count(gfx, "setColor") == 54
end)

h.finish()

