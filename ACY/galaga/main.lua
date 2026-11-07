-- main.lua
-- 2주차 겔러그 모놀리식: [과제 A - 유도 미사일(F키)] + [과제 B - 보스 탄막]
-- ⚠️ 모놀리식 안티패턴의 정점: 기능 2개가 결합되면서 수정이 파일 전체에 무차별 번짐

-- ========================================================
-- 파일 전역 상태 덩어리
-- ========================================================
local player
local bullets = {}
local enemies = {}
local enemyBullets = {}
local particles = {}
local score = 0
local lives = 3
local gameover = false
local won = false

-- 유도 미사일 탄수 및 점수 보상 관리
local MAX_MISSILES = 3 -- 최대 개수 제한
local missiles = 3 -- 기본 3개 지급
local nextMissileScore = 500 -- 500점 달성 시 1개씩 추가

-- 유도 미사일 탄수 및 점수 보상 관리
local missiles = 3 -- 기본 3개 지급
local nextMissileScore = 500 -- 500점 달성 시 1개씩 추가

local formationDir = 1
local enemyShootTimer = 0
local screenShake = 0
local flash = 0

-- 보스 엔티티
local boss = nil
local bossSpawned = false

local PLAYER_SPEED = 320
local BULLET_SPEED = 520
local BULLET_COOLDOWN = 0.25
local ENEMY_BULLET_SPEED = 240
local FORMATION_SPEED = 40
local DROP_STEP = 16

-- 드라마틱한 유도 미사일 상수
local HOMING_SPEED = 480
local HOMING_TURN = 0.16 -- 선회 추종율을 2배로 올려 날카롭게 꺾이도록 강화
local MISSILE_COOLDOWN = 0.45 -- 쿨다운 단축

-- 보스 상수
local BOSS_BULLET_SPEED = 180
local BOSS_SCORE_TRIGGER = 1000

-- 적 편대 생성 (4행 8열)
local function spawnFormation()
  enemies = {}
  for row = 0, 3 do
    for col = 0, 7 do
      enemies[#enemies + 1] = {
        x = 60 + col * 60,
        y = 60 + row * 50,
        w = 36,
        h = 28,
        alive = true,
      }
    end
  end
end

-- 보스 생성 함수
local function spawnBoss()
  boss = {
    x = 240,
    y = 70,
    w = 120,
    h = 60,
    hp = 40,
    maxhp = 40,
    alive = true,
    dir = 1,
    shootTimer = 1.0,
  }
  bossSpawned = true
end

-- 가장 가까운 적(또는 보스)의 중심 좌표 탐색 함수
local function nearestTarget(x, y)
  local tx, ty, bestDist = nil, nil, math.huge

  for _, e in ipairs(enemies) do
    if e.alive then
      local cx = e.x + e.w * 0.5
      local cy = e.y + e.h * 0.5
      local distSq = (cx - x) * (cx - x) + (cy - y) * (cy - y)
      if distSq < bestDist then
        bestDist = distSq
        tx, ty = cx, cy
      end
    end
  end

  if boss and boss.alive then
    local cx = boss.x + boss.w * 0.5
    local cy = boss.y + boss.h * 0.5
    local distSq = (cx - x) * (cx - x) + (cy - y) * (cy - y)
    if distSq < bestDist then
      tx, ty = cx, cy
    end
  end

  return tx, ty
end

local function resetGame()
  player = {
    x = 300 - 20,
    y = 740,
    w = 40,
    h = 24,
    cooldown = 0,
    missileCd = 0,
  }
  bullets = {}
  enemyBullets = {}
  particles = {}
  score = 0
  lives = 3
  missiles = 3
  nextMissileScore = 500
  gameover = false
  won = false
  boss = nil
  bossSpawned = false
  formationDir = 1
  enemyShootTimer = 0.6
  screenShake = 0
  flash = 0
  spawnFormation()
end

local function hit(a, b)
  return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function explode(x, y)
  for i = 1, 12 do
    local angle = math.random() * math.pi * 2
    local speed = 40 + math.random() * 120
    particles[#particles + 1] = {
      x = x,
      y = y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = 0.5,
    }
  end
  flash = 0.06
end

function love.load()
  love.graphics.setBackgroundColor(0.02, 0.02, 0.06)
  math.randomseed(os.time())
  resetGame()
end

function love.update(dt)
  if gameover then
    return
  end

  if screenShake > 0 then
    screenShake = screenShake - dt
  end
  if flash > 0 then
    flash = flash - dt
  end

  -- 1. 플레이어 이동
  if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
    player.x = player.x - PLAYER_SPEED * dt
  end
  if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
    player.x = player.x + PLAYER_SPEED * dt
  end

  if player.x < 0 then
    player.x = 0
  elseif player.x > 600 - player.w then
    player.x = 600 - player.w
  end

  -- 2-1. Space 일반 총알 발사
  player.cooldown = player.cooldown - dt
  if love.keyboard.isDown("space") and player.cooldown <= 0 then
    bullets[#bullets + 1] = {
      x = player.x + player.w * 0.5 - 2,
      y = player.y,
      w = 4,
      h = 12,
      vx = 0,
      vy = -BULLET_SPEED,
      homing = false,
    }
    player.cooldown = BULLET_COOLDOWN
  end

  -- 2-2. F키 유도 미사일 발사 (보유 탄수 확인 및 차감)
  player.missileCd = player.missileCd - dt
  if love.keyboard.isDown("f") and player.missileCd <= 0 and missiles > 0 then
    missiles = missiles - 1
    local spread = (math.random() - 0.5) * 360 -- 발사 시 좌우로 확 튕겨져 나가는 초기 수평 속도
    bullets[#bullets + 1] = {
      x = player.x + player.w * 0.5 - 4,
      y = player.y,
      w = 8,
      h = 14,
      vx = spread,
      vy = -260, -- 위로 부드럽게 솟구침
      homing = true,
    }
    player.missileCd = MISSILE_COOLDOWN
  end

  -- 플레이어 총알 이동 (드라마틱 유도 선회 알고리즘)
  for i = #bullets, 1, -1 do
    local b = bullets[i]
    if b.homing then
      local tx, ty = nearestTarget(b.x, b.y)
      if tx and ty then
        local dx = tx - b.x
        local dy = ty - b.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0 then
          local desiredVx = (dx / dist) * HOMING_SPEED
          local desiredVy = (dy / dist) * HOMING_SPEED

          -- 선회력 강화 (타겟을 향해 다이내믹하게 휨)
          b.vx = b.vx + (desiredVx - b.vx) * HOMING_TURN
          b.vy = b.vy + (desiredVy - b.vy) * HOMING_TURN

          local currentSpeed = math.sqrt(b.vx * b.vx + b.vy * b.vy)
          if currentSpeed > 0 then
            b.vx = (b.vx / currentSpeed) * HOMING_SPEED
            b.vy = (b.vy / currentSpeed) * HOMING_SPEED
          end
        end
      end
    end

    b.x = b.x + (b.vx or 0) * dt
    b.y = b.y + (b.vy or -BULLET_SPEED) * dt

    -- 상하좌우 화면 밖 제거
    if b.y + b.h < -30 or b.y > 830 or b.x < -30 or b.x > 630 then
      table.remove(bullets, i)
    end
  end

  -- 3. 적 편대 이동
  local minx, maxx = math.huge, -math.huge
  for _, e in ipairs(enemies) do
    if e.alive then
      minx = math.min(minx, e.x)
      maxx = math.max(maxx, e.x + e.w)
    end
  end

  if minx ~= math.huge then
    local dx = formationDir * FORMATION_SPEED * dt
    if (maxx + dx > 590) or (minx + dx < 10) then
      formationDir = -formationDir
      for _, e in ipairs(enemies) do
        e.y = e.y + DROP_STEP
      end
    else
      for _, e in ipairs(enemies) do
        e.x = e.x + dx
      end
    end
  end

  -- 4. 적 랜덤 발사
  enemyShootTimer = enemyShootTimer - dt
  if enemyShootTimer <= 0 then
    enemyShootTimer = 0.6
    local alive = {}
    for _, e in ipairs(enemies) do
      if e.alive then
        alive[#alive + 1] = e
      end
    end
    if #alive > 0 then
      local shooter = alive[math.random(#alive)]
      enemyBullets[#enemyBullets + 1] = {
        x = shooter.x + shooter.w * 0.5 - 2,
        y = shooter.y + shooter.h,
        w = 4,
        h = 12,
        vx = 0,
        vy = ENEMY_BULLET_SPEED,
      }
    end
  end

  -- 보스 스폰 조건
  if not bossSpawned and score >= BOSS_SCORE_TRIGGER then
    spawnBoss()
  end

  -- 보스 이동 및 원형 탄막
  if boss and boss.alive then
    boss.x = boss.x + boss.dir * 70 * dt
    if boss.x < 10 then
      boss.x, boss.dir = 10, 1
    elseif boss.x > 590 - boss.w then
      boss.x, boss.dir = 590 - boss.w, -1
    end

    boss.shootTimer = boss.shootTimer - dt
    if boss.shootTimer <= 0 then
      boss.shootTimer = 1.2
      local cx, cy = boss.x + boss.w * 0.5, boss.y + boss.h * 0.5
      local n = 18
      for k = 0, n - 1 do
        local a = (k / n) * math.pi * 2
        enemyBullets[#enemyBullets + 1] = {
          x = cx,
          y = cy,
          w = 6,
          h = 6,
          vx = math.cos(a) * BOSS_BULLET_SPEED,
          vy = math.sin(a) * BOSS_BULLET_SPEED,
        }
      end
    end
  end

  -- 적 총알 이동
  for i = #enemyBullets, 1, -1 do
    local b = enemyBullets[i]
    b.x = b.x + (b.vx or 0) * dt
    b.y = b.y + (b.vy or ENEMY_BULLET_SPEED) * dt
    if b.y > 800 or b.y < -20 or b.x < -20 or b.x > 620 then
      table.remove(enemyBullets, i)
    end
  end

  -- 5. 충돌 처리
  for bi = #bullets, 1, -1 do
    local b = bullets[bi]
    for _, e in ipairs(enemies) do
      if e.alive and hit(b, e) then
        e.alive = false
        score = score + 100
        -- 500점 달성할 때마다 유도탄 1개 충전 (최대 3개 제한)
        while score >= nextMissileScore do
          if missiles < MAX_MISSILES then
            missiles = missiles + 1
          end
          nextMissileScore = nextMissileScore + 500
        end
        -- 500점 달성할 때마다 유도탄 1개 충전 (최대 3개 제한)
        while score >= nextMissileScore do
          if missiles < MAX_MISSILES then
            missiles = missiles + 1
          end
          nextMissileScore = nextMissileScore + 500
        end
        explode(e.x + e.w * 0.5, e.y + e.h * 0.5)
        table.remove(bullets, bi)
        break
      end
    end
  end

  if boss and boss.alive then
    for bi = #bullets, 1, -1 do
      if hit(bullets[bi], boss) then
        boss.hp = boss.hp - 1
        explode(bullets[bi].x, bullets[bi].y)
        table.remove(bullets, bi)
        if boss.hp <= 0 then
          boss.alive = false
          score = score + 2000
          while score >= nextMissileScore do
            if missiles < MAX_MISSILES then
              missiles = missiles + 1
            end
            nextMissileScore = nextMissileScore + 500
          end
          while score >= nextMissileScore do
            if missiles < MAX_MISSILES then
              missiles = missiles + 1
            end
            nextMissileScore = nextMissileScore + 500
          end
          won = true
          gameover = true
        end
        break
      end
    end
  end

  for i = #enemyBullets, 1, -1 do
    if hit(enemyBullets[i], player) then
      table.remove(enemyBullets, i)
      lives = lives - 1
      screenShake = 0.3
      if lives <= 0 then
        gameover = true
      end
    end
  end

  -- 파티클 업데이트
  for i = #particles, 1, -1 do
    local p = particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(particles, i)
    end
  end

  -- 편대 리스폰
  local anyAlive = false
  for _, e in ipairs(enemies) do
    if e.alive then
      anyAlive = true
      break
    end
  end
  if not anyAlive and not bossSpawned then
    spawnFormation()
  end
end

function love.draw()
  local ox, oy = 0, 0
  if screenShake > 0 then
    ox = (math.random() - 0.5) * 10
    oy = (math.random() - 0.5) * 10
  end

  love.graphics.push()
  love.graphics.translate(ox, oy)

  if flash > 0 then
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.rectangle("fill", 0, 0, 600, 800)
  end

  -- 플레이어 (하늘색)
  love.graphics.setColor(0.4, 0.9, 1)
  love.graphics.rectangle("fill", player.x, player.y, player.w, player.h)

  -- 파티클 / 미사일 궤적 먼저 그리기
  love.graphics.setColor(1, 0.8, 0.2)
  for _, p in ipairs(particles) do
    love.graphics.rectangle("fill", p.x, p.y, 3, 3)
  end

  -- 총알 렌더링
  for _, b in ipairs(bullets) do
    if b.homing then
      love.graphics.setColor(0.2, 1.0, 0.5) -- 밝은 형광 민트색 대형 미사일
    else
      love.graphics.setColor(1, 1, 0.3)
    end
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
  end

  -- 적 편대 (빨간색)
  love.graphics.setColor(1, 0.4, 0.4)
  for _, e in ipairs(enemies) do
    if e.alive then
      love.graphics.rectangle("fill", e.x, e.y, e.w, e.h)
    end
  end

  -- 보스 렌더링
  if boss and boss.alive then
    love.graphics.setColor(0.9, 0.3, 0.9)
    love.graphics.rectangle("fill", boss.x, boss.y, boss.w, boss.h)

    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 100, 48, 400, 10)
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.rectangle("fill", 100, 48, 400 * (boss.hp / boss.maxhp), 10)
  end

  -- 적 총알
  love.graphics.setColor(1, 0.6, 0.2)
  for _, b in ipairs(enemyBullets) do
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
  end

  love.graphics.pop()

  -- HUD
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("SCORE  " .. score, 15, 12)
  love.graphics.printf("LIVES " .. lives, 0, 12, 585, "right")

  -- LIVES 아래에 유도탄(MISSILE) 보유량을 유도탄 색상(민트/초록) 칸으로 표시
  love.graphics.setColor(0.3, 1.0, 0.6)
  for i = 1, missiles do
    love.graphics.rectangle("fill", 585 - (i * 18), 32, 14, 8)
  end

  if gameover then
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, 600, 800)

    if won then
      love.graphics.setColor(0.3, 1, 0.4)
      love.graphics.printf("YOU WIN!", 0, 340, 600, "center")
    else
      love.graphics.setColor(1, 0.3, 0.3)
      love.graphics.printf("GAME OVER", 0, 340, 600, "center")
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Final Score: " .. score, 0, 385, 600, "center")
    love.graphics.printf("Press R to Restart", 0, 420, 600, "center")
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "r" and gameover then
    resetGame()
  end
end
