-- CC RaidTools - Spec Reminder
-- Reminds the player of their current specialization at two moments where
-- it's still possible to act on it (spec cannot be changed once in combat):
-- entering a Mythic+ dungeon or a raid, and at each Ready Check.
local C = CCRT

local db
local confirmFrame
local finishAt

local REMINDER_DURATION = 15
local TIMER_H = 12
local TIMER_TEXTURE = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\atrocity.tga"
local wasInInstance = false

-- Mascot pool: one is picked at random each time the popup shows.
-- To add one, drop the PNG in TexturesGUI and list it here (new files need
-- a full game restart, /reload is not enough).
local MASCOT_PATH = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\"
local MASCOTS = {
    "SpecReminderMascot1.png",
    "SpecReminderMascot2.png",
    "SpecReminderMascot3.png",
    "SpecReminderMascot4.png",
    "SpecReminderMascot5.png",
    "SpecReminderMascot6.png",
    "SpecReminderMascot7.png",
    "SpecReminderMascot8.png",
    "SpecReminderMascot9.png",
    "SpecReminderMascot10.png",
    "SpecReminderMascot11.png",
    "SpecReminderMascot12.png",
    "SpecReminderMascot13.png",
    "SpecReminderMascot14.png",
}
local lastMascot

local function PickMascot()
    local count = #MASCOTS
    local index = math.random(count)
    -- Avoid showing the same mascot twice in a row when there is a choice.
    if count > 1 and index == lastMascot then
        index = index % count + 1
    end
    lastMascot = index
    return MASCOT_PATH .. MASCOTS[index]
end

local function InitDB()
    C.InitDB()
    CCRaidToolsDB.specReminder = CCRaidToolsDB.specReminder or {}
    db = CCRaidToolsDB.specReminder
    if db.enabled == nil then
        db.enabled = true
    end
    if db.onZoneEnter == nil then
        db.onZoneEnter = true
    end
    if db.onReadyCheck == nil then
        db.onReadyCheck = true
    end
end

-- ===== Current spec lookup (with deprecated-API fallback) =====

local function GetCurrentSpecIndex()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        return C_SpecializationInfo.GetSpecialization()
    end
    return GetSpecialization and GetSpecialization()
end

-- Returns specID, specName for the given spec index.
local function GetSpecIDAndName(index)
    if not index then
        return nil, nil
    end
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        local specID, name = C_SpecializationInfo.GetSpecializationInfo(index)
        return specID, name
    end
    if GetSpecializationInfo then
        local specID, name = GetSpecializationInfo(index)
        return specID, name
    end
    return nil, nil
end

local function GetCurrentSpecName()
    local _, name = GetSpecIDAndName(GetCurrentSpecIndex())
    return name
end

-- Returns the loot spec name and whether it's an explicit loot spec (true)
-- or just the current active spec (false, i.e. never set). Same lookup
-- pattern as BonusRoll.lua's loot-spec display.
local function GetLootSpecDisplay()
    local lootSpecID = GetLootSpecialization and GetLootSpecialization() or 0
    if lootSpecID and lootSpecID ~= 0 then
        local name
        if GetSpecializationInfoForSpecID then
            local _, n = GetSpecializationInfoForSpecID(lootSpecID)
            name = n
        elseif GetSpecializationInfoByID then
            local _, n = GetSpecializationInfoByID(lootSpecID)
            name = n
        end
        if name then
            return name, true
        end
    end
    return GetCurrentSpecName(), false
end

-- The active talent loadout/config name (e.g. "Raid", "M+") — a player can
-- be in the right specialization but the wrong saved build, which matters
-- just as much before a pull. Only worth showing if the player actually
-- has more than one saved loadout for this spec — with just one, its name
-- (often left as the default, which just duplicates the spec name, e.g.
-- "Arcanes" vs "Arcane") adds nothing and reads as confusing duplication.
--
-- Note: C_ClassTalents.GetActiveConfigID() returns the character's live
-- "working" talent state, which is a DIFFERENT object from a saved loadout
-- slot (their configIDs don't match even when the content is identical —
-- confirmed via live debug output: active config had a fresh generic ID
-- with configInfo.name just equal to the spec name, while the two actually
-- saved loadouts "M+"/"Raid" had entirely different IDs). What the in-game
-- loadout dropdown actually shows as "selected" is tracked separately via
-- GetLastSelectedSavedConfigID. There's no fully authoritative API for
-- this (per Warcraft Wiki's own Dragonflight Talent System page), so this
-- is a best-effort match, matching Blizzard's own recommended approach.
local function GetActiveLoadoutName()
    if not C_ClassTalents or not C_ClassTalents.GetLastSelectedSavedConfigID then
        return nil
    end
    local specID = GetSpecIDAndName(GetCurrentSpecIndex())
    if not specID then
        return nil
    end
    local configID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    if not configID then
        return nil
    end

    if C_ClassTalents.GetConfigIDsBySpecID then
        local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID)
        if configIDs and #configIDs <= 1 then
            return nil
        end
    end

    if not C_Traits or not C_Traits.GetConfigInfo then
        return nil
    end
    local configInfo = C_Traits.GetConfigInfo(configID)
    local name = configInfo and configInfo.name
    if name and name ~= "" then
        return name
    end
    return nil
end

-- ===== Reminder popup =====

local function EnsureConfirmFrame()
    if confirmFrame then
        return confirmFrame
    end
    InitDB()
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(340, 155)
    if db and db.framePoint then
        f:SetPoint(db.framePoint, UIParent, db.frameRelativePoint or db.framePoint, db.frameX or 0, db.frameY or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
    f:SetFrameStrata("DIALOG")
    C.ApplyPanelSkin(f)
    f:Hide()

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        db.framePoint = point
        db.frameRelativePoint = relativePoint
        db.frameX = x
        db.frameY = y
    end)

    -- Mascot portrait, front and center this time (not a faint watermark).
    local mascot = f:CreateTexture(nil, "ARTWORK")
    mascot:SetSize(150, 150)
    mascot:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -2)
    -- Texture is set by ShowReminder() each time the popup opens.
    mascot:SetAlpha(1)
    f.mascot = mascot

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetPoint("RIGHT", mascot, "LEFT", -14, 0)
    title:SetJustifyH("CENTER")
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
    title:SetText(C.L.srTitle)
    f.title = title

    local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    body:SetPoint("RIGHT", mascot, "LEFT", -14, 0)
    body:SetJustifyH("LEFT")
    body:SetWordWrap(true)
    f.body = body

    local timerBar = CreateFrame("StatusBar", nil, f)
    timerBar:SetHeight(TIMER_H)
    timerBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 8)
    timerBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 8)
    timerBar:SetMinMaxValues(0, REMINDER_DURATION)
    timerBar:SetValue(REMINDER_DURATION)
    timerBar:SetStatusBarTexture(TIMER_TEXTURE)
    timerBar:SetStatusBarColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
    timerBar.bg = timerBar:CreateTexture(nil, "BACKGROUND")
    timerBar.bg:SetAllPoints()
    timerBar.bg:SetColorTexture(0.08, 0.08, 0.10, 0.8)
    timerBar.text = timerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerBar.text:SetPoint("CENTER", 0, 1.5)
    timerBar.text:SetText(string.format(C.L.srClosingIn, REMINDER_DURATION))
    f.timerBar = timerBar

    -- Same close-X pattern as the main CC RaidTools window.
    local close = CreateFrame("Button", nil, f)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -4, -4)
    local closeTex = close:CreateTexture(nil, "ARTWORK")
    closeTex:SetPoint("CENTER")
    closeTex:SetSize(13, 13)
    closeTex:SetTexture("Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\Close.png")
    closeTex:SetVertexColor(0.851, 0.851, 0.851, 1)
    close:SetScript("OnEnter", function() closeTex:SetVertexColor(C.BRAND_R, C.BRAND_G, C.BRAND_B, 1) end)
    close:SetScript("OnLeave", function() closeTex:SetVertexColor(0.851, 0.851, 0.851, 1) end)
    close:SetScript("OnClick", function()
        finishAt = nil
        f:SetScript("OnUpdate", nil)
        f:Hide()
    end)
    f.closeButton = close

    confirmFrame = f
    return f
end

local function UpdateTimerDisplay(f)
    if not finishAt then
        return
    end
    local remaining = math.max(0, finishAt - GetTime())
    f.timerBar:SetValue(remaining)
    f.timerBar.text:SetText(string.format(C.L.srClosingIn, math.ceil(remaining)))
    if remaining <= 0 then
        finishAt = nil
        f:SetScript("OnUpdate", nil)
        f:Hide()
    end
end

local function ShowReminder()
    local f = EnsureConfirmFrame()
    local specName = GetCurrentSpecName() or C.L.srUnknownSpec
    local loadoutName = GetActiveLoadoutName()

    local lines = {}
    if C.L.srBody then
        table.insert(lines, string.format(C.L.srBody, specName))
    else
        -- Defensive last resort: never hard-error just because a locale
        -- string is missing (e.g. Locales.lua out of sync with this file).
        table.insert(lines, specName)
    end
    if loadoutName and C.L.srLoadoutLine then
        table.insert(lines, string.format(C.L.srLoadoutLine, loadoutName))
    end
    local lootSpecName = GetLootSpecDisplay()
    -- Always shown now (was previously suppressed when it matched the
    -- current spec exactly, but the guild wants it displayed every time).
    if lootSpecName and C.L.srLootSpecLine then
        table.insert(lines, string.format(C.L.srLootSpecLine, lootSpecName))
    end
    f.body:SetText(table.concat(lines, "\n"))
    if not f:IsShown() then
        f.mascot:SetTexture(PickMascot())
    end
    f:Show()

    -- Auto-dismiss after REMINDER_DURATION if the player never clicks
    -- anything — this is a reminder, not something that should block
    -- indefinitely. Restarting on every call (rather than only when not
    -- already running) so a fresh reminder always gets the full duration.
    finishAt = GetTime() + REMINDER_DURATION
    f.timerBar:SetMinMaxValues(0, REMINDER_DURATION)
    f.timerBar:SetValue(REMINDER_DURATION)
    f.timerBar.text:SetText(string.format(C.L.srClosingIn, REMINDER_DURATION))
    f._ccrtTimerElapsed = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        self._ccrtTimerElapsed = (self._ccrtTimerElapsed or 0) + elapsed
        if self._ccrtTimerElapsed >= 0.03 then
            self._ccrtTimerElapsed = 0
            UpdateTimerDisplay(self)
        end
    end)
end

-- ===== Triggers =====

-- Only fires when actually entering a new instance (not on every loading
-- screen transition within one you're already in, e.g. a wipe recall).
local function CheckZoneEntry()
    if not db.enabled or not db.onZoneEnter then
        return
    end
    local inInstance, instanceType = IsInInstance()
    if inInstance and not wasInInstance then
        local _, _, difficultyID = GetInstanceInfo()
        -- difficultyID 8 = Mythic Keystone (M+); 23 = regular Mythic
        -- 5-player ("Mythic 0") — you're in this difficulty from the moment
        -- you zone in until the keystone is actually slotted at the font,
        -- so checking only 8 would miss the window the reminder is for.
        -- Any raid difficulty also qualifies, not just Mythic raid, since
        -- spec matters regardless.
        if instanceType == "raid" or difficultyID == 8 or difficultyID == 23 then
            ShowReminder()
        end
    end
    wasInInstance = inInstance
end

local e = CreateFrame("Frame")
e:RegisterEvent("PLAYER_ENTERING_WORLD")
e:RegisterEvent("READY_CHECK")
e:SetScript("OnEvent", function(_, event)
    InitDB()
    if event == "PLAYER_ENTERING_WORLD" then
        -- Instance info can take a moment to populate right after zoning.
        C_Timer.After(0.5, CheckZoneEntry)
    elseif event == "READY_CHECK" then
        if db.enabled and db.onReadyCheck then
            ShowReminder()
        end
    end
end)

-- ===== Settings UI =====

local function BuildUI(panel)
    InitDB()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
    title:SetText(C.L.srLabel)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    local enableCheck = CreateFrame("CheckButton", nil, panel, "BackdropTemplate")
    enableCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    C.SkinCheckBox(enableCheck)
    local enableLabel = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 7, 0)
    enableLabel:SetText(C.L.srEnableLabel)
    enableCheck:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked() and true or false
    end)

    local zoneCheck = CreateFrame("CheckButton", nil, panel, "BackdropTemplate")
    zoneCheck:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -34)
    C.SkinCheckBox(zoneCheck)
    local zoneLabel = zoneCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneLabel:SetPoint("LEFT", zoneCheck, "RIGHT", 7, 0)
    zoneLabel:SetText(C.L.srZoneEnterLabel)
    zoneCheck:SetScript("OnClick", function(self)
        db.onZoneEnter = self:GetChecked() and true or false
    end)

    local readyCheck = CreateFrame("CheckButton", nil, panel, "BackdropTemplate")
    readyCheck:SetPoint("TOPLEFT", zoneCheck, "BOTTOMLEFT", 0, -34)
    C.SkinCheckBox(readyCheck)
    local readyLabel = readyCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    readyLabel:SetPoint("LEFT", readyCheck, "RIGHT", 7, 0)
    readyLabel:SetText(C.L.srReadyCheckLabel)
    readyCheck:SetScript("OnClick", function(self)
        db.onReadyCheck = self:GetChecked() and true or false
    end)

    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetSize(140, 22)
    testBtn:SetPoint("TOPLEFT", readyCheck, "BOTTOMLEFT", 0, -34)
    testBtn:SetText(C.L.srTestButton)
    C.SkinButton(testBtn)
    testBtn:SetScript("OnClick", ShowReminder)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", testBtn, "BOTTOMLEFT", 0, -12)
    hint:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(C.L.srHint)
    hint:SetTextColor(0.7, 0.7, 0.7)

    panel.enableCheck = enableCheck
    panel.zoneCheck = zoneCheck
    panel.readyCheck = readyCheck
end

local function RefreshUI(panel)
    InitDB()
    if panel and panel.enableCheck then
        panel.enableCheck:SetChecked(db.enabled)
        if panel.enableCheck._ccrtRefresh then
            panel.enableCheck:_ccrtRefresh()
        end
    end
    if panel and panel.zoneCheck then
        panel.zoneCheck:SetChecked(db.onZoneEnter)
        if panel.zoneCheck._ccrtRefresh then
            panel.zoneCheck:_ccrtRefresh()
        end
    end
    if panel and panel.readyCheck then
        panel.readyCheck:SetChecked(db.onReadyCheck)
        if panel.readyCheck._ccrtRefresh then
            panel.readyCheck:_ccrtRefresh()
        end
    end
end

C.RegisterModule("SpecReminder", BuildUI, RefreshUI)
