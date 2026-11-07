-- main.lua
-- 2주차 겔러그 모놀리식 [1단계: 플레이어 사각형 + 좌우 이동 + 화면 경계 클램프]

local player
local PLAYER_SPEED = 320

function love.load()
  love.graphics.setBackgroundColor(0.02, 0.02, 0.06)

  local winWidth = love.graphics.getWidth()
  local winHeight = love.graphics.getHeight()

  player = {
    w = 40,
    h = 24,
    x = winWidth * 0.5 - 20,
    y = winHeight - 60,
  }
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

  -- 2. 화면 경계 클램프
  if player.x < 0 then
    player.x = 0
  elseif player.x > winWidth - player.w then
    player.x = winWidth - player.w
  end
end

function love.draw()
  -- 플레이어 그리기 (하늘색 사각형)
  love.graphics.setColor(0.4, 0.9, 1)
  love.graphics.rectangle("fill", player.x, player.y, player.w, player.h)
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  end
end
