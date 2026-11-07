-- main.lua
-- 2주차 겔러그 모놀리식
-- [1단계: 플레이어 좌우 이동]
-- [2단계: Space 발사(쿨다운) + 총알 위로 이동]
-- [3단계: 적 편대(그리드) 생성 + 좌우 이동 + 끝에서 한 칸 하강]
-- [4단계: 적 랜덤 발사 + 적 총알 아래로 이동]
-- [5단계: 충돌 판정 (내 총알 x 적: 점수+파괴, 적 총알 x 플레이어: 라이프 감소)]

local player
local bullets = {}
local enemies = {}
local enemyBullets = {}

local score = 0 -- ⚠️ 점수 상태
local lives = 3 -- ⚠️ 라이프 상태
local gameover = false -- ⚠️ 게임오버 상태

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

  local winWidth = love.graphics.getWidth()
  local winHeight = love.graphics.getHeight()

  player = {
    w = 40,
    h = 24,
    x = winWidth * 0.5 - 20,
    y = winHeight - 60,
    cooldown = 0,
  }
  bullets = {}
  enemyBullets = {}
  score = 0
  lives = 3
  gameover = false
  formationDir = 1
  enemyShootTimer = ENEMY_SHOOT_INTERVAL
  spawnFormation()
end

function love.update(dt)
  if gameover then
    return
  end

  local winWidth = love.graphics.getWidth()
  local winHeight = love.graphics.getHeight()

  -- 1. 플레이어 이동
  if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
    player.x = player.x - PLAYER_SPEED * dt
  end
  if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
    player.x = player.x + PLAYER_SPEED * dt
  end

  if player.x < 0 then
    player.x = 0
  elseif player.x > winWidth - player.w then
    player.x = winWidth - player.w
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
    if (maxx + dx > winWidth - 10) or (minx + dx < 10) then
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
    if b.y > winHeight then
      table.remove(enemyBullets, i)
    end
  end

  -- ========================================================
  -- 5. 충돌 처리
  -- ========================================================
  -- 5-1) 내 총알 x 적 (점수 획득 + 적 파괴 + 총알 제거)
  for bi = #bullets, 1, -1 do
    local b = bullets[bi]
    for _, e in ipairs(enemies) do
      if e.alive and hit(b, e) then
        e.alive = false
        score = score + 100
        table.remove(bullets, bi)
        break
      end
    end
  end

  -- 5-2) 적 총알 x 플레이어 (라이프 감소 + 총알 제거 + 게임오버 체크)
  for i = #enemyBullets, 1, -1 do
    if hit(enemyBullets[i], player) then
      table.remove(enemyBullets, i)
      lives = lives - 1
      if lives <= 0 then
        gameover = true
      end
    end
  end

  -- 적 편대 전멸 시 다음 편대 리스폰
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

  -- 점수 및 라이프 표시
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("SCORE: " .. score, 10, 10)
  love.graphics.print("LIVES: " .. lives, 500, 10)

  if gameover then
    love.graphics.printf("GAME OVER\nPress R to Restart", 0, 380, love.graphics.getWidth(), "center")
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "r" and gameover then
    love.load()
  end
end
