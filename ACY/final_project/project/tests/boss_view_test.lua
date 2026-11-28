-- boss_view_test.lua
-- BossView(네온 드레드노트, 일반/광폭화 팔레트, aiState 연출, HP 바, 히트박스 경계) 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local GameModel = require("GameModel")
local BossModel = require("BossModel")
local BossView = require("BossView")
local GameView = require("GameView")

local function hasColor(gfx, r, g, b)
  for _, c in ipairs(gfx.calls) do
    if c.name == "setColor" and c.args[1] == r and c.args[2] == g and c.args[3] == b then
      return true
    end
  end
  return false
end

local function allPolygonsInBounds(gfx, boss)
  local eps = 1e-6
  for _, c in ipairs(gfx.calls) do
    if c.name == "polygon" then
      for j = 2, #c.args, 2 do
        local px, py = c.args[j], c.args[j + 1]
        if px < boss.x - eps or px > boss.x + boss.w + eps then
          return false
        end
        if py < boss.y - eps or py > boss.y + boss.h + eps then
          return false
        end
      end
    end
  end
  return true
end

h.test("BossView: boss 가 nil 이거나 죽었으면 아무것도 그리지 않는다", function()
  local gfx = h.fakeGfx()
  BossView.draw(gfx, nil, 600)
  local dead = BossModel(240, 80, 30)
  dead.alive = false
  BossView.draw(gfx, dead, 600)
  return #gfx.calls == 0
end)

h.test("BossView: 일반 상태와 광폭화 상태에서 팔레트가 전환되고 히트박스 안에 그려진다", function()
  local boss = BossModel(240, 80, 30)
  local gfxNormal = h.fakeGfx()
  BossView.draw(gfxNormal, boss, 600)

  boss.enraged = true
  local gfxEnraged = h.fakeGfx()
  BossView.draw(gfxEnraged, boss, 600)

  return h.count(gfxNormal, "polygon") >= 4
    and h.count(gfxNormal, "circle") >= 8
    and h.count(gfxNormal, "rectangle") == 2
    and allPolygonsInBounds(gfxNormal, boss)
    and hasColor(gfxNormal, 0.92, 0.35, 1.0)
    and not hasColor(gfxNormal, 1.0, 0.25, 0.25)
    and hasColor(gfxEnraged, 1.0, 0.25, 0.25)
end)

h.test("BossView: spiral 상태에서는 코어 주위에 회전 마커 3개가 추가된다", function()
  local boss = BossModel(240, 80, 30)
  boss.aiState = "patrol"
  local gfxPatrol = h.fakeGfx()
  BossView.draw(gfxPatrol, boss, 600)

  boss.aiState = "spiral"
  boss.spiralAngle = 0.5
  local gfxSpiral = h.fakeGfx()
  BossView.draw(gfxSpiral, boss, 600)

  return h.count(gfxSpiral, "circle") == h.count(gfxPatrol, "circle") + 3
end)

h.test("GameView:draw 는 보스를 그려도 GameModel 을 전혀 변경하지 않는다", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.boss = BossModel(240, 80, 30)
  local view = GameView({ width = 600, height = 800 })
  local gfx = h.fakeGfx()

  local before = h.snapshot(g)
  view:draw(gfx, g)
  local after = h.snapshot(g)

  return h.same(before, after) == true
end)

h.finish()

