-- test_ships.lua
-- 기체 3종 카탈로그, GameModel/PlayerModel 연동, DifficultyScene 기체 선택, PlayerView 색상 분기 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local ShipCatalog = require("ShipCatalog")
local GameModel = require("GameModel")
local DifficultyScene = require("DifficultyScene")
local PlayerView = require("PlayerView")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    io.stderr:write("FAIL: " .. name .. (detail and (" (" .. tostring(detail) .. ")") or "") .. "\n")
  end
end

-- 1. ShipCatalog 조회 및 폴백
do
  local list = ShipCatalog.list()
  check("catalog_list_count", #list == 3, "got " .. tostring(#list))

  local def = ShipCatalog.get(nil)
  check("catalog_nil_fallback", def.id == "balanced", def.id)

  local unknown = ShipCatalog.get("nonexistent")
  check("catalog_unknown_fallback", unknown.id == "balanced", unknown.id)

  local rapid = ShipCatalog.get("rapid")
  check("catalog_rapid", rapid.id == "rapid" and rapid.fireCooldown < def.fireCooldown)
end

-- 2. rapid 기체 스탯 적용 (연사력, 이동속도, 라이프)
do
  local gm = GameModel({ shipId = "rapid" })
  check("rapid_ship_id", gm.player.shipId == "rapid")
  check("rapid_lives", gm.lives == 2 and gm.maxLives == 2, tostring(gm.lives))
  check("rapid_cooldown", math.abs(gm.fireCooldown - 0.17) < 1e-6, tostring(gm.fireCooldown))

  local gmBal = GameModel({ shipId = "balanced" })
  local x0 = gm.player.x
  local xb0 = gmBal.player.x
  gm:update(0.1, { move = 1, fire = false })
  gmBal:update(0.1, { move = 1, fire = false })
  check("rapid_faster_move", (gm.player.x - x0) > (gmBal.player.x - xb0))
end

-- 3. emp 기체 스탯 적용 (시작 실드, 초기/최대 폭탄, EMP 데미지)
do
  local gm = GameModel({ shipId = "emp" })
  check("emp_shield", gm.player.hasShield == true)
  check("emp_bombs", gm.player.bombs == 2 and gm.player.maxBombs == 4)
  check("emp_damage", gm.empDamage == 8, tostring(gm.empDamage))
end

-- 4. DifficultyScene 기체 선택 전환 및 ctx.shipId 전달
do
  local switchedTo = nil
  local ctx = {
    width = 800,
    height = 600,
    shipId = "balanced",
    scenes = {
      Play = function(c) return { kind = "play", ctx = c } end,
      Title = function(c) return { kind = "title", ctx = c } end,
    },
  }
  local scene = DifficultyScene(ctx)
  scene.stack = {
    switch = function(_, target) switchedTo = target end,
  }
  scene:keypressed("down")
  scene:keypressed("return")
  check("scene_select_ship", ctx.shipId == "rapid", tostring(ctx.shipId))
  check("scene_switch_play", switchedTo and switchedTo.kind == "play")
end

-- 5. PlayerView 기체별 색상 분기
do
  local function captureColors(shipId)
    local colors = {}
    local fakeGfx = {
      setColor = function(r, g, b, a)
        colors[#colors + 1] = string.format("%.2f,%.2f,%.2f", r, g, b)
      end,
      polygon = function() end,
      rectangle = function() end,
      circle = function() end,
      line = function() end,
    }
    local p = { x = 100, y = 200, w = 40, h = 24, shipId = shipId, hasShield = false, invincibleTimer = 0 }
    PlayerView.draw(fakeGfx, p)
    return table.concat(colors, "|")
  end

  local cBal = captureColors("balanced")
  local cRap = captureColors("rapid")
  local cEmp = captureColors("emp")
  check("view_color_diff_rapid", cBal ~= cRap)
  check("view_color_diff_emp", cBal ~= cEmp and cRap ~= cEmp)
end

print(string.format("test_ships: passed=%d failed=%d", passed, failed))
if failed > 0 then
  os.exit(1)
end
