-- CC RaidTools - Module menu icons
-- Adds custom HD CC RaidTools icons to the module selector.
local ADDON_NAME = "CC_RaidTools"

local ICON_PATH = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\"

local MODULE_ICONS = {
    AutoPromote = ICON_PATH .. "AutoPromote.png",
    AutoLog     = ICON_PATH .. "AutoLog.png",
    ReadyCheck  = ICON_PATH .. "ReadyCheck.png",
    InviteTool  = ICON_PATH .. "InviteTool.png",
    Focus       = ICON_PATH .. "Focus.png",
    MarksBar    = ICON_PATH .. "MarksBar.png",
}

local function ApplyModuleIcons()
    if not CCRT or not CCRT.GetMainFrame then return end
    local frame = CCRT.GetMainFrame()
    if not frame or not frame.menuButtons then return end

    for moduleName, button in pairs(frame.menuButtons) do
        local texturePath = MODULE_ICONS[moduleName]
        if texturePath and not button._ccrtModuleIcon then
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetSize(20, 20)
            icon:SetPoint("LEFT", button, "LEFT", 5, 0)
            icon:SetTexture(texturePath)
            icon:SetTexCoord(0, 1, 0, 1)
            button._ccrtModuleIcon = icon

            if button.text then
                button.text:ClearAllPoints()
                button.text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
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
