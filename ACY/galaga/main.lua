-- main.lua
-- 2주차 겔러그 모놀리식
-- [1단계: 플레이어 좌우 이동]
-- [2단계: Space 발사(쿨다운) + 총알 위로 이동]

local player
local bullets = {} -- ⚠️ 총알 목록을 담는 전역 상태 배열

local PLAYER_SPEED = 320
local BULLET_SPEED = 520
local BULLET_COOLDOWN = 0.25

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
end

function love.update(dt)
  local winWidth = love.graphics.getWidth()

  -- 1. 좌우 이동 입력 (화살표 키 및 A/D)
  if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
    player.x = player.x - PLAYER_SPEED * dt
  end
  if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
    player.x = player.x + PLAYER_SPEED * dt
  end

  -- 화면 경계 클램프
  if player.x < 0 then
    player.x = 0
  elseif player.x > winWidth - player.w then
    player.x = winWidth - player.w
  end

  -- 2. Space 발사 및 쿨다운 처리
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

  -- 총알 이동 및 화면 밖 제거
  for i = #bullets, 1, -1 do
    local b = bullets[i]
    b.y = b.y - BULLET_SPEED * dt
    if b.y + b.h < 0 then
      table.remove(bullets, i)
    end
  end
end

function love.draw()
  -- 플레이어 그리기 (하늘색 사각형)
  love.graphics.setColor(0.4, 0.9, 1)
  love.graphics.rectangle("fill", player.x, player.y, player.w, player.h)

  -- 총알 그리기 (노란색 직사각형)
  love.graphics.setColor(1, 1, 0.3)
  for _, b in ipairs(bullets) do
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  end
end
