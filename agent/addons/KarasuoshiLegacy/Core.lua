-- Karasuoshi Legacy: сбор состояния персонажей и логика подсказок
local ADDON, ns = ...
local KL = CreateFrame("Frame", "KarasuoshiLegacyCore")
ns.KL = KL

local floor, min, max, lower, time = math.floor, math.min, math.max, string.lower, time
local L = ns.LIMITS

------------------------------------------------------------------------
-- База
------------------------------------------------------------------------
local DB
local function InitDB()
    KarasuoshiLegacyDB = KarasuoshiLegacyDB or {}
    DB = KarasuoshiLegacyDB
    DB.chars   = DB.chars or {}
    DB.checks  = DB.checks or {}
    DB.spelunk = DB.spelunk or {}
    DB.ui      = DB.ui or {}
    for _, k in ipairs(ns.ROSTER_ORDER) do DB.chars[k] = DB.chars[k] or { profs = {}, quests = {} } end
    ns.DB = DB
end

-- Шаги с id, как на странице-черновике: ключ этапа - группа - номер
ns.STEPS = {}
for _, st in ipairs(ns.STAGES) do
    for gi, g in ipairs(st.groups) do
        for i, s in ipairs(g.steps) do
            s.id, s.who, s.stage = st.key .. "-" .. (gi - 1) .. "-" .. (i - 1), g.who, st
            ns.STEPS[#ns.STEPS + 1] = s
        end
    end
end
local DUNGEON_BY_KEY = {}
for _, d in ipairs(ns.DUNGEONS) do DUNGEON_BY_KEY[d.key] = d end
ns.DUNGEON_BY_KEY = DUNGEON_BY_KEY

------------------------------------------------------------------------
-- Кто сейчас в игре
------------------------------------------------------------------------
function KL:Role()
    if self.role ~= nil then return self.role or nil end
    local name = UnitName("player") or ""
    local first = lower(name:match("^(%S+)") or name)
    self.role = false
    for k, r in pairs(ns.ROSTER) do
        if lower(r.name) == first then self.role = k end
    end
    return self.role or nil
end

------------------------------------------------------------------------
-- Чтение игры (всё с запасными путями, как в Rested Buff)
------------------------------------------------------------------------
local PROF_BY_NAME = {}
for k, p in pairs(ns.PROFS) do for _, n in ipairs(p.names) do PROF_BY_NAME[n] = k; PROF_BY_NAME[lower(n)] = k end end
local function ProfKey(name) return name and (PROF_BY_NAME[name] or PROF_BY_NAME[lower(name)]) end

local function ScanProfessions()
    local out = {}
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, (GetNumSkillLines() or 0) do
            local name, isHeader, _, rank = GetSkillLineInfo(i)
            local k = not isHeader and ProfKey(name)
            if k then out[k] = rank or 0 end
        end
    end
    if GetProfessions and GetProfessionInfo then
        local p = { GetProfessions() }
        for i = 1, 6 do
            if p[i] then
                local name, _, rank = GetProfessionInfo(p[i])
                local k = ProfKey(name)
                if k then out[k] = rank or 0 end
            end
        end
    end
    return out
end

local function ItemClass(itemID)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not f or not itemID then return end
    local _, _, _, _, _, classID, subClassID = f(itemID)
    return classID, subClassID
end

local function ItemMinLevel(itemID)
    local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not f or not itemID then return end
    local name, _, _, _, minLevel = f(itemID)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
    return minLevel
end

local function WandLevel()
    local id = GetInventoryItemID and GetInventoryItemID("player", 18)
    if not id then return 0 end
    local c, sc = ItemClass(id)
    if c ~= 2 or sc ~= 19 then return 0 end
    return ItemMinLevel(id) or 1
end

local function BagSlot(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then return info.itemID, info.quality, info.isBound end
        return
    end
    if GetContainerItemInfo then
        local _, _, _, quality, _, _, _, _, _, itemID, isBound = GetContainerItemInfo(bag, slot)
        return itemID, quality, isBound
    end
end

local function NumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

-- Что в сумках Osh уходит Ebosh: ткань, кожа/шкуры, непривязанные зелёные и выше
local function CountToSend()
    local n = 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, NumSlots(bag) do
            local id, quality, bound = BagSlot(bag, slot)
            if id then
                local c, sc = ItemClass(id)
                if c == 7 and (sc == 5 or sc == 6) then
                    n = n + 1
                elseif (c == 2 or c == 4) and (quality or 0) >= 2 and not bound then
                    n = n + 1
                end
            end
        end
    end
    return n
end

local function ItemCount(itemID)
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(itemID, true) or 0 end
    return GetItemCount and GetItemCount(itemID, true) or 0
end

local function QuestDone(id)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(id) end
    return IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(id)
end

-- Названия квестов в журнале (для поиска по имени, если id не совпал)
local function QuestLogTitles()
    local t = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        for i = 1, (C_QuestLog.GetNumQuestLogEntries() or 0) do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader then
                if info.title then t[lower(info.title)] = true end
                if info.questID then t[info.questID] = true end
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, (GetNumQuestLogEntries() or 0) do
            local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
            if title and not isHeader then
                t[lower(title)] = true
                if questID then t[questID] = true end
            end
        end
    end
    return t
end

local function ScanDungeonQuests()
    local out, log = {}, QuestLogTitles()
    for _, d in ipairs(ns.DUNGEONS) do
        for i, q in ipairs(d.quests) do
            local key, st = d.key .. i, nil
            if q.item then
                if ItemCount(q.item) > 0 then st = "done" end
            elseif q.id and QuestDone(q.id) then
                st = "done"
            elseif (q.id and log[q.id]) or log[lower(q.title)] then
                st = "log"
            end
            out[key] = st
        end
    end
    return out
end

------------------------------------------------------------------------
-- Снимок текущего персонажа
------------------------------------------------------------------------
function KL:Snapshot()
    local role = self:Role()
    if not role or not DB then return end
    local c = DB.chars[role]
    local xpMax = UnitXPMax("player") or 0
    local rested = (GetXPExhaustion and GetXPExhaustion()) or 0
    c.level   = UnitLevel("player") or 1
    c.restPct = xpMax > 0 and floor(rested / xpMax * 100 + 0.5) or 0
    c.resting = IsResting and IsResting() or false
    c.gold    = floor((GetMoney() or 0) / 10000)
    c.seen    = time()
    local profs = ScanProfessions()
    for k, p in pairs(ns.PROFS) do
        if p.who == role then c.profs[k] = profs[k] or c.profs[k] or 0 end
    end
    if role == "osh" then
        c.wand   = WandLevel()
        c.toSend = CountToSend()
        c.quests = ScanDungeonQuests()
    end
end

------------------------------------------------------------------------
-- Расчёты
------------------------------------------------------------------------
-- Рестед второго персонажа: последний снимок + накопление офлайн
-- (5% уровня за 8 часов в зоне отдыха, вчетверо медленнее вне её, потолок 150%)
function KL:Rest(k)
    local c = DB.chars[k]
    if not c or not c.level then return 0 end
    if k == self:Role() then return c.restPct or 0 end
    local hours = (time() - (c.seen or time())) / 3600
    local rate = c.resting and (5 / 8) or (5 / 32)
    return min(150, floor((c.restPct or 0) + hours * rate))
end

function KL:Level(k) return (DB.chars[k] and DB.chars[k].level) or 0 end

function KL:Skill(pk)
    local p = ns.PROFS[pk]
    local c = DB.chars[p.who]
    return (c and c.profs and c.profs[pk]) or 0
end

local function CapFor(level)
    if level < 10 then return 75 elseif level < 20 then return 150 elseif level < 35 then return 225 end
    return 300
end
local function NextRankLevel(cap) return cap == 75 and 10 or cap == 150 and 20 or 35 end
ns.CapFor = CapFor

function KL:ProfInfo(pk)
    local p = ns.PROFS[pk]
    local lvl, skill = self:Level(p.who), self:Skill(pk)
    local cap = CapFor(lvl)
    local ms
    for _, m in ipairs({ 150, 225, 300 }) do if skill < m then ms = m break end end
    local st, msg = "ok", "в норме"
    if skill >= cap and cap < 300 then
        st, msg = "lock", ("упёрся в %d, ранг выше с %d ур."):format(cap, NextRankLevel(cap))
    elseif ms and ms <= cap then
        st, msg = "behind", ("до %d ещё %d"):format(ms, ms - skill)
    end
    return { key = pk, label = p.label, who = p.who, level = lvl, skill = skill, cap = cap, ms = ms, st = st, msg = msg }
end

function KL:DungeonDone(dk)
    local d, q = DUNGEON_BY_KEY[dk], DB.chars.osh.quests or {}
    if not d then return false end
    for i in ipairs(d.quests) do if q[dk .. i] ~= "done" then return false end end
    return true
end

function KL:AutoDone(s)
    local a = s.auto
    if not a then return false end
    if a.level then return self:Level(a.who) >= a.level end
    if a.skill then return self:Skill(a.skill) >= a.min end
    if a.skills then
        for pk, m in pairs(a.skills) do if self:Skill(pk) < m then return false end end
        return true
    end
    if a.dungeon then return self:DungeonDone(a.dungeon) end
    return false
end

-- Ручной шаг считается пройденным, когда этап остался позади:
-- этап Ebosh 1 → 10 — с 10 уровня Ebosh, этапы Osh — когда Osh перерос их уровни
function KL:StagePassed(st)
    if st.key == "s1" then return self:Level("ebosh") >= 10 end
    return st.levels and self:Level("osh") > st.levels[2] or false
end

function KL:IsDone(s) return DB.checks[s.id] or self:AutoDone(s) or self:StagePassed(s.stage) end

function KL:ToggleCheck(s)
    if self:AutoDone(s) then return end
    DB.checks[s.id] = not DB.checks[s.id] or nil
    self:Refresh()
end

function KL:CurrentStage()
    local osh, eb = self:Level("osh"), self:Level("ebosh")
    if eb < 10 and osh <= 1 then return ns.STAGES[2] end
    for _, st in ipairs(ns.STAGES) do
        if st.levels and osh >= st.levels[1] and osh <= st.levels[2] then return st end
    end
    return ns.STAGES[#ns.STAGES]
end

local function StageIndex(st)
    for i, s in ipairs(ns.STAGES) do if s == st then return i end end
    return 1
end

function KL:NextSteps(who, n)
    local list, cur = {}, self:CurrentStage()
    if who == "osh" then
        for _, s in ipairs(ns.STEPS) do
            if s.stage == cur and (s.who == "osh" or s.who == "all") and not self:IsDone(s) then list[#list + 1] = s end
        end
    else
        local ci = max(2, StageIndex(cur))
        for _, s in ipairs(ns.STEPS) do
            if s.who == "ebosh" and StageIndex(s.stage) <= ci and not self:IsDone(s) then list[#list + 1] = s end
        end
    end
    if #list == 0 then
        for _, s in ipairs(ns.STEPS) do
            if s.who == who and s.stage ~= ns.STAGES[1] and not self:IsDone(s) then list[#list + 1] = s end
        end
    end
    local out = {}
    for i = 1, min(n, #list) do out[i] = list[i] end
    return out
end

-- Плитки главной: только то, с чем надо что-то сделать
function KL:Tiles()
    local role, t = self:Role(), {}
    if not role then return t end
    local osh = DB.chars.osh
    local lag = (osh.level or 0) - (osh.wand or 0)
    local needWand = (osh.level or 0) < 40 and (((osh.wand or 0) == 0 and (osh.level or 0) >= 5) or ((osh.wand or 0) > 0 and lag >= L.wandLag))
    if role == "osh" then
        if needWand then
            if (osh.wand or 0) == 0 then
                t[#t + 1] = { label = "Палочка", val = "нет", sub = "Lesser Magic Wand от Ebosh", st = "bad" }
            else
                t[#t + 1] = { label = "Палочка", val = osh.wand .. " ур.", sub = "отстаёт на " .. lag, st = "warn" }
            end
        end
        local p = self:ProfInfo("lw")
        if p.st ~= "ok" then t[#t + 1] = { label = p.label, val = p.skill .. " / " .. p.cap, sub = p.msg, st = p.st == "behind" and "warn" or "bad" } end
        local n = osh.toSend or 0
        if n >= L.mailItems or (self.atMailbox and n > 0) then
            t[#t + 1] = { label = "Почта", val = n .. " → Ebosh", sub = self.atMailbox and "ты у ящика" or "сумки полнеют", st = n >= L.mailItems and "warn" or "ok" }
        end
    else
        for _, pk in ipairs({ "tail", "ench" }) do
            local p = self:ProfInfo(pk)
            if p.st ~= "ok" then t[#t + 1] = { label = p.label, val = p.skill .. " / " .. p.cap, sub = p.msg, st = p.st == "behind" and "warn" or "bad" } end
        end
        local n = DB.chars.ebosh.inbox or 0
        if n >= L.mailItems or (self.atMailbox and n > 0) then
            t[#t + 1] = { label = "Почта", val = n .. " писем", sub = "диз, аукцион, сумки", st = n >= L.mailItems and "warn" or "ok" }
        end
        if needWand then
            t[#t + 1] = { label = "Для Osh", val = "палочка", sub = (osh.wand or 0) > 0 and ("Osh отстаёт на " .. lag) or "у Osh нет палочки", st = "warn" }
        end
    end
    return t
end

function KL:Alerts()
    local role, a = self:Role(), {}
    if not role then return a end
    local other = role == "osh" and "ebosh" or "osh"
    local mine, theirs = self:Rest(role), self:Rest(other)
    if DB.chars[other].level and mine < L.restLow and theirs - mine >= L.restGap then
        a[#a + 1] = { st = "info", text = ("У %s рестед %d%%: пора переключиться"):format(ns.ROSTER[other].short, theirs) }
    end
    return a
end

-- Данж рядом: зона совпала, уровень в диапазоне, не все квесты сданы
function KL:NearDungeon()
    if self:Role() ~= "osh" then return end
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local lvl = self:Level("osh")
    for _, d in ipairs(ns.DUNGEONS) do
        if lvl >= d.min - 1 and lvl <= d.max and not self:DungeonDone(d.key) then
            for _, z in ipairs(d.zones) do
                if z == zone then
                    local miss = 0
                    for i in ipairs(d.quests) do if not (DB.chars.osh.quests or {})[d.key .. i] then miss = miss + 1 end end
                    return d, miss
                end
            end
        end
    end
end

------------------------------------------------------------------------
-- Легаси
------------------------------------------------------------------------
function KL:Spelunker()
    local id, list = ns.SPELUNKER_ACHIEVEMENT, {}
    if GetAchievementNumCriteria and GetAchievementCriteriaInfo then
        local ok, n = pcall(GetAchievementNumCriteria, id)
        if ok and n and n > 0 then
            for i = 1, n do
                local ok2, name, _, done = pcall(GetAchievementCriteriaInfo, id, i)
                if ok2 and name then list[#list + 1] = { name = name, done = done and true or false, game = true } end
            end
            if #list > 0 then return list, true end
        end
    end
    for _, d in ipairs(ns.SPELUNKER) do
        list[#list + 1] = { key = d.key, name = d.name, done = DB.spelunk[d.key] and true or false }
    end
    return list, false
end

function KL:ToggleSpelunk(key)
    DB.spelunk[key] = not DB.spelunk[key] or nil
    self:Refresh()
end

-- got / now / lock: есть, можно добрать на текущих уровнях, закрыто уровнем
function KL:LegacyItems()
    local out = {}
    local function add(name, st, how, soon) out[#out + 1] = { name = name, st = st, how = how or "", soon = soon } end
    for _, rc in ipairs({ { "osh", "Жрец", { 25, 45, 60 } }, { "ebosh", "Чернокнижник", { 25 } } }) do
        local lvl = self:Level(rc[1])
        for _, m in ipairs(rc[3]) do
            if lvl >= m then add(rc[2] .. " " .. m, "got")
            else add(rc[2] .. " " .. m, "now", ("ещё %d ур."):format(m - lvl), m - lvl <= 5) end
        end
    end
    for _, pk in ipairs(ns.PROF_ORDER) do
        local p = self:ProfInfo(pk)
        for _, m in ipairs({ 150, 225, 300 }) do
            local name = p.label .. " " .. m
            if p.skill >= m then add(name, "got")
            elseif CapFor(p.level) >= m then add(name, "now", ("ещё %d навыка"):format(m - p.skill), true)
            else add(name, "lock", ("с %d ур. %s"):format(m == 150 and 10 or m == 225 and 20 or 35, ns.ROSTER[p.who].short)) end
        end
    end
    local list = self:Spelunker()
    local miss = 0
    for _, d in ipairs(list) do if not d.done then miss = miss + 1 end end
    if miss == 0 then add("Novice Spelunker", "got")
    elseif self:Level("osh") >= 13 then add("Novice Spelunker", "now", ("осталось %d из %d"):format(miss, #list), true)
    else add("Novice Spelunker", "lock", "с 13 ур. Osh") end
    return out
end

------------------------------------------------------------------------
-- События
------------------------------------------------------------------------
local pending
function KL:Refresh()
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        KL:Snapshot()
        if ns.UI then ns.UI:Refresh() end
    end)
end

local EVENTS = {
    "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION",
    "PLAYER_UPDATE_RESTING", "PLAYER_MONEY", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL",
    "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN",
    "ZONE_CHANGED_NEW_AREA", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE",
    "PLAYER_CAMPING", "PLAYER_LOGOUT", "GET_ITEM_INFO_RECEIVED",
}

KL:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then InitDB() end
        return
    end
    if event == "PLAYER_LOGIN" then
        if not DB then InitDB() end
        for _, ev in ipairs(EVENTS) do pcall(self.RegisterEvent, self, ev) end
        self:Snapshot()
        if ns.UI then ns.UI:Create() end
        self:Refresh()
        return
    end
    if not DB then return end
    if event == "MAIL_SHOW" then
        self.atMailbox = true
    elseif event == "MAIL_CLOSED" then
        self.atMailbox = false
    elseif event == "MAIL_INBOX_UPDATE" then
        local role = self:Role()
        if role and GetInboxNumItems then DB.chars[role].inbox = GetInboxNumItems() or 0 end
    elseif event == "PLAYER_CAMPING" then
        if self:Role() and not (IsResting and IsResting()) and ns.UI then
            ns.UI:Toast("Ты вне зоны отдыха: рестед здесь не копится. Дойди до таверны или города")
        end
    elseif event == "PLAYER_LOGOUT" then
        self:Snapshot()
        return
    end
    self:Refresh()
end)
KL:RegisterEvent("ADDON_LOADED")
KL:RegisterEvent("PLAYER_LOGIN")

------------------------------------------------------------------------
-- /kl
------------------------------------------------------------------------
SLASH_KARASUOSHILEGACY1 = "/kl"
SlashCmdList["KARASUOSHILEGACY"] = function(msg)
    msg = lower(msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "strip" or msg == "полоска" then
        ns.UI:ToggleStrip()
    elseif msg == "reset" then
        DB.ui = {}
        ns.UI:ApplyPositions()
        print("|cfff0c35aKarasuoshi Legacy:|r позиции сброшены")
    elseif msg == "debug" then
        KL:Snapshot()
        for _, k in ipairs(ns.ROSTER_ORDER) do
            local c = DB.chars[k]
            print(("|cfff0c35a%s|r ур.%s рестед %s%% (оценка %d%%) золото %s палочка %s к отправке %s писем %s"):format(
                k, tostring(c.level), tostring(c.restPct), KL:Rest(k), tostring(c.gold), tostring(c.wand), tostring(c.toSend), tostring(c.inbox)))
            for pk, v in pairs(c.profs or {}) do print("   " .. pk .. " = " .. v) end
        end
        print("Роль сейчас: " .. tostring(KL:Role()) .. ", этап: " .. KL:CurrentStage().title)
    else
        ns.UI:Toggle()
    end
end
