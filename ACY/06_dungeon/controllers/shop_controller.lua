-- shop_controller.lua
-- 상점 모드 입력 담당. 규약: handle(game, input) → ok, err
-- 입력 명령: b (물약 구매 5골드), l (상점 나가기)

local ShopController = {}
ShopController.__index = ShopController

function ShopController.new()
  return setmetatable({}, ShopController)
end

function ShopController:handle(game, input)
  if input == "b" then
    return game:buyPotion()
  elseif input == "l" then
    return game:leaveShop()
  end
  return false, "상점에서는 b / l 만 쓸 수 있습니다"
end

return ShopController

