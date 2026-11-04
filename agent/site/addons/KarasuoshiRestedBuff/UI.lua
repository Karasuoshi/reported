-- Karasuoshi Rested Buff - "Minimal" bar and options
-- One thin line, no background: XP buffs | camp & other buffs, a small time bar
-- under every icon, and a pill-shaped Sit button. Details live in the tooltips.

local ADDON, ns = ...
ns = ns or {}
local KRB = ns.KRB

local UI = {}
ns.UI = UI

local GAP    = 4    -- between icons
local BAR_H  = 4    -- time bar under each icon
local BAR_GAP = 3   -- icon -> bar
local LBL_H  = 12   -- group label above the icons
local SEP    = 11   -- space taken by a group separator
local PILL_W = 92   -- Sit pill width (min)
local EDGE   = 2    -- invisible padding around the bar

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local FLAT = "Interface\\Buttons\\WHITE8X8"

local anchor, panel
local tiles, tileCount = {}, 0
local labels, seps = {}, {}
local sitBtn

local GROUPS = {
    { key = "xp",   label = "XP",   name = "XP buffs",           color = { 0.73, 0.66, 1.00 },
      desc = "Food, Cozy Sleeping Bag, rested XP - everything that speeds up levelling." },
    { key = "buff", label = "CAMP", name = "Camp & other buffs", color = { 1.00, 0.70, 0.36 },
      desc = "Campfire, your profession camp items, camp buff and your own tracked buffs." },
}

local STATE_COLOR = {
    ok      = { 0.24, 0.81, 0.31 },
    warn    = { 1.00, 0.80, 0.00 },
    missing = { 1.00, 0.23, 0.23 },
    ready   = { 1.00, 0.60, 0.15 },
    wait    = { 0.44, 0.58, 0.90 },
    na      = { 0.33, 0.33, 0.33 },
    fill    = { 0.66, 0.58, 1.00 },   -- in progress: eating / lying in the bag
}

local function InLockdown()
    return InCombatLockdown and InCombatLockdown()
end

local function Size()
    return (KRB.db and KRB.db.iconSize) or 30
end

local function ShortTime(sec)
    if not sec or sec <= 0 then return "" end
    if sec >= 3600 then return string.format("%dh", math.floor(sec / 3600 + 0.5)) end
    if sec >= 60 then return string.format("%dm", math.floor(sec / 60 + 0.5)) end
    return string.format("%ds", math.floor(sec + 0.5))
end

local function MinSec(sec)
    sec = math.max(0, math.floor(sec + 0.5))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function SetFont(fs, size, flags)
    if fs.SetFont then fs:SetFont(FONT, size, flags or "OUTLINE") end
end

function UI:ApplyPosition()
    if not anchor or InLockdown() then return end
    local p = KRB.db.point or { "TOP", "TOP", 0, -140 }
    anchor:ClearAllPoints()
    anchor:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    anchor:SetScale(KRB.db.scale or 1)
end

function UI:ApplyCombatVisibility()
    if not anchor then return end
    if InLockdown() then self.combatVisPending = true return end
    self.combatVisPending = false
    if RegisterStateDriver then
        RegisterStateDriver(anchor, "visibility", KRB.db.hideInCombat and "[combat] hide; show" or "show")
    end
end

function UI:OnCombatEnd()
    if self.combatVisPending then self:ApplyCombatVisibility() end
end

------------------------------------------------------------------------
-- Moving: drag the XP / CAMP labels or any gap in the bar
------------------------------------------------------------------------
local function StartMove()
    if KRB.db.locked or InLockdown() then return end
    anchor:StartMoving()
    anchor.moving = true
end

local function StopMove()
    if not anchor.moving then return false end
    anchor:StopMovingOrSizing()
    anchor.moving = nil
    local point, _, relPoint, x, y = anchor:GetPoint()
    KRB.db.point = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) }
    return true
end

local function MenuClick(button)
    if button == "RightButton" then
        if IsShiftKeyDown() then KRB:Snooze(15) else UI:OpenOptions() end
    end
end

local function MakeDraggable(f)
    f:EnableMouse(true)
    f:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then StartMove() end end)
    f:SetScript("OnMouseUp", function(_, button) if not StopMove() then MenuClick(button) end end)
end

------------------------------------------------------------------------
-- Tooltips
------------------------------------------------------------------------
local function TipFooter()
    GameTooltip:AddLine("Right-click: options   Shift+Right-click: snooze 15 min", 0.55, 0.75, 1, true)
end

local function ShowTip(t)
    local m = t.model
    if not m then return end
    GameTooltip:SetOwner(t, "ANCHOR_BOTTOMRIGHT")
    local c = STATE_COLOR[m.state] or STATE_COLOR.na
    GameTooltip:AddLine(m.title or "", 1, 0.82, 0)
    if m.sub and m.sub ~= "" then GameTooltip:AddLine(m.sub, c[1], c[2], c[3], true) end
    for _, line in ipairs(m.tip or {}) do GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
    if m.hint then
        GameTooltip:AddLine(" ")
        if m.enabled then GameTooltip:AddLine(m.hint, 0.4, 1, 0.4, true)
        else GameTooltip:AddLine(m.hint, 1, 0.45, 0.45, true) end
    end
    TipFooter()
    GameTooltip:Show()
end

local function ShowLabelTip(f)
    local g = f.group
    GameTooltip:SetOwner(f, "ANCHOR_TOP")
    GameTooltip:AddLine(g.name, g.color[1], g.color[2], g.color[3])
    GameTooltip:AddLine(g.desc, 0.85, 0.85, 0.85, true)
    if KRB.db and not KRB.db.enabled then
        GameTooltip:AddLine("Reminders are off (/krb on)", 1, 0.4, 0.4)
    elseif KRB:IsSnoozed() then
        GameTooltip:AddLine("Snoozed for " .. KRB.FormatTime(KRB.db.snoozeUntil - time()), 0.6, 0.7, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Drag to move the bar   /krb - all commands", 0.8, 0.8, 0.8)
    TipFooter()
    GameTooltip:Show()
end

------------------------------------------------------------------------
-- Icons (secure: a click can eat / use an item / cast a spell)
------------------------------------------------------------------------
local function MakeEdges(parent)
    local e = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = parent:CreateTexture(nil, "OVERLAY")
        t:SetTexture(FLAT)
        e[side] = t
    end
    function e.Set(_, r, g, b, a, th)
        th = th or 1
        e.TOP:ClearAllPoints();    e.TOP:SetPoint("TOPLEFT", -th, th);       e.TOP:SetPoint("TOPRIGHT", th, th);        e.TOP:SetHeight(th)
        e.BOTTOM:ClearAllPoints(); e.BOTTOM:SetPoint("BOTTOMLEFT", -th, -th); e.BOTTOM:SetPoint("BOTTOMRIGHT", th, -th); e.BOTTOM:SetHeight(th)
        e.LEFT:ClearAllPoints();   e.LEFT:SetPoint("TOPLEFT", -th, th);      e.LEFT:SetPoint("BOTTOMLEFT", -th, -th);   e.LEFT:SetWidth(th)
        e.RIGHT:ClearAllPoints();  e.RIGHT:SetPoint("TOPRIGHT", th, th);     e.RIGHT:SetPoint("BOTTOMRIGHT", th, -th);  e.RIGHT:SetWidth(th)
        for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do e[side]:SetVertexColor(r, g, b, a or 1) end
    end
    return e
end

local function SetGlow(b, r, g, bl)
    if not b.glow then return end
    if r then
        b.glow:SetVertexColor(r, g, bl)
        b.glow:SetSize(b:GetWidth() * 1.7, b:GetHeight() * 1.7)
        b.glow:Show()
        if b.pulse and not b.pulse:IsPlaying() then b.pulse:Play() end
    else
        if b.pulse and b.pulse:IsPlaying() then b.pulse:Stop() end
        b.glow:Hide()
    end
end

local function CreateTile(key)
    tileCount = tileCount + 1
    local t = CreateFrame("Button", "KarasuoshiRestedBuffTile" .. tileCount, panel, "SecureActionButtonTemplate")
    t.key = key
    t:SetSize(Size(), Size())
    t:RegisterForClicks("AnyUp", "AnyDown")

    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetAllPoints()
    t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    t.cd = CreateFrame("Cooldown", nil, t, "CooldownFrameTemplate")
    t.cd:SetAllPoints()
    if t.cd.SetHideCountdownNumbers then t.cd:SetHideCountdownNumbers(true) end
    if t.cd.SetDrawEdge then t.cd:SetDrawEdge(false) end

    t.over = CreateFrame("Frame", nil, t)
    t.over:SetAllPoints()
    t.over:SetFrameLevel((t.cd:GetFrameLevel() or t:GetFrameLevel() or 1) + 2)
    if t.over.EnableMouse then t.over:EnableMouse(false) end
    t.edges = MakeEdges(t.over)
    t.edges:Set(0, 0, 0, 1, 1)

    t.glow = t.over:CreateTexture(nil, "OVERLAY")
    t.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    t.glow:SetBlendMode("ADD")
    t.glow:SetPoint("CENTER")
    t.glow:Hide()
    if t.glow.CreateAnimationGroup then
        t.pulse = t.glow:CreateAnimationGroup()
        t.pulse:SetLooping("BOUNCE")
        local a = t.pulse:CreateAnimation("Alpha")
        a:SetFromAlpha(0.15)
        a:SetToAlpha(1)
        a:SetDuration(0.6)
    end

    t.timer = t.over:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    t.timer:SetPoint("BOTTOM", t, "BOTTOM", 0, 2)
    t.count = t.over:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    t.count:SetPoint("TOPRIGHT", t, "TOPRIGHT", -1, -2)

    -- thin time bar under the icon
    t.barBg = t:CreateTexture(nil, "BACKGROUND")
    t.barBg:SetTexture(FLAT)
    t.barBg:SetVertexColor(0, 0, 0, 0.75)
    t.barBg:SetPoint("TOPLEFT", t, "BOTTOMLEFT", -1, -(BAR_GAP - 1))
    t.barBg:SetPoint("TOPRIGHT", t, "BOTTOMRIGHT", 1, -(BAR_GAP - 1))
    t.barBg:SetHeight(BAR_H + 2)
    t.bar = t:CreateTexture(nil, "ARTWORK")
    t.bar:SetTexture(FLAT)
    t.bar:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -BAR_GAP)
    t.bar:SetHeight(BAR_H)

    t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    if t.SetPushedTexture then t:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress") end

    t:HookScript("OnEnter", ShowTip)
    t:HookScript("OnLeave", function() GameTooltip:Hide() end)
    t:HookScript("OnMouseUp", function(_, button) MenuClick(button) end)
    -- non-secure extras after a left click (crafting, noting a placed item)
    t:HookScript("OnClick", function(self, button, down)
        if down or button ~= "LeftButton" then return end
        local m = self.model
        if not m then return end
        if m.blocked then
            if UIErrorsFrame then UIErrorsFrame:AddMessage(m.blocked, 1, 0.15, 0.15) end
            return
        end
        if not m.enabled then return end
        KRB:NoteClick(m.key, m.title)
        if m.insecure and not InLockdown() then m.insecure() end
        if m.postClick then m.postClick() end
    end)
    tiles[key] = t
    return t
end

local ATTRS = { "item", "spell", "macrotext" }

-- secure attributes can only change out of combat
local function ApplyAction(t, action)
    local sig = action and (action.type .. "|" .. (action.item or action.spell or action.macrotext or "")) or ""
    if t.actionSig == sig then return end
    if InLockdown() then UI.layoutPending = true return end
    t:SetAttribute("type1", action and action.type or nil)
    for _, a in ipairs(ATTRS) do t:SetAttribute(a, action and action[a] or nil) end
    t.actionSig = sig
end

local function SetSwipe(b, left, total)
    if left and total and left > 0 and total > 0 then
        local start = GetTime() - (total - left)
        if not b.cdStart or math.abs(b.cdStart - start) > 1 or b.cdDur ~= total then
            b.cd:SetCooldown(start, total)
            b.cdStart, b.cdDur = start, total
        end
    elseif b.cdStart then
        b.cd:SetCooldown(0, 0)
        b.cdStart, b.cdDur = nil, nil
    end
end

local function BarValue(m)
    if m.barValue then return m.barValue end
    if m.state == "ok" or m.state == "warn" then
        if m.timer and m.timerTotal and m.timerTotal > 0 then return math.max(0, math.min(1, m.timer / m.timerTotal)) end
        return 1
    elseif m.state == "wait" then
        if m.cdLeft and m.cdTotal and m.cdTotal > 0 then return math.max(0, math.min(1, 1 - m.cdLeft / m.cdTotal)) end
        return 0
    elseif m.state == "missing" or m.state == "ready" then
        return 1
    end
    return 0
end

local function UpdateTile(t, m)
    t.model = m
    t.icon:SetTexture(m.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local dim = (m.enabled == false) and m.state ~= "ok" and m.state ~= "warn"
    if t.icon.SetDesaturated then t.icon:SetDesaturated(dim and true or false) end
    t.icon:SetVertexColor(dim and 0.6 or 1, dim and 0.6 or 1, dim and 0.6 or 1)

    local c = STATE_COLOR[m.state] or STATE_COLOR.na
    if m.err or m.blocked then
        t.edges:Set(1, 0.2, 0.2, 1, 2)
    elseif m.state == "missing" or m.state == "ready" or m.state == "warn" or m.state == "fill" then
        t.edges:Set(c[1], c[2], c[3], 1, 2)
    else
        t.edges:Set(0, 0, 0, 1, 1)
    end

    local v = BarValue(m)
    local w = t:GetWidth() or Size()
    if v > 0 then
        t.bar:SetWidth(math.max(1, w * v))
        t.bar:SetVertexColor(c[1], c[2], c[3], m.state == "missing" and 0.4 or 1)
        t.bar:Show()
    else
        t.bar:Hide()
    end

    t.timer:SetText(m.badge or ShortTime(m.timer))
    t.count:SetText((m.count and m.count > 1) and tostring(m.count) or "")
    if m.state == "ok" or m.state == "warn" then SetSwipe(t, nil) else SetSwipe(t, m.cdLeft, m.cdTotal) end
    if t.flashUntil and GetTime() < t.flashUntil and m.state == "missing" then
        SetGlow(t, 1, 0.15, 0.15)
    else
        SetGlow(t, nil)
    end
    if GameTooltip:IsOwned(t) then ShowTip(t) end
end

------------------------------------------------------------------------
-- Sit pill: rounded button with a fill bar for the 1-minute camp timer
------------------------------------------------------------------------
local PILL_BACKDROP = {
    bgFile = FLAT, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function SitTip(b)
    GameTooltip:SetOwner(b, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine("Sit by the fire", 1, 0.82, 0)
    if KRB.sitStart then
        local el = GetTime() - KRB.sitStart
        if el < KRB:SitNeed() then
            GameTooltip:AddLine("Resting... camp buffs in " .. MinSec(KRB:SitNeed() - el), 1, 0.7, 0.3)
        else
            GameTooltip:AddLine(KRB.campEarned and "Camp buffs earned!" or "One minute done", 0.4, 1, 0.4)
        end
    end
    GameTooltip:AddLine("Sit next to a campfire for 1 minute to get the camp buffs (Camp Benefits, 1 hour).", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("Eating and the Cozy Sleeping Bag also want you seated.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("Moving or combat stands you up and resets the timer.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: sit down", 0.4, 1, 0.4)
    TipFooter()
    GameTooltip:Show()
end

local function CreateSitButton()
    local b = CreateFrame("Button", "KarasuoshiRestedBuffSitButton", panel, "SecureActionButtonTemplate")
    b:SetSize(PILL_W, Size())
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type1", "macro")
    b:SetAttribute("macrotext", "/sit")

    local tmpl = BackdropTemplateMixin and "BackdropTemplate" or nil
    -- orange halo when a fire is nearby (pulses)
    b.halo = CreateFrame("Frame", nil, b, tmpl)
    b.halo:SetPoint("TOPLEFT", -3, 3)
    b.halo:SetPoint("BOTTOMRIGHT", 3, -3)
    if b.halo.SetBackdrop then
        b.halo:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
        b.halo:SetBackdropBorderColor(1, 0.55, 0.15, 1)
    end
    b.halo:Hide()
    if b.halo.CreateAnimationGroup then
        b.pulse = b.halo:CreateAnimationGroup()
        b.pulse:SetLooping("BOUNCE")
        local a = b.pulse:CreateAnimation("Alpha")
        a:SetFromAlpha(0.2)
        a:SetToAlpha(1)
        a:SetDuration(0.8)
    end

    b.skin = CreateFrame("Frame", nil, b, tmpl)
    b.skin:SetAllPoints()
    if b.skin.SetBackdrop then
        b.skin:SetBackdrop(PILL_BACKDROP)
        b.skin:SetBackdropColor(0, 0, 0, 0.7)
        b.skin:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    end

    b.fill = CreateFrame("StatusBar", nil, b)
    b.fill:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.fill:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.fill:SetStatusBarTexture(FLAT)
    b.fill:SetStatusBarColor(1, 0.55, 0.12, 0.7)
    b.fill:SetMinMaxValues(0, 1)
    b.fill:SetValue(0)
    if b.fill.EnableMouse then b.fill:EnableMouse(false) end
    b.fill:SetFrameLevel((b.skin:GetFrameLevel() or 1) + 1)

    b.over = CreateFrame("Frame", nil, b)
    b.over:SetAllPoints()
    b.over:SetFrameLevel((b.fill:GetFrameLevel() or 2) + 1)
    if b.over.EnableMouse then b.over:EnableMouse(false) end

    b.icon = b.over:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexture("Interface\\Icons\\Spell_Nature_Sleep")
    b.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    b.icon:SetPoint("LEFT", b, "LEFT", 4, 0)
    b.text = b.over:CreateFontString(nil, "OVERLAY")
    SetFont(b.text, 12, "OUTLINE")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
    b.text:SetJustifyH("LEFT")

    b:HookScript("OnClick", function(self, button, down)
        if down or button ~= "LeftButton" then return end
        if self.macroOn ~= false then KRB:StartSitting(nil, true) end
    end)
    b:HookScript("OnEnter", function(self)
        if self.skin.SetBackdropBorderColor then self.skin:SetBackdropBorderColor(0.9, 0.75, 0.4, 1) end
        SitTip(self)
    end)
    b:HookScript("OnLeave", function(self)
        if self.skin.SetBackdropBorderColor then self.skin:SetBackdropBorderColor(0.35, 0.35, 0.35, 1) end
        GameTooltip:Hide()
    end)
    b:HookScript("OnMouseUp", function(_, button) MenuClick(button) end)

    b.ticker = CreateFrame("Frame", nil, b)
    local acc = 0
    b.ticker:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.1 then return end
        acc = 0
        UI:UpdateSitBar()
    end)

    sitBtn = b
    return b
end

local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"

local MODE = {
    eat  = { color = { 1.00, 0.82, 0.10 }, icon = "Interface\\Icons\\Spell_Misc_Food" },
    bag  = { color = { 0.66, 0.58, 1.00 }, icon = "Interface\\Icons\\INV_Misc_Bag_10" },
    camp = { color = { 1.00, 0.55, 0.12 }, icon = "Interface\\Icons\\Spell_Fire_Fire" },
}

local function ModelIcon(key, fallback)
    for _, m in ipairs(KRB.results or {}) do
        if m.key == key and m.icon then return m.icon end
    end
    return fallback
end

local function ModeIcon(kind)
    if kind == "eat" then return ModelIcon("food", MODE.eat.icon) end
    if kind == "bag" then return ModelIcon("bag", MODE.bag.icon) end
    return ModelIcon("fire", MODE.camp.icon)
end

-- don't let a Sit click pull you out of the sleeping bag
local function SetPillMacro(b, on)
    if b.macroOn == on or InLockdown() then return end
    b:SetAttribute("type1", on and "macro" or nil)
    b:SetAttribute("macrotext", on and "/sit" or nil)
    b.macroOn = on
end

function UI:UpdateSitBar()
    local b = sitBtn
    if not b then return end
    local h = b:GetHeight() or Size()
    b.icon:SetSize(h - 8, h - 8)
    local act = KRB:RestActivity()
    SetPillMacro(b, not (act and act.kind == "bag" and not act.done))

    if act and act.kind ~= "camp" then
        local c = MODE[act.kind].color
        b.icon:SetTexture(ModeIcon(act.kind))
        b.icon:SetVertexColor(1, 1, 1)
        if act.done then
            b.fill:SetStatusBarColor(0.24, 0.81, 0.31, 0.6)
            b.fill:SetValue(1)
            b.text:SetText((act.kind == "eat" and "FED " or (act.max .. "% ")) .. CHECK)
        else
            b.fill:SetStatusBarColor(c[1], c[2], c[3], 0.7)
            b.fill:SetValue(act.progress or 0)
            if act.kind == "eat" then
                b.text:SetText("EAT  " .. MinSec(act.left))
            else
                b.text:SetText(act.pct .. "%  " .. MinSec(act.left))
            end
        end
        if b.pulse and b.pulse:IsPlaying() then b.pulse:Stop() end
        b.halo:Hide()
        if GameTooltip:IsOwned(b) then SitTip(b) end
        return
    end

    b.icon:SetTexture("Interface\\Icons\\Spell_Nature_Sleep")
    local need = KRB:SitNeed()
    local start = KRB.sitStart
    if start then
        local el = GetTime() - start
        if el < need then
            b.fill:SetStatusBarColor(1, 0.55, 0.12, 0.7)
            b.fill:SetValue(el / need)
            b.text:SetText("SIT  " .. MinSec(need - el))
        else
            b.fill:SetStatusBarColor(0.24, 0.81, 0.31, 0.6)
            b.fill:SetValue(1)
            b.text:SetText("SIT " .. CHECK .. " " .. MinSec(el))
        end
        b.icon:SetVertexColor(1, 1, 1)
        if b.pulse and b.pulse:IsPlaying() then b.pulse:Stop() end
        b.halo:Hide()
    else
        b.fill:SetValue(0)
        b.icon:SetVertexColor(0.85, 0.85, 0.85)
        if KRB.fireActive then
            b.text:SetText("|cffffd100SIT|r")
            b.halo:Show()
            if b.pulse and not b.pulse:IsPlaying() then b.pulse:Play() end
        else
            b.text:SetText("SIT")
            if b.pulse and b.pulse:IsPlaying() then b.pulse:Stop() end
            b.halo:Hide()
        end
    end
    if GameTooltip:IsOwned(b) then SitTip(b) end
end

------------------------------------------------------------------------
-- "Don't move" notice over your character (eating / sleeping bag / fire)
------------------------------------------------------------------------
local overlay

local SUBTEXT = {
    eat  = function(a) return "Eating - Well Fed in " .. MinSec(a.left) end,
    bag  = function(a) return string.format("Sleeping bag %d%% / %d%% - next %% in %s", a.pct, a.max, MinSec(a.left)) end,
    camp = function(a) return "By the fire - camp buffs in " .. MinSec(a.left) end,
}
local DONETEXT = {
    eat  = "Well Fed!",
    bag  = "Sleeping bag full: +3% XP",
    camp = "Camp buffs are yours",
}

function UI:PlaceOverlay()
    if not overlay then return end
    overlay:ClearAllPoints()
    overlay:SetPoint("CENTER", UIParent, "CENTER", 0, (KRB.db and KRB.db.overlayY) or 170)
end

local function CreateOverlay()
    local o = CreateFrame("Frame", "KarasuoshiRestedBuffNotice", UIParent)
    o:SetSize(300, 70)
    o:SetFrameStrata("HIGH")
    if o.EnableMouse then o:EnableMouse(false) end
    o.icon = o:CreateTexture(nil, "ARTWORK")
    o.icon:SetSize(30, 30)
    o.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    o.icon:SetPoint("TOP", o, "TOP", -95, 0)
    o.title = o:CreateFontString(nil, "OVERLAY")
    SetFont(o.title, 20, "THICKOUTLINE")
    o.title:SetPoint("LEFT", o.icon, "RIGHT", 8, 0)
    o.sub = o:CreateFontString(nil, "OVERLAY")
    SetFont(o.sub, 13, "OUTLINE")
    o.sub:SetPoint("TOP", o, "TOP", 0, -36)
    o.barBg = o:CreateTexture(nil, "BACKGROUND")
    o.barBg:SetTexture(FLAT)
    o.barBg:SetVertexColor(0, 0, 0, 0.7)
    o.barBg:SetSize(202, 8)
    o.barBg:SetPoint("TOP", o, "TOP", 0, -56)
    o.bar = o:CreateTexture(nil, "ARTWORK")
    o.bar:SetTexture(FLAT)
    o.bar:SetHeight(6)
    o.bar:SetPoint("LEFT", o.barBg, "LEFT", 1, 0)
    o.spark = o:CreateTexture(nil, "OVERLAY")
    o.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    o.spark:SetBlendMode("ADD")
    o.spark:SetSize(14, 22)
    o:Hide()
    overlay = o
    UI:PlaceOverlay()
end

function UI:UpdateRestOverlay()
    local o = overlay
    if not o then return end
    local act = KRB.db and KRB.db.restOverlay and KRB:RestActivity()
    if not act then o:Hide() return end
    local c = act.done and { 0.30, 1.00, 0.35 } or MODE[act.kind].color
    o.icon:SetTexture(ModeIcon(act.kind))
    if act.done then
        o.title:SetText("YOU CAN GET UP")
        o.title:SetTextColor(0.35, 1, 0.4)
        o.title:SetAlpha(1)
        o.sub:SetText(DONETEXT[act.kind])
    else
        o.title:SetText("DON'T MOVE")
        o.title:SetTextColor(1, 0.45, 0.2)
        o.title:SetAlpha(0.7 + 0.3 * math.abs(math.sin(GetTime() * 3)))
        o.sub:SetText(SUBTEXT[act.kind](act))
    end
    o.sub:SetTextColor(1, 1, 1)
    local v = math.max(0, math.min(1, act.progress or 0))
    o.bar:SetVertexColor(c[1], c[2], c[3], 0.9)
    if v > 0 then o.bar:SetWidth(200 * v) o.bar:Show() else o.bar:Hide() end
    if not act.done and v > 0 and v < 1 then
        o.spark:ClearAllPoints()
        o.spark:SetPoint("CENTER", o.barBg, "LEFT", 1 + 200 * v, 0)
        o.spark:Show()
    else
        o.spark:Hide()
    end
    o:Show()
end

------------------------------------------------------------------------
-- Emote panel: every /emote one click away, right-click pins favourites
------------------------------------------------------------------------
local EMOTE_GROUPS = {
    { "Friendly", { "WAVE", "HELLO", "BYE", "BOW", "HUG", "THANK", "CHEER", "APPLAUD", "CLAP", "SALUTE", "SMILE",
        "GREET", "WELCOME", "CONGRATULATE", "KISS", "FLIRT", "LOVE", "COMFORT", "SOOTHE", "INTRODUCE", "CURTSEY", "HAIL" } },
    { "Fun", { "DANCE", "LAUGH", "ROFL", "GIGGLE", "CHUCKLE", "CACKLE", "GUFFAW", "JOKE", "SILLY", "CHICKEN", "MOO",
        "BARK", "PURR", "ROAR", "TRAIN", "FLEX", "SHIMMY", "BOUNCE", "VIOLIN", "MOON", "FART", "BURP", "WHISTLE", "TICKLE" } },
    { "Rude", { "SPIT", "RUDE", "INSULT", "MOCK", "TAUNT", "TEASE", "THREATEN", "GLARE", "SNARL", "GROWL", "SLAP",
        "PUNCH", "POKE", "BONK", "SMIRK", "SNUB", "STINK", "VETO", "GLOAT", "LICK", "NOSEPICK", "DROOL", "RASP" } },
    { "Feelings", { "CRY", "SIGH", "SHRUG", "CONFUSED", "SURPRISED", "GASP", "SCARED", "PANIC", "SHY", "BLUSH",
        "BASHFUL", "FROWN", "ANGRY", "MOURN", "PITY", "APOLOGIZE", "BORED", "TIRED", "YAWN", "COWER", "CRINGE",
        "GROVEL", "PLEAD", "BEG", "HAPPY", "CURIOUS", "LOST", "CALM" } },
    { "Actions", { "SIT", "STAND", "SLEEP", "KNEEL", "LAYDOWN", "POINT", "BECKON", "NOD", "NO", "AGREE", "PONDER",
        "PEER", "STARE", "LISTEN", "EAT", "DRINK", "HUNGRY", "THIRSTY", "COLD", "SHIVER", "PRAY", "SURRENDER",
        "VICTORY", "READY", "WORK", "TAP", "SCRATCH", "FIDGET" } },
    { "Group calls", { "CHARGE", "ATTACKMYTARGET", "FOLLOW", "WAIT", "HELPME", "HEALME", "INCOMING", "OPENFIRE",
        "OOM", "FLEE" } },
}
local EMOTE_LABEL = { ATTACKMYTARGET = "/attacktarget" }
local EM_COLS, EM_W, EM_H, EM_GAP = 6, 78, 18, 2

local emotePanel, emoteBtn
local emotePool = {}

local function EmoteLabel(token)
    return EMOTE_LABEL[token] or ("/" .. string.lower(token))
end

local function IsFav(token)
    for _, t in ipairs(KRB.db.favEmotes or {}) do if t == token then return true end end
    return false
end

local function ToggleFav(token)
    KRB.db.favEmotes = KRB.db.favEmotes or {}
    local list = KRB.db.favEmotes
    for i, t in ipairs(list) do
        if t == token then table.remove(list, i) UI:BuildEmotes() return end
    end
    table.insert(list, token)
    UI:BuildEmotes()
end

local function DoTheEmote(token)
    if DoEmote then
        local ok = pcall(DoEmote, token)
        if ok then return end
    end
    KRB.Print("couldn't do " .. EmoteLabel(token) .. " - type it in chat")
end

local function EmoteButton(i)
    local b = emotePool[i]
    if b then return b end
    b = CreateFrame("Button", nil, emotePanel)
    b:SetSize(EM_W, EM_H)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(FLAT)
    b.text = b:CreateFontString(nil, "OVERLAY")
    SetFont(b.text, 11, "")
    b.text:SetPoint("CENTER")
    b:SetHighlightTexture(FLAT)
    local hl = b:GetHighlightTexture()
    if hl then hl:SetVertexColor(1, 0.8, 0.3, 0.25) end
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then ToggleFav(self.token) else DoTheEmote(self.token) end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(EmoteLabel(self.token), 1, 0.82, 0)
        GameTooltip:AddLine("Target someone first for a directed emote.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(IsFav(self.token) and "Right-click: unpin" or "Right-click: pin to the top", 0.55, 0.75, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    emotePool[i] = b
    return b
end

function UI:BuildEmotes()
    if not emotePanel then return end
    local groups = {}
    local favs = KRB.db.favEmotes or {}
    if #favs > 0 then groups[1] = { "Pinned", favs, true } end
    for _, g in ipairs(EMOTE_GROUPS) do groups[#groups + 1] = g end

    local n, y = 0, -30
    emotePanel.headers = emotePanel.headers or {}
    for gi, g in ipairs(groups) do
        local h = emotePanel.headers[gi]
        if not h then
            h = emotePanel:CreateFontString(nil, "OVERLAY")
            SetFont(h, 10, "OUTLINE")
            emotePanel.headers[gi] = h
        end
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", emotePanel, "TOPLEFT", 10, y)
        h:SetText(g[1])
        if g[3] then h:SetTextColor(0.73, 0.66, 1) else h:SetTextColor(1, 0.7, 0.36) end
        h:Show()
        y = y - 13
        for i, token in ipairs(g[2]) do
            n = n + 1
            local b = EmoteButton(n)
            b.token = token
            b.text:SetText(EmoteLabel(token))
            if g[3] then b.bg:SetVertexColor(0.30, 0.25, 0.55, 0.85) else b.bg:SetVertexColor(0.12, 0.12, 0.15, 0.9) end
            local col, row = (i - 1) % EM_COLS, math.floor((i - 1) / EM_COLS)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", emotePanel, "TOPLEFT", 10 + col * (EM_W + EM_GAP), y - row * (EM_H + EM_GAP))
            b:Show()
        end
        y = y - math.ceil(#g[2] / EM_COLS) * (EM_H + EM_GAP) - 6
    end
    for i = n + 1, #emotePool do emotePool[i]:Hide() end
    for i = #groups + 1, #emotePanel.headers do emotePanel.headers[i]:Hide() end
    emotePanel:SetSize(20 + EM_COLS * (EM_W + EM_GAP) - EM_GAP, -y + 6)
end

local function CreateEmotePanel()
    local tmpl = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "KarasuoshiRestedBuffEmotes", UIParent, tmpl)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = FLAT, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        f:SetBackdropColor(0.03, 0.04, 0.07, 0.94)
        f:SetBackdropBorderColor(0.55, 0.45, 0.3, 1)
    end
    f.title = f:CreateFontString(nil, "OVERLAY")
    SetFont(f.title, 13, "OUTLINE")
    f.title:SetPoint("TOPLEFT", 10, -9)
    f.title:SetTextColor(1, 0.82, 0)
    f.title:SetText("Emotes")
    f.hint = f:CreateFontString(nil, "OVERLAY")
    SetFont(f.hint, 10, "")
    f.hint:SetPoint("LEFT", f.title, "RIGHT", 10, 0)
    f.hint:SetTextColor(0.7, 0.7, 0.7)
    f.hint:SetText("click: do it   right-click: pin   Esc: close")
    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", 2, 2)
    f:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "KarasuoshiRestedBuffEmotes") end
    emotePanel = f
    UI:BuildEmotes()
end

function UI:ToggleEmotes()
    if not emotePanel then return end
    if emotePanel:IsShown() then emotePanel:Hide() return end
    emotePanel:ClearAllPoints()
    local _, ay = anchor:GetCenter()
    local screenH = UIParent:GetHeight() or 768
    if ay and ay < screenH / 2 then
        emotePanel:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 6)
    else
        emotePanel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    end
    UI:BuildEmotes()
    emotePanel:Show()
end

local function CreateEmoteButton()
    local b = CreateFrame("Button", "KarasuoshiRestedBuffEmoteButton", panel)
    b:SetSize(Size(), Size())
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture("Interface\\Icons\\Ability_Warrior_BattleShout")
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.edges = MakeEdges(b)
    b.edges:Set(0, 0, 0, 1, 1)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then MenuClick(button) else UI:ToggleEmotes() end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine("Emotes", 1, 0.82, 0)
        GameTooltip:AddLine("All emotes in one panel: /wave, /spit, /dance...", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Left-click: open / close", 0.4, 1, 0.4)
        TipFooter()
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    emoteBtn = b
end

------------------------------------------------------------------------
-- Frame
------------------------------------------------------------------------
local function CreateLabel(group)
    local f = CreateFrame("Frame", nil, panel)
    f.group = group
    f:SetSize(40, LBL_H)
    f.text = f:CreateFontString(nil, "OVERLAY")
    SetFont(f.text, 9, "OUTLINE")
    f.text:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 2)
    f.text:SetTextColor(group.color[1], group.color[2], group.color[3])
    f.text:SetText(group.label)
    MakeDraggable(f)
    f:SetScript("OnEnter", ShowLabelTip)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    labels[group.key] = f

    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(FLAT)
    sep:SetVertexColor(1, 1, 1, 0.25)
    seps[group.key] = sep
end

function UI:Create()
    if anchor then return end
    -- outer anchor: holds position, hidden in combat by a secure state driver
    anchor = CreateFrame("Frame", "KarasuoshiRestedBuffAnchor", UIParent)
    anchor:SetSize(100, 50)
    anchor:SetFrameStrata("MEDIUM")
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)

    panel = CreateFrame("Frame", "KarasuoshiRestedBuffFrame", anchor)
    panel:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    panel:SetSize(100, 50)
    MakeDraggable(panel)

    for _, g in ipairs(GROUPS) do CreateLabel(g) end
    for _, key in ipairs(KRB.ORDER) do
        if key ~= "profs" then CreateTile(key) end
    end
    CreateSitButton()
    CreateEmoteButton()
    CreateEmotePanel()
    CreateOverlay()

    -- light ticker for the notice (and the pill text when visible)
    local tick = CreateFrame("Frame", nil, UIParent)
    local acc = 0
    tick:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.1 then return end
        acc = 0
        UI:UpdateRestOverlay()
    end)
    UI.ticker = tick

    UI:ApplyPosition()
    UI:ApplyCombatVisibility()
end

-- reminder fired: make the missing icons glow for a few seconds
function UI:Flash()
    if not panel or not panel:IsVisible() then return end
    local untilT = GetTime() + 3
    for _, t in pairs(tiles) do
        if t.model and t.model.state == "missing" and t:IsShown() then
            t.flashUntil = untilT
            SetGlow(t, 1, 0.15, 0.15)
        end
    end
end

function UI:Render(results, missingCount)
    if not panel then return end
    local db = KRB.db
    local locked = InLockdown()

    -- visuals are fine in combat; attributes / layout only out of combat
    local lists = { xp = {}, buff = {} }
    for _, t in pairs(tiles) do t.wanted = false end
    for _, m in ipairs(results) do
        local t = tiles[m.key] or (not locked and CreateTile(m.key))
        if t then
            local show = not m.hidden and not (db.hideNA and m.state == "na")
            t.wanted = show
            if show then table.insert(lists[m.group == "xp" and "xp" or "buff"], t) end
            if not locked then
                t:SetSize(Size(), Size())
                ApplyAction(t, (show and m.enabled) and m.action or nil)
            end
            UpdateTile(t, m)
        end
    end
    if sitBtn then UI:UpdateSitBar() end
    if locked then self.layoutPending = true return end
    self.layoutPending = false

    local s = Size()
    local vertical = db.vertical
    local slotH = s + BAR_GAP + BAR_H          -- icon + time bar
    local x, y = EDGE, -EDGE                   -- cursor (top-left)
    local maxX, minY = 0, 0
    local used, first = {}, true

    for _, g in ipairs(GROUPS) do
        local list = lists[g.key]
        local lbl, sep = labels[g.key], seps[g.key]
        if #list > 0 then
            used[g.key] = true
            if not first then
                sep:ClearAllPoints()
                if vertical then
                    y = y - 4
                    sep:SetPoint("TOPLEFT", panel, "TOPLEFT", EDGE, y)
                    sep:SetSize(s, 1)
                    y = y - (SEP - 4)
                else
                    x = x + 4
                    sep:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -(EDGE + LBL_H))
                    sep:SetSize(1, slotH)
                    x = x + (SEP - 4)
                end
                sep:Show()
            else
                sep:Hide()
            end
            first = false
            lbl:ClearAllPoints()
            lbl:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
            lbl:SetWidth(math.max(s, 30))
            lbl:Show()
            if vertical then y = y - LBL_H end
            for i, t in ipairs(list) do
                t:ClearAllPoints()
                if vertical then
                    t:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
                    y = y - slotH - GAP
                else
                    t:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y - LBL_H)
                    x = x + s + GAP
                end
                t:Show()
            end
            if vertical then y = y + GAP else x = x - GAP end
            if x > maxX then maxX = x end
            if y < minY then minY = y end
        else
            lbl:Hide()
            sep:Hide()
        end
    end
    for _, t in pairs(tiles) do
        if not t.wanted then
            t:Hide()
            ApplyAction(t, nil)
        end
    end

    -- Sit pill at the end of the line (or under the column)
    local anyIcons = used.xp or used.buff
    if sitBtn then
        if db.checks.sit then
            local pw = math.max(PILL_W, math.floor(s * 3))
            sitBtn:SetSize(pw, s)
            sitBtn:ClearAllPoints()
            if vertical then
                local py = anyIcons and (y - 8) or -EDGE
                sitBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", EDGE, py)
                if py - s < minY then minY = py - s end
                if EDGE + pw > maxX then maxX = EDGE + pw end
            else
                local px = anyIcons and (x + 10) or EDGE
                sitBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", px, -(EDGE + (anyIcons and LBL_H or 0)))
                if px + pw > maxX then maxX = px + pw end
            end
            sitBtn:Show()
            UI:UpdateSitBar()
        else
            sitBtn:Hide()
        end
    end

    if emoteBtn then
        if db.checks.emotes then
            emoteBtn:SetSize(s, s)
            emoteBtn:ClearAllPoints()
            if vertical then
                local below = minY ~= 0 and (minY - 6) or -EDGE
                emoteBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", EDGE, below)
                minY = below - s
            else
                local ex = (maxX > 0) and (maxX + 6) or EDGE
                emoteBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", ex, -(EDGE + (anyIcons and LBL_H or 0)))
                maxX = ex + s
            end
            emoteBtn:Show()
        else
            emoteBtn:Hide()
            if emotePanel then emotePanel:Hide() end
        end
    end

    local w, h
    if vertical then
        w = math.max(maxX, EDGE + math.max(s, 30)) + EDGE
        h = -minY + EDGE
    else
        w = maxX + EDGE
        h = EDGE + ((anyIcons and LBL_H or 0) + (anyIcons and slotH or s)) + EDGE
    end
    panel:SetSize(w, h)
    anchor:SetSize(w, h)

    local show = db.showFrame and (anyIcons or db.checks.sit or db.checks.emotes) and not (db.hideWhenAllOK and missingCount == 0)
    if show then panel:Show() else panel:Hide() end
end

------------------------------------------------------------------------
-- Options panel (Esc -> Options -> AddOns)
------------------------------------------------------------------------
local options
local checks = {}

local function MakeCheck(parent, x, y, label, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(24, 24)
    local own = cb.text or cb.Text
    if own then own:SetText("") end
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    fs:SetText(label)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        KRB:Update()
    end)
    cb.Refresh = function(self) self:SetChecked(get() and true or false) end
    checks[#checks + 1] = cb
    return cb
end

local function MakeButton(parent, x, y, w, label, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(w, 22)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

function UI:CreateOptions()
    if options then return end
    options = CreateFrame("Frame", "KarasuoshiRestedBuffOptions")
    options.name = "Karasuoshi Rested Buff"

    local h = options:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    h:SetPoint("TOPLEFT", 16, -16)
    h:SetText("Karasuoshi Rested Buff  |cff999999v" .. KRB.version .. "|r")

    local sub = options:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
    sub:SetText("Tracks your XP / rested buffs, reminds you when one is missing, and lets you fix it with one click.")

    local db = function() return KRB.db end
    local y = -64
    local function section(text)
        local s = options:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        s:SetPoint("TOPLEFT", col, y + 4)
        s:SetText(text)
        y = y - 20
    end
    local col = 16
    local function bool(key, label, after)
        MakeCheck(options, col, y, label, function() return db()[key] end, function(v)
            db()[key] = v
            if after then after() end
        end)
        y = y - 26
    end
    local function chk(cat, label)
        MakeCheck(options, col, y, label, function() return db().checks[cat] end, function(v) db().checks[cat] = v end)
        y = y - 26
    end

    local top = y
    section("XP buffs")
    chk("food", "XP food (eat the best Well Fed food)")
    chk("bag",  "Cozy Sleeping Bag")
    chk("tent", "Rested XP / Camp Tent")
    y = y - 6
    section("Camp & other buffs")
    chk("fire",  "Campfire (light / craft a kit)")
    chk("profs", "Profession camp items (First Aid Kit...)")
    chk("camp",  "Camp buff (Camp Benefits)")
    chk("sit",   "Sit button with 1-minute timer")
    chk("emotes", "Emote button (all /emotes in one panel)")
    bool("restOverlay", "\"Don't move\" notice over your character")
    local leftEnd = y

    col, y = 330, top
    section("Reminders")
    bool("enabled",        "Remind me")
    bool("centerText",     "Big text in the middle of the screen")
    bool("sound",          "Sound")
    bool("chat",           "Chat message")
    bool("silentInCombat", "Stay quiet in combat")
    bool("strictFood",     "Strict Well Fed check (tooltip says XP)")
    bool("hideAtMaxLevel", "No XP buffs at max level")
    y = y - 6
    section("Look")
    bool("showFrame",     "Show the bar")
    bool("locked",        "Lock the bar")
    bool("vertical",      "Vertical (icons in a column)")
    bool("hideNA",        "Hide greyed-out icons")
    bool("hideInCombat",  "Hide the bar in combat", function() UI:ApplyCombatVisibility() end)
    bool("hideWhenAllOK", "Hide the bar when everything is up")

    col = 16
    y = math.min(y, leftEnd) - 10
    MakeButton(options, 16, y, 130, "Test reminder", function() KRB:Alert({ "XP food", "sleeping bag" }, true) end)
    MakeButton(options, 152, y, 130, "Snooze 15 min", function() KRB:Snooze(15) end)
    MakeButton(options, 288, y, 150, "Reset position", function()
        KRB.db.point = { "TOP", "TOP", 0, -140 }
        UI:ApplyPosition()
    end)

    local foot = options:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    foot:SetPoint("TOPLEFT", 16, y - 34)
    foot:SetJustifyH("LEFT")
    foot:SetText("More via |cffffd100/krb|r: icon size (/krb size 30), scale, interval, forced food or campfire spell.\n" ..
        "If a buff isn't recognised: |cffffd100/krb scan|r, then |cffffd100/krb addid food <ID>|r")

    options:SetScript("OnShow", function()
        for _, cb in ipairs(checks) do cb:Refresh() end
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, options, options.name)
        if ok and cat then
            Settings.RegisterAddOnCategory(cat)
            UI.category = cat
        end
    end
    if not UI.category and InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(options)
    end
end

function UI:OpenOptions()
    if InLockdown() then KRB.Print("options can't be opened in combat.") return end
    if UI.category and Settings and Settings.OpenToCategory then
        local id = UI.category.ID or (UI.category.GetID and UI.category:GetID())
        Settings.OpenToCategory(id)
    elseif InterfaceOptionsFrame_OpenToCategory and options then
        InterfaceOptionsFrame_OpenToCategory(options)
        InterfaceOptionsFrame_OpenToCategory(options) -- second call works around a Blizzard bug
    else
        KRB.Print("options panel unavailable - use /krb")
    end
end
