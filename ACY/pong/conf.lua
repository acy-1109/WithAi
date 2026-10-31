-- conf.lua
-- Pong 창 설정 (LÖVE 11.x / LuaJIT)

function love.conf(t)
  t.window.title = "Pong - ACY"
  t.window.width = 800
  t.window.height = 600
  t.window.resizable = false
  t.window.vsync = 1
  t.console = false
end

