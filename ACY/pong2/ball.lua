-- ball.lua
local class = require("class")
local G = require("global")

local Ball = class()

function Ball:init()
  self.radius = G.BALL_RADIUS
  self:reset(1)
end

function Ball:reset(serveDirection)
  self.x = G.WINDOW_WIDTH / 2
  self.y = G.WINDOW_HEIGHT / 2
  self.prevX = self.x
  self.prevY = self.y
  local dir = serveDirection or 1
  self.vx = G.BALL_INITIAL_SPEED * dir
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
  elseif self.y + self.radius >= G.WINDOW_HEIGHT then
    self.y = G.WINDOW_HEIGHT - self.radius
    self.vy = -self.vy
  end
end

function Ball:draw(alpha)
  local a = alpha or 1
  local renderX = self.prevX + (self.x - self.prevX) * a
  local renderY = self.prevY + (self.y - self.prevY) * a
  love.graphics.circle("fill", renderX, renderY, self.radius)
end

return Ball

