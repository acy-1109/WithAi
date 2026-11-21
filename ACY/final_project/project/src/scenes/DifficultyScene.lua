-- DifficultyScene.lua
-- R1: 난이도 선택 씬. ctx 로만 의존하며 love 를 직접 참조하지 않는다.
-- TitleScene 에서 switch 로 진입하고, 선택 완료 시 PlayScene 으로 switch 한다.

local class = require("class")
local DifficultyView = require("DifficultyView")

local DifficultyScene = class()

local OPTIONS = { "easy", "normal", "hard" }

local function findIndex(current)
  for i = 1, #OPTIONS do
    if OPTIONS[i] == current then
      return i
    end
  end
  return 2
end

--- @param ctx table  { width, height, scenes, difficulty, ... }
function DifficultyScene:init(ctx)
  self.ctx = ctx
  self.options = OPTIONS
  self.selected = findIndex(ctx.difficulty)
end

function DifficultyScene:keypressed(key)
  if key == "up" or key == "w" then
    self.selected = ((self.selected - 2) % #self.options) + 1
  elseif key == "down" or key == "s" then
    self.selected = (self.selected % #self.options) + 1
  elseif key == "1" or key == "2" or key == "3" then
    self.selected = tonumber(key)
  elseif key == "return" or key == "space" then
    self.ctx.difficulty = self.options[self.selected]
    self.stack:switch(self.ctx.scenes.Play(self.ctx))
  elseif key == "escape" then
    self.stack:switch(self.ctx.scenes.Title(self.ctx))
  end
end

function DifficultyScene:draw(gfx)
  DifficultyView.draw(gfx, self.ctx.width, self.ctx.height, self.options, self.selected)
end

return DifficultyScene

