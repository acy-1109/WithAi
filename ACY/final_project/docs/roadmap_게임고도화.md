# MVC Galaga 게임 고도화 로드맵

현재 구현된 기본 슈팅, 5종 적(`grunt`, `weaver`, `sniper`, `sprinter`, `tank`), 3페이즈 보스, 아이템 4종(`life`, `attack_up`, `speed_up`, `triple_shot`), 업적/하이스코어 시스템을 바탕으로 **전투 손맛 → 리스크-리워드 → 방어/역전 수단 → 보스/웨이브 깊이** 순으로 확장하기 위한 작업 순서와 설계 메모입니다.

> 원칙: 모든 단계는 한 세션에 1개 단계(또는 1개 기능)씩 진행하며, `models/`의 `love.*` 비의존 원칙과 `tests/layer_check.lua` 0건 위반, 헤드리스 테스트 통과를 유지합니다.

---

## 권장 작업 순서

### 1단계. 타격감(Game Feel) 및 사운드 피드백
기존 `GameModel` 이벤트를 그대로 구독하여 **Model 변경을 최소화하면서** 플레이 체감을 가장 크게 끌어올리는 단계입니다.

- **핵심 내용**
  - **효과음(SFX) 추가**: 발사, `Weaver` 차징/레이저 발사, 피격, 폭발, 아이템 획득, 보스 등장 경고음(`love.audio` 기반 프로시저럴 파형 또는 에셋 로드).
  - **화면 흔들림(Screen Shake)**: 플레이어 피격, `tank`/보스 격파, 레이저 발사 순간에 감쇠형 카메라 오프셋 적용.
  - **히트 플래시 / 히트스톱**: 보스·중형 적 피격 시 짧은 플래시 및 격파 순간 미세한 연출 강화.
- **관련 파일**
  - 수정/추가: `src/views/AudioView.lua`(신규), `src/views/GameView.lua`, `src/views/EffectsView.lua`, `src/scenes/PlayScene.lua`
  - 읽기 전용: `src/models/GameModel.lua`(발행 이벤트 목록 확인)
- **검증 포인트**
  - `layer_check.lua` 통과 (Model에 `love.audio` 침투 없음)
  - 실게임 실행 시 모든 주요 이벤트에서 음향/시각 피드백 확인

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

### 3단계. 방어·역전용 아이템 및 회피 액션 확장
`ItemModel.registerType` 레지스트리 구조를 활용해 공격·체력 일변도인 아이템 풀에 **생존과 탄막 소거 수단**을 추가합니다.

- **핵심 내용**
  - **에너지 실드(`shield`)**: 1회 피격을 무효화하고 짧은 무적 + 주변 탄환 정리.
  - **EMP / 스마트 폭탄(`bomb`)**: 보유 후 키 입력(또는 획득 즉시)으로 화면 내 적 탄환 소거 + 전체 적 광역 피해.
  - *(선택)* **짧은 대시/회피기**: 짧은 쿨다운의 무적 회피 이동으로 `Weaver` 레이저/보스 패턴 능동 돌파.
- **관련 파일**
  - 수정: `src/models/ItemModel.lua`, `src/models/GameModel.lua`, `src/models/PlayerModel.lua`, `src/views/ItemView.lua`, `src/views/PlayerView.lua`, `src/controllers/InputController.lua`
- **검증 포인트**
  - 실드 보유 중 피격 시 라이프 감소 없이 실드만 소모되는지 테스트
  - 폭탄 발동 시 적 탄환 제거 및 보스/적 피해 적용 테스트

---

### 4단계. 보스전 기믹 심화
`BossModel`의 기존 3상태(`patrol`, `aimed`, `spiral`) + `enraged` 구조에 **패턴 변주와 공략 루트**를 추가합니다.

- **핵심 내용**
  - **보스 레이저 패턴**: `Weaver`와 유사하게 예고선 차징 후 굵은 수직/조준 레이저 발사 상태 추가.
  - **호위 적 소환**: `enraged` 진입 시 `grunt` 또는 `weaver` 소환.
  - **부위 파괴(서브 포탑)**: 좌우 파괴 가능 포탑을 두고, 파괴 시 해당 탄막 패턴 약화 및 보너스 점수 부여.
- **관련 파일**
  - 수정: `src/models/BossModel.lua`, `src/models/GameModel.lua`, `src/views/BossView.lua`
  - 읽기 전용: `src/models/BossPhase.lua`, `src/models/EnemyModel.lua`
- **검증 포인트**
  - 보스 FSM 상태 전이 및 소환/레이저/부위 파괴 조건 헤드리스 테스트

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

