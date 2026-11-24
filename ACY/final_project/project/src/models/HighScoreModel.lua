-- HighScoreModel.lua
-- 최고 점수 보관 및 문자열 직렬화/역직렬화만 담당한다.
-- 파일 I/O(io, love.filesystem)는 main.lua 에서만 수행한다. love / io / print 비의존.

local class = require("class")

local HighScoreModel = class()

function HighScoreModel:init(best)
  if type(best) == "number" and best >= 0 and best == best and best < math.huge then
    self.best = math.floor(best)
  else
    self.best = 0
  end
end

--- 새 점수를 제출한다. 최고 점수 갱신 시 true 를 반환한다.
function HighScoreModel:submit(score)
  if type(score) ~= "number" or score ~= score or score < 0 then
    return false
  end
  local s = math.floor(score)
  if s > self.best then
    self.best = s
    return true
  end
  return false
end

--- 저장용 문자열로 직렬화한다.
function HighScoreModel:serialize()
  return "highscore=" .. tostring(self.best)
end

--- 저장 문자열을 역직렬화한다. 깨진 입력이면 에러 없이 기본값(0)으로 복구한다.
function HighScoreModel.deserialize(str)
  if type(str) ~= "string" then
    return HighScoreModel(0)
  end
  local digits = str:match("^%s*highscore%s*=%s*(%d+)%s*$")
  local num = digits and tonumber(digits) or nil
  if not num or num < 0 then
    return HighScoreModel(0)
  end
  return HighScoreModel(num)
end

return HighScoreModel
