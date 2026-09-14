-- CC RaidTools - Spec Reminder
-- Reminds the player of their current specialization at two moments where
-- it's still possible to act on it (spec cannot be changed once in combat):
-- entering a Mythic+ dungeon or a raid, and at each Ready Check.
local C = CCRT

local db
local confirmFrame
local wasInInstance = false

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

local function GetCurrentSpecName()
    local index
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        index = C_SpecializationInfo.GetSpecialization()
    else
        index = GetSpecialization and GetSpecialization()
    end
    if not index then
        return nil
    end
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        local _, name = C_SpecializationInfo.GetSpecializationInfo(index)
        return name
    end
    if GetSpecializationInfo then
        local _, name = GetSpecializationInfo(index)
        return name
    end
    return nil
end

-- ===== Reminder popup =====

local function EnsureConfirmFrame()
    if confirmFrame then
        return confirmFrame
    end
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(300, 120)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    f:SetFrameStrata("DIALOG")
    C.ApplyPanelSkin(f)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
    title:SetText(C.L.srTitle)
    f.title = title

    local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 12, -34)
    body:SetPoint("RIGHT", -12, 0)
    body:SetJustifyH("LEFT")
    body:SetWordWrap(true)
    f.body = body

    local confirmBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    confirmBtn:SetSize(160, 24)
    confirmBtn:SetPoint("BOTTOM", 0, 14)
    confirmBtn:SetText(C.L.srConfirmButton)
    C.SkinButton(confirmBtn)
    confirmBtn:SetScript("OnClick", function()
        f:Hide()
    end)
    f.confirmBtn = confirmBtn

    confirmFrame = f
    return f
end

local function ShowReminder()
    local f = EnsureConfirmFrame()
    local specName = GetCurrentSpecName() or C.L.srUnknownSpec
    f.body:SetText(string.format(C.L.srBody, specName))
    f:Show()
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
        -- difficultyID 8 = Mythic Keystone (M+); any raid difficulty also
        -- qualifies, not just Mythic raid, since spec matters regardless.
        if instanceType == "raid" or difficultyID == 8 then
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
