-- ============================================================================
-- player.lua — 플레이어 초기화, 업데이트 및 렌더링 모듈
-- ============================================================================

local Player = {}

-- 플레이어 데이터 초기화
function Player.init(skillIndex, metaUpgrades)
    -- 메타 스킬/특성 강화 데이터 불러오기 (없으면 0레벨 디폴트)
    metaUpgrades = metaUpgrades or {
        skills = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        upgrades = { 0, 0, 0, 0, 0, 0, 0, 0 }
    }
    
    local skillLevels = {}
    for i = 1, 10 do
        skillLevels[i] = metaUpgrades.skills[i] or 0
    end
    -- 시작 스킬로 선택한 항목은 레벨 1 추가
    if skillIndex and skillIndex >= 1 and skillIndex <= 10 then
        skillLevels[skillIndex] = skillLevels[skillIndex] + 1
    end

    local upgradeLevels = {}
    for i = 1, 8 do
        upgradeLevels[i] = metaUpgrades.upgrades[i] or 0
    end

    -- 영구 강화 스탯 적용
    -- 1번 Magnet
    local magnetRange = 100 * (1.03 ^ upgradeLevels[1])
    -- 2번 Health Boost
    local maxHp = 100 + upgradeLevels[2] * 20
    -- 3번 Speed Boost
    local speed = 200 * (1.05 ^ upgradeLevels[3])
    -- 4번 Damage Boost
    local damage = 10 * (1.1 ^ upgradeLevels[4])
    -- 5번 Health Regen
    local regenRate = upgradeLevels[5] * 5
    -- 6번 EXP Boost
    local expModifier = 1.0 + upgradeLevels[6] * 0.25

    local stats = {
        x = 400,
        y = 300,
        width = 32,
        height = 32,
        speed = speed,
        health = maxHp,
        maxHealth = maxHp,
        invincibleTime = 0,
        maxInvincibleTime = 0.6,
        controlsInvertedTimer = 0,       -- 키보드 반전 디버프 타이머
        level = 1,
        experience = 0,
        maxExperience = 50,
        expModifier = expModifier,
        hasMagnet = (upgradeLevels[1] > 0),
        magnetRange = magnetRange,
        upgradeLevels = upgradeLevels,     -- 영구 특성 레벨 반영
        damage = damage,
        regenRate = regenRate,             -- 영구 체력 재생률 반영
        alwaysRegenTimer = 0,              -- 1초 주기 항상 체력 재생 타이머
        selectedSkill = skillIndex,        -- 선택한 스킬 인덱스
        skillLevels = skillLevels,          -- 영구 스킬 레벨 반영
        
        -- 에너지 실드 특성 상태 데이터
        shieldActive = (upgradeLevels[8] > 0),
        shieldTimer = 0,
        shieldBreakVisualTimer = 0,
        shieldRestoreVisualTimer = 0
    }

    local proxy = {}
    setmetatable(proxy, {
        __index = function(t, k)
            return stats[k]
        end,
        __newindex = function(t, k, v)
            if k == "health" then
                local current = stats.health
                if v < current then
                    -- 피해를 입었을 때 실드가 켜져있으면 무조건 무효화 처리
                    if stats.shieldActive then
                        stats.shieldActive = false
                        stats.shieldTimer = 0 -- 실드가 깨졌을 때를 기점으로 쿨타임 시작
                        stats.shieldBreakVisualTimer = 0.5 -- 0.5초 동안 파괴 팽창 이펙트
                        stats.invincibleTime = stats.maxInvincibleTime -- 피격 판정 후 짧은 무적 시간 부여
                        return
                    end
                end
            end
            stats[k] = v
        end,
        __pairs = function(t)
            return pairs(stats)
        end,
        __ipairs = function(t)
            return ipairs(stats)
        end
    })

    return proxy
end

-- 플레이어 위치 및 타이머 상태 업데이트
function Player.update(game, dt)
    local player = game.player
    if not player then return end

    -- 무적 시간 감소
    if player.invincibleTime > 0 then
        player.invincibleTime = player.invincibleTime - dt
    end

    -- 에너지 실드 타이머 및 쿨타임 업데이트
    if player.shieldBreakVisualTimer and player.shieldBreakVisualTimer > 0 then
        player.shieldBreakVisualTimer = player.shieldBreakVisualTimer - dt
    end
    if player.shieldRestoreVisualTimer and player.shieldRestoreVisualTimer > 0 then
        player.shieldRestoreVisualTimer = player.shieldRestoreVisualTimer - dt
    end

    if player.upgradeLevels and player.upgradeLevels[8] and player.upgradeLevels[8] > 0 then
        if not player.shieldActive then
            local level = player.upgradeLevels[8] or 1
            local maxCooldown = 15 - 3 * level -- Level 1 = 12초, Level 2 = 9초, Level 3 = 6초
            player.shieldTimer = (player.shieldTimer or 0) + dt
            if player.shieldTimer >= maxCooldown then
                player.shieldActive = true
                player.shieldTimer = 0
                player.shieldRestoreVisualTimer = 0.4
            end
        end
    end

    -- 체력 재생 로직 (전투 여부와 무관하게 1초마다 회복)
    if player.regenRate > 0 then
        player.alwaysRegenTimer = (player.alwaysRegenTimer or 0) + dt
        if player.alwaysRegenTimer >= 1.0 then
            player.alwaysRegenTimer = player.alwaysRegenTimer - 1.0
            -- regenRate % 만큼 체력 회복 (예: 1레벨 5% 회복)
            local regenAmount = player.maxHealth * (player.regenRate / 100)
            player.health = math.min(player.health + regenAmount, player.maxHealth)
        end
    end

    -- 플레이어 이동 처리
    local speed = player.speed * (player.speedMultiplier or 1.0) * dt
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

    -- 키보드 제어 반전 디버프 타이머 및 키 입력 벡터 반전 처리
    if player.controlsInvertedTimer and player.controlsInvertedTimer > 0 then
        player.controlsInvertedTimer = player.controlsInvertedTimer - dt
        dx = -dx
        dy = -dy
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

    -- 엔진 추진 파티클 생성 및 수명 관리
    player.particles = player.particles or {}
    if dx ~= 0 or dy ~= 0 then
        local moveAngle = math.atan2(dy, dx)
        local emitAngle = moveAngle + math.pi + (math.random() - 0.5) * 0.6
        local speed = 60 + math.random(0, 60)
        table.insert(player.particles, {
            x = player.x + player.width / 2 - dx * (player.width / 2),
            y = player.y + player.height / 2 - dy * (player.height / 2),
            vx = math.cos(emitAngle) * speed,
            vy = math.sin(emitAngle) * speed,
            life = 0.35,
            maxLife = 0.35,
            size = 2 + math.random() * 2
        })
    end

    for i = #player.particles, 1, -1 do
        local p = player.particles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(player.particles, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
    end
end

-- 플레이어 본체 렌더링
function Player.draw(game)
    local player = game.player
    if not player then return end

    local cx = player.x + player.width / 2
    local cy = player.y + player.height / 2
    local r = player.width / 2

    -- 1. 엔진 추진 스파크 파티클 그리기
    player.particles = player.particles or {}
    for _, p in ipairs(player.particles) do
        local alpha = p.life / p.maxLife
        love.graphics.setColor(0.3, 0.7, 1.0, alpha * 0.7)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end

    -- 2. 쉴드 오라 아우라 (은은하게 일렁이는 청록색 정전기 링)
    local shieldPulse = 1 + math.sin(game.time * 6) * 0.05
    love.graphics.setColor(0.2, 0.8, 1.0, 0.12)
    love.graphics.circle("fill", cx, cy, r * 1.6 * shieldPulse)
    
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(0.3, 0.8, 1.0, 0.45 + math.sin(game.time * 12) * 0.05)
    love.graphics.circle("line", cx, cy, r * 1.6 * shieldPulse)

    -- 에너지 실드 패시브 특성 (블로킹 실드 비주얼) 그리기
    if player.shieldActive then
        local blockPulse = 1 + math.sin(game.time * 8) * 0.04
        -- 복합 색상 네온 아웃라인 (황금빛/오렌지빛 일렁임)
        love.graphics.setLineWidth(2.0)
        love.graphics.setColor(1.0, 0.75, 0.0, 0.85 + math.sin(game.time * 15) * 0.1) -- Gold
        love.graphics.circle("line", cx, cy, r * 2.0 * blockPulse)
        
        -- 실드 복구 시 순간적인 백색 광원 플래시
        if player.shieldRestoreVisualTimer and player.shieldRestoreVisualTimer > 0 then
            local flashAlpha = (player.shieldRestoreVisualTimer / 0.4) * 0.6
            love.graphics.setColor(1.0, 0.92, 0.6, flashAlpha)
            love.graphics.circle("fill", cx, cy, r * 2.0 * blockPulse)
        else
            love.graphics.setColor(1.0, 0.75, 0.0, 0.13 + math.sin(game.time * 8) * 0.03) -- 투명한 황금빛 채우기
            love.graphics.circle("fill", cx, cy, r * 2.0 * blockPulse)
        end
    elseif player.shieldBreakVisualTimer and player.shieldBreakVisualTimer > 0 then
        -- 실드 파괴 시 폭발적으로 팽창하며 사라지는 주황색 링
        local progress = 1.0 - (player.shieldBreakVisualTimer / 0.5)
        local breakPulse = 1.0 + progress * 0.7
        local alpha = (1.0 - progress) * 0.7
        love.graphics.setLineWidth(3.0 * (1.0 - progress))
        love.graphics.setColor(1.0, 0.4, 0.0, alpha)
        love.graphics.circle("line", cx, cy, r * 2.0 * breakPulse)
    end

    -- 무적(피격) 시 빨간 전자기 스파크/번쩍임 효과
    local blink = false
    if player.invincibleTime > 0 then
        blink = math.floor(player.invincibleTime * 20) % 2 == 0
        
        -- 경고 전자기 스파크 그리기
        love.graphics.setColor(1.0, 0.3, 0.3, 0.8)
        love.graphics.setLineWidth(1)
        for s = 1, 4 do
            local sa = math.random() * 2 * math.pi
            local sd = r * (1.1 + math.random() * 0.4)
            local sx1 = cx + math.cos(sa) * sd
            local sy1 = cy + math.sin(sa) * sd
            local sx2 = sx1 + (math.random() - 0.5) * 8
            local sy2 = sy1 + (math.random() - 0.5) * 8
            love.graphics.line(sx1, sy1, sx2, sy2)
        end
    end

    -- 3. 회전하는 장갑 플레이트 (4개 모듈)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(game.time * 1.5) -- 부드럽게 회전
    
    for k = 1, 4 do
        local angle = (k * math.pi / 2)
        love.graphics.push()
        love.graphics.rotate(angle)
        
        -- 장갑 모듈 색상 (피격 시 붉은색 틴팅)
        if blink then
            love.graphics.setColor(0.9, 0.2, 0.2, 0.9)
        else
            love.graphics.setColor(0.1, 0.15, 0.25, 0.9)
        end
        -- 모듈 채우기
        love.graphics.rectangle("fill", -5, -r - 2, 10, 5, 1, 1)
        
        -- 네온 테두리
        if blink then
            love.graphics.setColor(1.0, 0.4, 0.4, 0.95)
        else
            love.graphics.setColor(0.3, 0.6, 1.0, 0.85)
        end
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", -5, -r - 2, 10, 5, 1, 1)
        
        love.graphics.pop()
    end
    love.graphics.pop()

    -- 4. 마름모 코어 본체
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(-game.time * 2.2) -- 반대 방향 회전
    
    if blink then
        love.graphics.setColor(0.8, 0.1, 0.1, 0.95)
    else
        love.graphics.setColor(0.2, 0.5, 0.85, 0.95)
    end
    -- 마름모 그리기
    love.graphics.polygon("fill", 0, -r * 0.7, r * 0.7, 0, 0, r * 0.7, -r * 0.7, 0)
    
    -- 마름모 테두리
    if blink then
        love.graphics.setColor(1.0, 0.4, 0.4, 0.95)
    else
        love.graphics.setColor(0.5, 0.85, 1.0, 0.95)
    end
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", 0, -r * 0.7, r * 0.7, 0, 0, r * 0.7, -r * 0.7, 0)
    
    love.graphics.pop()

    -- 5. 눈부신 백색 중심부
    if blink then
        love.graphics.setColor(1.0, 0.6, 0.6, 0.95)
    else
        love.graphics.setColor(1.0, 1.0, 1.0, 0.95)
    end
    love.graphics.circle("fill", cx, cy, r * 0.3)
    
    -- 복구
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(1)
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
