# [게임알고리즘(3A)] 기말 과제 최종 보고서

## 1. 프로젝트 개요
- **프로젝트 명**: Roguelike Survivor (SF 테마 로그라이크 액션 게임)
- **제출자**: [학번 및 이름 기재]
- **개발 환경**: LÖVE2D 11.5 / LuaJIT (Lua 5.1 호환)
- **실행 방법**: 프로젝트 루트의 `run.bat` (Windows) 또는 `run.sh` (macOS/Linux) 실행

---

## 2. 요구사항 매핑표 (기능 구현 추적성)

| 요구 기능 | 구현 여부 | 소스코드 파일 및 라인 위치 | 핵심 알고리즘 및 작동 방식 |
| :--- | :---: | :--- | :--- |
| **플레이어 이동** | Y | [player.lua](file:///c:/Users/talon/OneDrive/Desktop/lua/WithAi/project/src/game/player.lua) (L10-L45) | WASD / 방향키 키보드 입력 매핑 처리 및 매 프레임 이동량 합산 |
| **대각선 속도 정규화** | Y | [player.lua](file:///c:/Users/talon/OneDrive/Desktop/lua/WithAi/project/src/game/player.lua) (L31-L36) | X, Y축 동시 입력 시 벡터 크기(L2-norm)로 나누어 속도가 $\sqrt{2}$배 가속되는 현상 방지 |
| **월드 경계 제한** | Y | [player.lua](file:///c:/Users/talon/OneDrive/Desktop/lua/WithAi/project/src/game/player.lua) (L38-L41), <br>[spawner.lua](file:///c:/Users/talon/OneDrive/Desktop/lua/WithAi/project/src/enemy/spawner.lua) | 플레이어 및 모든 적 캐릭터가 2000x2000 월드 경계를 이탈하지 못하도록 Clamp($0, width$) 처리 |
| **카메라 추적 및 LERP** | Y | [camera.lua](file:///c:/Users/talon/OneDrive/Desktop/lua/WithAi/project/src/game/camera.lua) | 플레이어 중심 좌표를 추적하여 부드러운 카메라 선형 보간 이동(Lerp) 구현 |
| **AABB 충돌 감지** | Y | [collision.lua](file:///c:/Users/talon/OneDrive/Desktop/lua/WithAi/project/src/combat/collision.lua) | 두 직사각형 오브젝트의 겹침 여부를 판단하는 경계 상자 충돌 알고리즘 수립 |
| **경험치 및 레벨업** | Y | [exp.lua](file:///c:/Users/talon/OneDrive/Desktop/lua/WithAi/project/src/progression/exp.lua) | 적 처치 시 구슬 스폰, 자석 기능, 경험치 충족 시 레벨 상승 및 3개 옵션 카드 활성화 |
| **액티브 스킬 (10종)** | Y | [skills.lua](file:///c:/Users/talon/OneDrive/Desktop/lua/WithAi/project/src/progression/skills.lua) | Orbiting Orb, Thunder, Blade, Bullet, Laser, Magnetic Field, Meteor, Cutter, Chain, Seeker Orb 각기 다른 쿨다운/타이머와 고유한 연출 물리식 구현 |
| **패시브 업그레이드 (7종)** | Y | [skills.lua](file:///c:/Users/talon/OneDrive/Desktop/lua/WithAi/project/src/progression/skills.lua) | Magnet, Health/Speed/Damage/EXP Boost, Health Regen, Thorns(반사 피해) 속성 튜닝 |
| **보스 상태 머신 (6종)** | Y | [spawner.lua](file:///c:/Users/talon/OneDrive/Desktop/lua/WithAi/project/src/enemy/spawner.lua) | Stage 1~6 각각 고유 테마 보스 구현 (Void Overlord, Infernus Leviathan, Phantom Stalker, Tesla Archon, Aegis, Chronos Weaver) |
| **데이터 영구 세이브** | Y | [main.lua](file:///c:/Users/talon/OneDrive/Desktop/lua/WithAi/project/src/main.lua) (L79-L127) | `save.txt` 파일 생성 및 파싱 작업을 통한 총 스코어, 영구 강화 레벨, 설정 데이터 저장 및 로드 |

---

## 3. 아키텍처 및 모듈 구조 설명

본 프로젝트는 스파게티 코드를 원천 차단하고 높은 유지보수성과 최적화를 실현하기 위해 **느슨한 결합(Loose Coupling) 구조의 모듈식 아키텍처**로 설계되었습니다.

```
project/src/
├── main.lua           # 메인 엔트리 및 LÖVE 콜백 루프 관리
├── conf.lua           # LÖVE 엔진 설정 (창 크기 1220x540, VSync 활성화 등)
├── game/
│   ├── player.lua     # 플레이어 상태 제어 및 이동, UI 렌더링
│   └── camera.lua     # 카메라 LERP 트래킹 및 카메라 쉐이크
├── enemy/
│   └── spawner.lua    # 일반 몬스터 및 스테이지별 보스 스포너, 상태 머신 AI
├── combat/
│   └── collision.lua  # AABB 및 선분-원형 충돌 감지 유틸리티
├── progression/
│   ├── exp.lua        # 경험치 구슬 관리 및 레벨업 로직
│   └── skills.lua     # 10종 액티브 스킬 및 7종 패시브 업그레이드 연산
└── ui/
    └── hud.lua        # 메인 메뉴, 설정, 영구 강화 상점 및 게임 오버 HUD 렌더러
```

### 아키텍처 핵심 설계 특징
1. **Update와 Draw의 철저한 분리**: 
   - `love.update(dt)`에서는 프레임 독립적인 델타 타임(`dt`) 물리 계산만 처리합니다.
   - `love.draw()`에서는 화면 버퍼를 갱신하고 그래픽스 파이프라인을 호출하는 연산만 수행합니다. 드로우 도중 데이터 상태 변경은 절대 일어나지 않습니다.
2. **순환 참조 방지 및 결합도 최소화**:
   - 상호 참조가 잦은 HUD 모듈과 메인 루프 모듈은 초기 로드 단계에서 의존성을 주입(`game.calculateUpgradeBoxes`)받는 구조로 컴파일하여 순환 종속성을 완벽히 우회했습니다.
3. **독자적인 보스 FSM (Finite State Machine)**:
   - 각 보스는 `"normal"`, `"charging"`, `"dashing"`, `"exhausted"`, `"rewinding"` 등 정밀한 상태 변수를 가집니다. 이를 델타 타이머 기반으로 전환하여 상태 전이가 비정상적으로 스킵되는 문제를 완전 배제했습니다.

---

## 4. 품질 개선 내용 및 한계

### 주요 품질 개선점
1. **그리기 순서 레이어링 고정**: 스킬 이펙트나 몬스터들에 의해 플레이어 위치가 보이지 않는 현상을 방지하고자 그리기 레이어를 `바닥/데코 -> 스킬 -> 구슬 -> 몬스터 -> 플레이어 -> HUD` 순서로 명확히 정렬하여 시인성을 극대화했습니다.
2. **상점 격자(Grid) 구조 최적화**: 스킬이 추가됨에 따라 하단 복귀/초기화 버튼과 카드가 겹치던 문제를 가로 3열 격자 배치로 리팩터링하여 해상도 1220x540 내에서 완벽한 레이아웃 공간을 확보했습니다.
3. **단위 테스트 러너 통합**: LuaJIT 인터프리터가 없는 환경에서도 LÖVE2D 엔진 자체를 사용해 GUI 터미널 화면으로 단위 테스트 결과를 한눈에 확인할 수 있는 독창적인 `tests/main.lua` 테스트 러너를 제작하고 VS Code 작업(`tasks.json`)으로 등록했습니다.
4. **스테이지별 동적 테마 배경 구현**: 각 스테이지의 고유 정체성을 강화하기 위해, 배경을 공통 단일 테마에서 탈피하여 6개 스테이지별 독자적 테마(공허 Sector, 마그마 재 표류 및 용암 지열구, 사이버 보드 회로망, 일렉트릭 뇌우 번개 섬광, 황금빛 성역 회전 오라 헤일로, 시간 지동 톱니바퀴)로 세분화하고, 매 프레임 파티클 이동 및 크기 맥동 등의 물리 보간을 연동하여 시각 품질을 고도로 업그레이드했습니다.

### 프로젝트의 한계 및 향후 개선 계획
- **공간 분할 알고리즘 미도입**: 현재 적의 개체수가 300개를 초과할 시 매 프레임 AABB 전수 조사로 인해 CPU 병목 현상이 발생할 우려가 있습니다. 향후 Spatial Hashing이나 Quadtree와 같은 공간 분할 충돌 감지 방식을 도입할 예정입니다.
- **오디오 피드백 부재**: 타격감 증대를 위한 사운드 효과음 및 배경음악 탑재가 설계 단계에서 지연되었습니다. 차기 버전에서 Love.audio 모듈 기반 폴더 연동을 추가할 계획입니다.

---

## 5. 테스트 증빙

### 기능별 테스트 결과
| 테스트 항목 | 테스트 방법 | 결과 | 비고 |
| :--- | :--- | :---: | :--- |
| **플레이어 이동** | WASD/방향키 입력 시 플레이어 이동 확인 | ✓ 통과 | 대각선 속도 정규화 적용 확인 |
| **월드 경계 제한** | 플레이어가 2000x2000 경계를 넘으려 할 때 동작 확인 | ✓ 통과 | Clamp 함수로 경계 제한 |
| **카메라 추적** | 플레이어 이동 시 카메라 부드럽게 추적 확인 | ✓ 통과 | LERP 적용 확인 |
| **AABB 충돌 감지** | 적과 플레이어 충돌 시 체력 감소 확인 | ✓ 통과 | collision.lua 테스트 통과 |
| **무적 시간** | 피격 후 1초 동안 깜빡임 효과 및 추가 피격 방지 확인 | ✓ 통과 | invincibility 타이머 확인 |
| **경험치 시스템** | 적 처치 시 구슬 스폰 및 레벨업 확인 | ✓ 통과 | 경험치 충족 시 옵션 카드 활성화 |
| **액티브 스킬** | 10종 스킬 각각 발동 및 쿨다운 확인 | ✓ 통과 | Orbiting Orb, Thunder 등 |
| **패시브 업그레이드** | 7종 패시브 스탯 증가 확인 | ✓ 통과 | Magnet, Health Boost 등 |
| **보스 상태 머신** | 6종 보스 각 상태 전이 확인 | ✓ 통과 | normal → charging → dashing 등 |
| **데이터 세이브** | 게임 종료 후 save.txt 생성 및 로드 확인 | ✓ 통과 | 총 스코어, 영구 강화 레벨 저장 |

### 테스트 실행 방법
```bash
# 테스트 러너 실행 (LÖVE2D 엔진 사용)
love project/tests/main.lua

# 또는 IDE에서 task "Love2D: Run tests" 실행
```

### 테스트 코드 구조
- `project/tests/collision_test.lua`: AABB 충돌 감지 알고리즘 단위 테스트
- `project/tests/main.lua`: 테스트 러너 및 GUI 결과 표시

---

## 6. 알려진 이슈 및 제한사항

### 현재 알려진 이슈
1. **고밀도 적 스폰 시 프레임 드롭**: 적 개체수가 300개를 초과할 경우 AABB 전수 조사로 인해 성능 저하 발생 (공간 분할 알고리즘 도입으로 해결 예정)
2. **사운드 미구현**: 효과음 및 배경음악이 탑재되지 않아 타격감이 다소 부족함 (Love.audio 모듈 추가 예정)

### 제한사항
1. **해상도 고정**: 현재 1220x540 해상도로 고정되어 있어 다른 해상도에서는 UI 레이아웃이 깨질 수 있음
2. **입력 장치 제한**: 키보드 입력만 지원하며, 게임패드/컨트롤러는 미지원
3. **언어**: 한국어 UI만 지원

---

## 7. 데모 영상

### 데모 영상 링크
- [데모 영상 링크 추가 예정] (3~7분 권장)

### 데모 영상 포함 내용
1. 핵심 기능 시연 (플레이어 이동, 적 추적, 충돌 감지)
2. 스킬 시스템 데모 (액티브 스킬 10종, 패시브 업그레이드 7종)
3. 보스 전투 및 상태 머신 시연
4. 레벨업 및 옵션 선택 시스템
5. 실패/예외 케이스 대응 (무적 시간, 경계 제한)
6. 개선 포인트 간단 설명
