-- Cat (고양이, Mammal 2단계 상속)
local class = require "class"
local Mammal = require "Mammal"

local Cat = class(Mammal)

function Cat:init(name, age)
  Mammal.init(self, name, age or 2)
end

function Cat:speak()
  return self.name .. " meows: Meow~"
end

function Cat:move(distance)
  local cost = distance * 0.3
  self.energy = math.max(0, self.energy - cost)
  return self.name .. " sneaks " .. distance .. " meters silently (energy -" .. cost .. ")"
end

function Cat:nap()
  self.energy = math.min(self.maxEnergy, self.energy + 10)
  return self.name .. " takes a quick catnap (energy +10)"
end

return Cat
