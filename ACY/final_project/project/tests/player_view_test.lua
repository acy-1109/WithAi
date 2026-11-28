-- player_view_test.lua
-- PlayerView(네온 벡터 전투기 렌더링, 히트박스 정렬, nil 가드) 및 GameView 비오염 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local GameModel = require("GameModel")
local PlayerModel = require("PlayerModel")
local PlayerView = require("PlayerView")
local GameView = require("GameView")

h.test("PlayerView: player 가 nil 이면 아무것도 그리지 않는다", function()
  local gfx = h.fakeGfx()
  PlayerView.draw(gfx, nil)
  return #gfx.calls == 0
end)

h.test("PlayerView: 날카로운 네온 전투기를 히트박스 범위 내 다각형과 원으로 그린다", function()
  local gfx = h.fakeGfx()
  local player = PlayerModel(280, 740)
  PlayerView.draw(gfx, player)

  local polyCount = h.count(gfx, "polygon")
  local circleCount = h.count(gfx, "circle")
  local rectCount = h.count(gfx, "rectangle")
  if polyCount < 4 or circleCount < 3 or rectCount ~= 0 then
    return false
  end

  local eps = 1e-6
  for i = 1, #gfx.calls do
    local c = gfx.calls[i]
    if c.name == "polygon" then
      for j = 2, #c.args, 2 do
        local px = c.args[j]
        local py = c.args[j + 1]
        if px < player.x - eps or px > player.x + player.w + eps then
          return false
        end
        if py < player.y - eps or py > player.y + player.h + eps then
          return false
        end
      end
    end
  end

  return true
end)

h.test("GameView:draw 는 플레이어를 그려도 GameModel 을 전혀 변경하지 않는다", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  local view = GameView({ width = 600, height = 800 })
  local gfx = h.fakeGfx()

  local before = h.snapshot(g)
  view:draw(gfx, g)
  local after = h.snapshot(g)

  return h.same(before, after) == true and h.count(gfx, "polygon") >= 4
end)

h.finish()

