-- TitleScene.lua
-- 타이틀 화면. 마우스 버튼 클릭으로 시작(난도 선택), 업적, 종료를 처리한다.
-- love 를 모른다. 필요한 것은 모두 ctx 로 받는다(ctx.scenes 로 다른 씬을 만든다).

local class = require("class")
local TitleView = require("TitleView")

local TitleScene = class()

local function pointInRect(px, py, r)
  return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local function findButtonId(width, height, x, y)
  local buttons = TitleView.getButtons(width, height)
  for i = 1, #buttons do
    if pointInRect(x, y, buttons[i]) then
      return buttons[i].id
    end
  end
  return nil
end

local ACTIONS = {
  start = function(self)
    if self.ctx.scenes.Difficulty then
      self.stack:switch(self.ctx.scenes.Difficulty(self.ctx))
    else
      self.stack:switch(self.ctx.scenes.Play(self.ctx))
    end
  end,
  achievements = function(self)
    if self.ctx.scenes.Achievements then
      self.stack:push(self.ctx.scenes.Achievements(self.ctx))
    end
  end,
  quit = function(self)
    self.ctx.quit()
  end,
}

--- @param ctx table  { width, height, scenes, quit, ... } (main 이 만든 공용 문맥)
function TitleScene:init(ctx)
  self.ctx = ctx
  self.hoveredId = nil
end

function TitleScene:mousemoved(x, y)
  self.hoveredId = findButtonId(self.ctx.width, self.ctx.height, x, y)
end

function TitleScene:mousepressed(x, y, button)
  if button ~= 1 then
    return
  end
  local id = findButtonId(self.ctx.width, self.ctx.height, x, y)
  local action = id and ACTIONS[id]
  if action then
    action(self)
  end
end

function TitleScene:draw(gfx)
  local best = self.ctx.highScore and self.ctx.highScore.best or 0
  TitleView.draw(gfx, self.ctx.width, self.ctx.height, best, self.hoveredId)
end

return TitleScene
