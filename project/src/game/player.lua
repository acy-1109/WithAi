-- ============================================================================
-- player.lua — 플레이어 초기화, 업데이트 및 렌더링 모듈
-- ============================================================================

local Player = {}

-- 플레이어 데이터 초기화
function Player.init(skillIndex)
    local skillLevels = { 0, 0, 0, 0, 0, 0 }
    if skillIndex and skillIndex >= 1 and skillIndex <= 6 then
        skillLevels[skillIndex] = 1
    end

    return {
        x = 400,
        y = 300,
        width = 32,
        height = 32,
        speed = 200,
        health = 100,
        maxHealth = 100,
        invincibleTime = 0,
        maxInvincibleTime = 0.6,
        level = 1,
        experience = 0,
        maxExperience = 100,
        expModifier = 1.0,                 -- 경험치 획득 배율
        hasMagnet = false,                 -- 자석 특성 플래그
        magnetRange = 100,                 -- 자석 범위
        upgradeLevels = { 0, 0, 0, 0, 0, 0 }, -- 개별 특성별 선택 횟수 (최대 3회)
        damage = 10,                       -- 구체 기본 데미지
        regenRate = 0,                     -- 체력 재생률 (%)
        regenTimer = 0,                    -- 체력 재생 타이머
        regenDelay = 3.0,                  -- 체력 재생 시작까지의 대기 시간
        selectedSkill = skillIndex,        -- 선택한 스킬 인덱스
        skillLevels = skillLevels          -- 5개 스킬 레벨 (각 스킬 최대 5레벨)
    }
end

-- 플레이어 위치 및 타이머 상태 업데이트
function Player.update(game, dt)
    local player = game.player
    if not player then return end

    -- 무적 시간 감소
    if player.invincibleTime > 0 then
        player.invincibleTime = player.invincibleTime - dt
    end

    -- 체력 재생 로직
    if player.regenRate > 0 then
        player.regenTimer = player.regenTimer + dt

        if player.regenTimer >= player.regenDelay then
            -- 체력 재생
            local regenAmount = player.maxHealth * (player.regenRate / 100) * dt
            player.health = math.min(player.health + regenAmount, player.maxHealth)
        end
    end

    -- 플레이어 이동 처리
    local speed = player.speed * dt
    local dx = 0
    local dy = 0

    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
        dy = dy - 1
    end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
        dy = dy + 1
    end
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
        dx = dx - 1
    end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
        dx = dx + 1
    end

    -- 대각선 이동 시 속도 정규화
    if dx ~= 0 and dy ~= 0 then
        local length = math.sqrt(dx * dx + dy * dy)
        dx = dx / length
        dy = dy / length
    end

    player.x = player.x + dx * speed
    player.y = player.y + dy * speed

    -- 월드 경계 제한
    player.x = math.max(0, math.min(game.world.width - player.width, player.x))
    player.y = math.max(0, math.min(game.world.height - player.height, player.y))
end

-- 플레이어 본체 렌더링
function Player.draw(game)
    local player = game.player
    if not player then return end

    -- 무적 시간 중에는 깜빡임 효과
    if player.invincibleTime > 0 then
        -- 무적 시간(invincibleTime)과 깜빡임 주기를 완전히 동기화
        local blink = math.floor(player.invincibleTime * 20) % 2 == 0
        if blink then
            love.graphics.setColor(0.2, 0.6, 1.0, 0.4)
        else
            love.graphics.setColor(0.2, 0.6, 1.0, 0.9)
        end
    else
        love.graphics.setColor(0.2, 0.6, 1.0)
    end

    love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
end

-- 플레이어 머리 위의 체력/경험치바 렌더링
function Player.drawUI(game)
    local player = game.player
    if not player then return end

    local barWidth = 40
    local barHeight = 6
    local barX = player.x - (barWidth - player.width) / 2
    local healthBarY = player.y - 20
    local expBarY = player.y - 12

    -- 체력바 배경
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", barX, healthBarY, barWidth, barHeight)

    -- 체력바 (빨간색)
    local healthRatio = player.health / player.maxHealth
    love.graphics.setColor(1.0, 0.3, 0.3)
    love.graphics.rectangle("fill", barX, healthBarY, barWidth * healthRatio, barHeight)

    -- 체력바 테두리
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("line", barX, healthBarY, barWidth, barHeight)

    -- 경험치바 배경 (흰색)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", barX, expBarY, barWidth, barHeight)

    -- 경험치바 (하늘색)
    local expRatio = player.experience / player.maxExperience
    love.graphics.setColor(0.3, 0.8, 1.0)
    love.graphics.rectangle("fill", barX, expBarY, barWidth * expRatio, barHeight)

    -- 경험치바 테두리
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("line", barX, expBarY, barWidth, barHeight)
end

return Player
