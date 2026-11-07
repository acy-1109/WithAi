local AchievementModel = {}
AchievementModel.__index = AchievementModel

function AchievementModel.new(bus, player)
  local self = setmetatable({ bus = bus, player = player, unlocked = false }, AchievementModel)
  -- 적 처치 시 골드가 들어오므로 enemy_killed를 감시
  bus:on("enemy_killed", function()
    if not self.unlocked and self.player.gold >= 15 then
      self.unlocked = true
      self.bus:emit("log_added", { text = "★ 업적 달성: 골드 15 이상 수집!" })
    end
  end)
  return self
end

return AchievementModel