-- main.lua
-- Pong 2: 모듈 분리 및 .new 기반 인스턴스 생성 방식 (ACY/pong2)

local G = require("global")
local Paddle = require("paddle")
local Ball = require("ball")

--------------------------------------------------
-- 원과 사각형 충돌 검사 (Circle-AABB Clamping)
--------------------------------------------------
local function checkCollision(b, p)
  local closestX = math.max(p.x, math.min(b.x, p.x + p.w))
  local closestY = math.max(p.y, math.min(b.y, p.y + p.h))

  local dx = b.x - closestX
  local dy = b.y - closestY
  return (dx * dx + dy * dy) <= (b.radius * b.radius)
end

--------------------------------------------------
-- 게임 상태 변수
--------------------------------------------------
local gameState = "serve" -- "serve" | "play"
local servingPlayer = 1   -- 1: 왼쪽 서브, 2: 오른쪽 서브
local accumulator = 0
local leftPaddle
local rightPaddle
local ball
local fontLarge
local fontScore
local fontSmall

-- 고정 타임스텝 물리/로직 스텝
local function step(dt)
  leftPaddle:update(dt)
  rightPaddle:update(dt)

  if gameState == "play" then
    ball:update(dt)

    -- 왼쪽 패들 충돌
    if checkCollision(ball, leftPaddle) and ball.vx < 0 then
      ball.x = leftPaddle.x + leftPaddle.w + ball.radius
      ball.vx = -ball.vx * G.BALL_SPEED_INCREMENT
      local paddleCenter = leftPaddle.y + leftPaddle.h / 2
      ball.vy = (ball.y - paddleCenter) * 8
    end

    -- 오른쪽 패들 충돌
    if checkCollision(ball, rightPaddle) and ball.vx > 0 then
      ball.x = rightPaddle.x - ball.radius
      ball.vx = -ball.vx * G.BALL_SPEED_INCREMENT
      local paddleCenter = rightPaddle.y + rightPaddle.h / 2
      ball.vy = (ball.y - paddleCenter) * 8
    end

    -- 득점 처리
    if ball.x + ball.radius < 0 then
      rightPaddle.score = rightPaddle.score + 1
      servingPlayer = 1
      gameState = "serve"
      ball:reset(1)
    elseif ball.x - ball.radius > G.WINDOW_WIDTH then
      leftPaddle.score = leftPaddle.score + 1
      servingPlayer = 2
      gameState = "serve"
      ball:reset(-1)
    end
  end
end

--------------------------------------------------
-- LÖVE 수명주기 콜백
--------------------------------------------------
function love.load()
  math.randomseed(os.time())
  fontSmall = love.graphics.newFont(18)
  fontLarge = love.graphics.newFont(32)
  fontScore = love.graphics.newFont(48)

  -- .new 방식으로 인스턴스 생성
  leftPaddle = Paddle.new(30, (G.WINDOW_HEIGHT - G.PADDLE_HEIGHT) / 2, "w", "s")
  rightPaddle = Paddle.new(G.WINDOW_WIDTH - 30 - G.PADDLE_WIDTH, (G.WINDOW_HEIGHT - G.PADDLE_HEIGHT) / 2, "up", "down")
  ball = Ball.new()
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "return" or key == "kpenter" then
    if gameState == "serve" then
      gameState = "play"
    end
  elseif key == "r" then
    leftPaddle.score = 0
    rightPaddle.score = 0
    servingPlayer = 1
    gameState = "serve"
    ball:reset(1)
  end
end

function love.update(dt)
  if dt > G.MAX_FRAME_TIME then
    dt = G.MAX_FRAME_TIME
  end

  accumulator = accumulator + dt
  while accumulator >= G.FIXED_DT do
    leftPaddle:savePrev()
    rightPaddle:savePrev()
    ball:savePrev()

    step(G.FIXED_DT)
    accumulator = accumulator - G.FIXED_DT
  end
end

function love.draw()
  local alpha = accumulator / G.FIXED_DT

  -- 중앙 점선
  love.graphics.setColor(1, 1, 1, 0.25)
  for y = 0, G.WINDOW_HEIGHT, 24 do
    love.graphics.rectangle("fill", G.WINDOW_WIDTH / 2 - 2, y, 4, 12)
  end

  -- 점수 표시
  love.graphics.setColor(1, 1, 1, 0.7)
  love.graphics.setFont(fontScore)
  love.graphics.printf(tostring(leftPaddle.score), 0, 40, G.WINDOW_WIDTH / 2 - 50, "right")
  love.graphics.printf(tostring(rightPaddle.score), G.WINDOW_WIDTH / 2 + 50, 40, G.WINDOW_WIDTH / 2 - 50, "left")

  -- 패들과 공 그리기 (보간 렌더링)
  love.graphics.setColor(1, 1, 1, 1)
  leftPaddle:draw(alpha)
  rightPaddle:draw(alpha)
  ball:draw(alpha)

  -- 상태 안내 메시지 (화면 상단 점수 아래 위치)
  if gameState == "serve" then
    local msg = (servingPlayer == 1) and "Player 1's Serve" or "Player 2's Serve"
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(msg, 0, 110, G.WINDOW_WIDTH, "center")

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.printf("Press ENTER to Serve!", 0, 150, G.WINDOW_WIDTH, "center")
  end
end

