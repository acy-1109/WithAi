-- Bird (조류, Animal 1단계 상속)
local class = require "class"
local Animal = require "Animal"

local Bird = class(Animal)

function Bird:init(name, age, wingSpan)
  Animal.init(self, name, age or 2)
  self.canFly = true
  self.wingSpan = wingSpan or 1.0
end

function Bird:speak()
  return self.name .. " chirps"
end

return Bird
