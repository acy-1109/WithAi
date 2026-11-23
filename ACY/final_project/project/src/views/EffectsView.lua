-- EffectsView.lua
-- 연출(파티클·번쩍임·화면 흔들림·웨이브 배너). 2주차에서 Model 에 섞여 있던 것들이다.
-- Model 이 남긴 이벤트를 받아 "보이는 효과"만 만든다. 연출 상태는 View 의 것이다.
-- 연출용 난수는 게임 규칙에 영향이 없으므로 View 에 있어도 결정성(Model 의 약속)이 깨지지 않는다.

local class = require("class")

local EffectsView = class()

local BURST = 12
local PARTICLE_LIFE = 0.5
local FLASH_TIME = 0.06
local SHAKE_TIME = 0.3
local SHAKE_PIXELS = 10
local BANNER_TIME = 1.0
local NOTICE_TIME = 2.5

--- @param rand function|nil  0~1 난수 함수. 테스트에서 고정값을 주입할 수 있다. 기본 math.random
function EffectsView:init(rand)
  self.rand = rand or math.random
  self.particles = {}
  self.flash = 0
  self.shake = 0
  self.banner = 0
  self.ox, self.oy = 0, 0
  self.noticeQueue = {}
  self.noticeText = nil
  self.noticeTimer = 0
end

local DEFAULT_COLOR = { 1, 0.8, 0.2 }
local SPLIT_COLOR = { 0.85, 0.5, 1.0 }

function EffectsView:_burst(x, y, count, life, minSpeed, speedRange, color, size)
  local n = count or BURST
  local pLife = life or PARTICLE_LIFE
  local sMin = minSpeed or 40
  local sRange = speedRange or 120
  local c = color or DEFAULT_COLOR
  local pSize = size or 3
  for _ = 1, n do
    local a = self.rand() * math.pi * 2
    local s = sMin + self.rand() * sRange
    self.particles[#self.particles + 1] = {
      x = x,
      y = y,
      vx = math.cos(a) * s,
      vy = math.sin(a) * s,
      life = pLife,
      color = c,
      size = pSize,
    }
  end
end

--- Model 이벤트 → 연출. (사운드를 붙인다면 여기서 love.audio 를 호출한다)
function EffectsView:onEvent(ev)
  if ev.type == "enemy_destroyed" then
    self:_burst(ev.x, ev.y)
    self.flash = FLASH_TIME
  elseif ev.type == "bullet_split" then
    self:_burst(ev.x, ev.y, 4, 0.16, 30, 45, SPLIT_COLOR, 2)
  elseif ev.type == "boss_enraged" then
    self.shake = SHAKE_TIME
    self.flash = FLASH_TIME
    self:_burst(ev.x, ev.y, 12, 0.4, 60, 140, { 1.0, 0.25, 0.25 }, 4)
  elseif ev.type == "player_hit" then
    self.shake = SHAKE_TIME
  elseif ev.type == "formation_cleared" then
    self.banner = BANNER_TIME
  elseif ev.type == "achievement_unlocked" then
    self.noticeQueue[#self.noticeQueue + 1] = "ACHIEVEMENT: " .. tostring(ev.title or "")
  end
end

-- 연출 시간 진행. 흔들림 오프셋도 여기서 정해 draw 는 읽기만 한다.
function EffectsView:update(dt)
  if self.flash > 0 then
    self.flash = self.flash - dt
  end
  if self.banner > 0 then
    self.banner = self.banner - dt
  end
  if self.noticeTimer > 0 then
    self.noticeTimer = self.noticeTimer - dt
    if self.noticeTimer <= 0 then
      self.noticeText = nil
    end
  end
  if not self.noticeText and #self.noticeQueue > 0 then
    self.noticeText = table.remove(self.noticeQueue, 1)
    self.noticeTimer = NOTICE_TIME
  end
  if self.shake > 0 then
    self.shake = self.shake - dt
    self.ox = (self.rand() - 0.5) * SHAKE_PIXELS
    self.oy = (self.rand() - 0.5) * SHAKE_PIXELS
  else
    self.ox, self.oy = 0, 0
  end

  local list = self.particles
  for i = #list, 1, -1 do
    local p = list[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(list, i)
    end
  end
end

function EffectsView:drawFlash(gfx, width, height)
  if self.flash > 0 then
    gfx.setColor(0.3, 0.3, 0.4)
    gfx.rectangle("fill", 0, 0, width, height)
  end
end

function EffectsView:drawParticles(gfx)
  for i = 1, #self.particles do
    local p = self.particles[i]
    local c = p.color or DEFAULT_COLOR
    local sz = p.size or 3
    gfx.setColor(c[1], c[2], c[3])
    gfx.rectangle("fill", p.x, p.y, sz, sz)
  end
end

function EffectsView:drawBanner(gfx, width, height)
  if self.banner > 0 then
    gfx.setColor(0.6, 1, 0.6)
    gfx.printf("WAVE CLEAR", 0, height * 0.4, width, "center")
  end
end

function EffectsView:drawAchievement(gfx, width)
  if self.noticeText then
    gfx.setColor(0.15, 0.2, 0.35)
    gfx.rectangle("fill", width * 0.5 - 150, 56, 300, 26)
    gfx.setColor(1.0, 0.9, 0.3)
    gfx.printf(self.noticeText, 0, 62, width, "center")
  end
end

return EffectsView
