local Camera = require("camera")
local WorldAxis = require("worldAxis")
local cam
local isMiddleMouseDown = false
local lastMouseX, lastMouseY
local playerX, playerY = 0, 0
local moveSpeed = 10
local velocityX, velocityY = 0, 0
local boxRotation = 0
local isLeftButtonPressed = false
local isRightButtonPressed = false
local initialZoom
local boxSizeWorld
local isSpaceHeld = false
local hasStartedFalling = false
local gameStarted = false
local timeScale = 0.0
local gameOver = false
local gameClear = false
local ballSpeedMultipliers = { 1.0, 1.1, 1.2 }
local ballSpeedMultiplierIndex = 1
local blinkTimer = 0
local showingGoalMessage = false
local goalMessageTimer = 0

-- Target System Constants
local BALL_RADIUS = 0.5
local TARGET_RADIUS = 0.3
local TARGET_HP = 2
local TARGET_SCORE = 50
local TARGET_LIFETIME = 5

-- Item System Constants
local ITEM_RADIUS = 0.15
local ITEM_SCORE_PENALTY = 10
local ITEM_LIFETIME = 8

-- Clock Item System Constants
local CLOCK_ITEM_RADIUS = 0.2
local CLOCK_ITEM_TIME_BONUS = 5
local CLOCK_ITEM_LIFETIME = 10
local CLOCK_ITEM_SPAWN_INTERVAL = 15

-- Target System State Variables
local score = 0
local targets = {}
local gameTime = 60
local remainingTime = 60

-- Item System State Variables
local items = {}
local itemSpawnTimer = 0
local itemSpawnInterval = 5

-- Clock Item System State Variables
local clockItems = {}
local clockSpawnTimer = 0

-- Function to spawn a new target inside the box (excluding walls and ball start position)
local function spawnTarget()
    local halfBox = boxSizeWorld / 2
    local minCoord = -halfBox + TARGET_RADIUS
    local maxCoord = halfBox - TARGET_RADIUS

    -- 현재 타겟 수 확인
    local currentTargetCount = #targets

    -- 남은 시간이 40초 이하면 최대 2개, 아니면 1개 스폰 (단, 최대 2개 제한)
    local desiredCount = remainingTime <= 40 and 2 or 1
    local numToSpawn = math.max(0, desiredCount - currentTargetCount)

    for i = 1, numToSpawn do
        local tx, ty
        local startDistanceLimit = TARGET_RADIUS + BALL_RADIUS + 0.5
        repeat
            tx = love.math.random() * (maxCoord - minCoord) + minCoord
            ty = love.math.random() * (maxCoord - minCoord) + minCoord
            local distToStart = math.sqrt(tx * tx + ty * ty)
        until distToStart > startDistanceLimit

        -- Create a new target and add to targets array
        table.insert(targets, {
            x = tx,
            y = ty,
            hp = TARGET_HP,
            timer = TARGET_LIFETIME
        })
    end
end

-- Function to spawn a new item inside the box (excluding walls and ball start position)
local function spawnItem()
    local halfBox = boxSizeWorld / 2
    local minCoord = -halfBox + ITEM_RADIUS
    local maxCoord = halfBox - ITEM_RADIUS

    -- 이미 아이템이 있으면 소환하지 않음
    if #items >= 1 then
        return
    end

    local ix, iy
    local startDistanceLimit = ITEM_RADIUS + BALL_RADIUS + 0.5
    repeat
        ix = love.math.random() * (maxCoord - minCoord) + minCoord
        iy = love.math.random() * (maxCoord - minCoord) + minCoord
        local distToStart = math.sqrt(ix * ix + iy * iy)
    until distToStart > startDistanceLimit

    -- Create a new item and add to items array
    table.insert(items, {
        x = ix,
        y = iy,
        timer = ITEM_LIFETIME
    })
end

-- Function to spawn a new clock item inside the box (excluding walls and ball start position)
local function spawnClockItem()
    local halfBox = boxSizeWorld / 2
    local minCoord = -halfBox + CLOCK_ITEM_RADIUS
    local maxCoord = halfBox - CLOCK_ITEM_RADIUS

    -- 이미 시계 아이템이 있으면 소환하지 않음
    if #clockItems >= 1 then
        return
    end

    local cx, cy
    local startDistanceLimit = CLOCK_ITEM_RADIUS + BALL_RADIUS + 0.5
    repeat
        cx = love.math.random() * (maxCoord - minCoord) + minCoord
        cy = love.math.random() * (maxCoord - minCoord) + minCoord
        local distToStart = math.sqrt(cx * cx + cy * cy)
    until distToStart > startDistanceLimit

    -- Create a new clock item and add to clockItems array
    table.insert(clockItems, {
        x = cx,
        y = cy,
        timer = CLOCK_ITEM_LIFETIME
    })
end

function love.load()
    -- 화면 높이의 절반을 orthoSize로 설정하여 1유닛 = 1픽셀 매핑을 기본으로 지정합니다.
    local height = love.graphics.getHeight()
    cam = Camera.new(0, 0, 5)
    -- 초기 zoom 저장 (박스 크기 고정용)
    initialZoom = height / (2 * 5)
    -- 스크린 400픽셀을 월드 좌표로 변환 (초기 zoom 기준)
    boxSizeWorld = 400 / initialZoom

    score = 0
    spawnTarget()
end

function love.update(dt)
    -- timeScale 적용
    local scaledDt = dt * timeScale

    -- 깜빡이는 텍스트 타이머 업데이트 (게임 시작 전에만)
    if not gameStarted then
        blinkTimer = blinkTimer + dt
    end

    -- 목표 메시지 타이머 업데이트
    if showingGoalMessage then
        goalMessageTimer = goalMessageTimer + dt
        if goalMessageTimer >= 2.0 then
            -- 2초 후 게임 시작
            showingGoalMessage = false
            velocityY = -5
            hasStartedFalling = true
            gameStarted = true
            timeScale = 1.0
        end
    end

    -- 게임 타이머 업데이트 (게임 시작 후에만, 게임 종료 상태가 아닐 때만)
    if gameStarted and not gameOver and not gameClear then
        remainingTime = remainingTime - scaledDt
        if remainingTime <= 0 then
            remainingTime = 0
            -- 게임 종료 처리: 점수에 따라 클리어/오버 판정
            if score >= 500 then
                gameClear = true
            else
                gameOver = true
            end
        end
    end

    -- 타겟 타이머 업데이트 및 시간 초과 처리 (게임 시작 후에만, 게임 종료 상태가 아닐 때만)
    if gameStarted and not gameOver and not gameClear then
        for i = #targets, 1, -1 do
            targets[i].timer = targets[i].timer - scaledDt
            if targets[i].timer <= 0 then
                table.remove(targets, i)
                spawnTarget()
            end
        end
    end

    -- 아이템 타이머 업데이트 및 랜덤 소환 (게임 시작 후에만, 게임 종료 상태가 아닐 때만)
    if gameStarted and not gameOver and not gameClear then
        -- 아이템 타이머 업데이트
        for i = #items, 1, -1 do
            items[i].timer = items[i].timer - scaledDt
            if items[i].timer <= 0 then
                table.remove(items, i)
            end
        end

        -- 랜덤 소환 타이머 업데이트
        itemSpawnTimer = itemSpawnTimer + scaledDt
        if itemSpawnTimer >= itemSpawnInterval then
            itemSpawnTimer = 0
            spawnItem()
        end
    end

    -- 시계 아이템 타이머 업데이트 및 랜덤 소환 (게임 시작 후에만, 게임 종료 상태가 아닐 때만)
    if gameStarted and not gameOver and not gameClear then
        -- 시계 아이템 타이머 업데이트
        for i = #clockItems, 1, -1 do
            clockItems[i].timer = clockItems[i].timer - scaledDt
            if clockItems[i].timer <= 0 then
                table.remove(clockItems, i)
            end
        end

        -- 랜덤 소환 타이머 업데이트
        clockSpawnTimer = clockSpawnTimer + scaledDt
        if clockSpawnTimer >= CLOCK_ITEM_SPAWN_INTERVAL then
            clockSpawnTimer = 0
            spawnClockItem()
        end
    end

    -- 게임 로직 (게임 시작 후에만, 게임 종료 상태가 아닐 때만)
    if gameStarted and not gameOver and not gameClear then
        -- 박스 회전 (버튼 눌림 상태에 따라)
        local rotationSpeed = math.rad(45) -- 초당 45도 (느리게)
        if isLeftButtonPressed then
            boxRotation = boxRotation - rotationSpeed * scaledDt
        end
        if isRightButtonPressed then
            boxRotation = boxRotation + rotationSpeed * scaledDt
        end

        -- 속도 적용
        playerX = playerX + velocityX * scaledDt
        playerY = playerY + velocityY * scaledDt

        -- 박스 충돌 감지 (월드 좌표계 - 고정 크기)
        local halfBox = boxSizeWorld / 2

        -- 박스 회전을 고려한 로컬 좌표계로 변환
        local localX = playerX
        local localY = playerY
        local cos_box = math.cos(-boxRotation)
        local sin_box = math.sin(-boxRotation)
        local rotatedLocalX = localX * cos_box - localY * sin_box
        local rotatedLocalY = localX * sin_box + localY * cos_box

        -- 로컬 좌표계에서 충돌 감지
        local collided = false
        local normalX, normalY = 0, 0

        -- X축 충돌 감지
        if rotatedLocalX - BALL_RADIUS < -halfBox then
            rotatedLocalX = -halfBox + BALL_RADIUS
            normalX = -1
            collided = true
        elseif rotatedLocalX + BALL_RADIUS > halfBox then
            rotatedLocalX = halfBox - BALL_RADIUS
            normalX = 1
            collided = true
        end

        -- Y축 충돌 감지
        if rotatedLocalY - BALL_RADIUS < -halfBox then
            rotatedLocalY = -halfBox + BALL_RADIUS
            normalY = -1
            collided = true
        elseif rotatedLocalY + BALL_RADIUS > halfBox then
            rotatedLocalY = halfBox - BALL_RADIUS
            normalY = 1
            collided = true
        end

        -- 타겟과의 충돌 감지 및 반경 충돌 해결
        local targetCollided = false
        local targetNormalX, targetNormalY = 0, 0
        local hitTargetIndex = nil
        for i, t in ipairs(targets) do
            local dx = rotatedLocalX - t.x
            local dy = rotatedLocalY - t.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local minDist = BALL_RADIUS + TARGET_RADIUS
            if dist < minDist then
                targetCollided = true
                hitTargetIndex = i
                local overlap = minDist - dist
                if dist > 0 then
                    targetNormalX = dx / dist
                    targetNormalY = dy / dist
                else
                    targetNormalX = 1
                    targetNormalY = 0
                    overlap = minDist
                end
                -- 밀려남 처리 (로컬 좌표계에서)
                rotatedLocalX = rotatedLocalX + targetNormalX * overlap
                rotatedLocalY = rotatedLocalY + targetNormalY * overlap
                break -- 한 번에 하나의 타겟만 충돌 처리
            end
        end

        -- 아이템과의 충돌 감지 (팅겨지지 않고 점수만 감소)
        for i = #items, 1, -1 do
            local dx = rotatedLocalX - items[i].x
            local dy = rotatedLocalY - items[i].y
            local dist = math.sqrt(dx * dx + dy * dy)
            local minDist = BALL_RADIUS + ITEM_RADIUS
            if dist < minDist then
                -- 점수 감소
                score = score - ITEM_SCORE_PENALTY
                -- 아이템 제거
                table.remove(items, i)
                break -- 한 번에 하나의 아이템만 충돌 처리
            end
        end

        -- 시계 아이템과의 충돌 감지 (시간 추가)
        for i = #clockItems, 1, -1 do
            local dx = rotatedLocalX - clockItems[i].x
            local dy = rotatedLocalY - clockItems[i].y
            local dist = math.sqrt(dx * dx + dy * dy)
            local minDist = BALL_RADIUS + CLOCK_ITEM_RADIUS
            if dist < minDist then
                -- 시간 추가
                remainingTime = remainingTime + CLOCK_ITEM_TIME_BONUS
                -- 시계 아이템 제거
                table.remove(clockItems, i)
                break -- 한 번에 하나의 시계 아이템만 충돌 처리
            end
        end

        -- 충돌 시 반사
        if collided or targetCollided then
            -- 로컬 좌표를 다시 월드 좌표로 변환
            cos_box = math.cos(boxRotation)
            sin_box = math.sin(boxRotation)
            playerX = rotatedLocalX * cos_box - rotatedLocalY * sin_box
            playerY = rotatedLocalX * sin_box + rotatedLocalY * cos_box

            -- 벽 충돌 반사
            if collided then
                -- 법선 벡터를 월드 좌표계로 변환
                local worldNormalX = normalX * cos_box - normalY * sin_box
                local worldNormalY = normalX * sin_box + normalY * cos_box

                -- 법선 벡터 정규화 (꼭짓점 충돌 시 대각선 법선 처리)
                local normalLength = math.sqrt(worldNormalX * worldNormalX + worldNormalY * worldNormalY)
                if normalLength > 0 then
                    worldNormalX = worldNormalX / normalLength
                    worldNormalY = worldNormalY / normalLength
                end

                -- 속도 반사 (v' = v - 2 * (v · n) * n)
                local dot = velocityX * worldNormalX + velocityY * worldNormalY
                velocityX = velocityX - 2 * dot * worldNormalX
                velocityY = velocityY - 2 * dot * worldNormalY
            end

            -- 타겟 충돌 반사 및 체력 감소
            if targetCollided then
                -- 법선 벡터를 월드 좌표계로 변환
                local worldNormalX = targetNormalX * cos_box - targetNormalY * sin_box
                local worldNormalY = targetNormalX * sin_box + targetNormalY * cos_box

                -- 법선 벡터 정규화
                local normalLength = math.sqrt(worldNormalX * worldNormalX + worldNormalY * worldNormalY)
                if normalLength > 0 then
                    worldNormalX = worldNormalX / normalLength
                    worldNormalY = worldNormalY / normalLength
                end

                -- 속도 반사 (v' = v - 2 * (v · n) * n)
                local dot = velocityX * worldNormalX + velocityY * worldNormalY
                velocityX = velocityX - 2 * dot * worldNormalX
                velocityY = velocityY - 2 * dot * worldNormalY

                -- 타겟 체력 감소 및 처치 판정
                if hitTargetIndex then
                    targets[hitTargetIndex].hp = targets[hitTargetIndex].hp - 1
                    -- HP가 2에서 1로 감소할 때 쿨타임 초기화
                    if targets[hitTargetIndex].hp == 1 then
                        targets[hitTargetIndex].timer = TARGET_LIFETIME
                    end
                    if targets[hitTargetIndex].hp <= 0 then
                        score = score + TARGET_SCORE
                        table.remove(targets, hitTargetIndex)
                        spawnTarget()
                    end
                end
            end
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then -- 왼쪽 버튼
        local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()

        -- 게임 클리어 화면 버튼 처리
        if gameClear then
            local buttonWidth = 200
            local buttonHeight = 50
            local buttonY = screenHeight / 2 + 50

            -- Next Stage 버튼
            local nextStageX = (screenWidth - buttonWidth) / 2
            if x >= nextStageX and x <= nextStageX + buttonWidth and y >= buttonY and y <= buttonY + buttonHeight then
                -- 게임 재시작 (다음 스테이지 로직은 추후 추가)
                playerX, playerY = 0, 0
                velocityX, velocityY = 0, 0
                boxRotation = 0
                isSpaceHeld = false
                hasStartedFalling = false
                gameStarted = false
                showingGoalMessage = false
                goalMessageTimer = 0
                timeScale = 0.0
                ballSpeedMultiplierIndex = 1
                score = 0
                remainingTime = 60
                gameOver = false
                gameClear = false
                targets = {}
                items = {}
                itemSpawnTimer = 0
                clockItems = {}
                clockSpawnTimer = 0
                spawnTarget()
                return
            end

            -- Quit 버튼
            local quitX = (screenWidth - buttonWidth) / 2
            if x >= quitX and x <= quitX + buttonWidth and y >= buttonY + 70 and y <= buttonY + 70 + buttonHeight then
                love.event.quit()
                return
            end
        end

        -- 게임 오버 화면 버튼 처리
        if gameOver then
            local buttonWidth = 200
            local buttonHeight = 50
            local buttonY = screenHeight / 2 + 50

            -- Retry 버튼
            local retryX = (screenWidth - buttonWidth) / 2
            if x >= retryX and x <= retryX + buttonWidth and y >= buttonY and y <= buttonY + buttonHeight then
                -- 게임 재시작
                playerX, playerY = 0, 0
                velocityX, velocityY = 0, 0
                boxRotation = 0
                isSpaceHeld = false
                hasStartedFalling = false
                gameStarted = false
                showingGoalMessage = false
                goalMessageTimer = 0
                timeScale = 0.0
                ballSpeedMultiplierIndex = 1
                score = 0
                remainingTime = 60
                gameOver = false
                gameClear = false
                targets = {}
                items = {}
                itemSpawnTimer = 0
                clockItems = {}
                clockSpawnTimer = 0
                spawnTarget()
                return
            end

            -- Quit 버튼
            local quitX = (screenWidth - buttonWidth) / 2
            if x >= quitX and x <= quitX + buttonWidth and y >= buttonY + 70 and y <= buttonY + 70 + buttonHeight then
                love.event.quit()
                return
            end
        end

        -- 게임 중 버튼 클릭 감지
        local boxSize = 400
        local boxX = (screenWidth - boxSize) / 2
        local boxY = (screenHeight - boxSize) / 2
        local buttonSize = 80

        -- 왼쪽 버튼 (반시계 방향)
        local leftButtonX = boxX - buttonSize - 20
        local leftButtonY = boxY + boxSize + 10
        if x >= leftButtonX and x <= leftButtonX + buttonSize and y >= leftButtonY and y <= leftButtonY + buttonSize then
            isLeftButtonPressed = true
            return
        end

        -- 오른쪽 버튼 (시계 방향)
        local rightButtonX = boxX + boxSize + 20
        local rightButtonY = boxY + boxSize + 10
        if x >= rightButtonX and x <= rightButtonX + buttonSize and y >= rightButtonY and y <= rightButtonY + buttonSize then
            isRightButtonPressed = true
            return
        end
    elseif button == 3 then -- 가운데 버튼
        isMiddleMouseDown = true
        lastMouseX, lastMouseY = x, y
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then -- 왼쪽 버튼
        isLeftButtonPressed = false
        isRightButtonPressed = false
    elseif button == 3 then
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
    -- 최소/최대 줌 제한 (너무 가까우면 버그, 너무 멀면 그리드 벗어남)
    newSize = math.max(3, math.min(newSize, 10))
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

    -- 화면 중앙에 정사각형 박스 (월드 좌표계 - 고정 크기)
    local halfBox = boxSizeWorld / 2

    -- 박스 회전 적용
    love.graphics.push()
    love.graphics.rotate(boxRotation)
    love.graphics.setColor(1, 1, 1, 1)
    local zoom = cam.zoom or 1
    love.graphics.setLineWidth(1 / zoom)
    love.graphics.rectangle("line", -halfBox, -halfBox, boxSizeWorld, boxSizeWorld)

    -- 타겟 그리기 (박스 내부 로컬 좌표계 기준)
    for _, t in ipairs(targets) do
        -- 체력별 색상 (HP 2 -> 빨강, HP 1 -> 주황)
        if t.hp == 2 then
            love.graphics.setColor(1.0, 0.0, 0.0, 1)
        else
            love.graphics.setColor(1.0, 0.5, 0.0, 1)
        end
        love.graphics.circle("fill", t.x, t.y, TARGET_RADIUS)

        -- 타겟 외곽선 (내부 색상과 동일)
        love.graphics.setLineWidth(1.5 / zoom)
        love.graphics.circle("line", t.x, t.y, TARGET_RADIUS)

        -- 타겟 생성 후 남은 시간 표시하는 원형 링
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.setLineWidth(1 / zoom)
        local timerRatio = math.max(0, t.timer / TARGET_LIFETIME)
        love.graphics.arc("line", "open", t.x, t.y, TARGET_RADIUS + 0.15, -math.pi / 2,
            -math.pi / 2 + timerRatio * 2 * math.pi)
    end

    -- 아이템 그리기 (박스 내부 로컬 좌표계 기준)
    for _, item in ipairs(items) do
        -- 보라색 원
        love.graphics.setColor(0.5, 0.0, 0.5, 1)
        love.graphics.circle("fill", item.x, item.y, ITEM_RADIUS)

        -- 아이템 외곽선
        love.graphics.setLineWidth(1.5 / zoom)
        love.graphics.circle("line", item.x, item.y, ITEM_RADIUS)
    end

    -- 시계 아이템 그리기 (박스 내부 로컬 좌표계 기준)
    for _, clockItem in ipairs(clockItems) do
        -- 파란색 원 (시계 본체)
        love.graphics.setColor(0.0, 0.5, 1.0, 1)
        love.graphics.circle("fill", clockItem.x, clockItem.y, CLOCK_ITEM_RADIUS)

        -- 시계 외곽선
        love.graphics.setLineWidth(1.5 / zoom)
        love.graphics.circle("line", clockItem.x, clockItem.y, CLOCK_ITEM_RADIUS)

        -- 시계 바늘 (12시 방향에서 시작)
        love.graphics.setLineWidth(2 / zoom)
        love.graphics.setColor(1, 1, 1, 1)
        -- 시침
        love.graphics.line(clockItem.x, clockItem.y, clockItem.x, clockItem.y - CLOCK_ITEM_RADIUS * 0.6)
        -- 분침
        love.graphics.line(clockItem.x, clockItem.y, clockItem.x + CLOCK_ITEM_RADIUS * 0.4, clockItem.y)
    end

    love.graphics.setLineWidth(1)
    love.graphics.pop()

    cam:reset()

    drawScreenAxis()

    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()

    -- 화면 상단 중앙에 남은 시간 표시
    local timeText = string.format("TIME : %.1f", remainingTime)
    local font = love.graphics.getFont()
    local timeWidth = font:getWidth(timeText)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(timeText, (screenWidth - timeWidth) / 2, 20)

    -- 화면 상단 중앙에 점수 표시
    local scoreText = string.format("SCORE : %d", score)
    local textWidth = font:getWidth(scoreText)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(scoreText, (screenWidth - textWidth) / 2, 50)

    -- 버튼은 스크린 좌표계에서 그리기
    local boxSize = 400
    local boxX = (screenWidth - boxSize) / 2
    local boxY = (screenHeight - boxSize) / 2

    -- 왼쪽 하단 버튼 (반시계 방향 회전) - 삼각형
    local buttonSize = 80
    local leftButtonX = boxX - buttonSize - 20
    local leftButtonY = boxY + boxSize + 10 -- 아래로 조정
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.polygon("fill",
        leftButtonX + buttonSize - 10, leftButtonY + 10,
        leftButtonX + buttonSize - 10, leftButtonY + buttonSize - 10,
        leftButtonX + 10, leftButtonY + buttonSize / 2
    )
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.polygon("line",
        leftButtonX + buttonSize - 10, leftButtonY + 10,
        leftButtonX + buttonSize - 10, leftButtonY + buttonSize - 10,
        leftButtonX + 10, leftButtonY + buttonSize / 2
    )

    -- 오른쪽 하단 버튼 (시계 방향 회전) - 삼각형
    local rightButtonX = boxX + boxSize + 20
    local rightButtonY = boxY + boxSize + 10 -- 아래로 조정
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.polygon("fill",
        rightButtonX + 10, rightButtonY + 10,
        rightButtonX + 10, rightButtonY + buttonSize - 10,
        rightButtonX + buttonSize - 10, rightButtonY + buttonSize / 2
    )
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.polygon("line",
        rightButtonX + 10, rightButtonY + 10,
        rightButtonX + 10, rightButtonY + buttonSize - 10,
        rightButtonX + buttonSize - 10, rightButtonY + buttonSize / 2
    )

    -- 2. 스크린 기준 카메라 정보 출력
    cam:drawInfo(10, 20)

    -- 속도 배율 표시
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print(
        string.format("Ball Speed: %.1fx\nTime Scale: %.1fx", ballSpeedMultipliers[ballSpeedMultiplierIndex], timeScale),
        10, 190
    )
    love.graphics.setColor(r, g, b, a)

    -- 3. 마우스 위치 표시
    local mx, my = love.mouse.getPosition()
    local worldMx, worldMy = cam:screenToWorld(mx, my)

    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(0.5, 0.8, 1, 1)
    love.graphics.print(
        string.format("Mouse Position\nScreen: (%d, %d)\nWorld: (%.2f, %.2f)", mx, my, worldMx, worldMy),
        10, 240
    )
    love.graphics.setColor(r, g, b, a)

    -- 오른쪽 상단에 키 설명 표시
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(1, 1, 1, 1)
    local keyHelpText = "Space = SlowTime\nR = Reset\nS = Increase Speed"
    local keyHelpFont = love.graphics.newFont(16)
    local keyHelpWidth = keyHelpFont:getWidth(keyHelpText)
    love.graphics.setFont(keyHelpFont)
    love.graphics.print(keyHelpText, screenWidth - keyHelpWidth - 10, 10)
    love.graphics.setFont(love.graphics.getFont()) -- 기본 폰트로 복원
    love.graphics.setColor(r, g, b, a)

    -- 게임 클리어 화면
    if gameClear then
        local originalFont = love.graphics.getFont()
        love.graphics.setColor(0, 1, 0, 1)
        local clearFont = love.graphics.newFont(64)
        love.graphics.setFont(clearFont)
        local clearText = "CLEAR"
        local clearWidth = clearFont:getWidth(clearText)
        love.graphics.print(clearText, (screenWidth - clearWidth) / 2, screenHeight / 3)

        -- 버튼 설정
        local buttonWidth = 200
        local buttonHeight = 50
        local buttonY = screenHeight / 2 + 50

        -- Next Stage 버튼
        love.graphics.setColor(0.2, 0.8, 0.2, 1)
        love.graphics.rectangle("fill", (screenWidth - buttonWidth) / 2, buttonY, buttonWidth, buttonHeight)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", (screenWidth - buttonWidth) / 2, buttonY, buttonWidth, buttonHeight)
        local buttonFont = love.graphics.newFont(24)
        love.graphics.setFont(buttonFont)
        local nextStageText = "Next Stage"
        local nextStageWidth = buttonFont:getWidth(nextStageText)
        love.graphics.print(nextStageText, (screenWidth - nextStageWidth) / 2, buttonY + 10)

        -- Quit 버튼
        love.graphics.setColor(0.8, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", (screenWidth - buttonWidth) / 2, buttonY + 70, buttonWidth, buttonHeight)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", (screenWidth - buttonWidth) / 2, buttonY + 70, buttonWidth, buttonHeight)
        local quitText = "Quit"
        local quitWidth = buttonFont:getWidth(quitText)
        love.graphics.print(quitText, (screenWidth - quitWidth) / 2, buttonY + 80)

        love.graphics.setFont(originalFont)
    end

    -- 게임 오버 화면
    if gameOver then
        local originalFont = love.graphics.getFont()
        love.graphics.setColor(1, 0, 0, 1)
        local gameOverFont = love.graphics.newFont(64)
        love.graphics.setFont(gameOverFont)
        local gameOverText = "GAME OVER"
        local gameOverWidth = gameOverFont:getWidth(gameOverText)
        love.graphics.print(gameOverText, (screenWidth - gameOverWidth) / 2, screenHeight / 3)

        -- 버튼 설정
        local buttonWidth = 200
        local buttonHeight = 50
        local buttonY = screenHeight / 2 + 50

        -- Retry 버튼
        love.graphics.setColor(0.2, 0.6, 0.8, 1)
        love.graphics.rectangle("fill", (screenWidth - buttonWidth) / 2, buttonY, buttonWidth, buttonHeight)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", (screenWidth - buttonWidth) / 2, buttonY, buttonWidth, buttonHeight)
        local buttonFont = love.graphics.newFont(24)
        love.graphics.setFont(buttonFont)
        local retryText = "Retry"
        local retryWidth = buttonFont:getWidth(retryText)
        love.graphics.print(retryText, (screenWidth - retryWidth) / 2, buttonY + 10)

        -- Quit 버튼
        love.graphics.setColor(0.8, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", (screenWidth - buttonWidth) / 2, buttonY + 70, buttonWidth, buttonHeight)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", (screenWidth - buttonWidth) / 2, buttonY + 70, buttonWidth, buttonHeight)
        local quitText = "Quit"
        local quitWidth = buttonFont:getWidth(quitText)
        love.graphics.print(quitText, (screenWidth - quitWidth) / 2, buttonY + 80)

        love.graphics.setFont(originalFont)
    end

    -- 게임 시작 전에 깜빡이는 시작 메시지 표시 (가장 마지막에 그려서 다른 요소 위에 표시)
    if not gameStarted and not showingGoalMessage then
        local originalFont = love.graphics.getFont()
        local blinkAlpha = (math.sin(blinkTimer * 3) + 1) / 2 -- 0~1 사이로 깜빡임
        love.graphics.setColor(1, 1, 1, blinkAlpha)
        local startText = "Press SPACE to Start"
        local largeFont = love.graphics.newFont(32)
        local textWidth = largeFont:getWidth(startText)
        local textHeight = largeFont:getHeight()
        love.graphics.setFont(largeFont)
        love.graphics.print(startText, (screenWidth - textWidth) / 2, screenHeight / 3)
        love.graphics.setFont(originalFont) -- 기본 폰트로 복원
    end

    -- 목표 메시지 표시 (가장 마지막에 그려서 다른 요소 위에 표시)
    if showingGoalMessage then
        local originalFont = love.graphics.getFont()
        love.graphics.setColor(0, 1, 1, 1) -- 시안색으로 변경 (플레이어 노란색과 구분)
        local goalFont = love.graphics.newFont(48)
        local goalText = "Get 500 Score!!"
        local textWidth = goalFont:getWidth(goalText)
        love.graphics.setFont(goalFont)
        love.graphics.print(goalText, (screenWidth - textWidth) / 2, screenHeight / 2 - 24)
        love.graphics.setFont(originalFont)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        isSpaceHeld = true
        if not hasStartedFalling then
            -- 첫 번째 Space: 목표 메시지 표시
            if not showingGoalMessage then
                showingGoalMessage = true
                goalMessageTimer = 0
            end
        else
            -- 게임 시작 후 스페이스바를 누르고 있으면 슬로우 모드 활성화 (게임 시간)
            timeScale = 0.1
        end
    elseif key == "s" then
        -- S 키로 공 속도 배율 순환 (1.0x -> 1.1x -> 1.2x -> 1.0x)
        ballSpeedMultiplierIndex = ballSpeedMultiplierIndex + 1
        if ballSpeedMultiplierIndex > #ballSpeedMultipliers then
            ballSpeedMultiplierIndex = 1
        end
        -- 현재 속도에 배율 적용
        local currentSpeed = math.sqrt(velocityX * velocityX + velocityY * velocityY)
        if currentSpeed > 0 then
            local multiplier = ballSpeedMultipliers[ballSpeedMultiplierIndex]
            velocityX = velocityX * multiplier
            velocityY = velocityY * multiplier
        end
    elseif key == "r" then
        -- 완전 초기화
        playerX, playerY = 0, 0
        velocityX, velocityY = 0, 0
        boxRotation = 0
        isSpaceHeld = false
        hasStartedFalling = false
        gameStarted = false
        timeScale = 0.0
        ballSpeedMultiplierIndex = 1
        score = 0
        remainingTime = 60
        gameOver = false
        gameClear = false
        targets = {}
        items = {}
        itemSpawnTimer = 0
        clockItems = {}
        clockSpawnTimer = 0
        spawnTarget()
    end
end

function love.keyreleased(key)
    if key == "space" then
        isSpaceHeld = false
        -- 스페이스바를 떼면 정상 시간으로 복원
        timeScale = 1.0
    end
end
