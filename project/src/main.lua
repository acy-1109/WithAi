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
local Sound = require("game.sound")

-- 게임 상태 관리 테이블
local game_data = {
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
        { name = "Orbiting Orb",   description = "Orbiting damage aura" },
        { name = "Thunder",        description = "Strike lightning periodically" },
        { name = "Blade",          description = "Fire homing curved glaives" },
        { name = "Bullet",         description = "Fire rapid projectiles" },
        { name = "Laser",          description = "Fire continuous plasma beam" },
        { name = "Magnetic Field", description = "Deploy circular electric field" },
        { name = "Meteor",         description = "Call down meteors from sky" },
        { name = "Cutter",         description = "Rotate energy blades" },
        { name = "Chain",          description = "Lock enemies with chains" },
        { name = "Seeker Orb",     description = "Spawn homing orbs" }
    },
    selectedSkill = nil,
    skillBoxes = {},
    skillOptions = {}, -- 선택창에 표시할 3개 스킬 인덱스
    upgrades = {
        { name = "Magnet",        description = "Pull experience orbs" },
        { name = "Health Boost",  description = "Increase max health by 10%" },
        { name = "Speed Boost",   description = "Increase movement speed" },
        { name = "Damage Boost",  description = "Increase weapon damage" },
        { name = "Health Regen",  description = "Regenerate health" },
        { name = "EXP Boost",     description = "Increase experience gained" },
        { name = "Thorns",        description = "Retaliate when hit" },
        { name = "Energy Shield", description = "Generate block shield" },
        { name = "Defense Boost", description = "Reduce damage taken" }
    },
    upgradeOptions = {},  -- 현재 레벨업 시 표시할 특성 3개 (인덱스)
    upgradeBoxes = {},
    thunders = {},        -- 벼락 스킬 프로젝타일
    blades = {},          -- 칼날 스킬 프로젝타일
    bullets = {},         -- 총알 스킬 프로젝타일
    lasers = {},          -- 레이저 스킬 프로젝타일
    skillUpgradeBox = {}, -- 스킬 업그레이드 박스

    -- 영구 강화 및 설정 데이터
    totalScore = 0,
    metaUpgrades = {
        skills = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, -- 10 active skills starting level offsets
        upgrades = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }   -- 9 passive traits starting level offsets
    },
    showStars = true,                              -- 설정: 성간 배경 먼지 그리기 여부
    muted = false,                                 -- 설정: 음소거 여부 (필요 시 효과음 제어용)
    resolutionIndex = 13,                          -- 설정: 해상도 인덱스 (conf.lua의 resolutionList 참조)
}

local game = setmetatable({}, {
    __index = game_data,
    __newindex = function(t, k, v)
        if (k == "state" and v == "gameover") or (k == "running" and v == false) then
            if game_data.player and game_data.player.health <= 0 and not game_data.player.dyingComplete then
                if not game_data.player.dying then
                    game_data.player.dying = true
                    game_data.player.deathTimer = 0
                end
                game_data.running = true
                game_data.state = "playing"
                return
            end
        end
        game_data[k] = v
    end
})

-- 세이브 파일 저장 기능
game.saveGame = function()
    local totalScoreVal = game.totalScore or 0
    local dataStr = string.format("totalScore:%d\nshowStars:%s\nmuted:%s\nresolutionIndex:%d\n",
        totalScoreVal, tostring(game.showStars), tostring(game.muted), game.resolutionIndex or 13)

    for i = 1, 10 do
        dataStr = dataStr .. string.format("skill_%d:%d\n", i, game.metaUpgrades.skills[i] or 0)
    end
    for i = 1, 9 do
        dataStr = dataStr .. string.format("upgrade_%d:%d\n", i, game.metaUpgrades.upgrades[i] or 0)
    end

    love.filesystem.write("save.txt", dataStr)
end

-- 세이브 파일 불러오기 기능
game.loadGame = function()
    game.totalScore = 0
    game.metaUpgrades = {
        skills = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        upgrades = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }
    }
    game.showStars = true
    game.muted = false
    game.resolutionIndex = 13

    if love.filesystem.getInfo("save.txt") then
        for line in love.filesystem.lines("save.txt") do
            local k, v = line:match("([^:]+):([^%s]+)")
            if k and v then
                local val = tonumber(v)
                if k == "totalScore" then
                    game.totalScore = val or 0
                elseif k == "showStars" then
                    game.showStars = (v == "true")
                elseif k == "muted" then
                    game.muted = (v == "true")
                elseif k == "resolutionIndex" then
                    game.resolutionIndex = val or 13
                elseif k:match("^skill_%d+$") then
                    local idx = tonumber(k:match("skill_(%d+)"))
                    if idx and idx >= 1 and idx <= 10 then
                        game.metaUpgrades.skills[idx] = val or 0
                    end
                elseif k:match("^upgrade_%d+$") then
                    local idx = tonumber(k:match("upgrade_(%d+)"))
                    if idx and idx >= 1 and idx <= 9 then
                        local loadedVal = val or 0
                        local maxLvl = 3
                        if idx == 2 or idx == 4 or idx == 9 then
                            maxLvl = 999
                        end
                        if loadedVal > maxLvl then
                            local refundConfigs = {
                                [1] = { base = 800, scale = 400 },
                                [2] = { base = 1000, scale = 500 },
                                [3] = { base = 1000, scale = 500 },
                                [4] = { base = 1200, scale = 600 },
                                [5] = { base = 1000, scale = 500 },
                                [6] = { base = 1200, scale = 600 },
                                [8] = { base = 1500, scale = 700 },
                                [9] = { base = 1200, scale = 600 }
                            }
                            local conf = refundConfigs[idx]
                            if conf then
                                local refund = 0
                                for lv = maxLvl, loadedVal - 1 do
                                    refund = refund + conf.base + lv * conf.scale
                                end
                                game.totalScore = game.totalScore + refund
                                game.shouldReSaveSaveFile = true
                            end
                            loadedVal = maxLvl
                        end
                        game.metaUpgrades.upgrades[idx] = loadedVal
                    end
                end
            end
        end
        if game.shouldReSaveSaveFile then
            game.shouldReSaveSaveFile = nil
            game.saveGame()
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

    -- 사운드 모듈 초기화
    Sound.init(game)

    -- 1회성 스코어 및 업그레이드 현황 초기화 처리
    if not love.filesystem.getInfo("reset_done.txt") then
        game.totalScore = 0
        game.metaUpgrades = {
            skills = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            upgrades = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }
        }
        game.saveGame()
        love.filesystem.write("reset_done.txt", "done")
    end

    game.state = "main_menu"
    game.selectedSkill = nil
    game.metaUpgradePage = 1 -- Default to page 1 (Active Skills)

    HUD.calculateSkillBoxes(game)
    HUD.shuffleSkills(game)
    Sound.playBGM()
    print("Game loaded successfully")
end

-- 배경 데코레이션 초기화 (스테이지별 테마 배경 설계)
local function initBackground(game)
    game.backgroundElements = {}
    game.nebulas = {}
    game.lightningFlash = 0

    if game.endlessMode then
        -- 1. Endless Mode Nebula Palette (Cosmic rift: Violet, Cyan, Magenta, Gold)
        local palette = {
            { 0.12, 0.02, 0.16 },
            { 0.02, 0.14, 0.16 },
            { 0.16, 0.02, 0.10 },
            { 0.15, 0.12, 0.02 }
        }
        for i = 1, 10 do
            local col = palette[math.random(1, #palette)]
            table.insert(game.nebulas, {
                x = math.random(100, game.world.width - 100),
                y = math.random(100, game.world.height - 100),
                radius = math.random(200, 420),
                r = col[1],
                g = col[2],
                b = col[3],
                alpha = 0.08
            })
        end

        -- 2. Endless Mode Dynamic Elements
        -- Rift Sparkles
        for i = 1, 220 do
            table.insert(game.backgroundElements, {
                x = math.random(0, game.world.width),
                y = math.random(0, game.world.height),
                size = math.random(1.2, 3.2),
                alpha = math.random(30, 80) / 100,
                type = "rift_spark",
                speedX = math.random(-25, 25),
                speedY = math.random(-25, -5),
                colorPhase = math.random() * 2 * math.pi
            })
        end

        -- Space-Time Rifts
        for i = 1, 8 do
            table.insert(game.backgroundElements, {
                x = math.random(150, game.world.width - 150),
                y = math.random(150, game.world.height - 150),
                size = math.random(80, 150),
                alpha = math.random(12, 26) / 100,
                type = "time_rift",
                angle = math.random() * 2 * math.pi,
                rotSpeed = (math.random() > 0.5 and 1 or -1) * math.random(3, 7) / 10,
                pulseSpeed = math.random(2, 5),
                color = (math.random() > 0.5 and { 0.2, 0.8, 1.0 } or { 1.0, 0.2, 0.8 })
            })
        end

        -- Cyber Grid Waves
        for i = 1, 12 do
            table.insert(game.backgroundElements, {
                x = math.random(0, game.world.width),
                y = math.random(0, game.world.height),
                len = math.random(120, 300),
                alpha = math.random(8, 22) / 100,
                type = "matrix_wave",
                speed = math.random(30, 80),
                color = { 0.5, 0.3, 0.9 }
            })
        end
        return
    end

    local stage = game.stage or 1

    -- 1. 스테이지별 네뷸라(성운) 색상 팔레트 및 생성
    local nebulaPalettes = {
        -- Stage 1: 공허 구역 - 차가운 블루/바이올렛/다크 사이언
        [1] = { { 0.06, 0.04, 0.16 }, { 0.03, 0.06, 0.15 }, { 0.04, 0.1, 0.14 } },
        -- Stage 2: 붉은 연옥 - 마그마 크림슨/다크 오렌지
        [2] = { { 0.18, 0.03, 0.03 }, { 0.15, 0.06, 0.02 }, { 0.12, 0.01, 0.04 } },
        -- Stage 3: 네온 매트릭스 - 일렉트릭 그린/사이버 사이언
        [3] = { { 0.01, 0.15, 0.06 }, { 0.02, 0.12, 0.1 }, { 0.01, 0.06, 0.12 } },
        -- Stage 4: 뇌전 폐허 - 먹구름 인디고/다크 플럼
        [4] = { { 0.1, 0.05, 0.18 }, { 0.06, 0.03, 0.15 }, { 0.04, 0.04, 0.12 } },
        -- Stage 5: 우주 성역 - 신성한 골든 옐로우/브론즈
        [5] = { { 0.18, 0.13, 0.03 }, { 0.15, 0.1, 0.01 }, { 0.12, 0.12, 0.04 } },
        -- Stage 6: 시간의 특이점 - 에메랄드 그린/에테르 골드/크로노 블랙
        [6] = { { 0.03, 0.16, 0.1 }, { 0.12, 0.1, 0.03 }, { 0.06, 0.06, 0.1 } },
        -- Stage 7: 시스템 코어 - 일렉트릭 마젠타/사이버 사이언/다크 플럼
        [7] = { { 0.16, 0.02, 0.12 }, { 0.02, 0.12, 0.16 }, { 0.06, 0.06, 0.12 } },
        -- Stage 8: 특이점 코어 - 중력 바이올렛/다크 블루/블랙
        [8] = { { 0.1, 0.02, 0.18 }, { 0.02, 0.04, 0.15 }, { 0.04, 0.01, 0.08 } },
        -- Stage 9: 성운의 성소 - 세레스티얼 골드/신성한 백색광/앰버
        [9] = { { 0.2, 0.15, 0.04 }, { 0.18, 0.18, 0.1 }, { 0.15, 0.12, 0.02 } }
    }

    local palette = nebulaPalettes[stage] or nebulaPalettes[1]
    for i = 1, 7 do
        local col = palette[math.random(1, #palette)]
        table.insert(game.nebulas, {
            x = math.random(100, game.world.width - 100),
            y = math.random(100, game.world.height - 100),
            radius = math.random(160, 380),
            r = col[1],
            g = col[2],
            b = col[3],
            alpha = 0.065
        })
    end

    -- 2. 스테이지별 바닥 디테일 입자(backgroundElements) 스케폴딩
    if stage == 1 then
        -- 우주 먼지 및 미세 파티클
        for i = 1, 280 do
            table.insert(game.backgroundElements, {
                x = math.random(0, game.world.width),
                y = math.random(0, game.world.height),
                size = math.random(1, 3),
                alpha = math.random(15, 55) / 100,
                type = "dust",
                color = { 0.4, 0.6, 1.0 }
            })
        end
    elseif stage == 2 then
        -- 마그마 재(Ash) - 위로 표류
        for i = 1, 180 do
            table.insert(game.backgroundElements, {
                x = math.random(0, game.world.width),
                y = math.random(0, game.world.height),
                size = math.random(1.5, 3.5),
                alpha = math.random(25, 70) / 100,
                type = "ash",
                speed = math.random(25, 55),
                color = { 1.0, math.random(20, 60) / 100, 0.05 }
            })
        end
        -- 바닥 용암 분출구 (Magma Vents) - 이펙터
        for i = 1, 15 do
            table.insert(game.backgroundElements, {
                x = math.random(100, game.world.width - 100),
                y = math.random(100, game.world.height - 100),
                size = math.random(40, 80),
                alpha = 0.35,
                type = "vent",
                pulse = math.random() * math.pi
            })
        end
    elseif stage == 3 then
        -- 사이버 정점(Nodes)
        for i = 1, 140 do
            table.insert(game.backgroundElements, {
                x = math.random(0, game.world.width),
                y = math.random(0, game.world.height),
                size = math.random(2, 4),
                alpha = math.random(20, 55) / 100,
                type = "node",
                color = { 0.2, 1.0, 0.5 }
            })
        end
        -- 회로 기판 패턴 (Circuits)
        for i = 1, 24 do
            table.insert(game.backgroundElements, {
                x = math.random(100, game.world.width - 100),
                y = math.random(100, game.world.height - 100),
                len = math.random(50, 130),
                horizontal = (math.random() > 0.5),
                alpha = math.random(15, 38) / 100,
                type = "circuit"
            })
        end
    elseif stage == 4 then
        -- 공중 스파크 입자
        for i = 1, 160 do
            table.insert(game.backgroundElements, {
                x = math.random(0, game.world.width),
                y = math.random(0, game.world.height),
                size = math.random(1, 3),
                alpha = math.random(15, 45) / 100,
                type = "sparkle",
                color = { 0.65, 0.5, 1.0 }
            })
        end
        -- 소형 정전기 방전구
        for i = 1, 18 do
            table.insert(game.backgroundElements, {
                x = math.random(50, game.world.width - 50),
                y = math.random(50, game.world.height - 50),
                size = math.random(4, 7),
                alpha = 0.45,
                type = "electric_charge",
                timer = math.random() * 2.0
            })
        end
    elseif stage == 5 then
        -- 아래로 표류하는 황금 먼지
        for i = 1, 260 do
            table.insert(game.backgroundElements, {
                x = math.random(0, game.world.width),
                y = math.random(0, game.world.height),
                size = math.random(1.5, 3),
                alpha = math.random(30, 70) / 100,
                type = "golden_dust",
                speedY = math.random(12, 28),
                color = { 1.0, 0.85, 0.15 }
            })
        end
        -- 바닥 성역의 빛나는 문양 (Celestial Halos)
        for i = 1, 10 do
            table.insert(game.backgroundElements, {
                x = math.random(150, game.world.width - 150),
                y = math.random(150, game.world.height - 150),
                size = math.random(60, 100),
                alpha = math.random(12, 28) / 100,
                type = "celestial_halo",
                rotSpeed = (math.random() > 0.5 and 1 or -1) * math.random(2, 5) / 10
            })
        end
    elseif stage == 6 then
        -- 시간의 균열 입자
        for i = 1, 150 do
            table.insert(game.backgroundElements, {
                x = math.random(0, game.world.width),
                y = math.random(0, game.world.height),
                size = math.random(1, 2.5),
                alpha = math.random(20, 60) / 100,
                type = "chrono_dust",
                color = { 0.1, 0.9, 0.6 }
            })
        end
        -- 배경 시계 톱니바퀴 (Chrono Gears)
        for i = 1, 12 do
            table.insert(game.backgroundElements, {
                x = math.random(100, game.world.width - 100),
                y = math.random(100, game.world.height - 100),
                size = math.random(70, 120),
                alpha = math.random(10, 22) / 100,
                type = "chrono_gear",
                angle = math.random() * 2 * math.pi,
                rotSpeed = (math.random() > 0.5 and 1 or -1) * math.random(1, 3) / 10
            })
        end
    elseif stage == 7 then
        -- 사이버 글리치 입자 (수평 글리치 라인이나 깨진 코드 블록 노드)
        for i = 1, 150 do
            table.insert(game.backgroundElements, {
                x = math.random(0, game.world.width),
                y = math.random(0, game.world.height),
                size = math.random(2, 4),
                alpha = math.random(20, 60) / 100,
                type = "glitch_node",
                color = (math.random() > 0.5 and { 1.0, 0.0, 0.4 } or { 0.0, 1.0, 1.0 }), -- Cyan or Magenta
                speed = math.random(40, 90)
            })
        end
        -- 글리치 수평 스캔라인
        for i = 1, 15 do
            table.insert(game.backgroundElements, {
                x = math.random(0, game.world.width),
                y = math.random(0, game.world.height),
                len = math.random(60, 200),
                alpha = math.random(10, 30) / 100,
                type = "glitch_line",
                speed = math.random(150, 300)
            })
        end
    elseif stage == 8 then
        -- 8스테이지 중력 왜곡 특이점 입자 (중심으로 회전하는 입자)
        for i = 1, 160 do
            local angle = math.random() * 2 * math.pi
            local dist = math.random(100, 1200)
            table.insert(game.backgroundElements, {
                angle = angle,
                dist = dist,
                speed = math.random(40, 90),
                rotSpeed = math.random(2, 6) / 10,
                size = math.random(1.5, 3.5),
                alpha = math.random(30, 75) / 100,
                type = "void_node",
                color = (math.random() > 0.5 and { 0.5, 0.2, 0.9 } or { 0.2, 0.3, 1.0 }) -- Violet or Blue
            })
        end
    elseif stage == 9 then
        -- 9스테이지 천상의 황금 먼지 및 태양 아우라
        for i = 1, 240 do
            table.insert(game.backgroundElements, {
                x = math.random(0, game.world.width),
                y = math.random(0, game.world.height),
                size = math.random(1, 3.2),
                alpha = math.random(35, 80) / 100,
                type = "shimmer_star",
                speed = math.random(15, 35),
                pulseSpeed = math.random(3, 7),
                color = { 1.0, 0.9, 0.55 }
            })
        end
        for i = 1, 8 do
            table.insert(game.backgroundElements, {
                x = math.random(150, game.world.width - 150),
                y = math.random(150, game.world.height - 150),
                size = math.random(90, 165),
                alpha = math.random(15, 30) / 100,
                type = "solar_halo",
                pulse = math.random() * math.pi,
                rotSpeed = (math.random() > 0.5 and 1 or -1) * math.random(1, 3) / 10
            })
        end
    end
end

-- 게임 시작 함수
local function startGame(startOption)
    -- 플레이어 초기화 (영구 강화 능력치 적용)
    game.player = Player.init(startOption, game.metaUpgrades)

    if startOption and type(startOption) == "table" and startOption.type == "skill" then
        game.selectedSkill = startOption.index
    elseif type(startOption) == "number" then
        game.selectedSkill = startOption
    else
        game.selectedSkill = nil
    end

    -- 첫 카메라 위치 강제 동기화 (적의 화면 밖 스폰 판정을 위함)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    game.camera.x = game.player.x - screenWidth / 2 + game.player.width / 2
    game.camera.y = game.player.y - screenHeight / 2 + game.player.height / 2

    game.enemies = {}
    game.orbs = {}
    game.expOrbs = {}                -- 경험치 구슬
    game.thunders = {}               -- 벼락 스킬 프로젝타일
    game.blades = {}                 -- 칼날 스킬 프로젝타일
    game.bullets = {}                -- 총알 스킬 프로젝타일
    game.lasers = {}                 -- 레이저 스킬 프로젝타일
    game.meteors = {}                -- 운석 스킬 프로젝타일
    game.firePatches = {}            -- 운석 불장판
    game.enemyBullets = {}           -- 적 탄환 프로젝타일
    game.thornsVisuals = {}          -- 가시 이펙트 데칼/비주얼
    game.pendingThornsAttackers = {} -- 피격 시 가시 발동 예약을 위한 리스트
    game.chains = {}                 -- 체인 스킬 프로젝타일
    game.chainTimer = 0              -- 체인 발사 타이머
    game.seekerOrbs = {}             -- 추적 구체 스킬 프로젝타일
    game.seekerOrbTimer = 0          -- 추적 구체 타이머
    game.seekerExplosions = {}       -- 추적 구체 폭발 이펙트 리스트
    game.score = 0
    game.scoreAccumulated = false
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
    game.endlessMode = false
    game.waveState = "playing"
    game.waveTransitionTimer = 0
    game.bannerText = "WAVE 1"
    game.bannerTimer = 2.0
    Enemy.spawnWave(game, 1)

    -- 배경 데코레이션 초기화 연동
    initBackground(game)

    -- 배경 데코레이션용 정적 배경 먼지/별빛은 Stage 1 전용 요소로 startGame에 일부만 유지
    game.backgroundElementsStatic = {}
    for i = 1, 200 do
        table.insert(game.backgroundElementsStatic, {
            x = math.random(0, game.world.width),
            y = math.random(0, game.world.height),
            size = math.random(1, 3),
            alpha = math.random(10, 30) / 100,
            type = math.random(1, 3)
        })
    end

    game.nebulas = {}
    local nebulaColors = {
        { 0.1,  0.05, 0.2 }, -- Purple
        { 0.05, 0.1,  0.2 }, -- Blue/Cyan
        { 0.15, 0.05, 0.1 }, -- Magenta/Pink
        { 0.05, 0.15, 0.1 }  -- Green
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
    -- 메인메뉴, 설정, 강화 화면, 일시정지에서는 일반 루프 미가동
    if game.state == "main_menu" or game.state == "settings" or game.state == "meta_upgrade" or
        game.state == "menu" or game.state == "upgrade" or game.state == "stage_clear" or game.state == "paused" or not game.running or game.showHelp then
        -- 플레이 중이 아니었다가 gameover 상태가 된 순간 스코어 누적 및 세이브 처리
        if game.state == "gameover" and not game.scoreAccumulated then
            game.totalScore = (game.totalScore or 0) + (game.score or 0)
            game.scoreAccumulated = true -- 누적 완료 표기하여 중복 합산 방지 (스코어는 드로우를 위해 유지)
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

    -- 배경 데코레이션 실시간 애니메이션 업데이트
    if game.backgroundElements then
        if game.endlessMode then
            -- Endless Mode Background Elements Update
            for _, elem in ipairs(game.backgroundElements) do
                if elem.type == "rift_spark" then
                    elem.x = elem.x + elem.speedX * dt
                    elem.y = elem.y + elem.speedY * dt
                    elem.colorPhase = elem.colorPhase + 2.0 * dt
                    if elem.y < 0 then
                        elem.y = game.world.height
                        elem.x = math.random(0, game.world.width)
                    end
                    if elem.x < 0 or elem.x > game.world.width then
                        elem.x = math.random(0, game.world.width)
                    end
                elseif elem.type == "time_rift" then
                    elem.angle = elem.angle + elem.rotSpeed * dt
                elseif elem.type == "matrix_wave" then
                    elem.y = elem.y + elem.speed * dt
                    if elem.y > game.world.height then
                        elem.y = 0
                        elem.x = math.random(0, game.world.width)
                    end
                end
            end
        else
            local stage = game.stage or 1
            if stage == 2 then
                -- 마그마 재 입자 상승 처리
                for _, elem in ipairs(game.backgroundElements) do
                    if elem.type == "ash" then
                        elem.y = elem.y - elem.speed * dt
                        if elem.y < 0 then
                            elem.y = game.world.height
                            elem.x = math.random(0, game.world.width)
                        end
                    end
                end
            elseif stage == 4 then
                -- 뇌우/번개 임의 발생 업데이트
                if not game.lightningFlash then game.lightningFlash = 0 end
                if game.lightningFlash > 0 then
                    game.lightningFlash = game.lightningFlash - dt
                else
                    if math.random() < 0.0025 then -- 약 7초 주기 평균
                        game.lightningFlash = math.random(10, 25) / 100
                        game.triggerShake(0.25, 4.5)
                    end
                end
            elseif stage == 5 then
                -- 황금빛 별빛 하강 처리
                for _, elem in ipairs(game.backgroundElements) do
                    if elem.type == "golden_dust" then
                        elem.y = elem.y + elem.speedY * dt
                        if elem.y > game.world.height then
                            elem.y = 0
                            elem.x = math.random(0, game.world.width)
                        end
                    end
                end
            elseif stage == 6 then
                -- 크로노 기어 회전각 업데이트
                for _, elem in ipairs(game.backgroundElements) do
                    if elem.type == "chrono_gear" then
                        elem.angle = elem.angle + elem.rotSpeed * dt
                    end
                end
            elseif stage == 7 then
                -- 글리치 노드 및 스캔라인 업데이트
                for _, elem in ipairs(game.backgroundElements) do
                    if elem.type == "glitch_node" then
                        elem.x = elem.x + (math.random() - 0.5) * elem.speed * dt
                        if elem.x < 0 then
                            elem.x = game.world.width
                        elseif elem.x > game.world.width then
                            elem.x = 0
                        end
                    elseif elem.type == "glitch_line" then
                        elem.x = elem.x + elem.speed * dt
                        if elem.x > game.world.width then
                            elem.x = -elem.len
                            elem.y = math.random(0, game.world.height)
                        end
                    end
                end
            elseif stage == 8 then
                -- 8스테이지 중력 특이점 입자 업데이트 (반경이 줄어들며 공전 속도 상승)
                for _, elem in ipairs(game.backgroundElements) do
                    if elem.type == "void_node" then
                        elem.dist = elem.dist - elem.speed * dt
                        elem.angle = elem.angle + elem.rotSpeed * dt
                        if elem.dist <= 10 then
                            elem.dist = math.random(800, 1200)
                            elem.angle = math.random() * 2 * math.pi
                        end
                    end
                end
            elseif stage == 9 then
                -- 9스테이지 빛 입자 및 아우라 펄스 업데이트
                for _, elem in ipairs(game.backgroundElements) do
                    if elem.type == "shimmer_star" then
                        elem.y = elem.y + elem.speed * dt
                        if elem.y > game.world.height then
                            elem.y = 0
                            elem.x = math.random(0, game.world.width)
                        end
                    elseif elem.type == "solar_halo" then
                        elem.pulse = elem.pulse + 1.5 * dt
                    end
                end
            end
        end
    end

    -- 카메라 업데이트 (플레이어 추적)
    Camera.update(game, dt)

    -- 시간 정지 효과 처리
    if game.timeStopped then
        game.timeStopTimer = (game.timeStopTimer or 0) - dt
        if game.timeStopTimer <= 0 then
            game.timeStopped = false
        else
            -- 시간 정지 중: 플레이어와 적 업데이트 스킵
            return
        end
    end

    -- 플레이어 업데이트 (이동, 피격 쿨다운, 재생)
    Player.update(game, dt)

    -- 스킬 업데이트 (오브, 벼락, 칼날, 총알)
    if game.player and not game.player.dying then
        Skills.update(game, dt)
    end

    -- 적 업데이트 (스폰, 플레이어 추적, 각종 피격 판정)
    Enemy.update(game, dt)

    -- 경험치 구슬 업데이트 (트래킹, 획득 및 레벨업 체크)
    if game.player and not game.player.dying then
        Exp.update(game, dt)
    end
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

    -- 1. 배경 화면 지우기 (스테이지별 전용 테마 색상)
    local clearColors = {
        [1] = { 0.04, 0.04, 0.06 },    -- 공허 구역: 심해 우주색
        [2] = { 0.07, 0.02, 0.02 },    -- 붉은 연옥: 마그마 크림슨
        [3] = { 0.02, 0.04, 0.03 },    -- 네온 매트릭스: 매트릭스 다크 그린
        [4] = { 0.05, 0.045, 0.07 },   -- 뇌전 폐허: 먹구름 바이올렛
        [5] = { 0.07, 0.05, 0.02 },    -- 우주 성역: 세크리드 앰버
        [6] = { 0.02, 0.04, 0.035 },   -- 시간의 특이점: 크로노 다크 에메랄드
        [7] = { 0.015, 0.015, 0.03 },  -- 시스템 코어: 사이버 딥 바이올렛/블랙
        [8] = { 0.005, 0.005, 0.015 }, -- 특이점 코어: 중력 블랙홀 다크 블루
        [9] = { 0.05, 0.04, 0.02 }     -- 성운의 성소: 코스믹 골든 아이보리
    }
    local col = clearColors[game.stage or 1] or clearColors[1]
    love.graphics.clear(col[1], col[2], col[3])

    -- 시간 정지 시각 효과
    if game.timeStopped then
        love.graphics.setColor(0.1, 0.9, 0.6, 0.3)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end

    -- 카메라 적용 (쉐이크 효과 포함)
    local shakeX, shakeY = 0, 0
    if game.shakeTimer and game.shakeTimer > 0 then
        shakeX = (math.random() - 0.5) * game.shakeIntensity
        shakeY = (math.random() - 0.5) * game.shakeIntensity
    end
    love.graphics.push()
    love.graphics.translate(-game.camera.x + shakeX, -game.camera.y + shakeY)

    -- 2. 대형 네뷸라 광원 그리기 (카메라 좌표계 안에서 은은한 광원 효과)
    if game.nebulas then
        for _, neb in ipairs(game.nebulas) do
            love.graphics.setColor(neb.r, neb.g, neb.b, neb.alpha)
            love.graphics.circle("fill", neb.x, neb.y, neb.radius)
        end
    end

    -- 3. 바닥 격자 무늬(Grid Floor) 그리기 (스테이지별 전용 색상 테마)
    local gridColors = {
        [1] = { 0.12, 0.16, 0.25, 0.35 }, -- 사이언 블루
        [2] = { 0.25, 0.08, 0.05, 0.45 }, -- 크림슨 오렌지
        [3] = { 0.05, 0.35, 0.15, 0.45 }, -- 매트릭스 네온 그린
        [4] = { 0.22, 0.12, 0.38, 0.4 },  -- 일렉트릭 퍼플
        [5] = { 0.35, 0.28, 0.08, 0.45 }, -- 홀리 골든 브론즈
        [6] = { 0.1, 0.32, 0.22, 0.4 },   -- 크로노 에메랄드
        [7] = { 0.35, 0.05, 0.2, 0.45 },  -- 사이버 글리치 일렉트릭 마젠타
        [8] = { 0.12, 0.15, 0.22, 0.35 }, -- 그래비티 다크 블루
        [9] = { 0.5, 0.4, 0.1, 0.5 }      -- 세레스티얼 골드 글로우
    }
    local gridCol = gridColors[game.stage or 1] or gridColors[1]
    love.graphics.setColor(gridCol[1], gridCol[2], gridCol[3], gridCol[4])
    love.graphics.setLineWidth(1)
    local gridSize = 80
    for x = 0, game.world.width, gridSize do
        love.graphics.line(x, 0, x, game.world.height)
    end
    for y = 0, game.world.height, gridSize do
        love.graphics.line(0, y, game.world.width, y)
    end

    -- 4. 바닥 상세 데코레이션 그리기
    if game.stage == 1 and game.backgroundElementsStatic then
        -- 1스테이지 전용 정적 우주 파편
        for _, elem in ipairs(game.backgroundElementsStatic) do
            if elem.type == 1 then
                if game.showStars then
                    love.graphics.setColor(0.4, 0.6, 1.0, elem.alpha)
                    love.graphics.circle("fill", elem.x, elem.y, elem.size)
                end
            elseif elem.type == 2 then
                love.graphics.setColor(0.3, 0.7, 0.4, elem.alpha * 0.7)
                love.graphics.setLineWidth(1)
                love.graphics.line(elem.x - 2, elem.y, elem.x + 2, elem.y)
                love.graphics.line(elem.x, elem.y - 2, elem.x, elem.y + 2)
            else
                love.graphics.setColor(0.25, 0.25, 0.3, elem.alpha * 0.9)
                love.graphics.rectangle("fill", elem.x, elem.y, elem.size + 1, elem.size + 1)
            end
        end
    end

    -- 동적 배경 요소 드로잉 (스테이지별 파티클 효과)
    if game.backgroundElements then
        for _, elem in ipairs(game.backgroundElements) do
            if elem.type == "dust" or elem.type == "ash" or elem.type == "node" or elem.type == "sparkle" or elem.type == "golden_dust" or elem.type == "chrono_dust" then
                -- 먼지/재/스파크/네온 노드 (showStars 설정에 연동)
                if game.showStars then
                    love.graphics.setColor(elem.color[1], elem.color[2], elem.color[3], elem.alpha)
                    love.graphics.circle("fill", elem.x, elem.y, elem.size)
                end
            elseif elem.type == "vent" then
                -- 2스테이지 용암 분출구
                local p = 0.8 + 0.2 * math.sin(game.time * 2.0 + elem.pulse)
                love.graphics.setColor(0.32, 0.06, 0.02, elem.alpha * p)
                love.graphics.circle("fill", elem.x, elem.y, elem.size)
                love.graphics.setColor(0.55, 0.15, 0.05, elem.alpha * 0.55 * p)
                love.graphics.circle("fill", elem.x, elem.y, elem.size * 0.6)
            elseif elem.type == "circuit" then
                -- 3스테이지 사이버 회로망
                love.graphics.setColor(0.12, 0.45, 0.22, elem.alpha)
                love.graphics.setLineWidth(1.5)
                if elem.horizontal then
                    love.graphics.line(elem.x, elem.y, elem.x + elem.len, elem.y)
                    love.graphics.setColor(0.2, 0.9, 0.4, elem.alpha * 1.6)
                    love.graphics.rectangle("fill", elem.x + elem.len - 2.5, elem.y - 2.5, 5, 5)
                else
                    love.graphics.line(elem.x, elem.y, elem.x, elem.y + elem.len)
                    love.graphics.setColor(0.2, 0.9, 0.4, elem.alpha * 1.6)
                    love.graphics.rectangle("fill", elem.x - 2.5, elem.y + elem.len - 2.5, 5, 5)
                end
            elseif elem.type == "electric_charge" then
                -- 4스테이지 정전기 이펙터
                local aPulse = 0.45 + 0.35 * math.sin(game.time * 9.0 + elem.timer)
                love.graphics.setColor(0.5, 0.65, 1.0, elem.alpha * aPulse)
                love.graphics.circle("fill", elem.x, elem.y, elem.size)
                love.graphics.setColor(1.0, 1.0, 1.0, elem.alpha * 1.8 * aPulse)
                love.graphics.circle("fill", elem.x, elem.y, elem.size * 0.3)
            elseif elem.type == "celestial_halo" then
                -- 5스테이지 황금빛 오라 링
                love.graphics.push()
                love.graphics.translate(elem.x, elem.y)
                love.graphics.rotate(game.time * elem.rotSpeed)

                love.graphics.setColor(1.0, 0.85, 0.2, elem.alpha)
                love.graphics.setLineWidth(1.6)
                love.graphics.circle("line", 0, 0, elem.size)
                love.graphics.circle("line", 0, 0, elem.size * 0.45)

                for k = 1, 4 do
                    local angle = (k - 1) * (math.pi / 2)
                    love.graphics.line(
                        math.cos(angle) * (elem.size * 0.45), math.sin(angle) * (elem.size * 0.45),
                        math.cos(angle) * elem.size, math.sin(angle) * elem.size
                    )
                end
                love.graphics.pop()
            elseif elem.type == "chrono_gear" then
                -- 6스테이지 크로노 시계 태엽
                love.graphics.push()
                love.graphics.translate(elem.x, elem.y)
                love.graphics.rotate(elem.angle)

                love.graphics.setColor(0.1, 0.82, 0.52, elem.alpha)
                love.graphics.setLineWidth(1.8)
                love.graphics.circle("line", 0, 0, elem.size * 0.75)
                love.graphics.circle("line", 0, 0, elem.size * 0.3)

                for tooth = 1, 8 do
                    local tAngle = (tooth - 1) * (2 * math.pi / 8)
                    love.graphics.push()
                    love.graphics.rotate(tAngle)
                    love.graphics.rectangle("line", elem.size * 0.7, -4, elem.size * 0.15, 8)
                    love.graphics.pop()
                end
                love.graphics.pop()
            elseif elem.type == "glitch_node" then
                -- 7스테이지 사이버 글리치 노드
                if game.showStars then
                    love.graphics.setColor(elem.color[1], elem.color[2], elem.color[3], elem.alpha)
                    if math.random() < 0.08 then
                        love.graphics.rectangle("fill", elem.x - 5, elem.y - 1, 10, 2)
                    else
                        love.graphics.rectangle("fill", elem.x - elem.size / 2, elem.y - elem.size / 2, elem.size,
                            elem.size)
                    end
                end
            elseif elem.type == "glitch_line" then
                -- 7스테이지 글리치 수평 스캔라인
                love.graphics.setColor(0.0, 1.0, 1.0, elem.alpha * 0.7)
                love.graphics.setLineWidth(1)
                love.graphics.line(elem.x, elem.y, elem.x + elem.len, elem.y)

                love.graphics.setColor(1.0, 0.0, 0.4, elem.alpha * 1.5)
                love.graphics.rectangle("fill", elem.x + elem.len - 3, elem.y - 1.5, 6, 3)
            elseif elem.type == "void_node" then
                -- 8스테이지 특이점 블랙홀 입자
                if game.showStars then
                    local centerX = game.world.width / 2
                    local centerY = game.world.height / 2
                    local px = centerX + math.cos(elem.angle) * elem.dist
                    local py = centerY + math.sin(elem.angle) * elem.dist
                    love.graphics.setColor(elem.color[1], elem.color[2], elem.color[3], elem.alpha)
                    love.graphics.circle("fill", px, py, elem.size)
                end
            elseif elem.type == "shimmer_star" then
                -- 9스테이지 천상의 황금 먼지
                if game.showStars then
                    local pulse = 0.7 + 0.3 * math.sin(game.time * (elem.pulseSpeed or 5))
                    love.graphics.setColor(elem.color[1], elem.color[2], elem.color[3], elem.alpha * pulse)
                    love.graphics.circle("fill", elem.x, elem.y, elem.size * pulse)
                end
            elseif elem.type == "solar_halo" then
                -- 9스테이지 태양 아우라
                local sizePulse = 1.0 + math.sin(elem.pulse) * 0.08
                local r = elem.size * sizePulse
                love.graphics.setColor(1.0, 0.8, 0.35, elem.alpha)
                love.graphics.setLineWidth(1.5)
                love.graphics.circle("line", elem.x, elem.y, r)
                love.graphics.circle("line", elem.x, elem.y, r * 0.75)

                for k = 1, 12 do
                    local angle = (k - 1) * (2 * math.pi / 12) + game.time * (elem.rotSpeed or 0.2)
                    love.graphics.line(
                        elem.x + math.cos(angle) * (r * 0.75), elem.y + math.sin(angle) * (r * 0.75),
                        elem.x + math.cos(angle) * r, elem.y + math.sin(angle) * r
                    )
                end
            elseif elem.type == "rift_spark" then
                -- Endless Mode: Shift colors dynamically based on colorPhase
                if game.showStars then
                    local r_val = 0.5 + 0.5 * math.sin(elem.colorPhase)
                    local g_val = 0.5 + 0.5 * math.sin(elem.colorPhase + 2.09)
                    local b_val = 0.5 + 0.5 * math.sin(elem.colorPhase + 4.18)
                    local pulse = 0.75 + 0.25 * math.sin(elem.colorPhase * 3)
                    love.graphics.setColor(r_val, g_val, b_val, elem.alpha * pulse)
                    love.graphics.circle("fill", elem.x, elem.y, elem.size * pulse)
                end
            elseif elem.type == "time_rift" then
                -- Endless Mode: Warping dimensional ellipses
                love.graphics.push()
                love.graphics.translate(elem.x, elem.y)
                love.graphics.rotate(elem.angle)

                local pulse = 1.0 + 0.12 * math.sin(game.time * elem.pulseSpeed)
                local rw = elem.size * pulse
                local rh = elem.size * 0.45 * pulse

                -- Outer glowing boundary
                love.graphics.setLineWidth(2)
                love.graphics.setColor(elem.color[1], elem.color[2], elem.color[3], elem.alpha)
                love.graphics.ellipse("line", 0, 0, rw, rh)

                -- Inner core
                love.graphics.setColor(1.0, 1.0, 1.0, elem.alpha * 1.5)
                love.graphics.ellipse("line", 0, 0, rw * 0.5, rh * 0.5)

                -- Portal particle lines crossing inside
                love.graphics.setLineWidth(1)
                love.graphics.setColor(elem.color[1], elem.color[2], elem.color[3], elem.alpha * 0.6)
                for k = 1, 4 do
                    local offset = (k - 1) * (rw * 0.2) - rw * 0.4
                    love.graphics.line(offset, -rh * 0.3, offset, rh * 0.3)
                end

                love.graphics.pop()
            elseif elem.type == "matrix_wave" then
                -- Endless Mode: Horizontal scanner lines
                love.graphics.setColor(elem.color[1], elem.color[2], elem.color[3], elem.alpha)
                love.graphics.setLineWidth(1.5)
                love.graphics.line(elem.x, elem.y, elem.x + elem.len, elem.y)

                -- End dot
                love.graphics.setColor(0.8, 0.4, 1.0, elem.alpha * 1.8)
                love.graphics.rectangle("fill", elem.x + elem.len - 3, elem.y - 1.5, 6, 3)
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

    -- 5. 번개 섬광 효과 (Stage 4 전용) - 화면 전체를 뒤덮는 짧은 섬광 효과
    if game.stage == 4 and game.lightningFlash and game.lightningFlash > 0 then
        love.graphics.setColor(0.78, 0.85, 1.0, game.lightningFlash * 0.45)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end

    -- 6. 시스템 해킹 / 키보드 반전 글리치 화면 왜곡 효과 (Stage 7 보스 패턴 연동)
    if game.player and game.player.controlsInvertedTimer and game.player.controlsInvertedTimer > 0 then
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()

        -- 임의로 깜빡이는 사이언/마젠타 반투명 레이어 틴트
        local glitchIntensity = game.player.controlsInvertedTimer / 2.5
        local randOffset = (math.random() - 0.5) * 12 * glitchIntensity

        -- Chromatic Aberration 모사: 마젠타 빔과 사이언 빔을 오프셋 시켜 드로우
        love.graphics.setColor(1.0, 0.0, 0.4, 0.14 * glitchIntensity)
        love.graphics.rectangle("fill", randOffset, 0, w, h)
        love.graphics.setColor(0.0, 1.0, 1.0, 0.14 * glitchIntensity)
        love.graphics.rectangle("fill", -randOffset, 0, w, h)

        -- 화면에 가로로 찢어지는 글리치 라인 노이즈 그리기
        love.graphics.setLineWidth(math.random(1, 4))
        for line = 1, math.random(2, 6) do
            local ly = math.random(50, h - 50)
            local lh = math.random(2, 16)
            local lx = math.random(-20, 20)
            love.graphics.setColor(0.1, 0.9, 0.8, 0.35 * glitchIntensity)
            love.graphics.rectangle("fill", lx, ly, w, lh)
        end
        love.graphics.setLineWidth(1)

        -- 경고 텍스트 출력
        local pulse = 0.8 + 0.2 * math.sin(game.time * 25)
        love.graphics.setColor(1.0, 0.1, 0.4, 0.95 * pulse)
        local font = love.graphics.newFont(20)
        love.graphics.setFont(font)
        love.graphics.printf("WARNING: SYSTEM HACKED", 0, 80, w, "center")

        local subFont = love.graphics.newFont(12)
        love.graphics.setFont(subFont)
        love.graphics.setColor(0.0, 1.0, 1.0, 0.9 * pulse)
        love.graphics.printf("CONTROLS INVERTED (" .. string.format("%.1fs", game.player.controlsInvertedTimer) .. ")", 0,
            115, w, "center")
    end

    -- 화면 UI 그리기 (HUD: 점수, 레벨, 시간)
    HUD.drawUI(game)

    -- 일시정지 팝업 그리기
    if game.state == "paused" then
        HUD.drawPause(game)
    end

    -- Render help overlay
    if game.showHelp then
        HUD.drawHelp(game)
    end
end

-- ============================================================================
-- 이벤트 핸들러
-- ============================================================================

function love.keypressed(key)
    if game.player and game.player.dying and not game.player.dyingComplete then
        return
    end

    if key == "f1" then
        game.showHelp = not game.showHelp
        return
    end

    if game.showHelp then
        if key == "escape" then
            game.showHelp = false
        end
        return
    end

    if key == "escape" then
        if game.state == "playing" then
            game.state = "paused"
            game.running = false
        elseif game.state == "paused" then
            game.state = "playing"
            game.running = true
        elseif game.state == "settings" then
            game.state = game.prevSettingsState or "main_menu"
            game.prevSettingsState = nil
        end
    end

    if game.state == "playing" and (key == "p" or key == "P") then
        game.enemies = {}
        game.enemyBullets = {}
    end

    -- Cheat key O: Instant level up by granting maximum experience
    if game.state == "playing" and (key == "o" or key == "O") then
        local player = game.player
        if player then
            player.experience = player.maxExperience
            local Exp = require("progression.exp")
            Exp.checkLevelUp(game)
        end
    end

    -- Cheat key K: Force skip to next stage and start wave 1 (Disabled in Endless Mode)
    if game.state == "playing" and not game.endlessMode and (key == "k" or key == "K") then
        game.enemies = {}
        game.enemyBullets = {}
        if game.stage == 9 then
            game.state = "stage_clear"
            game.running = false
        else
            game.stage = (game.stage or 1) + 1
            game.wave = 1
            game.waveState = "playing"
            game.bannerText = "STAGE " .. game.stage .. " START!"
            game.bannerTimer = 3.0
            initBackground(game)
            Enemy.spawnWave(game, 1)
        end
    end

    -- Cheat key I: Instant transition to Boss Wave (Wave 7 in normal, next 5th wave in endless) and spawn boss
    if game.state == "playing" and (key == "i" or key == "I") then
        game.enemies = {}
        game.enemyBullets = {}
        if game.endlessMode then
            local nextBossWave = math.floor(game.wave / 5) * 5 + 5
            game.wave = nextBossWave
            game.waveState = "playing"
            Enemy.spawnWave(game, nextBossWave)
        else
            game.wave = 7
            game.waveState = "playing"
            Enemy.spawnWave(game, 7)
        end
    end
end

function love.mousepressed(x, y, button)
    if game.player and game.player.dying and not game.player.dyingComplete then
        return
    end

    if game.showHelp then
        if button == 1 and game.helpCloseBtn then
            local btn = game.helpCloseBtn
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                game.showHelp = false
            end
        end
        return
    end

    if button == 1 then
        Sound.play("select")
        if game.state == "main_menu" then
            if game.mainMenuButtons then
                for _, btn in ipairs(game.mainMenuButtons) do
                    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                        if btn.action == "exit" then
                            love.event.quit()
                        else
                            game.state = btn.state
                            if btn.state == "menu" then
                                HUD.shuffleSkills(game)
                            end
                        end
                        break
                    end
                end
            end
        elseif game.state == "paused" then
            if game.pauseButtons then
                for _, btn in ipairs(game.pauseButtons) do
                    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                        if btn.action == "resume" then
                            game.state = "playing"
                            game.running = true
                        elseif btn.action == "settings" then
                            game.prevSettingsState = "paused"
                            game.state = "settings"
                        elseif btn.action == "title" then
                            -- 타이틀로 이동 시 스코어 누적 및 세이브 처리
                            game.totalScore = (game.totalScore or 0) + (game.score or 0)
                            game.score = 0
                            game.saveGame()
                            game.state = "main_menu"
                            game.running = false
                        elseif btn.action == "exit" then
                            love.event.quit()
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
                        if box.key == "muted" then
                            Sound.updateMuteState()
                        end
                        break
                    end
                end
            end

            -- 뒤로 가기 버튼 클릭 처리
            local back = game.settingsBackBtn
            if back and x >= back.x and x <= back.x + back.w and y >= back.y and y <= back.y + back.h then
                game.state = game.prevSettingsState or "main_menu"
                game.prevSettingsState = nil
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
                    local option = game.skillOptions[i]
                    if option then
                        startGame(option)
                    end
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
        elseif game.state == "gameover" then
            if game.gameOverButtons then
                for _, btn in ipairs(game.gameOverButtons) do
                    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                        if btn.action == "menu" then
                            if not game.scoreAccumulated then
                                game.totalScore = (game.totalScore or 0) + (game.score or 0)
                                game.scoreAccumulated = true
                                game.saveGame()
                            end
                            game.score = 0
                            game.state = "main_menu"
                            game.running = false
                        elseif btn.action == "exit" then
                            love.event.quit()
                        end
                        break
                    end
                end
            end
        elseif game.state == "stage_clear" then
            local screenWidth = love.graphics.getWidth()
            local screenHeight = love.graphics.getHeight()
            local btnY = screenHeight / 2 + 50
            local btnHeight = 60

            if game.stage == 9 and not game.endlessMode then
                local centerX = screenWidth / 2
                local btn1X = centerX - 275
                local btn1Width = 260
                local btn2X = centerX + 15
                local btn2Width = 260

                if x >= btn1X and x <= btn1X + btn1Width and y >= btnY and y <= btnY + btnHeight then
                    -- Start Endless Mode!
                    game.endlessMode = true
                    game.stage = 9
                    game.wave = 1
                    game.waveState = "playing"
                    game.bannerText = "ENDLESS MODE START!"
                    game.bannerTimer = 3.0
                    game.state = "playing"
                    game.running = true
                    initBackground(game)

                    local EnemyModule = require("enemy.spawner")
                    EnemyModule.spawnWave(game, 1)
                elseif x >= btn2X and x <= btn2X + btn2Width and y >= btnY and y <= btnY + btnHeight then
                    -- Back to Main Menu
                    game.totalScore = (game.totalScore or 0) + (game.score or 0)
                    game.score = 0
                    game.saveGame()
                    game.state = "main_menu"
                    game.running = false
                end
            else
                local btnWidth = 280
                local btnX = (screenWidth - btnWidth) / 2
                if x >= btnX and x <= btnX + btnWidth and y >= btnY and y <= btnY + btnHeight then
                    if game.stage == 9 then
                        game.totalScore = (game.totalScore or 0) + (game.score or 0)
                        game.score = 0
                        game.saveGame()
                        game.state = "main_menu"
                        game.running = false
                    else
                        -- 다음 스테이지 개시 처리
                        game.stage = (game.stage or 1) + 1
                        game.wave = 1
                        game.waveState = "playing"
                        game.bannerText = "STAGE " .. game.stage .. " START!"
                        game.bannerTimer = 3.0
                        game.state = "playing"
                        game.running = true
                        initBackground(game)

                        local EnemyModule = require("enemy.spawner")
                        EnemyModule.spawnWave(game, 1)
                    end
                end
            end
        end
    end
end
