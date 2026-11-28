-- item_growth_test.lua
-- TANK 타격 횟수 규칙, 보스 처치 연동 적 HP 스케일링·확정 교차 드랍,
-- attack_up / speed_up / triple_shot 아이템 동작 및 8% 4종 드랍 헤드리스 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local GameModel = require("GameModel")
local ItemModel = require("ItemModel")
local BulletModel = require("BulletModel")
local EnemyModel = require("EnemyModel")
local EnemyView = require("EnemyView")
local EffectsView = require("EffectsView")

local function collectItem(game, kind)
  game.items[#game.items + 1] = ItemModel(kind, game.player.x + 4, game.player.y)
  game:update(1 / 60, { move = 0, fire = false })
end

h.test("TANK: 공격력 3 상태에서도 1타격당 1씩 감소해 3번 맞아야 파괴된다", function()
  local wavesText = "wave 1\nenemy tank 100 100\n"
  local g = GameModel({ width = 600, height = 800, seed = 1, wavesText = wavesText })
  collectItem(g, "attack_up")
  collectItem(g, "attack_up")
  if g.playerDamage ~= 3 then
    return false
  end

  local tank = g.enemies[1]
  -- 1발째 (damage=3) -> hp 2로 생존
  g.bullets[1] = BulletModel(tank.x + 4, tank.y + 4, 0, 0, 4, 12, "player", { damage = g.playerDamage })
  g:_resolveCollisions()
  if not tank.alive or tank.hp ~= 2 then
    return false
  end

  -- 2발째 (damage=3) -> hp 1로 생존
  g.bullets[1] = BulletModel(tank.x + 4, tank.y + 4, 0, 0, 4, 12, "player", { damage = g.playerDamage })
  g:_resolveCollisions()
  if not tank.alive or tank.hp ~= 1 then
    return false
  end

  -- 3발째 (damage=3) -> 파괴
  g.bullets[1] = BulletModel(tank.x + 4, tank.y + 4, 0, 0, 4, 12, "player", { damage = g.playerDamage })
  g:_resolveCollisions()
  return tank.alive == false and tank.hp == 0
end)

h.test("보스 처치: 매 회차 attack_up 확정 드랍 및 이후 일반 적 HP가 1 + bossDefeatedCount 로 증가한다", function()
  local wavesText = "wave 1\nenemy grunt 100 100\nenemy tank 200 100\n"
  local g = GameModel({ width = 600, height = 800, seed = 1, wavesText = wavesText })

  -- 초기 일반 적 HP = 1, tank HP = 3
  if g.enemies[1].hp ~= 1 or g.enemies[2].hp ~= 3 then
    return false
  end

  -- 5웨이브 클리어 -> 1차 보스 등장
  g.wave = 5
  for _, e in ipairs(g.enemies) do
    e.alive = false
  end
  g:update(1 / 60, { move = 0, fire = false })
  if g.phase.name ~= "boss" or not g.boss then
    return false
  end

  -- 1차 보스 격파 -> attack_up 확정 드랍
  local boss1 = g.boss
  local bx1, by1 = boss1:centerX(), boss1:centerY()
  boss1.hp = 1
  g.bullets[#g.bullets + 1] = BulletModel(bx1, by1, 0, 0, 4, 12, "player")
  g:update(1 / 60, { move = 0, fire = false })

  local okBoss1Drop = (#g.items == 1 and g.items[1].kind == "attack_up" and math.abs((g.items[1].x + g.items[1].w * 0.5) - bx1) < 5)
  local okWaveAfter1 = (g.bossDefeatedCount == 1 and g.enemies[1].hp == 2 and g.enemies[2].hp == 3)
  if not (okBoss1Drop and okWaveAfter1) then
    return false
  end

  -- 2차 보스 격파 -> 이번에도 attack_up 확정 드랍
  g.items = {}
  g.wave = 15
  for _, e in ipairs(g.enemies) do
    e.alive = false
  end
  g:update(1 / 60, { move = 0, fire = false })
  local boss2 = g.boss
  if not boss2 then
    return false
  end
  boss2.hp = 1
  g.bullets[#g.bullets + 1] = BulletModel(boss2:centerX(), boss2:centerY(), 0, 0, 4, 12, "player")
  g:update(1 / 60, { move = 0, fire = false })

  local okBoss2Drop = (#g.items == 1 and g.items[1].kind == "attack_up")
  local okWaveAfter2 = (g.bossDefeatedCount == 2 and g.enemies[1].hp == 3 and g.enemies[2].hp == 3)
  return okBoss2Drop and okWaveAfter2
end)

h.test("speed_up: 쿨다운이 0.85배씩 감소하며 0.10초 미만으로 내려가지 않는다", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  collectItem(g, "speed_up")
  if math.abs(g.fireCooldown - (0.25 * 0.85)) > 1e-6 then
    return false
  end

  for _ = 1, 20 do
    collectItem(g, "speed_up")
  end
  return math.abs(g.fireCooldown - 0.10) < 1e-6 and g.fireCooldown >= 0.10
end)

h.test("attack_up: 공격력이 영구 +1 증가하고 일반 적·보스 피해에 반영된다", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  collectItem(g, "attack_up")
  if g.playerDamage ~= 2 then
    return false
  end

  -- 발사된 총알이 damage=2를 가지며 HP 2인 적을 1발에 처치
  local target = g.enemies[1]
  target.hp = 2
  g:update(1 / 60, { move = 0, fire = true })
  local firedBullet = g.bullets[#g.bullets]
  if not firedBullet or firedBullet.damage ~= 2 then
    return false
  end
  firedBullet.x = target.x + 2
  firedBullet.y = target.y + 2
  firedBullet.vx = 0
  firedBullet.vy = 0
  g:update(1 / 60, { move = 0, fire = false })
  return target.alive == false
end)

h.test("triple_shot: 6초 활성화, 재획득 시 6초 초기화, Sniper식 3갈래 분열, 6초 후 복귀", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  -- 적이 맞지 않도록 화면 우측 구석에 1기만 두어 웨이브 전멸 리셋을 방지
  g.enemies = { g.enemies[1] }
  g.enemies[1].x = g.width - 50
  g.enemies[1].y = 20
  g.enemyFireTimer = 999

  collectItem(g, "triple_shot")
  if math.abs(g.tripleShotTimer - 6.0) > 1e-6 then
    return false
  end

  -- 발사 후 0.45초 경과 시 3갈래로 분열하고 damage 계승
  collectItem(g, "attack_up")
  g:update(1 / 60, { move = 0, fire = true })
  if #g.bullets ~= 1 then
    return false
  end
  for _ = 1, 30 do
    g:update(1 / 60, { move = 0, fire = false })
  end
  if #g.bullets ~= 3 then
    return false
  end
  for i = 1, 3 do
    if g.bullets[i].damage ~= 2 then
      return false
    end
  end

  -- 재획득 시 남은 시간에 합산하지 않고 6초로 초기화
  g.tripleShotTimer = 2.0
  collectItem(g, "triple_shot")
  if g.tripleShotTimer > 6.0 or g.tripleShotTimer < 5.9 then
    return false
  end

  -- 6초 이상 경과 후에는 일반 사격(분열 안 함)으로 복귀
  g.bullets = {}
  for _ = 1, 370 do
    g:update(1 / 60, { move = 0, fire = false })
  end
  if g.tripleShotTimer ~= 0 then
    return false
  end
  g:update(1 / 60, { move = 0, fire = true })
  for _ = 1, 35 do
    g:update(1 / 60, { move = 0, fire = false })
  end
  return #g.bullets == 1
end)

h.test("일반 드랍: 8% 확률로 life, speed_up, triple_shot 만 드랍하고 attack_up 은 나오지 않는다", function()
  local expected = { "life", "speed_up", "triple_shot" }
  for idx = 1, 3 do
    local g = GameModel({ width = 600, height = 800, seed = 1 })
    local target = g.enemies[1]
    target.hp = 1
    g.rng.nextFloat = function()
      return 0.05
    end
    local passedMax
    g.rng.range = function(_self, n)
      passedMax = n
      return idx
    end
    g.bullets[1] = BulletModel(target.x + 2, target.y + 2, 0, 0, 4, 12, "player")
    g:update(1 / 60, { move = 0, fire = false })
    if passedMax ~= 3 or #g.items ~= 1 or g.items[1].kind ~= expected[idx] or g.items[1].kind == "attack_up" then
      return false
    end
  end
  return true
end)

h.test("EnemyView: Tank 는 처음부터 흰색 계열 3칸 분리 바, 일반 다중 HP 적은 녹색 연속 바로 구분해 그린다", function()
  local tank = EnemyModel.create("tank", 100, 100)
  local grunt = EnemyModel.create("grunt", 200, 100)
  grunt.hp = 2
  grunt.maxHp = 2

  -- Tank: 본체는 벡터 도형, HP 바 3칸 = rectangle 3회, 3칸은 서로 간격(gap)이 있고 흰색 계열 사용
  local gfxTank = h.fakeGfx()
  EnemyView.draw(gfxTank, { tank })
  if h.count(gfxTank, "rectangle") ~= 3 then
    return false
  end
  local segXs = {}
  local sawWhiteSeg = false
  for _, c in ipairs(gfxTank.calls) do
    if c.name == "setColor" and c.args[1] >= 0.9 and c.args[2] >= 0.9 and c.args[3] >= 0.9 then
      sawWhiteSeg = true
    end
    if c.name == "rectangle" then
      segXs[#segXs + 1] = { x = c.args[2], w = c.args[4] }
    end
  end
  if not sawWhiteSeg or #segXs ~= 3 then
    return false
  end
  -- 각 칸 사이가 띄워져 있는지 확인
  if segXs[2].x <= segXs[1].x + segXs[1].w or segXs[3].x <= segXs[2].x + segXs[2].w then
    return false
  end

  -- 일반 적 (HP 2): 본체는 벡터 도형, HP 바 배경(1) + 녹색바(1) = rectangle 2회, 녹색 계열 사용
  local gfxGrunt = h.fakeGfx()
  EnemyView.draw(gfxGrunt, { grunt })
  if h.count(gfxGrunt, "rectangle") ~= 2 then
    return false
  end
  local sawGreenBar = false
  for _, c in ipairs(gfxGrunt.calls) do
    if c.name == "setColor" and c.args[2] > 0.9 and c.args[1] < 0.4 then
      sawGreenBar = true
    end
  end
  return sawGreenBar
end)

h.test("triple_shot 분열 파티클: 플레이어 탄 분열 시 플레이어 탄환 색(노랑)을, 적 탄 분열 시 보라색을 사용한다", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.enemies = { g.enemies[1] }
  g.enemies[1].x = g.width - 50
  g.enemies[1].y = 20
  g.enemyFireTimer = 999

  collectItem(g, "triple_shot")
  g:drainEvents()
  g:update(1 / 60, { move = 0, fire = true })

  local fx = EffectsView(function() return 0.5 end)
  local splitEv
  for _ = 1, 30 do
    g:update(1 / 60, { move = 0, fire = false })
    local evts = g:drainEvents()
    for i = 1, #evts do
      if evts[i].type == "bullet_split" then
        splitEv = evts[i]
        fx:onEvent(evts[i])
      end
    end
  end

  if not splitEv or splitEv.kind ~= "player" or #fx.particles ~= 4 then
    return false
  end
  local pc = fx.particles[1].color
  local isPlayerColor = (math.abs(pc[1] - 1.0) < 1e-6 and math.abs(pc[2] - 0.92) < 1e-6 and math.abs(pc[3] - 0.25) < 1e-6)

  local fxEnemy = EffectsView(function() return 0.5 end)
  fxEnemy:onEvent({ type = "bullet_split", x = 100, y = 100, kind = "enemy_sniper" })
  local ec = fxEnemy.particles[1].color
  local isEnemyColor = (math.abs(ec[1] - 0.85) < 1e-6 and math.abs(ec[2] - 0.5) < 1e-6 and math.abs(ec[3] - 1.0) < 1e-6)

  return isPlayerColor and isEnemyColor
end)

h.finish()
