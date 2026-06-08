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
    state = "menu", -- menu, playing, upgrade, gameover, skill_upgrade
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
        { name = "Magnetic Field", description = "Periodically deploy a circular magnetic field that damages nearby enemies" }
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
        { name = "EXP Boost",    description = "Increase experience gained by 25%" }
    },
    upgradeOptions = {}, -- 현재 레벨업 시 표시할 특성 3개 (인덱스)
    upgradeBoxes = {},
    thunders = {},       -- 벼락 스킬 프로젝타일
    blades = {},         -- 칼날 스킬 프로젝타일
    bullets = {},        -- 총알 스킬 프로젝타일
    lasers = {},         -- 레이저 스킬 프로젝타일
    skillUpgradeBox = {} -- 스킬 업그레이드 박스
}

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

    -- 게임 초기화
    game.state = "menu"
    game.selectedSkill = nil
    HUD.calculateSkillBoxes(game)
    HUD.shuffleSkills(game)
    print("Game loaded successfully")
end

-- 게임 시작 함수
local function startGame(skillIndex)
    -- 플레이어 초기화
    game.player = Player.init(skillIndex)

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
    game.enemyBullets = {} -- 적 탄환 프로젝타일
    game.score = 0
    game.time = 0

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

    -- 웨이브 시스템 초기화
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

    -- 첫 스킬 적용 및 오비팅 오브 생성
    if skillIndex == 1 then
        Skills.syncOrbs(game)
    end

    game.state = "playing"
    game.running = true
end

-- ============================================================================
-- 업데이트 (상태 변경)
-- ============================================================================

function love.update(dt)
    if game.state == "menu" or game.state == "upgrade" or not game.running then
        return
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
    if game.state == "menu" then
        HUD.drawMenu(game)
        return
    elseif game.state == "upgrade" then
        HUD.drawUpgrade(game)
        return
    elseif game.state == "gameover" then
        HUD.drawGameOver(game)
        return
    end

    -- 배경 지우기
    love.graphics.clear(0.06, 0.06, 0.08) -- Deep dark blue-grey background

    -- 카메라 적용
    love.graphics.push()
    love.graphics.translate(-game.camera.x, -game.camera.y)

    -- 1. 대형 네뷸라 광원 그리기 (카메라 좌표계 안에서 잔잔한 고유 웅장함 부여)
    if game.nebulas then
        for _, neb in ipairs(game.nebulas) do
            love.graphics.setColor(neb.r, neb.g, neb.b, neb.alpha)
            love.graphics.circle("fill", neb.x, neb.y, neb.radius)
        end
    end

    -- 2. 바닥 격자 무늬(Grid Floor) 그리기
    love.graphics.setColor(0.12, 0.14, 0.2, 0.35) -- Faint tech grid lines
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
                -- 푸른 별빛 먼지
                love.graphics.setColor(0.4, 0.6, 1.0, elem.alpha)
                love.graphics.circle("fill", elem.x, elem.y, elem.size)
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

    -- 플레이어 그리기
    Player.draw(game)

    -- 플레이어 UI 그리기 (체력바, 경험치바)
    Player.drawUI(game)

    -- 스킬 그리기
    Skills.draw(game)

    -- 적 그리기
    Enemy.draw(game)

    -- 경험치 구슬 그리기
    Exp.draw(game)

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

    if game.state == "playing" and (key == "o" or key == "O") then
        local player = game.player
        if player then
            player.experience = player.maxExperience
            local Exp = require("progression.exp")
            Exp.checkLevelUp(game)
        end
    end

    if game.state == "gameover" then
        if key == "r" or key == "R" then
            game.state = "menu"
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and game.state == "menu" then
        for i, box in ipairs(game.skillBoxes) do
            if x >= box.x and x <= box.x + box.width and
                y >= box.y and y <= box.y + box.height then
                local skillIndex = game.skillOptions[i]
                startGame(skillIndex)
                break
            end
        end
    elseif button == 1 and game.state == "upgrade" then
        for i, box in ipairs(game.upgradeBoxes) do
            if x >= box.x and x <= box.x + box.width and
                y >= box.y and y <= box.y + box.height then
                Skills.applyUpgrade(game, i)
                break
            end
        end
    end
end
