-- TitleScene.lua
-- 타이틀 화면. Enter/Space → 게임 시작, Esc → 종료 요청.
-- love 를 모른다. 필요한 것은 모두 ctx 로 받는다(ctx.scenes 로 다른 씬을 만든다).

local class = require("class")
local TitleView = require("TitleView")

local TitleScene = class()

local function pointInRect(px, py, r)
  return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

--- @param ctx table  { width, height, scenes, quit, ... } (main 이 만든 공용 문맥)
function TitleScene:init(ctx)
  self.ctx = ctx
  self.hovered = false
end

function TitleScene:keypressed(key)
  if key == "return" or key == "space" then
    self.stack:switch(self.ctx.scenes.Play(self.ctx))
  elseif key == "d" then
    self.stack:switch(self.ctx.scenes.Difficulty(self.ctx))
  elseif key == "escape" then
    self.ctx.quit()
  end
end

function TitleScene:mousemoved(x, y)
  local btn = TitleView.getAchievementButtonRect(self.ctx.width, self.ctx.height)
  self.hovered = pointInRect(x, y, btn)
end

function TitleScene:mousepressed(x, y, button)
  if button ~= 1 then
    return
  end
  local btn = TitleView.getAchievementButtonRect(self.ctx.width, self.ctx.height)
  if pointInRect(x, y, btn) and self.ctx.scenes.Achievements then
    self.stack:push(self.ctx.scenes.Achievements(self.ctx))
  end
end

function TitleScene:draw(gfx)
  local best = self.ctx.highScore and self.ctx.highScore.best or 0
  TitleView.draw(gfx, self.ctx.width, self.ctx.height, best, self.hovered)
end

return TitleScene
