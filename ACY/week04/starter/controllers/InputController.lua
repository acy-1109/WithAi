-- InputController.lua  (STARTER)
-- 입력(키 상태)을 해석해 Model 이 이해하는 입력 계약 { move, fire } 로 바꾼다.
-- love.keyboard 를 직접 부르지 않고 isDown 함수를 주입받는다 → 창 없이 테스트 가능.

local class = require("class")

local InputController = class()

local DEFAULT_KEYS = {
  left = { "left", "a" },
  right = { "right", "d" },
  fire = { "space" },
  restart = "r",
  quit = "escape",
}

--- @param game   table              GameModel (명령 대상)
--- @param isDown function(key)->bool 보통 love.keyboard.isDown
--- @param keys   table|nil          키 배치. 기본 DEFAULT_KEYS
function InputController:init(game, isDown, keys)
  self.game = game
  self.isDown = isDown
  self.keys = keys or DEFAULT_KEYS
  -- 프레임마다 새 테이블을 만들지 않고 재사용한다(GC 부담 감소).
  self.input = { move = 0, fire = false }
end

local function anyDown(isDown, list)
  for i = 1, #list do
    if isDown(list[i]) then
      return true
    end
  end
  return false
end

--- 연속 입력(누르고 있는 키) → 입력 계약. 프레임당 1회 호출.
-- @return table { move = -1|0|1, fire = boolean }
function InputController:read()
  -- TODO: self.keys.left 중 하나라도 눌리면 -1, right 면 +1 (둘 다면 0)
  --       fire 키가 눌렸는지. 결과를 self.input 에 채워 돌려준다.
  local left = anyDown(self.isDown, self.keys.left)   -- a, left 아무거나
  local right = anyDown(self.isDown, self.keys.right) -- d, right 아무거나
  local move = 0                                      -- 둘다 누르거나 안누르면 이동방향 0
  if left and not right then                          -- 왼쪽키를 누르면 -1
    move = -1
  elseif right and not left then                      -- 오른쪽 키는 1
    move = 1
  end
  self.input.move = move
  self.input.fire = anyDown(self.isDown, self.keys.fire) -- 발사 키가 눌렸는지
  return self.input
end

--- 단발 입력(눌린 순간) → Model 명령 또는 앱 명령.
-- @return string|nil  "quit" | "restart" | nil
function InputController:keypressed(key)
  -- TODO: quit 키 → "quit" 반환 (종료 자체는 main 이 한다 — 왜?)
  --       restart 키 + 게임오버 상태 → self.game:reset() 후 "restart"
  if key == self.keys.quit then
    return "quit"
  end
  if key == self.keys.restart and self.game.state == "gameover" then
    self.game:reset()
    return "restart"
  end
  return nil
end

return InputController
