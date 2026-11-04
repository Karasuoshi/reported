-- Karasuoshi Rested Buff
-- Keeps track of every XP / rested buff, reminds you when one is missing,
-- and gives you clickable panels to fix it (eat, sleeping bag, campfire...).
-- WoW Forever (client 1.60.x, Interface 16001). Also runs on Classic Era.

local ADDON, ns = ...
ns = ns or {}

local KRB = CreateFrame("Frame", "KarasuoshiRestedBuffCore")
ns.KRB = KRB
_G.KarasuoshiRestedBuff = KRB

KRB.version = "1.8.0"
local PREFIX = "|cff7fd4ffKarasuoshi Rested Buff|r: "

local floor, format, find, lower = math.floor, string.format, string.find, string.lower
local tinsert, tconcat = table.insert, table.concat

------------------------------------------------------------------------
-- Defaults
------------------------------------------------------------------------
local DEFAULTS = {
    enabled        = true,   -- reminders on
    showFrame      = true,   -- panel visible
    locked         = false,
    scale          = 1,
    width          = 280,
    iconSize       = 30,     -- compact icon bar
    vertical       = false,  -- groups as columns instead of rows
    hideNA         = false,  -- hide greyed-out (unavailable) icons
    restOverlay    = true,   -- big "don't move" notice over your character while eating / sleeping / by the fire
    overlayY       = 170,    -- its height above the screen centre
    point          = { "TOP", "TOP", 0, -140 },
    interval       = 90,     -- repeat reminder every N sec
    warnBefore     = 60,     -- warn N sec before a buff runs out
    sound          = true,
    centerText     = true,
    chat           = true,
    silentInCombat = true,
    hideInCombat   = true,   -- hide the panel in combat (nothing to click there anyway)
    hideWhenAllOK  = false,
    hideAtMaxLevel = true,   -- XP buffs are pointless at max level
    strictFood     = false,  -- true: Well Fed only counts if its tooltip mentions experience
    tentThreshold  = 5,      -- Camp Tent tops rested up to 5% of a level
    snoozeUntil    = 0,
    checks         = { food = true, bag = true, tent = true, fire = true, camp = false, sit = true, profs = true, emotes = true },
    favEmotes      = {},     -- emote tokens pinned to the top of the emote panel
    extraIDs       = { food = {}, bag = {}, tent = {}, camp = {} },
    custom         = {},     -- { {label=, id=, name=}, ... }
}

------------------------------------------------------------------------
-- What we track. IDs come from WoW Forever beta data and may change:
-- names are matched too, and you can add your own IDs with /krb addid.
------------------------------------------------------------------------
local DATA = {
    food = {
        label = "XP Food",
        ids   = { [1243969] = true, [1248422] = true },   -- 1248422: WoW Forever "Well Fed" (seen in game)
        names = { "well fed" },
        eatingNames = { ["food"] = true, ["food & drink"] = true },
        xpWords = { "experience" },
        wellFedWords = { "well fed" },
        icon  = "Interface\\Icons\\Spell_Misc_Food",
    },
    bag = {
        label = "Cozy Sleeping Bag",
        maxPct = 3,           -- +1% per minute lying in the bag, up to 3%
        ids   = { [429959] = true },
        names = { "sleeping bag", "well rested", "well-rested" },
        item  = 211527,
        icon  = "Interface\\Icons\\INV_Misc_Bag_10",
    },
    tent = {
        label = "Rested XP",
        ids   = { [1229432] = true, [1229451] = true, [1307230] = true },
        names = { "boosted rest", "camp tent" },
        placeNames = { "camp tent" },
        icon  = "Interface\\Icons\\INV_Misc_Rune_01",
        cooldown = 3600,
    },
    fire = {
        label = "Campfire",
        spells = { 818 },              -- Basic Campfire
        names  = { "campfire" },       -- spellbook names that count as a campfire
        tiers  = {
            { words = { "expert" },     prio = 3 },
            { words = { "journeyman" }, prio = 2, reagents = { 11291 } },          -- Star Wood
            { words = { "basic" },      prio = 1, reagents = { 4470, 4471 } },     -- Simple Wood, Flint and Tinder
        },
        reagentNames = { [4470] = "Simple Wood", [4471] = "Flint and Tinder", [11291] = "Star Wood" },
        kitWords  = { "campfire" },     -- WoW Forever: "Basic Campfire Kit" etc. are items placed from bags
        cookingIDs = { 2550, 3102, 3413, 18260 },
        burnTime  = 600,                -- a basic campfire burns ~10 min
        cozyIDs   = { [7353] = true, [1283391] = true },  -- Cozy Fire / WoW Forever "Campfire Nearby"
        cozyNames = { "cozy fire", "campfire nearby" },
        icon  = "Interface\\Icons\\Spell_Fire_Fire",
    },
    camp = {
        label = "Camp Buff",
        ids   = {
            [1229741] = true, -- Camp Benefits
            [1230564] = true, [1230171] = true, [1230643] = true, [1230117] = true,
            [1229745] = true, [1229705] = true, [1230161] = true, [1229517] = true,
            [1263425] = true,
        },
        names = { "camp benefits" },
        timerWords = { "camp", "fire", "warm", "cozy", "rest", "sit", "hearth" },
        icon  = "Interface\\Icons\\INV_Misc_Bag_EnchantedRunecloth",
    },
}
KRB.DATA = DATA

-- Camp items per profession (WoW Forever). Tier 1 is taught at skill 20 by the
-- profession trainer ("Camping 101: <profession>"), tiers 2-3 are dungeon blueprints.
-- One camp item per player per fire, and all camp items share a 1-hour cooldown.
local PROFS = {
    { name = "First Aid", window = "First Aid", icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
      buff = "Stamina (weaker Power Word: Fortitude)", ids = { [1230117] = true },
      objects = { { "First Aid Kit", 20 }, { "Toxin Study", 140 }, { "Plague Doctor's Laboratory", 300 } } },
    { name = "Alchemy", window = "Alchemy", icon = "Interface\\Icons\\Trade_Alchemy",
      buff = "Mana every 5 sec", ids = { [1230564] = true },
      objects = { { "Mana Well", 20 }, { "Fermenter", 140 }, { "Alchemy Laboratory", 300 } } },
    { name = "Blacksmithing", window = "Blacksmithing", icon = "Interface\\Icons\\Trade_BlackSmithing",
      buff = "Strength (weaker Strength of Earth Totem)", ids = { [1230171] = true },
      objects = { { "Sharpening Wheel", 20 }, { "Anvil", 140 }, { "Master Forge", 300 } } },
    { name = "Enchanting", window = "Enchanting", icon = "Interface\\Icons\\Trade_Engraving",
      buff = "Armor, stats and resistances (weaker Mark of the Wild)", ids = { [1230643] = true },
      objects = { { "Enchanted Lute", 20 }, { "Arcane Salvager", 140 }, { "Arcane Forge", 300 } } },
    { name = "Engineering", window = "Engineering", icon = "Interface\\Icons\\Trade_Engineering",
      buff = "Vendor at camp (sell / buy reagents)", ids = { [1230656] = true },
      objects = { { "Reagent Bot", 20 }, { "Repair Bot", 140 }, { "Anarchist's Workbench", 300 } } },
    { name = "Herbalism", icon = "Interface\\Icons\\Trade_Herbalism",
      buff = "Intellect (weaker Arcane Intellect)", ids = { [1229705] = true },
      objects = { { "Incense Candle", 20 }, { "Greenhouse", 140 }, { "Seed Hybridizer", 300 } } },
    { name = "Leatherworking", window = "Leatherworking", icon = "Interface\\Icons\\Trade_LeatherWorking",
      buff = "Rested XP up to 5% of a level", ids = { [1229432] = true },
      objects = { { "Camp Tent", 20 }, { "Tanning Rack", 140 }, { "Sewing Machine", 300 } } },
    { name = "Mining", icon = "Interface\\Icons\\Trade_Mining",
      buff = "Melee attack power (weaker Battle Shout)", ids = { [1230161] = true },
      objects = { { "Lodestone", 20 }, { "Rock Garden", 140 }, { "Molten Foundry", 300 } } },
    { name = "Skinning", icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
      buff = "2% critical strike", ids = { [1229517] = true },
      objects = { { "Camp Chair", 20 }, { "Field Guide", 140 }, { "Trapper's Workbench", 300 } } },
    { name = "Tailoring", window = "Tailoring", icon = "Interface\\Icons\\Trade_Tailoring",
      buff = "Spirit (weaker Divine Spirit)", ids = { [1263425] = true },
      objects = { { "Faction Banner", 20 }, { "Spinning Wheel", 140 }, { "Loom", 300 } } },
    { name = "Fishing", icon = "Interface\\Icons\\Trade_Fishing",
      buff = "8% all stats (weaker Blessing of Kings)", ids = { [1229745] = true },
      objects = { { "Fish Bowl", 20 }, { "Fishing Rack", 140 }, { "Fishing Hut", 300 } } },
    { name = "Cooking", window = "Cooking", icon = "Interface\\Icons\\INV_Misc_Food_15",
      buff = "Feast / oven at camp", ids = {}, minShow = 140,
      objects = { { "Cookie's Feast", 140 }, { "Iron Oven", 300 } } },
}
local PROF_BY_NAME, CAMP_INDEX = {}, {}
for _, def in ipairs(PROFS) do
    def.key = def.name:gsub("[^%w]", "")
    PROF_BY_NAME[lower(def.name)] = def
    for i, o in ipairs(def.objects) do
        o.name, o.skill, o.tier = o[1], o[2], i
        CAMP_INDEX[lower(o.name)] = { def = def, obj = o }
    end
end
KRB.PROFS = PROFS
KRB.CAMP_COOLDOWN = 3600

local function CampLookup(name)
    if not name then return nil end
    local l = lower(name)
    local hit = CAMP_INDEX[l]
    if hit then return hit end
    local base = l:match("^(.-) kit$")             -- "Fish Bowl Kit" style names
    if base and CAMP_INDEX[base] then return CAMP_INDEX[base] end
    return nil
end

KRB.ORDER = { "food", "bag", "tent", "fire", "profs", "camp" }
KRB.XP_GROUP = { food = true, bag = true, tent = true }
KRB.CHECK_LABELS = {
    food = "XP food", bag = "Cozy Sleeping Bag", tent = "Rested XP / Camp Tent",
    fire = "Campfire button", camp = "Camp buff", sit = "Sit button", profs = "Profession camp items",
    emotes = "Emote button",
}

------------------------------------------------------------------------
-- Utils / API wrappers (work on both old and new client APIs)
------------------------------------------------------------------------
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end
KRB.Print = Print

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

local function FormatTime(sec)
    sec = floor((sec or 0) + 0.5)
    if sec >= 3600 then
        return format("%dh %02dm", floor(sec / 3600), floor((sec % 3600) / 60))
    elseif sec >= 60 then
        return format("%dm %02ds", floor(sec / 60), sec % 60)
    end
    return format("%ds", sec)
end
KRB.FormatTime = FormatTime

local function ContainsAny(text, list)
    if not text then return false end
    local l = lower(text)
    for i = 1, #list do
        if find(l, lower(list[i]), 1, true) then return true end
    end
    return false
end
KRB.ContainsAny = ContainsAny

local function ItemCount(itemID)
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(itemID) or 0 end
    if GetItemCount then return GetItemCount(itemID) or 0 end
    return 0
end

local function ItemCooldownLeft(itemID)
    local start, duration
    if C_Container and C_Container.GetItemCooldown then
        start, duration = C_Container.GetItemCooldown(itemID)
    elseif GetItemCooldown then
        start, duration = GetItemCooldown(itemID)
    end
    if start and duration and start > 0 and duration > 1.5 then
        local left = start + duration - GetTime()
        if left > 0 then return left end
    end
    return 0
end

local function ItemCD(itemID)
    local start, duration
    if C_Container and C_Container.GetItemCooldown then
        start, duration = C_Container.GetItemCooldown(itemID)
    elseif GetItemCooldown then
        start, duration = GetItemCooldown(itemID)
    end
    if start and duration and start > 0 and duration > 1.5 then
        local left = start + duration - GetTime()
        if left > 0 then return left, duration end
    end
    return 0, 0
end

local function ItemInfo(itemID)
    local name, _, _, _, minLevel, _, _, _, _, icon
    if C_Item and C_Item.GetItemInfo then
        name, _, _, _, minLevel, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    elseif GetItemInfo then
        name, _, _, _, minLevel, _, _, _, _, icon = GetItemInfo(itemID)
    end
    return name, minLevel, icon
end

local function ItemClassID(itemID)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not f then return nil end
    local _, _, _, _, icon, classID, subClassID = f(itemID)
    return classID, subClassID, icon
end

local function ItemIcon(itemID, fallback)
    local icon
    if C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(itemID) end
    if not icon and GetItemIcon then icon = GetItemIcon(itemID) end
    return icon or fallback
end

local function IsItemUsable(itemID)
    local f = (C_Item and C_Item.IsUsableItem) or IsUsableItem
    if not f then return true end
    local usable = f(itemID)
    return usable and true or false
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        return info and info.name
    end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    if GetSpellTexture then return GetSpellTexture(id) end
end

local function IsSpellKnownW(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    return false
end

local function IsSpellUsableW(spell)
    if C_Spell and C_Spell.IsSpellUsable then
        local ok = C_Spell.IsSpellUsable(spell)
        return ok and true or false
    end
    if IsUsableSpell then
        local ok = IsUsableSpell(spell)
        return ok and true or false
    end
    return true
end

local function SpellCooldownLeft(spell)
    local start, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(spell)
        if cd then start, duration = cd.startTime, cd.duration end
    elseif GetSpellCooldown then
        start, duration = GetSpellCooldown(spell)
    end
    if start and duration and start > 0 and duration > 1.5 then
        local left = start + duration - GetTime()
        if left > 0 then return left end
    end
    return 0
end

local function MaxLevel()
    if GetMaxPlayerLevel then
        local m = GetMaxPlayerLevel()
        if m and m > 0 then return m end
    end
    return MAX_PLAYER_LEVEL or 60
end

local function IsXPRelevant()
    if not KRB.db.hideAtMaxLevel then return true end
    if (UnitLevel("player") or 1) >= MaxLevel() then return false end
    if IsXPUserDisabled and IsXPUserDisabled() then return false end
    return true
end

------------------------------------------------------------------------
-- Hidden tooltip for reading buff / item text
------------------------------------------------------------------------
local scanTip
local function TooltipText(setter, ...)
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "KarasuoshiRestedBuffScanTip", nil, "GameTooltipTemplate")
    end
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip[setter](scanTip, ...)
    local parts = {}
    for i = 1, (scanTip:NumLines() or 0) do
        local fs = _G["KarasuoshiRestedBuffScanTipTextLeft" .. i]
        local t = fs and fs:GetText()
        if t and t ~= "" then parts[#parts + 1] = t end
    end
    scanTip:Hide()
    if #parts == 0 then return nil end
    return tconcat(parts, "\n")
end

------------------------------------------------------------------------
-- Player auras
------------------------------------------------------------------------
local auras = {}

-- WoW Forever runs on the 12.x client: in combat aura data is "secret" and
-- addons must not touch it. We never read auras then (and pcall just in case).
local function IsSecret(v)
    return issecretvalue and v ~= nil and issecretvalue(v) or false
end

local function AurasLocked()
    if (InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player") then return true end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and secret == true then return true end
    end
    return false
end
KRB.AurasLocked = AurasLocked

local function ReadAuras(list)
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        for i = 1, 80 do
            local skip = false
            if C_Secrets and C_Secrets.ShouldUnitAuraIndexBeSecret then
                local ok, secret = pcall(C_Secrets.ShouldUnitAuraIndexBeSecret, "player", i, filter)
                skip = ok and secret == true
            end
            local name, icon, count, duration, expires, spellId
            if not skip then
                if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                    local a = C_UnitAuras.GetAuraDataByIndex("player", i, filter)
                    if not a then break end
                    name, icon, count, duration, expires, spellId =
                        a.name, a.icon, a.applications, a.duration, a.expirationTime, a.spellId
                elseif UnitAura then
                    local _
                    name, icon, count, _, duration, expires, _, _, _, spellId = UnitAura("player", i, filter)
                    if not name then break end
                else
                    break
                end
                if not (IsSecret(name) or IsSecret(spellId) or IsSecret(duration) or IsSecret(expires) or IsSecret(count)) then
                    list[#list + 1] = {
                        index = i, filter = filter, name = name, icon = icon,
                        count = count or 0, duration = duration or 0, expires = expires or 0, spellId = spellId,
                    }
                end
            end
        end
    end
end

-- returns true if the aura list is fresh, false if auras can't be read right now
local function ScanAuras()
    if AurasLocked() then return false end
    local list = {}
    local ok = pcall(ReadAuras, list)
    if not ok then return false end
    for i = #auras, 1, -1 do auras[i] = nil end
    for i = 1, #list do auras[i] = list[i] end
    return true
end
KRB.auras = auras
KRB.ScanAuras = ScanAuras

local xpTextCache = {}
local function AuraMentionsXP(a)
    local key = a.spellId or a.name
    if xpTextCache[key] ~= nil then return xpTextCache[key] end
    local text = TooltipText(a.filter == "HARMFUL" and "SetUnitDebuff" or "SetUnitBuff", "player", a.index)
    if not text then return false end -- tooltip not loaded yet: don't cache
    local r = ContainsAny(text, DATA.food.xpWords)
    xpTextCache[key] = r
    return r
end

-- Find an aura of a category: by spell ID first, then by name (timed auras only)
local function FindAura(cat, opts)
    local def = DATA[cat]
    local extra = (KRB.db.extraIDs[cat]) or {}
    local includeDebuffs = opts and opts.debuffs
    local anyDuration = opts and opts.anyDuration
    for _, a in ipairs(auras) do
        if (includeDebuffs or a.filter == "HELPFUL") and a.spellId
            and (def.ids[a.spellId] or extra[a.spellId]) then
            return a, true
        end
    end
    for _, a in ipairs(auras) do
        if (includeDebuffs or a.filter == "HELPFUL")
            and (anyDuration or (a.duration and a.duration > 0))
            and ContainsAny(a.name, def.names) then
            return a, false
        end
    end
end
KRB.FindAura = FindAura

local function TimeLeft(a)
    if a and a.expires and a.expires > 0 then
        local left = a.expires - GetTime()
        if left > 0 then return left end
        return 0
    end
end

local function NearFire()
    local def = DATA.fire
    local cozyName = SpellName(7353)
    for _, a in ipairs(auras) do
        if a.filter == "HELPFUL" then
            if (a.spellId and def.cozyIDs[a.spellId]) or ContainsAny(a.name, def.cozyNames)
                or (cozyName and a.name == cozyName) then
                return true
            end
        end
    end
    return false
end

------------------------------------------------------------------------
-- Bags: Well Fed food, Camp Tent item
------------------------------------------------------------------------
local bags = { foods = {}, tentItem = nil, kits = {}, byName = {}, camp = {} }
local bagsDirty = true
local foodCache = {}  -- itemID -> true/false

local function NumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
    if GetContainerNumSlots then return GetContainerNumSlots(bag) or 0 end
    return 0
end

local function SlotItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then return info.itemID, info.stackCount or 1 end
        return nil
    end
    if GetContainerItemInfo then
        local _, count, _, _, _, _, link, _, _, itemID = GetContainerItemInfo(bag, slot)
        if not itemID and link then itemID = tonumber(link:match("item:(%d+)")) end
        return itemID, count or 1
    end
end

local function ItemLoaded(itemID)
    if C_Item and C_Item.IsItemDataCachedByID then
        local ok, cached = pcall(C_Item.IsItemDataCachedByID, itemID)
        if ok and cached == false then
            if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
            return false
        end
    end
    return true
end

local function IsWellFedFood(itemID, bag, slot)
    if foodCache[itemID] ~= nil then return foodCache[itemID] end
    local classID, subClassID = ItemClassID(itemID)
    if classID and classID ~= 0 then foodCache[itemID] = false return false end -- not a consumable
    local text = TooltipText("SetBagItem", bag, slot)
    local r = text and (ContainsAny(text, DATA.food.wellFedWords)
        or (subClassID == 5 and ContainsAny(text, DATA.food.xpWords))) or false
    -- only remember "not food" once the item and its whole tooltip are loaded
    if r or (text and ItemLoaded(itemID) and select(2, text:gsub("\n", "")) >= 1) then
        foodCache[itemID] = r
    end
    return r
end

-- item data arrived later: forget "not food" verdicts so they're checked again
local function ForgetFoodMisses()
    for id, v in pairs(foodCache) do
        if v == false then foodCache[id] = nil end
    end
end

local FireTier -- defined below

local function ScanBags()
    local found, kits, byName, camp = {}, {}, {}, {}
    bags.tentItem = nil
    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, lastBag do
        for slot = 1, NumSlots(bag) do
            local itemID, count = SlotItem(bag, slot)
            if itemID then
                local iname = ItemInfo(itemID)
                if iname then
                    local key = lower(iname)
                    byName[key] = (byName[key] or 0) + (count or 1)
                    local hit = CampLookup(iname)
                    if hit then
                        local c = camp[lower(hit.obj.name)]
                        if not c then
                            c = { id = itemID, name = iname, count = 0, icon = ItemIcon(itemID) }
                            camp[lower(hit.obj.name)] = c
                        end
                        c.count = c.count + (count or 1)
                    end
                    if ContainsAny(iname, DATA.fire.kitWords) and not find(key, "recipe", 1, true) then
                        local k = kits[itemID]
                        if not k then
                            k = { id = itemID, name = iname, count = 0, tier = FireTier(iname), icon = ItemIcon(itemID) }
                            kits[itemID] = k
                        end
                        k.count = k.count + (count or 1)
                    end
                end
                if IsWellFedFood(itemID, bag, slot) then
                    local f = found[itemID]
                    if not f then
                        local name, minLevel, icon = ItemInfo(itemID)
                        f = { id = itemID, count = 0, name = name or ("item " .. itemID),
                              minLevel = minLevel or 0, icon = icon or ItemIcon(itemID) }
                        found[itemID] = f
                    end
                    f.count = f.count + (count or 1)
                end
                if not bags.tentItem then
                    local name = ItemInfo(itemID)
                    if name and ContainsAny(name, DATA.tent.placeNames) then bags.tentItem = itemID end
                end
            end
        end
    end
    local list = {}
    for _, f in pairs(found) do list[#list + 1] = f end
    table.sort(list, function(a, b)
        if a.minLevel ~= b.minLevel then return a.minLevel > b.minLevel end
        if a.count ~= b.count then return a.count > b.count end
        return a.id < b.id
    end)
    bags.foods = list
    local klist = {}
    for _, k in pairs(kits) do klist[#klist + 1] = k end
    table.sort(klist, function(a, b) return (a.tier.prio or 0) > (b.tier.prio or 0) end)
    bags.kits = klist
    bags.byName = byName
    bags.camp = camp
    bagsDirty = false
end
KRB.bags = bags

local function BestFood()
    if bagsDirty then ScanBags() end
    local pref = KRB.db.preferredFood
    if pref then
        for _, f in ipairs(bags.foods) do
            if f.id == pref then return f end
        end
    end
    -- level check only: IsUsableItem says "no" for items that aren't loaded yet
    local level = UnitLevel("player") or 1
    for _, f in ipairs(bags.foods) do
        if (f.minLevel or 0) <= level then return f end
    end
end

------------------------------------------------------------------------
-- Spellbook: campfire spells, Camp Tent placement
------------------------------------------------------------------------
local book = { fires = {}, tent = nil, cooking = nil, names = {}, camp = {}, profs = {} }

local function ScanProfessions()
    local found, list = {}, {}
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, (GetNumSkillLines() or 0) do
            local name, isHeader, _, rank = GetSkillLineInfo(i)
            local def = name and not isHeader and PROF_BY_NAME[lower(name)]
            if def then found[def.name] = { def = def, rank = rank or 0 } end
        end
    end
    if GetProfessions and GetProfessionInfo then
        local p = { GetProfessions() }
        for i = 1, 6 do
            if p[i] then
                local name, icon, rank = GetProfessionInfo(p[i])
                local def = name and PROF_BY_NAME[lower(name)]
                if def then found[def.name] = { def = def, rank = rank or 0, icon = icon } end
            end
        end
    end
    for _, def in ipairs(PROFS) do
        if found[def.name] then list[#list + 1] = found[def.name] end
    end
    return list
end
local bookDirty = true

local function IterateSpellbook(fn)
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        for tab = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(tab)
            if info then
                for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
                    if item and item.name and not item.isPassive then fn(item.name, item.spellID) end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo then
        local bt = BOOKTYPE_SPELL or "spell"
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, numSpells = GetSpellTabInfo(tab)
            for i = (offset or 0) + 1, (offset or 0) + (numSpells or 0) do
                local name = GetSpellBookItemName(i, bt)
                local _, id = GetSpellBookItemInfo(i, bt)
                if name then fn(name, id) end
            end
        end
    end
end

function FireTier(name, id)
    if id == 818 then return DATA.fire.tiers[3] end
    for _, t in ipairs(DATA.fire.tiers) do
        if ContainsAny(name, t.words) then return t end
    end
    return { prio = 0 }
end

local function ScanBook()
    local fires, seen = {}, {}
    book.tent = nil
    book.cooking = nil
    local names, campSpells = {}, {}
    IterateSpellbook(function(name, id)
        names[lower(name)] = name
        if CAMP_INDEX[lower(name)] then campSpells[lower(name)] = { name = name, id = id } end
        if lower(name) == "cooking" then book.cooking = name end
        if ContainsAny(name, DATA.fire.names) and not seen[name] then
            seen[name] = true
            fires[#fires + 1] = { name = name, id = id, tier = FireTier(name, id) }
        end
        if not book.tent and ContainsAny(name, DATA.tent.placeNames) then
            book.tent = { name = name, id = id }
        end
    end)
    for _, id in ipairs(DATA.fire.spells) do
        local name = SpellName(id)
        if name and not seen[name] and IsSpellKnownW(id) then
            seen[name] = true
            fires[#fires + 1] = { name = name, id = id, tier = FireTier(name, id) }
        end
    end
    table.sort(fires, function(a, b) return (a.tier.prio or 0) > (b.tier.prio or 0) end)
    book.fires = fires
    book.names = names
    book.camp = campSpells
    book.profs = ScanProfessions()
    if not book.cooking then
        for _, p in ipairs(book.profs) do
            if p.def.name == "Cooking" then book.cooking = "Cooking" end
        end
    end
    if not book.cooking then
        -- not in the spellbook: check skill lines / professions / known ranks
        if GetNumSkillLines and GetSkillLineInfo then
            for i = 1, (GetNumSkillLines() or 0) do
                local name, isHeader = GetSkillLineInfo(i)
                if name and not isHeader and lower(name) == "cooking" then book.cooking = name break end
            end
        end
        if not book.cooking and GetProfessions and GetProfessionInfo then
            local p = { GetProfessions() }
            for i = 1, 6 do
                local name = p[i] and GetProfessionInfo(p[i])
                if name and lower(name) == "cooking" then book.cooking = name break end
            end
        end
        if not book.cooking then
            for _, id in ipairs(DATA.fire.cookingIDs) do
                if IsSpellKnownW(id) then book.cooking = SpellName(id) or "Cooking" break end
            end
        end
    end
    bookDirty = false
end
KRB.book = book

local function ReagentCount(itemID)
    if bagsDirty then ScanBags() end
    local n = ItemCount(itemID)
    local name = DATA.fire.reagentNames[itemID]
    local byName = name and bags.byName[lower(name)] or 0
    return math.max(n, byName)
end
KRB.ReagentCount = ReagentCount

local function MissingReagents(fire)
    local missing = {}
    for _, itemID in ipairs(fire.tier.reagents or {}) do
        if ReagentCount(itemID) < 1 then
            missing[#missing + 1] = ItemInfo(itemID) or DATA.fire.reagentNames[itemID] or ("item " .. itemID)
        end
    end
    return missing
end

local function ReagentSummary(fire)
    local parts = {}
    for _, itemID in ipairs(fire.tier.reagents or {}) do
        local name = ItemInfo(itemID) or DATA.fire.reagentNames[itemID] or ("item " .. itemID)
        parts[#parts + 1] = format("%s: %d", name, ReagentCount(itemID))
    end
    return tconcat(parts, ", ")
end

-- Best campfire the player can light right now (or the best known one + why not)
local function PickFire()
    if bookDirty then ScanBook() end
    local override = KRB.db.fireSpell
    local list = book.fires
    if override then
        list = { { name = SpellName(override) or tostring(override), id = tonumber(override), tier = { prio = 0 } } }
        if not tonumber(override) then list[1].name = override end
    end
    if #list == 0 then return nil, "not learned (Cooking)" end
    local firstReason
    for _, f in ipairs(list) do
        local miss = MissingReagents(f)
        local cd = SpellCooldownLeft(f.id or f.name)
        if #miss == 0 and cd == 0 and IsSpellUsableW(f.id or f.name) then
            return f, nil
        end
        if not firstReason then
            if cd > 0 then firstReason = "cooldown " .. FormatTime(cd)
            elseif #miss > 0 then firstReason = "need " .. tconcat(miss, ", ")
            else firstReason = "can't use right now" end
        end
    end
    return nil, firstReason, list[1]
end

-- Open profession window (Campfire Kits / camp items are crafted there)
function KRB:TradeOpenName()
    if not self.tradeOpen then return nil end
    local shown
    if TradeSkillFrame and TradeSkillFrame.IsShown then shown = TradeSkillFrame:IsShown() end
    if ProfessionsFrame and ProfessionsFrame.IsShown then shown = shown or ProfessionsFrame:IsShown() end
    if shown == false then return nil end
    local name
    if GetTradeSkillLine then name = GetTradeSkillLine() end
    if (not name or name == "UNKNOWN") and C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local info = C_TradeSkillUI.GetBaseProfessionInfo()
        name = info and info.professionName
    end
    return name and lower(name) or "?"
end

function KRB:CookingOpen()
    local n = self:TradeOpenName()
    return n == "cooking" or n == "?"
end

-- Find a recipe in the open profession window. match(name) -> priority number or nil
-- craftableOnly: skip recipes you can't make right now. Returns best, anyLearned
local function FindRecipe(match, craftableOnly)
    local best, anyLearned
    local function consider(e) if not best or e.prio > best.prio then best = e end end
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo then
        local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
        if ok and type(ids) == "table" then
            for _, id in ipairs(ids) do
                local info = C_TradeSkillUI.GetRecipeInfo(id)
                local prio = info and info.name and info.learned ~= false and match(info.name)
                if prio then
                    anyLearned = true
                    local n = info.numAvailable
                    if n == nil and C_TradeSkillUI.GetCraftableCount then n = C_TradeSkillUI.GetCraftableCount(id) end
                    if not craftableOnly or (n or 1) > 0 then
                        consider({ kind = "recipe", id = id, name = info.name, prio = prio })
                    end
                end
            end
        end
    end
    if not best and GetNumTradeSkills and GetTradeSkillInfo then
        for i = 1, (GetNumTradeSkills() or 0) do
            local name, kind, numAvailable = GetTradeSkillInfo(i)
            local prio = name and kind ~= "header" and kind ~= "subheader" and match(name)
            if prio then
                anyLearned = true
                if not craftableOnly or (numAvailable or 0) > 0 then
                    consider({ kind = "index", id = i, name = name, prio = prio })
                end
            end
        end
    end
    return best, anyLearned
end

local function FireRecipeMatch(name)
    if ContainsAny(name, DATA.fire.names) then return FireTier(name).prio or 0 end
end

local function FindCampfireRecipe()
    return (FindRecipe(FireRecipeMatch, true))
end
KRB.FindCampfireRecipe = FindCampfireRecipe

local function CraftRecipe(r, where)
    if not r then
        Print("nothing you can craft right now - check reagents, or press Create in the " .. (where or "profession") .. " window.")
        return
    end
    local ok, err
    if r.kind == "recipe" then
        ok, err = pcall(C_TradeSkillUI.CraftRecipe, r.id, 1)
    else
        if SelectTradeSkill then pcall(SelectTradeSkill, r.id) end
        ok, err = pcall(DoTradeSkill, r.id, 1)
    end
    if ok then
        Print("crafting " .. r.name .. "...")
    else
        Print("couldn't craft automatically (" .. tostring(err) .. ") - press Create in the " .. (where or "profession") .. " window.")
    end
end

function KRB:CraftCampfireKit()
    CraftRecipe(FindCampfireRecipe(), "Cooking")
end

------------------------------------------------------------------------
-- Resting: lying in the sleeping bag (+1% a minute up to 3%), eating
-- (10 sec to Well Fed) and sitting by the fire (1 min to camp buffs)
------------------------------------------------------------------------
KRB.bagState = { pct = 0 }
KRB.EAT_TIME = 10

local function AuraPercent(a)
    if not a then return nil end
    if a.count and a.count > 0 then return a.count end
    local text = TooltipText(a.filter == "HARMFUL" and "SetUnitDebuff" or "SetUnitBuff", "player", a.index)
    if text then
        local best
        for n in text:gmatch("(%d+)%%") do
            n = tonumber(n)
            if n and n <= 10 then best = n end
        end
        return best
    end
end

local function Applied(a)
    if a and a.duration and a.duration > 0 and a.expires and a.expires > 0 then return a.expires - a.duration end
end

local function FindWellFed()
    for _, a in ipairs(auras) do
        if a.filter == "HELPFUL" and ((a.spellId and DATA.food.ids[a.spellId]) or ContainsAny(a.name, DATA.food.names)) then
            return a
        end
    end
end

function KRB:BagUsed()
    local st = self.bagState
    st.lyingSince = GetTime()
    st.lastChange = GetTime()
    st.fullAt = nil
end

-- "you can get up" / "you got up too early" notices
function KRB:RestNotify(msg, isWarn)
    if not self.db then return end
    if isWarn and self.db.centerText and RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, "|cffff5555" .. msg .. "|r",
            ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.3, b = 0.3 })
    end
    if self.db.sound and PlaySound then
        if isWarn then PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
        else PlaySound((SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960, "Master") end
    end
    if self.db.chat then Print((isWarn and "|cffff5555" or "|cff66ff66") .. msg .. "|r") end
end

local function UpdateRestState()
    local now = GetTime()
    -- eating -> Well Fed
    local eating
    for _, a in ipairs(auras) do
        if a.filter == "HELPFUL" and DATA.food.eatingNames[lower(a.name)] then eating = a break end
    end
    if eating then
        if not KRB.eat then KRB.eat = { start = Applied(eating) or now } end
        local e, fed = KRB.eat, FindWellFed()
        if not e.fed and fed and (Applied(fed) or now) >= e.start - 1 then
            e.fed, e.fedAt = true, now
            KRB:RestNotify("Well Fed! You can get up.")
        end
    elseif KRB.eat then
        if KRB.eat.fed then KRB.fedFlashUntil = (KRB.eat.fedAt or now) + 4 end
        KRB.eat = nil
    end

    -- sleeping bag percent
    local st, MAX = KRB.bagState, DATA.bag.maxPct
    local a = FindAura("bag")
    local pct = 0
    if a then
        pct = AuraPercent(a)
        if pct == nil then
            pct = st.lyingSince and math.min(MAX, floor((now - st.lyingSince) / 60)) or MAX
        end
        pct = math.min(pct, MAX)
    end
    if pct < (st.pct or 0) then
        st.lyingSince = nil -- the bag buff went away / was replaced: not lying any more
    end
    if pct > (st.pct or 0) then
        st.lastChange = now
        if pct >= MAX then
            if st.lyingSince then KRB:RestNotify(format("Sleeping bag full: +%d%% XP. You can get up!", MAX)) end
            st.lyingSince = nil
            st.fullAt = now
        elseif not st.lyingSince then
            st.lyingSince = now - 1 -- it only grows while you lie in it
        end
    end
    st.pct = pct
    -- no progress for a long time: you probably stood up with a key
    if st.lyingSince and st.lastChange and now - st.lastChange > 80 then st.lyingSince = nil end
end

-- what to show on the "don't move" notice / Sit pill (pure: no aura reads)
function KRB:RestActivity()
    local now = GetTime()
    if self.eat and not self.eat.fed then
        local el = now - self.eat.start
        return { kind = "eat", progress = math.min(1, el / self.EAT_TIME), left = math.max(0, self.EAT_TIME - el) }
    end
    local st, MAX = self.bagState, DATA.bag.maxPct
    if st.lyingSince and (st.pct or 0) < MAX then
        local since = now - (st.lastChange or st.lyingSince)
        local pct = st.pct or 0
        return { kind = "bag", pct = pct, max = MAX,
                 progress = math.min(1, (pct + math.min(1, since / 60)) / MAX),
                 left = math.max(0, 60 - since), total = math.max(0, (MAX - pct) * 60 - since) }
    end
    local campOn = self.sitStart and (self.sitExplicit or self.fireActive)
    if campOn then
        local el = now - self.sitStart
        if el < self:SitNeed() then
            return { kind = "camp", progress = el / self:SitNeed(), left = self:SitNeed() - el }
        end
    end
    -- short "you can get up" flashes
    if (self.eat and self.eat.fed and now - (self.eat.fedAt or now) < 4) or (self.fedFlashUntil and now < self.fedFlashUntil) then
        return { kind = "eat", done = true, progress = 1 }
    end
    if st.fullAt and now - st.fullAt < 5 then return { kind = "bag", done = true, pct = MAX, max = MAX, progress = 1 } end
    if campOn and now - self.sitStart < self:SitNeed() + 5 then return { kind = "camp", done = true, progress = 1 } end
end

-- you moved / entered combat: warn if it was too early
function KRB:OnStandUp(reason)
    local now, warn = GetTime(), nil
    if self.eat and not self.eat.fed and now - self.eat.start < self.EAT_TIME then
        warn = "You got up before Well Fed - eat for 10 sec."
    end
    local st, MAX = self.bagState, DATA.bag.maxPct
    if not warn and st.lyingSince and (st.pct or 0) < MAX then
        warn = format("You got up early: sleeping bag only %d%% of %d%%.", st.pct or 0, MAX)
    end
    if not warn and self.sitStart and (self.sitExplicit or self.fireActive) and now - self.sitStart < self:SitNeed() then
        warn = "You got up before the camp buffs (sit 1 min by the fire)."
    end
    st.lyingSince = nil
    self.eat = nil
    self:StopSitting()
    if warn and reason == "move" then self:RestNotify(warn, true) end
end

------------------------------------------------------------------------
-- Where things can't be done: say it on the icon instead of a silent click
------------------------------------------------------------------------
local function PlaceBlocker()
    if UnitOnTaxi and UnitOnTaxi("player") then return "You're on a flight" end
    if IsMounted and IsMounted() then return "Dismount first" end
    if IsSwimming and IsSwimming() then return "Can't do that in water" end
    if IsIndoors and IsIndoors() then return "You're indoors - go outside" end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return "You're dead" end
end
KRB.PlaceBlocker = PlaceBlocker

local function RestBlocker()   -- sleeping bag: open world only
    if UnitOnTaxi and UnitOnTaxi("player") then return "You're on a flight" end
    if IsMounted and IsMounted() then return "Dismount first" end
    if IsSwimming and IsSwimming() then return "Can't do that in water" end
    if IsResting and IsResting() then return "Doesn't work in cities and inns" end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return "You're dead" end
end

local function EatBlocker()
    if UnitOnTaxi and UnitOnTaxi("player") then return "You're on a flight" end
    if IsMounted and IsMounted() then return "Dismount first" end
    if IsSwimming and IsSwimming() then return "Can't eat in water" end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return "You're dead" end
end

-- the game's own red error right after one of our clicks (e.g. "You can't do that here")
KRB.tileErrors = {}
function KRB:NoteClick(key, title)
    self.lastClick = { key = key, title = title, at = GetTime() }
end

function KRB:OnUIError(msg)
    local c = self.lastClick
    if not c or not msg or GetTime() - c.at > 2 then return end
    self.tileErrors[c.key] = { msg = msg, untilT = GetTime() + 12 }
    self.lastClick = nil
    Print("|cffff5555" .. (c.title or c.key) .. ": " .. msg .. "|r")
end

local function ApplyBlock(m, why)
    m.action, m.insecure, m.postClick = nil, nil, nil
    m.enabled = false
    m.blocked = why
    m.hint = why
end

------------------------------------------------------------------------
-- Checks -> panel models
-- model: key, state (ok/warn/missing/wait/ready/na), title, sub, icon,
--        action ({type=, item=/spell=/macrotext=}), enabled, hint, tip, short,
--        hidden, noAlert
------------------------------------------------------------------------
local SHORT = { food = "XP food", bag = "sleeping bag", camp = "camp buff" }

local function Timed(m, a, extraText)
    local left = TimeLeft(a)
    m.timer = left
    m.timerTotal = (a.duration and a.duration > 0) and a.duration or nil
    local stacks = (a.count and a.count > 1) and (" x" .. a.count) or ""
    if left and left <= KRB.db.warnBefore then
        m.state = "warn"
        m.sub = (a.name or "") .. stacks .. " - expiring in " .. FormatTime(left)
        m.short = (SHORT[m.key] or m.title) .. " (expiring)"
    else
        m.state = "ok"
        m.sub = (a.name or "") .. stacks .. ": " .. (left and FormatTime(left) or "active") .. (extraText or "")
    end
    return m
end

local Checks = {}

function Checks.food()
    local def = DATA.food
    local m = { key = "food", title = def.label, icon = def.icon, tip = {
        "Well Fed food gives +5% experience from kills.",
    } }
    if not IsXPRelevant() then m.hidden = true m.state = "na" return m end

    local food = BestFood()
    local eatWhy = food and EatBlocker()
    if food and eatWhy then
        m.icon = food.icon or def.icon
        m.count = food.count
        ApplyBlock(m, eatWhy)
    elseif food then
        m.action = { type = "item", item = "item:" .. food.id }
        m.enabled = true
        m.icon = food.icon or def.icon
        m.count = food.count
        m.hint = "Left-click: eat " .. food.name .. " (" .. food.count .. " left)"
        if #bags.foods > 1 then
            local names = {}
            for i, f in ipairs(bags.foods) do
                if i <= 5 then names[#names + 1] = f.name .. " x" .. f.count end
            end
            m.tip[#m.tip + 1] = "In bags: " .. tconcat(names, ", ")
        end
    else
        m.enabled = false
        m.hint = "No Well Fed food in your bags - cook some at a campfire."
        if bookDirty then ScanBook() end
        if book.cooking and not KRB:CookingOpen() then
            m.action = { type = "spell", spell = book.cooking }
            m.enabled = true
            m.hint = "Left-click: open Cooking to cook Well Fed food (needs a fire nearby)"
        end
    end

    local best, bestXP
    for _, a in ipairs(auras) do
        if a.filter == "HELPFUL" then
            if a.spellId and (def.ids[a.spellId] or KRB.db.extraIDs.food[a.spellId]) then
                best, bestXP = a, true
                break
            end
            if ContainsAny(a.name, def.names) then
                local xp = AuraMentionsXP(a)
                if not best or (xp and not bestXP) then best, bestXP = a, xp end
            end
        end
    end
    if best and (bestXP or not KRB.db.strictFood) then
        return Timed(m, best)
    end

    if KRB.eat and not KRB.eat.fed then
        local el = GetTime() - KRB.eat.start
        local left = math.max(0, KRB.EAT_TIME - el)
        m.state = "fill"
        m.barValue = math.min(1, el / KRB.EAT_TIME)
        m.badge = format("%ds", math.ceil(left))
        m.sub = format("Eating... Well Fed in %ds - don't move", math.ceil(left))
        return m
    end

    m.state = "missing"
    m.short = "XP food"
    if food and m.blocked then
        m.sub = m.blocked
    elseif food then
        m.sub = "Click to eat " .. food.name .. " (" .. food.count .. ")"
    elseif KRB:CookingOpen() then
        m.sub = "Cook some Well Fed food in the Cooking window"
    elseif m.enabled then
        m.sub = "No Well Fed food - click to open Cooking"
    elseif best then
        m.sub = "Well Fed without XP bonus - eat XP food"
    else
        m.sub = "No Well Fed food in bags"
    end
    return m
end

function Checks.bag()
    local def = DATA.bag
    local m = { key = "bag", title = def.label, icon = ItemIcon(def.item, def.icon), tip = {
        "+3% experience. Use it while resting at a camp.",
    } }
    if not IsXPRelevant() then m.hidden = true m.state = "na" return m end

    local have = ItemCount(def.item) > 0
    local cd, cdTotal = 0, 0
    if have then cd, cdTotal = ItemCD(def.item) end
    if cd > 0 then m.cdLeft, m.cdTotal, m.timer = cd, cdTotal, cd end
    if have then
        m.action = { type = "item", item = "item:" .. def.item }
        m.enabled = cd == 0
        m.hint = cd == 0 and "Left-click: use Cozy Sleeping Bag" or ("On cooldown: " .. FormatTime(cd))
    else
        m.enabled = false
        m.hint = "You don't have a Cozy Sleeping Bag (quest chain from level 14)."
    end

    if have and cd == 0 then
        m.postClick = function() KRB:BagUsed() end
        local why = RestBlocker()
        if why then ApplyBlock(m, why) end
    end
    local st, MAX = KRB.bagState, def.maxPct
    local a = FindAura("bag")
    local pct = st.pct or 0
    if st.lyingSince and pct < MAX then
        local since = GetTime() - (st.lastChange or st.lyingSince)
        m.state = "fill"
        m.barValue = math.min(1, (pct + math.min(1, since / 60)) / MAX)
        m.badge = pct .. "%"
        m.sub = format("Lying in the bag: %d%% of %d%% - don't move (next %% in %s)", pct, MAX, FormatTime(math.max(0, 60 - since)))
        return m
    end
    if a and pct < MAX then
        Timed(m, a)
        m.state = (have and cd == 0) and "warn" or "fill"
        m.badge = pct .. "%"
        m.barValue = pct / MAX
        m.sub = format("Only %d%% of %d%% - lie in the bag %d more min", pct, MAX, MAX - pct)
        m.short = format("sleeping bag only %d%%", pct)
        return m
    end
    if a then
        Timed(m, a)
        m.sub = format("+%d%% XP: %s", MAX, m.timer and FormatTime(m.timer) or "active")
        return m
    end

    if not have then
        m.state = "na"
        m.sub = "Not in your bags"
    elseif cd > 0 then
        m.state = "wait"
        m.sub = "Cooldown " .. FormatTime(cd)
    else
        m.state = "missing"
        m.sub = m.blocked or "Click to use (+3% XP)"
        m.short = "sleeping bag"
    end
    return m
end

function Checks.tent()
    local def = DATA.tent
    local m = { key = "tent", title = def.label, icon = def.icon, tip = {
        "Camp Tent (Leatherworking) tops your rested XP up to 5% of a level.",
        "Logging out in an inn or city fills rested XP 4x faster.",
    } }
    if not IsXPRelevant() then m.hidden = true m.state = "na" return m end

    local maxXP = UnitXPMax("player") or 0
    if maxXP <= 0 then m.hidden = true m.state = "na" return m end
    local rested = (GetXPExhaustion and GetXPExhaustion()) or 0
    local pct = rested / maxXP * 100
    local base = format("%d%% of a level", floor(pct + 0.5))
    if IsResting and IsResting() then base = base .. ", resting" end
    m.title = format("Rested XP: %d%%", floor(pct + 0.5))
    m.badge = format("%d%%", floor(pct + 0.5))
    m.barValue = math.min(pct / 100, 1)

    -- placing a tent (if you have one as a spell or item)
    if bookDirty then ScanBook() end
    if bagsDirty then ScanBags() end
    if book.tent then
        m.action = { type = "spell", spell = book.tent.name }
        m.enabled = true
        m.hint = "Left-click: place " .. book.tent.name
    elseif bags.tentItem then
        m.action = { type = "item", item = "item:" .. bags.tentItem }
        m.enabled = true
        m.hint = "Left-click: place Camp Tent"
    else
        m.enabled = false
        m.hint = "Find a camp with a Camp Tent (Leatherworking) and sit for 1 min."
    end

    -- remember when we saw the tent buff so we don't ask during its cooldown
    local seen = FindAura("tent", { debuffs = true, anyDuration = true })
    if seen and not KRB.tentPrevSeen then
        local applied = time()
        if seen.duration and seen.duration > 0 and seen.expires and seen.expires > 0 then
            applied = time() - floor(GetTime() - (seen.expires - seen.duration))
        end
        KRB.char.tentSeenAt = applied
    end
    KRB.tentPrevSeen = seen and true or false

    if pct >= KRB.db.tentThreshold then
        m.state = "ok"
        m.sub = base
        return m
    end
    local since = time() - (KRB.char.tentSeenAt or 0)
    if seen or since < def.cooldown then
        local left = def.cooldown - since
        if not seen and left > 0 then m.cdLeft, m.cdTotal = left, def.cooldown end
        m.state = "wait"
        m.sub = base .. ((not seen and left > 0) and (" - tent on cooldown ~" .. FormatTime(left)) or " - tent active")
        return m
    end
    m.state = "missing"
    m.sub = base .. " - use a Camp Tent at a campfire"
    m.short = format("Camp Tent (rested < %d%%)", KRB.db.tentThreshold)
    return m
end

function Checks.fire()
    local def = DATA.fire
    local m = { key = "fire", title = def.label, icon = def.icon, noAlert = true, tip = {
        "Campfire Kits are crafted in Cooking (Camping) and placed from your bags.",
        "Sit next to the fire for 1 minute to get the camp buffs (Camp Benefits, 1 hour).",
    } }
    if bagsDirty then ScanBags() end
    if bookDirty then ScanBook() end
    local wood, flint = ReagentCount(4470), ReagentCount(4471)
    local woodText = format("Simple Wood: %d", wood)
    m.tip[#m.tip + 1] = format("Simple Wood: %d   Flint and Tinder: %s", wood, flint > 0 and "yes" or "no")

    -- did our last click place a kit? (kit count went down)
    local kitTotal = 0
    for _, k in ipairs(bags.kits) do kitTotal = kitTotal + k.count end
    if KRB.kitClick then
        if kitTotal < KRB.kitClick.count then
            KRB.firePlacedAt = GetTime()
            KRB.kitClick = nil
        elseif GetTime() - KRB.kitClick.at > 20 then
            KRB.kitClick = nil
        end
    end
    local placedAgo = KRB.firePlacedAt and (GetTime() - KRB.firePlacedAt)
    local near = NearFire()
    if near and KRB.char then KRB.char.sawNearAura = true end
    local burning = not (KRB.char and KRB.char.sawNearAura) and placedAgo and placedAgo < def.burnTime

    local kit = bags.kits[1]
    local reason, ready
    if kit then
        -- 1) a Campfire Kit in the bags: place it
        local cd, cdTotal = ItemCD(kit.id)
        m.icon = kit.icon or def.icon
        m.count = kit.count
        if cd > 0 then m.cdLeft, m.cdTotal, m.timer = cd, cdTotal, cd end
        if cd > 0 then
            m.enabled = false
            reason = "Cooldown " .. FormatTime(cd)
            m.hint = "Campfire on cooldown: " .. FormatTime(cd)
        else
            m.action = { type = "item", item = "item:" .. kit.id }
            m.enabled = true
            m.hint = format("Left-click: place %s (%d in bags)", kit.name, kit.count)
            m.postClick = function() KRB.kitClick = { at = GetTime(), count = kitTotal } end
            ready = format("Click to place %s (%d)", kit.name, kit.count)
        end
    elseif #book.fires > 0 or KRB.db.fireSpell then
        -- 2) Classic-style campfire spell in the spellbook
        local fire, why, known = PickFire()
        local f = fire or known
        if f then m.icon = (f.id and SpellIcon(f.id)) or def.icon end
        if fire then
            m.action = { type = "spell", spell = fire.name }
            m.enabled = true
            m.hint = "Left-click: cast " .. fire.name
            ready = "Click to light: " .. fire.name
            if fire.tier and fire.tier.reagents then ready = ready .. " (" .. ReagentSummary(fire) .. ")" end
        else
            m.enabled = false
            reason = why and (why:sub(1, 1):upper() .. why:sub(2)) or "Not available"
            m.hint = "Can't light a fire: " .. (why or "?")
        end
    elseif book.cooking and KRB:CookingOpen() then
        -- 3) Cooking window is open: craft a kit
        if FindCampfireRecipe() then
            m.enabled = true
            m.insecure = function() KRB:CraftCampfireKit() end
            m.hint = "Left-click: craft a Campfire Kit"
            ready = "Click to craft a Campfire Kit (" .. woodText .. ")"
        else
            m.enabled = false
            reason = "Can't craft a kit: need Simple Wood + Flint and Tinder"
            m.hint = "Buy Simple Wood and Flint and Tinder from a Cooking trainer or supplies vendor."
        end
    elseif book.cooking then
        -- 4) no kit: open Cooking so the next click crafts one
        if wood < 1 or flint < 1 then
            local need = {}
            if wood < 1 then need[#need + 1] = "Simple Wood" end
            if flint < 1 then need[#need + 1] = "Flint and Tinder" end
            m.enabled = false
            reason = "No kit - need " .. tconcat(need, " + ")
            m.hint = "Buy " .. tconcat(need, " and ") .. " from a Cooking trainer or supplies vendor."
        else
            m.action = { type = "spell", spell = book.cooking }
            m.enabled = true
            m.hint = "Left-click: open Cooking (then click again to craft a kit)"
            ready = "No kit - click to open Cooking (" .. woodText .. ")"
        end
    else
        m.enabled = false
        reason = "Learn Cooking to make campfires"
        m.hint = "Campfire Kits come from the Cooking profession."
    end

    if (m.action and (m.action.type == "item" or m.action.type == "spell") and m.action.spell ~= book.cooking) then
        local why = PlaceBlocker()
        if why then
            ApplyBlock(m, why)
            ready = nil
            reason = "Can't light a fire: " .. why
        end
    end
    if near or burning then
        m.state = "ok"
        m.sub = near and "Fire nearby" or format("Fire placed %s ago (burns ~10 min)", FormatTime(placedAgo))
        return m
    end
    if ready then
        m.state = "ready"
        m.sub = ready
    else
        m.state = (reason and find(lower(reason), "cooldown", 1, true)) and "wait" or "na"
        m.sub = reason or "Not available"
    end
    return m
end

function Checks.camp()
    local def = DATA.camp
    local m = { key = "camp", title = def.label, icon = def.icon, tip = {
        "Sit next to a campfire for 1 minute to get the buffs of the camp objects around it (1 hour).",
        "Camp buffs don't stack with the matching class buffs.",
    } }
    m.action = { type = "macro", macrotext = "/sit" }
    m.enabled = true
    m.hint = "Left-click: sit down"
    local a = FindAura("camp")
    if a then return Timed(m, a) end
    m.state = "missing"
    m.sub = NearFire() and "Click to sit by the fire for 1 min" or "Light a fire and sit by it for 1 min"
    m.short = "camp buff"
    return m
end

-- one panel per profession you have: place / craft / learn its camp item
local function CampMatcher(def)
    return function(name)
        local hit = CampLookup(name)
        if hit and hit.def == def then return hit.obj.tier end
    end
end

local function CheckProf(p)
    local def, rank = p.def, p.rank or 0
    local m = { key = "prof_" .. def.key, noAlert = true, icon = p.icon or def.icon, tip = {} }
    if def.minShow and rank < def.minShow then
        local any = false
        for _, o in ipairs(def.objects) do if bags.camp[lower(o.name)] then any = true end end
        if not any then m.hidden = true m.state = "na" return m end
    end

    -- best camp item you actually have (bag item or spell), highest tier first
    local obj, item, spell
    for i = #def.objects, 1, -1 do
        local o = def.objects[i]
        local it, sp = bags.camp[lower(o.name)], book.camp[lower(o.name)]
        if it or sp then obj, item, spell = o, it, sp break end
    end
    if not obj then
        obj = def.objects[1]
        for _, o in ipairs(def.objects) do if rank >= o.skill then obj = o end end
        if KRB.char.campLearned and KRB.char.campLearned[def.name] then
            obj = def.objects[1]
        end
    end
    if item then m.icon = item.icon or m.icon; m.count = item.count end
    m.title = obj.name .. "  |cff8f8f8f" .. def.name .. " " .. rank .. "|r"
    m.tip = {
        def.name .. " " .. rank .. " - camp item: " .. obj.name,
        "Buff: " .. def.buff,
        "Place it next to a campfire, then sit for 1 min (Camp Benefits, 1 hour).",
        "One camp item per player per fire; all camp items share a 1-hour cooldown.",
    }

    -- placement tracking (our click -> item used / cooldown started)
    local cc = KRB.campClick
    if cc and cc.key == m.key then
        local nowCount = item and item.count or 0
        local cdNow = (item and ItemCooldownLeft(item.id)) or (spell and SpellCooldownLeft(spell.id or spell.name)) or 0
        if nowCount < cc.count or cdNow > 0 then
            KRB.char.campPlacedAt = time()
            KRB.char.campPlacedProf = def.name
            KRB.campClick = nil
        elseif GetTime() - cc.at > 20 then
            KRB.campClick = nil
        end
    end

    local cd, cdTotal = 0, 0
    if item then cd, cdTotal = ItemCD(item.id)
    elseif spell then cd = SpellCooldownLeft(spell.id or spell.name); cdTotal = KRB.CAMP_COOLDOWN end
    local sharedLeft = KRB.char.campPlacedAt and (KRB.CAMP_COOLDOWN - (time() - KRB.char.campPlacedAt)) or 0
    if cd <= 0 and sharedLeft > 0 then cd, cdTotal = sharedLeft, KRB.CAMP_COOLDOWN end
    if cd > 0 then m.cdLeft, m.cdTotal, m.timer = cd, math.max(cdTotal, cd), cd end

    local trade = KRB:TradeOpenName()
    local ready, reason
    local needFire = (item or spell) and KRB.char and KRB.char.sawNearAura and not NearFire()
    local placeWhy = (item or spell) and cd <= 0 and PlaceBlocker()
    if placeWhy then
        m.enabled = false
        reason = "Can't place it: " .. placeWhy
        m.hint = placeWhy
        needFire = true -- shows as "wait"
    elseif cd <= 0 and needFire then
        m.enabled = false
        m.state = "wait"
        reason = "Stand next to a campfire to place " .. ((item and item.name) or (spell and spell.name) or obj.name)
        m.hint = "Light a campfire first (Campfire icon), then place it right next to the fire."
    elseif cd > 0 then
        m.enabled = false
        reason = "Camp item cooldown " .. FormatTime(cd)
        m.hint = "All camp items share a 1-hour cooldown: " .. FormatTime(cd)
    elseif item then
        m.action = { type = "item", item = "item:" .. item.id }
        m.enabled = true
        m.hint = "Left-click: place " .. item.name .. " (" .. item.count .. " in bags)"
        ready = "Click to place " .. item.name .. (item.count > 1 and (" (" .. item.count .. ")") or "")
        local count = item.count
        m.postClick = function() KRB.campClick = { key = m.key, at = GetTime(), count = count } end
    elseif spell then
        m.action = { type = "spell", spell = spell.name }
        m.enabled = true
        m.hint = "Left-click: place " .. spell.name
        ready = "Click to place " .. spell.name
        m.postClick = function() KRB.campClick = { key = m.key, at = GetTime(), count = 0 } end
    elseif trade and def.window and trade == lower(def.window) then
        local r, learned = FindRecipe(CampMatcher(def), true)
        KRB.char.campLearned = KRB.char.campLearned or {}
        KRB.char.campLearned[def.name] = learned and true or false
        if r then
            m.enabled = true
            m.insecure = function() CraftRecipe(FindRecipe(CampMatcher(def), true), def.window) end
            m.hint = "Left-click: craft " .. r.name
            ready = "Click to craft " .. r.name
        elseif learned then
            m.enabled = false
            reason = "Missing reagents for " .. obj.name
            m.hint = "Check the reagents in the " .. def.window .. " window."
        else
            m.enabled = false
            reason = "Learn " .. obj.name .. " from your trainer"
            m.hint = "Quest \"Camping 101: " .. def.name .. "\" at your " .. def.name .. " trainer."
        end
    elseif rank < obj.skill then
        m.enabled = false
        reason = format("Needs %s %d (you have %d)", def.name, obj.skill, rank)
        m.hint = "At " .. obj.skill .. " skill your trainer teaches " .. obj.name .. " (Camping 101)."
    elseif KRB.char.campLearned and KRB.char.campLearned[def.name] == false then
        m.enabled = false
        reason = "Learn " .. obj.name .. " from your trainer"
        m.hint = "Quest \"Camping 101: " .. def.name .. "\" at your " .. def.name .. " trainer."
        if def.window and book.names[lower(def.window)] then
            m.action = { type = "spell", spell = book.names[lower(def.window)] }
            m.enabled = true
            m.hint = m.hint .. " Left-click: open " .. def.window .. " to re-check."
        end
    elseif def.window and book.names[lower(def.window)] then
        m.action = { type = "spell", spell = book.names[lower(def.window)] }
        m.enabled = true
        m.hint = "Left-click: open " .. def.window .. " (then click again to craft " .. obj.name .. ")"
        ready = "No " .. obj.name .. " - click to open " .. def.window
    else
        m.enabled = false
        reason = "Make a " .. obj.name .. " in your " .. def.name .. " window"
        m.hint = "Open " .. def.name .. " in your professions window and craft " .. obj.name .. "."
    end

    -- buff status
    local buff
    for _, a in ipairs(auras) do
        if a.filter == "HELPFUL" and ((a.spellId and def.ids[a.spellId]) or a.name == obj.name) then buff = a break end
    end
    local camp = FindAura("camp")
    local mine = KRB.char.campPlacedProf == def.name and sharedLeft > 0
    if buff then
        local left = TimeLeft(buff)
        m.state = "ok"
        m.timer = left
        m.timerTotal = (buff.duration and buff.duration > 0) and buff.duration or nil
        m.sub = buff.name .. ": " .. (left and FormatTime(left) or "active")
    elseif camp and mine then
        local left = TimeLeft(camp)
        m.state = "ok"
        m.timer = left
        m.timerTotal = (camp.duration and camp.duration > 0) and camp.duration or nil
        m.sub = "In Camp Benefits: " .. (left and FormatTime(left) or "active")
    elseif ready then
        m.state = "ready"
        m.sub = ready
    else
        m.state = (cd > 0 or needFire) and "wait" or "na"
        m.sub = reason or "Not available"
    end
    return m
end
KRB.CheckProf = CheckProf

local function CheckCustom(entry, i)
    local label = entry.label or entry.name or ("ID " .. tostring(entry.id))
    local m = { key = "custom" .. i, title = label, icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        tip = { "Your own tracked buff (/krb list)." } }
    local spellName = entry.id and SpellName(entry.id) or entry.name
    if entry.id then m.icon = SpellIcon(entry.id) or m.icon end
    if spellName and ((entry.id and IsSpellKnownW(entry.id)) or (not entry.id and IsSpellUsableW(spellName))) then
        m.action = { type = "spell", spell = spellName }
        m.enabled = true
        m.hint = "Left-click: cast " .. spellName
    else
        m.enabled = false
    end
    for _, a in ipairs(auras) do
        if a.filter == "HELPFUL" then
            if (entry.id and a.spellId == entry.id) or (entry.name and ContainsAny(a.name, { entry.name }))
                or (spellName and a.name == spellName) then
                return Timed(m, a)
            end
        end
    end
    m.state = "missing"
    m.sub = m.enabled and "Missing - click to cast" or "Missing"
    m.short = label
    return m
end

function KRB:Evaluate()
    if not ScanAuras() then return nil end
    UpdateRestState()
    local results = {}
    for _, cat in ipairs(KRB.ORDER) do
        if self.db.checks[cat] then
            if cat == "profs" then
                if bagsDirty then ScanBags() end
                if bookDirty then ScanBook() end
                for _, p in ipairs(book.profs) do
                    local r = CheckProf(p)
                    r.group = "buff"
                    results[#results + 1] = r
                end
            else
                local r = Checks[cat]()
                r.group = KRB.XP_GROUP[cat] and "xp" or "buff"
                results[#results + 1] = r
            end
        end
    end
    for i, entry in ipairs(self.db.custom) do
        local r = CheckCustom(entry, i)
        r.group = "buff"
        results[#results + 1] = r
    end
    local now = GetTime()
    for _, r in ipairs(results) do
        local e = self.tileErrors[r.key]
        if e and now < e.untilT and r.state ~= "ok" then
            r.err = e.msg
            r.sub = e.msg
            r.hint = "The game said: " .. e.msg
        elseif e and now >= e.untilT then
            self.tileErrors[r.key] = nil
        end
    end
    return results
end

------------------------------------------------------------------------
-- Reminders
------------------------------------------------------------------------
KRB.lastStates = {}
KRB.lastAlert = 0
KRB.pending = false
KRB.readyAt = 0

function KRB:IsSnoozed()
    return (self.db.snoozeUntil or 0) > time()
end

function KRB:InCombat()
    return (InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player")
end

function KRB:CanAlert()
    if not self.db.enabled or self:IsSnoozed() then return false end
    if GetTime() < self.readyAt then return false end
    if self.db.silentInCombat and self:InCombat() then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
    if UnitOnTaxi and UnitOnTaxi("player") then return false end
    return true
end

function KRB:Alert(missing, isTest)
    local list = tconcat(missing, ", ")
    if self.db.centerText then
        local msg = "|cffff9933Missing:|r " .. list
        if RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.5, b = 0 })
        elseif UIErrorsFrame then
            UIErrorsFrame:AddMessage(msg, 1, 0.6, 0.2)
        end
    end
    if self.db.sound and PlaySound then
        PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
    end
    if self.db.chat then
        Print((isTest and "[test] " or "") .. "missing: |cffffd100" .. list .. "|r - click the panel to fix it")
    end
    if ns.UI and ns.UI.Flash then ns.UI:Flash() end
    self.lastAlert = GetTime()
    self.pending = false
end

------------------------------------------------------------------------
-- Sitting by the fire (Sit button timer)
------------------------------------------------------------------------
KRB.SIT_TIME = 60 -- sit next to a fire for 1 minute to get camp buffs

-- length of the current sit: the game's own countdown buff if we see it, else 1 min
function KRB:SitNeed()
    return self.sitDur or self.SIT_TIME
end

-- WoW Forever shows its own short countdown buff while you sit by a fire
-- (fire icon, ~1 min). Find it so our timer matches the game exactly.
local function FindCampTimer()
    local now = GetTime()
    local known = KRB.char and KRB.char.campTimerId
    for _, a in ipairs(auras) do
        if a.filter == "HELPFUL" and a.duration and a.duration >= 20 and a.duration <= 180
            and a.expires and a.expires > now then
            if known and a.spellId == known then return a end
            local l = lower(a.name or "")
            if not DATA.food.eatingNames[l] and not ContainsAny(a.name, DATA.bag.names)
                and not ContainsAny(a.name, DATA.food.names) and ContainsAny(a.name, DATA.camp.timerWords) then
                return a
            end
        end
    end
end

function KRB:StartSitting(at, explicit)
    if self.sitStart and not explicit then return end
    self.sitStart = at or GetTime()
    self.sitDur = nil
    self.sitExplicit = explicit and true or false
    self.campNotified = false
    self.campEarned = false
    if ns.UI and ns.UI.UpdateSitBar then ns.UI:UpdateSitBar() end
end

function KRB:StopSitting()
    if not self.sitStart then return end
    self.sitStart = nil
    self.sitDur = nil
    self.sitExplicit = false
    self.campEarned = false
    if ns.UI and ns.UI.UpdateSitBar then ns.UI:UpdateSitBar() end
end

local function UpdateSitState()
    -- eating means you're sitting too
    if not KRB.sitStart then
        for _, a in ipairs(auras) do
            if a.filter == "HELPFUL" and DATA.food.eatingNames[lower(a.name)] then
                local at = GetTime()
                if a.duration and a.duration > 0 and a.expires and a.expires > 0 then at = a.expires - a.duration end
                KRB:StartSitting(at)
                break
            end
        end
    end
    -- camp buff refreshed while sitting = earned
    if KRB.sitStart and not KRB.campEarned then
        local a = FindAura("camp")
        if a and a.duration and a.duration > 0 and a.expires and a.expires > 0
            and (a.expires - a.duration) >= KRB.sitStart - 2 then
            KRB.campEarned = true
        end
    end
    local placed = KRB.firePlacedAt and (GetTime() - KRB.firePlacedAt) < DATA.fire.burnTime
    local near = NearFire()
    if near and KRB.char then KRB.char.sawNearAura = true end
    local reliable = KRB.char and KRB.char.sawNearAura
    KRB.fireActive = near or (not reliable and placed) or false
    local ct = FindCampTimer()
    if ct then
        -- the game is counting: use its start and length
        KRB.sitStart = ct.expires - ct.duration
        KRB.sitDur = ct.duration
        KRB.sitExplicit = true
        KRB.fireActive = true
        KRB.campTimerAura = { name = ct.name, id = ct.spellId, dur = ct.duration }
        if KRB.char and ct.spellId and not KRB.char.campTimerId then KRB.char.campTimerId = ct.spellId end
    end
    if KRB.sitStart and not KRB.campNotified and (KRB.sitExplicit or KRB.fireActive)
        and GetTime() - KRB.sitStart >= KRB:SitNeed() then
        KRB.campNotified = true
        KRB:RestNotify("1 minute by the fire - camp buffs are yours. You can get up.")
    end
end

function KRB:Update()
    if not self.db then return end
    -- nothing is checked in combat: buffs are secret there, and you can't eat or camp anyway
    if AurasLocked() then self.pausedInCombat = true return end
    local ok, results = pcall(self.Evaluate, self)
    if not ok then
        if not self.evalErrorShown then
            self.evalErrorShown = true
            Print("couldn't read your buffs (" .. tostring(results) .. "). Will retry.")
        end
        return
    end
    if not results then return end
    self.pausedInCombat = false
    self.results = results
    UpdateSitState()

    local missing, newly = {}, false
    for _, r in ipairs(results) do
        local bad = not r.noAlert and not r.hidden and (r.state == "missing" or r.state == "warn")
        if bad then
            missing[#missing + 1] = r.short or r.title
            if self.lastStates[r.key] ~= r.state then newly = true end
        end
        self.lastStates[r.key] = r.state
    end
    self.missingCount = #missing

    if #missing == 0 then
        self.pending = false
    elseif newly then
        self.pending = true
    end

    if #missing > 0 and self:CanAlert() then
        if self.pending or (GetTime() - self.lastAlert) >= self.db.interval then
            self:Alert(missing)
        end
    end

    if ns.UI then ns.UI:Render(results, #missing) end
end

function KRB:Snooze(minutes)
    minutes = tonumber(minutes) or 15
    if minutes <= 0 then
        self.db.snoozeUntil = 0
        Print("reminders are back on.")
    else
        self.db.snoozeUntil = time() + floor(minutes * 60)
        Print(format("reminders snoozed for %d min.", minutes))
    end
    self:Update()
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local dirty = true
local elapsedAcc = 0

local function OnUpdate(_, elapsed)
    elapsedAcc = elapsedAcc + elapsed
    if elapsedAcc >= 1 or (dirty and elapsedAcc >= 0.2) then
        elapsedAcc = 0
        dirty = false
        KRB:Update()
    end
end

local function SafeRegister(ev)
    pcall(KRB.RegisterEvent, KRB, ev)
end

local BAG_EVENTS = {
    BAG_UPDATE_DELAYED = true, BAG_UPDATE = true, GET_ITEM_INFO_RECEIVED = true,
    ITEM_DATA_LOAD_RESULT = true, PLAYER_LEVEL_UP = true,
}
local BOOK_EVENTS = {
    SPELLS_CHANGED = true, LEARNED_SPELL_IN_TAB = true, SKILL_LINES_CHANGED = true,
    CHAT_MSG_SKILL = true,
}

KRB:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        KarasuoshiRestedBuffDB = CopyDefaults(DEFAULTS, KarasuoshiRestedBuffDB)
        KarasuoshiRestedBuffCharDB = KarasuoshiRestedBuffCharDB or { tentSeenAt = 0 }
        self.db = KarasuoshiRestedBuffDB
        if (self.db.styleVersion or 0) < 2 then   -- switched to the "Minimal" look
            self.db.iconSize = 30
            self.db.styleVersion = 2
        end
        self.char = KarasuoshiRestedBuffCharDB
        self:UnregisterEvent("ADDON_LOADED")
        return
    end
    if event == "PLAYER_LOGIN" then
        self.readyAt = GetTime() + 8 -- let buffs load after the loading screen
        if ns.UI then
            ns.UI:Create()
            ns.UI:CreateOptions()
        end
        self:SetScript("OnUpdate", OnUpdate)
        Print("loaded. Commands: |cffffd100/krb|r")
        return
    end
    if event == "UNIT_AURA" and arg1 ~= "player" then return end
    if event == "UI_ERROR_MESSAGE" then
        local msg = (type(arg2) == "string" and arg2) or (type(arg1) == "string" and arg1) or nil
        self:OnUIError(msg)
        return
    end
    if event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then ForgetFoodMisses() end
    if event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED" or event == "PLAYER_MOUNT_DISPLAY_CHANGED" then dirty = true end
    if event == "PLAYER_STARTED_MOVING" then self:OnStandUp("move") end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_DEAD" then self:OnStandUp("combat") end
    if event == "TRADE_SKILL_SHOW" then self.tradeOpen = true end
    if event == "TRADE_SKILL_CLOSE" then self.tradeOpen = false end
    if BAG_EVENTS[event] then bagsDirty = true end
    if BOOK_EVENTS[event] or event == "PLAYER_LEVEL_UP" then bookDirty = true end
    if event == "PLAYER_ENTERING_WORLD" then
        self.readyAt = math.max(self.readyAt, GetTime() + 5)
        bagsDirty, bookDirty = true, true
    end
    if event == "PLAYER_REGEN_ENABLED" then
        for _, st in pairs(self.lastStates) do
            if st == "missing" or st == "warn" then self.pending = true break end
        end
        if ns.UI and ns.UI.OnCombatEnd then ns.UI:OnCombatEnd() end
    end
    if event == "PLAYER_CAMPING" and self.db and self.db.enabled and IsXPRelevant()
        and not (IsResting and IsResting()) then
        local msg = "You're logging out outside an inn/city - rested XP builds 4x slower here."
        if RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame, "|cffff9933" .. msg .. "|r", ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.5, b = 0 })
        end
        Print(msg)
    end
    dirty = true
end)

KRB:RegisterEvent("ADDON_LOADED")
KRB:RegisterEvent("PLAYER_LOGIN")
for _, ev in ipairs({
    "PLAYER_ENTERING_WORLD", "UNIT_AURA", "PLAYER_UPDATE_RESTING", "UPDATE_EXHAUSTION",
    "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "BAG_UPDATE", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN",
    "GET_ITEM_INFO_RECEIVED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "SKILL_LINES_CHANGED",
    "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_DEAD", "PLAYER_UNGHOST",
    "PLAYER_CONTROL_GAINED", "PLAYER_CAMPING", "CHAT_MSG_SKILL",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE",
    "PLAYER_STARTED_MOVING", "UI_ERROR_MESSAGE", "ITEM_DATA_LOAD_RESULT",
    "ZONE_CHANGED_INDOORS", "ZONE_CHANGED", "PLAYER_MOUNT_DISPLAY_CHANGED",
}) do
    SafeRegister(ev)
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
local CAT_ALIASES = {
    food = "food", bag = "bag", sleepingbag = "bag", tent = "tent", rested = "tent",
    fire = "fire", campfire = "fire", camp = "camp", sit = "sit",
    profs = "profs", professions = "profs", prof = "profs", emotes = "emotes", emote = "emotes",
}

local function OnOff(v) return v and "|cff40ff40on|r" or "|cffff4040off|r" end

local function Help()
    Print("v" .. KRB.version .. " - commands:")
    local lines = {
        "/krb status - what's active and what's missing",
        "/krb show | hide - show/hide the panel",
        "/krb lock | unlock - lock the panel in place",
        "/krb on | off - reminders on/off",
        "/krb toggle food|bag|tent|fire|camp|sit|profs|emotes - turn a panel on/off",
        "/krb snooze 15 - pause reminders for N minutes (0 = resume)",
        "/krb interval 90 - repeat reminder every N seconds",
        "/krb warn 60 - warn N seconds before a buff runs out",
        "/krb food <itemID> | reset - force a specific food for the food panel",
        "/krb fire <spellID or name> | reset - force a specific campfire spell",
        "/krb size 30, /krb scale 0.9 - icon size / overall scale",
        "/krb vertical on|off - stack the icons in a column",
        "/krb hidena on|off - hide greyed-out icons",
        "/krb emotes - open the emote panel (right-click an emote to pin it)",
        "/krb overlay on|off, /krb overlay 200 - 'don't move' notice over your character / its height",
        "/krb sound on|off, /krb strict on|off, /krb hideok on|off, /krb combat on|off",
        "/krb scan - list all your buffs with spell IDs",
        "/krb addid food|bag|tent|camp <ID> - add a spell ID to a category",
        "/krb add <spellID or name> - track your own buff (click casts it if you know it)",
        "/krb list, /krb del <n> - your own buffs",
        "/krb debug - what the addon sees (cooking, kits, reagents, food)",
        "/krb test - test reminder, /krb config - options, /krb reset - reset settings",
    }
    for _, l in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100" .. l .. "|r") end
end

local function SetBool(key, arg, label)
    if arg == "on" then KRB.db[key] = true
    elseif arg == "off" then KRB.db[key] = false
    else KRB.db[key] = not KRB.db[key] end
    Print(label .. ": " .. OnOff(KRB.db[key]))
end

SLASH_KARASUOSHIRESTEDBUFF1 = "/krb"
SLASH_KARASUOSHIRESTEDBUFF2 = "/karasuoshi"
SLASH_KARASUOSHIRESTEDBUFF3 = "/rested"
SlashCmdList["KARASUOSHIRESTEDBUFF"] = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = lower(cmd or "")
    local db = KRB.db
    if not db then return end

    if AurasLocked() and (cmd == "status" or cmd == "scan" or cmd == "debug") then
        Print("buffs can't be read in combat - try again after the fight.")
        return
    end
    if cmd == "" or cmd == "help" or cmd == "?" then
        Help()
    elseif cmd == "status" then
        KRB:Update()
        for _, r in ipairs(KRB.results or {}) do
            if not r.hidden then
                local c = (r.state == "ok" and "|cff40ff40") or (r.state == "missing" and "|cffff4040")
                    or (r.state == "warn" and "|cffffd100") or "|cff9999ff"
                DEFAULT_CHAT_FRAME:AddMessage("  " .. c .. (r.title or "") .. ": " .. (r.sub or "") .. "|r")
            end
        end
        if KRB:IsSnoozed() then
            DEFAULT_CHAT_FRAME:AddMessage("  snoozed for " .. FormatTime(db.snoozeUntil - time()))
        end
    elseif cmd == "show" then
        db.showFrame = true; Print("panel shown.")
    elseif cmd == "hide" then
        db.showFrame = false; Print("panel hidden (/krb show to bring it back).")
    elseif cmd == "lock" then
        db.locked = true; Print("panel locked.")
    elseif cmd == "unlock" then
        db.locked = false; Print("panel unlocked - drag it by the title.")
    elseif cmd == "on" then
        db.enabled = true; Print("reminders " .. OnOff(true))
    elseif cmd == "off" then
        db.enabled = false; Print("reminders " .. OnOff(false))
    elseif cmd == "toggle" then
        local cat = CAT_ALIASES[lower(rest)]
        if not cat then Print("use: food, bag, tent, fire, camp, sit, profs or emotes") return end
        db.checks[cat] = not db.checks[cat]
        Print(KRB.CHECK_LABELS[cat] .. ": " .. OnOff(db.checks[cat]))
    elseif cmd == "snooze" or cmd == "pause" then
        KRB:Snooze(tonumber(rest) or 15)
    elseif cmd == "interval" then
        local n = tonumber(rest)
        if n and n >= 10 then db.interval = n; Print("repeating every " .. n .. " sec.")
        else Print("give a number of seconds (10 or more).") end
    elseif cmd == "warn" then
        local n = tonumber(rest)
        if n and n >= 0 then db.warnBefore = n; Print("warning " .. n .. " sec before a buff runs out.")
        else Print("give a number of seconds.") end
    elseif cmd == "food" then
        if lower(rest) == "reset" or rest == "" then
            db.preferredFood = nil; Print("food panel picks the best Well Fed food automatically.")
        elseif tonumber(rest) then
            db.preferredFood = tonumber(rest); Print("food panel will use item " .. rest .. " when you have it.")
        end
        bagsDirty = true
    elseif cmd == "fire" then
        if lower(rest) == "reset" or rest == "" then
            db.fireSpell = nil; Print("campfire panel picks the best campfire automatically.")
        else
            db.fireSpell = tonumber(rest) or rest; Print("campfire panel will cast: " .. rest)
        end
    elseif cmd == "scale" then
        local n = tonumber(rest)
        if n and n >= 0.5 and n <= 2 then db.scale = n; if ns.UI then ns.UI:ApplyPosition() end; Print("scale " .. n)
        else Print("scale between 0.5 and 2") end
    elseif cmd == "size" or cmd == "width" then
        local n = tonumber(rest)
        if n and n >= 20 and n <= 64 then db.iconSize = floor(n); Print("icon size " .. floor(n))
        else Print("icon size between 20 and 64 (default 30)") end
    elseif cmd == "vertical" then
        SetBool("vertical", rest, "vertical layout")
    elseif cmd == "overlay" then
        local n = tonumber(rest)
        if n then
            db.overlayY = floor(n); Print("notice height " .. floor(n))
            if ns.UI and ns.UI.PlaceOverlay then ns.UI:PlaceOverlay() end
        else
            SetBool("restOverlay", rest, "'don't move' notice over your character")
        end
    elseif cmd == "emotes" or cmd == "emote" then
        if ns.UI and ns.UI.ToggleEmotes then ns.UI:ToggleEmotes() end
    elseif cmd == "hidena" then
        SetBool("hideNA", rest, "hide unavailable icons")
    elseif cmd == "sound" then
        SetBool("sound", rest, "sound")
    elseif cmd == "strict" then
        SetBool("strictFood", rest, "strict food check")
    elseif cmd == "hideok" then
        SetBool("hideWhenAllOK", rest, "hide panel when everything is up")
    elseif cmd == "combat" then
        SetBool("hideInCombat", rest, "hide panel in combat")
        if ns.UI then ns.UI:ApplyCombatVisibility() end
    elseif cmd == "scan" then
        ScanAuras()
        Print("your buffs and debuffs (IDs for /krb addid):")
        if #auras == 0 then DEFAULT_CHAT_FRAME:AddMessage("  none") end
        for _, a in ipairs(auras) do
            local left = TimeLeft(a)
            DEFAULT_CHAT_FRAME:AddMessage(format("  %s |cffffd100%s|r  ID: |cff7fd4ff%s|r  %s",
                a.filter == "HARMFUL" and "|cffff6060[debuff]|r" or "|cff60ff60[buff]|r",
                a.name, tostring(a.spellId or "?"), left and FormatTime(left) or "no timer"))
        end
    elseif cmd == "addid" then
        local c, id = rest:match("^(%S+)%s+(%d+)$")
        local cat = c and CAT_ALIASES[lower(c)]
        id = tonumber(id)
        if not cat or not id or not db.extraIDs[cat] then Print("example: /krb addid food 1243969") return end
        db.extraIDs[cat][id] = true
        Print(format("ID %d added to %s.", id, KRB.CHECK_LABELS[cat]))
    elseif cmd == "add" then
        if rest == "" then Print("example: /krb add 1243  or  /krb add Power Word: Fortitude") return end
        local id = tonumber(rest)
        if id then
            tinsert(db.custom, { id = id, label = SpellName(id) or ("ID " .. id) })
        else
            tinsert(db.custom, { name = rest, label = rest })
        end
        Print("now tracking: " .. (db.custom[#db.custom].label))
    elseif cmd == "del" or cmd == "remove" then
        local n = tonumber(rest)
        if n and db.custom[n] then
            local e = table.remove(db.custom, n)
            Print("removed: " .. (e.label or "?"))
        else
            Print("use a number from /krb list")
        end
    elseif cmd == "list" then
        Print("your own buffs:")
        if #db.custom == 0 then DEFAULT_CHAT_FRAME:AddMessage("  none (/krb add ...)") end
        for i, e in ipairs(db.custom) do
            DEFAULT_CHAT_FRAME:AddMessage(format("  %d. %s", i, e.label or e.name or tostring(e.id)))
        end
        for cat, set in pairs(db.extraIDs) do
            local ids = {}
            for id in pairs(set) do ids[#ids + 1] = tostring(id) end
            if #ids > 0 then
                DEFAULT_CHAT_FRAME:AddMessage("  extra IDs for " .. (KRB.CHECK_LABELS[cat] or cat) .. ": " .. tconcat(ids, ", "))
            end
        end
    elseif cmd == "debug" then
        bagsDirty, bookDirty = true, true
        ScanBags(); ScanBook()
        Print("debug v" .. KRB.version)
        local function line(t) DEFAULT_CHAT_FRAME:AddMessage("  " .. t) end
        line("Cooking known: " .. tostring(book.cooking or "no") .. "   Cooking window open: " .. tostring(KRB:CookingOpen()))
        line(format("Simple Wood: %d   Flint and Tinder: %d", ReagentCount(4470), ReagentCount(4471)))
        local kits = {}
        for _, k in ipairs(bags.kits) do kits[#kits + 1] = format("%s x%d (item %d)", k.name, k.count, k.id) end
        line("Campfire kits in bags: " .. (#kits > 0 and tconcat(kits, ", ") or "none"))
        local fires = {}
        for _, f in ipairs(book.fires) do fires[#fires + 1] = format("%s (%s)", f.name, tostring(f.id)) end
        line("Campfire spells in spellbook: " .. (#fires > 0 and tconcat(fires, ", ") or "none"))
        if KRB:CookingOpen() then
            local r = FindCampfireRecipe()
            line("Craftable campfire recipe: " .. (r and (r.name .. " [" .. r.kind .. " " .. tostring(r.id) .. "]") or "none"))
        end
        local foods = {}
        for _, f in ipairs(bags.foods) do foods[#foods + 1] = format("%s x%d (lvl %d)", f.name, f.count, f.minLevel or 0) end
        line("Well Fed food in bags: " .. (#foods > 0 and tconcat(foods, ", ") or "none"))
        line("Camp Tent item: " .. tostring(bags.tentItem or "none") .. "   Near fire: " .. tostring(NearFire()))
        local ct = KRB.campTimerAura
        line("Game's sit-by-fire timer: " .. (ct and format("%s (%s, %ds)", ct.name, tostring(ct.id), ct.dur) or "not seen yet"))
        local profs = {}
        for _, p in ipairs(book.profs) do profs[#profs + 1] = p.def.name .. " " .. tostring(p.rank) end
        line("Professions: " .. (#profs > 0 and tconcat(profs, ", ") or "none found"))
        local ci = {}
        for _, c in pairs(bags.camp) do ci[#ci + 1] = format("%s x%d (item %d)", c.name, c.count, c.id) end
        for _, c in pairs(book.camp) do ci[#ci + 1] = c.name .. " (spell)" end
        line("Camp items: " .. (#ci > 0 and tconcat(ci, ", ") or "none"))
        if KRB.char.campPlacedAt then
            line("Last camp item placed: " .. FormatTime(time() - KRB.char.campPlacedAt) .. " ago (" .. tostring(KRB.char.campPlacedProf) .. ")")
        end
        local trade = KRB:TradeOpenName()
        if trade then line("Open profession window: " .. trade) end
        line("Indoors: " .. tostring(IsIndoors and IsIndoors()) .. "   Resting: " .. tostring(IsResting and IsResting())
            .. "   Mounted: " .. tostring(IsMounted and IsMounted()) .. "   Swimming: " .. tostring(IsSwimming and IsSwimming()))
        local cons = {}
        for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
            for slot = 1, NumSlots(bag) do
                local id = SlotItem(bag, slot)
                local classID, sub = id and ItemClassID(id)
                if id and classID == 0 and sub == 5 then
                    cons[#cons + 1] = format("%s%s", ItemInfo(id) or ("item " .. id), foodCache[id] and "(+)" or "(-)")
                end
            end
        end
        line("Food & drink in bags ((+) = gives Well Fed): " .. (#cons > 0 and tconcat(cons, ", ") or "none"))
    elseif cmd == "test" then
        KRB:Alert({ "XP food", "sleeping bag" }, true)
    elseif cmd == "config" or cmd == "options" then
        if ns.UI then ns.UI:OpenOptions() end
    elseif cmd == "reset" then
        KarasuoshiRestedBuffDB = CopyDefaults(DEFAULTS, {})
        KRB.db = KarasuoshiRestedBuffDB
        if ns.UI then ns.UI:ApplyPosition() end
        Print("settings reset.")
    else
        Help()
    end
    KRB:Update()
end
