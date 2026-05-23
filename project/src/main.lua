local Camera = require("camera")
local WorldAxis = require("worldAxis")
local cam
local isMiddleMouseDown = false
local lastMouseX, lastMouseY
local playerX, playerY = 0, 0
local targetX, targetY = 0, 0
local moveSpeed = 10

function love.load()
    -- 화면 높이의 절반을 orthoSize로 설정하여 1유닛 = 1픽셀 매핑을 기본으로 지정합니다.
    local height = love.graphics.getHeight()
    cam = Camera.new(0, 0, 5)
end

function love.update(dt)
    -- 플레이어를 목표 위치로 이동
    local dx = targetX - playerX
    local dy = targetY - playerY
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance > 0.01 then
        -- 목표 방향으로 이동
        local moveAmount = moveSpeed * dt
        if moveAmount >= distance then
            playerX, playerY = targetX, targetY
        else
            playerX = playerX + (dx / distance) * moveAmount
            playerY = playerY + (dy / distance) * moveAmount
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then -- 왼쪽 버튼
        local worldX, worldY = cam:screenToWorld(x, y)
        targetX, targetY = worldX, worldY
    elseif button == 3 then -- 가운데 버튼
        isMiddleMouseDown = true
        lastMouseX, lastMouseY = x, y
    end
end

function love.mousereleased(x, y, button)
    if button == 3 then
        isMiddleMouseDown = false
    end
end

function love.mousemoved(x, y, dx, dy)
    if isMiddleMouseDown then
        -- 스크린 픽셀 이동량을 월드 좌표로 변환
        local zoom = cam.zoom or 1
        local worldDx = dx / zoom
        local worldDy = -dy / zoom -- Y축은 반대 방향
        cam:move(worldDx, worldDy)
    end
end

function love.wheelmoved(dx, dy)
    -- dy: 휠 이동량 (양수: 줌 아웃, 음수: 줌 인)
    local currentSize = cam:getOrthoSize()
    local newSize = currentSize + dy * 0.5
    -- 최소/최대 줌 제한
    newSize = math.max(1, math.min(newSize, 20))
    cam:setOrthoSize(newSize)
end

local function drawScreenAxis()
    local gr = love.graphics

    gr.setLineWidth(4)

    -- X 축
    gr.setColor(1, 0, 0)
    gr.line(0, 0, 30, 0)

    -- Y 축
    gr.setColor(0, 1, 0)
    gr.line(0, 0, 0, 30)

    gr.setLineWidth(1)
end

function love.draw()
    -- 1. 카메라 좌표계 내에서 월드 축 그리기 (+x, +y)
    cam:apply()
    WorldAxis.drawGrid(10, 1, 1)
    WorldAxis.draw(cam, 3, 4)

    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.circle("fill", playerX, playerY, 0.5)
    cam:reset()

    drawScreenAxis()

    -- 2. 스크린 기준 카메라 정보 출력
    cam:drawInfo(10, 10)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
