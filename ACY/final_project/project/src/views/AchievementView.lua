-- AchievementView.lua
-- 업적 목록 모달 오버레이를 그린다. 상태 변경 없이 전달받은 목록과 스크롤 오프셋을 읽기만 한다.

local AchievementView = {}

local max, min = math.max, math.min

local PANEL_W = 480
local PANEL_H = 560
local PAD = 24
local HEADER_H = 64
local LIST_H = 396
local TRACK_W = 14
local TRACK_GAP = 12
local ITEM_H = 92
local ITEM_GAP = 12
local MIN_THUMB_H = 36
local CLOSE_W = 140
local CLOSE_H = 40

--- 화면 크기에 따른 모달·목록·스크롤바·닫기 버튼 레이아웃을 계산한다.
function AchievementView.getLayout(width, height)
  local panelX = (width - PANEL_W) * 0.5
  local panelY = (height - PANEL_H) * 0.5
  local listX = panelX + PAD
  local listY = panelY + HEADER_H
  local listW = PANEL_W - PAD * 2 - TRACK_W - TRACK_GAP
  local trackX = listX + listW + TRACK_GAP
  local closeX = (width - CLOSE_W) * 0.5
  local closeY = panelY + PANEL_H - CLOSE_H - 40

  return {
    panel = { x = panelX, y = panelY, w = PANEL_W, h = PANEL_H },
    list = { x = listX, y = listY, w = listW, h = LIST_H },
    track = { x = trackX, y = listY, w = TRACK_W, h = LIST_H },
    closeBtn = { x = closeX, y = closeY, w = CLOSE_W, h = CLOSE_H },
    itemH = ITEM_H,
    gap = ITEM_GAP,
  }
end

--- 전체 항목 수와 현재 스크롤 위치로부터 스크롤 한계 및 스크롤바 썸 좌표를 계산한다.
function AchievementView.getScrollMetrics(layout, itemCount, scrollOffset)
  local n = itemCount or 0
  local contentH = n > 0 and (n * layout.itemH + (n - 1) * layout.gap) or 0
  local maxScroll = max(0, contentH - layout.list.h)
  local clamped = max(0, min(maxScroll, scrollOffset or 0))
  local trackH = layout.track.h
  local thumbH = contentH <= layout.list.h and trackH or max(MIN_THUMB_H, trackH * (layout.list.h / contentH))
  local movableTrack = max(0, trackH - thumbH)
  local thumbY = layout.track.y + (maxScroll > 0 and (clamped / maxScroll) * movableTrack or 0)

  return {
    contentH = contentH,
    maxScroll = maxScroll,
    scrollOffset = clamped,
    thumbY = thumbY,
    thumbH = thumbH,
    movableTrack = movableTrack,
  }
end

local function drawCards(gfx, layout, entries, scrollOffset)
  local list = layout.list
  local step = layout.itemH + layout.gap

  if gfx.setScissor then
    gfx.setScissor(list.x, list.y, list.w, list.h)
  end

  for i = 1, #entries do
    local entry = entries[i]
    local cardY = list.y + (i - 1) * step - scrollOffset
    if cardY + layout.itemH >= list.y and cardY <= list.y + list.h then
      if entry.unlocked then
        gfx.setColor(0.11, 0.19, 0.28, 0.96)
      else
        gfx.setColor(0.08, 0.09, 0.14, 0.92)
      end
      gfx.rectangle("fill", list.x, cardY, list.w, layout.itemH)

      if entry.unlocked then
        gfx.setColor(0.35, 0.85, 1.0)
      else
        gfx.setColor(0.28, 0.30, 0.38)
      end
      gfx.rectangle("line", list.x, cardY, list.w, layout.itemH)

      if entry.unlocked then
        gfx.setColor(0.4, 1.0, 0.65)
        gfx.print("UNLOCKED", list.x + list.w - 86, cardY + 12)
        gfx.setColor(1.0, 0.92, 0.35)
        gfx.print(entry.title, list.x + 14, cardY + 12)
        gfx.setColor(0.9, 0.94, 1.0)
        gfx.printf(entry.desc, list.x + 14, cardY + 38, list.w - 28, "left")
      else
        gfx.setColor(0.5, 0.52, 0.6)
        gfx.print("LOCKED", list.x + list.w - 70, cardY + 12)
        gfx.setColor(0.6, 0.62, 0.7)
        gfx.print(entry.title, list.x + 14, cardY + 12)
        gfx.setColor(0.5, 0.52, 0.6)
        gfx.printf(entry.desc, list.x + 14, cardY + 38, list.w - 28, "left")
      end
    end
  end

  if gfx.setScissor then
    gfx.setScissor()
  end
end

local function drawScrollbar(gfx, layout, metrics, state)
  local track = layout.track
  gfx.setColor(0.12, 0.14, 0.22)
  gfx.rectangle("fill", track.x, track.y, track.w, track.h)
  gfx.setColor(0.25, 0.30, 0.42)
  gfx.rectangle("line", track.x, track.y, track.w, track.h)

  if state and (state.dragging or state.thumbHovered) then
    gfx.setColor(0.55, 0.92, 1.0)
  else
    gfx.setColor(0.35, 0.68, 0.85)
  end
  gfx.rectangle("fill", track.x + 2, metrics.thumbY + 1, track.w - 4, max(8, metrics.thumbH - 2))
end

local function drawCloseButton(gfx, closeBtn, hovered)
  if hovered then
    gfx.setColor(0.25, 0.34, 0.48)
  else
    gfx.setColor(0.14, 0.18, 0.28)
  end
  gfx.rectangle("fill", closeBtn.x, closeBtn.y, closeBtn.w, closeBtn.h)

  if hovered then
    gfx.setColor(1.0, 0.9, 0.4)
  else
    gfx.setColor(0.5, 0.75, 0.9)
  end
  gfx.rectangle("line", closeBtn.x, closeBtn.y, closeBtn.w, closeBtn.h)

  gfx.setColor(1, 1, 1)
  gfx.printf("CLOSE", closeBtn.x, closeBtn.y + 12, closeBtn.w, "center")
end

function AchievementView.draw(gfx, width, height, entries, scrollOffset, state)
  local list = entries or {}
  local layout = AchievementView.getLayout(width, height)
  local metrics = AchievementView.getScrollMetrics(layout, #list, scrollOffset)

  local unlockedCount = 0
  for i = 1, #list do
    if list[i].unlocked then
      unlockedCount = unlockedCount + 1
    end
  end

  -- 배경 어둡게 덮기
  gfx.setColor(0, 0, 0, 0.65)
  gfx.rectangle("fill", 0, 0, width, height)

  -- 모달 본체
  local panel = layout.panel
  gfx.setColor(0.05, 0.07, 0.13, 0.98)
  gfx.rectangle("fill", panel.x, panel.y, panel.w, panel.h)
  gfx.setColor(0.4, 0.85, 1.0)
  gfx.rectangle("line", panel.x, panel.y, panel.w, panel.h)

  -- 제목
  gfx.setColor(0.4, 0.9, 1.0)
  gfx.printf(string.format("ACHIEVEMENTS (%d/%d)", unlockedCount, #list), panel.x, panel.y + 22, panel.w, "center")

  -- 업적 카드 목록 & 스크롤바
  drawCards(gfx, layout, list, metrics.scrollOffset)
  drawScrollbar(gfx, layout, metrics, state)

  -- 닫기 버튼 및 안내
  drawCloseButton(gfx, layout.closeBtn, state and state.closeHovered)
  gfx.setColor(0.65, 0.7, 0.8)
  gfx.printf("Mouse Wheel / Drag Scrollbar  |  Esc : Close", panel.x, panel.y + panel.h - 24, panel.w, "center")
end

return AchievementView

