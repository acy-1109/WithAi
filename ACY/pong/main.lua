-- main.lua
-- 1주차: 고정 타임스텝 기반 결정적 Pong (ACY/pong)
--
-- 원칙 준수:
-- 1) class.lua 메타테이블 OOP 활용
-- 2) 암묵적 전역 금지 (모든 모듈/변수 local 선언)
-- 3) update / draw 분리 (draw는 읽기 전용)
-- 4) accumulator 기반 고정 타임스텝 (FIXED_DT)
-- 5) 루프 내 불필요한 테이블 생성 방지

local class = require("class")

-- 화면 규격 및 물리 상수
local WINDOW_WIDTH = 800
local WINDOW_HEIGHT = 600
local FIXED_DT = 1 / 60
local MAX_FRAME_TIME = 0.25

local PADDLE_WIDTH = 12
local PADDLE_HEIGHT = 80
local PADDLE_SPEED = 400

local BALL_RADIUS = 7
local BALL_INITIAL_SPEED = 280
local BALL_SPEED_INCREMENT = 1.05

--------------------------------------------------
-- 1. Paddle 클래스
--------------------------------------------------
local Paddle = class()

function Paddle:init(x, y, upKey, downKey)
  self.x = x
  self.y = y
  self.prevY = y
  self.w = PADDLE_WIDTH
  self.h = PADDLE_HEIGHT
  self.upKey = upKey
  self.downKey = downKey
  self.score = 0
end

function Paddle:savePrev()
  self.prevY = self.y
end

function Paddle:update(dt)
  if love.keyboard.isDown(self.upKey) then
    self.y = self.y - PADDLE_SPEED * dt
  end
  if love.keyboard.isDown(self.downKey) then
    self.y = self.y + PADDLE_SPEED * dt
  end

  -- 화면 경계 제한
  if self.y < 0 then
    self.y = 0
  elseif self.y + self.h > WINDOW_HEIGHT then
    self.y = WINDOW_HEIGHT - self.h
  end
end

function Paddle:draw(alpha)
  local renderY = self.prevY + (self.y - self.prevY) * (alpha or 1)
  love.graphics.rectangle("fill", self.x, renderY, self.w, self.h)
end

--------------------------------------------------
-- 2. Ball 클래스
--------------------------------------------------
local Ball = class()

function Ball:init()
  self.radius = BALL_RADIUS
  self:reset(1)
end

function Ball:reset(serveDirection)
  self.x = WINDOW_WIDTH / 2
  self.y = WINDOW_HEIGHT / 2
  self.prevX = self.x
  self.prevY = self.y
  local dir = serveDirection or 1
  self.vx = BALL_INITIAL_SPEED * dir
  self.vy = math.random(-150, 150)
end

function Ball:savePrev()
  self.prevX = self.x
  self.prevY = self.y
end

function Ball:update(dt)
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt

  -- 상/하 벽 반사 (원의 상단/하단 기준)
  if self.y - self.radius <= 0 then
    self.y = self.radius
    self.vy = -self.vy
  elseif self.y + self.radius >= WINDOW_HEIGHT then
    self.y = WINDOW_HEIGHT - self.radius
    self.vy = -self.vy
  end
end

function Ball:draw(alpha)
  local a = alpha or 1
  local renderX = self.prevX + (self.x - self.prevX) * a
  local renderY = self.prevY + (self.y - self.prevY) * a
  love.graphics.circle("fill", renderX, renderY, self.radius)
end

--------------------------------------------------
-- 3. 충돌 검사 (원과 패들 사각형 충돌)
--------------------------------------------------
local function checkCollision(b, p)
  -- 사각형 내에서 원의 중심과 가장 가까운 점 (clamping)
  local closestX = math.max(p.x, math.min(b.x, p.x + p.w))
  local closestY = math.max(p.y, math.min(b.y, p.y + p.h))

  local dx = b.x - closestX
  local dy = b.y - closestY
  return (dx * dx + dy * dy) <= (b.radius * b.radius)
end

--------------------------------------------------
-- 4. 게임 상태 & 고정 타임스텝 제어
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

-- 고정 타임스텝 물리/로직 단위 스텝
local function step(dt)
  leftPaddle:update(dt)
  rightPaddle:update(dt)

  if gameState == "play" then
    ball:update(dt)

    -- 왼쪽 패들 충돌
    if checkCollision(ball, leftPaddle) and ball.vx < 0 then
      ball.x = leftPaddle.x + leftPaddle.w + ball.radius
      ball.vx = -ball.vx * BALL_SPEED_INCREMENT
      -- 패들 중심과의 거리에 따른 vy 반사각 조절
      local paddleCenter = leftPaddle.y + leftPaddle.h / 2
      ball.vy = (ball.y - paddleCenter) * 8
    end

    -- 오른쪽 패들 충돌
    if checkCollision(ball, rightPaddle) and ball.vx > 0 then
      ball.x = rightPaddle.x - ball.radius
      ball.vx = -ball.vx * BALL_SPEED_INCREMENT
      local paddleCenter = rightPaddle.y + rightPaddle.h / 2
      ball.vy = (ball.y - paddleCenter) * 8
    end

    -- 득점 처리 (화면 밖으로 완전히 벗어났을 때)
    if ball.x + ball.radius < 0 then
      rightPaddle.score = rightPaddle.score + 1
      servingPlayer = 1
      gameState = "serve"
      ball:reset(1)
    elseif ball.x - ball.radius > WINDOW_WIDTH then
      leftPaddle.score = leftPaddle.score + 1
      servingPlayer = 2
      gameState = "serve"
      ball:reset(-1)
    end
  end
end

--------------------------------------------------
-- 5. LÖVE 콜백 (수명주기)
--------------------------------------------------
function love.load()
  math.randomseed(os.time())
  fontSmall = love.graphics.newFont(18)
  fontLarge = love.graphics.newFont(32)
  fontScore = love.graphics.newFont(48)

  leftPaddle = Paddle(30, (WINDOW_HEIGHT - PADDLE_HEIGHT) / 2, "w", "s")
  rightPaddle = Paddle(WINDOW_WIDTH - 30 - PADDLE_WIDTH, (WINDOW_HEIGHT - PADDLE_HEIGHT) / 2, "up", "down")
  ball = Ball()
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

-- 상태 변경(물리/로직)은 오직 고정 스텝 안에서만 실행
function love.update(dt)
  -- 렉 스파이크로 인한 spiral of death 방지
  if dt > MAX_FRAME_TIME then
    dt = MAX_FRAME_TIME
  end

  accumulator = accumulator + dt
  while accumulator >= FIXED_DT do
    leftPaddle:savePrev()
    rightPaddle:savePrev()
    ball:savePrev()

    step(FIXED_DT)
    accumulator = accumulator - FIXED_DT
  end
end

-- 그리기 전용 (상태 변경 절대 금지)
function love.draw()
  -- 프레임 보간 계수 (0.0 ~ 1.0)
  local alpha = accumulator / FIXED_DT

  -- 중앙 점선
  love.graphics.setColor(1, 1, 1, 0.25)
  for y = 0, WINDOW_HEIGHT, 24 do
    love.graphics.rectangle("fill", WINDOW_WIDTH / 2 - 2, y, 4, 12)
  end

  -- 점수 표시
  love.graphics.setColor(1, 1, 1, 0.7)
  love.graphics.setFont(fontScore)
  love.graphics.printf(tostring(leftPaddle.score), 0, 40, WINDOW_WIDTH / 2 - 50, "right")
  love.graphics.printf(tostring(rightPaddle.score), WINDOW_WIDTH / 2 + 50, 40, WINDOW_WIDTH / 2 - 50, "left")

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
    love.graphics.printf(msg, 0, 110, WINDOW_WIDTH, "center")

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.printf("Press ENTER to Serve!", 0, 150, WINDOW_WIDTH, "center")
  end
end

