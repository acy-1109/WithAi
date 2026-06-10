-- ============================================================================
-- main.lua — Roguelike Survivor 메인 게임 루프 및 모듈 통합
-- ============================================================================
--
-- ◆ 역할
--   LÖVE의 load, update, draw, event 콜백을 정의하여 게임 루프를 구현한다.
--   각종 시스템 로직(플레이어, 카메라, 적, 스킬, UI)을 서브 모듈로 위임한다.
--

-- 모듈 로드
local Player = require("game.player")
local Camera = require("game.camera")
local Enemy = require("enemy.spawner")
local Skills = require("progression.skills")
local Exp = require("progression.exp")
local HUD = require("ui.hud")

-- 게임 상태 관리 테이블
local game = {
    running = false,
    state = "main_menu", -- main_menu, settings, meta_upgrade, menu, playing, upgrade, gameover, stage_clear
    stage = 1,
    player = nil,
    enemies = {},
    projectiles = {},
    orbs = {}, -- 플레이어 주위 회전 구체
    score = 0,
    time = 0,
    camera = {
        x = 0,
        y = 0
    },
    world = {
        width = 2000,
        height = 2000
    },
    skills = {
        { name = "Orbiting Orb", description = "Orb orbits player and damages enemies" },
        { name = "Thunder",      description = "Strike lightning on enemies periodically" },
        { name = "Blade",        description = "Auto-attack enemies with tracking blades" },
        { name = "Bullet",       description = "Auto-target enemies and fire bullets" },
        { name = "Laser",        description = "Fire a slow-charging laser beam that follows your position" },
        { name = "Magnetic Field", description = "Periodically deploy a circular magnetic field that damages nearby enemies" },
        { name = "Meteor",       description = "Call down devastating meteors from the sky that shake the screen and leave fire patches" },
        { name = "Cutter",       description = "Energy cutter blades extending from your body that rotate and slice through enemies" },
        { name = "Chain",        description = "Fires glowing chains that lock enemies in place and deal damage" }
    },
    selectedSkill = nil,
    skillBoxes = {},
    skillOptions = {}, -- 선택창에 표시할 3개 스킬 인덱스
    upgrades = {
        { name = "Magnet",       description = "Attract experience orbs from nearby" },
        { name = "Health Boost", description = "Increase max health by 20" },
        { name = "Speed Boost",  description = "Increase movement speed by 5%" },
        { name = "Damage Boost", description = "Increase orb damage by 10%" },
        { name = "Health Regen", description = "Regenerate health when not taking damage" },
        { name = "EXP Boost",    description = "Increase experience gained by 25%" },
        { name = "Thorns",       description = "30% chance per level to retaliate and damage nearby enemies when hit" }
    },
    upgradeOptions = {}, -- 현재 레벨업 시 표시할 특성 3개 (인덱스)
    upgradeBoxes = {},
    thunders = {},       -- 벼락 스킬 프로젝타일
    blades = {},         -- 칼날 스킬 프로젝타일
    bullets = {},        -- 총알 스킬 프로젝타일
    lasers = {},         -- 레이저 스킬 프로젝타일
    skillUpgradeBox = {}, -- 스킬 업그레이드 박스
    
    -- 영구 강화 및 설정 데이터
    totalScore = 0,
    metaUpgrades = {
        skills = { 0, 0, 0, 0, 0, 0, 0, 0, 0 },  -- 9 active skills starting level offsets
        upgrades = { 0, 0, 0, 0, 0, 0, 0 }     -- 7 passive traits starting level offsets
    },
    showStars = true, -- 설정: 성간 배경 먼지 그리기 여부
    muted = false     -- 설정: 음소거 여부 (필요 시 효과음 제어용)
}

-- 세이브 파일 저장 기능
game.saveGame = function()
    local totalScoreVal = game.totalScore or 0
    local dataStr = string.format("totalScore:%d\nshowStars:%s\nmuted:%s\n",
        totalScoreVal, tostring(game.showStars), tostring(game.muted))
    
    for i = 1, 9 do
        dataStr = dataStr .. string.format("skill_%d:%d\n", i, game.metaUpgrades.skills[i] or 0)
    end
    for i = 1, 6 do
        dataStr = dataStr .. string.format("upgrade_%d:%d\n", i, game.metaUpgrades.upgrades[i] or 0)
    end
    
    love.filesystem.write("save.txt", dataStr)
end

-- 세이브 파일 불러오기 기능
game.loadGame = function()
    game.totalScore = 0
    game.metaUpgrades = {
        skills = { 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        upgrades = { 0, 0, 0, 0, 0, 0, 0 }
    }
    game.showStars = true
    game.muted = false
    
    if love.filesystem.getInfo("save.txt") then
        for line in love.filesystem.lines("save.txt") do
            local k, v = line:match("([^:]+):([^%s]+)")
            if k and v then
                local val = tonumber(v)
                if k == "totalScore" then game.totalScore = val or 0
                elseif k == "showStars" then game.showStars = (v == "true")
                elseif k == "muted" then game.muted = (v == "true")
                elseif k:match("^skill_%d+$") then
                    local idx = tonumber(k:match("skill_(%d+)"))
                    if idx and idx >= 1 and idx <= 9 then
                        game.metaUpgrades.skills[idx] = val or 0
                    end
                elseif k:match("^upgrade_%d+$") then
                    local idx = tonumber(k:match("upgrade_(%d+)"))
                    if idx and idx >= 1 and idx <= 6 then
                        game.metaUpgrades.upgrades[idx] = val or 0
                    end
                end
            end
        end
    end
end

-- 의존성 순환 참조 방지를 위한 콜백 바인딩
game.calculateUpgradeBoxes = function()
    HUD.calculateUpgradeBoxes(game)
end

-- ============================================================================
-- 초기화
-- ============================================================================

function love.load()
    -- 시드 설정 (매 실행마다 다른 랜덤 결과 보장)
    math.randomseed(os.time() + love.timer.getTime())
    for i = 1, 5 do math.random() end -- 난수 생성기 예열

    -- 게임 데이터 및 영구 강화 로드
    game.loadGame()

    -- 1회성 스코어 및 업그레이드 현황 초기화 처리
    if not love.filesystem.getInfo("reset_done.txt") then
        game.totalScore = 0
        game.metaUpgrades = {
            skills = { 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            upgrades = { 0, 0, 0, 0, 0, 0, 0 }
        }
        game.saveGame()
        love.filesystem.write("reset_done.txt", "done")
    end

    game.state = "main_menu"
    game.selectedSkill = nil
    game.metaUpgradePage = 1 -- Default to page 1 (Active Skills)
    
    HUD.calculateSkillBoxes(game)
    HUD.shuffleSkills(game)
    print("Game loaded successfully")
end

-- 게임 시작 함수
local function startGame(skillIndex)
    -- 플레이어 초기화 (영구 강화 능력치 적용)
    game.player = Player.init(skillIndex, game.metaUpgrades)

    -- 첫 카메라 위치 강제 동기화 (적의 화면 밖 스폰 판정을 위함)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    game.camera.x = game.player.x - screenWidth / 2 + game.player.width / 2
    game.camera.y = game.player.y - screenHeight / 2 + game.player.height / 2

    game.enemies = {}
    game.orbs = {}
    game.expOrbs = {}  -- 경험치 구슬
    game.thunders = {} -- 벼락 스킬 프로젝타일
    game.blades = {}   -- 칼날 스킬 프로젝타일
    game.bullets = {}  -- 총알 스킬 프로젝타일
    game.lasers = {}   -- 레이저 스킬 프로젝타일
    game.meteors = {}  -- 운석 스킬 프로젝타일
    game.firePatches = {} -- 운석 불장판
    game.enemyBullets = {} -- 적 탄환 프로젝타일
    game.thornsVisuals = {} -- 가시 이펙트 데칼/비주얼
    game.pendingThornsAttackers = {} -- 피격 시 가시 발동 예약을 위한 리스트
    game.chains = {}   -- 체인 스킬 프로젝타일
    game.chainTimer = 0 -- 체인 발사 타이머
    game.score = 0
    game.time = 0

    -- 카메라 쉐이크 데이터
    game.shakeTimer = 0
    game.shakeIntensity = 0
    game.triggerShake = function(duration, intensity)
        game.shakeTimer = duration
        game.shakeIntensity = intensity
    end

    -- 모든 스킬 타이머 및 쿨다운 초기화
    game.thunderTimer = 0
    game.thunderCooldown = 3.0
    game.bladeTimer = 0
    game.bladeCooldown = 2.0
    game.bulletTimer = 0
    game.bulletCooldown = 1.5
    game.laserTimer = 0
    game.laserCooldown = 5.0
    game.magneticFieldTimer = 0
    game.magneticFieldCooldown = 6.0
    game.activeMagneticField = nil
    game.meteorTimer = 0
    game.meteorCooldown = 8.0

    -- 웨이브 시스템 초기화
    game.stage = 1
    game.wave = 1
    game.waveState = "playing"
    game.waveTransitionTimer = 0
    game.bannerText = "WAVE 1"
    game.bannerTimer = 2.0
    Enemy.spawnWave(game, 1)

    -- 배경 데코레이션 초기화
    game.backgroundElements = {}
    for i = 1, 250 do
        table.insert(game.backgroundElements, {
            x = math.random(0, game.world.width),
            y = math.random(0, game.world.height),
            size = math.random(1, 3),
            alpha = math.random(10, 35) / 100,
            type = math.random(1, 3)
        })
    end

    game.nebulas = {}
    local nebulaColors = {
        {0.1, 0.05, 0.2}, -- Purple
        {0.05, 0.1, 0.2}, -- Blue/Cyan
        {0.15, 0.05, 0.1}, -- Magenta/Pink
        {0.05, 0.15, 0.1}  -- Green
    }
    for i = 1, 6 do
        local col = nebulaColors[math.random(1, #nebulaColors)]
        table.insert(game.nebulas, {
            x = math.random(200, game.world.width - 200),
            y = math.random(200, game.world.height - 200),
            radius = math.random(180, 350),
            r = col[1],
            g = col[2],
            b = col[3],
            alpha = 0.045
        })
    end

    -- 첫 스킬 적용 및 오비팅 오브 생성 (시작 선택 또는 영구 강화에 의해 Orb 보유 시)
    if skillIndex == 1 or (game.player.skillLevels[1] or 0) > 0 then
        Skills.syncOrbs(game)
    end

    game.state = "playing"
    game.running = true
end

-- ============================================================================
-- 업데이트 (상태 변경)
-- ============================================================================

function love.update(dt)
    -- 메인메뉴, 설정, 강화 화면에서는 일반 루프 미가동
    if game.state == "main_menu" or game.state == "settings" or game.state == "meta_upgrade" or
       game.state == "menu" or game.state == "upgrade" or game.state == "stage_clear" or not game.running then
        
        -- 플레이 중이 아니었다가 gameover 상태가 된 순간 스코어 누적 및 세이브 처리
        if game.state == "gameover" and game.score > 0 then
            game.totalScore = game.totalScore + game.score
            game.score = 0 -- 누적 후 리셋하여 중복 합산 방지
            game.saveGame()
        end
        return
    end

    -- 카메라 쉐이크 타이머 업데이트
    if game.shakeTimer and game.shakeTimer > 0 then
        game.shakeTimer = game.shakeTimer - dt
    end

    -- 게임 시간 갱신
    game.time = game.time + dt

    -- 카메라 업데이트 (플레이어 추적)
    Camera.update(game, dt)

    -- 플레이어 업데이트 (이동, 피격 쿨다운, 재생)
    Player.update(game, dt)

    -- 스킬 업데이트 (오브, 벼락, 칼날, 총알)
    Skills.update(game, dt)

    -- 적 업데이트 (스폰, 플레이어 추적, 각종 피격 판정)
    Enemy.update(game, dt)

    -- 경험치 구슬 업데이트 (트래킹, 획득 및 레벨업 체크)
    Exp.update(game, dt)
end

-- ============================================================================
-- 렌더링 (화면 출력)
-- ============================================================================

function love.draw()
    if game.state == "main_menu" then
        HUD.drawMainMenu(game)
        return
    elseif game.state == "settings" then
        HUD.drawSettings(game)
        return
    elseif game.state == "meta_upgrade" then
        HUD.drawMetaUpgrade(game)
        return
    elseif game.state == "menu" then
        HUD.drawMenu(game)
        return
    elseif game.state == "upgrade" then
        HUD.drawUpgrade(game)
        return
    elseif game.state == "stage_clear" then
        HUD.drawStageClear(game)
        return
    elseif game.state == "gameover" then
        HUD.drawGameOver(game)
        return
    end

    -- 배경 지우기
    if game.stage == 1 then
        love.graphics.clear(0.06, 0.06, 0.08) -- Deep dark blue-grey background (Stage 1)
    else
        love.graphics.clear(0.09, 0.04, 0.04) -- Deep dark crimson background (Stage 2+)
    end

    -- 카메라 적용 (쉐이크 효과 포함)
    local shakeX, shakeY = 0, 0
    if game.shakeTimer and game.shakeTimer > 0 then
        shakeX = (math.random() - 0.5) * game.shakeIntensity
        shakeY = (math.random() - 0.5) * game.shakeIntensity
    end
    love.graphics.push()
    love.graphics.translate(-game.camera.x + shakeX, -game.camera.y + shakeY)

    -- 1. 대형 네뷸라 광원 그리기 (카메라 좌표계 안에서 잔잔한 고유 웅장함 부여)
    if game.nebulas then
        for _, neb in ipairs(game.nebulas) do
            if game.stage == 1 then
                love.graphics.setColor(neb.r, neb.g, neb.b, neb.alpha)
            else
                -- Stage 2+ 에서 붉은 틴트 적용
                love.graphics.setColor(neb.r * 1.5 + 0.1, neb.g * 0.5, neb.b * 0.5, neb.alpha * 1.2)
            end
            love.graphics.circle("fill", neb.x, neb.y, neb.radius)
        end
    end

    -- 2. 바닥 격자 무늬(Grid Floor) 그리기
    if game.stage == 1 then
        love.graphics.setColor(0.12, 0.14, 0.2, 0.35) -- Faint tech grid lines (Stage 1)
    else
        love.graphics.setColor(0.24, 0.1, 0.1, 0.4)  -- Warm low-lit red-orange grid lines (Stage 2+)
    end
    love.graphics.setLineWidth(1)
    local gridSize = 80
    for x = 0, game.world.width, gridSize do
        love.graphics.line(x, 0, x, game.world.height)
    end
    for y = 0, game.world.height, gridSize do
        love.graphics.line(0, y, game.world.width, y)
    end

    -- 3. 바닥 상세 데코레이션(성간 먼지, 돌, 미세 전자기 균열) 그리기
    if game.backgroundElements then
        for _, elem in ipairs(game.backgroundElements) do
            if elem.type == 1 then
                -- 푸른 별빛 먼지 (설정에서 켜져 있을 때만 렌더링)
                if game.showStars then
                    love.graphics.setColor(0.4, 0.6, 1.0, elem.alpha)
                    love.graphics.circle("fill", elem.x, elem.y, elem.size)
                end
            elseif elem.type == 2 then
                -- 미세 격자 조각
                love.graphics.setColor(0.3, 0.7, 0.4, elem.alpha * 0.7)
                love.graphics.setLineWidth(1)
                love.graphics.line(elem.x - 2, elem.y, elem.x + 2, elem.y)
                love.graphics.line(elem.x, elem.y - 2, elem.x, elem.y + 2)
            else
                -- 바닥 부스러기/돌
                love.graphics.setColor(0.25, 0.25, 0.3, elem.alpha * 0.9)
                love.graphics.rectangle("fill", elem.x, elem.y, elem.size + 1, elem.size + 1)
            end
        end
    end

    -- 월드 경계 그리기 (빛나는 네온 블루 사각형 테두리)
    love.graphics.setColor(0.2, 0.4, 0.6, 0.6)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", 0, 0, game.world.width, game.world.height)

    -- 스킬 그리기
    Skills.draw(game)

    -- 경험치 구슬 그리기
    Exp.draw(game)

    -- 적 그리기
    Enemy.draw(game)

    -- 플레이어 그리기 (플레이어 레이어가 가장 위에 오도록 나중에 렌더링)
    Player.draw(game)

    -- 플레이어 UI 그리기 (체력바, 경험치바)
    Player.drawUI(game)

    -- 카메라 복원
    love.graphics.pop()

    -- 화면 UI 그리기 (HUD: 점수, 레벨, 시간)
    HUD.drawUI(game)
end

-- ============================================================================
-- 이벤트 핸들러
-- ============================================================================

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end

    if game.state == "playing" and (key == "p" or key == "P") then
        game.enemies = {}
        game.enemyBullets = {}
    end

    -- 치트키 O: 즉시 레벨업 경험치 지급
    if game.state == "playing" and (key == "o" or key == "O") then
        local player = game.player
        if player then
            player.experience = player.maxExperience
            local Exp = require("progression.exp")
            Exp.checkLevelUp(game)
        end
    end

    -- 치트키 K: 즉시 다음 스테이지로 강제 이동 및 1웨이브 시작
    if game.state == "playing" and (key == "k" or key == "K") then
        game.enemies = {}
        game.enemyBullets = {}
        game.stage = (game.stage or 1) + 1
        game.wave = 1
        game.waveState = "playing"
        game.bannerText = "STAGE " .. game.stage .. " START!"
        game.bannerTimer = 3.0
        Enemy.spawnWave(game, 1)
    end

    -- 치트키 I: 즉시 보스 웨이브(7웨이브)로 이동 및 보스 스폰
    if game.state == "playing" and (key == "i" or key == "I") then
        game.enemies = {}
        game.enemyBullets = {}
        game.wave = 7
        game.waveState = "playing"
        Enemy.spawnWave(game, 7)
    end

    -- 게임오버 시 R 누르면 스킬 선택이 아니라 메인메뉴로 이동
    if game.state == "gameover" then
        if key == "r" or key == "R" then
            game.state = "main_menu"
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        if game.state == "main_menu" then
            if game.mainMenuButtons then
                for _, btn in ipairs(game.mainMenuButtons) do
                    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                        if btn.action == "exit" then
                            love.event.quit()
                        else
                            game.state = btn.state
                        end
                        break
                    end
                end
            end
            
        elseif game.state == "settings" then
            -- 체크박스 영역 클릭 처리
            if game.settingsCheckboxes then
                for _, box in ipairs(game.settingsCheckboxes) do
                    if x >= box.x and x <= box.x + 400 and y >= box.y and y <= box.y + box.h then
                        game[box.key] = not game[box.key]
                        game.saveGame()
                        break
                    end
                end
            end
            
            -- 뒤로 가기 버튼 클릭 처리
            local back = game.settingsBackBtn
            if back and x >= back.x and x <= back.x + back.w and y >= back.y and y <= back.y + back.h then
                game.state = "main_menu"
            end
            
        elseif game.state == "meta_upgrade" then
            -- 탭 클릭 처리
            if game.metaUpgradeTabs then
                for _, tab in ipairs(game.metaUpgradeTabs) do
                    if x >= tab.x and x <= tab.x + tab.w and y >= tab.y and y <= tab.y + tab.h then
                        game.metaUpgradePage = tab.page
                        break
                    end
                end
            end

            -- 강화 상점 구매 클릭 처리
            if game.upgradeStoreButtons then
                for _, btn in ipairs(game.upgradeStoreButtons) do
                    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                        if btn.lv < btn.max and game.totalScore >= btn.cost then
                            game.totalScore = game.totalScore - btn.cost
                            if btn.type == "skill" then
                                game.metaUpgrades.skills[btn.index] = btn.lv + 1
                            elseif btn.type == "upgrade" then
                                game.metaUpgrades.upgrades[btn.index] = btn.lv + 1
                            end
                            game.saveGame()
                        end
                        break
                    end
                end
            end
            
            -- 뒤로 가기 버튼 클릭 처리
            local back = game.upgradeBackBtn
            if back and x >= back.x and x <= back.x + back.w and y >= back.y and y <= back.y + back.h then
                game.state = "main_menu"
            end

            -- 리셋 버튼 클릭 처리
            local reset = game.upgradeResetBtn
            if reset and x >= reset.x and x <= reset.x + reset.w and y >= reset.y and y <= reset.y + reset.h then
                HUD.resetMetaUpgrades(game)
            end
            
        elseif game.state == "menu" then
            for i, box in ipairs(game.skillBoxes) do
                if x >= box.x and x <= box.x + box.width and
                    y >= box.y and y <= box.y + box.height then
                    local skillIndex = game.skillOptions[i]
                    startGame(skillIndex)
                    break
                end
            end
            
        elseif game.state == "upgrade" then
            for i, box in ipairs(game.upgradeBoxes) do
                if x >= box.x and x <= box.x + box.width and
                    y >= box.y and y <= box.y + box.height then
                    Skills.applyUpgrade(game, i)
                    break
                end
            end
            
        elseif game.state == "stage_clear" then
            local screenWidth = love.graphics.getWidth()
            local screenHeight = love.graphics.getHeight()
            local btnWidth = 240
            local btnHeight = 60
            local btnX = (screenWidth - btnWidth) / 2
            local btnY = screenHeight / 2 + 50
            
            if x >= btnX and x <= btnX + btnWidth and
               y >= btnY and y <= btnY + btnHeight then
                -- 다음 스테이지 개시 처리
                game.stage = (game.stage or 1) + 1
                game.wave = 1
                game.waveState = "playing"
                game.bannerText = "STAGE " .. game.stage .. " START!"
                game.bannerTimer = 3.0
                game.state = "playing"
                game.running = true
                
                local EnemyModule = require("enemy.spawner")
                EnemyModule.spawnWave(game, 1)
            end
        end
    end
end
