-- ============================================================================
-- exp.lua — 경험치 구슬 관리 및 레벨업 시스템 모듈
-- ============================================================================

local Collision = require("combat.collision")
local Exp = {}

-- 경험치 구슬 생성
function Exp.spawn(game, x, y)
    table.insert(game.expOrbs, {
        x = x,
        y = y,
        size = 6,
        experience = 10,
        speed = 150,
        magnetRange = 100
    })
end

-- 경험치 구슬 업데이트 (자석 효과 및 플레이어 획득 처리)
function Exp.update(game, dt)
    local player = game.player
    if not player then return end

    for i = #game.expOrbs, 1, -1 do
        local expOrb = game.expOrbs[i]

        -- 플레이어와의 거리 계산
        local dx = player.x + player.width / 2 - expOrb.x
        local dy = player.y + player.height / 2 - expOrb.y
        local dist = math.sqrt(dx * dx + dy * dy)

        -- 자석 특성이 있고 자석 범위 내에 있으면 플레이어에게 이동
        if player.hasMagnet and dist < player.magnetRange then
            -- 플레이어 속도보다 훨씬 빠르게 설정하여 확실히 따라잡도록 함
            local pullSpeed = math.max(expOrb.speed, player.speed + 150)
            expOrb.x = expOrb.x + (dx / dist) * pullSpeed * dt
            expOrb.y = expOrb.y + (dy / dist) * pullSpeed * dt
        end

        -- 플레이어와 충돌하면 경험치 획득
        local orbRect = { x = expOrb.x, y = expOrb.y, width = expOrb.size, height = expOrb.size }
        if Collision.check(player, orbRect) then
            local gain = math.floor(expOrb.experience * (player.expModifier or 1.0))
            player.experience = player.experience + gain
            table.remove(game.expOrbs, i)

            -- 레벨업 체크
            Exp.checkLevelUp(game)
        end
    end
end

-- 레벨업 조건 충족 확인 및 보너스/특성 선택 창 활성화
function Exp.checkLevelUp(game)
    local player = game.player
    if not player then return end

    if player.experience >= player.maxExperience then
        player.experience = player.experience - player.maxExperience
        player.level = player.level + 1
        player.maxExperience = math.floor(player.maxExperience * 1.5)

        -- 레벨업 보너스 (체력 회복)
        player.health = math.min(player.health + 20, player.maxHealth)

        -- 1) 사용 가능한 스킬 목록 추출 (최대 5레벨 미만)
        local availableSkills = {}
        for i = 1, #game.skills do
            if (player.skillLevels[i] or 0) < 5 then
                table.insert(availableSkills, i)
            end
        end
        -- 스킬 목록 셔플 (중복 없는 무작위)
        for i = #availableSkills, 2, -1 do
            local j = math.random(i)
            availableSkills[i], availableSkills[j] = availableSkills[j], availableSkills[i]
        end

        -- 2) 사용 가능한 특성 목록 추출 (최대 3레벨 미만)
        local availableUpgrades = {}
        for i = 1, #game.upgrades do
            if (player.upgradeLevels[i] or 0) < 3 then
                table.insert(availableUpgrades, i)
            end
        end
        -- 특성 목록 셔플 (중복 없는 무작위)
        for i = #availableUpgrades, 2, -1 do
            local j = math.random(i)
            availableUpgrades[i], availableUpgrades[j] = availableUpgrades[j], availableUpgrades[i]
        end

        -- 3) 3개의 상자 슬롯 옵션 구성 (왼쪽 2개: 스킬 우선, 오른쪽 1개: 특성)
        game.upgradeOptions = {}

        -- 박스 1 (왼쪽)
        if #availableSkills > 0 then
            table.insert(game.upgradeOptions, { type = "skill", index = table.remove(availableSkills, 1) })
        elseif #availableUpgrades > 0 then
            table.insert(game.upgradeOptions, { type = "upgrade", index = table.remove(availableUpgrades, 1) })
        end

        -- 박스 2 (중앙)
        if #availableSkills > 0 then
            table.insert(game.upgradeOptions, { type = "skill", index = table.remove(availableSkills, 1) })
        elseif #availableUpgrades > 0 then
            table.insert(game.upgradeOptions, { type = "upgrade", index = table.remove(availableUpgrades, 1) })
        end

        -- 박스 3 (오른쪽)
        if #availableUpgrades > 0 then
            table.insert(game.upgradeOptions, { type = "upgrade", index = table.remove(availableUpgrades, 1) })
        elseif #availableSkills > 0 then
            table.insert(game.upgradeOptions, { type = "skill", index = table.remove(availableSkills, 1) })
        end

        -- 만약 아무런 업그레이드 옵션도 남지 않은 경우 바로 게임을 재개함
        if #game.upgradeOptions == 0 then
            game.state = "playing"
            game.running = true
        else
            game.state = "upgrade"
            game.running = false
            if game.calculateUpgradeBoxes then
                game.calculateUpgradeBoxes()
            end
        end
    end
end

-- 경험치 구슬 렌더링
function Exp.draw(game)
    love.graphics.setColor(0.3, 0.8, 1.0)
    for _, expOrb in ipairs(game.expOrbs) do
        love.graphics.circle("fill", expOrb.x, expOrb.y, expOrb.size)
    end
end

return Exp
