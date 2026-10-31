-- Dog (개, Mammal 2단계 상속)
local class = require "class"
local Mammal = require "Mammal"
local Animal = require "Animal"

local Dog = class(Mammal)

function Dog:init(name, age, breed)
  Mammal.init(self, name, age or 3)
  self.breed = breed
end

function Dog:speak()
  return self.name .. " barks: Woof! Woof!"
end

function Dog:move(distance)
  local cost = distance * 0.4
  self.energy = math.max(0, self.energy - cost)
  return self.name .. " runs " .. distance .. " meters (energy -" .. cost .. ")"
end

function Dog:fetch()
  return self.name .. " fetches the ball excitedly!"
end

function Dog:getInfo()
  local baseInfo = Animal.getInfo(self)
  if self.breed then
    return string.format("%s [Breed: %s]", baseInfo, self.breed)
  end
  return baseInfo
end

return Dog
