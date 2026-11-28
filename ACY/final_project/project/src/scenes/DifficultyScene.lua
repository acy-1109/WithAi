-- DifficultyScene.lua
-- R1: 난이도 선택 씬. ctx 로만 의존하며 love 를 직접 참조하지 않는다.
-- TitleScene 에서 switch 로 진입하고, 선택 완료 시 PlayScene 으로 switch 한다.

local class = require("class")
local DifficultyView = require("DifficultyView")
local ShipCatalog = require("ShipCatalog")

local DifficultyScene = class()

--- @param ctx table  { width, height, scenes, shipId, ... }
function DifficultyScene:init(ctx)
  self.ctx = ctx
  self.options = ShipCatalog.list()
  self.selected = ShipCatalog.indexOf(ctx.shipId)
end

function DifficultyScene:keypressed(key)
  if key == "up" or key == "w" or key == "left" or key == "a" then
    self.selected = ((self.selected - 2) % #self.options) + 1
  elseif key == "down" or key == "s" or key == "right" or key == "d" then
    self.selected = (self.selected % #self.options) + 1
  elseif key == "1" or key == "2" or key == "3" then
    self.selected = tonumber(key)
  elseif key == "return" or key == "space" then
    self.ctx.shipId = self.options[self.selected].id
    self.stack:switch(self.ctx.scenes.Play(self.ctx))
  elseif key == "escape" then
    self.stack:switch(self.ctx.scenes.Title(self.ctx))
  end
end

function DifficultyScene:draw(gfx)
  DifficultyView.draw(gfx, self.ctx.width, self.ctx.height, self.options, self.selected)
end

return DifficultyScene

