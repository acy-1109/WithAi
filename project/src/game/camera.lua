-- ============================================================================
-- camera.lua — 카메라 업데이트 및 부드러운 이동 관리 모듈
-- ============================================================================

local Camera = {}

-- 플레이어를 중심으로 카메라 부드럽게 추적 (lerp 및 떨림 방지)
function Camera.update(game, dt)
    local player = game.player
    if not player then return end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- 카메라가 플레이어를 중심으로 따라옴 (부드러운 이동)
    local targetX = player.x - screenWidth / 2 + player.width / 2
    local targetY = player.y - screenHeight / 2 + player.height / 2

    -- lerp (linear interpolation)로 부드럽게 이동
    local lerpFactor = 3.0
    local dx = targetX - game.camera.x
    local dy = targetY - game.camera.y

    -- 거리가 매우 작으면 업데이트 중단 (떨림 방지)
    if math.abs(dx) < 0.5 then
        game.camera.x = targetX
    else
        game.camera.x = game.camera.x + dx * lerpFactor * dt
    end

    if math.abs(dy) < 0.5 then
        game.camera.y = targetY
    else
        game.camera.y = game.camera.y + dy * lerpFactor * dt
    end
end

return Camera
