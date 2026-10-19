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
end

-- If the standalone addon is still installed it plays the sound itself;
-- stay silent rather than doubling it.
local function StandaloneLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("SonDuLust")
end

local function IsLockedOut()
    for i = 1, #LOCKOUTS do
        if C_UnitAuras.GetPlayerAuraBySpellID(LOCKOUTS[i]) then
            return true
        end
    end
    return false
end

local wasLockedOut = false

local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(_, event)
    local locked = IsLockedOut()
    -- Sound only on the debuff APPEARING, never at login, /reload or a zone
    -- change (PLAYER_ENTERING_WORLD only records the starting state).
    if event == "UNIT_AURA" and locked and not wasLockedOut and not StandaloneLoaded() then
        PlaySoundFile(SOUND, db.channel)
    end
    wasLockedOut = locked
end)

-- UNIT_AURA fires constantly in combat, so it is only registered while the
-- option is on.
local function ApplyEnabled()
    InitDB()
    watcher:UnregisterAllEvents()
    if db.enabled then
        -- Taking the current state first means enabling the option while a
        -- lockout is already running doesn't play the sound.
        wasLockedOut = IsLockedOut()
        watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
        watcher:RegisterUnitEvent("UNIT_AURA", "player")
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", ApplyEnabled)

-- ===== Settings UI =====

local enableCheck, channelDrop, standaloneNote

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

    local channelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    channelLabel:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -16)
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
    testBtn:SetScript("OnClick", function()
        PlaySoundFile(SOUND, db.channel)
    end)

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
end

local function RefreshUI()
    InitDB()
    if enableCheck then
        enableCheck:SetChecked(db.enabled)
        if enableCheck._ccrtRefresh then
            enableCheck:_ccrtRefresh()
        end
    end
    if channelDrop then
        channelDrop:SetValue(db.channel)
    end
    if standaloneNote then
        standaloneNote:SetShown(StandaloneLoaded() and true or false)
    end
end

C.RegisterModule("LustSound", BuildUI, RefreshUI)
