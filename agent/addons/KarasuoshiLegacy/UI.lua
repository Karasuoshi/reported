-- Karasuoshi Legacy: полоска на экране и окно /kl
local ADDON, ns = ...
local UI = {}
ns.UI = UI

local KL = ns.KL
local FLAT = "Interface\\Buttons\\WHITE8X8"
local EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local TMPL = BackdropTemplateMixin and "BackdropTemplate" or nil

local C = {
    gold  = { 0.94, 0.76, 0.35 }, ink  = { 0.93, 0.89, 0.80 }, dim = { 0.66, 0.60, 0.48 },
    green = { 0.49, 0.82, 0.50 }, amber = { 0.91, 0.69, 0.33 }, red = { 0.94, 0.54, 0.42 },
    blue  = { 0.47, 0.66, 0.94 },
}
local ST_COLOR = { ok = C.green, good = C.green, warn = C.amber, behind = C.amber, bad = C.red, lock = C.red, info = C.blue }
local function hex(c) return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255) end

local strip, win, toast
local tab = "now"
local WIN_W, PAD = 400, 12

local function Skin(f, alpha)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = FLAT, edgeFile = EDGE, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        f:SetBackdropColor(0.09, 0.075, 0.06, alpha or 0.94)
        f:SetBackdropBorderColor(0.54, 0.42, 0.18, 1)
    end
end

local function SavePos(f, key)
    local point, _, rel, x, y = f:GetPoint(1)
    ns.DB.ui[key] = { point = point, rel = rel, x = x, y = y }
end
local function LoadPos(f, key, dPoint, dX, dY)
    f:ClearAllPoints()
    local p = ns.DB.ui[key]
    if p and p.point then f:SetPoint(p.point, UIParent, p.rel or p.point, p.x or 0, p.y or 0)
    else f:SetPoint(dPoint, UIParent, dPoint, dX, dY) end
end

------------------------------------------------------------------------
-- Полоска
------------------------------------------------------------------------
local function CreateStrip()
    strip = CreateFrame("Button", "KarasuoshiLegacyStrip", UIParent, TMPL)
    strip:SetHeight(24)
    strip:SetFrameStrata("MEDIUM")
    strip:SetClampedToScreen(true)
    strip:SetMovable(true)
    strip:RegisterForDrag("LeftButton")
    strip:RegisterForClicks("LeftButtonUp")
    Skin(strip, 0.85)
    strip.text = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    strip.text:SetPoint("LEFT", 10, 0)
    strip.text:SetJustifyH("LEFT")
    strip.text:SetWordWrap(false)
    strip:SetScript("OnDragStart", function(self) self:StartMoving() end)
    strip:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos(self, "strip") end)
    strip:SetScript("OnClick", function() UI:Toggle() end)
    strip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Karasuoshi Legacy")
        GameTooltip:AddLine("Клик: окно /kl. Перетащить: двигать.", 1, 1, 1)
        GameTooltip:Show()
    end)
    strip:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

------------------------------------------------------------------------
-- Окно: строки из пула
------------------------------------------------------------------------
local rows, used = {}, 0
local content, scroll

local function GetRow()
    used = used + 1
    local r = rows[used]
    if not r then
        r = CreateFrame("Button", nil, content)
        r.fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.fs:SetJustifyH("LEFT")
        r.fs:SetWordWrap(true)
        r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.right:SetJustifyH("RIGHT")
        r.bar = CreateFrame("StatusBar", nil, r)
        r.bar:SetStatusBarTexture(FLAT)
        r.bar.bg = r.bar:CreateTexture(nil, "BACKGROUND")
        r.bar.bg:SetAllPoints()
        r.bar.bg:SetColorTexture(0.05, 0.04, 0.03, 1)
        r.hl = r:CreateTexture(nil, "HIGHLIGHT")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(1, 0.85, 0.4, 0.08)
        rows[used] = r
    end
    r:Show()
    return r
end

local y
-- o: text, right, color, font, indent, gap, bar = {value, max, color}, onClick
local function Row(o)
    local r = GetRow()
    local w = WIN_W - PAD * 2 - 24
    local indent = o.indent or 0
    y = y + (o.gap or 2)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    r:SetWidth(w)
    r.fs:SetFontObject(o.font or "GameFontHighlightSmall")
    r.fs:ClearAllPoints()
    r.fs:SetPoint("TOPLEFT", indent, -2)
    local rw = o.right and 160 or 0
    r.fs:SetWidth(w - indent - rw)
    r.fs:SetText(o.text or "")
    local c = o.color or C.ink
    r.fs:SetTextColor(c[1], c[2], c[3])
    r.right:ClearAllPoints()
    r.right:SetPoint("TOPRIGHT", 0, -2)
    r.right:SetWidth(math.max(rw - 6, 1))
    r.right:SetWordWrap(true)
    r.right:SetText(o.right or "")
    local rc = o.rightColor or C.dim
    r.right:SetTextColor(rc[1], rc[2], rc[3])
    local h = math.max(r.fs:GetStringHeight() or 12, o.right and (r.right:GetStringHeight() or 12) or 0) + 4
    if o.bar then
        r.bar:Show()
        r.bar:ClearAllPoints()
        r.bar:SetPoint("TOPLEFT", indent, -h)
        r.bar:SetSize(w - indent, 6)
        r.bar:SetMinMaxValues(0, o.bar.max or 1)
        r.bar:SetValue(math.min(o.bar.value or 0, o.bar.max or 1))
        local bc = o.bar.color or C.blue
        r.bar:SetStatusBarColor(bc[1], bc[2], bc[3])
        h = h + 10
    else
        r.bar:Hide()
    end
    r:SetHeight(h)
    if o.onClick then
        r:EnableMouse(true)
        r:SetScript("OnClick", o.onClick)
        r.hl:Show()
    else
        r:EnableMouse(false)
        r:SetScript("OnClick", nil)
        r.hl:Hide()
    end
    y = y + h
    return r
end
local function Head(text) Row({ text = text, color = C.dim, font = "GameFontNormalSmall", gap = 10 }) end

------------------------------------------------------------------------
-- Вкладки
------------------------------------------------------------------------
local TABS = { { "now", "Главная" }, { "chars", "Чары" }, { "legacy", "Легаси" }, { "dung", "Данжи" } }
local Build = {}

function Build.now()
    local role = KL:Role()
    if not role then
        Row({ text = "Этого персонажа нет в плане. План ведётся для Osh и Ebosh.", color = C.dim })
        return
    end
    local c = ns.DB.chars[role]
    Row({ text = ("%s  |cffa8987a%d ур. · %d з.|r"):format(ns.ROSTER[role].short, c.level or 0, c.gold or 0), color = C.gold, font = "GameFontNormal" })
    local rest = KL:Rest(role)
    Row({ text = ("рестед %d%%"):format(rest), color = C.dim, bar = { value = rest, max = 150, color = C.blue } })

    local tiles = KL:Tiles()
    if #tiles > 0 then
        y = y + 4
        for _, t in ipairs(tiles) do
            local col = ST_COLOR[t.st] or C.ink
            Row({ text = ("%s%s:|r %s"):format(hex(C.dim), t.label, t.val), right = t.sub, rightColor = col, color = col })
        end
    end

    local steps = KL:NextSteps(role, 3)
    local stTitle = steps[1] and steps[1].stage.title or ""
    Head((role == "osh" and "ЦЕЛИ" or "СМЕНА EBOSH") .. (stTitle ~= "" and (" · " .. stTitle) or ""))
    if #steps == 0 then Row({ text = "Все шаги закрыты", color = C.green }) end
    for _, s in ipairs(steps) do
        local manual = not s.auto
        Row({
            text = (manual and "[  ]  " or "•  ") .. s.t,
            indent = 2,
            onClick = manual and function() KL:ToggleCheck(s) end or nil,
        })
    end

    local alerts = KL:Alerts()
    if #alerts > 0 then
        y = y + 6
        for _, a in ipairs(alerts) do Row({ text = a.text, color = ST_COLOR[a.st] or C.ink }) end
    end

    local d, miss = KL:NearDungeon()
    if d then
        Row({
            text = ("%s рядом: %s · открыть Данжи"):format(d.name, miss > 0 and ("не взято квестов " .. miss) or "все квесты в журнале"),
            color = C.dim, gap = 8, onClick = function() UI:SetTab("dung") end,
        })
    end
end

local function ProfRow(pk)
    local p = KL:ProfInfo(pk)
    local col = ST_COLOR[p.st] or C.green
    Row({ text = ("%s  %d / %d"):format(p.label, p.skill, p.cap), right = p.msg, rightColor = col,
          bar = { value = p.skill, max = 300, color = col } })
end

function Build.chars()
    local DB = ns.DB
    for _, k in ipairs(ns.ROSTER_ORDER) do
        local c = DB.chars[k]
        Head(ns.ROSTER[k].short:upper())
        if not c.level then
            Row({ text = "Ещё не заходил этим персонажем с аддоном", color = C.dim })
        else
            Row({ text = ("Уровень %d · рестед %d%% · %d з."):format(c.level, KL:Rest(k), c.gold or 0) })
            if k == "osh" then
                local lag = c.level - (c.wand or 0)
                if c.level < 40 and (((c.wand or 0) == 0 and c.level >= 5) or ((c.wand or 0) > 0 and lag >= ns.LIMITS.wandLag)) then
                    Row({ text = (c.wand or 0) > 0 and ("Палочка %d ур., пора менять"):format(c.wand) or "Палочки нет, нужна от Ebosh", color = C.amber })
                end
                Row({ text = ("В сумках для Ebosh: %d"):format(c.toSend or 0) })
            else
                Row({ text = ("Писем в ящике: %d"):format(c.inbox or 0) })
            end
            for _, pk in ipairs(ns.PROF_ORDER) do
                if ns.PROFS[pk].who == k then ProfRow(pk) end
            end
        end
    end
end

function Build.legacy()
    local items = KL:LegacyItems()
    local got, now, later = {}, {}, {}
    for _, i in ipairs(items) do
        if i.st == "got" then got[#got + 1] = i
        elseif i.st == "now" and i.soon then now[#now + 1] = i
        else later[#later + 1] = i end
    end
    Row({ text = ("Заработано: %s%d|r   Можно добрать сейчас: %s%d|r"):format(hex(C.gold), #got, hex(C.gold), #now) })

    Head("ДОБРАТЬ СЕЙЧАС")
    if #now == 0 then Row({ text = "Всё доступное уже взято", color = C.dim }) end
    for _, i in ipairs(now) do Row({ text = i.name, right = i.how, rightColor = C.amber, color = C.amber }) end

    Head("NOVICE SPELUNKER · ПОДЗЕМЕЛЬЯ 15–25")
    local list, fromGame = KL:Spelunker()
    for _, d in ipairs(list) do
        Row({
            text = (d.done and "[x]  " or "[  ]  ") .. d.name,
            color = d.done and C.green or C.ink,
            onClick = (not fromGame) and function() KL:ToggleSpelunk(d.key) end or nil,
        })
    end
    if not fromGame then Row({ text = "Нажми, чтобы отметить пройденное. Прогресс общий на аккаунт.", color = C.dim }) end

    Head("ДАЛЬШЕ ПО УРОВНЯМ")
    for _, i in ipairs(later) do Row({ text = i.name, right = i.how, color = C.dim }) end

    Head("УЖЕ ЕСТЬ")
    if #got == 0 then Row({ text = "Пока ничего", color = C.dim }) end
    for _, i in ipairs(got) do Row({ text = i.name, color = C.green }) end
end

function Build.dung()
    local q = ns.DB.chars.osh.quests or {}
    local near = KL:NearDungeon()
    for _, d in ipairs(ns.DUNGEONS) do
        Head(("%s · %d–%d%s"):format(d.name:upper(), d.min, d.max, (near and near.key == d.key) and "  · РЯДОМ" or ""))
        for i, qq in ipairs(d.quests) do
            local st = q[d.key .. i]
            local label, col = "не взят", C.dim
            if st == "done" then label, col = "сдан", C.green elseif st == "log" then label, col = "в журнале", C.blue end
            Row({ text = qq.title .. "  " .. hex(C.dim) .. qq.where .. "|r", right = label, rightColor = col, indent = 2 })
        end
    end
end

------------------------------------------------------------------------
-- Окно
------------------------------------------------------------------------
local function CreateWindow()
    win = CreateFrame("Frame", "KarasuoshiLegacyWindow", UIParent, TMPL)
    win:SetSize(WIN_W, 480)
    win:SetFrameStrata("HIGH")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos(self, "win") end)
    Skin(win)
    win:Hide()
    tinsert(UISpecialFrames, "KarasuoshiLegacyWindow")

    win.title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    win.title:SetPoint("TOPLEFT", PAD, -10)
    win.title:SetText("Karasuoshi Legacy")
    win.title:SetTextColor(C.gold[1], C.gold[2], C.gold[3])

    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    win.tabs = {}
    local prev
    for _, t in ipairs(TABS) do
        local b = CreateFrame("Button", nil, win, TMPL)
        b:SetSize(84, 20)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", PAD, -32) end
        if b.SetBackdrop then
            b:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
            b:SetBackdropColor(0.05, 0.04, 0.03, 1)
            b:SetBackdropBorderColor(0.23, 0.19, 0.15, 1)
        end
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.fs:SetPoint("CENTER")
        b.fs:SetText(t[2])
        b.key = t[1]
        b:SetScript("OnClick", function() UI:SetTab(t[1]) end)
        win.tabs[#win.tabs + 1] = b
        prev = b
    end

    scroll = CreateFrame("ScrollFrame", "KarasuoshiLegacyScroll", win, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PAD, -60)
    scroll:SetPoint("BOTTOMRIGHT", -30, PAD)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIN_W - PAD * 2 - 24, 10)
    scroll:SetScrollChild(content)
end

local function CreateToast()
    toast = CreateFrame("Frame", nil, UIParent, TMPL)
    toast:SetSize(460, 40)
    toast:SetPoint("TOP", 0, -140)
    toast:SetFrameStrata("DIALOG")
    Skin(toast)
    toast.fs = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toast.fs:SetPoint("CENTER")
    toast.fs:SetWidth(440)
    toast.fs:SetTextColor(C.red[1], C.red[2], C.red[3])
    toast:Hide()
end

function UI:Toast(text)
    if not toast then return end
    toast.fs:SetText(text)
    toast:SetHeight((toast.fs:GetStringHeight() or 14) + 20)
    toast:Show()
    if toast.timer then toast.timer:Cancel() end
    toast.timer = C_Timer.NewTimer(6, function() toast:Hide() end)
end

function UI:SetTab(key)
    tab = key
    if win and not win:IsShown() then win:Show() end
    self:Refresh()
end

function UI:Toggle()
    if not win then return end
    if win:IsShown() then win:Hide() else win:Show(); self:Refresh() end
end

function UI:ToggleStrip()
    ns.DB.ui.stripHidden = not ns.DB.ui.stripHidden or nil
    self:Refresh()
end

function UI:ApplyPositions()
    if strip then LoadPos(strip, "strip", "TOP", 0, -24) end
    if win then LoadPos(win, "win", "CENTER", 300, 40) end
end

local function RefreshStrip()
    local role = KL:Role()
    if not role or ns.DB.ui.stripHidden then strip:Hide() return end
    local steps = KL:NextSteps(role, 1)
    local parts = {
        ("%s%s|r · рестед %d%%"):format(hex(C.gold), ns.ROSTER[role].short, KL:Rest(role)),
        "Дальше: " .. (steps[1] and steps[1].t or "этап закрыт"),
    }
    local alerts = KL:Alerts()
    if alerts[1] then parts[#parts + 1] = hex(ST_COLOR[alerts[1].st] or C.ink) .. alerts[1].text .. "|r" end
    strip.text:SetText(table.concat(parts, hex(C.dim) .. "  |  |r"))
    strip:SetWidth(math.min(760, (strip.text:GetStringWidth() or 200) + 20))
    strip.text:SetWidth(strip:GetWidth() - 20)
    strip:Show()
end

function UI:Refresh()
    if not strip then return end
    RefreshStrip()
    if not win or not win:IsShown() then return end
    for _, b in ipairs(win.tabs) do
        local on = b.key == tab
        b.fs:SetTextColor((on and C.gold or C.dim)[1], (on and C.gold or C.dim)[2], (on and C.gold or C.dim)[3])
    end
    for i = 1, used do rows[i]:Hide() end
    used, y = 0, 0
    Build[tab]()
    content:SetHeight(y + 8)
end

function UI:Create()
    if strip then return end
    CreateStrip()
    CreateWindow()
    CreateToast()
    self:ApplyPositions()
end
