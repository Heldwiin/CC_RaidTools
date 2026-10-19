-- CC RaidTools - Lust Sound
-- Plays a sound whenever the player receives a Bloodlust-type effect, whatever
-- their class. Integrated from the standalone "Son du Lust" addon.
--
-- The lust buff itself is a secret value in combat since 12.1, so it can't be
-- read. What can be read is the lockout debuff (Sated / Exhaustion / Temporal
-- Displacement / Fatigued...) the game applies at the very same instant, so
-- the sound is tied to that debuff appearing. Drums apply the same debuffs.
-- C_UnitAuras.GetPlayerAuraBySpellID is documented RequiresNonSecretAura:
-- it only ever returns auras the addon is allowed to see, which these are.
--
-- The sound is either the bundled Apocalypse file (default) or any of the
-- game sounds Blizzard offers for Cooldown Manager alerts (CooldownViewerSoundData:
-- 93 sound kits in 7 categories, with names already localized by the client).
local C = CCRT

local db

local SOUND = "Interface\\AddOns\\CC_RaidTools\\sounds\\Apocalypse.ogg"

local LOCKOUTS = {
    57723,   -- Exhaustion (Heroism, Alliance shaman)
    57724,   -- Sated (Bloodlust, Horde shaman)
    80354,   -- Temporal Displacement (Time Warp, mage)
    264689,  -- Fatigued (Primal Rage, hunter pet)
    390435,  -- Exhaustion (Fury of the Aspects, evoker)
    95809,   -- Insanity (Ancient Hysteria, old pet)
    160455,  -- Fatigued (Netherwinds, old pet)
}

-- Seconds after entering the world during which auras are still arriving in
-- waves: we only observe, we never play.
local WORLD_SETTLE = 3
-- A lockout lasts its full duration (10 min) from the moment it is applied;
-- if noticeably less is left, it is an old lust seen again (reload, relog...).
local FRESH_MARGIN = 10

local CHANNEL_VALUES = {
    { "Master", "Master" },
    { "SFX", "SFX" },
    { "Music", "Music" },
    { "Ambience", "Ambience" },
    { "Dialog", "Dialog" },
}

local function InitDB()
    C.InitDB()
    CCRaidToolsDB.lustSound = CCRaidToolsDB.lustSound or {}
    db = CCRaidToolsDB.lustSound
    -- Opt-in: a surprise sound on every lust is not something to ship on by
    -- default to the whole guild.
    if db.enabled == nil then
        db.enabled = false
    end
    local valid = false
    for _, entry in ipairs(CHANNEL_VALUES) do
        if db.channel == entry[2] then
            valid = true
        end
    end
    if not valid then
        db.channel = "Master"
    end
    -- nil means the bundled Apocalypse file; otherwise a game sound kit ID.
    if type(db.soundKit) ~= "number" then
        db.soundKit = nil
    end
end

-- ===== Game sound catalog =====
-- Read from Blizzard's own Cooldown Manager data rather than copied, so the
-- list, the localized names and any future additions stay in step with the
-- client. If it ever isn't there, only the bundled sound is offered.

local catalog, soundNames

local function CategoryTitle(name)
    return _G["COOLDOWN_VIEWER_SETTINGS_SOUND_ALERT_CATEGORY_" .. name:upper()] or name
end

local function GetCatalog()
    if catalog then
        return catalog
    end
    catalog, soundNames = {}, {}
    local data = _G.CooldownViewerSoundData
    local categories = Enum and Enum.CooldownViewerSoundCategory
    if type(data) ~= "table" or type(categories) ~= "table" then
        return catalog
    end
    local ordered = {}
    for name, value in pairs(categories) do
        if type(value) == "number" and type(data[value]) == "table" then
            table.insert(ordered, { name = name, value = value })
        end
    end
    table.sort(ordered, function(a, b) return a.value < b.value end)
    for _, category in ipairs(ordered) do
        local sounds = {}
        for _, entry in ipairs(data[category.value]) do
            if type(entry.soundKitID) == "number" then
                local text = (type(entry.text) == "string" and entry.text ~= "") and entry.text or tostring(entry.soundKitID)
                table.insert(sounds, { id = entry.soundKitID, text = text })
                soundNames[entry.soundKitID] = soundNames[entry.soundKitID] or text
            end
        end
        if #sounds > 0 then
            table.insert(catalog, { title = CategoryTitle(category.name), sounds = sounds })
        end
    end
    return catalog
end

local function CurrentSoundName()
    if not db.soundKit then
        return C.L.lustSoundDefault
    end
    GetCatalog()
    return soundNames[db.soundKit] or ("ID " .. db.soundKit)
end

local function PlayConfigured()
    if db.soundKit then
        -- Game sounds take a UI sound subtype rather than a channel name
        -- (C_Sound.PlaySound), so the channel setting only applies to the file.
        PlaySound(db.soundKit)
    else
        PlaySoundFile(SOUND, db.channel)
    end
end

-- ===== Detection =====

-- If the standalone addon is still installed it plays the sound itself;
-- stay silent rather than doubling it.
local function StandaloneLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("SonDuLust")
end

-- Returns the player's lockout aura, if any.
local function FindLockoutAura()
    for i = 1, #LOCKOUTS do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(LOCKOUTS[i])
        if aura then
            return aura
        end
    end
end

local function IsFresh(aura)
    local expires, duration = aura.expirationTime, aura.duration
    if issecretvalue and (issecretvalue(expires) or issecretvalue(duration)) then
        return true -- unreadable: rely on having seen it appear
    end
    if not expires or expires == 0 or not duration or duration == 0 then
        return true
    end
    return (expires - GetTime()) >= (duration - FRESH_MARGIN)
end

-- In restricted content (combat, encounters, M+) fields of the UNIT_AURA
-- payload can be secret values, and a secret boolean can't even be tested
-- (`if x then` raises an error). When isFullUpdate is unreadable we treat it
-- as "not a full update": the ready window and IsFresh already stop a reload
-- or relog from replaying the sound.
local function IsFullUpdate(updateInfo)
    if not updateInfo then
        return false
    end
    local full = updateInfo.isFullUpdate
    if issecretvalue and issecretvalue(full) then
        return false
    end
    return full == true
end

local ready = false        -- false while loading: observe only
local generation = 0       -- invalidates settle timers from an earlier load
local wasLockedOut = false

local function SyncState()
    wasLockedOut = FindLockoutAura() ~= nil
end

local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(_, event, _, updateInfo)
    if event == "PLAYER_LEAVING_WORLD" then
        ready = false
        generation = generation + 1
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- Auras arrive in waves after loading: wait for them to be in place
        -- before taking the starting state.
        ready = false
        generation = generation + 1
        local mine = generation
        C_Timer.After(WORLD_SETTLE, function()
            if mine == generation then
                SyncState()
                ready = true
            end
        end)
        return
    end

    -- UNIT_AURA
    local aura = FindLockoutAura()
    local locked = aura ~= nil
    -- Sound only on a fresh lockout APPEARING: never during loading, on a
    -- full aura refresh, or for an old lust (reload, relog, zone change).
    if ready and locked and not wasLockedOut
        and not IsFullUpdate(updateInfo)
        and IsFresh(aura) and not StandaloneLoaded() then
        PlayConfigured()
    end
    wasLockedOut = locked
end)

-- UNIT_AURA fires constantly in combat, so it is only registered while the
-- option is on.
local function ApplyEnabled(fromLogin)
    InitDB()
    watcher:UnregisterAllEvents()
    generation = generation + 1
    if db.enabled then
        watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
        watcher:RegisterEvent("PLAYER_LEAVING_WORLD")
        watcher:RegisterUnitEvent("UNIT_AURA", "player")
        if fromLogin then
            -- PLAYER_ENTERING_WORLD follows and re-arms once loading settles.
            ready = false
        else
            -- Enabled from the panel while already in the world: taking the
            -- current state first means a lockout already running is ignored.
            SyncState()
            ready = true
        end
    else
        ready = false
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    ApplyEnabled(true)
end)

-- ===== Settings UI =====

local ROW_H = 20
local HEADER_H = 24
local POPUP_W, POPUP_H = 280, 300

local enableCheck, channelDrop, standaloneNote, pickerText
local popup, catcher
local rows = {}

local function UpdateChannelState()
    if not channelDrop then
        return
    end
    local custom = db.soundKit == nil
    channelDrop:SetAlpha(custom and 1 or 0.4)
    channelDrop._button:SetEnabled(custom)
end

local function RefreshRows()
    for _, row in ipairs(rows) do
        local selected = (row.soundKit == db.soundKit)
        if selected then
            row.text:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
        else
            row.text:SetTextColor(0.92, 0.92, 0.92)
        end
    end
end

local function SelectSound(soundKit)
    db.soundKit = soundKit
    if pickerText then
        pickerText:SetText(CurrentSoundName())
    end
    UpdateChannelState()
    RefreshRows()
    -- Clicking a sound plays it, so the list doubles as a preview.
    PlayConfigured()
end

local function HidePopup()
    if popup then
        popup:Hide()
    end
    if catcher then
        catcher:Hide()
    end
end

local function AddRow(child, y, text, soundKit)
    local row = CreateFrame("Button", nil, child)
    row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
    row:SetPoint("RIGHT", child, "RIGHT", 0, 0)
    row:SetHeight(ROW_H)
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(C.BRAND_R * 0.35, C.BRAND_G * 0.35, C.BRAND_B * 0.48, 1)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 8, 0)
    row.text:SetPoint("RIGHT", -4, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetText(text)
    row.soundKit = soundKit
    row:SetScript("OnClick", function()
        SelectSound(row.soundKit)
    end)
    table.insert(rows, row)
end

-- Built on first open: ~100 rows that are never needed unless the player
-- actually browses the list.
local function BuildPopup()
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    catcher:SetScript("OnClick", HidePopup)
    catcher:Hide()

    popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetSize(POPUP_W, POPUP_H)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(catcher:GetFrameLevel() + 10)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    C.ApplyPanelSkin(popup)
    popup:Hide()

    local scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -28, 4)
    C.SkinScrollBar(scroll)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(POPUP_W - 36, 20)
    scroll:SetScrollChild(child)

    local y = 0
    AddRow(child, y, C.L.lustSoundDefault, nil)
    y = y - ROW_H

    local groups = GetCatalog()
    if #groups == 0 then
        local note = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        note:SetPoint("TOPLEFT", child, "TOPLEFT", 8, y - 8)
        note:SetPoint("RIGHT", child, "RIGHT", -4, 0)
        note:SetJustifyH("LEFT")
        note:SetWordWrap(true)
        note:SetTextColor(0.7, 0.7, 0.7)
        note:SetText(C.L.lustNoGameSounds)
        y = y - 48
    end
    for _, group in ipairs(groups) do
        local header = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header:SetPoint("TOPLEFT", child, "TOPLEFT", 8, y - 8)
        header:SetText(group.title)
        header:SetTextColor(0.85, 0.75, 0.45)
        y = y - HEADER_H
        for _, sound in ipairs(group.sounds) do
            AddRow(child, y, sound.text, sound.id)
            y = y - ROW_H
        end
    end
    child:SetHeight(-y + 4)
    RefreshRows()
end

local function TogglePopup(anchor)
    if popup and popup:IsShown() then
        HidePopup()
        return
    end
    if not popup then
        BuildPopup()
    end
    RefreshRows()
    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    catcher:Show()
    popup:Show()
end

-- Same look as Focus.lua's switch menu, but opening the scrollable list.
local function CreatePickerButton(parent, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 24)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.035, 0.035, 0.045, 0.96)

    local border = button:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetVertexColor(0, 0, 0, 0.95)

    pickerText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pickerText:SetPoint("LEFT", 9, 0)
    pickerText:SetPoint("RIGHT", -24, 0)
    pickerText:SetJustifyH("LEFT")
    pickerText:SetTextColor(0.92, 0.92, 0.92)

    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(14, 10)
    arrow:SetPoint("RIGHT", -7, 0)
    arrow:SetTexture("Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\arrow.png")

    button:SetScript("OnEnter", function()
        background:SetColorTexture(0.07, 0.07, 0.09, 0.98)
    end)
    button:SetScript("OnLeave", function()
        background:SetColorTexture(0.035, 0.035, 0.045, 0.96)
    end)
    button:SetScript("OnClick", function(self)
        TogglePopup(self)
    end)
    return button
end

local function BuildUI(panel)
    InitDB()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
    title:SetText(C.L.lustLabel)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    enableCheck = CreateFrame("CheckButton", nil, panel, "BackdropTemplate")
    enableCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    C.SkinCheckBox(enableCheck)
    local enableLabel = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 7, 0)
    -- Stop short of the 100px header icon in the top-right corner
    -- (ModuleIcons.lua), wrapping instead of running under it.
    enableLabel:SetPoint("RIGHT", panel, "RIGHT", -110, 0)
    enableLabel:SetJustifyH("LEFT")
    enableLabel:SetWordWrap(true)
    enableLabel:SetText(C.L.lustEnableLabel)
    enableCheck:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked() and true or false
        ApplyEnabled()
    end)

    local soundLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    soundLabel:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -16)
    soundLabel:SetText(C.L.lustSoundLabel)

    local picker = CreatePickerButton(panel, 250)
    picker:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 0, -4)

    local channelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    channelLabel:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 0, -14)
    channelLabel:SetText(C.L.lustChannelLabel)

    channelDrop = C.CreateSwitchMenu(panel, CHANNEL_VALUES, db.channel, function(value)
        db.channel = value
    end)
    channelDrop:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -4)

    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetSize(140, 22)
    testBtn:SetPoint("TOPLEFT", channelDrop, "BOTTOMLEFT", 0, -16)
    testBtn:SetText(C.L.lustTestButton)
    C.SkinButton(testBtn)
    testBtn:SetScript("OnClick", PlayConfigured)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", testBtn, "BOTTOMLEFT", 0, -16)
    hint:SetPoint("RIGHT", panel, "RIGHT", -110, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(C.L.lustHint)
    hint:SetTextColor(0.7, 0.7, 0.7)

    standaloneNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    standaloneNote:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)
    standaloneNote:SetPoint("RIGHT", panel, "RIGHT", -110, 0)
    standaloneNote:SetJustifyH("LEFT")
    standaloneNote:SetWordWrap(true)
    standaloneNote:SetText(C.L.lustStandaloneNote)
    standaloneNote:SetTextColor(1, 0.7, 0.3)

    -- The main window sizes itself from the panel's child *frames* only
    -- (GetModuleHeight in CC_RaidTools.lua), so trailing text gets clipped;
    -- this empty frame under the notes makes them count.
    local spacer = CreateFrame("Frame", nil, panel)
    spacer:SetSize(1, 1)
    spacer:SetPoint("TOPLEFT", standaloneNote, "BOTTOMLEFT", 0, 0)

    -- Leaving the tab (or closing the window) closes an open sound list.
    panel:HookScript("OnHide", HidePopup)
end

local function RefreshUI()
    InitDB()
    if enableCheck then
        enableCheck:SetChecked(db.enabled)
        if enableCheck._ccrtRefresh then
            enableCheck:_ccrtRefresh()
        end
    end
    if pickerText then
        pickerText:SetText(CurrentSoundName())
    end
    if channelDrop then
        channelDrop:SetValue(db.channel)
    end
    UpdateChannelState()
    if standaloneNote then
        standaloneNote:SetShown(StandaloneLoaded() and true or false)
    end
end

C.RegisterModule("LustSound", BuildUI, RefreshUI)
