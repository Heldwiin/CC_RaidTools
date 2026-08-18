-- CC RaidTools - Module menu icons
-- Custom high-resolution icons for the module selector.
local ADDON_NAME = "CC_RaidTools"

local MODULE_ICONS = {
    AutoPromote = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\AutoPromote.png",
    AutoLog     = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\AutoLog.png",
    ReadyCheck  = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\ReadyCheck.png",
    InviteTool  = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\InviteTool.png",
    Focus       = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\Focus.png",
    MarksBar    = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\MarksBar.png",
}

local function ApplyModuleIcons()
    if not CCRT or not CCRT.GetMainFrame then return end
    local frame = CCRT.GetMainFrame()
    if not frame or not frame.menuButtons then return end

    for moduleName, button in pairs(frame.menuButtons) do
        local texturePath = MODULE_ICONS[moduleName]
        if texturePath then
            if not button._ccrtModuleIcon then
                local icon = button:CreateTexture(nil, "ARTWORK")
                icon:SetSize(24, 24)
                icon:SetPoint("LEFT", button, "LEFT", 5, 0)
                icon:SetTexture(texturePath)
                icon:SetTexCoord(0, 1, 0, 1)
                button._ccrtModuleIcon = icon
            end

            if button.text then
                button.text:ClearAllPoints()
                button.text:SetPoint("LEFT", button._ccrtModuleIcon, "RIGHT", 7, 0)
            end
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, addonName)
    if addonName ~= ADDON_NAME then return end
    if CCRT and CCRT.ToggleUI then
        local originalToggle = CCRT.ToggleUI
        CCRT.ToggleUI = function(...)
            originalToggle(...)
            ApplyModuleIcons()
        end
    end
end)
