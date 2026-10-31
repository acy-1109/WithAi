-- paddle.lua
local class = require("class")
local G = require("global")

local Paddle = class()

function Paddle:init(x, y, upKey, downKey)
  self.x = x
  self.y = y
  self.prevY = y
  self.w = G.PADDLE_WIDTH
  self.h = G.PADDLE_HEIGHT
  self.upKey = upKey
  self.downKey = downKey
  self.score = 0
end

function Paddle:savePrev()
  self.prevY = self.y
end

function Paddle:update(dt)
  if love.keyboard.isDown(self.upKey) then
    self.y = self.y - G.PADDLE_SPEED * dt
  end
  if love.keyboard.isDown(self.downKey) then
    self.y = self.y + G.PADDLE_SPEED * dt
  end

  -- 화면 경계 제한
  if self.y < 0 then
    self.y = 0
  elseif self.y + self.h > G.WINDOW_HEIGHT then
    self.y = G.WINDOW_HEIGHT - self.h
  end
end

function Paddle:draw(alpha)
  local renderY = self.prevY + (self.y - self.prevY) * (alpha or 1)
  love.graphics.rectangle("fill", self.x, renderY, self.w, self.h)
end

return Paddle

