-- test_wave_entry.lua
-- 웨이브 시작 시 적들이 화면 상단 밖에서 목표 대형 위치로 수직 진입하는 연출 테스트.

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

local function stepN(gm, n, dt, input)
  dt = dt or (1 / 60)
  input = input or { move = 0, fire = false }
  for _ = 1, n do
    gm:update(dt, input)
  end
end

-- 1. 초기 진입 위치: 스폰 직후 모든 적이 entering=true, y < 0
do
  local gm = GameModel({ seed = 1 })
  local allEntering = true
  local allOffscreen = true
  for _, e in ipairs(gm.enemies) do
    if not e.entering then
      allEntering = false
    end
    if e.y >= 0 then
      allOffscreen = false
    end
  end
  check("spawn_all_entering", #gm.enemies > 0 and allEntering)
  check("spawn_all_above_screen", allOffscreen)
end

-- 2. 시차(Stagger) 및 보간 완료 후 목표 좌표 일치
do
  local wavesText = "wave 1\nenemy grunt 100 80\nenemy grunt 200 120\nenemy grunt 300 160\n"
  local gm = GameModel({ seed = 1, wavesText = wavesText })
  local e1, e2, e3 = gm.enemies[1], gm.enemies[2], gm.enemies[3]
  local x1, x2, x3 = e1.x, e2.x, e3.x
  check("vertical_start_x", x1 == 100 and x2 == 200 and x3 == 300)

  -- 짧은 시간 진행: 첫 번째 적은 이미 내려오기 시작하고, 뒤쪽 적은 지연 중이거나 더 적게 이동
  stepN(gm, 15, 1 / 60)
  check("stagger_order", e1.y > e2.y or e1.entryElapsed > e2.entryElapsed)

  -- 충분히 진행하면 모두 진입 완료
  stepN(gm, 120, 1 / 60)
  check("entry_finished", not e1.entering and not e2.entering and not e3.entering)
  check("target_y_reached", math.abs(e1.y - 80) < 1e-6 and math.abs(e2.y - 120) < 1e-6 and math.abs(e3.y - 160) < 1e-6)
end

-- 3. 진입 중 행동 제한 (사격/AI 정지) 및 무적 상태 확인
do
  local wavesText = "wave 1\nenemy sniper 100 80\nenemy weaver 200 80\nenemy sprinter 300 80\nenemy grunt 400 80\n"
  local gm = GameModel({ seed = 1, wavesText = wavesText })
  -- 진입 중에는 총알 발사, AI 상태 전이, EMP 피격이 발생하지 않아야 함
  stepN(gm, 15, 1 / 60)
  check("no_enemy_bullets_during_entry", #gm.enemyBullets == 0, "bullets=" .. tostring(#gm.enemyBullets))
  check("weaver_no_weave_during_entry", gm.enemies[2].x == 200, "x=" .. tostring(gm.enemies[2].x))

  -- EMP 폭탄 사용 시 진입 중인 적은 무적
  gm:_detonateEmpBomb()
  local allAlive = true
  for _, e in ipairs(gm.enemies) do
    if not e.alive then
      allAlive = false
    end
  end
  check("invincible_to_emp_during_entry", allAlive)
end

-- 4. 대형 이동 동기화 (먼저 도착한 적이 편대를 이동시켜도 뒤따르는 적의 목표 좌표가 어긋나지 않음)
do
  local wavesText = "wave 1\nenemy grunt 100 80\nenemy grunt 200 80\nenemy grunt 300 80\nenemy grunt 400 80\n"
  local gm = GameModel({ seed = 1, wavesText = wavesText })
  stepN(gm, 120, 1 / 60)
  local y0 = gm.enemies[1].y
  local d12 = gm.enemies[2].x - gm.enemies[1].x
  local d23 = gm.enemies[3].x - gm.enemies[2].x
  local d34 = gm.enemies[4].x - gm.enemies[3].x
  check("formation_spacing_preserved", math.abs(d12 - 100) < 1e-4 and math.abs(d23 - 100) < 1e-4 and math.abs(d34 - 100) < 1e-4,
    string.format("%.2f, %.2f, %.2f", d12, d23, d34))
  check("formation_y_aligned", gm.enemies[4].y == y0)
end

-- 5. 결정성: 동일 시드, 동일 dt 시퀀스
do
  local gmA = GameModel({ seed = 42 })
  local gmB = GameModel({ seed = 42 })
  stepN(gmA, 45, 1 / 60)
  stepN(gmB, 45, 1 / 60)
  local same = true
  for i = 1, #gmA.enemies do
    local a, b = gmA.enemies[i], gmB.enemies[i]
    if math.abs(a.x - b.x) > 1e-9 or math.abs(a.y - b.y) > 1e-9 or a.entering ~= b.entering then
      same = false
      break
    end
  end
  check("determinism", same)
end

print(string.format("test_wave_entry: %d passed, %d failed", passed, failed))
if failed > 0 then
  os.exit(1)
end
