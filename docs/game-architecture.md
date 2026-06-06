# Roguelike Survivor - 게임 아키텍처

## 개요

로그라이크 + 뱀파이어 서바이벌 조합 게임의 아키텍처 문서입니다.

## 시스템 구조

### 메인 게임 루프
- `love.load()`: 초기화
- `love.update(dt)`: 상태 업데이트
- `love.draw()`: 렌더링

### 주요 시스템

#### 1. 플레이어 시스템
- **위치**: `game.player`
- **속성**:
  - x, y: 위치
  - width, height: 크기
  - speed: 이동 속도
  - health, maxHealth: 체력
  - invincibleTime, maxInvincibleTime: 무적 시간
- **기능**:
  - WASD/방향키 이동
  - 대각선 이동 속도 정규화
  - 월드 경계 제한

#### 2. 적 시스템
- **위치**: `game.enemies[]`
- **속성**:
  - x, y: 위치
  - width, height: 크기
  - speed: 이동 속도
  - health: 체력
  - velX, velY: 속도 벡터 (부드러운 이동)
- **기능**:
  - 플레이어 추적 AI
  - 부드러운 방향 변경 (lerp)
  - 웨이브 스폰 (매 2초, 최대 10개)

#### 3. 카메라 시스템
- **위치**: `game.camera`
- **속성**:
  - x, y: 카메라 위치
- **기능**:
  - 플레이어 추적 (lerp)
  - 부드러운 이동
  - 떨림 방지 (거리 기반 업데이트 중단)

#### 4. 충돌 감지 시스템
- **알고리즘**: AABB (Axis-Aligned Bounding Box)
- **기능**:
  - 플레이어-적 충돌 감지
  - 무적 시간 중 데미지 무시

#### 5. 월드 시스템
- **위치**: `game.world`
- **속성**:
  - width: 2000
  - height: 2000
- **기능**:
  - 플레이어 경계 제한
  - 적 스폰 범위
  - 월드 경계 시각화

## 데이터 흐름

```
love.update(dt)
  ├─ 무적 시간 감소
  ├─ 카메라 업데이트
  ├─ 플레이어 이동
  ├─ 적 업데이트
  │   ├─ 스폰
  │   ├─ 이동 (부드러운 방향 변경)
  │   └─ 충돌 감지
  └─ 투사체 업데이트 (TODO)

love.draw()
  ├─ 배경
  ├─ 카메라 적용 (push/translate/pop)
  │   ├─ 월드 경계
  │   ├─ 플레이어
  │   ├─ 적
  │   └─ 투사체 (TODO)
  └─ UI (카메라 영향 없음)
```

## 모듈 구조 (향후 계획)

```
project/src/
├── main.lua           # 메인 게임 루프
├── config.lua         # 설정
├── game/
│   ├── state.lua      # 게임 상태 관리
│   ├── player.lua     # 플레이어
│   └── camera.lua     # 카메라
├── enemy/
│   ├── base.lua       # 적 기본 클래스
│   ├── ai.lua         # AI
│   └── spawner.lua    # 스포너
├── combat/
│   ├── collision.lua  # 충돌 감지
│   ├── projectile.lua # 투사체
│   └── damage.lua     # 데미지 계산
├── progression/
│   ├── exp.lua        # 경험치 시스템
│   ├── level.lua      # 레벨업
│   └── skills.lua     # 스킬 풀
├── optimization/
│   ├── object_pool.lua # 오브젝트 풀
│   ├── spatial_hash.lua # 공간 해시
│   └── profiler.lua   # 성능 프로파일링
└── ui/
    ├── hud.lua        # HUD
    └── menu.lua       # 메뉴
```

## 알고리즘

### 1. AABB 충돌 감지
```lua
function checkCollision(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end
```

### 2. 플레이어 추적 AI (부드러운 방향 변경)
```lua
local targetVelX = (dx / dist) * enemy.speed
local targetVelY = (dy / dist) * enemy.speed
enemy.velX = enemy.velX + (targetVelX - enemy.velX) * turnSpeed * dt
enemy.velY = enemy.velY + (targetVelY - enemy.velY) * turnSpeed * dt
```

### 3. 대각선 이동 속도 정규화
```lua
if dx ~= 0 and dy ~= 0 then
    local length = math.sqrt(dx * dx + dy * dy)
    dx = dx / length
    dy = dy / length
end
```

### 4. 카메라 추적 (lerp)
```lua
local lerpFactor = 3.0
game.camera.x = game.camera.x + (targetX - game.camera.x) * lerpFactor * dt
```

## 최적화 계획

### 1단계: 기본 최적화
- Object Pooling: 적/투사체 재사용
- 메모리 관리: 불필요한 객체 생성 회피

### 2단계: 공간 분할
- Spatial Hashing: 충돌 감지 최적화
- Quadtree: 대량 오브젝트 관리

### 3단계: 병렬 처리
- 멀티스레딩: 물리 계산, AI 병렬 처리
- Job System: 작업 큐 기반 병렬 실행

## 성능 목표

- 60 FPS 유지
- 100+ 적 동시 처리
- 메모리 사용량 < 100MB
