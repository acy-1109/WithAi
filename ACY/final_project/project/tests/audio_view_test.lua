-- audio_view_test.lua
-- AudioView(프로시저럴 SFX 생성, 이벤트 매핑, Weaver/보스 레이저 전이, 디바운스, 헤드리스 가드) 테스트.

package.path = ((arg[0] or ""):match("(.*/)") or "./") .. "?.lua;" .. package.path
local h = require("helper")
local app = arg[1] or "src"
h.setup(app)

local AudioView = require("AudioView")
local GameView = require("GameView")
local GameModel = require("GameModel")

local function makeFakeAudio()
  local played = {}
  local soundDataCount = 0
  local sourceCount = 0

  local sound = {
    newSoundData = function(samples, rate, bits, ch)
      soundDataCount = soundDataCount + 1
      local buf = {
        samples = samples,
        rate = rate,
        bits = bits,
        ch = ch,
        minVal = 0,
        maxVal = 0,
        setSample = function(self, idx, val)
          if val < self.minVal then self.minVal = val end
          if val > self.maxVal then self.maxVal = val end
        end,
      }
      return buf
    end,
  }

  local function makeSource(data, mode, id)
    sourceCount = sourceCount + 1
    local sid = id or sourceCount
    local src = {
      id = sid,
      data = data,
      mode = mode,
      volume = 1,
      setVolume = function(self, v)
        self.volume = v
      end,
      stop = function() end,
      play = function(self)
        played[#played + 1] = {
          id = self.id,
          samples = self.data.samples,
          volume = self.volume,
        }
      end,
      clone = function(self)
        return makeSource(self.data, self.mode)
      end,
    }
    return src
  end

  local audio = {
    newSource = function(data, mode)
      return makeSource(data, mode)
    end,
  }

  return {
    audio = audio,
    sound = sound,
    played = played,
    getCounts = function()
      return soundDataCount, sourceCount
    end,
  }
end

h.test("AudioView: audio/sound 가 nil 이면 헤드리스 안전 모드로 no-op 동작한다", function()
  local av = AudioView()
  av:onEvent({ type = "fire" })
  av:onEvent({ type = "enemy_destroyed" })
  av:update(0.016, { enemies = {}, boss = nil })
  return av.enabled == false and av:play("fire") == false
end)

h.test("AudioView: 초기화 시 SoundData 를 생성하고 주요 이벤트마다 SFX 를 재생한다", function()
  local fake = makeFakeAudio()
  local av = AudioView({ audio = fake.audio, sound = fake.sound })
  local sdCount, srcCount = fake.getCounts()

  local events = {
    "fire",
    "missile_fired",
    "enemy_destroyed",
    "player_hit",
    "shield_broken",
    "emp_detonated",
    "item_collected",
    "boss_appeared",
    "boss_hit",
    "boss_turret_destroyed",
    "boss_enraged",
    "boss_destroyed",
    "formation_cleared",
    "achievement_unlocked",
    "game_over",
  }

  for i = 1, #events do
    av:onEvent({ type = events[i] })
  end

  return av.enabled == true
    and sdCount >= 15
    and srcCount >= sdCount
    and #fake.played == #events
end)

h.test("AudioView: Weaver 및 Boss 의 레이저 차징/발사 상태 전이 시 1회씩만 재생한다", function()
  local fake = makeFakeAudio()
  local av = AudioView({ audio = fake.audio, sound = fake.sound })

  local weaver = { alive = true, kind = "weaver", aiState = "wait" }
  local boss = { alive = true, aiState = "patrol" }
  local game = { enemies = { weaver }, boss = boss }

  av:update(0.016, game)
  local c0 = #fake.played

  weaver.aiState = "charge"
  av:update(0.20, game)
  av:update(0.20, game) -- 같은 상태 유지 시 중복 재생 안 됨
  local c1 = #fake.played

  weaver.aiState = "laser"
  av:update(0.20, game)
  local c2 = #fake.played

  boss.aiState = "laser_charge"
  av:update(0.20, game)
  local c3 = #fake.played

  boss.aiState = "laser"
  av:update(0.20, game)
  local c4 = #fake.played

  return c0 == 0 and c1 == 1 and c2 == 2 and c3 == 3 and c4 == 4
end)

h.test("AudioView: 동일 프레임 다발 이벤트는 디바운스되고 쿨다운 경과 후 다시 재생된다", function()
  local fake = makeFakeAudio()
  local av = AudioView({ audio = fake.audio, sound = fake.sound })

  av:onEvent({ type = "enemy_destroyed" })
  av:onEvent({ type = "enemy_destroyed" })
  av:onEvent({ type = "enemy_destroyed" })
  local firstCount = #fake.played

  av:update(0.10, nil)
  av:onEvent({ type = "enemy_destroyed" })
  local afterCooldown = #fake.played

  return firstCount == 1 and afterCooldown == 2
end)

h.test("GameView: AudioView 연동 후에도 update(dt, game)/onEvent 가 GameModel 을 변경하지 않는다", function()
  local fake = makeFakeAudio()
  local game = GameModel({ width = 600, height = 800, seed = 42 })
  local view = GameView({ width = 600, height = 800, audio = fake.audio, sound = fake.sound })

  local before = h.snapshot(game)
  view:onEvent({ type = "fire" })
  view:update(0.016, game)
  local after = h.snapshot(game)

  return h.same(before, after) and #fake.played == 1
end)

h.finish()
