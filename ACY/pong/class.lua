-- class.lua
-- 메타테이블 기반 최소 클래스 유틸 (LuaJIT / Lua 5.1 호환)
--
-- 사용법:
--   local class = require("class")
--   local Paddle = class()
--   function Paddle:init(...) end

local function class(base)
  local cls = {}
  cls.__index = cls

  local mt = {
    __call = function(c, ...)
      local self = setmetatable({}, c)
      if self.init then
        self:init(...)
      end
      return self
    end,
  }

  if base then
    mt.__index = base
  end

  return setmetatable(cls, mt)
end

return class

