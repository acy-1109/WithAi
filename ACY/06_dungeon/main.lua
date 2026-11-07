-- main.lua  (예제 6: 던전 RPG — 다중 Model / 다중 View / 다중 Controller)
-- 실행: lua main.lua        → 자동 시연
--       lua main.lua -i     → 직접 플레이
--
-- main 은 "조립"만 한다. 게임 규칙도, 출력 문구도, 키 해석도 여기 없다.

local here = (arg and arg[0] or ""):match("(.*[/\\])") or "./"
package.path = here .. "?.lua;" .. package.path

local GameModel = require("models.game_model")
local KillListModel = require("models.kill_list_model")
local AchievementModel = require("models.achievement_model")
local data = require("data.dungeon_data")

local ScreenView = require("views.screen_view")
local StatusView = require("views.status_view")
local EnemyView = require("views.enemy_view")
local InventoryView = require("views.inventory_view")
local QuestView = require("views.quest_view")
local LogView = require("views.log_view")
local CommandView = require("views.command_view")
local KillListView = require("views.kill_list_view")

local InputRouter = require("controllers.input_router")
local ExploreController = require("controllers.explore_controller")
local BattleController = require("controllers.battle_controller")
local InventoryController = require("controllers.inventory_controller")
local ShopController = require("controllers.shop_controller")
local EndController = require("controllers.end_controller")

-- ── Model 조립 ──
local game = GameModel.new(data)
local killList = KillListModel.new(game.bus)
local achievement = AchievementModel.new(game.bus, game.player)
game.killList = killList -- 뷰가 쉽게 접근할 수 있도록 연결

-- ── View: 위젯 등록 + 모드별 레이아웃 ──
local widgets = {
  status = StatusView.new(),
  enemy = EnemyView.new(),
  inventory = InventoryView.new(),
  quest = QuestView.new(),
  killList = KillListView.new(killList),
  log = LogView.new(),
  command = CommandView.new(),
}
local layouts = {
  explore = { "status", "inventory", "quest", "killList", "log", "command" },
  shop = { "status", "inventory", "log", "command" },
  battle = { "status", "enemy", "log", "command" },
  inventory = { "status", "enemy", "inventory", "command" },
  default = { "status", "quest", "killList", "log", "command" },
}
local screen = ScreenView.new(print, widgets, layouts)

-- ── Controller: 모드별 담당자 등록 ──
local endController = EndController.new()
local router = InputRouter.new(game, screen, {
  explore = ExploreController.new(),
  shop = ShopController.new(),
  battle = BattleController.new(),
  inventory = InventoryController.new(),
  gameover = endController,
  victory = endController,
})

-- ── 입력 루프 ──
local interactive = arg and arg[1] == "-i"
local script = {
  "n", "a", "a", -- 슬라임 처치 (처치 목록 & 퀘스트에 반영)
  "n", -- 회복 물약 획득
  "n", "i", "1", "a", "a", "a", "a", -- 고블린 (전투 중 물약 사용 -> "아이템 2번 사용" 진행)
  "n", "i", "1", -- 철검 장착 ("아이템 2번 사용" 퀘스트 완료!)
  "n", "x", "a", "a", "a", "a", -- 오크 처치 (골드 15 이상 달성 -> "★ 업적 달성" 로그 출력!)
  "n", "r", -- 박쥐 떼에게서 도망
  "n", "b", "e", -- 상점 진입 -> 물약 구매 -> 상점 나가기
  "n", -- 출구
  "q",
}
local step = 0

local function nextInput()
  if interactive then
    io.write("> ")
    return io.read("*l")
  end
  step = step + 1
  local input = script[step]
  if input then
    print("> " .. input)
  end
  return input
end

screen:render(game)
while true do
  local input = nextInput()
  if input == nil or not router:handle(input) then
    break
  end
end
print("종료합니다.")
