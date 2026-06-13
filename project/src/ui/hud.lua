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

-- Detailed lookup table for skill descriptions by level
local skillLevelDescriptions = {
    [1] = { -- Orbiting Orb
        "Spawns an orbiting orb that damages enemies",
        "Adds 1 orbiting orb",
        "Adds 1 orb & increases rotation speed",
        "Adds 1 orb & increases damage",
        "Adds 1 orb & increases rotation speed further",
    },
    [2] = { -- Thunder
        "Strike lightning on the closest enemy",
        "Reduces cooldown & increases damage",
        "Increases lightning count to 2 targets",
        "Reduces cooldown & increases damage",
        "Increases lightning count to 3 targets",
    },
    [3] = { -- Blade
        "Fires a tracking blade at the closest enemy",
        "Reduces cooldown & increases damage",
        "Fires 2 blades sequentially",
        "Reduces cooldown",
        "Fires 3 blades sequentially & increases blade size",
    },
    [4] = { -- Bullet
        "Fires a bullet at the closest enemy",
        "Adds piercing effect & reduces cooldown",
        "Fires triple shot spread, increases damage & reduces cooldown",
        "Reduces cooldown",
        "Increases damage & reduces cooldown",
    },
    [5] = { -- Laser
        "Fires a slow-charging laser beam that follows you for a short duration",
        "Increases damage & duration slightly",
        "Increases laser thickness, damage & duration",
        "Reduces cooldown slightly",
        "Hyper Laser: Colossal damage, maximum thickness & longest duration",
    },
    [6] = { -- Magnetic Field
        "Deploys a circular magnetic field around you",
        "Increases damage & reduces cooldown",
        "Increases duration",
        "Increases radius & damage",
        "Reduces cooldown",
    },
    [7] = { -- Meteor
        "Call down a meteor from the sky that damages enemies and shakes the screen",
        "Reduces cooldown & increases meteor damage",
        "Increases meteor count by 1 target",
        "Leaves burning fire patches on the ground that deal damage over time",
        "Increases meteor count by 1 target",
    },
    [8] = { -- Cutter
        "Sharp energy blade extends from your body and rotates",
        "Adds 1 blade & increases damage",
        "Adds 1 blade & increases rotation speed",
        "Adds 1 blade & increases damage",
        "Adds 1 blade & increases rotation speed"
    },
    [9] = { -- Chain
        "Fires a glowing chain that locks the closest enemy in place and damages them",
        "Increases lock duration",
        "Reaction: Chain cascades from locked enemy to another nearby enemy",
        "Fires 2 chains targeting the 2 closest enemies",
        "Reduces cooldown significantly"
    },
    [10] = { -- Seeker Orb
        "Spawns a charging orb that fires at the closest enemy",
        "Increases the number of spawned orbs to 2",
        "Reduces cooldown and increases orb damage",
        "Increases the number of spawned orbs to 3",
        "Adds a powerful explosion on impact (AoE damage)"
    }
}

-- Detailed lookup table for upgrade descriptions by level
local upgradeLevelDescriptions = {
    [1] = { -- Magnet
        "Attract experience orbs from nearby (+3% range)",
        "Increase attraction range (+6% range)",
        "Increase attraction range further (+9% range)"
    },
    [3] = { -- Speed Boost
        "Increase movement speed by 5%",
        "Increase movement speed by 10%",
        "Increase movement speed by 15%"
    },
    [5] = { -- Health Regen
        "Regenerate 5% of max health every second",
        "Regenerate 10% of max health every second",
        "Regenerate 15% of max health every second"
    },
    [6] = { -- EXP Boost
        "Increase experience gained by 25%",
        "Increase experience gained by 50%",
        "Increase experience gained by 75%"
    },
    [7] = { -- Thorns
        "30% chance to retaliate and damage nearby enemies when hit",
        "60% chance to retaliate and damage nearby enemies when hit",
        "90% chance to retaliate and damage nearby enemies when hit"
    },
    [8] = { -- Energy Shield
        "Generate a block shield every 12 seconds",
        "Generate a block shield every 9 seconds",
        "Generate a block shield every 6 seconds"
    }
}

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

    -- Draw skill selection boxes
    for i, box in ipairs(game.skillBoxes) do
        local skillIndex = game.skillOptions[i]
        local skill = game.skills[skillIndex]

        -- Box background and hover effect
        local mouseX, mouseY = love.mouse.getPosition()
        local isHovered = mouseX >= box.x and mouseX <= box.x + box.width and
            mouseY >= box.y and mouseY <= box.y + box.height

        if isHovered then
            love.graphics.setColor(0.4, 0.4, 0.6)
        else
            love.graphics.setColor(0.3, 0.3, 0.5)
        end
        love.graphics.rectangle("fill", box.x, box.y, box.width, box.height)

        -- Box borders
        love.graphics.setColor(0.6, 0.6, 0.8)
        love.graphics.rectangle("line", box.x, box.y, box.width, box.height)

        -- Skill name
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(32))
        love.graphics.printf(skill.name, box.x, box.y + box.height * 0.35, box.width, "center")

        -- Skill description (wrapped with font size 13 to avoid overflow)
        love.graphics.setFont(getFont(13))
        love.graphics.printf(skill.description, box.x + 20, box.y + box.height * 0.44, box.width - 40, "center")
    end

    -- Main title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(48))
    love.graphics.printf("Roguelike Survivor", 0, 50, screenWidth, "center")

    -- Footer guidance
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
                -- Skill card styling
                if isHovered then
                    love.graphics.setColor(0.4, 0.4, 0.6)
                else
                    love.graphics.setColor(0.3, 0.3, 0.5)
                end
            else
                -- Trait card styling
                if isHovered then
                    love.graphics.setColor(0.4, 0.6, 0.4)
                else
                    love.graphics.setColor(0.3, 0.5, 0.3)
                end
            end
            love.graphics.rectangle("fill", box.x, box.y, box.width, box.height)

            -- Draw card borders
            if option.type == "skill" then
                love.graphics.setColor(0.6, 0.6, 0.8)
            else
                love.graphics.setColor(0.6, 0.8, 0.6)
            end
            love.graphics.rectangle("line", box.x, box.y, box.width, box.height)

            -- Prepare text rendering
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

                local nextLevel = currentLevel + 1
                local descList = skillLevelDescriptions[option.index]
                if descList and descList[nextLevel] then
                    descText = descList[nextLevel]
                else
                    descText = skill.description
                end
            else
                local upgrade = game.upgrades[option.index]
                nameText = upgrade.name
                
                local currentLevel = game.player.upgradeLevels[option.index] or 0
                local nextLevel = currentLevel + 1
                local descList = upgradeLevelDescriptions[option.index]
                if descList and descList[nextLevel] then
                    descText = descList[nextLevel]
                else
                    descText = upgrade.description
                end
            end

            -- Draw card name
            love.graphics.printf(nameText, box.x, box.y + box.height * 0.32, box.width, "center")

            -- Draw card description (wrapped, font size 13 to prevent box overflow)
            love.graphics.setFont(getFont(13))
            love.graphics.printf(descText, box.x + 20, box.y + box.height * 0.44, box.width - 40, "center")

            -- Draw card footer info
            if option.type == "skill" then
                -- Skills: Render level text
                love.graphics.setColor(0.9, 0.9, 0.9)
                love.graphics.setFont(getFont(16))
                love.graphics.printf(levelText, box.x, box.y + box.height * 0.72, box.width, "center")
            else
                -- Traits: Renders level diamonds or level text if infinite
                local player = game.player
                if player then
                    local upgradeLevel = player.upgradeLevels[option.index] or 0
                    local isInfinite = (option.index == 2 or option.index == 4)

                    if isInfinite then
                        local levelText = "Level: " .. upgradeLevel .. " -> " .. (upgradeLevel + 1)
                        love.graphics.setColor(0.9, 0.9, 0.9)
                        love.graphics.setFont(getFont(16))
                        love.graphics.printf(levelText, box.x, box.y + box.height * 0.72, box.width, "center")
                    else
                        local starSize = 15
                        local starSpacing = 18
                        local totalWidth = 2 * starSpacing + starSize
                        local startX = box.x + (box.width - totalWidth) / 2
                        local starY = box.y + box.height * 0.72

                        for j = 1, 3 do
                            local x = startX + (j - 1) * starSpacing
                            if j <= upgradeLevel then
                                love.graphics.setColor(1.0, 0.8, 0.0) -- Gold
                            else
                                love.graphics.setColor(0.5, 0.5, 0.5) -- Grey
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

-- 스테이지 클리어 또는 게임 승리 화면 렌더링
function HUD.drawStageClear(game)
    -- 반투명 어두운 배경으로 덮기 (인게임 상태가 살짝 비치도록 함)
    love.graphics.setColor(0.04, 0.04, 0.06, 0.85)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    if game.stage == 9 then
        -- VICTORY: SYSTEM RESTORED!
        local goldPulse = 0.8 + 0.2 * math.sin(love.timer.getTime() * 4)
        love.graphics.setColor(1.0, 0.8, 0.2, goldPulse)
        love.graphics.setFont(getFont(44))
        love.graphics.printf("VICTORY: SYSTEM RESTORED!", 0, screenHeight / 3 - 60, screenWidth, "center")

        love.graphics.setColor(0.9, 0.9, 1.0)
        love.graphics.setFont(getFont(20))
        love.graphics.printf("You have defeated the Nebula Seraph and saved the system core!", 0, screenHeight / 3 + 10, screenWidth, "center")
    else
        -- STAGE CLEARED 제목 (그린 네온 느낌)
        love.graphics.setColor(0.2, 0.9, 0.4)
        love.graphics.setFont(getFont(48))
        love.graphics.printf("STAGE " .. (game.stage or 1) .. " CLEARED!", 0, screenHeight / 3 - 50, screenWidth, "center")
    end

    -- 스코어 표시
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(24))
    love.graphics.printf("Score: " .. game.score, 0, screenHeight / 3 + 60, screenWidth, "center")

    -- Next Stage / Back to Main Menu 버튼 그리기 (네온 스타일 및 마우스 호버 효과)
    local mouseX, mouseY = love.mouse.getPosition()

    if game.stage == 9 and not game.endlessMode then
        local centerX = screenWidth / 2
        local btn1Width = 260
        local btn1Height = 60
        local btn1X = centerX - 275
        local btnY = screenHeight / 2 + 50

        local btn2Width = 260
        local btn2Height = 60
        local btn2X = centerX + 15

        local isHovered1 = mouseX >= btn1X and mouseX <= btn1X + btn1Width and
                           mouseY >= btnY and mouseY <= btnY + btn1Height
        local isHovered2 = mouseX >= btn2X and mouseX <= btn2X + btn2Width and
                           mouseY >= btnY and mouseY <= btnY + btn2Height

        -- Button 1: Start Endless Mode
        if isHovered1 then
            love.graphics.setColor(0.12, 0.55, 0.3, 0.95) -- 녹색 호버
        else
            love.graphics.setColor(0.08, 0.4, 0.2, 0.85) -- 녹색 기본
        end
        love.graphics.rectangle("fill", btn1X, btnY, btn1Width, btn1Height, 8, 8)
        love.graphics.setColor(0.4, 1.0, 0.6, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", btn1X, btnY, btn1Width, btn1Height, 8, 8)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(20))
        love.graphics.printf("Start Endless Mode", btn1X, btnY + 18, btn1Width, "center")

        -- Button 2: Back to Main Menu
        if isHovered2 then
            love.graphics.setColor(0.12, 0.3, 0.55, 0.95) -- 파란색 호버
        else
            love.graphics.setColor(0.08, 0.2, 0.4, 0.85) -- 파란색 기본
        end
        love.graphics.rectangle("fill", btn2X, btnY, btn2Width, btn2Height, 8, 8)
        love.graphics.setColor(0.4, 0.75, 1.0, 0.9)
        love.graphics.rectangle("line", btn2X, btnY, btn2Width, btn2Height, 8, 8)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(20))
        love.graphics.printf("Back to Main Menu", btn2X, btnY + 18, btn2Width, "center")
    else
        local btnWidth = 280
        local btnHeight = 60
        local btnX = (screenWidth - btnWidth) / 2
        local btnY = screenHeight / 2 + 50

        local isHovered = mouseX >= btnX and mouseX <= btnX + btnWidth and
                          mouseY >= btnY and mouseY <= btnY + btnHeight

        if game.stage == 9 then
            if isHovered then
                love.graphics.setColor(0.12, 0.3, 0.55, 0.95) -- 파란색 호버
            else
                love.graphics.setColor(0.08, 0.2, 0.4, 0.85) -- 파란색 기본
            end
        else
            if isHovered then
                love.graphics.setColor(0.3, 0.8, 0.5, 0.95) -- 밝은 녹색 호버
            else
                love.graphics.setColor(0.2, 0.6, 0.3, 0.85) -- 녹색 기본
            end
        end
        love.graphics.rectangle("fill", btnX, btnY, btnWidth, btnHeight, 8, 8)

        if game.stage == 9 then
            love.graphics.setColor(0.4, 0.75, 1.0, 0.9)
        else
            love.graphics.setColor(0.6, 1.0, 0.7, 0.9)
        end
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", btnX, btnY, btnWidth, btnHeight, 8, 8)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(22))
        if game.stage == 9 then
            love.graphics.printf("Back to Main Menu", btnX, btnY + 16, btnWidth, "center")
        else
            love.graphics.printf("Next Stage", btnX, btnY + 16, btnWidth, "center")
        end
    end
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
    love.graphics.print("Stage: " .. (game.stage or 1), 10, 90)
    if game.enemies then
        love.graphics.print("Enemies: " .. #game.enemies, 10, 110)
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
    local bosses = {}
    if game.enemies then
        for _, enemy in ipairs(game.enemies) do
            if enemy.type == "boss" then
                table.insert(bosses, enemy)
            end
        end
    end

    if #bosses > 0 then
        local screenWidth = love.graphics.getWidth()
        local barWidth = 450
        local barHeight = 16
        local barX = (screenWidth - barWidth) / 2
        
        for idx, boss in ipairs(bosses) do
            local barY = 40 + (idx - 1) * 50
            
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
            local displayHp = math.max(0, math.ceil(boss.health))
            local displayMaxHp = math.max(1, math.ceil(boss.maxHealth))
            love.graphics.printf(displayHp .. " / " .. displayMaxHp, barX, barY + 1, barWidth, "center")
        end
    end
end

-- ============================================================================
-- Main Menu
-- ============================================================================
function HUD.drawMainMenu(game)
    love.graphics.clear(0.05, 0.05, 0.07) -- Deep space dark color
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mx, my = love.mouse.getPosition()
    
    -- Futuristic title rendering
    local titleGlow = 0.85 + math.sin(love.timer.getTime() * 4) * 0.1
    love.graphics.setFont(getFont(54))
    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.printf("ROGUELIKE SURVIVOR", 4, screenHeight / 2 - 216, screenWidth, "center")
    -- Main neon logo
    love.graphics.setColor(0.3, 0.7, 1.0, titleGlow)
    love.graphics.printf("ROGUELIKE SURVIVOR", 0, screenHeight / 2 - 220, screenWidth, "center")
    
    -- 4 menu navigation buttons
    local buttons = {
        { label = "START GAME", state = "menu" },
        { label = "UPGRADES", state = "meta_upgrade" },
        { label = "OPTIONS", state = "settings" },
        { label = "EXIT GAME", action = "exit" }
    }
    
    local btnW = 320
    local btnH = 50
    local startY = screenHeight / 2 - 80
    local gap = 70
    
    game.mainMenuButtons = {}
    
    for i, btn in ipairs(buttons) do
        local bx = (screenWidth - btnW) / 2
        local by = startY + (i - 1) * gap
        
        table.insert(game.mainMenuButtons, {
            x = bx, y = by, w = btnW, h = btnH,
            state = btn.state, action = btn.action
        })
        
        local isHovered = mx >= bx and mx <= bx + btnW and my >= by and my <= by + btnH
        
        if isHovered then
            love.graphics.setColor(0.12, 0.2, 0.35, 0.95)
        else
            love.graphics.setColor(0.08, 0.1, 0.15, 0.85)
        end
        love.graphics.rectangle("fill", bx, by, btnW, btnH, 6, 6)
        
        if isHovered then
            love.graphics.setLineWidth(2)
            love.graphics.setColor(0.3, 0.8, 1.0, 0.95)
        else
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.2, 0.4, 0.6, 0.7)
        end
        love.graphics.rectangle("line", bx, by, btnW, btnH, 6, 6)
        
        love.graphics.setFont(getFont(18))
        if isHovered then
            love.graphics.setColor(1.0, 1.0, 1.0)
        else
            love.graphics.setColor(0.7, 0.8, 0.9)
        end
        love.graphics.printf(btn.label, bx, by + 14, btnW, "center")
    end
    
    -- Accumulated Persistent Score
    love.graphics.setFont(getFont(16))
    love.graphics.setColor(1.0, 0.75, 0.2, 0.85)
    love.graphics.printf("TOTAL SCORE: " .. (game.totalScore or 0) .. " PTS", 0, screenHeight - 60, screenWidth, "center")
    
    love.graphics.setLineWidth(1)
end

-- ============================================================================
-- Settings View
-- ============================================================================
function HUD.drawSettings(game)
    love.graphics.clear(0.05, 0.05, 0.07)
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mx, my = love.mouse.getPosition()
    
    -- Title
    love.graphics.setFont(getFont(36))
    love.graphics.setColor(0.3, 0.7, 1.0)
    love.graphics.printf("OPTIONS", 0, screenHeight / 2 - 200, screenWidth, "center")
    
    local cboxSize = 24
    local startY = screenHeight / 2 - 80
    local gap = 60
    
    local options = {
        { key = "showStars", label = "Enable Background Star Dust" },
        { key = "muted", label = "Mute Background Sound" }
    }
    
    game.settingsCheckboxes = {}
    
    for i, opt in ipairs(options) do
        local bx = screenWidth / 2 - 220
        local by = startY + (i - 1) * gap
        
        table.insert(game.settingsCheckboxes, {
            x = bx, y = by, w = cboxSize, h = cboxSize, key = opt.key
        })
        
        local isHovered = mx >= bx and mx <= bx + 450 and my >= by and my <= by + cboxSize
        
        if isHovered then
            love.graphics.setColor(0.15, 0.25, 0.4)
        else
            love.graphics.setColor(0.08, 0.1, 0.15)
        end
        love.graphics.rectangle("fill", bx, by, cboxSize, cboxSize, 4, 4)
        
        love.graphics.setColor(0.3, 0.7, 1.0, 0.8)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", bx, by, cboxSize, cboxSize, 4, 4)
        
        if game[opt.key] then
            love.graphics.setColor(0.3, 1.0, 0.5)
            love.graphics.rectangle("fill", bx + 5, by + 5, cboxSize - 10, cboxSize - 10, 2, 2)
        end
        
        love.graphics.setFont(getFont(16))
        love.graphics.setColor(0.85, 0.9, 0.95)
        love.graphics.print(opt.label, bx + 40, by + 2)
    end
    
    -- BACK button
    local btnW = 180
    local btnH = 46
    local btnX = (screenWidth - btnW) / 2
    local btnY = screenHeight / 2 + 120
    
    game.settingsBackBtn = { x = btnX, y = btnY, w = btnW, h = btnH }
    
    local isBackHovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
    
    if isBackHovered then
        love.graphics.setColor(0.12, 0.2, 0.35, 0.95)
    else
        love.graphics.setColor(0.08, 0.1, 0.15, 0.85)
    end
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 6, 6)
    
    if isBackHovered then
        love.graphics.setColor(0.3, 0.8, 1.0, 0.95)
    else
        love.graphics.setColor(0.2, 0.4, 0.6, 0.7)
    end
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 6, 6)
    
    love.graphics.setFont(getFont(16))
    love.graphics.setColor(1.0, 1.0, 1.0)
    love.graphics.printf("BACK", btnX, btnY + 12, btnW, "center")
    
    love.graphics.setLineWidth(1)
end

-- ============================================================================
-- Meta Upgrades (2-Column Grid Layout Shop)
-- ============================================================================
function HUD.drawMetaUpgrade(game)
    love.graphics.clear(0.05, 0.05, 0.07)
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mx, my = love.mouse.getPosition()
    local page = game.metaUpgradePage or 1
    
    -- Title
    love.graphics.setFont(getFont(32))
    love.graphics.setColor(0.3, 0.7, 1.0)
    love.graphics.printf("META UPGRADES", 0, 35, screenWidth, "center")
    
    -- Available score PTS
    love.graphics.setFont(getFont(18))
    love.graphics.setColor(1.0, 0.75, 0.2)
    love.graphics.printf("AVAILABLE SCORE: " .. (game.totalScore or 0) .. " PTS", 0, 85, screenWidth, "center")
    
    -- Tabs Navigation
    local tabW = 200
    local tabH = 36
    local tabY = 120
    local centerX = screenWidth / 2
    
    game.metaUpgradeTabs = {
        { x = centerX - tabW - 10, y = tabY, w = tabW, h = tabH, page = 1, label = "ACTIVE SKILLS" },
        { x = centerX + 10, y = tabY, w = tabW, h = tabH, page = 2, label = "PASSIVE STATS" }
    }
    
    for _, tab in ipairs(game.metaUpgradeTabs) do
        local isHovered = mx >= tab.x and mx <= tab.x + tab.w and my >= tab.y and my <= tab.y + tab.h
        local isActive = (page == tab.page)
        
        -- Tab background
        if isActive then
            love.graphics.setColor(0.12, 0.22, 0.4, 0.95)
        elseif isHovered then
            love.graphics.setColor(0.08, 0.14, 0.25, 0.8)
        else
            love.graphics.setColor(0.05, 0.07, 0.1, 0.6)
        end
        love.graphics.rectangle("fill", tab.x, tab.y, tab.w, tab.h, 6, 6)
        
        -- Tab border
        if isActive then
            love.graphics.setLineWidth(2)
            love.graphics.setColor(0.3, 0.8, 1.0, 0.95)
        else
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.2, 0.4, 0.6, 0.7)
        end
        love.graphics.rectangle("line", tab.x, tab.y, tab.w, tab.h, 6, 6)
        
        -- Tab label
        love.graphics.setFont(getFont(15))
        if isActive then
            love.graphics.setColor(1.0, 1.0, 1.0)
        else
            love.graphics.setColor(0.6, 0.7, 0.8)
        end
        love.graphics.printf(tab.label, tab.x, tab.y + 9, tab.w, "center")
    end
    
    -- Upgradable items lists
    local activeUpgrades = {
        { index = 1, name = "Orbiting Orb",    baseCost = 1000, scale = 500, max = 5, desc = "Orbits damage aura around you." },
        { index = 2, name = "Thunder",         baseCost = 1000, scale = 500, max = 5, desc = "Strikes lightning periodically." },
        { index = 3, name = "Blade",           baseCost = 1000, scale = 500, max = 5, desc = "Fires homing curved glaives." },
        { index = 4, name = "Bullet",          baseCost = 1000, scale = 500, max = 5, desc = "Rapid direct projectile shot." },
        { index = 5, name = "Laser",           baseCost = 1200, scale = 600, max = 5, desc = "Continuous heavy plasma beam." },
        { index = 6, name = "Magnetic Field",  baseCost = 1200, scale = 600, max = 5, desc = "Spawns circular electric field." },
        { index = 7, name = "Meteor",          baseCost = 1500, scale = 700, max = 5, desc = "Calls screen-shake fireballs." },
        { index = 8, name = "Cutter",          baseCost = 1200, scale = 600, max = 5, desc = "Rotates sharp energy blades." },
        { index = 9, name = "Chain",           baseCost = 1200, scale = 600, max = 5, desc = "Locks enemies in place with chains." },
        { index = 10, name = "Seeker Orb",     baseCost = 1200, scale = 600, max = 5, desc = "Spawns floating orbs that home in on enemies." }
    }
    
    local passiveUpgrades = {
        { index = 1, name = "Gravity Core",    baseCost = 800,  scale = 400, max = 3, desc = "Pull experience from far." },
        { index = 2, name = "Fortified Hull",  baseCost = 1000, scale = 500, max = 999, desc = "Permanent starting HP +20." },
        { index = 3, name = "Thruster Output",  baseCost = 1000, scale = 500, max = 3, desc = "Permanent speed boost +5%." },
        { index = 4, name = "Reactor Overload",baseCost = 1200, scale = 600, max = 999, desc = "Permanent weapon damage +10%." },
        { index = 5, name = "Health Regen",    baseCost = 1000, scale = 500, max = 3, desc = "Permanent starting regen +5%." },
        { index = 6, name = "EXP Collector",   baseCost = 1200, scale = 600, max = 3, desc = "Permanent EXP collection +25%." },
        { index = 8, name = "Energy Shield",   baseCost = 1500, scale = 700, max = 3, desc = "Block 1 hit unconditionally every 12/9/6s." }
    }
    
    local itemsToShow = {}
    local itemType = ""
    if page == 1 then
        itemsToShow = activeUpgrades
        itemType = "skill"
    else
        itemsToShow = passiveUpgrades
        itemType = "upgrade"
    end
    
    local colCount = 4
    local colWidth = 270
    local colSpacing = 16
    local itemH = 74
    local startY = 180
    local gapY = 84
    
    game.upgradeStoreButtons = {}
    
    for i, up in ipairs(itemsToShow) do
        local lv = 0
        if itemType == "skill" then
            lv = game.metaUpgrades.skills[up.index] or 0
        else
            lv = game.metaUpgrades.upgrades[up.index] or 0
        end
        
        local cost = up.baseCost + lv * up.scale
        local isMax = lv >= up.max
        
        local row = math.ceil(i / colCount)
        local col = (i - 1) % colCount + 1
        
        local totalW = colCount * colWidth + (colCount - 1) * colSpacing
        local rx = (screenWidth - totalW) / 2 + (col - 1) * (colWidth + colSpacing)
        local ry = startY + (row - 1) * gapY
        
        -- Item Box Body
        love.graphics.setColor(0.07, 0.08, 0.12, 0.95)
        love.graphics.rectangle("fill", rx, ry, colWidth, itemH, 6, 6)
        
        -- Border
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.2, 0.35, 0.5, 0.6)
        love.graphics.rectangle("line", rx, ry, colWidth, itemH, 6, 6)
        
        -- Title (Name)
        love.graphics.setFont(getFont(15))
        love.graphics.setColor(0.9, 0.95, 1.0)
        love.graphics.print(up.name, rx + 12, ry + 8)
        
        -- Level Info (Lv. X/Y) - 우측 상단으로 이동배치하여 BUY 버튼 및 긴 텍스트와 겹침 방지
        love.graphics.setFont(getFont(11))
        love.graphics.setColor(0.3, 0.8, 1.0)
        if up.max >= 999 then
            love.graphics.printf("Lv. " .. lv, rx, ry + 12, colWidth - 100, "right")
        else
            love.graphics.printf("Lv. " .. lv .. "/" .. up.max, rx, ry + 12, colWidth - 100, "right")
        end
        
        -- BUY Button dimensions & coordinates
        local btnW = 80
        local btnH = 34
        local btnX = rx + colWidth - btnW - 12
        local btnY = ry + (itemH - btnH) / 2
        
        -- Get level-specific description dynamically
        local displayDesc = up.desc
        local nextLevel = lv + 1
        if isMax then
            nextLevel = lv
        end
        
        if itemType == "skill" then
            local descList = skillLevelDescriptions[up.index]
            if descList and descList[nextLevel] then
                displayDesc = descList[nextLevel]
            end
        else
            local descList = upgradeLevelDescriptions[up.index]
            if descList and descList[nextLevel] then
                displayDesc = descList[nextLevel]
            end
        end

        -- Description (2-line layout, wrapped to avoid overlap with BUY button)
        love.graphics.setColor(0.65, 0.7, 0.75)
        love.graphics.setFont(getFont(11))
        local maxDescWidth = btnX - rx - 24
        love.graphics.printf(displayDesc, rx + 12, ry + 32, maxDescWidth, "left")
        
        table.insert(game.upgradeStoreButtons, {
            x = btnX, y = btnY, w = btnW, h = btnH, type = itemType, index = up.index, cost = cost, max = up.max, lv = lv
        })
        
        local isHovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
        local canAfford = (game.totalScore or 0) >= cost
        
        if isMax then
            love.graphics.setColor(0.15, 0.15, 0.15, 0.8)
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 4, 4)
            love.graphics.setColor(0.4, 0.4, 0.4)
            love.graphics.printf("MAXED", btnX, btnY + 10, btnW, "center")
        elseif not canAfford then
            love.graphics.setColor(0.12, 0.12, 0.14, 0.8)
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 4, 4)
            love.graphics.setColor(0.55, 0.35, 0.35)
            love.graphics.printf(cost .. "P", btnX, btnY + 10, btnW, "center")
        else
            if isHovered then
                love.graphics.setColor(0.1, 0.35, 0.2)
            else
                love.graphics.setColor(0.08, 0.25, 0.15)
            end
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 4, 4)
            
            if isHovered then
                love.graphics.setColor(0.3, 1.0, 0.5)
            else
                love.graphics.setColor(0.2, 0.8, 0.4)
            end
            love.graphics.setLineWidth(1.2)
            love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 4, 4)
            
            love.graphics.setColor(1.0, 1.0, 1.0)
            love.graphics.printf("BUY " .. cost, btnX, btnY + 10, btnW, "center")
        end
    end
    
    -- BACK and RESET ALL buttons (side by side, centered)
    local btnW = 180
    local btnH = 46
    local gap = 20
    local backX = centerX - btnW - gap / 2
    local resetX = centerX + gap / 2
    local btnY = screenHeight - 65
    
    game.upgradeBackBtn = { x = backX, y = btnY, w = btnW, h = btnH }
    game.upgradeResetBtn = { x = resetX, y = btnY, w = btnW, h = btnH }
    
    -- Draw BACK button
    local isBackHovered = mx >= backX and mx <= backX + btnW and my >= btnY and my <= btnY + btnH
    if isBackHovered then
        love.graphics.setColor(0.12, 0.2, 0.35, 0.95)
    else
        love.graphics.setColor(0.08, 0.1, 0.15, 0.85)
    end
    love.graphics.rectangle("fill", backX, btnY, btnW, btnH, 6, 6)
    
    if isBackHovered then
        love.graphics.setColor(0.3, 0.8, 1.0, 0.95)
    else
        love.graphics.setColor(0.2, 0.4, 0.6, 0.7)
    end
    love.graphics.rectangle("line", backX, btnY, btnW, btnH, 6, 6)
    
    love.graphics.setFont(getFont(16))
    love.graphics.setColor(1.0, 1.0, 1.0)
    love.graphics.printf("BACK", backX, btnY + 12, btnW, "center")
    
    -- Draw RESET ALL button
    local isResetHovered = mx >= resetX and mx <= resetX + btnW and my >= btnY and my <= btnY + btnH
    if isResetHovered then
        love.graphics.setColor(0.35, 0.12, 0.12, 0.95)
    else
        love.graphics.setColor(0.15, 0.08, 0.08, 0.85)
    end
    love.graphics.rectangle("fill", resetX, btnY, btnW, btnH, 6, 6)
    
    if isResetHovered then
        love.graphics.setColor(1.0, 0.3, 0.3, 0.95)
    else
        love.graphics.setColor(0.6, 0.2, 0.2, 0.7)
    end
    love.graphics.rectangle("line", resetX, btnY, btnW, btnH, 6, 6)
    
    love.graphics.setFont(getFont(16))
    if isResetHovered then
        love.graphics.setColor(1.0, 1.0, 1.0)
    else
        love.graphics.setColor(0.9, 0.7, 0.7)
    end
    love.graphics.printf("RESET ALL", resetX, btnY + 12, btnW, "center")
    
    love.graphics.setLineWidth(1)
end

function HUD.resetMetaUpgrades(game)
    local activeUpgrades = {
        { index = 1, name = "Orbiting Orb",    baseCost = 1000, scale = 500, max = 5, desc = "Orbits damage aura around you." },
        { index = 2, name = "Thunder",         baseCost = 1000, scale = 500, max = 5, desc = "Strikes lightning periodically." },
        { index = 3, name = "Blade",           baseCost = 1000, scale = 500, max = 5, desc = "Fires homing curved glaives." },
        { index = 4, name = "Bullet",          baseCost = 1000, scale = 500, max = 5, desc = "Rapid direct projectile shot." },
        { index = 5, name = "Laser",           baseCost = 1200, scale = 600, max = 5, desc = "Continuous heavy plasma beam." },
        { index = 6, name = "Magnetic Field",  baseCost = 1200, scale = 600, max = 5, desc = "Spawns circular electric field." },
        { index = 7, name = "Meteor",          baseCost = 1500, scale = 700, max = 5, desc = "Calls screen-shake fireballs." },
        { index = 8, name = "Cutter",          baseCost = 1200, scale = 600, max = 5, desc = "Rotates sharp energy blades." },
        { index = 9, name = "Chain",           baseCost = 1200, scale = 600, max = 5, desc = "Locks enemies in place with chains." },
        { index = 10, name = "Seeker Orb",     baseCost = 1200, scale = 600, max = 5, desc = "Spawns floating orbs that home in on enemies." }
    }
    
    local passiveUpgrades = {
        { index = 1, name = "Gravity Core",    baseCost = 800,  scale = 400, max = 3, desc = "Attract experience from far." },
        { index = 2, name = "Fortified Hull",  baseCost = 1000, scale = 500, max = 999, desc = "Permanent starting HP +20." },
        { index = 3, name = "Thruster Output",  baseCost = 1000, scale = 500, max = 3, desc = "Permanent speed boost +5%." },
        { index = 4, name = "Reactor Overload",baseCost = 1200, scale = 600, max = 999, desc = "Permanent weapon damage +10%." },
        { index = 5, name = "Health Regen",    baseCost = 1000, scale = 500, max = 3, desc = "Permanent starting regen +5%." },
        { index = 6, name = "EXP Collector",   baseCost = 1200, scale = 600, max = 3, desc = "Permanent EXP collection +25%." },
        { index = 8, name = "Energy Shield",   baseCost = 1500, scale = 700, max = 3, desc = "Block 1 hit unconditionally every 12/9/6s." }
    }

    local refundPoints = 0

    -- Calculate active skills refund
    for _, up in ipairs(activeUpgrades) do
        local lv = game.metaUpgrades.skills[up.index] or 0
        if lv > 0 then
            for currentLv = 0, lv - 1 do
                refundPoints = refundPoints + (up.baseCost + currentLv * up.scale)
            end
            game.metaUpgrades.skills[up.index] = 0
        end
    end

    -- Calculate passive upgrades refund
    for _, up in ipairs(passiveUpgrades) do
        local lv = game.metaUpgrades.upgrades[up.index] or 0
        if lv > 0 then
            for currentLv = 0, lv - 1 do
                refundPoints = refundPoints + (up.baseCost + currentLv * up.scale)
            end
            game.metaUpgrades.upgrades[up.index] = 0
        end
    end

    game.totalScore = (game.totalScore or 0) + refundPoints
    game.saveGame()
end

-- ============================================================================
-- Pause Menu Screen (Premium Glassmorphism Overlay)
-- ============================================================================
function HUD.drawPause(game)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mx, my = love.mouse.getPosition()
    
    -- 1. Dark semi-transparent background overlay
    love.graphics.setColor(0.02, 0.02, 0.03, 0.65)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- 2. Glassmorphism popup container (340px width, 420px height)
    local w, h = 340, 420
    local px = (screenWidth - w) / 2
    local py = (screenHeight - h) / 2
    
    -- Soft neon glow shadow layer behind popup
    love.graphics.setColor(0.1, 0.4, 0.8, 0.12)
    love.graphics.rectangle("fill", px - 6, py - 6, w + 12, h + 12, 16, 16)
    
    -- Main container panel body
    love.graphics.setColor(0.06, 0.08, 0.12, 0.92)
    love.graphics.rectangle("fill", px, py, w, h, 12, 12)
    
    -- Container neon border
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.2, 0.45, 0.75, 0.65)
    love.graphics.rectangle("line", px, py, w, h, 12, 12)
    
    -- 3. Title: "GAME PAUSED" with pulsing aura
    love.graphics.setFont(getFont(28))
    local titleGlow = 0.8 + math.sin(love.timer.getTime() * 3) * 0.15
    
    -- Drop shadow for readability
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.printf("GAME PAUSED", px + 2, py + 37, w, "center")
    
    -- Main cyan glowing title
    love.graphics.setColor(0.3, 0.75, 1.0, titleGlow)
    love.graphics.printf("GAME PAUSED", px, py + 35, w, "center")
    
    -- Elegant separator line
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.2, 0.35, 0.5, 0.4)
    love.graphics.line(px + 40, py + 85, px + w - 40, py + 85)
    
    -- 4. Four Menu Buttons (Resume, Options, Title Menu, Exit Game)
    local buttons = {
        { label = "RESUME", action = "resume" },
        { label = "OPTIONS", action = "settings" },
        { label = "TITLE MENU", action = "title" },
        { label = "EXIT GAME", action = "exit" }
    }
    
    local btnW = 260
    local btnH = 50
    local startY = py + 110
    local gap = 68
    
    game.pauseButtons = {}
    
    for i, btn in ipairs(buttons) do
        local bx = px + (w - btnW) / 2
        local by = startY + (i - 1) * gap
        
        -- Store coordinates for collision check in love.mousepressed
        table.insert(game.pauseButtons, {
            x = bx, y = by, w = btnW, h = btnH, action = btn.action
        })
        
        local isHovered = mx >= bx and mx <= bx + btnW and my >= by and my <= by + btnH
        
        -- Micro-animation: Hover scale and coordinate adjustments
        local scale = isHovered and 1.03 or 1.0
        local drawW = btnW * scale
        local drawH = btnH * scale
        local drawX = bx - (drawW - btnW) / 2
        local drawY = by - (drawH - btnH) / 2
        
        -- Draw button background & outline
        if isHovered then
            -- Cyan-blue hover glow background
            love.graphics.setColor(0.12, 0.22, 0.4, 0.95)
            love.graphics.rectangle("fill", drawX, drawY, drawW, drawH, 6, 6)
            
            -- Pulsing border
            local borderPulse = 0.8 + math.sin(love.timer.getTime() * 8) * 0.2
            love.graphics.setLineWidth(2)
            love.graphics.setColor(0.3, 0.8, 1.0, borderPulse)
            love.graphics.rectangle("line", drawX, drawY, drawW, drawH, 6, 6)
        else
            -- Semi-transparent default background
            love.graphics.setColor(0.08, 0.1, 0.15, 0.8)
            love.graphics.rectangle("fill", drawX, drawY, drawW, drawH, 6, 6)
            
            -- Normal border
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.2, 0.35, 0.5, 0.6)
            love.graphics.rectangle("line", drawX, drawY, drawW, drawH, 6, 6)
        end
        
        -- Text rendering (main label)
        love.graphics.setFont(getFont(15))
        if isHovered then
            love.graphics.setColor(1.0, 1.0, 1.0)
        else
            love.graphics.setColor(0.8, 0.85, 0.95)
        end
        
        -- Draw text centered within the button
        local displayText = btn.label
        love.graphics.printf(displayText, drawX, drawY + 16, drawW, "center")
    end
    
    love.graphics.setLineWidth(1)
end

-- ============================================================================
-- Help & Cheat Codes Overlay (F1 Window)
-- ============================================================================
function HUD.drawHelp(game)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mx, my = love.mouse.getPosition()
    
    -- 1. Dark semi-transparent background overlay
    love.graphics.setColor(0.02, 0.02, 0.03, 0.75)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- 2. Glassmorphism popup container (560px width, 480px height)
    local w, h = 560, 480
    local px = (screenWidth - w) / 2
    local py = (screenHeight - h) / 2
    
    -- Soft neon glow shadow layer behind popup
    love.graphics.setColor(0.1, 0.5, 0.9, 0.15)
    love.graphics.rectangle("fill", px - 6, py - 6, w + 12, h + 12, 16, 16)
    
    -- Main container panel body
    love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", px, py, w, h, 12, 12)
    
    -- Container neon border
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.2, 0.5, 0.85, 0.8)
    love.graphics.rectangle("line", px, py, w, h, 12, 12)
    
    -- 3. Title: "GAME INFO & CHEATS" with pulsing aura
    love.graphics.setFont(getFont(26))
    local titleGlow = 0.85 + math.sin(love.timer.getTime() * 4) * 0.15
    
    -- Drop shadow for readability
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.printf("HELP AND CHEAT CODES", px + 2, py + 32, w, "center")
    
    -- Main cyan glowing title
    love.graphics.setColor(0.3, 0.8, 1.0, titleGlow)
    love.graphics.printf("HELP AND CHEAT CODES", px, py + 30, w, "center")
    
    -- Elegant separator line
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.2, 0.35, 0.5, 0.4)
    love.graphics.line(px + 40, py + 75, px + w - 40, py + 75)
    
    -- 4. Left Column: CONTROLS
    local colW = 220
    local lx = px + 40
    local ly = py + 95
    
    love.graphics.setFont(getFont(18))
    love.graphics.setColor(0.3, 1.0, 0.5) -- Neon Green
    love.graphics.print("CONTROLS", lx, ly)
    
    love.graphics.setFont(getFont(13))
    love.graphics.setColor(0.85, 0.9, 0.95)
    local controls = {
        { key = "W, A, S, D", desc = "Move character" },
        { key = "Arrow Keys", desc = "Move character" },
        { key = "ESC Key", desc = "Pause / Go Back" },
        { key = "F1 Key", desc = "Toggle Help Overlay" },
        { key = "Auto Attack", desc = "All weapons fire automatically at regular intervals." }
    }
    
    local textY = ly + 30
    for _, ctrl in ipairs(controls) do
        love.graphics.setColor(0.4, 0.75, 1.0) -- Key color (cyan)
        love.graphics.print(ctrl.key, lx, textY)
        love.graphics.setColor(0.8, 0.85, 0.9) -- Desc color
        
        if ctrl.key == "Auto Attack" then
            love.graphics.printf(ctrl.desc, lx, textY + 18, colW, "left")
            textY = textY + 50
        else
            love.graphics.print(" : " .. ctrl.desc, lx + 105, textY)
            textY = textY + 22
        end
    end
    
    -- 5. Right Column: CHEAT CODES
    local rx = px + w - colW - 40
    local ry = py + 95
    
    love.graphics.setFont(getFont(18))
    love.graphics.setColor(1.0, 0.4, 0.4) -- Neon Red
    love.graphics.print("CHEAT CODES", rx, ry)
    
    love.graphics.setFont(getFont(13))
    love.graphics.setColor(0.85, 0.9, 0.95)
    local cheats = {
        { key = "O Key", desc = "Instant Level Up (grants EXP)" },
        { key = "K Key", desc = "Force Skip to Next Stage" },
        { key = "I Key", desc = "Spawn Boss Wave (Wave 7 / Next 5th Wave)" },
        { key = "P Key", desc = "Clear All Enemies & Bullets" }
    }
    
    textY = ry + 30
    for _, cheat in ipairs(cheats) do
        love.graphics.setColor(1.0, 0.75, 0.2) -- Cheat key color (golden)
        love.graphics.print(cheat.key, rx, textY)
        love.graphics.setColor(0.8, 0.85, 0.9) -- Desc color
        love.graphics.printf(cheat.desc, rx, textY + 18, colW, "left")
        textY = textY + 52
    end
    
    -- Elegant separator line before Close Button
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.2, 0.35, 0.5, 0.4)
    love.graphics.line(px + 40, py + h - 75, px + w - 40, py + h - 75)
    
    -- 6. CLOSE Button
    local btnW = 180
    local btnH = 40
    local btnX = px + (w - btnW) / 2
    local btnY = py + h - 55
    
    game.helpCloseBtn = { x = btnX, y = btnY, w = btnW, h = btnH }
    
    local isHovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
    
    -- Scale micro-animation on hover
    local scale = isHovered and 1.03 or 1.0
    local drawW = btnW * scale
    local drawH = btnH * scale
    local drawX = btnX - (drawW - btnW) / 2
    local drawY = btnY - (drawH - btnH) / 2
    
    if isHovered then
        love.graphics.setColor(0.12, 0.22, 0.4, 0.95)
        love.graphics.rectangle("fill", drawX, drawY, drawW, drawH, 6, 6)
        
        local borderPulse = 0.8 + math.sin(love.timer.getTime() * 8) * 0.2
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.3, 0.8, 1.0, borderPulse)
        love.graphics.rectangle("line", drawX, drawY, drawW, drawH, 6, 6)
    else
        love.graphics.setColor(0.08, 0.1, 0.15, 0.8)
        love.graphics.rectangle("fill", drawX, drawY, drawW, drawH, 6, 6)
        
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.2, 0.35, 0.5, 0.6)
        love.graphics.rectangle("line", drawX, drawY, drawW, drawH, 6, 6)
    end
    
    love.graphics.setFont(getFont(14))
    if isHovered then
        love.graphics.setColor(1.0, 1.0, 1.0)
    else
        love.graphics.setColor(0.8, 0.85, 0.95)
    end
    love.graphics.printf("CLOSE", drawX, drawY + 11, drawW, "center")
    
    love.graphics.setLineWidth(1)
end

return HUD

