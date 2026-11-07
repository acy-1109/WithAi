-- shop_controller.lua
-- 과제 4: 상점 전용 Controller
-- 입력 명령: b (물약 구매 5G), e (상점 나가기)

local ShopController = {}
ShopController.__index = ShopController

function ShopController.new()
  return setmetatable({}, ShopController)
end

function ShopController:handle(game, cmd)
  if cmd == "b" or cmd == "buy" then
    return game:buyPotion()
  elseif cmd == "e" or cmd == "exit" then
    return game:exitShop()
  end
  return false, "명령: b(물약 구매 5골드), e(상점 나가기)"
end

return ShopController

