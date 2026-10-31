-- Mammal (포유류, Animal 1단계 상속)
local class = require "class"
local Animal = require "Animal"

local Mammal = class(Animal)

function Mammal:init(name, age)
  Animal.init(self, name, age or 3)
  self.warmBlooded = true
end

function Mammal:speak()
  return self.name .. " makes a mammalian sound"
end

return Mammal
