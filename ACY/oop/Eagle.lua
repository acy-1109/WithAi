-- Eagle (독수리, Bird 2단계 상속)
local class = require "class"
local Bird = require "Bird"
local Animal = require "Animal"

local Eagle = class(Bird)

function Eagle:init(name, age, wingSpan)
  Bird.init(self, name, age or 5, wingSpan or 2.2)
  self.hunting = false
end

function Eagle:speak()
  return self.name .. " screeches fiercely: Screeech!"
end

function Eagle:move(distance)
  local cost = distance * 0.2
  self.energy = math.max(0, self.energy - cost)
  return self.name .. " soars through the sky " .. distance .. " meters (energy -" .. cost .. ")"
end

function Eagle:hunt()
  self.hunting = true
  return self.name .. " spots a prey and dives to hunt!"
end

function Eagle:getInfo()
  local baseInfo = Animal.getInfo(self)
  if self.hunting then
    return string.format("%s [Status: Hunting]", baseInfo)
  end
  return baseInfo
end

return Eagle
