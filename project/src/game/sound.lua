-- ============================================================================
-- sound.lua — 실시간 사운드 합성 및 효과음 재생 모듈
-- ============================================================================
--
-- ◆ 역할
--   별도의 외부 사운드 파일(.wav, .mp3 등) 없이, love.sound.newSoundData와
--   love.audio.newSource를 사용하여 메모리 상에서 수학적 파형을 통해
--   복고풍(Retro/Chiptune) 효과음을 실시간으로 생성하고 재생합니다.
--

local Sound = {}

-- 생성된 사운드 소스들을 저장할 캐시 테이블
local sources = {}

-- 사운드 데이터 생성 헬퍼 함수
-- duration: 소리 길이 (초 단위, 예: 0.15)
-- generator: 각 시간(t)과 총길이(duration)를 기반으로 -1.0 ~ 1.0 사이의 샘플 값을 반환하는 함수
local function createSound(name, duration, generator)
    local sampleRate = 44100
    local bits = 16
    local channels = 1
    local sampleCount = math.floor(duration * sampleRate)
    
    -- LÖVE 메모리 사운드 데이터 객체 생성
    local soundData = love.sound.newSoundData(sampleCount, sampleRate, bits, channels)
    
    for i = 0, sampleCount - 1 do
        local t = i / sampleRate
        local val = generator(t, duration)
        -- 샘플 값이 -1.0 ~ 1.0 범위를 벗어나지 않도록 클램핑
        val = math.max(-1, math.min(1, val))
        soundData:setSample(i, val)
    end
    
    -- 정적 소스로 사운드 생성 및 캐싱
    sources[name] = love.audio.newSource(soundData, "static")
end

-- 사운드 시스템 초기화 (게임 오브젝트 레퍼런스를 전달받아 음소거 상태 체크에 활용)
function Sound.init(game_ref)
    Sound.game = game_ref
    
    -- 1. 발사 효과음 (Shoot) - 높은 주파수에서 낮은 주파수로 빠르게 휩(sweep)하는 사인파
    createSound("shoot", 0.12, function(t, duration)
        local tRatio = t / duration
        local freq = 900 - 700 * tRatio -- 900Hz -> 200Hz
        local phase = 2 * math.pi * freq * t
        local envelope = 1 - tRatio -- 부드러운 페이드아웃 감쇄(Decay)
        return math.sin(phase) * envelope * 0.25 -- 볼륨 조정
    end)
    
    -- 2. 폭발 효과음 (Explosion) - 화이트 노이즈와 급격한 볼륨 감쇄
    createSound("explosion", 0.35, function(t, duration)
        local tRatio = t / duration
        local envelope = (1 - tRatio) ^ 2 -- 빠른 감쇄를 위해 제곱근 사용
        local noise = math.random() * 2 - 1 -- -1 ~ 1 사이의 화이트 노이즈
        return noise * envelope * 0.3
    end)
    
    -- 3. 피격 효과음 (Hit) - 거친 사각파(Square Wave)를 사용한 메탈릭 버즈음
    createSound("hit", 0.08, function(t, duration)
        local tRatio = t / duration
        local freq = 130
        local phase = 2 * math.pi * freq * t
        -- 사각파 생성: 주기의 절반은 1, 절반은 -1
        local sample = (phase % (2 * math.pi) < math.pi) and 1 or -1
        local envelope = 1 - tRatio
        return sample * envelope * 0.15
    end)
    
    -- 4. 레벨업 효과음 (Level Up) - 도-미-솔-도(C5-E5-G5-C6) 아르페지오 멜로디
    createSound("levelup", 0.6, function(t, duration)
        local tRatio = t / duration
        -- 시간에 따라 주파수가 계단식으로 상승
        local noteIdx = math.floor(tRatio * 4)
        local freq = 523 -- C5 (도)
        if noteIdx == 1 then freq = 659 -- E5 (미)
        elseif noteIdx == 2 then freq = 784 -- G5 (솔)
        elseif noteIdx == 3 then freq = 1046 -- C6 (높은 도)
        end
        
        local phase = 2 * math.pi * freq * t
        local envelope = 1 - tRatio
        
        -- 사인파와 삼각파를 합성하여 풍부한 칩튠 음색 구현
        local sinVal = math.sin(phase)
        local triVal = (phase % (2 * math.pi)) / math.pi - 1
        if triVal < 0 then triVal = -triVal end
        triVal = triVal * 2 - 1
        
        return (sinVal * 0.7 + triVal * 0.3) * envelope * 0.25
    end)
    
    -- 5. 선택/UI 클릭 효과음 (Select) - 짧고 깔끔한 높은 주파수 사인파
    createSound("select", 0.06, function(t, duration)
        local tRatio = t / duration
        local freq = 650
        local phase = 2 * math.pi * freq * t
        local envelope = (1 - tRatio) ^ 3
        return math.sin(phase) * envelope * 0.2
    end)

    -- 6. 배경 음악 (BGM) - 16초 루프용 절차적 합성
    local sampleRate = 44100
    local bits = 16
    local channels = 1
    local bgmDuration = 16.0
    local bgmSampleCount = math.floor(bgmDuration * sampleRate)

    local bgmSoundData = love.sound.newSoundData(bgmSampleCount, sampleRate, bits, channels)

    for i = 0, bgmSampleCount - 1 do
        local t = i / sampleRate

        -- 코드 진행 (Am - F - C - G, 각 4초씩)
        local chordIndex = math.floor(t / 4.0) % 4
        local rootFreq = 55.00 -- A1
        local note1, note2, note3, note4 = 220.00, 261.63, 329.63, 440.00 -- A3, C4, E4, A4

        if chordIndex == 1 then -- F
            rootFreq = 43.65 -- F1
            note1, note2, note3, note4 = 174.61, 220.00, 261.63, 349.23 -- F3, A3, C4, F4
        elseif chordIndex == 2 then -- C
            rootFreq = 65.41 -- C2
            note1, note2, note3, note4 = 130.81, 164.81, 196.00, 261.63 -- C3, E3, G3, C4
        elseif chordIndex == 3 then -- G
            rootFreq = 49.00 -- G1
            note1, note2, note3, note4 = 196.00, 246.94, 293.66, 392.00 -- G3, B3, D4, G4
        end

        -- 1) 베이스 (Triangle Wave) - 8분 음표 (0.25초 간격으로 감쇠)
        local bassT = t % 0.25
        local bassEnv = math.exp(-6.0 * bassT)
        local bassPhase = 2 * math.pi * rootFreq * t
        local triVal = (bassPhase % (2 * math.pi)) / math.pi - 1
        if triVal < 0 then triVal = -triVal end
        triVal = triVal * 2 - 1
        local bassVal = triVal * bassEnv * 0.12

        -- 2) 아르페지오 (Sine Wave) - 16분 음표 (0.125초 간격으로 급격 감쇠)
        local arpStep = math.floor(t / 0.125) % 8
        local currentNoteFreq = note1
        if arpStep == 1 or arpStep == 6 then
            currentNoteFreq = note2
        elseif arpStep == 2 or arpStep == 5 then
            currentNoteFreq = note3
        elseif arpStep == 3 or arpStep == 4 then
            currentNoteFreq = note4
        end

        local arpT = t % 0.125
        local arpEnv = math.exp(-12.0 * arpT)
        local arpPhase = 2 * math.pi * currentNoteFreq * t
        local arpVal = math.sin(arpPhase) * arpEnv * 0.06

        -- 3) 하이햇 (White Noise) - 4분 음표 정박 (0.5초 간격으로 0.03초 동안 노이즈 방출)
        local drumT = t % 0.5
        local noiseVal = 0
        if drumT < 0.03 then
            local noiseEnv = 1.0 - (drumT / 0.03)
            local noise = math.random() * 2 - 1
            noiseVal = noise * noiseEnv * 0.012
        end

        local val = bassVal + arpVal + noiseVal
        val = math.max(-1, math.min(1, val))
        bgmSoundData:setSample(i, val)
    end

    sources["bgm"] = love.audio.newSource(bgmSoundData, "static")
    sources["bgm"]:setLooping(true)
end

-- 효과음 재생
function Sound.play(name)
    -- 게임 설정의 음소거(muted) 상태 확인
    if Sound.game and Sound.game.muted then
        return
    end

    local src = sources[name]
    if src then
        -- 동일 소리가 연속해서 중복 재생될 때 끊김 방지를 위해 소스 복제(Clone) 후 재생
        local clone = src:clone()
        clone:play()
    end
end

-- BGM 재생
function Sound.playBGM()
    local src = sources["bgm"]
    if src then
        if Sound.game and Sound.game.muted then
            src:pause()
        else
            if not src:isPlaying() then
                src:play()
            end
        end
    end
end

-- BGM 정지
function Sound.stopBGM()
    local src = sources["bgm"]
    if src then
        src:stop()
    end
end

-- 음소거 상태 업데이트 (설정 화면 등에서 사용)
function Sound.updateMuteState()
    local src = sources["bgm"]
    if not src then return end

    if Sound.game and Sound.game.muted then
        src:pause()
    else
        src:play()
    end
end

return Sound

