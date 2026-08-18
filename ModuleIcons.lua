-- CC RaidTools - Module menu icons
-- Custom high-resolution icons and visual treatment for the module selector.
local ADDON_NAME = "CC_RaidTools"

local MODULE_ICONS = {
    AutoPromote = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\AutoPromote.png",
    AutoLog     = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\AutoLog.png",
    ReadyCheck  = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\ReadyCheck.png",
    InviteTool  = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\InviteTool.png",
    Focus       = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\Focus.png",
    MarksBar    = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\MarksBar.png",
}

local function StyleModuleButton(button)
    if not button or button._ccrtModuleStyled then return end
    button._ccrtModuleStyled = true

    button:SetSize(120, 30)

    -- Slightly brighter dark panel behind each module, with a crisp border.
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.025, 0.025, 0.035, 0.94)
    button._ccrtModuleBg = bg

    local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(0.10, 0.10, 0.13, 0.95)
    button._ccrtModuleBorder = border

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(0.18, 0.18, 0.24, 0.22)
    button._ccrtModuleHover = hover

    button:HookScript("OnEnter", function(self)
        if self._ccrtModuleBg then
            self._ccrtModuleBg:SetColorTexture(0.08, 0.07, 0.11, 0.98)
        end
    end)
    button:HookScript("OnLeave", function(self)
        if self._ccrtModuleBg and not self.selected then
            self._ccrtModuleBg:SetColorTexture(0.025, 0.025, 0.035, 0.94)
        end
    end)
end

local function ApplyModuleIcons()
    if not CCRT or not CCRT.GetMainFrame then return end
    local frame = CCRT.GetMainFrame()
    if not frame or not frame.menuButtons then return end

    for moduleName, button in pairs(frame.menuButtons) do
        local texturePath = MODULE_ICONS[moduleName]
        if texturePath then
            StyleModuleButton(button)

            if not button._ccrtModuleIconBg then
                local iconBg = button:CreateTexture(nil, "ARTWORK")
                iconBg:SetSize(28, 28)
                iconBg:SetPoint("LEFT", button, "LEFT", 1, 0)
                iconBg:SetColorTexture(0.01, 0.01, 0.014, 0.72)
                button._ccrtModuleIconBg = iconBg
            end

            if not button._ccrtModuleIcon then
                local icon = button:CreateTexture(nil, "ARTWORK")
                icon:SetSize(24, 24)
                icon:SetPoint("CENTER", button._ccrtModuleIconBg, "CENTER")
                icon:SetTexture(texturePath)
                icon:SetTexCoord(0, 1, 0, 1)
                button._ccrtModuleIcon = icon
            else
                button._ccrtModuleIcon:SetTexture(texturePath)
            end

            if button.text then
                button.text:ClearAllPoints()
                button.text:SetPoint("LEFT", button._ccrtModuleIconBg, "RIGHT", 7, 0)
                button.text:SetTextColor(0.96, 0.96, 0.96)
                button.text:SetShadowOffset(1, -1)
                button.text:SetShadowColor(0, 0, 0, 1)
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
