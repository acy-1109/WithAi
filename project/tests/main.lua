-- ============================================================================
-- main.lua (tests) — Love2D 기반 단위 테스트 러너 및 시각화 화면
-- ============================================================================

local testOutput = {}

-- print 함수를 재정의하여 테스트 출력을 캡처하고 로그로 저장
local originalPrint = print
_G.print = function(...)
    local args = {...}
    local str = ""
    for i, v in ipairs(args) do
        str = str .. tostring(v) .. (i < #args and "\t" or "")
    end
    originalPrint(str)
    table.insert(testOutput, str)
end

function love.load()
    love.window.setTitle("Roguelike Survivor - Unit Test Runner")
    love.window.setMode(800, 600)
    
    print("==================================================")
    print("Roguelike Survivor - 단위 테스트 러너 시작")
    print("==================================================")
    
    -- collision_test.lua 실행
    local success, err = pcall(function()
        -- 파일 시스템 정보 확인 후 직접 로드
        local info = love.filesystem.getInfo("collision_test.lua")
        if info then
            local chunk = love.filesystem.load("collision_test.lua")
            chunk()
        else
            -- fallback: require 시도
            local ok, testChunk = pcall(require, "collision_test")
            if not ok then
                error("collision_test.lua 파일을 찾을 수 없습니다: " .. tostring(testChunk))
            end
        end
    end)
    
    if not success then
        print("\n[FAIL] 테스트 실행 중 치명적 오류 발생:")
        print(tostring(err))
    else
        print("\n[SUCCESS] 모든 단위 테스트 검증 작업 완료!")
    end
    print("==================================================")
end

function love.draw()
    -- 다크 터미널 테마 배경
    love.graphics.clear(0.07, 0.08, 0.1)
    
    -- 격자 백그라운드 효과 (가시성 향상)
    love.graphics.setColor(0.1, 0.15, 0.2, 0.3)
    love.graphics.setLineWidth(1)
    for x = 0, 800, 40 do
        love.graphics.line(x, 0, x, 600)
    end
    for y = 0, 600, 40 do
        love.graphics.line(0, y, 800, y)
    end
    
    -- 상단 상태 바
    love.graphics.setColor(0.12, 0.2, 0.3, 0.8)
    love.graphics.rectangle("fill", 0, 0, 800, 45)
    love.graphics.setColor(0.2, 0.5, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, 45, 800, 45)
    
    love.graphics.setColor(0.4, 0.8, 1.0)
    local titleFont = love.graphics.newFont(14)
    love.graphics.setFont(titleFont)
    love.graphics.print("🧪 Roguelike Survivor - AUTOMATED TEST SUITE RUNNER", 15, 12)
    
    -- 테스트 결과 줄별 출력
    local textFont = love.graphics.newFont(12)
    love.graphics.setFont(textFont)
    
    local y = 65
    for _, line in ipairs(testOutput) do
        if line:find("PASS") then
            love.graphics.setColor(0.2, 0.9, 0.4) -- 성공: 초록색
        elseif line:find("FAIL") or line:find("ERROR") or line:find("ERR") then
            love.graphics.setColor(1.0, 0.3, 0.3) -- 실패: 빨간색
        elseif line:find("===") or line:find("---") then
            love.graphics.setColor(0.3, 0.6, 0.9) -- 구분선: 파란색
        else
            love.graphics.setColor(0.8, 0.8, 0.85) -- 기본 메시지: 연한 그레이
        end
        love.graphics.print(line, 25, y)
        y = y + 20
        
        -- 스크롤 제한을 위해 화면을 넘어가면 중단
        if y > 530 then
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.print("... (출력 생략됨) ...", 25, y)
            break
        end
    end
    
    -- 하단 정보 바
    love.graphics.setColor(0.1, 0.12, 0.15, 0.9)
    love.graphics.rectangle("fill", 0, 560, 800, 40)
    love.graphics.setColor(0.2, 0.5, 0.8, 0.5)
    love.graphics.line(0, 560, 800, 560)
    
    love.graphics.setColor(0.5, 0.6, 0.7)
    local infoFont = love.graphics.newFont(11)
    love.graphics.setFont(infoFont)
    love.graphics.print("종료하시려면 ESC 키를 누르거나 창을 닫으십시오. | LÖVE2D Test Harness Mode Active", 15, 573)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
