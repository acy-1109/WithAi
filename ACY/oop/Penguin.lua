-- Penguin (펭귄, Bird 2단계 상속)
local class = require "class"
local Bird = require "Bird"

local Penguin = class(Bird)

function Penguin:init(name, age)
  Bird.init(self, name, age or 4, 0.5)
  self.canFly = false
end

function Penguin:speak()
  return self.name .. " honks: Honk! Honk!"
end

function Penguin:move(distance)
  local cost = distance * 0.6
  self.energy = math.max(0, self.energy - cost)
  return self.name .. " waddles " .. distance .. " meters on ice (energy -" .. cost .. ")"
end

function Penguin:dive()
  return self.name .. " dives gracefully into the cold ocean water!"
end

return Penguin
