# REPORT — 안찬영 (2025391016)

> 작성 방법·예시: [06_dungeon_퀴즈_REPORT_작성가이드.md](./06_dungeon_퀴즈_REPORT_작성가이드.md)

## 1) 파일 변경표

| 문제 | 새 파일 | 고친 파일 | 고치지 않은 주요 파일 |
|---|---|---|---|
| 1 | 없음 | `data/dungeon_data.lua` (`quests` 에 `item_used` 1줄 추가), `test/dungeon_test.lua` | `models/quest_model.lua`, `models/game_model.lua` 등 코드 파일 전부 |
| 2 | `models/kill_list_model.lua`, `views/kill_list_view.lua` | `models/game_model.lua` (`GameModel.new` 생성자에 1줄 추가), `main.lua` (위젯·레이아웃 등록), `test/dungeon_test.lua` | `GameModel:attack()`, `models/enemy_model.lua`, `controllers/` 전부 |
| 3 | `models/achievement_model.lua` | `models/game_model.lua` (`GameModel.new` 생성자에 1줄 추가), `views/log_view.lua` (`FORMAT` 에 `achievement_unlocked` 추가), `test/dungeon_test.lua` | `models/player_model.lua`, `models/log_model.lua`, `GameModel:attack()` |
| 4 | `controllers/shop_controller.lua` | `data/dungeon_data.lua` (출구 앞 `shop` 방 추가), `models/game_model.lua` (생성자 `room_entered` 구독 + 새 메서드 `buyPotion`, `leaveShop`), `views/command_view.lua`, `views/log_view.lua`, `main.lua`, `test/dungeon_test.lua` | `GameModel:explore()`, `controllers/input_router.lua`, 기존 Controller 4개 전부 |

한 줄 이유: EventBus의 이벤트(item_used, enemy_killed, room_entered)를 구독해 새 모델을 연결하고 InputRouter에 ShopController만 추가했기 때문에 GameModel:attack()이나 GameModel:explore()같은 기존 메서드는 고칠 필요가 없었습니다.

## 2) 핵심 프롬프트 (3~5개)

1. "`AGENTS.md` 와 `.antigravity/skills/lua-expert/SKILL.md` 규칙을 적용해 `06_dungeon` 의 README 3장 의존성 표를 지켜 줘. 전역 변수는 절대 만들지 말고(`local M = {} ... return M`), 기존 메서드는 한 줄도 수정하지 마(새 메서드와 생성자 추가만 허용)."
2. "구현하기 전에 `test/dungeon_test.lua` 의 `[0] 디커플링` 목록에 새 Model/Controller 파일 3개를 등록하고, `[5]` 구역에 과제 1~4(아이템 2번 사용 퀘스트, `KillListModel`+`View`, 15골드 업적 1회 달성 및 중복 방지, 상점 `b` 구매 / `l` 나가기 / 골드 부족·가방 가득 실패 이유)의 실패하는 테스트부터 먼저 작성해 줘."
3. "`AchievementModel` 은 `GameModel` 이나 `PlayerModel` 을 인자로 받지 말고 오직 `EventBus` 만 구독해. `enemy_killed` 이벤트 데이터 `{ name, gold }` 의 `gold` 를 누적해서 15 이상이 되는 순간 `achievement_unlocked` 이벤트를 딱 1번만 발행하게 만들어 줘."
4. (실수 발견 후) "`git diff` 로 확인해 보니 상점 방 진입을 위해 기존 메서드인 `GameModel:explore()` 에 `elseif room.kind == 'shop'` 을 넣었어. 기존 메서드 수정 금지 규칙 위반이니 `GameModel:explore()` 는 원본 그대로 되돌리고, `GameModel.new` 생성자 안에서 `bus:on('room_entered', ...)` 를 구독해 `shop` 모드로 전환하도록 고쳐 줘."
5. (실수 발견 후) "문제 조건에서 상점 나가기 키는 `e` 가 아니라 `l` 이야. `ShopController:handle`, `CommandView` 의 `COMMANDS.shop`, `main.lua` 의 자동 시연 스크립트를 모두 `l` 로 수정하고 테스트와 자동 시연을 다시 실행해 줘."

> **활용한 에이전트 스킬·규칙 (첨부: `skills/lua-expert-SKILL.md`)**
> - 프로젝트에 설정된 `.antigravity/skills/lua-expert/SKILL.md`, `.antigravity/rules/lua-expert.md`, `AGENTS.md`, `.antigravity/workflows/release-check.md` 를 활용했습니다.

## 3) AI 실수 사례 (1개 이상)

### 사례 1: `AchievementModel` 이 `PlayerModel` 을 직접 참조한 실수

**AI 가 만든 코드**

```lua
function AchievementModel.new(bus, player)
  local self = setmetatable({ bus = bus, player = player, unlocked = false }, AchievementModel)
  bus:on("enemy_killed", function()
    if not self.unlocked and self.player.gold >= 15 then
      self.unlocked = true
      self.bus:emit("log_added", { text = "★ 업적 달성: 골드 15 이상 수집!" })
    end
  end)
  return self
end
```

**어긴 규칙**: "문제 3: 처치 골드 누적 15 이상 시 로그에 업적 1회 표시 (`Game`·`PlayerModel` 의존 금지)"

**발견 방법**: AI가 작성한 achievement_model.lua와 main.lua를 읽어 보다가 생성자 인자로 game.player를 넘겨받고 self.player.gold >= 15를 직접 검사하고 있는 것을 확인해 Game, PlayerModel 의존 금지 위반을 찾았습니다.

**고친 코드**

```lua
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
```

---

### 사례 2: 기존 메서드 `GameModel:explore()` 를 직접 수정한 실수

**AI 가 만든 코드**

```lua
-- models/game_model.lua 의 기존 explore() 메서드 내부
  elseif room.kind == "item" then
    ...
  elseif room.kind == "shop" then
    self.mode = "shop"
    self.bus:emit("shop_entered", {})
  elseif room.kind == "exit" then
```

**어긴 규칙**: "기존 메서드 수정 금지 (새 메서드, 생성자 추가는 허용)"

**발견 방법**: game_model.lua를 diff로 비교해보다가 기존 메서드인 GameModel:explore()안에 elseif room.kind == "shop" 분기가 추가된 것을 발견했습니다. 

**고친 코드**

```lua
-- GameModel:explore() 는 원본 그대로 두고, 생성자 GameModel.new(data) 에만 추가
  self.bus:on("room_entered", function(d)
    local room = self.dungeon.rooms[d and d.index]
    if room and room.kind == "shop" then
      self.mode = "shop"
      self.bus:emit("shop_entered", { price = 5 })
    end
  end)
```

## 4) 테스트 결과

구현 전

```
[5] 퀴즈 과제 1~4 테스트
  FAIL - 과제1: dungeon_data 에 아이템 2번 사용 퀘스트 존재
  FAIL - 과제1: 아이템 2번 사용 시 퀘스트 완료
  FAIL - 과제2: 처치 전 빈 상태 문구
  FAIL - 과제2: KillListModel 적 이름 누적
  FAIL - 과제2: KillListView 처치 목록 렌더링
  FAIL - 과제3: 누적 14골드에서는 미달성
  FAIL - 과제3: 누적 19골드(>=15) 달성 시 이벤트 1회 발생
  FAIL - 과제3: 이후 추가 처치에도 중복 발생 없음(1회만)
  FAIL - 과제3: 통합 시 LogView 에 업적 달성 표시
  FAIL - 과제4: dungeon_data 출구 직전 방이 shop
  FAIL - 과제4: 상점 방 진입 시 shop 모드 전환
  FAIL - 과제4: 골드 부족 시 구매 실패 및 이유 표시
  FAIL - 과제4: b 입력으로 물약 구매 성공 (5골드 차감, 가방 +1)
  FAIL - 과제4: 가방 가득 시 구매 실패 및 이유 표시
  FAIL - 과제4: l 입력으로 상점 나가기 → explore 복귀
  FAIL - 과제4: 상점 나온 뒤 다음 방(출구) 이동 → 승리

결과: 56 통과, 16 실패
```

구현 후

```
[0] 디커플링: Model/Controller 에 print·io·love 없음
  ok   - models/kill_list_model.lua
  ok   - models/achievement_model.lua
  ok   - controllers/shop_controller.lua
...
[5] 퀴즈 과제 1~4 테스트
  ok   - 과제1: dungeon_data 에 아이템 2번 사용 퀘스트 존재
  ok   - 과제1: 아이템 2번 사용 시 퀘스트 완료
  ok   - 과제2: 처치 전 빈 상태 문구
  ok   - 과제2: KillListModel 적 이름 누적
  ok   - 과제2: KillListView 처치 목록 렌더링
  ok   - 과제3: 누적 14골드에서는 미달성
  ok   - 과제3: 누적 19골드(>=15) 달성 시 이벤트 1회 발생
  ok   - 과제3: 이후 추가 처치에도 중복 발생 없음(1회만)
  ok   - 과제3: 통합 시 LogView 에 업적 달성 표시
  ok   - 과제4: dungeon_data 출구 직전 방이 shop
  ok   - 과제4: 상점 방 진입 시 shop 모드 전환
  ok   - 과제4: 골드 부족 시 구매 실패 및 이유 표시
  ok   - 과제4: b 입력으로 물약 구매 성공 (5골드 차감, 가방 +1)
  ok   - 과제4: 가방 가득 시 구매 실패 및 이유 표시
  ok   - 과제4: l 입력으로 상점 나가기 → explore 복귀
  ok   - 과제4: 상점 나온 뒤 다음 방(출구) 이동 → 승리

결과: 75 통과, 0 실패
```

## 5) 설명 문항 (본인 문장, 각 3~5줄)

**Q1. 퀘스트 진행도가 오르는 원리**
QuestModel.new(bus, defs)가 생성될 때 dungeon_data.lua에 적힌 각 퀘스트의 event 이름을 bus:on으로 구독하면
게임 진행 중 GameModel:useItem()같은 메서드가 self.bus:emit("이벤트 명", ...)로 이벤트를 버스에 알립니다.
EventBus가 이를 구독하면 QuestModel:advance(quest)를 호출해 quest.progress를 1올리고 needed에 도달하면 quest.done을 true로 바꾸어 quest_completed 이벤트를 발행합니다. 이 구조 덕에 GameModel이나 QuestModel의 수정 없이 dungeon_data.lua에 데이터만 추가해도 새 퀘스트가 작동합니다.

**Q2. attack() 을 안 고쳐도 되는 이유**
game_model.lua의 GameModel:attack()은 적이 죽었을 때 self.bus:emit("enemy_killed", { name = enemy.name, gold = enemy.gold })를 호출하여 적 이름과 골드를 이벤트 버스로 보냅니다. 새로 만든 KillListModel과 AchievementModel은 EventBus에서 enemy_killed 이벤트를 구독해 각각 payload.name과 payload.gold를 받아 처리합니다. GameModel:attack()은 누가 이벤트를 구독하는지 모르고 이벤트만 발행하면 되기에 처치 목록이나 업적 기능이 추가되어도 attack()코드는 수정할 필요가 없습니다.

**Q3. 업적 기준 30 변경 시 고칠 파일과 이유**
achievement_model.lua 파일에서 local TARGET_GOLD = 15를 30으로 고치면 됩니다.
처치 골드를 누적하고 목표치 이상인지 판단하는 코드들이 AchievementModel:onEnemyKilled에만 모여있기 때문입니다.
달성 시 발행하는 achievement_unlocked 이벤트의 text도 self.target 값으로 만들어지고 LogModel과 log_view.lua는 전달받은 데이터만 기록, 출력하므로 다른 파일은 고칠 필요가 없습니다.
