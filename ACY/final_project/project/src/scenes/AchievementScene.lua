-- AchievementScene.lua
-- 타이틀 화면 위에 뜨는 업적 조회 모달 오버레이(transparent).
-- 마우스 휠 / 스크롤바 드래그로 목록을 탐색하고, 닫기 버튼 클릭 또는 Esc 로 닫는다.

local class = require("class")
local AchievementModel = require("AchievementModel")
local AchievementView = require("AchievementView")

local AchievementScene = class()

AchievementScene.transparent = true

local WHEEL_STEP = 36

local function pointInRect(px, py, r)
  return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

function AchievementScene:init(ctx)
  self.ctx = ctx
  self.achievements = ctx.achievements or AchievementModel()
  self.entries = self.achievements:getCatalogEntries()
  self.scrollOffset = 0
  self.dragging = false
  self.dragStartY = 0
  self.dragStartScroll = 0
  self.closeHovered = false
  self.thumbHovered = false
end

function AchievementScene:_layoutAndMetrics()
  local layout = AchievementView.getLayout(self.ctx.width, self.ctx.height)
  local metrics = AchievementView.getScrollMetrics(layout, #self.entries, self.scrollOffset)
  self.scrollOffset = metrics.scrollOffset
  return layout, metrics
end

function AchievementScene:_setScroll(value)
  local layout = AchievementView.getLayout(self.ctx.width, self.ctx.height)
  local metrics = AchievementView.getScrollMetrics(layout, #self.entries, value)
  self.scrollOffset = metrics.scrollOffset
end

function AchievementScene:keypressed(key)
  if key == "escape" then
    self.stack:pop()
  end
end

function AchievementScene:wheelmoved(_, y)
  if y and y ~= 0 then
    self:_setScroll(self.scrollOffset - y * WHEEL_STEP)
  end
end

function AchievementScene:mousepressed(x, y, button)
  if button ~= 1 then
    return
  end

  local layout, metrics = self:_layoutAndMetrics()

  if pointInRect(x, y, layout.closeBtn) then
    self.stack:pop()
    return
  end

  local thumbRect = {
    x = layout.track.x,
    y = metrics.thumbY,
    w = layout.track.w,
    h = metrics.thumbH,
  }
  if pointInRect(x, y, thumbRect) then
    self.dragging = true
    self.dragStartY = y
    self.dragStartScroll = self.scrollOffset
    return
  end

  if pointInRect(x, y, layout.track) and metrics.movableTrack > 0 and metrics.maxScroll > 0 then
    local ratio = (y - layout.track.y - metrics.thumbH * 0.5) / metrics.movableTrack
    local clampedRatio = math.max(0, math.min(1, ratio))
    self:_setScroll(clampedRatio * metrics.maxScroll)
    self.dragging = true
    self.dragStartY = y
    self.dragStartScroll = self.scrollOffset
  end
end

function AchievementScene:mousemoved(x, y)
  local layout, metrics = self:_layoutAndMetrics()
  self.closeHovered = pointInRect(x, y, layout.closeBtn)

  local thumbRect = {
    x = layout.track.x,
    y = metrics.thumbY,
    w = layout.track.w,
    h = metrics.thumbH,
  }
  self.thumbHovered = pointInRect(x, y, thumbRect)

  if self.dragging and metrics.movableTrack > 0 and metrics.maxScroll > 0 then
    local dy = y - self.dragStartY
    self:_setScroll(self.dragStartScroll + (dy / metrics.movableTrack) * metrics.maxScroll)
  end
end

function AchievementScene:mousereleased(_, _, button)
  if button == 1 then
    self.dragging = false
  end
end

function AchievementScene:draw(gfx)
  AchievementView.draw(gfx, self.ctx.width, self.ctx.height, self.entries, self.scrollOffset, {
    closeHovered = self.closeHovered,
    thumbHovered = self.thumbHovered,
    dragging = self.dragging,
  })
end

return AchievementScene

