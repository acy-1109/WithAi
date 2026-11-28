# MVC Galaga 기말과제 프로젝트

- **학번 / 이름**: 2025391016 / 안찬영
- **출발 코드**: 선택 B (`lua_tuto/mvc/week05/examples/galaga_states`)

## 실행 방법

### 1. 게임 실행 (Windows)
- `run.bat` 더블클릭 또는 터미널에서:
```bat
run.bat
```
*(또는 LÖVE 11.5가 설치된 환경에서 `love project/src`)*

### 2. 테스트 및 경계 검사 실행
`project` 폴더에서 Lua(또는 LuaJIT)로 실행합니다:
```sh
lua tests/layer_check.lua src
lua tests/scene_test.lua src
lua tests/title_buttons_test.lua src
lua tests/r1_difficulty_scene_test.lua src
lua tests/achievement_overlay_test.lua src
lua tests/achievement_catalog_test.lua src
lua tests/player_view_test.lua src
lua tests/bullet_view_test.lua src
lua tests/enemy_view_test.lua src
lua tests/boss_view_test.lua src
lua tests/space_background_test.lua src
```

## 조작법
- 타이틀: 마우스 클릭 — `START`(난이도 선택 이동), `ACHIEVEMENTS`(업적 조회), `QUIT`(종료)
- 업적 창: 마우스 휠 / 스크롤바 드래그 스크롤, `CLOSE` 버튼 클릭 또는 `Esc` 닫기
- 난이도 선택: `↑`/`↓` 또는 `1`~`3` 선택, `Enter`/`Space` 시작, `Esc` 타이틀
- 플레이: `←`/`→` (`A`/`D`) 이동, `Space` 발사, `X` 유도 미사일, `P`/`Esc` 일시정지
- 일시정지: `P`/`Esc` 재개, `Q` 타이틀
- 결과: `R` 재도전, `Enter`/`Esc` 타이틀

