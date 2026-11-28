-- r1_difficulty_scene_test.lua
-- R1(새 씬: DifficultyScene) 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local SceneStack = require("SceneStack")
local TitleView = require("TitleView")

local function newApp()
  local ctx = h.fakeCtx()
  ctx.difficulty = "normal"
  ctx.scenes.Difficulty = require("DifficultyScene")
  local stack = SceneStack()
  stack:push(ctx.scenes.Title(ctx))
  return stack, ctx
end

local function clickStartButton(stack, ctx)
  local buttons = TitleView.getButtons(ctx.width, ctx.height)
  for i = 1, #buttons do
    if buttons[i].id == "start" then
      local b = buttons[i]
      stack:mousepressed(b.x + b.w * 0.5, b.y + b.h * 0.5, 1)
      return
    end
  end
end

h.test("R1: 타이틀에서 START 버튼 클릭 시 DifficultyScene 으로 switch (스택 1개)", function()
  local stack, ctx = newApp()
  clickStartButton(stack, ctx)
  return stack:size() == 1 and stack:top().options ~= nil and ctx.difficulty == "normal"
end)

h.test("R1: 방향키 위/아래 및 숫자 1~3 으로 난이도 선택 후 Enter 시 PlayScene 진입", function()
  local stack, ctx = newApp()
  clickStartButton(stack, ctx)
  stack:keypressed("down")
  local diff = stack:top()
  local okDown = (diff.selected == 2) -- balanced(1) -> rapid(2)
  stack:keypressed("1")
  local okNum = (diff.selected == 1)
  stack:keypressed("return")
  return okDown and okNum and ctx.shipId == "balanced" and stack:size() == 1 and stack:top().game ~= nil
end)

h.test("R1: 난이도 화면에서 Esc 입력 시 TitleScene 으로 복귀", function()
  local stack, ctx = newApp()
  clickStartButton(stack, ctx)
  stack:keypressed("escape")
  return stack:size() == 1 and stack:top().options == nil
end)

h.test("R1: DifficultyView.draw 가 가짜 gfx 로 정상 호출됨", function()
  local stack, ctx = newApp()
  local gfx = h.fakeGfx()
  clickStartButton(stack, ctx)
  stack:draw(gfx)
  return #gfx.calls > 0
end)

h.finish()
