-- main.lua
-- 2주차 겔러그 모놀리식
-- [1단계: 플레이어 좌우 이동]
-- [2단계: Space 발사(쿨다운) + 총알 위로 이동]
-- [3단계: 적 편대(그리드) 생성 + 좌우 이동 + 끝에서 한 칸 하강]

local player
local bullets = {}
local enemies = {} -- ⚠️ 적 편대 목록을 담는 전역 상태 배열

local PLAYER_SPEED = 320
local BULLET_SPEED = 520
local BULLET_COOLDOWN = 0.25

local formationDir = 1
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

function love.load()
  love.graphics.setBackgroundColor(0.02, 0.02, 0.06)

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
  formationDir = 1
  spawnFormation()
end

function love.update(dt)
  local winWidth = love.graphics.getWidth()

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

  -- 3. 적 편대 이동 (좌우 이동 + 화면 끝 도달 시 반전 및 한 칸 하강)
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
end

function love.draw()
  -- 플레이어 그리기 (하늘색)
  love.graphics.setColor(0.4, 0.9, 1)
  love.graphics.rectangle("fill", player.x, player.y, player.w, player.h)

  -- 플레이어 총알 (노란색)
  love.graphics.setColor(1, 1, 0.3)
  for _, b in ipairs(bullets) do
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
  end

  -- 적 편대 그리기 (빨간색)
  love.graphics.setColor(1, 0.4, 0.4)
  for _, e in ipairs(enemies) do
    if e.alive then
      love.graphics.rectangle("fill", e.x, e.y, e.w, e.h)
    end
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  end
end
