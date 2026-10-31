-- class.lua
-- 메타테이블 기반 클래스 유틸 (.new 생성자 방식)
--
-- 사용법:
--   local class = require("class")
--   local Animal = class()
--   function Animal:init(name) self.name = name end
--
--   local Dog = class(Animal) -- 상속
--   local d = Dog.new("Rex")  -- .new 로 생성 (init 자동 호출)

local function class(base)
  local cls = {}
  cls.__index = cls

  -- 부모 상속 체인 연결
  if base then
    setmetatable(cls, { __index = base })
  end

  -- .new 생성자 함수 정의
  function cls.new(...)
    local self = setmetatable({}, cls)
    if self.init then
      self:init(...)
    end
    return self
  end

  return cls
end

return class

