local KillListModel = {}
KillListModel.__index = KillListModel

function KillListModel.new(bus)
  local self = setmetatable({ kills = {} }, KillListModel)
  -- enemy_killed 이벤트를 구독하여 처치된 적의 이름을 스스로 수집
  bus:on("enemy_killed", function(payload)
    self.kills[#self.kills + 1] = payload.name
  end)
  return self
end

return KillListModel