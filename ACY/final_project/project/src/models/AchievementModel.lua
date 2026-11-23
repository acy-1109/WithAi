-- AchievementModel.lua
-- GameModel 이 발행한 이벤트(drainEvents)를 구독해 업적을 판정한다.
-- GameModel 은 업적을 모른다(Observer 패턴). love / io / print 비의존.

local class = require("class")

local AchievementModel = class()

local ACHIEVEMENTS = {
  first_blood = "FIRST BLOOD",
  streak_10 = "10 KILL STREAK",
  flawless_wave = "FLAWLESS WAVE",
  boss_slayer = "BOSS SLAYER",
  trigger_happy = "TRIGGER HAPPY",
}

function AchievementModel:init()
  self.unlocked = {}
  self.unlockedOrder = {}
  self.streak = 0
  self.shots = 0
  self.waveHit = false
end

function AchievementModel:_unlock(id, newly)
  if self.unlocked[id] then
    return
  end
  self.unlocked[id] = true
  local item = { id = id, title = ACHIEVEMENTS[id] or id }
  self.unlockedOrder[#self.unlockedOrder + 1] = item
  newly[#newly + 1] = item
end

--- GameModel 이벤트 1건을 구독해 처리하고, 이번에 새로 해금된 업적 목록을 반환한다.
function AchievementModel:onEvent(ev)
  local newly = {}
  if not ev or not ev.type then
    return newly
  end

  if ev.type == "enemy_destroyed" then
    self:_unlock("first_blood", newly)
    self.streak = self.streak + 1
    if self.streak >= 10 then
      self:_unlock("streak_10", newly)
    end
  elseif ev.type == "fire" then
    self.shots = self.shots + 1
    if self.shots >= 100 then
      self:_unlock("trigger_happy", newly)
    end
  elseif ev.type == "player_hit" then
    self.streak = 0
    self.waveHit = true
  elseif ev.type == "formation_cleared" then
    if not self.waveHit then
      self:_unlock("flawless_wave", newly)
    end
    self.waveHit = false
  elseif ev.type == "boss_destroyed" then
    self:_unlock("boss_slayer", newly)
  end

  return newly
end

function AchievementModel:isUnlocked(id)
  return self.unlocked[id] == true
end

function AchievementModel:count()
  return #self.unlockedOrder
end

function AchievementModel:list()
  return self.unlockedOrder
end

return AchievementModel
