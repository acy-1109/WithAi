-- 08 메타테이블 실습 과제 — 학생 작성 파일
-- 각 TODO 를 채운 뒤 테스트로 확인한다.
--   lua ACY/08_metatables/metatable_tasks_test.lua
-- 규칙: 전역 변수 금지, Lua 5.1 / LuaJIT 호환 문법만 사용.

local M = {}

-- 문제 1. 기본값 테이블 (15점)
-- t 에 없는 키를 읽으면 defaults 에서 값을 가져온다.
-- t 자체를 반환하며, defaults 의 키가 t 에 복사되면 안 된다.
function M.withDefaults(t, defaults)
  return setmetatable(t, { __index = defaults })
end

-- 문제 2. 읽기 전용 테이블 (15점)
-- 읽기는 원본 t 에서, 쓰기는 항상 error("read-only: <key>") 를 발생시킨다.
-- 이미 있는 키에 대한 쓰기도 막아야 한다.
function M.readOnly(t)
  return setmetatable({}, {
    __index = t,
    __newindex = function(_, key)
      error("read-only: " .. tostring(key), 2)
    end,
  })
end

-- 문제 3. Stats 값 타입 (25점)
-- Stats.new({hp=?, atk=?, def=?}) : 빠진 필드는 Stats.DEFAULT 값으로 채운다.
-- a + b       : 필드별 합으로 새 Stats 반환 (원본 불변)
-- s * n, n * s: 필드별 스칼라 곱으로 새 Stats 반환
-- a == b      : 세 필드가 모두 같으면 true
-- tostring(s) : "Stats(hp=100, atk=10, def=5)"  (%g 형식, 필드 순서 고정)
-- s:power()   : atk * 2 + def
local Stats = {}
Stats.__index = Stats
Stats.DEFAULT = { hp = 100, atk = 10, def = 5 }

function Stats.new(o)
  o = o or {}
  return setmetatable({
    hp = o.hp or Stats.DEFAULT.hp,
    atk = o.atk or Stats.DEFAULT.atk,
    def = o.def or Stats.DEFAULT.def,
  }, Stats)
end

function Stats:power()
  return self.atk * 2 + self.def
end

function Stats.__add(a, b)
  return Stats.new({
    hp = a.hp + b.hp,
    atk = a.atk + b.atk,
    def = a.def + b.def,
  })
end

function Stats.__mul(a, b)
  if type(a) == "number" then
    a, b = b, a
  end
  return Stats.new({
    hp = a.hp * b,
    atk = a.atk * b,
    def = a.def * b,
  })
end

function Stats.__eq(a, b)
  return a.hp == b.hp and a.atk == b.atk and a.def == b.def
end

function Stats.__tostring(s)
  return string.format("Stats(hp=%g, atk=%g, def=%g)", s.hp, s.atk, s.def)
end

M.Stats = Stats

-- 문제 4. 변경 감시 프록시 (20점)
-- 반환된 프록시에 값을 쓰면 원본 t 에 저장하고 onChange(key, old, new) 를 호출한다.
-- 값이 실제로 바뀌지 않으면(old == new) onChange 를 호출하지 않는다.
-- 이미 있는 키를 수정할 때도 onChange 가 호출되어야 한다.
function M.tracked(t, onChange)
  return setmetatable({}, {
    __index = t,
    __newindex = function(_, key, new)
      local old = t[key]
      t[key] = new
      if old ~= new then
        onChange(key, old, new)
      end
    end,
  })
end

-- 문제 5. __call 팩토리 + __lt 정렬 (15점)
-- Enemy.new(name, hp) 와 Enemy(name, hp) 둘 다 인스턴스를 만든다.
-- 생성될 때마다 Enemy.count 가 1 증가하고, 인스턴스 id 는 생성 순번이다.
-- a < b : hp 오름차순, hp 가 같으면 id 오름차순 → table.sort(list) 가 그대로 동작해야 한다.
-- tostring(e) : "Slime#1(hp=50)"
local Enemy = {}
Enemy.__index = Enemy
Enemy.count = 0

function Enemy.new(name, hp)
  Enemy.count = Enemy.count + 1
  return setmetatable({
    id = Enemy.count,
    name = name,
    hp = hp,
  }, Enemy)
end

function Enemy.__lt(a, b)
  if a.hp ~= b.hp then
    return a.hp < b.hp
  end
  return a.id < b.id
end

function Enemy.__tostring(e)
  return string.format("%s#%d(hp=%g)", e.name, e.id, e.hp)
end

setmetatable(Enemy, {
  __call = function(_, name, hp)
    return Enemy.new(name, hp)
  end,
})

M.Enemy = Enemy

return M

