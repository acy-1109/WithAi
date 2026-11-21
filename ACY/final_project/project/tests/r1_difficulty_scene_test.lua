-- r1_difficulty_scene_test.lua
-- R1(새 씬: DifficultyScene) 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local SceneStack = require("SceneStack")

local function newApp()
  local ctx = h.fakeCtx()
  ctx.difficulty = "normal"
  ctx.scenes.Difficulty = require("DifficultyScene")
  local stack = SceneStack()
  stack:push(ctx.scenes.Title(ctx))
  return stack, ctx
end

h.test("R1: 타이틀에서 D 입력 시 DifficultyScene 으로 switch (스택 1개)", function()
  local stack, ctx = newApp()
  stack:keypressed("d")
  return stack:size() == 1 and stack:top().options ~= nil and ctx.difficulty == "normal"
end)

h.test("R1: 방향키 위/아래 및 숫자 1~3 으로 난이도 선택 후 Enter 시 PlayScene 진입", function()
  local stack, ctx = newApp()
  stack:keypressed("d")
  stack:keypressed("down")
  local diff = stack:top()
  local okDown = (diff.selected == 3) -- normal(2) -> hard(3)
  stack:keypressed("1")
  local okNum = (diff.selected == 1)
  stack:keypressed("return")
  return okDown and okNum and ctx.difficulty == "easy" and stack:size() == 1 and stack:top().game ~= nil
end)

h.test("R1: 난이도 화면에서 Esc 입력 시 TitleScene 으로 복귀", function()
  local stack, _ = newApp()
  stack:keypressed("d")
  stack:keypressed("escape")
  return stack:size() == 1 and stack:top().options == nil
end)

h.test("R1: DifficultyView.draw 가 가짜 gfx 로 정상 호출됨", function()
  local stack, _ = newApp()
  local gfx = h.fakeGfx()
  stack:keypressed("d")
  stack:draw(gfx)
  return #gfx.calls > 0
end)

h.finish()
