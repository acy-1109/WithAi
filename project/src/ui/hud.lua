-- ============================================================================
-- hud.lua — 게임 UI, 스킬/특성 선택 박스 및 각종 상태 화면 렌더링 모듈
-- ============================================================================

local HUD = {}

local fontCache = {}
local function getFont(size)
    if not fontCache[size] then
        fontCache[size] = love.graphics.newFont(size)
    end
    return fontCache[size]
end

-- 스킬 선택 박스 레이아웃 계산 (3등분)
function HUD.calculateSkillBoxes(game)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local boxWidth = screenWidth / 3
    local boxHeight = screenHeight

    game.skillBoxes = {}
    for i = 1, 3 do
        game.skillBoxes[i] = {
            x = (i - 1) * boxWidth,
            y = 0,
            width = boxWidth,
            height = boxHeight
        }
    end
end

-- 랜덤 3개 스킬 선택 및 셔플
function HUD.shuffleSkills(game)
    local allIndices = {}
    for i = 1, #game.skills do
        table.insert(allIndices, i)
    end

    -- Fisher-Yates shuffle
    for i = #allIndices, 2, -1 do
        local j = math.random(i)
        allIndices[i], allIndices[j] = allIndices[j], allIndices[i]
    end

    -- 상위 3개 선택
    game.skillOptions = {}
    for i = 1, 3 do
        table.insert(game.skillOptions, allIndices[i])
    end
end

-- 특성 선택 박스 레이아웃 계산 (3등분)
function HUD.calculateUpgradeBoxes(game)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local boxWidth = screenWidth / 3
    local boxHeight = screenHeight

    game.upgradeBoxes = {}
    for i = 1, 3 do
        game.upgradeBoxes[i] = {
            x = (i - 1) * boxWidth,
            y = 0,
            width = boxWidth,
            height = boxHeight
        }
    end
end

-- 시작 스킬 선택 메뉴 렌더링
function HUD.drawMenu(game)
    love.graphics.clear(0.1, 0.1, 0.1)

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- 스킬 박스 그리기
    for i, box in ipairs(game.skillBoxes) do
        local skillIndex = game.skillOptions[i]
        local skill = game.skills[skillIndex]

        -- 박스 배경 및 호버 효과
        local mouseX, mouseY = love.mouse.getPosition()
        local isHovered = mouseX >= box.x and mouseX <= box.x + box.width and
            mouseY >= box.y and mouseY <= box.y + box.height

        if isHovered then
            love.graphics.setColor(0.4, 0.4, 0.6)
        else
            love.graphics.setColor(0.3, 0.3, 0.5)
        end
        love.graphics.rectangle("fill", box.x, box.y, box.width, box.height)

        -- 박스 테두리
        love.graphics.setColor(0.6, 0.6, 0.8)
        love.graphics.rectangle("line", box.x, box.y, box.width, box.height)

        -- 스킬 이름 (박스 중앙 위)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(32))
        love.graphics.printf(skill.name, box.x, box.y + box.height / 2 - 30, box.width, "center")

        -- 스킬 설명 (박스 중앙 아래)
        love.graphics.setFont(getFont(18))
        love.graphics.printf(skill.description, box.x, box.y + box.height / 2 + 20, box.width, "center")
    end

    -- 메인 제목
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(48))
    love.graphics.printf("Roguelike Survivor", 0, 50, screenWidth, "center")

    -- 하단 안내
    love.graphics.setFont(getFont(24))
    love.graphics.printf("Select a skill", 0, screenHeight - 50, screenWidth, "center")
end

-- 특성 및 스킬 선택(업그레이드) 화면 렌더링
function HUD.drawUpgrade(game)
    love.graphics.clear(0.1, 0.1, 0.1)

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- 3분할된 레이아웃 박스 렌더링
    for i, box in ipairs(game.upgradeBoxes) do
        local option = game.upgradeOptions[i]
        if option then
            -- 박스 배경 및 마우스 호버 효과
            local mouseX, mouseY = love.mouse.getPosition()
            local isHovered = mouseX >= box.x and mouseX <= box.x + box.width and
                mouseY >= box.y and mouseY <= box.y + box.height

            if option.type == "skill" then
                -- 스킬 카드: 청회색 계열 (시작 스킬 메뉴와 일관성 부여)
                if isHovered then
                    love.graphics.setColor(0.4, 0.4, 0.6)
                else
                    love.graphics.setColor(0.3, 0.3, 0.5)
                end
            else
                -- 특성 카드: 초록색 계열
                if isHovered then
                    love.graphics.setColor(0.4, 0.6, 0.4)
                else
                    love.graphics.setColor(0.3, 0.5, 0.3)
                end
            end
            love.graphics.rectangle("fill", box.x, box.y, box.width, box.height)

            -- 박스 테두리 그리기
            if option.type == "skill" then
                love.graphics.setColor(0.6, 0.6, 0.8)
            else
                love.graphics.setColor(0.6, 0.8, 0.6)
            end
            love.graphics.rectangle("line", box.x, box.y, box.width, box.height)

            -- 텍스트 렌더링 준비
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(32))

            local nameText, descText = "", ""
            local levelText = ""

            if option.type == "skill" then
                local skill = game.skills[option.index]
                nameText = skill.name
                
                local currentLevel = game.player.skillLevels[option.index] or 0
                if currentLevel == 0 then
                    levelText = "NEW SKILL"
                else
                    levelText = "Level: " .. currentLevel .. " -> " .. (currentLevel + 1)
                end

                if option.index == 2 then
                    local nextLevel = currentLevel + 1
                    if nextLevel == 1 then
                        descText = "Strike lightning on the closest enemy"
                    elseif nextLevel == 2 then
                        descText = "Reduces cooldown & increases damage"
                    elseif nextLevel == 3 then
                        descText = "Increases lightning count to 2 targets"
                    elseif nextLevel == 4 then
                        descText = "Reduces cooldown & increases damage"
                    elseif nextLevel == 5 then
                        descText = "Increases lightning count to 3 targets"
                    else
                        descText = skill.description
                    end
                elseif option.index == 3 then
                    local nextLevel = currentLevel + 1
                    if nextLevel == 1 then
                        descText = "Fires a tracking blade at the closest enemy"
                    elseif nextLevel == 2 then
                        descText = "Reduces cooldown & increases damage"
                    elseif nextLevel == 3 then
                        descText = "Fires 2 blades sequentially"
                    elseif nextLevel == 4 then
                        descText = "Reduces cooldown"
                    elseif nextLevel == 5 then
                        descText = "Fires 3 blades sequentially & increases blade size"
                    else
                        descText = skill.description
                    end
                elseif option.index == 4 then
                    local nextLevel = currentLevel + 1
                    if nextLevel == 1 then
                        descText = "Fires a bullet at the closest enemy"
                    elseif nextLevel == 2 then
                        descText = "Adds piercing effect & reduces cooldown"
                    elseif nextLevel == 3 then
                        descText = "Fires triple shot spread, increases damage & reduces cooldown"
                    elseif nextLevel == 4 then
                        descText = "Reduces cooldown"
                    elseif nextLevel == 5 then
                        descText = "Increases damage & reduces cooldown"
                    else
                        descText = skill.description
                    end
                elseif option.index == 5 then
                    local nextLevel = currentLevel + 1
                    if nextLevel == 1 then
                        descText = "Fires a slow-charging laser beam that follows you for a short duration"
                    elseif nextLevel == 2 then
                        descText = "Increases damage & duration slightly"
                    elseif nextLevel == 3 then
                        descText = "Increases laser thickness, damage & duration"
                    elseif nextLevel == 4 then
                        descText = "Reduces cooldown slightly"
                    elseif nextLevel == 5 then
                        descText = "Hyper Laser: Colossal damage, maximum thickness & longest duration"
                    else
                        descText = skill.description
                    end
                elseif option.index == 6 then
                    local nextLevel = currentLevel + 1
                    if nextLevel == 1 then
                        descText = "Deploys a circular magnetic field around you"
                    elseif nextLevel == 2 then
                        descText = "Increases damage & reduces cooldown"
                    elseif nextLevel == 3 then
                        descText = "Increases duration"
                    elseif nextLevel == 4 then
                        descText = "Increases radius & damage"
                    elseif nextLevel == 5 then
                        descText = "Reduces cooldown"
                    else
                        descText = skill.description
                    end
                else
                    descText = skill.description
                end
            else
                local upgrade = game.upgrades[option.index]
                nameText = upgrade.name
                descText = upgrade.description
            end

            -- 이름 출력 (박스 세로 중앙 기준 살짝 위)
            love.graphics.printf(nameText, box.x, box.y + box.height / 2 - 40, box.width, "center")

            -- 설명 출력
            love.graphics.setFont(getFont(18))
            love.graphics.printf(descText, box.x, box.y + box.height / 2 + 15, box.width, "center")

            -- 하단 부가 정보 렌더링
            if option.type == "skill" then
                -- 스킬: 레벨 텍스트 표시
                love.graphics.setColor(0.9, 0.9, 0.9)
                love.graphics.setFont(getFont(16))
                love.graphics.printf(levelText, box.x, box.y + box.height / 2 + 70, box.width, "center")
            else
                -- 특성: 별 표시 (3회 누적 업그레이드 표시)
                local player = game.player
                if player then
                    local upgradeLevel = player.upgradeLevels[option.index] or 0
                    local starSize = 15
                    local starSpacing = 18
                    local totalWidth = 2 * starSpacing + starSize
                    local startX = box.x + (box.width - totalWidth) / 2
                    local starY = box.y + box.height / 2 + 80

                    for j = 1, 3 do
                        local x = startX + (j - 1) * starSpacing
                        if j <= upgradeLevel then
                            love.graphics.setColor(1.0, 0.8, 0.0) -- 획득한 레벨: 황금색
                        else
                            love.graphics.setColor(0.5, 0.5, 0.5) -- 미획득 레벨: 회색
                        end

                        love.graphics.polygon("fill",
                            x, starY - starSize / 2,
                            x + starSize / 2, starY,
                            x, starY + starSize / 2,
                            x - starSize / 2, starY
                        )
                    end
                end
            end
        end
    end

    -- 상단 제목
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(48))
    love.graphics.printf("Level Up!", 0, 50, screenWidth, "center")

    -- 하단 선택 가이드라인
    love.graphics.setFont(getFont(24))
    love.graphics.printf("Select a skill or upgrade", 0, screenHeight - 50, screenWidth, "center")
end

-- 게임오버 화면 렌더링
function HUD.drawGameOver(game)
    love.graphics.clear(0.1, 0.1, 0.1)

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- Game Over 제목
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.setFont(getFont(48))
    love.graphics.printf("Game Over", 0, screenHeight / 3, screenWidth, "center")

    -- 최종 점수 및 재시작 키 안내
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(24))
    love.graphics.printf("Score: " .. game.score, 0, screenHeight / 2, screenWidth, "center")
    love.graphics.printf("Press R to Restart", 0, screenHeight / 2 + 50, screenWidth, "center")
end

-- 인게임 좌상단 기본 HUD 스탯 표시
function HUD.drawUI(game)
    local player = game.player
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(14)) -- 기본 폰트 크기 재지정 (폰트 오버라이드 방지)
    
    love.graphics.print("Score: " .. game.score, 10, 10)

    if player then
        love.graphics.print("Level: " .. player.level, 10, 30)
    end

    love.graphics.print("Time: " .. string.format("%.1f", game.time), 10, 50)
    love.graphics.print("Wave: " .. (game.wave or 1), 10, 70)
    if game.enemies then
        love.graphics.print("Enemies: " .. #game.enemies, 10, 90)
    end

    -- Draw wave banner
    if game.bannerText and game.bannerTimer and game.bannerTimer > 0 then
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        
        local alpha = 1.0
        if game.bannerTimer < 0.5 then
            alpha = game.bannerTimer / 0.5
        end
        
        -- Dark background band
        love.graphics.setColor(0.04, 0.05, 0.08, alpha * 0.75)
        love.graphics.rectangle("fill", 0, screenHeight / 2 - 60, screenWidth, 120)
        
        -- Border lines on the band (top/bottom)
        love.graphics.setColor(0.2, 0.4, 0.8, alpha * 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.line(0, screenHeight / 2 - 60, screenWidth, screenHeight / 2 - 60)
        love.graphics.line(0, screenHeight / 2 + 60, screenWidth, screenHeight / 2 + 60)
        
        -- Font configuration
        love.graphics.setFont(getFont(40))
        
        -- Drop shadow
        love.graphics.setColor(0, 0, 0, alpha * 0.8)
        love.graphics.printf(game.bannerText, 2, screenHeight / 2 - 23, screenWidth, "center")
        
        -- Main text color
        if string.find(game.bannerText, "CLEAR") then
            love.graphics.setColor(0.2, 0.9, 0.4, alpha) -- Vibrant green
        else
            love.graphics.setColor(1.0, 0.75, 0.1, alpha) -- Golden
        end
        love.graphics.printf(game.bannerText, 0, screenHeight / 2 - 25, screenWidth, "center")
    end

    -- 보스 HP바 그리기 (보스가 존재하는 경우)
    local boss = nil
    if game.enemies then
        for _, enemy in ipairs(game.enemies) do
            if enemy.type == "boss" then
                boss = enemy
                break
            end
        end
    end

    if boss then
        local screenWidth = love.graphics.getWidth()
        local barWidth = 450
        local barHeight = 16
        local barX = (screenWidth - barWidth) / 2
        local barY = 40
        
        -- 보스 이름 출력
        love.graphics.setFont(getFont(18))
        love.graphics.setColor(0.9, 0.2, 0.9) -- 보라색 네온 컬러 느낌
        love.graphics.printf(boss.name or "BOSS", 0, barY - 24, screenWidth, "center")
        
        -- HP바 배경
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 4, 4)
        
        -- HP바 내용물
        local hpRatio = math.max(0, boss.health / boss.maxHealth)
        love.graphics.setColor(0.8, 0.15, 0.15, 0.9)
        love.graphics.rectangle("fill", barX, barY, barWidth * hpRatio, barHeight, 4, 4)
        
        -- HP바 광택 효과
        love.graphics.setColor(1.0, 1.0, 1.0, 0.15)
        love.graphics.rectangle("fill", barX, barY, barWidth * hpRatio, barHeight / 2, 4, 4)
        
        -- HP바 테두리 (네온 파란색/보라색 글로우 테두리)
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.5, 0.2, 0.9, 0.8)
        love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 4, 4)
        
        -- HP 수치 텍스트
        love.graphics.setFont(getFont(12))
        love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
        love.graphics.printf(boss.health .. " / " .. boss.maxHealth, barX, barY + 1, barWidth, "center")
    end
end

return HUD
