-- kill_list_view.lua
-- 과제 2: 처치한 적 목록 위젯 View (ScreenView 규격에 맞춤)

local KillListView = { title = "처치한 적" }
KillListView.__index = KillListView

function KillListView.new(killListModel)
  return setmetatable({ model = killListModel }, KillListView)
end

function KillListView:lines(game)
  local model = self.model or game.killList
  if not model or #model.kills == 0 then
    return { "아직 처치한 적이 없습니다." }
  end
  return { table.concat(model.kills, ", ") }
end

return KillListView
