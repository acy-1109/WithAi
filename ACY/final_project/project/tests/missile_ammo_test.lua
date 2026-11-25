-- missile_ammo_test.lua
-- 유도탄 탄수 제한(최대 3개), 0발 발사 차단, 500점당 1발 충전 및 엣지 케이스 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local GameModel = require("GameModel")

h.test("GameModel: 시작 시 유도탄 3개 보유, 발사마다 1개 차감, 0개면 발사 불가", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  if g.maxMissiles ~= 3 or g.missiles ~= 3 then
    return false
  end

  for expected = 2, 0, -1 do
    g.missileCooldown = 0
    g:update(0.016, { missile = true })
    if g.missiles ~= expected then
      return false
    end
  end

  -- 0발 상태에서 발사 시도 → 발사되지 않고 탄수도 0 유지
  local bulletsBefore = #g.bullets
  g.missileCooldown = 0
  g:update(0.016, { missile = true })
  return g.missiles == 0 and #g.bullets == bulletsBefore
end)

h.test("GameModel: 500점 도달 시 1개 충전, 한 번에 1000점 획득 시 2개 충전", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.missiles = 0

  g:addScore(499)
  if g.missiles ~= 0 then
    return false
  end

  g:addScore(1) -- 500점 도달
  if g.missiles ~= 1 then
    return false
  end

  g:addScore(1000) -- 1500점 도달 → 1000, 1500 기준 통과로 +2발
  return g.missiles == 3 and g.nextMissileScore == 2000
end)

h.test("GameModel: MAX(3개) 상태에서 500점을 넘기면 상한 유지 및 기준점만 갱신", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  -- 시작 시 missiles == 3 (MAX)
  g:addScore(600)
  if g.missiles ~= 3 or g.nextMissileScore ~= 1000 then
    return false
  end

  -- 1발 소모 후 400점 더 얻어 1000점 도달 시 1발 충전
  g.missiles = 2
  g:addScore(400)
  return g.missiles == 3 and g.nextMissileScore == 1500
end)

h.finish()
