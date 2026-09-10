-- CC RaidTools - Bonus Roll Confirm
-- Adds a confirmation step before a bonus roll (Roll or Pass) actually goes
-- through, showing the loot specialization it will award for, so a mis-click
-- doesn't burn a roll (or waste one on the wrong spec) by accident.
--
-- Technical note: Blizzard's bonus roll Roll/Pass buttons are tied to a
-- protected action (rolling triggers a real spell cast under the hood), so
-- an addon cannot click them programmatically — attempting to do so via a
-- secure "clickbutton" redirect throws ADDON_ACTION_BLOCKED. Instead of
-- trying to click for the player, this module briefly DISABLES the native
-- buttons the instant the bonus roll prompt appears, shows our own
-- confirmation, and re-enables them once the player confirms — the actual
-- roll/pass is still a genuine click on Blizzard's own button.
local C = CCRT

local db
local confirmFrame
local safetyTimer

local function InitDB()
    C.InitDB()
    CCRaidToolsDB.bonusRoll = CCRaidToolsDB.bonusRoll or {}
    db = CCRaidToolsDB.bonusRoll
    if db.enabled == nil then
        db.enabled = true
    end
    if db.confirmPass == nil then
        db.confirmPass = true
    end
end

-- ===== Loot specialization lookup (with deprecated-API fallback) =====

local function GetCurrentSpecIndex()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        return C_SpecializationInfo.GetSpecialization()
    end
    return GetSpecialization and GetSpecialization()
end

local function GetSpecNameByIndex(specIndex)
    if not specIndex then
        return nil
    end
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        local _, name = C_SpecializationInfo.GetSpecializationInfo(specIndex)
        return name
    end
    if GetSpecializationInfo then
        local _, name = GetSpecializationInfo(specIndex)
        return name
    end
    return nil
end

local function GetSpecNameByID(specID)
    if not specID or specID == 0 then
        return nil
    end
    if GetSpecializationInfoForSpecID then
        local _, name = GetSpecializationInfoForSpecID(specID)
        return name
    end
    if GetSpecializationInfoByID then
        local _, name = GetSpecializationInfoByID(specID)
        return name
    end
    return nil
end

-- Returns the loot spec display name and whether it's an explicit loot spec
-- (true) or just the player's current active spec (false).
local function GetLootSpecDisplay()
    local lootSpecID = GetLootSpecialization and GetLootSpecialization() or 0
    if lootSpecID and lootSpecID ~= 0 then
        local name = GetSpecNameByID(lootSpecID)
        if name then
            return name, true
        end
    end
    local name = GetSpecNameByIndex(GetCurrentSpecIndex())
    return name, false
end

-- ===== Native button access =====

local function GetBonusRollButtons()
    local f = _G.BonusRollFrame
    local prompt = f and f.PromptFrame
    if not prompt then
        return nil
    end
    return prompt, prompt.RollButton, prompt.PassButton
end

local function CancelSafetyTimer()
    if safetyTimer then
        safetyTimer:Cancel()
        safetyTimer = nil
    end
end

-- Always re-enables the native buttons, whatever happened. Called on
-- confirm, on cancel, when the prompt closes on its own, and as a last
-- resort safety timeout — never leave the player stuck with the real
-- buttons disabled.
local function ReleaseButtons()
    local _, rollBtn, passBtn = GetBonusRollButtons()
    if rollBtn then
        rollBtn:Enable()
    end
    if passBtn then
        passBtn:Enable()
    end
    CancelSafetyTimer()
end

local function HideConfirm()
    if confirmFrame then
        confirmFrame:Hide()
    end
end

-- ===== Confirmation popup =====

local function EnsureConfirmFrame()
    if confirmFrame then
        return confirmFrame
    end
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(320, 150)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    f:SetFrameStrata("DIALOG")
    C.ApplyPanelSkin(f)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
    title:SetText(C.L.brTitle)
    f.title = title

    local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 12, -34)
    body:SetPoint("RIGHT", -12, 0)
    body:SetJustifyH("LEFT")
    body:SetWordWrap(true)
    f.body = body

    local rollBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    rollBtn:SetSize(130, 24)
    rollBtn:SetPoint("BOTTOMLEFT", 12, 40)
    rollBtn:SetText(C.L.brConfirmRollButton)
    C.SkinButton(rollBtn)
    rollBtn:SetScript("OnClick", function()
        local _, nativeRollBtn = GetBonusRollButtons()
        if nativeRollBtn then
            nativeRollBtn:Enable()
        end
        CancelSafetyTimer()
        HideConfirm()
        print(C.L.brRollConfirmed)
    end)
    f.rollBtn = rollBtn

    local passBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    passBtn:SetSize(130, 24)
    passBtn:SetPoint("BOTTOMRIGHT", -12, 40)
    passBtn:SetText(C.L.brConfirmPassButton)
    C.SkinButton(passBtn)
    passBtn:SetScript("OnClick", function()
        local _, _, nativePassBtn = GetBonusRollButtons()
        if nativePassBtn then
            nativePassBtn:Enable()
        end
        CancelSafetyTimer()
        HideConfirm()
        print(C.L.brPassConfirmed)
    end)
    f.passBtn = passBtn

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(270, 22)
    closeBtn:SetPoint("BOTTOM", 0, 12)
    closeBtn:SetText(C.L.brCloseButton)
    C.SkinButton(closeBtn)
    closeBtn:SetScript("OnClick", function()
        -- Leave without deciding: release whatever was disabled so the
        -- player is never stuck, without printing a roll/pass confirmation.
        ReleaseButtons()
        HideConfirm()
    end)
    f.closeBtn = closeBtn

    confirmFrame = f
    return f
end

-- passOffered: whether Pass is also gated (db.confirmPass) and needs its own
-- confirm button here, or was left natively clickable and shouldn't be
-- offered redundantly.
local function ShowConfirm(passOffered)
    local f = EnsureConfirmFrame()
    local specName, isExplicit = GetLootSpecDisplay()
    local specLabel = specName or C.L.brUnknownSpec
    f.body:SetText(string.format(isExplicit and C.L.brBodyExplicit or C.L.brBodyCurrent, specLabel))

    if passOffered then
        f.passBtn:Show()
        f.rollBtn:ClearAllPoints()
        f.rollBtn:SetPoint("BOTTOMLEFT", 12, 40)
    else
        f.passBtn:Hide()
        f.rollBtn:ClearAllPoints()
        f.rollBtn:SetPoint("BOTTOM", 0, 40)
    end

    f:Show()
end

-- ===== Event handling =====

local function OnBonusRollStarted(rollID)
    InitDB()
    if not db.enabled then
        return
    end
    local prompt, rollBtn, passBtn = GetBonusRollButtons()
    if not prompt or not rollBtn then
        return
    end

    rollBtn:Disable()
    local passOffered = db.confirmPass and passBtn ~= nil
    if passOffered then
        passBtn:Disable()
    end

    ShowConfirm(passOffered)

    -- Safety net: never leave the real buttons stuck disabled, even if
    -- something above goes wrong or the player alt-tabs away.
    CancelSafetyTimer()
    safetyTimer = C_Timer.NewTimer(45, function()
        safetyTimer = nil
        ReleaseButtons()
        HideConfirm()
    end)
end

local function OnBonusRollResult()
    HideConfirm()
    ReleaseButtons()
end

-- ===== Settings UI =====

local function BuildUI(panel)
    InitDB()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
    title:SetText(C.L.brLabel)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    local enableCheck = CreateFrame("CheckButton", nil, panel, "BackdropTemplate")
    enableCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    C.SkinCheckBox(enableCheck)
    local enableLabel = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 7, 0)
    enableLabel:SetText(C.L.brEnableLabel)
    enableCheck:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked() and true or false
    end)

    local passCheck = CreateFrame("CheckButton", nil, panel, "BackdropTemplate")
    passCheck:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -34)
    C.SkinCheckBox(passCheck)
    local passLabel = passCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    passLabel:SetPoint("LEFT", passCheck, "RIGHT", 7, 0)
    passLabel:SetText(C.L.brConfirmPassLabel)
    passCheck:SetScript("OnClick", function(self)
        db.confirmPass = self:GetChecked() and true or false
    end)

    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetSize(140, 22)
    testBtn:SetPoint("TOPLEFT", passCheck, "BOTTOMLEFT", 0, -34)
    testBtn:SetText(C.L.brTestButton)
    C.SkinButton(testBtn)
    testBtn:SetScript("OnClick", function()
        ShowConfirm(db.confirmPass)
    end)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", testBtn, "BOTTOMLEFT", 0, -12)
    hint:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(C.L.brHint)
    hint:SetTextColor(0.7, 0.7, 0.7)

    panel.enableCheck = enableCheck
    panel.passCheck = passCheck
end

local function RefreshUI(panel)
    InitDB()
    if panel and panel.enableCheck then
        panel.enableCheck:SetChecked(db.enabled)
        if panel.enableCheck._ccrtRefresh then
            panel.enableCheck:_ccrtRefresh()
        end
    end
    if panel and panel.passCheck then
        panel.passCheck:SetChecked(db.confirmPass)
        if panel.passCheck._ccrtRefresh then
            panel.passCheck:_ccrtRefresh()
        end
    end
end

C.RegisterModule("BonusRoll", BuildUI, RefreshUI)

local e = CreateFrame("Frame")
e:RegisterEvent("BONUS_ROLL_STARTED")
e:RegisterEvent("BONUS_ROLL_RESULT")
e:SetScript("OnEvent", function(_, event, a)
    if event == "BONUS_ROLL_STARTED" then
        OnBonusRollStarted(a)
    elseif event == "BONUS_ROLL_RESULT" then
        OnBonusRollResult()
    end
end)
