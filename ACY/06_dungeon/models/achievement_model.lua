-- achievement_model.lua
-- 처치 골드 누적 업적 모델. GameModel·PlayerModel 에 의존하지 않고 EventBus 만 구독한다.

local TARGET_GOLD = 15

local AchievementModel = {}
AchievementModel.__index = AchievementModel

function AchievementModel.new(bus, targetGold)
  local self = setmetatable({
    bus = bus,
    target = targetGold or TARGET_GOLD,
    totalGold = 0,
    unlocked = false,
  }, AchievementModel)

  bus:on("enemy_killed", function(payload)
    self:onEnemyKilled(payload)
  end)
  return self
end

function AchievementModel:onEnemyKilled(payload)
  local gained = (payload and payload.gold) or 0
  self.totalGold = self.totalGold + gained
  if not self.unlocked and self.totalGold >= self.target then
    self.unlocked = true
    self.bus:emit("achievement_unlocked", {
      text = string.format("처치 골드 %d 이상 획득", self.target),
      gold = self.totalGold,
    })
  end
end

return AchievementModel
