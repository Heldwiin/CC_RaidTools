-- CC RaidTools - Bonus Roll Confirm
-- Adds a confirmation step before a bonus roll (Roll or Pass) actually goes
-- through, showing the loot specialization it will award for, so a mis-click
-- doesn't burn a roll (or waste one on the wrong spec) by accident.
--
-- Technical note: rolling triggers a real spell cast under the hood, so this
-- cannot simulate a click on Blizzard's Roll/Pass buttons for the player —
-- redirecting a secure button's clickbutton attribute at them to fake a
-- click throws ADDON_ACTION_BLOCKED. Instead, this hooks each button's own
-- OnClick handler: a real click on Roll/Pass is intercepted, shows our
-- confirmation, and only calls the original (captured) handler once the
-- player confirms. That still runs as a direct consequence of a genuine
-- click (first on the native button, then on our own confirm button), just
-- not the exact same click — no secure-template click simulation involved.
local C = CCRT

local db
local confirmFrame

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

-- ===== Confirmation popup =====
-- One dynamic popup, reused for both roll and pass confirmations — shows
-- the relevant message for whichever native button was actually clicked and
-- calls the supplied callback (which finishes the real action) on confirm.

local function EnsureConfirmFrame()
    if confirmFrame then
        return confirmFrame
    end
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(320, 140)
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

    local confirmBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    confirmBtn:SetSize(140, 24)
    confirmBtn:SetPoint("BOTTOMLEFT", 16, 14)
    C.SkinButton(confirmBtn)
    f.confirmBtn = confirmBtn

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(140, 24)
    cancelBtn:SetPoint("BOTTOMRIGHT", -16, 14)
    cancelBtn:SetText(C.L.brCancelButton)
    C.SkinButton(cancelBtn)
    cancelBtn:SetScript("OnClick", function()
        f:Hide()
    end)
    f.cancelBtn = cancelBtn

    confirmFrame = f
    return f
end

-- kind: "roll" or "pass". onConfirm: called if the player confirms — this
-- is what actually performs the real action (invokes the captured original
-- button handler).
local function ShowConfirm(kind, onConfirm)
    local f = EnsureConfirmFrame()

    if kind == "roll" then
        local specName, isExplicit = GetLootSpecDisplay()
        local specLabel = specName or C.L.brUnknownSpec
        f.body:SetText(string.format(isExplicit and C.L.brBodyExplicit or C.L.brBodyCurrent, specLabel))
        f.confirmBtn:SetText(C.L.brConfirmRollButton)
    else
        f.body:SetText(C.L.brPassBody)
        f.confirmBtn:SetText(C.L.brConfirmPassButton)
    end

    f.confirmBtn:SetScript("OnClick", function()
        f:Hide()
        if onConfirm then
            onConfirm()
        end
    end)

    f:Show()
end

-- ===== Native button hooking =====

-- Wraps btn's own OnClick so a real click shows our confirmation instead of
-- immediately performing the action; the captured original only runs if the
-- player confirms. Idempotent — safe to call repeatedly on the same button.
local function HookButton(btn, kind)
    if not btn or btn._ccrtBonusHooked then
        return
    end
    local original = btn:GetScript("OnClick")
    if not original then
        return
    end
    btn._ccrtBonusHooked = true
    btn:SetScript("OnClick", function(self, button, down)
        if kind == "pass" and not db.confirmPass then
            original(self, button, down)
            return
        end
        ShowConfirm(kind, function()
            original(self, button, down)
            print(kind == "roll" and C.L.brRollConfirmed or C.L.brPassConfirmed)
        end)
    end)
end

local function TryHookBonusRollFrame()
    InitDB()
    if not db.enabled then
        return
    end
    local f = _G.BonusRollFrame
    local prompt = f and f.PromptFrame
    if not prompt then
        return
    end
    if prompt.RollButton then
        HookButton(prompt.RollButton, "roll")
    end
    if prompt.PassButton then
        HookButton(prompt.PassButton, "pass")
    end
end

-- ===== Settings UI =====

local layout

local function BuildUI(panel)
    InitDB()
    local UI = C.UI
    UI.Band(panel, "BonusRoll", C.L.brIntro)

    layout = UI.NewLayout(panel)

    layout:Header(C.L.uiSectionOptions)
    layout:Toggle({
        label = C.L.brEnableLabel,
        desc = C.L.brEnableDesc,
        get = function() return db.enabled end,
        set = function(value) db.enabled = value end,
    })
    layout:Toggle({
        label = C.L.brConfirmPassLabel,
        desc = C.L.brConfirmPassDesc,
        indent = true,
        parent = function() return db.enabled end,
        get = function() return db.confirmPass end,
        set = function(value) db.confirmPass = value end,
    })

    layout:Header(C.L.uiSectionPreview)
    layout:Button({
        label = C.L.brTestLabel,
        text = C.L.uiTestButton,
        onClick = function()
            ShowConfirm("roll", function() end)
        end,
    })

    layout:Note(C.L.brHint)
    layout:Finish()
end

local function RefreshUI()
    InitDB()
    if layout then
        layout:Refresh()
    end
end

C.RegisterModule("BonusRoll", BuildUI, RefreshUI)


-- Hook from multiple entry points, all idempotent thanks to the
-- _ccrtBonusHooked flag on each button — whichever fires first (or all of
-- them) ends up hooking exactly once per button.
if _G.BonusRollFrame_StartBonusRoll then
    hooksecurefunc("BonusRollFrame_StartBonusRoll", TryHookBonusRollFrame)
end

local e = CreateFrame("Frame")
e:RegisterEvent("BONUS_ROLL_STARTED")
e:SetScript("OnEvent", function(_, event)
    if event == "BONUS_ROLL_STARTED" then
        -- A frame or two of headroom in case BonusRollFrame.PromptFrame's
        -- buttons aren't fully populated at the exact moment this fires.
        C_Timer.After(0.1, TryHookBonusRollFrame)
    end
end)
