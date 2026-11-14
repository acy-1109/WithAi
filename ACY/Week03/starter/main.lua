-- main.lua
-- 3주차 겔러그 모델 분리 버전: Love2D 입력/연출/렌더링만 담당한다.
-- 게임 상태와 규칙은 GameModel / PlayerModel / EnemyModel / BossModel / BulletModel 에 있다.

local GameModel = require("GameModel")

local game
local particles = {}
local screenShake = 0
local flash = 0

local function spawnExplosion(x, y)
  for _ = 1, 12 do
    local angle = math.random() * math.pi * 2
    local speed = 40 + math.random() * 120
    particles[#particles + 1] = {
      x = x,
      y = y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = 0.5,
    }
  end
  flash = 0.06
end

local function resetEffects()
  particles = {}
  screenShake = 0
  flash = 0
end

local function readInput()
  local move = 0
  if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
    move = move - 1
  end
  if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
    move = move + 1
  end

  return {
    move = move,
    fire = love.keyboard.isDown("space"),
    homing = love.keyboard.isDown("f"),
  }
end

local function handleEvents(events)
  for _, ev in ipairs(events) do
    if ev.type == "enemy_destroyed" or ev.type == "boss_destroyed" then
      spawnExplosion(ev.x, ev.y)
    elseif ev.type == "player_hit" then
      screenShake = 0.3
    end
  end
end

local function updateEffects(dt)
  if screenShake > 0 then
    screenShake = math.max(0, screenShake - dt)
  end
  if flash > 0 then
    flash = math.max(0, flash - dt)
  end

  for i = #particles, 1, -1 do
    local p = particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(particles, i)
    end
  end
end

function love.load()
  love.graphics.setBackgroundColor(0.02, 0.02, 0.06)
  math.randomseed(os.time())
  game = GameModel({ width = 600, height = 800, seed = os.time() })
  resetEffects()
end

function love.update(dt)
  local input = readInput()
  game:update(dt, input)
  handleEvents(game:drainEvents())
  updateEffects(dt)
end

function love.draw()
  local ox, oy = 0, 0
  if screenShake > 0 then
    ox = (math.random() - 0.5) * 10
    oy = (math.random() - 0.5) * 10
  end

  love.graphics.push()
  love.graphics.translate(ox, oy)

  if flash > 0 then
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.rectangle("fill", 0, 0, game.width, game.height)
  end

  -- 플레이어 (하늘색)
  local player = game.player
  love.graphics.setColor(0.4, 0.9, 1)
  love.graphics.rectangle("fill", player.x, player.y, player.w, player.h)

  -- 파티클
  love.graphics.setColor(1, 0.8, 0.2)
  for _, p in ipairs(particles) do
    love.graphics.rectangle("fill", p.x, p.y, 3, 3)
  end

  -- 플레이어 총알
  for _, b in ipairs(game.bullets) do
    if b.homing then
      love.graphics.setColor(0.2, 1.0, 0.5)
    else
      love.graphics.setColor(1, 1, 0.3)
    end
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
  end

  -- 적 편대 (빨간색)
  love.graphics.setColor(1, 0.4, 0.4)
  for _, e in ipairs(game.enemies) do
    if e.alive then
      love.graphics.rectangle("fill", e.x, e.y, e.w, e.h)
    end
  end

  -- 보스 렌더링
  local boss = game.boss
  if boss and boss.alive then
    love.graphics.setColor(0.9, 0.3, 0.9)
    love.graphics.rectangle("fill", boss.x, boss.y, boss.w, boss.h)

    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 100, 48, 400, 10)
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.rectangle("fill", 100, 48, 400 * (boss.hp / boss.maxhp), 10)
  end

  -- 적 총알
  love.graphics.setColor(1, 0.6, 0.2)
  for _, b in ipairs(game.enemyBullets) do
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
  end

  love.graphics.pop()

  -- HUD
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("SCORE  " .. game.score, 15, 12)
  love.graphics.printf("LIVES " .. game.lives, 0, 12, game.width - 15, "right")

  love.graphics.setColor(0.3, 1.0, 0.6)
  for i = 1, game.missiles do
    love.graphics.rectangle("fill", game.width - 15 - (i * 18), 32, 14, 8)
  end

  if game.state == "gameover" then
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, game.width, game.height)

    if game.won then
      love.graphics.setColor(0.3, 1, 0.4)
      love.graphics.printf("YOU WIN!", 0, 340, game.width, "center")
    else
      love.graphics.setColor(1, 0.3, 0.3)
      love.graphics.printf("GAME OVER", 0, 340, game.width, "center")
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Final Score: " .. game.score, 0, 385, game.width, "center")
    love.graphics.printf("Press R to Restart", 0, 420, game.width, "center")
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "r" and game.state == "gameover" then
    game:reset()
    resetEffects()
  end
end
