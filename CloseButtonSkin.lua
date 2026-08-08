-- CC RaidTools - Ready Check close button skin
-- Keep the Ready Check close button visually identical to the main /ccrt window.
local function SkinReadyCheckClose()
    local frame = _G["CCRaidToolsRaidCheckFrame"]
    if not frame then return end
    if frame._ccrtCloseSkin then return end
    frame._ccrtCloseSkin = true

    -- Hide the original Ready Check close button (the one displaying the old style cross).
    for _, child in ipairs({frame:GetChildren()}) do
        if child.IsObjectType and child:IsObjectType("Button") and child.GetText and child:GetText() == "×" then
            child:Hide()
        end
    end

    -- Same simple cross button used by the main CC RaidTools window.
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetText("×")
    close:SetNormalFontObject("GameFontNormalLarge")
    close:SetHighlightFontObject("GameFontHighlightLarge")
    close:SetScript("OnClick", function() frame:Hide() end)
    frame.CCRTSkinnedCloseButton = close
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    SkinReadyCheckClose()
end)

local function HookShow()
    local frame = _G["CCRaidToolsRaidCheckFrame"]
    if frame and not frame._ccrtCloseHooked then
        frame._ccrtCloseHooked = true
        frame:HookScript("OnShow", SkinReadyCheckClose)
        SkinReadyCheckClose()
    end
end

C_Timer.After(0, HookShow)
C_Timer.After(1, HookShow)
C_Timer.After(2, HookShow)
