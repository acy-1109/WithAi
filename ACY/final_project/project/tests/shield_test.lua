-- shield_test.lua
-- 에너지 실드(shield) 아이템 획득, 중복 방지, 피격 무효화, 무적 시간, 주변 탄환 제거, View 렌더링 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local GameModel = require("GameModel")
local ItemModel = require("ItemModel")
local BulletModel = require("BulletModel")
local ItemView = require("ItemView")
local PlayerView = require("PlayerView")

h.test("shield: 아이템 획득 시 hasShield 활성화 및 이미 보유 중이면 중복 획득 안 됨", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  g.items[1] = ItemModel("shield", g.player.x + 4, g.player.y - 1)
  g:update(0.016, {})
  if not g.player.hasShield or #g.items ~= 0 then
    return false
  end

  -- 이미 실드 보유 중이면 두 번째 실드는 먹어지지 않고 통과
  g.items[1] = ItemModel("shield", g.player.x + 4, g.player.y)
  g:update(0.016, {})
  return g.player.hasShield and #g.items == 1
end)

h.test("shield: 실드 보유 중 피격 시 라이프 감소 없이 실드만 소모되고 주변 120px 탄환 제거", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  local startLives = g.lives
  g.player:activateShield()

  local px = g.player.x + g.player.w * 0.5
  local py = g.player.y + g.player.h * 0.5

  -- 플레이어에 직접 맞는 탄환
  g.enemyBullets[1] = BulletModel(px - 2, py - 2, 0, 0, 4, 12, "enemy")
  -- 반경 120px 이내 탄환 (제거 대상)
  g.enemyBullets[2] = BulletModel(px + 80, py, 0, 0, 4, 12, "enemy")
  -- 반경 120px 바깥 탄환 (유지 대상)
  g.enemyBullets[3] = BulletModel(px - 200, py - 200, 0, 0, 4, 12, "enemy")

  g:update(0.016, {})
  local evts = g:drainEvents()
  local broken = false
  local hit = false
  for _, e in ipairs(evts) do
    if e.type == "shield_broken" then
      broken = true
    elseif e.type == "player_hit" then
      hit = true
    end
  end

  return g.lives == startLives
    and not g.player.hasShield
    and g.player:isInvincible()
    and #g.enemyBullets == 1
    and broken
    and not hit
end)

h.test("shield: 파괴 후 무적 시간(1.5초) 동안 추가 피격이 무시되고 이후에는 정상 피격", function()
  local g = GameModel({ width = 600, height = 800, seed = 1 })
  local startLives = g.lives
  g.player:activateShield()

  local px = g.player.x + g.player.w * 0.5
  local py = g.player.y + g.player.h * 0.5

  -- 1차 피격: 실드 소모
  g.enemyBullets[1] = BulletModel(px - 2, py - 2, 0, 0, 4, 12, "enemy")
  g:update(0.016, {})
  if g.lives ~= startLives or not g.player:isInvincible() then
    return false
  end

  -- 무적 시간 중 2차 피격: 라이프 유지
  g.enemyBullets[1] = BulletModel(px - 2, py - 2, 0, 0, 4, 12, "enemy")
  g:update(0.5, {})
  if g.lives ~= startLives then
    return false
  end

  -- 무적 시간 만료 후 3차 피격: 라이프 감소
  g:update(1.1, {})
  if g.player:isInvincible() then
    return false
  end
  g.enemyBullets[1] = BulletModel(px - 2, py - 2, 0, 0, 4, 12, "enemy")
  g:update(0.016, {})
  return g.lives == startLives - 1
end)

h.test("ItemView / PlayerView: shield 아이템 및 플레이어 실드 보호막 렌더링", function()
  local itemGfx = h.fakeGfx()
  ItemView.draw(itemGfx, { ItemModel.create("shield", 100, 100) })
  if h.count(itemGfx, "circle") ~= 2 or h.count(itemGfx, "polygon") ~= 1 then
    return false
  end

  local g = GameModel({ width = 600, height = 800, seed = 1 })
  local baseGfx = h.fakeGfx()
  PlayerView.draw(baseGfx, g.player)
  local baseCircles = h.count(baseGfx, "circle")

  g.player:activateShield()
  local shieldGfx = h.fakeGfx()
  PlayerView.draw(shieldGfx, g.player)
  local shieldCircles = h.count(shieldGfx, "circle")

  return shieldCircles == baseCircles + 2
end)

h.finish()

