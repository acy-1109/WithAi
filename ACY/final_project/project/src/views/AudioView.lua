-- AudioView.lua
-- 프로시저럴 레트로 아케이드 효과음(SFX) View.
-- Model 이벤트를 구독하고 Weaver/보스 상태 전이를 감지해 사운드를 재생한다.
-- love 를 직접 참조하지 않고 주입받은 audio/sound 인터페이스로만 동작한다(헤드리스 테스트 가능).

local class = require("class")

local AudioView = class()

local SAMPLE_RATE = 44100
local BIT_DEPTH = 16
local CHANNELS = 1
local FADE_TIME = 0.004
local PI2 = math.pi * 2

local min, max, abs, floor = math.min, math.max, math.abs, math.floor
local sin, exp = math.sin, math.exp

--- 결정적 LCG 노이즈 생성기 (초기화 시 1회만 사용, 게임 RNG와 무관)
local function makeNoiseGen()
  local state = 1337
  return function()
    state = (state * 1103515245 + 12345) % 2147483648
    return (state / 1073741824) - 1
  end
end

local function sampleWave(wave, phase, nextNoise)
  if wave == "sine" then
    return sin(PI2 * phase)
  elseif wave == "square" then
    return (phase % 1) < 0.5 and 1 or -1
  elseif wave == "triangle" then
    local p = phase % 1
    return 1 - 4 * abs(p - 0.5)
  elseif wave == "saw" then
    return 2 * (phase % 1) - 1
  elseif wave == "noise" then
    return nextNoise()
  end
  return 0
end

--- 사운드 레시피 테이블
--- notes: { { dur, f0, f1, wave, decay }, ... } 형태 또는 단일 { duration, f0, f1, wave, decay }
local RECIPES = {
  fire = {
    duration = 0.075,
    f0 = 920,
    f1 = 280,
    wave = "square",
    decay = 28,
    volume = 0.22,
    cooldown = 0.04,
    voices = 4,
  },
  missile = {
    duration = 0.16,
    f0 = 260,
    f1 = 760,
    wave = "saw",
    decay = 12,
    volume = 0.28,
    cooldown = 0.06,
    voices = 3,
  },
  explosion = {
    duration = 0.20,
    f0 = 180,
    f1 = 45,
    wave = "noise",
    decay = 14,
    volume = 0.32,
    cooldown = 0.045,
    voices = 4,
  },
  player_hit = {
    duration = 0.28,
    f0 = 220,
    f1 = 55,
    wave = "saw",
    decay = 9,
    volume = 0.42,
    cooldown = 0.12,
    voices = 2,
  },
  shield_broken = {
    duration = 0.24,
    f0 = 1100,
    f1 = 220,
    wave = "triangle",
    decay = 10,
    volume = 0.36,
    cooldown = 0.10,
    voices = 2,
  },
  emp = {
    duration = 0.42,
    f0 = 520,
    f1 = 48,
    wave = "saw",
    decay = 6.5,
    volume = 0.45,
    cooldown = 0.15,
    voices = 2,
  },
  item = {
    notes = {
      { dur = 0.06, f0 = 523.25, f1 = 523.25, wave = "square", decay = 8 },
      { dur = 0.10, f0 = 783.99, f1 = 880.0, wave = "square", decay = 10 },
    },
    volume = 0.30,
    cooldown = 0.05,
    voices = 3,
  },
  boss_warning = {
    notes = {
      { dur = 0.14, f0 = 440, f1 = 330, wave = "square", decay = 5 },
      { dur = 0.14, f0 = 440, f1 = 330, wave = "square", decay = 5 },
      { dur = 0.18, f0 = 554, f1 = 277, wave = "saw", decay = 6 },
    },
    volume = 0.38,
    cooldown = 0.30,
    voices = 2,
  },
  boss_hit = {
    duration = 0.06,
    f0 = 360,
    f1 = 140,
    wave = "triangle",
    decay = 32,
    volume = 0.24,
    cooldown = 0.05,
    voices = 4,
  },
  turret_destroyed = {
    duration = 0.26,
    f0 = 240,
    f1 = 50,
    wave = "noise",
    decay = 10,
    volume = 0.36,
    cooldown = 0.08,
    voices = 2,
  },
  boss_enraged = {
    notes = {
      { dur = 0.10, f0 = 220, f1 = 440, wave = "saw", decay = 6 },
      { dur = 0.22, f0 = 440, f1 = 660, wave = "square", decay = 6 },
    },
    volume = 0.40,
    cooldown = 0.20,
    voices = 2,
  },
  boss_destroyed = {
    duration = 0.60,
    f0 = 160,
    f1 = 32,
    wave = "noise",
    decay = 4.5,
    volume = 0.48,
    cooldown = 0.25,
    voices = 2,
  },
  laser_charge = {
    duration = 0.24,
    f0 = 240,
    f1 = 880,
    wave = "sine",
    decay = 4,
    volume = 0.26,
    cooldown = 0.12,
    voices = 2,
  },
  laser_fire = {
    duration = 0.22,
    f0 = 960,
    f1 = 180,
    wave = "saw",
    decay = 11,
    volume = 0.34,
    cooldown = 0.10,
    voices = 3,
  },
  wave_clear = {
    notes = {
      { dur = 0.07, f0 = 523.25, f1 = 523.25, wave = "square", decay = 8 },
      { dur = 0.07, f0 = 659.25, f1 = 659.25, wave = "square", decay = 8 },
      { dur = 0.14, f0 = 783.99, f1 = 1046.5, wave = "square", decay = 8 },
    },
    volume = 0.32,
    cooldown = 0.20,
    voices = 2,
  },
  achievement = {
    notes = {
      { dur = 0.06, f0 = 659.25, f1 = 659.25, wave = "triangle", decay = 8 },
      { dur = 0.06, f0 = 783.99, f1 = 783.99, wave = "triangle", decay = 8 },
      { dur = 0.14, f0 = 1046.5, f1 = 1046.5, wave = "triangle", decay = 9 },
    },
    volume = 0.30,
    cooldown = 0.20,
    voices = 2,
  },
  game_over = {
    notes = {
      { dur = 0.14, f0 = 392.00, f1 = 349.23, wave = "triangle", decay = 6 },
      { dur = 0.14, f0 = 329.63, f1 = 293.66, wave = "triangle", decay = 6 },
      { dur = 0.28, f0 = 261.63, f1 = 196.00, wave = "saw", decay = 5 },
    },
    volume = 0.38,
    cooldown = 0.30,
    voices = 2,
  },
}

--- Model 이벤트 타입 → SFX 키 매핑
local EVENT_TO_SFX = {
  fire = "fire",
  missile_fired = "missile",
  enemy_destroyed = "explosion",
  player_hit = "player_hit",
  shield_broken = "shield_broken",
  emp_detonated = "emp",
  item_collected = "item",
  boss_appeared = "boss_warning",
  boss_hit = "boss_hit",
  boss_turret_hit = "boss_hit",
  boss_turret_destroyed = "turret_destroyed",
  boss_enraged = "boss_enraged",
  boss_destroyed = "boss_destroyed",
  formation_cleared = "wave_clear",
  achievement_unlocked = "achievement",
  game_over = "game_over",
}

local function fillSegment(data, startSample, seg, nextNoise)
  local count = max(1, floor(seg.dur * SAMPLE_RATE))
  local phase = 0
  local decay = seg.decay or 8
  local f0 = seg.f0
  local f1 = seg.f1 or f0
  local wave = seg.wave or "square"

  for i = 0, count - 1 do
    local t = i / SAMPLE_RATE
    local progress = i / count
    local freq = f0 + (f1 - f0) * progress
    phase = phase + freq / SAMPLE_RATE

    local env = exp(-decay * t)
    if t < FADE_TIME then
      env = env * (t / FADE_TIME)
    end
    local rem = (count - 1 - i) / SAMPLE_RATE
    if rem < FADE_TIME then
      env = env * (rem / FADE_TIME)
    end

    local raw = sampleWave(wave, phase, nextNoise) * env
    local clamped = max(-1, min(1, raw))
    data:setSample(startSample + i, clamped)
  end
  return startSample + count
end

local function buildSoundData(sound, recipe)
  local nextNoise = makeNoiseGen()
  if recipe.notes then
    local totalSamples = 0
    for i = 1, #recipe.notes do
      totalSamples = totalSamples + max(1, floor(recipe.notes[i].dur * SAMPLE_RATE))
    end
    local data = sound.newSoundData(totalSamples, SAMPLE_RATE, BIT_DEPTH, CHANNELS)
    local cursor = 0
    for i = 1, #recipe.notes do
      cursor = fillSegment(data, cursor, recipe.notes[i], nextNoise)
    end
    return data
  end

  local totalSamples = max(1, floor(recipe.duration * SAMPLE_RATE))
  local data = sound.newSoundData(totalSamples, SAMPLE_RATE, BIT_DEPTH, CHANNELS)
  fillSegment(data, 0, {
    dur = recipe.duration,
    f0 = recipe.f0,
    f1 = recipe.f1,
    wave = recipe.wave,
    decay = recipe.decay,
  }, nextNoise)
  return data
end

local function buildPool(audio, sound, recipe)
  local data = buildSoundData(sound, recipe)
  local base = audio.newSource(data, "static")
  local vol = recipe.volume or 0.3
  if base.setVolume then
    base:setVolume(vol)
  end

  local voices = max(1, recipe.voices or 2)
  local pool = { base }
  for i = 2, voices do
    local cloned = base.clone and base:clone() or base
    if cloned.setVolume then
      cloned:setVolume(vol)
    end
    pool[i] = cloned
  end
  return {
    pool = pool,
    cursor = 1,
    cooldown = recipe.cooldown or 0.05,
  }
end

--- @param opts table|nil  { audio=love.audio|nil, sound=love.sound|nil }
function AudioView:init(opts)
  opts = opts or {}
  self.audio = opts.audio
  self.sound = opts.sound
  self.enabled = (self.audio ~= nil and self.sound ~= nil)
  self.banks = {}
  self.cooldowns = {}
  self.weaverStates = setmetatable({}, { __mode = "k" })
  self.bossState = nil

  if not self.enabled then
    return
  end

  for key, recipe in pairs(RECIPES) do
    self.banks[key] = buildPool(self.audio, self.sound, recipe)
  end
end

--- 키에 해당하는 효과음을 재생한다 (디바운스 적용, 풀 순환)
function AudioView:play(key)
  if not self.enabled then
    return false
  end
  local bank = self.banks[key]
  if not bank then
    return false
  end
  local remaining = self.cooldowns[key] or 0
  if remaining > 0 then
    return false
  end

  local src = bank.pool[bank.cursor]
  bank.cursor = (bank.cursor % #bank.pool) + 1
  if src.stop then
    src:stop()
  end
  src:play()
  self.cooldowns[key] = bank.cooldown
  return true
end

--- GameModel:drainEvents() 로 받은 이벤트 1개 처리
function AudioView:onEvent(ev)
  if not self.enabled or not ev then
    return
  end
  local key = EVENT_TO_SFX[ev.type]
  if key then
    self:play(key)
  end
end

function AudioView:_checkLaserStates(game)
  local enemies = game.enemies
  if enemies then
    for i = 1, #enemies do
      local e = enemies[i]
      if e.alive and e.kind == "weaver" then
        local prev = self.weaverStates[e]
        local curr = e.aiState
        if curr == "charge" and prev ~= "charge" then
          self:play("laser_charge")
        elseif curr == "laser" and prev ~= "laser" then
          self:play("laser_fire")
        end
        self.weaverStates[e] = curr
      end
    end
  end

  local boss = game.boss
  if boss and boss.alive then
    local curr = boss.aiState
    if curr == "laser_charge" and self.bossState ~= "laser_charge" then
      self:play("laser_charge")
    elseif curr == "laser" and self.bossState ~= "laser" then
      self:play("laser_fire")
    end
    self.bossState = curr
  else
    self.bossState = nil
  end
end

--- 쿨다운 타이머 갱신 및 Weaver/보스 상태 전이 감지
function AudioView:update(dt, game)
  if not self.enabled then
    return
  end
  for key, t in pairs(self.cooldowns) do
    if t > 0 then
      local nextT = t - dt
      self.cooldowns[key] = nextT > 0 and nextT or 0
    end
  end
  if game then
    self:_checkLaserStates(game)
  end
end

return AudioView

