-- ============================================================================
-- spawner.lua — 적 스폰, 이동 AI, 피격 충돌 감지 및 처리 모듈
-- ============================================================================

local Collision = require("combat.collision")
local Enemy = {}

-- 새로운 적 스폰
function Enemy.spawn(game)
    local player = game.player
    if not player then return end

    local enemy = {
        x = math.random(0, game.world.width),
        y = math.random(0, game.world.height),
        width = 24,
        height = 24,
        speed = 80 + math.random(0, 40),
        health = 30,
        velX = 0,
        velY = 0
    }

    -- 플레이어와 너무 가까운 곳에는 스폰하지 않음
    local dx = enemy.x - player.x
    local dy = enemy.y - player.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 200 then
        table.insert(game.enemies, enemy)
    end
end

-- 적들의 위치 이동 및 모든 무기 스킬과의 피격 판정 처리
function Enemy.update(game, dt)
    local player = game.player
    if not player then return end

    -- 간단한 적 스폰 (매 2초마다)
    if math.floor(game.time) % 2 == 0 and #game.enemies < 10 then
        Enemy.spawn(game)
    end

    -- 순환 의존성(Circular Dependency) 방지를 위해 필요할 때 로컬에 로드
    local Exp = require("progression.exp")

    -- 적 이동 및 충돌
    for i = #game.enemies, 1, -1 do
        local enemy = game.enemies[i]
        
        -- 플레이어 추적 (부드러운 방향 변경)
        local dx = player.x - enemy.x
        local dy = player.y - enemy.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist > 0 then
            local targetVelX = (dx / dist) * enemy.speed
            local targetVelY = (dy / dist) * enemy.speed

            -- 방향 부드럽게 변경 (lerp)
            local turnSpeed = 3.0
            enemy.velX = enemy.velX + (targetVelX - enemy.velX) * turnSpeed * dt
            enemy.velY = enemy.velY + (targetVelY - enemy.velY) * turnSpeed * dt

            enemy.x = enemy.x + enemy.velX * dt
            enemy.y = enemy.y + enemy.velY * dt
        end

        -- 플레이어와 충돌 (피격 판정 처리, 겹침 해소는 생략하여 겹칠 수 있도록 함)
        if Collision.check(enemy, player) then
            if player.invincibleTime <= 0 then
                player.health = player.health - 1
                player.invincibleTime = player.maxInvincibleTime
                -- 체력 재생 타이머 리셋
                player.regenTimer = 0
                if player.health <= 0 then
                    game.running = false
                    game.state = "gameover"
                end
            end
        end

        -- 구체 충돌 (Orbiting Orb)
        local enemyRemoved = false
        for _, orb in ipairs(game.orbs) do
            local orbRect = { x = orb.x, y = orb.y, width = orb.size, height = orb.size }
            if Collision.check(enemy, orbRect) then
                enemy.health = enemy.health - orb.damage
                if enemy.health <= 0 then
                    game.score = game.score + 10
                    Exp.spawn(game, enemy.x + enemy.width / 2, enemy.y + enemy.height / 2)
                    table.remove(game.enemies, i)
                    enemyRemoved = true
                    break
                end
            end
        end

        -- 벼락 충돌 (Thunder)
        if not enemyRemoved then
            for _, thunder in ipairs(game.thunders) do
                local thunderRect = {
                    x = thunder.x - thunder.size / 2,
                    y = thunder.y - thunder.size / 2,
                    width = thunder.size,
                    height = thunder.size
                }
                if Collision.check(enemy, thunderRect) then
                    enemy.health = enemy.health - thunder.damage
                    if enemy.health <= 0 then
                        game.score = game.score + 10
                        Exp.spawn(game, enemy.x + enemy.width / 2, enemy.y + enemy.height / 2)
                        table.remove(game.enemies, i)
                        enemyRemoved = true
                        break
                    end
                end
            end
        end

        -- 칼날 충돌 (Blade)
        if not enemyRemoved then
            for _, blade in ipairs(game.blades) do
                local bladeRect = {
                    x = blade.x - blade.size / 2,
                    y = blade.y - blade.size / 2,
                    width = blade.size,
                    height = blade.size
                }
                if Collision.check(enemy, bladeRect) then
                    enemy.health = enemy.health - blade.damage
                    if enemy.health <= 0 then
                        game.score = game.score + 10
                        Exp.spawn(game, enemy.x + enemy.width / 2, enemy.y + enemy.height / 2)
                        table.remove(game.enemies, i)
                        enemyRemoved = true
                        break
                    end
                end
            end
        end

        -- 총알 충돌 (Bullet)
        if not enemyRemoved then
            for _, bullet in ipairs(game.bullets) do
                local bulletRect = {
                    x = bullet.x - bullet.size / 2,
                    y = bullet.y - bullet.size / 2,
                    width = bullet.size,
                    height = bullet.size
                }
                
                -- 이미 해당 적을 타격했는지 중복 검사 (다중 피격 방지) 및 관통 처리를 위한 제거 마크
                if not bullet.toRemove and not bullet.hitEnemies[enemy] and Collision.check(enemy, bulletRect) then
                    bullet.hitEnemies[enemy] = true
                    enemy.health = enemy.health - bullet.damage
                    
                    if not bullet.pierce then
                        bullet.toRemove = true
                    end
                    
                    if enemy.health <= 0 then
                        game.score = game.score + 10
                        Exp.spawn(game, enemy.x + enemy.width / 2, enemy.y + enemy.height / 2)
                        table.remove(game.enemies, i)
                        enemyRemoved = true
                        break
                    end
                end
            end
        end
    end
end

-- 적들의 렌더링
function Enemy.draw(game)
    love.graphics.setColor(1.0, 0.3, 0.3)
    for _, enemy in ipairs(game.enemies) do
        love.graphics.rectangle("fill", enemy.x, enemy.y, enemy.width, enemy.height)
    end
end

return Enemy
