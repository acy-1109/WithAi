-- ============================================================================
-- collision_test.lua — 충돌 감지 테스트
-- ============================================================================

local function testAABBCollision()
    print("=== AABB 충돌 감지 테스트 ===")
    
    -- 테스트 케이스 1: 충돌하는 경우
    local a = {x = 0, y = 0, width = 10, height = 10}
    local b = {x = 5, y = 5, width = 10, height = 10}
    
    local function checkCollision(a, b)
        return a.x < b.x + b.width and
               a.x + a.width > b.x and
               a.y < b.y + b.height and
               a.y + a.height > b.y
    end
    
    local result = checkCollision(a, b)
    print("테스트 1 (충돌):", result == true and "PASS" or "FAIL")
    
    -- 테스트 케이스 2: 충돌하지 않는 경우
    local c = {x = 20, y = 20, width = 10, height = 10}
    result = checkCollision(a, c)
    print("테스트 2 (비충돌):", result == false and "PASS" or "FAIL")
    
    -- 테스트 케이스 3: 경계에 있는 경우 (AABB는 경계가 겹치기만 하는 경우 충돌로 판정하지 않음)
    local d = {x = 10, y = 0, width = 10, height = 10}
    result = checkCollision(a, d)
    print("테스트 3 (경계):", result == false and "PASS" or "FAIL")
end

local function testPlayerMovement()
    print("\n=== 플레이어 이동 테스트 ===")
    
    local player = {
        x = 100,
        y = 100,
        width = 32,
        height = 32,
        speed = 200
    }
    
    local dt = 0.016 -- 60 FPS
    local speed = player.speed * dt
    
    -- 오른쪽 이동
    player.x = player.x + speed
    print("오른쪽 이동:", player.x == 100 + speed and "PASS" or "FAIL")
    
    -- 대각선 이동 속도 정규화 테스트
    local dx = 1
    local dy = 1
    if dx ~= 0 and dy ~= 0 then
        local length = math.sqrt(dx * dx + dy * dy)
        dx = dx / length
        dy = dy / length
    end
    local diagonalSpeed = math.sqrt(dx * dx + dy * dy)
    print("대각선 속도 정규화:", math.abs(diagonalSpeed - 1.0) < 0.0001 and "PASS" or "FAIL")
end

local function testCameraTracking()
    print("\n=== 카메라 추적 테스트 ===")
    
    local camera = {x = 0, y = 0}
    local player = {x = 400, y = 300, width = 32, height = 32}
    local screenWidth = 1220
    local screenHeight = 540
    
    local targetX = player.x - screenWidth / 2 + player.width / 2
    local targetY = player.y - screenHeight / 2 + player.height / 2
    
    local lerpFactor = 3.0
    local dt = 0.016
    
    camera.x = camera.x + (targetX - camera.x) * lerpFactor * dt
    camera.y = camera.y + (targetY - camera.y) * lerpFactor * dt
    
    print("카메라 X 추적:", camera.x < 0 and camera.x > targetX and "PASS" or "FAIL")
    print("카메라 Y 추적:", camera.y > 0 and camera.y < targetY and "PASS" or "FAIL")
end

-- 테스트 실행
testAABBCollision()
testPlayerMovement()
testCameraTracking()

print("\n=== 모든 테스트 완료 ===")
