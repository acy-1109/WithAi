-- WaveParser.lua
-- R2: waves.txt 문자열을 파싱해 웨이브 목록을 만든다.
-- models/ 계층이므로 io, love, print 를 사용하지 않고 문자열만 받아 처리한다.

local WaveParser = {}

local function splitTokens(line)
  local tokens = {}
  for token in line:gmatch("%S+") do
    tokens[#tokens + 1] = token
  end
  return tokens
end

local function parseLine(line, lineNo, waves, current)
  local trimmed = line:match("^%s*(.-)%s*$")
  if trimmed == "" or trimmed:sub(1, 1) == "#" then
    return current
  end

  local tokens = splitTokens(trimmed)
  local cmd = tokens[1]

  if cmd == "wave" then
    if #tokens ~= 2 then
      error(string.format("line %d: 'wave' 는 번호 1개만 필요합니다", lineNo), 2)
    end
    local id = tonumber(tokens[2])
    if not id or id < 1 or math.floor(id) ~= id then
      error(string.format("line %d: 잘못된 웨이브 번호 '%s'", lineNo, tokens[2]), 2)
    end
    local wave = { id = id, enemies = {} }
    waves[#waves + 1] = wave
    return wave
  elseif cmd == "enemy" then
    if not current then
      error(string.format("line %d: 'wave' 선언 전에 'enemy' 가 나올 수 없습니다", lineNo), 2)
    end
    if #tokens ~= 4 then
      error(string.format("line %d: 'enemy' 는 <종류> <x> <y> 3개 인자가 필요합니다", lineNo), 2)
    end
    local kind = tokens[2]
    if not kind:match("^[%a_][%w_]*$") then
      error(string.format("line %d: 잘못된 적 종류 '%s'", lineNo, kind), 2)
    end
    local x = tonumber(tokens[3])
    local y = tonumber(tokens[4])
    if not x or not y then
      error(string.format("line %d: 좌표는 숫자여야 합니다 (%s, %s)", lineNo, tokens[3], tokens[4]), 2)
    end
    current.enemies[#current.enemies + 1] = { kind = kind, x = x, y = y }
    return current
  else
    error(string.format("line %d: 알 수 없는 명령 '%s'", lineNo, tostring(cmd)), 2)
  end
end

--- 웨이브 텍스트를 파싱해 { { id = number, enemies = { { kind, x, y }, ... } }, ... } 를 반환한다.
function WaveParser.parse(text)
  if type(text) ~= "string" then
    error("line 1: 웨이브 데이터는 문자열이어야 합니다", 2)
  end

  local waves = {}
  local current = nil
  local lineNo = 0
  local pos = 1
  local len = #text

  while pos <= len do
    local nl = text:find("\n", pos, true)
    local raw
    if nl then
      raw = text:sub(pos, nl - 1)
      pos = nl + 1
    else
      raw = text:sub(pos)
      pos = len + 1
    end
    raw = raw:gsub("\r$", "")
    lineNo = lineNo + 1
    current = parseLine(raw, lineNo, waves, current)
  end

  if #waves == 0 then
    error("line 1: 최소 1개의 wave 가 필요합니다", 2)
  end
  for i = 1, #waves do
    if #waves[i].enemies == 0 then
      error(string.format("line %d: wave %d 에 적이 1기도 없습니다", lineNo, waves[i].id), 2)
    end
  end

  return waves
end

return WaveParser

