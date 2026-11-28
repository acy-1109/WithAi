-- title_buttons_test.lua
-- 타이틀 화면 3개 버튼 배치 순서(START → ACHIEVEMENTS → QUIT), 클릭, 호버, 단축키 제거 검증.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local AchievementModel = require("AchievementModel")
local AchievementScene = require("AchievementScene")
local DifficultyScene = require("DifficultyScene")
local SceneStack = require("SceneStack")
local TitleView = require("TitleView")

local function newTitleApp()
  local ctx = h.fakeCtx()
  ctx.difficulty = "normal"
  ctx.achievements = AchievementModel()
  ctx.scenes.Difficulty = DifficultyScene
  ctx.scenes.Achievements = AchievementScene
  local stack = SceneStack()
  stack:push(ctx.scenes.Title(ctx))
  return stack, ctx
end

local function hasPrinted(gfx, needle)
  for i = 1, #gfx.calls do
    local c = gfx.calls[i]
    if (c.name == "print" or c.name == "printf") and tostring(c.args[1]):find(needle, 1, true) then
      return true
    end
  end
  return false
end

local function buttonCenter(btn)
  return btn.x + btn.w * 0.5, btn.y + btn.h * 0.5
end

h.test("타이틀 버튼은 위에서 아래로 START → ACHIEVEMENTS → QUIT 순서다", function()
  local buttons = TitleView.getButtons(600, 800)
  if #buttons ~= 3 then
    return false
  end
  local expectedIds = { "start", "achievements", "quit" }
  local expectedLabels = { "START", "ACHIEVEMENTS", "QUIT" }
  for i = 1, 3 do
    if buttons[i].id ~= expectedIds[i] or buttons[i].label ~= expectedLabels[i] then
      return false
    end
    if i > 1 and buttons[i].y <= buttons[i - 1].y then
      return false
    end
  end
  local achRect = TitleView.getAchievementButtonRect(600, 800)
  return achRect ~= nil and achRect.y == buttons[2].y and achRect.x == buttons[2].x
end)

h.test("타이틀 화면에 키 안내 텍스트와 DIFFICULTY 버튼이 없고 3개 버튼만 폴리곤으로 그려진다", function()
  local stack = newTitleApp()
  local gfx = h.fakeGfx()
  stack:draw(gfx)
  return h.count(gfx, "rectangle") == 0
    and h.count(gfx, "polygon") == 6
    and hasPrinted(gfx, "START")
    and hasPrinted(gfx, "ACHIEVEMENTS")
    and hasPrinted(gfx, "QUIT")
    and not hasPrinted(gfx, "DIFFICULTY")
    and not hasPrinted(gfx, "Enter / Space")
    and not hasPrinted(gfx, "Esc : QUIT")
end)

h.test("START 클릭 시 DifficultyScene, ACHIEVEMENTS 클릭 시 업적 오버레이, QUIT 클릭 시 종료가 동작한다", function()
  -- 1. START -> Difficulty
  local stack1, ctx1 = newTitleApp()
  local buttons = TitleView.getButtons(ctx1.width, ctx1.height)
  local sx, sy = buttonCenter(buttons[1])
  stack1:mousepressed(sx, sy, 1)
  if stack1:size() ~= 1 or stack1:top().options == nil then
    return false
  end

  -- 2. ACHIEVEMENTS -> Achievements 오버레이 push
  local stack2, _ = newTitleApp()
  local ax, ay = buttonCenter(buttons[2])
  stack2:mousepressed(ax, ay, 1)
  if stack2:size() ~= 2 or stack2:top().transparent ~= true then
    return false
  end

  -- 3. QUIT -> ctx.quit()
  local stack3, ctx3 = newTitleApp()
  local qx, qy = buttonCenter(buttons[3])
  stack3:mousepressed(qx, qy, 1)
  return ctx3.quitCalled == true
end)

h.test("마우스 이동 시 해당 버튼만 hoveredId 로 설정되고 바깥으로 나가면 해제된다", function()
  local stack, ctx = newTitleApp()
  local title = stack:top()
  local buttons = TitleView.getButtons(ctx.width, ctx.height)

  for i = 1, #buttons do
    local cx, cy = buttonCenter(buttons[i])
    stack:mousemoved(cx, cy, 0, 0)
    if title.hoveredId ~= buttons[i].id then
      return false
    end
  end

  stack:mousemoved(5, 5, 0, 0)
  return title.hoveredId == nil
end)

h.test("타이틀 텍스트(GALAGA)는 큰 폰트를 적용한 뒤 기존 폰트로 복원한다", function()
  local defaultFont = { id = "default" }
  local bigFont = { id = "big" }
  local currentFont = defaultFont
  local titleFontDuringPrint = nil
  local calls = {}
  local gfx = {
    newFont = function(size)
      calls.fontSize = size
      return bigFont
    end,
    getFont = function()
      return currentFont
    end,
    setFont = function(f)
      currentFont = f
    end,
    setColor = function() end,
    polygon = function() end,
    printf = function(msg)
      if msg == "GALAGA" then
        titleFontDuringPrint = currentFont
      end
    end,
  }

  TitleView.draw(gfx, 600, 800, 123, nil)
  return calls.fontSize > 30
    and titleFontDuringPrint == bigFont
    and currentFont == defaultFont
end)

h.test("타이틀 화면에서 기존 단축키(Enter, Space, D, Esc)와 우클릭은 동작하지 않는다", function()
  local stack, ctx = newTitleApp()
  local buttons = TitleView.getButtons(ctx.width, ctx.height)

  stack:keypressed("return")
  stack:keypressed("space")
  stack:keypressed("d")
  stack:keypressed("escape")

  local sx, sy = buttonCenter(buttons[1])
  stack:mousepressed(sx, sy, 2)

  return stack:size() == 1
    and stack:top().game == nil
    and stack:top().options == nil
    and ctx.quitCalled == false
end)

h.finish()
