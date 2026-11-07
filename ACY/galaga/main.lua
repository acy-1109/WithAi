-- main.lua
-- 2주차 겔러그 모놀리식
-- [1단계: 플레이어 좌우 이동]
-- [2단계: Space 발사(쿨다운) + 총알 위로 이동]
-- [3단계: 적 편대(그리드) 생성 + 좌우 이동 + 끝에서 한 칸 하강]
-- [4단계: 적 랜덤 발사 + 적 총알 아래로 이동]
-- [5단계: 충돌 판정 (내 총알 x 적: 점수+파괴, 적 총알 x 플레이어: 라이프 감소)]
-- [6단계: 연출 - 파괴 파티클, 화면 번쩍임(flash), 피격 시 화면 흔들림(shake)]

local player
local bullets = {}
local enemies = {}
local enemyBullets = {}
local particles = {}

local score = 0
local lives = 3
local gameover = false

local screenShake = 0
local flash = 0

local PLAYER_SPEED = 320
local BULLET_SPEED = 520
local BULLET_COOLDOWN = 0.25

local formationDir = 1
local FORMATION_SPEED = 40
local DROP_STEP = 16

local enemyShootTimer = 0
local ENEMY_SHOOT_INTERVAL = 0.6
local ENEMY_BULLET_SPEED = 240

-- 충돌 판정 함수 (AABB)
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

function love.load()
  love.graphics.setBackgroundColor(0.02, 0.02, 0.06)
  math.randomseed(os.time())

  player = {
    w = 40,
    h = 24,
    x = 300 - 20,
    y = 740,
    cooldown = 0,
  }
  bullets = {}
  enemyBullets = {}
  particles = {}
  score = 0
  lives = 3
  gameover = false
  screenShake = 0
  flash = 0
  formationDir = 1
  enemyShootTimer = ENEMY_SHOOT_INTERVAL
  spawnFormation()
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

  -- 플레이어 총알 이동 및 화면 밖 제거
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
    enemyShootTimer = ENEMY_SHOOT_INTERVAL
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

  -- 적 총알 이동 및 화면 아래 밖 제거
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
        explode(e.x + e.w * 0.5, e.y + e.h * 0.5)
        table.remove(bullets, bi)
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

  -- 리스폰
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

  -- HUD 표시 (600 x 800 규격에 맞춰 정렬)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("SCORE " .. score, 10, 10)
  love.graphics.printf("LIVES " .. lives, 0, 10, 590, "right")

  if gameover then
    love.graphics.printf("GAME OVER\nPress R to Restart", 0, 380, 600, "center")
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "r" and gameover then
    love.load()
  end
end
