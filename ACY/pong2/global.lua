-- global.lua
-- 화면 규격, 물리 상수, 게임 설정 전역/공용 상수 모듈

local M = {
  WINDOW_WIDTH = 800,
  WINDOW_HEIGHT = 600,
  FIXED_DT = 1 / 60,
  MAX_FRAME_TIME = 0.25,

  PADDLE_WIDTH = 12,
  PADDLE_HEIGHT = 80,
  PADDLE_SPEED = 400,

  BALL_RADIUS = 7,
  BALL_INITIAL_SPEED = 280,
  BALL_SPEED_INCREMENT = 1.05,
}

return M

