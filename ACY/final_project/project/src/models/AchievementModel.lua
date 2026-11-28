-- AchievementModel.lua
-- GameModel 이 발행한 이벤트(drainEvents)를 구독해 업적을 판정한다.
-- GameModel 은 업적을 모른다(Observer 패턴). love / io / print 비의존.

local class = require("class")

local AchievementModel = class()

local CATALOG = {
  -- Combat
  {
    id = "first_blood",
    category = "combat",
    title = "FIRST BLOOD",
    desc = "Destroy your first enemy.",
  },
  {
    id = "streak_10",
    category = "combat",
    title = "10 KILL STREAK",
    desc = "Destroy 10 enemies in a row without taking a hit.",
  },
  {
    id = "run_kills_50",
    category = "combat",
    title = "BATTLE FRENZY",
    desc = "Destroy 50 enemies in a single run.",
  },
  {
    id = "total_kills_100",
    category = "combat",
    title = "CENTURION",
    desc = "Destroy 100 enemies in total across all runs.",
  },
  {
    id = "trigger_happy",
    category = "combat",
    title = "TRIGGER HAPPY",
    desc = "Fire 100 shots in a single run.",
  },
  {
    id = "flawless_wave",
    category = "combat",
    title = "FLAWLESS WAVE",
    desc = "Clear a formation wave without taking any hit.",
  },
  -- Boss
  {
    id = "boss_slayer",
    category = "boss",
    title = "BOSS SLAYER",
    desc = "Defeat the boss enemy.",
  },
  {
    id = "boss_hunter_5",
    category = "boss",
    title = "BOSS NEMESIS",
    desc = "Defeat 5 bosses in total across all runs.",
  },
  {
    id = "pure_gunner",
    category = "boss",
    title = "PURE GUNNER",
    desc = "Defeat the first boss without firing a homing missile.",
  },
  -- Survival
  {
    id = "field_medic",
    category = "survival",
    title = "FIELD MEDIC",
    desc = "Collect 3 life items in a single run.",
  },
  {
    id = "nine_lives",
    category = "survival",
    title = "NINE LIVES",
    desc = "Collect 10 life items in a single run.",
  },
  -- Score
  {
    id = "score_10k",
    category = "score",
    title = "RISING ACE",
    desc = "Reach 10,000 points in a single run.",
  },
  {
    id = "score_30k",
    category = "score",
    title = "STAR VETERAN",
    desc = "Reach 30,000 points in a single run.",
  },
  {
    id = "score_50k",
    category = "score",
    title = "GALAXY LEGEND",
    desc = "Reach 50,000 points in a single run.",
  },
  {
    id = "total_score_100k",
    category = "score",
    title = "ETERNAL COMMANDER",
    desc = "Earn 100,000 total points across all runs.",
  },
}

local LIFE_MILESTONES = {
  { count = 3, id = "field_medic" },
  { count = 10, id = "nine_lives" },
}

local SCORE_MILESTONES = {
  { score = 10000, id = "score_10k" },
  { score = 30000, id = "score_30k" },
  { score = 50000, id = "score_50k" },
}

local BY_ID = {}
for i = 1, #CATALOG do
  local entry = CATALOG[i]
  BY_ID[entry.id] = entry
end

local function sanitizeCount(v)
  if type(v) == "number" and v >= 0 and v == v and v < math.huge then
    return math.floor(v)
  end
  return 0
end

function AchievementModel:init(unlockedIds, stats)
  self.unlocked = {}
  self.unlockedOrder = {}
  local s = type(stats) == "table" and stats or {}
  self.totalScore = sanitizeCount(s.totalScore)
  self.totalKills = sanitizeCount(s.totalKills)
  self.totalBosses = sanitizeCount(s.totalBosses)
  self:resetRun()

  if type(unlockedIds) == "table" then
    for i = 1, #unlockedIds do
      local id = unlockedIds[i]
      if BY_ID[id] and not self.unlocked[id] then
        self:_unlock(id, {})
      end
    end
  end
end

--- 새 판 시작 시 판 단위 누적 카운터를 초기화한다(해금 기록 및 통산 누적은 유지).
function AchievementModel:resetRun()
  self.streak = 0
  self.shots = 0
  self.waveHit = false
  self.usedMissile = false
  self.bossesAppeared = 0
  self.lifeItems = 0
  self.runKills = 0
end

function AchievementModel:_unlock(id, newly)
  if self.unlocked[id] or not BY_ID[id] then
    return
  end
  self.unlocked[id] = true
  local entry = BY_ID[id]
  local item = { id = id, title = entry.title, desc = entry.desc }
  self.unlockedOrder[#self.unlockedOrder + 1] = item
  newly[#newly + 1] = item
end

local function unlockMilestones(self, milestones, value, key, newly)
  for i = 1, #milestones do
    local m = milestones[i]
    if value >= m[key] then
      self:_unlock(m.id, newly)
    end
  end
end

--- GameModel 이벤트 1건을 구독해 처리하고, 이번에 새로 해금된 업적 목록을 반환한다.
function AchievementModel:onEvent(ev)
  local newly = {}
  if not ev or not ev.type then
    return newly
  end

  if ev.type == "enemy_destroyed" then
    self:_unlock("first_blood", newly)
    self.streak = self.streak + 1
    if self.streak >= 10 then
      self:_unlock("streak_10", newly)
    end
    self.runKills = self.runKills + 1
    if self.runKills >= 50 then
      self:_unlock("run_kills_50", newly)
    end
    self.totalKills = self.totalKills + 1
    if self.totalKills >= 100 then
      self:_unlock("total_kills_100", newly)
    end
  elseif ev.type == "fire" then
    self.shots = self.shots + 1
    if self.shots >= 100 then
      self:_unlock("trigger_happy", newly)
    end
  elseif ev.type == "missile_fired" then
    self.usedMissile = true
  elseif ev.type == "player_hit" then
    self.streak = 0
    self.waveHit = true
  elseif ev.type == "formation_cleared" then
    if not self.waveHit then
      self:_unlock("flawless_wave", newly)
    end
    self.waveHit = false
  elseif ev.type == "boss_appeared" then
    self.bossesAppeared = self.bossesAppeared + 1
  elseif ev.type == "boss_destroyed" then
    self:_unlock("boss_slayer", newly)
    if self.bossesAppeared == 1 and not self.usedMissile then
      self:_unlock("pure_gunner", newly)
    end
    self.totalBosses = self.totalBosses + 1
    if self.totalBosses >= 5 then
      self:_unlock("boss_hunter_5", newly)
    end
  elseif ev.type == "item_collected" then
    if ev.kind == "life" then
      self.lifeItems = self.lifeItems + 1
      unlockMilestones(self, LIFE_MILESTONES, self.lifeItems, "count", newly)
    end
  elseif ev.type == "score_changed" then
    unlockMilestones(self, SCORE_MILESTONES, ev.score or 0, "score", newly)
    local delta = ev.delta or 0
    if delta > 0 then
      self.totalScore = self.totalScore + delta
      if self.totalScore >= 100000 then
        self:_unlock("total_score_100k", newly)
      end
    end
  end

  return newly
end

function AchievementModel:isUnlocked(id)
  return self.unlocked[id] == true
end

function AchievementModel:count()
  return #self.unlockedOrder
end

function AchievementModel:totalCount()
  return #CATALOG
end

function AchievementModel:list()
  return self.unlockedOrder
end

--- UI 표시용 전체 업적 목록을 반환한다. 미달성 업적은 이름은 "???", 조건은 "???????"로 마스킹한다.
function AchievementModel:getCatalogEntries()
  local entries = {}
  for i = 1, #CATALOG do
    local spec = CATALOG[i]
    local unlocked = self.unlocked[spec.id] == true
    entries[i] = {
      id = spec.id,
      unlocked = unlocked,
      title = unlocked and spec.title or "???",
      desc = unlocked and spec.desc or "???????",
    }
  end
  return entries
end

--- 저장용 문자열로 직렬화한다.
function AchievementModel:serialize()
  local ids = {}
  for i = 1, #self.unlockedOrder do
    ids[i] = self.unlockedOrder[i].id
  end
  return table.concat({
    "achievements=" .. table.concat(ids, ","),
    "total_score=" .. tostring(self.totalScore),
    "total_kills=" .. tostring(self.totalKills),
    "total_bosses=" .. tostring(self.totalBosses),
  }, "\n")
end

local function parseNonNegInt(v)
  if type(v) ~= "string" then
    return 0
  end
  local digits = v:match("^(%d+)$")
  local num = digits and tonumber(digits) or nil
  if not num or num < 0 or num >= math.huge then
    return 0
  end
  return math.floor(num)
end

--- 저장 문자열을 역직렬화한다. 깨진 입력이나 알 수 없는 ID는 무시하고 안전하게 복구한다.
function AchievementModel.deserialize(str)
  if type(str) ~= "string" then
    return AchievementModel()
  end

  local ids = {}
  local stats = { totalScore = 0, totalKills = 0, totalBosses = 0 }

  for raw in str:gmatch("[^\r\n]+") do
    local line = raw:match("^%s*(.-)%s*$")
    local key, val = line:match("^([%w_]+)%s*=%s*(.-)$")
    if key == "achievements" and val ~= "" then
      for token in val:gmatch("[^,]+") do
        local id = token:match("^%s*(.-)%s*$")
        if BY_ID[id] then
          ids[#ids + 1] = id
        end
      end
    elseif key == "total_score" then
      stats.totalScore = parseNonNegInt(val)
    elseif key == "total_kills" then
      stats.totalKills = parseNonNegInt(val)
    elseif key == "total_bosses" then
      stats.totalBosses = parseNonNegInt(val)
    end
  end

  return AchievementModel(ids, stats)
end

return AchievementModel
