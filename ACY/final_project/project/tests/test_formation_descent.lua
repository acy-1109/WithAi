-- test_formation_descent.lua
-- 편대가 좌우 경계에 닿았을 때 0.30초 동안 부드럽게 하강(좌우 이동 일시정지)하는 연출 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local GameModel = require("GameModel")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    io.stderr:write("FAIL: " .. name .. (detail and (" (" .. tostring(detail) .. ")") or "") .. "\n")
  end
end

local function finishEntry(gm)
  for _, e in ipairs(gm.enemies) do
    e.entering = false
    e.x = e.entryTargetX
    e.y = e.entryTargetY
  end
end

-- 1. 벽 접촉 직후 1프레임에는 16px 전체가 순간이동하지 않고 일부만 하강 + 좌우 이동 일시정지
do
  local gm = GameModel({
    width = 600,
    height = 800,
    seed = 1,
    wavesText = "wave 1\nenemy grunt 554 80\n",
  })
  finishEntry(gm)
  local e = gm.enemies[1]
  local startX, startY = e.x, e.y

  -- 1프레임: 554 + 36(w) + 0.67 > 590 이므로 반전 + 하강 시작
  gm:update(1 / 60, { move = 0, fire = false })
  local dy1 = e.y - startY
  check("partial_descend_on_first_frame", dy1 > 0 and dy1 < 16, "dy1=" .. tostring(dy1))
  check("horizontal_paused_during_descent", e.x == startX, "x=" .. tostring(e.x))
  check("direction_flipped", gm.formationDir == -1)

  -- 0.30초(총 18프레임) 완료 시 정확히 16px 하강
  for _ = 2, 18 do
    gm:update(1 / 60, { move = 0, fire = false })
  end
  check("exact_descend_after_duration", math.abs((e.y - startY) - 16) < 1e-6, "dy=" .. tostring(e.y - startY))
  check("descent_state_cleared", gm.descendTotal == 0)

  -- 다음 프레임부터는 반대 방향(-1)으로 좌우 이동 재개
  local xAfterDescend = e.x
  gm:update(1 / 60, { move = 0, fire = false })
  check("horizontal_resumed_after_descent", e.x < xAfterDescend, string.format("%.2f < %.2f", e.x, xAfterDescend))
end

-- 2. 특수 상태 적(entering)도 하강 중 shiftHome(0, dy)로 목표 Y가 동기화된다
do
  local gm = GameModel({
    width = 600,
    height = 800,
    seed = 1,
    wavesText = "wave 1\nenemy grunt 554 80\nenemy grunt 200 80\n",
  })
  -- 1번 적은 이미 대형에 있고, 2번 적은 아직 entering 상태
  local e1, e2 = gm.enemies[1], gm.enemies[2]
  e1.entering = false
  e1.x = e1.entryTargetX
  e1.y = e1.entryTargetY

  for _ = 1, 90 do
    gm:update(1 / 60, { move = 0, fire = false })
  end
  check("entering_enemy_synced_y", math.abs(e1.y - e2.y) < 1e-6, string.format("e1=%.2f, e2=%.2f", e1.y, e2.y))
end

-- 3. 결정성: 동일 시드, 동일 dt 시퀀스
do
  local wave = "wave 1\nenemy grunt 554 80\n"
  local gmA = GameModel({ width = 600, height = 800, seed = 7, wavesText = wave })
  local gmB = GameModel({ width = 600, height = 800, seed = 7, wavesText = wave })
  finishEntry(gmA)
  finishEntry(gmB)

  for _ = 1, 10 do
    gmA:update(1 / 60, { move = 0, fire = false })
    gmB:update(1 / 60, { move = 0, fire = false })
  end
  check("determinism_mid_descent",
    math.abs(gmA.enemies[1].y - gmB.enemies[1].y) < 1e-9 and gmA.descendElapsed == gmB.descendElapsed)
end

print(string.format("test_formation_descent: %d passed, %d failed", passed, failed))
if failed > 0 then
  os.exit(1)
end

