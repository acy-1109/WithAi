-- r4_enemy_ai_test.lua
-- R4(근접형 적 SprinterEnemy 의 wait -> charge -> return FSM + 결정성 + 충돌) 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local EnemyModel = require("EnemyModel")
local GameModel = require("GameModel")
local Rng = require("rng")

local function stepFrames(e, dt, frames, ctx)
  for _ = 1, frames do
    e:updateAI(dt, ctx)
  end
end

h.test("R4: SprinterEnemy 대기(wait) -> 돌진(charge) 상태 전이", function()
  local e = EnemyModel.create("sprinter", 100, 80)
  local ctx = {
    rng = Rng(42),
    player = {
      centerX = function() return 300 end,
      centerY = function() return 700 end,
    },
    width = 600,
    height = 800,
  }
  local okInitial = (e.aiState == "wait" and e:inFormation() == true)

  -- 최대 대기(2.7s) + 재시도(0.6s) 이상 진행하면 반드시 charge 전이
  local transitioned = false
  for _ = 1, 400 do
    e:updateAI(1 / 60, ctx)
    if e.aiState == "charge" then
      transitioned = true
      break
    end
  end

  return okInitial and transitioned and e:inFormation() == false and e.vy > 0
end)

h.test("R4: 돌진(charge) -> 복귀(return) -> 대기(wait) 순환 전이", function()
  local e = EnemyModel.create("sprinter", 200, 100)
  local ctx = {
    rng = Rng(7),
    player = {
      centerX = function() return 200 end,
      centerY = function() return 740 end,
    },
    width = 600,
    height = 800,
  }

  -- wait -> charge 대기
  local enteredCharge = false
  for _ = 1, 400 do
    e:updateAI(1 / 60, ctx)
    if e.aiState == "charge" then
      enteredCharge = true
      break
    end
  end

  -- charge -> 화면 하단 밖(y > 800) 통과 후 return 진입 및 상단 밖(-h) 래핑 확인
  local passedBottom = false
  local enteredReturn = false
  local wrappedTop = false
  for _ = 1, 300 do
    e:updateAI(1 / 60, ctx)
    if e.aiState == "charge" and e.y > 740 then
      passedBottom = true
    end
    if e.aiState == "return" then
      enteredReturn = true
      wrappedTop = (e.y < 0)
      break
    end
  end

  -- return -> wait 복귀 및 원위치(200, 100) 스냅 확인
  local returnedWait = false
  for _ = 1, 400 do
    e:updateAI(1 / 60, ctx)
    if e.aiState == "wait" then
      returnedWait = true
      break
    end
  end

  return enteredCharge and passedBottom and enteredReturn and wrappedTop and returnedWait
    and math.abs(e.x - 200) < 1e-6 and math.abs(e.y - 100) < 1e-6
    and e:inFormation() == true
end)

h.test("R4: 돌진 중 플레이어와 충돌 시 플레이어 피격 후 적은 소멸하지 않고 복귀", function()
  local g = GameModel({
    width = 600,
    height = 800,
    seed = 10,
    wavesText = "wave 1\nenemy sprinter 280 60\n",
  })
  local e = g.enemies[1]
  local startLives = g.lives

  -- sprinter 가 charge 상태가 될 때까지 진행
  for _ = 1, 400 do
    g:update(1 / 60, { move = 0, fire = false })
    if e.aiState == "charge" then
      break
    end
  end
  local wasCharging = (e.aiState == "charge")
  g:drainEvents()

  -- 강제로 플레이어 위치와 겹치게 배치 후 충돌 처리 검증
  e.x = g.player.x
  e.y = g.player.y
  g:_resolveCollisions()
  local evts = g:drainEvents()

  local sawHit = false
  for i = 1, #evts do
    if evts[i].type == "player_hit" then
      sawHit = true
      break
    end
  end

  return wasCharging
    and g.lives == startLives - 1
    and sawHit
    and e.alive == true
    and e.aiState == "return"
    and e.y == -e.h
end)

h.test("R4: SniperEnemy wait -> aim -> fire -> wait 전이 및 조준 3갈래 분열탄", function()
  local g = GameModel({
    width = 600,
    height = 800,
    seed = 21,
    wavesText = "wave 1\nenemy sniper 100 80\n",
  })
  local s = g.enemies[1]
  -- 플레이어를 오른쪽으로 이동시켜 대각선 조준 확인
  g.player.x = 460

  local sawWait = (s.aiState == "wait")
  local sawAim = false
  local sawFire = false
  local sawReturnWait = false
  local sawSingleAimedBullet = false
  local sawSplitThreeBullets = false

  for _ = 1, 360 do
    g:update(1 / 60, { move = 0, fire = false })
    if s.aiState == "aim" then
      sawAim = true
    elseif s.aiState == "fire" then
      sawFire = true
      if #g.enemyBullets == 1 and g.enemyBullets[1].vx > 0 then
        sawSingleAimedBullet = true
      end
    elseif sawFire and s.aiState == "wait" then
      sawReturnWait = true
    end
    if #g.enemyBullets == 3 then
      local b1, b2, b3 = g.enemyBullets[1], g.enemyBullets[2], g.enemyBullets[3]
      if b1.vx ~= b2.vx and b2.vx ~= b3.vx and b1.vx ~= b3.vx then
        sawSplitThreeBullets = true
        break
      end
    end
  end

  return sawWait and sawAim and sawFire and sawReturnWait
    and sawSingleAimedBullet and sawSplitThreeBullets
end)

h.test("R4: 동일 시드 2회 실행 시 적 AI 상태·위치·결과가 완전히 동일하다", function()
  local wave = "wave 1\nenemy sprinter 120 80\nenemy sprinter 300 80\nenemy sniper 420 80\nenemy grunt 200 120\n"
  local g1 = GameModel({ width = 600, height = 800, seed = 12345, wavesText = wave })
  local g2 = GameModel({ width = 600, height = 800, seed = 12345, wavesText = wave })

  for step = 1, 240 do
    local move = (step % 60 < 30) and 1 or -1
    g1:update(1 / 60, { move = move, fire = false })
    g2:update(1 / 60, { move = move, fire = false })
  end

  if #g1.enemies ~= #g2.enemies or #g1.enemyBullets ~= #g2.enemyBullets
    or g1.lives ~= g2.lives or g1.score ~= g2.score then
    return false
  end
  for i = 1, #g1.enemies do
    local a, b = g1.enemies[i], g2.enemies[i]
    if a.x ~= b.x or a.y ~= b.y or a.aiState ~= b.aiState or a.alive ~= b.alive then
      return false
    end
  end
  return true
end)

h.finish()
