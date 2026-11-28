-- FormationPhase.lua
-- 진행 단계(State) ①: 편대전. 편대를 전멸시키면 새 편대가 나오고, 보스 등장 웨이브(5, 10, 15, 20...)를 전멸시키면 보스전으로 넘어간다.
-- 단계마다 다른 규칙만 여기 둔다. 모든 단계에 공통인 규칙(이동·발사·충돌)은 GameModel 에 남는다.
--
-- 단계 인터페이스 (GameModel 이 호출):
--   enter(game)              단계에 들어올 때 1회
--   update(game, dt)         매 스텝, 편대 이동·적 발사 뒤
--   resolveCollisions(game)  매 스텝, 공통 충돌 판정 뒤
--   afterStep(game)          매 스텝 끝

local class = require("class")
local BossPhase = require("BossPhase")

local FormationPhase = class()

local FIRST_BOSS_WAVE = 5
local BOSS_WAVE_INTERVAL = 5

local function isBossWave(wave)
  return wave >= FIRST_BOSS_WAVE and (wave - FIRST_BOSS_WAVE) % BOSS_WAVE_INTERVAL == 0
end

FormationPhase.name = "formation"

function FormationPhase:enter(game) end

function FormationPhase:update(game, dt) end

function FormationPhase:resolveCollisions(game) end

function FormationPhase:afterStep(game)
  for _, e in ipairs(game.enemies) do
    if e.alive then
      return
    end
  end
  game.enemies = {}
  game:_emit({ type = "formation_cleared" })
  if isBossWave(game.wave or 1) then
    game:changePhase(BossPhase())
    return
  end
  game:spawnFormation()
end

return FormationPhase
