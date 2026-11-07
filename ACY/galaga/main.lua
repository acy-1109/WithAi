-- main.lua
-- 2주차 겔러그 모놀리식: [과제 B - 보스 탄막(Bullet Pattern) 추가]
-- ⚠️ 모놀리식의 스파게티/수정 전파 체험: 보스 하나를 추가하기 위해 파일 전역 9곳 이상이 수정됨
-- [B1] 보스 상태 변수 & 상수
-- [B2] resetGame 보스 초기화
-- [B3] spawnBoss 생성 및 등장 조건
-- [B4] 보스 좌우 이동 로직
-- [B5] 보스 원형 방사 탄막 (18갈래 탄막 생성) + 적 총알 vx/vy 확장
-- [B6] 적 총알 2D 이동 및 경계 판정
-- [B7] 플레이어 총알 x 보스 HP 충돌 판정 및 승리 조건
-- [B8] 보스 렌더링 및 보스 HP 게이지 바
-- [B9] 승리(YOU WIN) 및 게임오버 화면 분기

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
local won = false -- [B1] 보스 격파 승리 플래그

local formationDir = 1
local enemyShootTimer = 0
local screenShake = 0
local flash = 0

-- [B1] 보스 엔티티 및 스폰 플래그
local boss = nil
local bossSpawned = false

local PLAYER_SPEED = 320
local BULLET_SPEED = 520
local BULLET_COOLDOWN = 0.25
local ENEMY_BULLET_SPEED = 240
local FORMATION_SPEED = 40
local DROP_STEP = 16

-- [B1] 보스 관련 상수
local BOSS_BULLET_SPEED = 180
local BOSS_SCORE_TRIGGER = 1000 -- 보스 등장 기준 점수

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

-- [B3] 보스 생성 함수
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

-- [B2] resetGame에 보스 관련 상태 리셋 전파
local function resetGame()
  player = {
    x = 300 - 20,
    y = 740,
    w = 40,
    h = 24,
    cooldown = 0,
  }
  bullets = {}
  enemyBullets = {}
  particles = {}
  score = 0
  lives = 3
  gameover = false
  won = false -- [B2]
  boss = nil -- [B2]
  bossSpawned = false -- [B2]
  formationDir = 1
  enemyShootTimer = 0.6
  screenShake = 0
  flash = 0
  spawnFormation()
end

-- 충돌 판정 (AABB)
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

  -- 1. 플레이어 이동 (A/D 및 화살표 키)
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

  -- 2. 플레이어 발사
  player.cooldown = player.cooldown - dt
  if love.keyboard.isDown("space") and player.cooldown <= 0 then
    bullets[#bullets + 1] = {
      x = player.x + player.w * 0.5 - 2,
      y = player.y,
      w = 4,
      h = 12,
    }
    player.cooldown = BULLET_COOLDOWN
  end

  -- 플레이어 총알 이동
  for i = #bullets, 1, -1 do
    local b = bullets[i]
    b.y = b.y - BULLET_SPEED * dt
    if b.y + b.h < 0 then
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

  -- 4. 적 랜덤 발사 ( [B5] 적 총알도 이제 vx, vy를 가지도록 자료구조 전파 )
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

  -- [B3] 일정 점수 이상이면 보스 등장
  if not bossSpawned and score >= BOSS_SCORE_TRIGGER then
    spawnBoss()
  end

  -- [B4][B5] 보스 이동 및 원형 방사 탄막 발사
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
      local n = 18 -- 18방향 원형 탄막
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

  -- [B6] 적/보스 총알 이동 (vx, vy 적용 및 4방향 경계 제거)
  for i = #enemyBullets, 1, -1 do
    local b = enemyBullets[i]
    b.x = b.x + (b.vx or 0) * dt
    b.y = b.y + (b.vy or ENEMY_BULLET_SPEED) * dt
    if b.y > 800 or b.y < -20 or b.x < -20 or b.x > 620 then
      table.remove(enemyBullets, i)
    end
  end

  -- 5. 충돌 처리
  -- 일반 적 격추
  for bi = #bullets, 1, -1 do
    local b = bullets[bi]
    for _, e in ipairs(enemies) do
      if e.alive and hit(b, e) then
        e.alive = false
        score = score + 100
        explode(e.x + e.w * 0.5, e.y + e.h * 0.5)
        table.remove(bullets, bi)
        break
      end
    end
  end

  -- [B7] 플레이어 총알 x 보스 피격 판정 (HP 차감 및 승리 처리)
  if boss and boss.alive then
    for bi = #bullets, 1, -1 do
      if hit(bullets[bi], boss) then
        boss.hp = boss.hp - 1
        explode(bullets[bi].x, bullets[bi].y)
        table.remove(bullets, bi)
        if boss.hp <= 0 then
          boss.alive = false
          score = score + 2000
          won = true
          gameover = true
        end
        break
      end
    end
  end

  -- 적/보스 총알 x 플레이어 피격 판정
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

  -- 편대 리스폰 (단, 보스가 등장한 이후에는 적 편대 리스폰 중단)
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

  -- 플레이어 총알 (노란색)
  love.graphics.setColor(1, 1, 0.3)
  for _, b in ipairs(bullets) do
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
  end

  -- 일반 적 편대 (빨간색)
  love.graphics.setColor(1, 0.4, 0.4)
  for _, e in ipairs(enemies) do
    if e.alive then
      love.graphics.rectangle("fill", e.x, e.y, e.w, e.h)
    end
  end

  -- [B8] 보스 렌더링 (자주색 대형 기체) + HP 게이지 바
  if boss and boss.alive then
    love.graphics.setColor(0.9, 0.3, 0.9)
    love.graphics.rectangle("fill", boss.x, boss.y, boss.w, boss.h)

    -- 보스 HP 게이지 배경 (어두운 회색)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 100, 48, 400, 10)
    -- 보스 HP 게이지 (빨간색)
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.rectangle("fill", 100, 48, 400 * (boss.hp / boss.maxhp), 10)
  end

  -- 적/보스 총알 (주황색)
  love.graphics.setColor(1, 0.6, 0.2)
  for _, b in ipairs(enemyBullets) do
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
  end

  -- 파티클
  love.graphics.setColor(1, 0.8, 0.2)
  for _, p in ipairs(particles) do
    love.graphics.rectangle("fill", p.x, p.y, 3, 3)
  end

  love.graphics.pop()

  -- HUD (점수, 라이프)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("SCORE  " .. score, 15, 12)
  love.graphics.printf("LIVES " .. lives, 0, 12, 585, "right")

  love.graphics.setColor(0.4, 0.9, 1)
  for i = 1, lives do
    love.graphics.rectangle("fill", 585 - (i * 18), 32, 14, 8)
  end

  -- [B9] 게임오버 / 승리(YOU WIN) 오버레이 화면 분기
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
