# MVC Galaga 게임 고도화 로드맵

현재 구현된 기본 슈팅, 5종 적(`grunt`, `weaver`, `sniper`, `sprinter`, `tank`), 3페이즈 보스, 아이템 4종(`life`, `attack_up`, `speed_up`, `triple_shot`), 업적/하이스코어 시스템을 바탕으로 **전투 손맛 → 리스크-리워드 → 방어/역전 수단 → 보스/웨이브 깊이** 순으로 확장하기 위한 작업 순서와 설계 메모입니다.

> 원칙: 모든 단계는 한 세션에 1개 단계(또는 1개 기능)씩 진행하며, `models/`의 `love.*` 비의존 원칙과 `tests/layer_check.lua` 0건 위반, 헤드리스 테스트 통과를 유지합니다.

---

## 권장 작업 순서

### 1단계. 타격감(Game Feel) 및 사운드 피드백 (진행 중: 효과음 SFX 완료)
기존 `GameModel` 이벤트를 그대로 구독하여 **Model 변경을 최소화하면서** 플레이 체감을 가장 크게 끌어올리는 단계입니다.

- **핵심 내용**
  - [x] **효과음(SFX) 추가**: 발사, 미사일, `Weaver`/보스 레이저 차징·발사, 피격, 실드 해제, EMP, 폭발, 아이템 획득, 웨이브/업적/게임오버, 보스 등장 경고음(`AudioView`에서 `love.audio`/`love.sound` 기반 프로시저럴 레트로 파형 생성, 보이스 풀·디바운스 적용).
  - [ ] **화면 흔들림(Screen Shake)**: 플레이어 피격, `tank`/보스 격파, 레이저 발사 순간에 감쇠형 카메라 오프셋 적용.
  - [ ] **히트 플래시 / 히트스톱**: 보스·중형 적 피격 시 짧은 플래시 및 격파 순간 미세한 연출 강화.
- **관련 파일**
  - 수정/추가: `src/views/AudioView.lua`(구현 완료), `src/views/GameView.lua`, `src/scenes/PlayScene.lua`, `src/main.lua`, `src/views/EffectsView.lua`
  - 읽기 전용: `src/models/GameModel.lua`(발행 이벤트 목록 확인)
  - 테스트: `tests/audio_view_test.lua`
- **검증 포인트**
  - [x] `layer_check.lua` 통과 (Model에 `love.audio` 침투 없음, 0건 위반)
  - [x] 헤드리스 목 기반 이벤트→SFX 매핑·레이저 전이·디바운스 테스트 통과 (`tests/audio_view_test.lua` 5/5 통과)
  - [ ] 실게임 실행 시 모든 주요 이벤트에서 음향/시각 피드백 확인

---

### 2단계. 리스크-리워드 전투 시스템 (킬 콤보 & 그레이즈)
단순 회피 위주 플레이에 **공격적 몰아치기(콤보)**와 **아슬아슬한 회피 보상(그레이즈)**을 추가해 점수 및 미사일 순환 루프를 강화합니다.

- **핵심 내용**
  - **킬 콤보(Combo)**: 일정 시간(예: 2.0초) 내 연속 처치 시 콤보 카운트 및 점수 배율(`x1.0` → `x1.5` → `x2.0` 등) 적용, 미사일 충전 가속.
  - **그레이즈(Graze)**: 적 탄환 또는 `Weaver` 레이저가 플레이어 히트박스 외곽 판정(그레이즈 반경)을 스쳐 지나갈 때 탄환당 1회 그레이즈 인정 → 보너스 점수 + 스파크 파티클 이벤트 발행.
- **관련 파일**
  - 수정: `src/models/GameModel.lua`, `src/views/HudView.lua`, `src/views/EffectsView.lua`
  - 읽기 전용: `src/models/PlayerModel.lua`, `src/models/BulletModel.lua`
- **검증 포인트**
  - 콤보 타이머 만료·연장·배율 계산 헤드리스 테스트
  - 동일 탄환 중복 그레이즈 방지(`grazed` 플래그 등) 헤드리스 테스트

---

### 3단계. 방어·역전용 아이템 및 회피 액션 확장 (`shield`, `bomb` 구현 완료)
`ItemModel.registerType` 레지스트리 구조를 활용해 공격·체력 일변도인 아이템 풀에 **생존과 탄막 소거 수단**을 추가합니다.

- **핵심 내용**
  - [x] **에너지 실드(`shield`)**: 1회 피격 무효화 + `1.5초` 무적 + 반경 `120px` 주변 적 탄환 정리 (`PlayerModel`, `GameModel`, `ItemView`, `PlayerView`).
  - [x] **EMP / 스마트 폭탄(`bomb`)**: 기본 `1개` 지급(최대 `3개`), `Q` 키 상승 에지 발동으로 화면 내 적 탄환 전량 소거 + 전체 적/보스 광역 피해(`5`), 좌측 HUD(`EMP %d/%d [Q]`) 및 `EffectsView` 이중 충격파 링 연출(`0.45초`, 최대 반경 `750px`).
  - [ ] *(선택)* **짧은 대시/회피기**: 짧은 쿨다운의 무적 회피 이동으로 `Weaver` 레이저/보스 패턴 능동 돌파.
- **관련 파일**
  - 수정: `src/models/ItemModel.lua`, `src/models/GameModel.lua`, `src/models/PlayerModel.lua`, `src/models/BossPhase.lua`, `src/views/ItemView.lua`, `src/views/PlayerView.lua`, `src/views/HudView.lua`, `src/views/EffectsView.lua`, `src/views/GameView.lua`, `src/controllers/InputController.lua`
  - 테스트: `tests/shield_test.lua`, `tests/emp_bomb_test.lua`, `tests/item_growth_test.lua`
- **검증 포인트**
  - [x] 실드 보유 중 피격 시 라이프 감소 없이 실드만 소모되고 주변 탄환이 제거되는지 테스트 (`tests/shield_test.lua` 4/4 통과)
  - [x] 폭탄 발동 시 적 탄환 제거, 보스/적 피해, HUD/충격파 연출 테스트 (`tests/emp_bomb_test.lua` 6/6 통과, `tests/layer_check.lua` 0건 위반)

---

### 4단계. 보스전 기믹 심화 (구현 완료: `tier 2` 레이저, `tier 3` 호위 적 소환, `tier 4` 부위 파괴, `+5` 보스 주기, `F1` 치트)
`BossModel`의 기존 3상태(`patrol`, `aimed`, `spiral`) + `enraged` 구조에 **티어별 패턴 변주와 공략 루트**를 추가했습니다. (`BossPhase` / `FormationPhase` 주기를 `+5` 웨이브 단위로 조정: `5`=`tier 1`, `10`=`tier 2`, `15`=`tier 3`, `20`=`tier 4`)

- **핵심 내용**
  - [x] **보스 레이저 패턴 (`tier 2`, 10웨이브+)**: `LaserChargeState`(`1.0초` 수직 예고선, 속도 `0.35x`) → `LaserFireState`(`0.8초` 폭 `24px` 수직 레이저, 속도 `0.25x`) 상태 추가, `BossPhase:resolveCollisions` 1회 피격 판정, `BossView` 차징/빔 렌더링.
  - [x] **호위 적 소환 (`tier 3`, 15웨이브+)**: `enraged`(HP 50% 이하) 최초 진입 시 `game.rng` 기반 랜덤 동일 종류 2체 + 다른 종류 1체(총 3체) 1회 소환, 보스 격파 후에도 남은 호위 적 유지.
  - [x] **디버그용 페이즈 클리어 치트**: `PlayScene`에서 `F1` 키 입력 시 `GameModel:debugClearPhase()`로 현재 편대전/보스전을 즉시 클리어.
  - [x] **부위 파괴(서브 포탑, `tier 4`, 20웨이브+)**: 보스 좌우 바깥에 독립 분리된 서브 포탑 2기(각 `24×24`, HP `10`, 자체 조준 탄환 발사)를 두고, 파괴 시 보너스 `500`점 부여·해당 포탑 발사 중단·패턴 약화(`left` 파괴 시 `PatrolState` 원형 탄막 `18→10`/`24→14`, `right` 파괴 시 `AimedState` 조준 탄막 `5→3`/`7→5`).
- **관련 파일**
  - 수정: `src/models/BossModel.lua`, `src/models/BossPhase.lua`, `src/models/FormationPhase.lua`, `src/models/GameModel.lua`, `src/views/BossView.lua`, `src/scenes/PlayScene.lua`
  - 읽기 전용: `src/models/EnemyModel.lua`
  - 테스트: `tests/boss_laser_test.lua`, `tests/boss_escort_test.lua`, `tests/boss_turret_test.lua`, `tests/boss_fsm_test.lua`, `tests/boss_view_test.lua`
- **검증 포인트**
  - [x] `tier 1`(5웨이브) 기존 3상태 유지 및 `tier 2`(10웨이브+) 레이저 차징·발사·피격 판정 테스트 (`tests/boss_laser_test.lua` 5/5 통과)
  - [x] `tier 3`(15웨이브+) 호위 적 3체 1회 소환·중복 방지·격파 후 유지 테스트 (`tests/boss_escort_test.lua` 3/3 통과, `tests/layer_check.lua` 0건 위반)
  - [x] `tier 4`(20웨이브+) 좌우 분리 포탑 생성·피격·파괴 보너스 `500`점·자체 탄환 발사 및 중단·탄막 약화 테스트 (`tests/boss_turret_test.lua` 7/7 통과, `tests/layer_check.lua` 0건 위반)

---

### 5단계. 웨이브 리듬감과 적 시너지
`waves.txt` 기반 편대 구성에 **전술적 우선순위**와 **완급 조절 구간**을 추가합니다.

- **핵심 내용**
  - **신규 적 시너지**: 주변 적에게 보호막을 부여하는 서포터 드론, 또는 처치 시 주변 적에게 폭발 피해를 주는 기뢰형 적 추가.
  - **보너스 웨이브(Challenging Stage)**: 공격 없이 곡예 비행만 하는 편대가 등장해 전멸 시 대량 점수/아이템을 보상하는 휴식·보상 웨이브.
- **관련 파일**
  - 수정: `src/models/EnemyModel.lua`, `src/models/FormationPhase.lua`, `src/models/WaveParser.lua`, `src/waves.txt`, `src/views/EnemyView.lua`
- **검증 포인트**
  - 신규 적 행동/상호작용 및 보너스 웨이브 클리어 보상 헤드리스 테스트
  - `WaveParser` 파싱 호환성 테스트

