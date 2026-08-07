-- CC RaidTools - contrôles UI complémentaires du Ready Check
-- Ce fichier ne contient aucune logique d'invitation.

local uiInjected = false
local uiWatcher

local function SkinButton(button)
    if not button or button._ccrtSkin then return end
    button._ccrtSkin = true
    if button.Left then button.Left:Hide() end
    if button.Middle then button.Middle:Hide() end
    if button.Right then button.Right:Hide() end
    if button.LeftDisabled then button.LeftDisabled:Hide() end
    if button.MiddleDisabled then button.MiddleDisabled:Hide() end
    if button.RightDisabled then button.RightDisabled:Hide() end
    if button.SetNormalTexture then button:SetNormalTexture("") end
    if button.SetPushedTexture then button:SetPushedTexture("") end
    if button.SetDisabledTexture then button:SetDisabledTexture("") end

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.045, 0.045, 0.055, 0.94)

    local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    border:SetBackdropBorderColor(0, 0, 0, 1)

    button:HookScript("OnEnter", function()
        bg:SetColorTexture(0.10, 0.10, 0.13, 0.96)
    end)
    button:HookScript("OnLeave", function()
        bg:SetColorTexture(0.045, 0.045, 0.055, 0.94)
    end)
end

local function InjectReadyCheckControls()
    if uiInjected then return true end

    local mainFrame = _G.CCRaidToolsFrame
    if not mainFrame or not mainFrame.raidCheckChk then return false end

    uiInjected = true

    local testButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    testButton:SetSize(54, 22)
    -- Aligné verticalement sur la checkbox Ready Check et ancré à droite du panneau.
    testButton:SetPoint("RIGHT", mainFrame, "RIGHT", -16, 0)
    testButton:SetPoint("CENTER", mainFrame.raidCheckChk, "CENTER", 0, 0)
    testButton:SetText("Test")
    SkinButton(testButton)

    testButton:SetScript("OnClick", function()
        if IsInRaid() and SlashCmdList and SlashCmdList["CCRAIDTOOLS"] then
            SlashCmdList["CCRAIDTOOLS"]("raidcheck")
        else
            print("|cff33ff99[CC RaidTools]|r Le test du Ready Check nécessite d'être dans un raid.")
        end
    end)

    mainFrame.raidCheckTestButton = testButton
    return true
end

local function EnsureReadyCheckControls()
    if InjectReadyCheckControls() then
        if uiWatcher then
            uiWatcher:Cancel()
            uiWatcher = nil
        end
        return
    end

    if not uiWatcher then
        uiWatcher = C_Timer.NewTicker(0.25, function()
            if InjectReadyCheckControls() and uiWatcher then
                uiWatcher:Cancel()
                uiWatcher = nil
            end
        end, 240)
    end
end

C_Timer.After(0, EnsureReadyCheckControls)
