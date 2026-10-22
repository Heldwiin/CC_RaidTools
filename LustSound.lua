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
-- The sound is either the bundled Apocalypse file (default) or one of the
-- sounds of BigWigs, EllesmereUI or Northern Sky Raid Tools, whichever of
-- those addons is installed.
local C = CCRT

local db

local SOUND = "Interface\\AddOns\\CC_RaidTools\\sounds\\Apocalypse.ogg"
local SOUND_PI = "Interface\\AddOns\\CC_RaidTools\\sounds\\Bam.ogg"

-- Power Infusion (priest). Its buff is read directly: unlike the lust buff
-- there is no lockout debuff to watch instead, so this only fires when the
-- game lets addons see the aura.
local PI_SPELL_ID = 10060

-- The two alerts share the sound catalog, the picker and the audio channel;
-- each has its own pair of saved fields (source addon + sound key, both nil =
-- the bundled default file).
local KINDS = {
    lust = { source = "soundSource", name = "soundName", file = SOUND },
    pi = { source = "piSoundSource", name = "piSoundName", file = SOUND_PI },
}

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

local SOURCES = { bigwigs = true, ellesmere = true, nsrt = true }

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
    -- nil/nil means the bundled Apocalypse file; otherwise the sound is named
    -- by the addon it comes from and its key there. The name is stored rather
    -- than a file path, so it survives that addon moving its files around.
    for _, kind in pairs(KINDS) do
        if not (SOURCES[db[kind.source]] and type(db[kind.name]) == "string") then
            db[kind.source], db[kind.name] = nil, nil
        end
    end
    if db.piEnabled == nil then
        db.piEnabled = false
    end
    -- Earlier development builds stored a game sound kit ID here.
    db.soundKit = nil
end

-- ===== Sound catalog =====
-- Built from whichever of the three addons is installed:
--   * BigWigs and NSRT register their sounds in LibSharedMedia-3.0
--     (name -> file path or file ID); they are told apart by the "BigWigs: "
--     name prefix / the folder the file lives in;
--   * EllesmereUI keeps its own list and exposes it through
--     EllesmereUI.BuildAlertSoundTables().
-- Each group is { source, title, sounds = { { key, text, value } } }, where
-- value is something PlaySoundFile accepts (path or file ID).

local catalog

local function StripColor(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function ByName(a, b)
    return StripColor(a.text):lower() < StripColor(b.text):lower()
end

local function CollectSharedMedia()
    local bigwigs, nsrt = {}, {}
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    local registered = lsm and lsm:HashTable("sound")
    if type(registered) ~= "table" then
        return bigwigs, nsrt
    end
    for name, value in pairs(registered) do
        if type(name) == "string" and (type(value) == "string" or type(value) == "number") then
            local path = type(value) == "string" and value:lower() or ""
            if name:find("^BigWigs: ") or path:find("\\addons\\bigwigs\\", 1, true) then
                table.insert(bigwigs, { key = name, text = (name:gsub("^BigWigs: ", "")), value = value })
            elseif path:find("northernskyraidtools", 1, true) then
                table.insert(nsrt, { key = name, text = name, value = value })
            end
        end
    end
    table.sort(bigwigs, ByName)
    table.sort(nsrt, ByName)
    return bigwigs, nsrt
end

local function CollectEllesmere()
    local eui = _G.EllesmereUI
    if type(eui) ~= "table" or type(eui.BuildAlertSoundTables) ~= "function" then
        return nil
    end
    local ok, paths, names, order = pcall(eui.BuildAlertSoundTables)
    if not ok or type(paths) ~= "table" or type(order) ~= "table" then
        return nil
    end
    local sounds = {}
    for _, key in ipairs(order) do
        -- "none" has a name but no file.
        if paths[key] then
            table.insert(sounds, { key = key, text = (type(names) == "table" and names[key]) or key, value = paths[key] })
        end
    end
    return sounds
end

local function GetCatalog()
    if catalog then
        return catalog
    end
    catalog = {}
    local bigwigs, nsrt = CollectSharedMedia()
    local ellesmere = CollectEllesmere()
    if #bigwigs > 0 then
        table.insert(catalog, { source = "bigwigs", title = "BigWigs", sounds = bigwigs })
    end
    if ellesmere and #ellesmere > 0 then
        table.insert(catalog, { source = "ellesmere", title = "EllesmereUI", sounds = ellesmere })
    end
    if #nsrt > 0 then
        table.insert(catalog, { source = "nsrt", title = "Northern Sky Raid Tools", sounds = nsrt })
    end
    return catalog
end

local function FindSound(source, key)
    if not source then
        return nil
    end
    for _, group in ipairs(GetCatalog()) do
        if group.source == source then
            for _, sound in ipairs(group.sounds) do
                if sound.key == key then
                    return sound, group
                end
            end
        end
    end
end

local function DefaultLabel(kind)
    return kind == "pi" and C.L.piSoundDefault or C.L.lustSoundDefault
end

local function CurrentSoundName(kind)
    local fields = KINDS[kind]
    if not db[fields.source] then
        return DefaultLabel(kind)
    end
    local sound, group = FindSound(db[fields.source], db[fields.name])
    if sound then
        return group.title .. " - " .. sound.text
    end
    return db[fields.name]
end

-- Falls back to the bundled sound when the addon the choice came from is gone.
local function ResolveSound(kind)
    local fields = KINDS[kind or "lust"]
    local sound = FindSound(db[fields.source], db[fields.name])
    return sound and sound.value or fields.file
end

local function PlayConfigured(kind)
    PlaySoundFile(ResolveSound(kind), db.channel)
end

-- ===== Power Infusion: engine-side aura sound =====
-- The buff is a secret value in combat, so an addon cannot see it appear. The
-- game can: C_UnitAuras.AddAuraSound registers a sound that the client itself
-- plays when the aura is added, secret or not. It only needs to be registered
-- outside combat, and again whenever the sound or channel changes. Without
-- that API the UNIT_AURA path further down is used instead (out of combat only).
local piSoundID
local piPending = false       -- registration postponed until combat ends

local function RemovePISound()
    if piSoundID and C_UnitAuras.RemoveAuraSound then
        pcall(C_UnitAuras.RemoveAuraSound, piSoundID)
    end
    piSoundID = nil
end

local function RegisterPISound()
    RemovePISound()
    piPending = false
    if not (db and db.piEnabled and C_UnitAuras.AddAuraSound and Enum.UnitAuraSoundTrigger) then
        return
    end
    if InCombatLockdown() then
        piPending = true
        return
    end
    local value = ResolveSound("pi")
    local info = { unitToken = "player", spellID = PI_SPELL_ID, outputChannel = db.channel, throttleSeconds = 2 }
    if type(value) == "number" then
        info.soundFileID = value
    else
        info.soundFileName = value
    end
    local ok, id = pcall(C_UnitAuras.AddAuraSound, Enum.UnitAuraSoundTrigger.Added, info)
    if ok and id then
        piSoundID = id
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

local wasInfused = false

local function FindPowerInfusion()
    return C_UnitAuras.GetPlayerAuraBySpellID(PI_SPELL_ID)
end

local function SyncState()
    wasLockedOut = FindLockoutAura() ~= nil
    wasInfused = FindPowerInfusion() ~= nil
end

local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(_, event, _, updateInfo)
    if event == "PLAYER_LEAVING_WORLD" then
        ready = false
        generation = generation + 1
        RemovePISound()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        -- Left combat: register the Power Infusion sound if it had to wait.
        if piPending and ready then
            RegisterPISound()
        end
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
                RegisterPISound()
            end
        end)
        return
    end

    -- UNIT_AURA
    local aura = FindLockoutAura()
    local locked = aura ~= nil
    -- Sound only on a fresh lockout APPEARING: never during loading, on a
    -- full aura refresh, or for an old lust (reload, relog, zone change).
    if db.enabled and ready and locked and not wasLockedOut
        and not IsFullUpdate(updateInfo)
        and IsFresh(aura) and not StandaloneLoaded() then
        PlayConfigured("lust")
    end
    wasLockedOut = locked

    -- Same rule for Power Infusion appearing on the player, only when the
    -- engine-side sound is not in charge (it would play twice).
    local infusion = FindPowerInfusion()
    local infused = infusion ~= nil
    if db.piEnabled and not piSoundID and ready and infused and not wasInfused
        and not IsFullUpdate(updateInfo) and IsFresh(infusion) then
        PlayConfigured("pi")
    end
    wasInfused = infused
end)

-- UNIT_AURA fires constantly in combat, so it is only registered while the
-- option is on.
local function ApplyEnabled(fromLogin)
    InitDB()
    watcher:UnregisterAllEvents()
    generation = generation + 1
    RemovePISound()
    if db.enabled or db.piEnabled then
        watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
        watcher:RegisterEvent("PLAYER_LEAVING_WORLD")
        watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        watcher:RegisterUnitEvent("UNIT_AURA", "player")
        if fromLogin then
            -- PLAYER_ENTERING_WORLD follows and re-arms once loading settles.
            ready = false
        else
            -- Enabled from the panel while already in the world: taking the
            -- current state first means a lockout already running is ignored.
            SyncState()
            ready = true
            RegisterPISound()
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
local POPUP_W, POPUP_H = 300, 300

local layout, standaloneNote
local pickerTexts = {}          -- kind -> picker button label
local popup, catcher
local popupKind = "lust"        -- which alert the open list is choosing for
local defaultRow
local rows = {}

local function RefreshRows()
    local fields = KINDS[popupKind]
    for _, row in ipairs(rows) do
        if row.source == db[fields.source] and row.key == db[fields.name] then
            row.text:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
        else
            row.text:SetTextColor(0.92, 0.92, 0.92)
        end
    end
end

local function SelectSound(source, key)
    local fields = KINDS[popupKind]
    db[fields.source], db[fields.name] = source, key
    if pickerTexts[popupKind] then
        pickerTexts[popupKind]:SetText(CurrentSoundName(popupKind))
    end
    RefreshRows()
    if popupKind == "pi" and ready then
        RegisterPISound()
    end
    -- Clicking a sound plays it, so the list doubles as a preview.
    PlayConfigured(popupKind)
end

local function HidePopup()
    if popup then
        popup:Hide()
    end
    if catcher then
        catcher:Hide()
    end
end

local function AddRow(child, y, text, source, key)
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
    row.text:SetWordWrap(false)
    row.text:SetText(text)
    row.source, row.key = source, key
    row:SetScript("OnClick", function()
        SelectSound(row.source, row.key)
    end)
    table.insert(rows, row)
    return row
end

-- Built on first open: up to ~100 rows that are never needed unless the
-- player actually browses the list.
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
    defaultRow = AddRow(child, y, C.L.lustSoundDefault, nil, nil)
    y = y - ROW_H

    local groups = GetCatalog()
    if #groups == 0 then
        local note = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        note:SetPoint("TOPLEFT", child, "TOPLEFT", 8, y - 8)
        note:SetPoint("RIGHT", child, "RIGHT", -4, 0)
        note:SetJustifyH("LEFT")
        note:SetWordWrap(true)
        note:SetTextColor(0.7, 0.7, 0.7)
        note:SetText(C.L.lustNoSounds)
        y = y - 64
    end
    for _, group in ipairs(groups) do
        local header = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header:SetPoint("TOPLEFT", child, "TOPLEFT", 8, y - 8)
        header:SetText(group.title)
        header:SetTextColor(0.85, 0.75, 0.45)
        y = y - HEADER_H
        for _, sound in ipairs(group.sounds) do
            AddRow(child, y, sound.text, group.source, sound.key)
            y = y - ROW_H
        end
    end
    child:SetHeight(-y + 4)
    RefreshRows()
end

local function TogglePopup(anchor, kind)
    -- A click on the other alert's picker switches the list to it.
    if popup and popup:IsShown() and popupKind == kind then
        HidePopup()
        return
    end
    if not popup then
        BuildPopup()
    end
    popupKind = kind
    defaultRow.text:SetText(DefaultLabel(kind))
    RefreshRows()
    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    catcher:Show()
    popup:Show()
end

-- Same look as the shared dropdown, but opening the scrollable list.
local function CreatePickerButton(parent, width, kind)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 24)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.035, 0.035, 0.045, 0.96)

    local border = button:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetVertexColor(0, 0, 0, 0.95)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 9, 0)
    label:SetPoint("RIGHT", -24, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetTextColor(0.92, 0.92, 0.92)
    pickerTexts[kind] = label

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
        TogglePopup(self, kind)
    end)
    return button
end

local function BuildUI(panel)
    InitDB()
    local UI = C.UI
    UI.Band(panel, "LustSound", C.L.lustIntro)

    layout = UI.NewLayout(panel)

    layout:Header(C.L.uiSectionOptions)
    layout:Toggle({
        label = C.L.lustEnableLabel,
        desc = C.L.lustEnableDesc,
        get = function() return db.enabled end,
        set = function(value)
            db.enabled = value
            ApplyEnabled()
        end,
    })

    layout:Header(C.L.lustSectionSound)
    -- The sound list needs a wider control than a plain dropdown, so this row
    -- hosts the picker button; the list itself opens in BuildPopup.
    local soundRow = layout:Row({ label = C.L.lustSoundLabel, desc = C.L.lustSoundDesc }, false, 268)
    local picker = CreatePickerButton(soundRow, 250, "lust")
    picker:SetPoint("RIGHT", soundRow, "RIGHT", -6, 0)

    layout:Button({
        label = C.L.lustTestLabel,
        text = C.L.lustTestButton,
        onClick = function() PlayConfigured("lust") end,
    })

    layout:Note(C.L.lustHint)
    standaloneNote = layout:Note(C.L.lustStandaloneNote, { 1, 0.7, 0.3 })

    layout:Header(C.L.piSection)
    layout:Toggle({
        label = C.L.piEnableLabel,
        desc = C.L.piEnableDesc,
        get = function() return db.piEnabled end,
        set = function(value)
            db.piEnabled = value
            ApplyEnabled()
        end,
    })
    local piRow = layout:Row({ label = C.L.lustSoundLabel, desc = C.L.piSoundDesc, parent = function() return db.piEnabled end }, false, 268)
    local piPicker = CreatePickerButton(piRow, 250, "pi")
    piPicker:SetPoint("RIGHT", piRow, "RIGHT", -6, 0)
    layout:Button({
        label = C.L.lustTestLabel,
        text = C.L.lustTestButton,
        onClick = function() PlayConfigured("pi") end,
    })
    layout:Note(C.L.piHint)

    layout:Header(C.L.lustChannelHeader)
    layout:Choice({
        label = C.L.lustChannelLabel,
        desc = C.L.lustChannelDesc,
        values = CHANNEL_VALUES,
        get = function() return db.channel end,
        set = function(value)
            db.channel = value
            if ready then
                RegisterPISound()
            end
        end,
    })
    layout:Finish()

    -- Leaving the tab (or closing the window) closes an open sound list.
    panel:HookScript("OnHide", HidePopup)
end

local function RefreshUI()
    InitDB()
    if layout then
        layout:Refresh()
    end
    for kind, label in pairs(pickerTexts) do
        label:SetText(CurrentSoundName(kind))
    end
    if standaloneNote then
        standaloneNote:SetShown(StandaloneLoaded() and true or false)
    end
end

C.RegisterModule("LustSound", BuildUI, RefreshUI)
