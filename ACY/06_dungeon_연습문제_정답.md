1# 06_dungeon MVC 퀴즈 정답 및 상세 해설

이 문서는 `mvc/basics/06_dungeon` 대상 MVC 퀴즈의 4가지 문제와 규칙, 리포트(`REPORT.md`) 작성 내용 및 Q1~Q3 서술형 정답을 정리한 문서입니다.
실제 구현 코드는 `ACY/06_dungeon/`에 반영되어 있으며, 제출용 리포트 원문은 [REPORT.md](file:///d:/acy/Fork/WithAi/ACY/06_dungeon/REPORT.md)에서 확인할 수 있습니다.

---

## ■ 규칙 준수 핵심 포인트

1. **전역 변수 금지**: 모든 모듈과 변수는 `local`로 선언하고 `return`으로만 내보냅니다.
2. **기존 메서드 수정 금지 (새 메서드, 생성자 추가는 허용)**:
   - `GameModel:attack()`, `GameModel:explore()`, `GameModel:useItem()`, `PlayerModel:addGold()` 등 **기존 메서드는 한 줄도 수정하지 않습니다.**
   - 상점 방(`kind = "shop"`) 진입 처리도 `GameModel:explore()`를 수정하는 대신, **생성자(`GameModel.new`)**에서 `self.bus:on("room_entered", ...)`를 구독해 `room.kind == "shop"`일 때 `self.mode = "shop"`으로 전환합니다.
   - 상점 구매/나가기는 새 메서드인 `GameModel:buyPotion()`, `GameModel:leaveShop()`으로 추가합니다.
3. **Game·PlayerModel 의존 금지 (문제 3)**:
   - `AchievementModel.new(bus)`는 `GameModel`이나 `PlayerModel`을 인자로 받지 않고 오직 `EventBus`만 구독합니다.
   - `enemy_killed` 이벤트가 전달하는 `{ name, gold }`의 `gold`를 스스로 누적해 15 이상이 되는 순간 `achievement_unlocked` 이벤트를 단 1회 발행합니다.

---

## ■ 문제별 구현 정답

### 1. 데이터만 고쳐 "아이템 2번 사용" 퀘스트 추가
- **수정 파일**: [dungeon_data.lua](file:///d:/acy/Fork/WithAi/ACY/06_dungeon/data/dungeon_data.lua)
- `quests` 배열에 아래 데이터를 추가합니다.
```lua
{ id = "item_user", text = "아이템 2번 사용", event = "item_used", needed = 2 },
```

### 2. 처치한 적 목록 패널 (`KillListModel` + `KillListView`)
- **새 파일**:
  - [kill_list_model.lua](file:///d:/acy/Fork/WithAi/ACY/06_dungeon/models/kill_list_model.lua): `bus:on("enemy_killed", ...)`로 `payload.name`을 `self.kills` 배열에 저장합니다.
  - [kill_list_view.lua](file:///d:/acy/Fork/WithAi/ACY/06_dungeon/views/kill_list_view.lua): `game.killList.kills`를 읽어 처치한 적이 없으면 `"아직 처치한 적이 없습니다."`, 있으면 `table.concat(model.kills, ", ")`를 반환합니다.

### 3. 처치 골드 누적 15 이상 시 로그에 업적 1회 표시 (`Game`·`PlayerModel` 의존 금지)
- **새 파일**: [achievement_model.lua](file:///d:/acy/Fork/WithAi/ACY/06_dungeon/models/achievement_model.lua)
```lua
local TARGET_GOLD = 15

local AchievementModel = {}
AchievementModel.__index = AchievementModel

function AchievementModel.new(bus, targetGold)
  local self = setmetatable({
    bus = bus,
    target = targetGold or TARGET_GOLD,
    totalGold = 0,
    unlocked = false,
  }, AchievementModel)

  bus:on("enemy_killed", function(payload)
    self:onEnemyKilled(payload)
  end)
  return self
end

function AchievementModel:onEnemyKilled(payload)
  local gained = (payload and payload.gold) or 0
  self.totalGold = self.totalGold + gained
  if not self.unlocked and self.totalGold >= self.target then
    self.unlocked = true
    self.bus:emit("achievement_unlocked", {
      text = string.format("처치 골드 %d 이상 획득", self.target),
      gold = self.totalGold,
    })
  end
end

return AchievementModel
```
- [log_view.lua](file:///d:/acy/Fork/WithAi/ACY/06_dungeon/views/log_view.lua)의 `FORMAT` 테이블에 `achievement_unlocked` 포맷 함수를 추가하면 `LogModel`(`onAny` 구독)에 기록된 이벤트가 로그 화면에 표시됩니다.

### 4. 출구 앞 상점 방 + `ShopController` (`b`: 구매 5골드, `l`: 나가기)
- **데이터**: [dungeon_data.lua](file:///d:/acy/Fork/WithAi/ACY/06_dungeon/data/dungeon_data.lua)의 `rooms`에서 `{ kind = "exit" }` 바로 앞에 `{ kind = "shop" }`을 추가합니다.
- **Controller**: [shop_controller.lua](file:///d:/acy/Fork/WithAi/ACY/06_dungeon/controllers/shop_controller.lua)
  - `"b"` 입력 시 `game:buyPotion()` 호출
  - `"l"` 입력 시 `game:leaveShop()` 호출
- **Model 새 메서드**: [game_model.lua](file:///d:/acy/Fork/WithAi/ACY/06_dungeon/models/game_model.lua)
  - `GameModel:buyPotion()`: 골드가 5 미만이면 `false, "골드가 부족합니다"` 반환, 가방이 가득 찼으면 `self.inventory:add(potion)`이 반환하는 `false, "가방이 가득 찼습니다"`를 그대로 반환, 성공 시 5골드 차감 및 `"item_bought"` 이벤트 발행
  - `GameModel:leaveShop()`: `self.mode = "explore"`로 복귀 및 `"shop_left"` 이벤트 발행

---

## ■ 서술형 질문 (Q1 ~ Q3) 정답

- **Q1. 퀘스트 진행도가 오르는 원리**
  `QuestModel`이 초기화될 때 각 퀘스트 데이터의 `event` 문자열(예: `"item_used"`, `"enemy_killed"`)을 `EventBus`에 구독해 두고, `GameModel`이 행동 중 해당 이벤트를 `bus:emit`으로 발행하면 `QuestModel`의 리스너가 호출되어 `progress`를 1 증가시키고 `needed`에 도달하면 완료(`done = true`) 처리한다.
- **Q2. `attack()`을 안 고쳐도 되는 이유**
  `GameModel:attack()`은 적이 쓰러질 때 이미 `self.bus:emit("enemy_killed", { name = enemy.name, gold = enemy.gold })`를 발행하고 있으므로, `KillListModel`과 `AchievementModel`이 `EventBus`에서 `"enemy_killed"` 이벤트를 구독하기만 하면 `attack()` 코드를 전혀 수정하지 않고도 적 이름과 처치 골드를 받아 처리할 수 있다.
- **Q3. 업적 기준 30 변경 시 고칠 파일**
  `models/achievement_model.lua` 파일 1개만 고치면 된다(`TARGET_GOLD = 15` → `30`).
