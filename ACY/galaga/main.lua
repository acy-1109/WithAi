-- main.lua
-- 2주차 겔러그 모놀리식 (구현 순서 1~7단계 완성본)
-- [1단계: 플레이어 좌우 이동]
-- [2단계: Space 발사(쿨다운) + 총알 위로 이동]
-- [3단계: 적 편대(그리드) 생성 + 좌우 이동 + 끝에서 한 칸 하강]
-- [4단계: 적 랜덤 발사 + 적 총알 아래로 이동]
-- [5단계: 충돌 판정 (내 총알 x 적: 점수+파괴, 적 총알 x 플레이어: 라이프 감소)]
-- [6단계: 연출 (파괴 파티클, flash 번쩍임, 피격 shake 흔들림)]
-- [7단계: HUD(점수/라이프 아이콘) + 게임오버/재시작(resetGame)]

-- 파일 전역 상태 덩어리(모놀리식 전형)
local player
local bullets = {}
local enemies = {}
local enemyBullets = {}
local particles = {}
local score = 0
local lives = 3
local gameover = false

local formationDir = 1
local enemyShootTimer = 0
local screenShake = 0
local flash = 0

local PLAYER_SPEED = 320
local BULLET_SPEED = 520
local BULLET_COOLDOWN = 0.25
local ENEMY_BULLET_SPEED = 240
local FORMATION_SPEED = 40
local DROP_STEP = 16

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

-- 7단계: 전역 상태 초기화 함수 (재시작 시 깨끗하게 리셋)
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

-- ⚠️ Model-View 결합: 로직 한복판에서 연출 직접 생성
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
  math.randomseed(os.time()) -- ⚠️ 비결정적 시드
  resetGame()
end

function love.update(dt)
  -- 7단계: 게임오버 시 모든 물리 및 적/총알 이동 정지
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
      }
    end
  end

  -- 적 총알 이동
  for i = #enemyBullets, 1, -1 do
    local b = enemyBullets[i]
    b.y = b.y + ENEMY_BULLET_SPEED * dt
    if b.y > 800 then
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
        explode(e.x + e.w * 0.5, e.y + e.h * 0.5) -- ⚠️ 로직이 연출 직접 호출
        table.remove(bullets, bi)
        break
      end
    end
  end

  for i = #enemyBullets, 1, -1 do
    if hit(enemyBullets[i], player) then
      table.remove(enemyBullets, i)
      lives = lives - 1
      screenShake = 0.3 -- ⚠️ 로직이 shake 상태 직접 조작
      if lives <= 0 then
        gameover = true
      end
    end
  end

  -- 6. 파티클 이동 및 수명 소멸
  for i = #particles, 1, -1 do
    local p = particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(particles, i)
    end
  end

  -- 다음 편대 리스폰
  local anyAlive = false
  for _, e in ipairs(enemies) do
    if e.alive then
      anyAlive = true
      break
    end
  end
  if not anyAlive then
    spawnFormation()
  end
end

function love.draw()
  -- 화면 흔들림 연출
  local ox, oy = 0, 0
  if screenShake > 0 then
    ox = (math.random() - 0.5) * 10
    oy = (math.random() - 0.5) * 10
  end

  love.graphics.push()
  love.graphics.translate(ox, oy)

  -- 피격/파괴 플래시
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

  -- 적 편대 (빨간색)
  love.graphics.setColor(1, 0.4, 0.4)
  for _, e in ipairs(enemies) do
    if e.alive then
      love.graphics.rectangle("fill", e.x, e.y, e.w, e.h)
    end
  end

  -- 적 총알 (주황색)
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

  -- ========================================================
  -- 7단계: HUD (점수, 라이프 비행기 아이콘 + 텍스트)
  -- ========================================================
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("SCORE  " .. score, 15, 12)
  love.graphics.printf("LIVES " .. lives, 0, 12, 585, "right")

  -- 라이프를 작은 비행기 사각형 아이콘으로도 우측 상단에 표시
  love.graphics.setColor(0.4, 0.9, 1)
  for i = 1, lives do
    love.graphics.rectangle("fill", 585 - (i * 18), 32, 14, 8)
  end

  -- 7단계: 게임오버 안내 및 재시작 UI
  if gameover then
    -- 어두운 반투명 오버레이
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 600, 800)

    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.printf("GAME OVER", 0, 350, 600, "center")

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press R to Restart", 0, 390, 600, "center")
    love.graphics.printf("Final Score: " .. score, 0, 420, 600, "center")
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "r" and gameover then
    resetGame() -- 7단계: 안전한 전역 상태 리셋
  end
end
