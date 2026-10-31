-- class.lua
-- 메타테이블 기반 클래스 상속 유틸 (다단계 상속 지원 및 Dog.new(...) / Dog(...) 동시 지원)

local function class(base)
  local cls = {}

  -- base가 있으면 cls의 __index를 base로 위임하여 다단계 상속 체인 지원
  if base then
    setmetatable(cls, { __index = base })
  end

  cls.__index = cls

  -- .new 생성자
  function cls.new(...)
    local self = setmetatable({}, cls)
    if self.init then
      self:init(...)
    end
    return self
  end

  -- cls(...) 호출 지원
  return setmetatable(cls, {
    __index = base,
    __call = function(c, ...)
      return c.new(...)
    end,
  })
end

return class
