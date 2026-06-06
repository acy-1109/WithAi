# Roguelike Survivor

로그라이크 + 뱀파이어 서바이벌 조합 게임

## 개요

- **엔진**: LÖVE2D 11.5
- **언어**: Lua
- **장르**: 로그라이크 + 뱀파이어 서바이벌
- **목표**: 웨이브 기반 적 소환, 플레이어 추적 AI, 경험치/레벨업 시스템

## 설치

### 사전 요구사항
- LÖVE2D 11.5 이상
  - Windows: `love-11.5-win64/` 디렉토리에 포함
  - macOS: `love-11.5-mac/` 디렉토리에 포함

### 설치 방법
1. 이 저장소를 클론합니다
2. LÖVE2D를 설치합니다 (이미 포함되어 있음)
3. `project/src/` 디렉토리가 있는지 확인합니다

## 실행

### Windows
```bash
run.bat
```

### macOS/Linux
```bash
./run.sh
```

### IDE에서 실행
- VS Code: task "Love2D: Run project"
- 또는 직접 LÖVE2D로 `project/` 디렉토리 실행

## 게임 조작

- **WASD** 또는 **방향키**: 플레이어 이동
- **ESC**: 게임 종료

## 게임 규칙

1. 적들이 플레이어를 추적합니다
2. 적과 충돌하면 체력이 1씩 감소합니다
3. 피격 후 1초 동안 무적 시간이 적용됩니다
4. 체력이 0이 되면 게임이 종료됩니다

## 프로젝트 구조

```
.
├── project/
│   ├── src/           # 실행 코드
│   │   ├── main.lua   # 메인 게임 루프
│   │   └── config.lua # 설정
│   ├── tests/         # 테스트 코드
│   └── doc/           # 설계 문서
├── docs/              # 설계/요약 문서
├── worklogs/          # 작업 로그
│   └── conversations/ # 대화 로그
├── run.bat            # Windows 실행 스크립트
├── run.sh             # macOS/Linux 실행 스크립트
└── README.md          # 이 파일
```

## 검증 방법

### 기능 검증
1. 게임 실행
2. WASD로 플레이어 이동
3. 적 추적 확인
4. 충돌 시 체력 감소 확인
5. 무적 시간 중 깜빡임 효과 확인
6. 카메라가 플레이어를 따라오는지 확인

### 테스트 실행
```bash
# 테스트 파일 실행 (추후 예정)
love project/tests/test_file.lua
```

## 개발 로그

작업 로그는 `worklogs/` 디렉토리에 날짜별로 저장됩니다:
- `worklogs/2026-06-06.md`: 작업 내용
- `worklogs/conversations/2026-06-06.md`: 대화 로그

## 기술 스택

- LÖVE2D 11.5
- Lua 5.1+
- update/draw 책임 분리 원칙
- 모듈형 아키텍처

## 알고리즘

- AABB 충돌 감지
- 플레이어 추적 AI (부드러운 방향 변경)
- 대각선 이동 속도 정규화
- 카메라 추적 (lerp)

## 최적화

- Object Pooling (추후 예정)
- Spatial Hashing (추후 예정)
- 메모리 관리 (추후 예정)

## 라이선스

교육용 프로젝트
