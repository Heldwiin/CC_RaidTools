-- CC RaidTools - Module menu icons
-- Adds small native WoW icons to the module selector.
local ADDON_NAME = "CC_RaidTools"

local MODULE_ICONS = {
    -- Group leader crown
    AutoPromote = "Interface\\GroupFrame\\UI-Group-LeaderIcon",
    -- White parchment / note
    AutoLog     = "Interface\\Icons\\INV_Misc_Note_01",
    -- Native green Ready Check tick
    ReadyCheck  = "Interface\\RaidFrame\\ReadyCheck-Ready",
    -- Target icon
    InviteTool  = "Interface\\Icons\\INV_Misc_GroupLooking",
    Focus       = "Interface\\Icons\\Ability_Hunter_FocusedAim",
    -- Raid marker icon (star)
    MarksBar    = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1",
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
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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
