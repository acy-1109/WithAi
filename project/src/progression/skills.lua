-- ============================================================================
-- skills.lua — 스킬들(구체, 벼락, 칼날, 총알)의 업데이트, 그리기 및 특성/레벨업 처리
-- ============================================================================

-- 스킬별 레벨 스펙 데이터 테이블
local thunderLevels = {
    { cooldown = 3.0, damage = 40, count = 1 },
    { cooldown = 2.2, damage = 50, count = 1 },
    { cooldown = 2.2, damage = 50, count = 2 },
    { cooldown = 1.4, damage = 65, count = 2 },
    { cooldown = 1.4, damage = 65, count = 3 },
}

local bladeLevels = {
    { cooldown = 2.0, damage = 40, count = 1, size = 10 },
    { cooldown = 1.5, damage = 50, count = 1, size = 10 },
    { cooldown = 1.5, damage = 50, count = 2, size = 10 },
    { cooldown = 1.0, damage = 55, count = 2, size = 10 },
    { cooldown = 1.0, damage = 65, count = 3, size = 18 },
}

local bulletLevels = {
    { cooldown = 1.5, pierce = false, count = 1, damage = 40 },
    { cooldown = 1.2, pierce = true,  count = 1, damage = 45 },
    { cooldown = 0.9, pierce = true,  count = 3, damage = 55 },
    { cooldown = 0.7, pierce = true,  count = 3, damage = 55 },
    { cooldown = 0.5, pierce = true,  count = 3, damage = 70 },
}

local laserLevels = {
    { cooldown = 6.0, damage = 40,  thickness = 10, duration = 0.6 },
    { cooldown = 5.5, damage = 70,  thickness = 14, duration = 0.7 },
    { cooldown = 5.0, damage = 110, thickness = 18, duration = 0.8 },
    { cooldown = 4.5, damage = 160, thickness = 18, duration = 0.8 },
    { cooldown = 4.0, damage = 250, thickness = 26, duration = 1.0 },
}

local magneticFieldLevels = {
    { cooldown = 6.0, radius = 120, duration = 3.0, damage = 5,  tickInterval = 0.25 },
    { cooldown = 5.0, radius = 120, duration = 3.0, damage = 8,  tickInterval = 0.25 },
    { cooldown = 5.0, radius = 120, duration = 4.5, damage = 8,  tickInterval = 0.25 },
    { cooldown = 5.0, radius = 170, duration = 4.5, damage = 12, tickInterval = 0.25 },
    { cooldown = 4.0, radius = 170, duration = 4.5, damage = 12, tickInterval = 0.25 },
}

local meteorLevels = {
    { cooldown = 8.0, damage = 50, count = 1, hasFire = false },
    { cooldown = 6.0, damage = 85, count = 1, hasFire = false },
    { cooldown = 6.0, damage = 85, count = 2, hasFire = false },
    { cooldown = 6.0, damage = 85, count = 2, hasFire = true },
    { cooldown = 6.0, damage = 85, count = 3, hasFire = true },
}

local cutterLevels = {
    { count = 1, damage = 40, speed = 2.5, length = 80 },
    { count = 2, damage = 50, speed = 2.5, length = 85 },
    { count = 3, damage = 50, speed = 3.5, length = 90 },
    { count = 4, damage = 60, speed = 3.5, length = 95 },
    { count = 5, damage = 60, speed = 5.0, length = 100 }
}

local cutterCurvature = 0.7

local chainLevels = {
    { count = 1, rootDuration = 2.0, maxChains = 1, cooldown = 4.0, damage = 40 },
    { count = 1, rootDuration = 3.5, maxChains = 1, cooldown = 4.0, damage = 45 },
    { count = 1, rootDuration = 3.5, maxChains = 2, cooldown = 4.0, damage = 50 },
    { count = 2, rootDuration = 3.5, maxChains = 2, cooldown = 4.0, damage = 55 },
    { count = 2, rootDuration = 3.5, maxChains = 2, cooldown = 2.5, damage = 65 }
}

local seekerOrbLevels = {
    { cooldown = 4.0, count = 1, damage = 40, chargeTime = 1.2, speed = 400, explode = false },
    { cooldown = 4.0, count = 2, damage = 45, chargeTime = 1.2, speed = 400, explode = false },
    { cooldown = 2.5, count = 2, damage = 55, chargeTime = 1.2, speed = 450, explode = false },
    { cooldown = 2.5, count = 3, damage = 55, chargeTime = 1.2, speed = 450, explode = false },
    { cooldown = 2.5, count = 3, damage = 70, chargeTime = 1.2, speed = 500, explode = true },
}

local function isEnemyAlive(game, enemy)
    if not game.enemies then return false end
    for _, e in ipairs(game.enemies) do
        if e == enemy then return true end
    end
    return false
end

local function isAlreadyChained(game, enemy)
    if not game.chains then return false end
    for _, chain in ipairs(game.chains) do
        if chain.target == enemy and chain.state ~= "fading" then
            return true
        end
    end
    return false
end

local Skills = {}

-- 플레이어와 가장 가까운 적 찾기
function Skills.findClosestEnemy(game)
    local player = game.player
    if not player or #game.enemies == 0 then return nil end

    local closestEnemy = nil
    local closestDistance = math.huge

    for _, enemy in ipairs(game.enemies) do
        local dx = enemy.x + enemy.width / 2 - (player.x + player.width / 2)
        local dy = enemy.y + enemy.height / 2 - (player.y + player.height / 2)
        local distance = math.sqrt(dx * dx + dy * dy)

        if distance < closestDistance then
            closestDistance = distance
            closestEnemy = enemy
        end
    end

    return closestEnemy
end

-- 플레이어와 가까운 순서대로 최대 N개의 적 찾기 (excludeBoss가 참일 경우 보스는 제외)
function Skills.findClosestEnemies(game, n, excludeBoss)
    local player = game.player
    if not player or #game.enemies == 0 then return {} end

    local candidates = {}
    for _, enemy in ipairs(game.enemies) do
        if not (excludeBoss and enemy.type == "boss") and not isAlreadyChained(game, enemy) then
            local dx = enemy.x + enemy.width / 2 - (player.x + player.width / 2)
            local dy = enemy.y + enemy.height / 2 - (player.y + player.height / 2)
            local distance = math.sqrt(dx * dx + dy * dy)
            table.insert(candidates, { enemy = enemy, distance = distance })
        end
    end

    table.sort(candidates, function(a, b)
        return a.distance < b.distance
    end)

    local result = {}
    for i = 1, math.min(n, #candidates) do
        table.insert(result, candidates[i].enemy)
    end
    return result
end

-- 특정 좌표로부터 가장 가까우면서 제외 대상을 제외한 적 찾기 (체인 연쇄용, 보스는 제외)
function Skills.findClosestEnemyFrom(game, fromX, fromY, excludeSet)
    if not game.enemies or #game.enemies == 0 then return nil end

    local closestEnemy = nil
    local closestDistance = math.huge

    for _, enemy in ipairs(game.enemies) do
        if not excludeSet[enemy] and not isAlreadyChained(game, enemy) then
            local ecx = enemy.x + enemy.width / 2
            local ecy = enemy.y + enemy.height / 2
            local dx = ecx - fromX
            local dy = ecy - fromY
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance < closestDistance then
                closestDistance = distance
                closestEnemy = enemy
            end
        end
    end

    return closestEnemy
end

-- 칼날 투사체 인스턴스 생성 및 리스트 삽입
function Skills.spawnBlade(game, targetEnemy, damage, size)
    local player = game.player
    if not player or not targetEnemy then return end

    local startX = player.x + player.width / 2
    local startY = player.y + player.height / 2
    local targetX = targetEnemy.x + targetEnemy.width / 2
    local targetY = targetEnemy.y + targetEnemy.height / 2

    local dx = targetX - startX
    local dy = targetY - startY
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 0 then
        local offsetScale = math.min(100, dist * 0.3)
        local perpX = -dy / dist * offsetScale
        local perpY = dx / dist * offsetScale

        table.insert(game.blades, {
            x = startX,
            y = startY,
            startX = startX,
            startY = startY,
            targetX = targetX,
            targetY = targetY,
            perpX = perpX,
            perpY = perpY,
            speed = 220, -- 등속 비행 속도 (220)
            damage = damage,
            size = size,
            progress = 0,
            totalDistance = dist * 2,
            trail = {} -- 궤적 트레일 초기화
        })
    end
end

-- 회전 구체(Orbiting Orb) 개수 동기화 및 생성 (레벨에 비례하여 개수 증가 및 등간격 배치)
function Skills.syncOrbs(game)
    local player = game.player
    if not player then return end

    local level = player.skillLevels[1] or 0
    game.orbs = {}

    -- 레벨별 능력치 스케일링 설정
    -- 기본 속도: 3.0, 3레벨: 4.5, 5레벨: 6.0
    local speed = 3.0
    if level == 3 or level == 4 then
        speed = 4.5
    elseif level >= 5 then
        speed = 6.0
    end

    -- 기본 대미지: player.damage * 4.0 (1스테이지 적 원샷 보장), 4레벨 이상: player.damage * 4.0 * 1.5
    local damage = player.damage * 4.0
    if level >= 4 then
        damage = player.damage * 4.0 * 1.5
    end

    for i = 1, level do
        table.insert(game.orbs, {
            angle = (i - 1) * (2 * math.pi / level), -- 각 구체의 시작 각도를 균등 분할
            radius = 60,
            speed = speed,
            damage = damage,
            size = 18, -- 크기를 8에서 18로 확대 (유저 요청 반영)
            trail = {} -- 궤적 트레일 초기화
        })
    end
end

-- 모든 액티브 스킬들의 투사체 물리 상태 업데이트

local SkillsUpdate = require("progression.skills_update")
local SkillsDraw = require("progression.skills_draw")

Skills.thunderLevels = thunderLevels
Skills.bladeLevels = bladeLevels
Skills.bulletLevels = bulletLevels
Skills.laserLevels = laserLevels
Skills.magneticFieldLevels = magneticFieldLevels
Skills.meteorLevels = meteorLevels
Skills.cutterLevels = cutterLevels
Skills.cutterCurvature = cutterCurvature
Skills.chainLevels = chainLevels
Skills.seekerOrbLevels = seekerOrbLevels
Skills.isEnemyAlive = isEnemyAlive
Skills.isAlreadyChained = isAlreadyChained

function Skills.update(game, dt)
    SkillsUpdate.update(game, dt, Skills)
end

function Skills.draw(game)
    SkillsDraw.draw(game, Skills)
end

-- 통합 레벨업 선택창(스킬 또는 특성)에서 카드 클릭 시 업그레이드 적용
function Skills.applyUpgrade(game, boxIndex)
    local player = game.player
    if not player then return end

    local option = game.upgradeOptions[boxIndex]
    if not option then return end

    if option.type == "skill" then
        -- 스킬 해제 및 레벨업
        local skillIndex = option.index
        player.skillLevels[skillIndex] = (player.skillLevels[skillIndex] or 0) + 1

        -- 구체형 스킬의 경우 배치 상태 동기화
        if skillIndex == 1 then
            Skills.syncOrbs(game)
        end
    elseif option.type == "upgrade" then
        -- 특성 레벨업
        local upgradeIndex = option.index
        local upgrade = game.upgrades[upgradeIndex]

        local maxLvl = 3
        if upgradeIndex == 2 or upgradeIndex == 4 or upgradeIndex == 9 then
            maxLvl = 999
        end
        if player.upgradeLevels[upgradeIndex] < maxLvl then
            player.upgradeLevels[upgradeIndex] = player.upgradeLevels[upgradeIndex] + 1
        end

        if upgrade.name == "Magnet" then
            player.hasMagnet = true
            player.magnetRange = player.magnetRange * 1.03
        elseif upgrade.name == "Health Boost" then
            player.maxHealth = player.maxHealth * 1.1
            player.health = player.health * 1.1
        elseif upgrade.name == "Speed Boost" then
            player.speed = player.speed * 1.05
        elseif upgrade.name == "Damage Boost" then
            player.damage = player.damage * 1.1
            -- 활성화된 구체 상태 동기화 (데미지 및 스케일링 재설정)
            Skills.syncOrbs(game)
        elseif upgrade.name == "Health Regen" then
            player.regenRate = player.regenRate + 5
        elseif upgrade.name == "EXP Boost" then
            player.expModifier = (player.expModifier or 1.0) + 0.25
        elseif upgrade.name == "Thorns" then
            -- Thorns upgrade is matched here (no immediate stat updates required)
        elseif upgrade.name == "Energy Shield" then
            player.shieldActive = true
            player.shieldTimer = 0
            player.shieldRestoreVisualTimer = 0.4
        elseif upgrade.name == "Defense Boost" then
            player.defenseReduction = 1 - (1 - (player.defenseReduction or 0)) * 0.95
        end
    end

    -- 게임 재개
    game.state = "playing"
    game.running = true
end

-- 피해를 입었을 때 가시 특성(반사 피해 및 아우라) 트리거
function Skills.triggerThorns(game, attacker)
    local player = game.player
    if not player then return end

    -- Thorns는 7번째 특성이므로 인덱스 7
    local thornsLevel = player.upgradeLevels[7] or 0
    if thornsLevel <= 0 then return end

    -- 레벨당 30% 확률 (1레벨: 30%, 2레벨: 60%, 3레벨: 90%)
    if math.random() < thornsLevel * 0.3 then
        local dmg = player.damage * 2.5 * thornsLevel
        local radius = 150 + thornsLevel * 30
        local px = player.x + player.width / 2
        local py = player.y + player.height / 2

        -- 1) 가시 방출 비주얼 생성
        game.thornsVisuals = game.thornsVisuals or {}
        table.insert(game.thornsVisuals, {
            x = px,
            y = py,
            radius = radius,
            timer = 0.35,
            maxTimer = 0.35,
            level = thornsLevel
        })

        -- 2) 피해를 준 적(Attaker)이 있으면 먼저 다이렉트 대미지 적용
        local EnemyModule = require("enemy.spawner")
        if attacker then
            local attackerIdx = nil
            for idx, enemy in ipairs(game.enemies) do
                if enemy == attacker then
                    attackerIdx = idx
                    break
                end
            end
            if attackerIdx then
                EnemyModule.damage(game, attackerIdx, dmg)
            end
        end

        -- 3) 주변 모든 적들에게 범위 대미지(Retaliation AoE) 적용
        for idx = #game.enemies, 1, -1 do
            local enemy = game.enemies[idx]
            if enemy ~= attacker then
                local ecx = enemy.x + enemy.width / 2
                local ecy = enemy.y + enemy.height / 2
                local dx = ecx - px
                local dy = ecy - py
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist <= radius + enemy.width / 2 then
                    EnemyModule.damage(game, idx, dmg)
                end
            end
        end

        -- 4) 타격감 증대를 위한 가시적 화면 쉐이크 트리거
        if game.triggerShake then
            game.triggerShake(0.2, 5)
        end
    end
end

return Skills
