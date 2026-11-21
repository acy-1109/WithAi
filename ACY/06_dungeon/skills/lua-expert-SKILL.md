---
name: lua-expert
description: Lua 언어 자체의 문법, 테이블, 메타테이블, 모듈, 성능, 오류 처리를 다룰 때 사용. (MVC 던전 확장 퀴즈 적용 스킬)
---

# 목적

이 스킬은 Lua 언어 자체를 설계, 구현, 디버깅, 리팩터링할 때 사용합니다.
(`.antigravity/skills/lua-expert/SKILL.md` 및 `AGENTS.md` 기반)

## 절차

1. 문제의 Lua 언어 레벨 원인을 먼저 식별합니다.
2. 모듈 경계, 데이터 구조, 함수 책임을 정리합니다. (Model / View / Controller 분리 및 EventBus 디커플링)
3. 암묵적 전역과 불필요한 부수 효과를 제거합니다. (`local M = {} ... return M` 캡슐화, View 의 Model 상태 변경 금지)
4. 메타테이블, 클로저, 반복문, 에러 처리의 의도를 명확히 합니다.
5. 기존 메서드를 수정하지 않고(OCP) 생성자 이벤트 구독과 신규 메서드로 기능을 확장한 뒤 헤드리스 테스트(`dungeon_test.lua`)로 검증합니다.

