-- hud_view_test.lua
-- HudView 유도탄 네온 네모 표시(보유 개수만 그리기, 빈 슬롯 미표시) 및 Model 비오염 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local GameModel = require("GameModel")
local HudView = require("HudView")

h.test("HudView: 보유 유도탄 수만큼만 네온 네모를 그리고 빈 슬롯은 그리지 않는다", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })

  local gfx3 = h.fakeGfx()
  HudView.draw(gfx3, g, 600, 800)
  if h.count(gfx3, "rectangle") ~= 3 then
    return false
  end

  g.missiles = 1
  local gfx1 = h.fakeGfx()
  HudView.draw(gfx1, g, 600, 800)
  if h.count(gfx1, "rectangle") ~= 1 then
    return false
  end

  g.missiles = 0
  local gfx0 = h.fakeGfx()
  HudView.draw(gfx0, g, 600, 800)
  return h.count(gfx0, "rectangle") == 0
end)

h.test("HudView: draw 호출 전후로 GameModel 을 변경하지 않는다", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  local gfx = h.fakeGfx()
  local before = h.snapshot(g)
  HudView.draw(gfx, g, 600, 800)
  local after = h.snapshot(g)
  return h.same(before, after) == true
end)

h.test("HudView: 공격력·공속 및 트리플 샷 남은 시간(활성 시에만)을 표시한다", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.playerDamage = 3
  g.fireCooldown = 0.125

  local gfxNoTriple = h.fakeGfx()
  HudView.draw(gfxNoTriple, g, 600, 800)
  local sawStats = false
  local sawTripleOff = false
  for _, c in ipairs(gfxNoTriple.calls) do
    if c.name == "print" then
      local msg = tostring(c.args[1])
      if msg == "ATK 3  SPD 2.00x" then
        sawStats = true
      elseif msg:find("TRIPLE", 1, true) then
        sawTripleOff = true
      end
    end
  end

  g.tripleShotTimer = 4.2
  local gfxTriple = h.fakeGfx()
  HudView.draw(gfxTriple, g, 600, 800)
  local sawTripleOn = false
  for _, c in ipairs(gfxTriple.calls) do
    if c.name == "print" and tostring(c.args[1]) == "TRIPLE 4.2s" then
      sawTripleOn = true
    end
  end

  return sawStats and not sawTripleOff and sawTripleOn
end)

h.finish()
