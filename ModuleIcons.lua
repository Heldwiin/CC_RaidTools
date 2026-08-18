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

    button:SetSize(128, 34)

    -- Clean, compact card inspired by the reference UI.
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.018, 0.018, 0.024, 0.96)
    button._ccrtModuleBg = bg

    local topLine = button:CreateTexture(nil, "BORDER")
    topLine:SetPoint("TOPLEFT", 1, -1)
    topLine:SetPoint("TOPRIGHT", -1, -1)
    topLine:SetHeight(1)
    topLine:SetColorTexture(0.16, 0.16, 0.20, 0.9)
    button._ccrtModuleTopLine = topLine

    local bottomLine = button:CreateTexture(nil, "BORDER")
    bottomLine:SetPoint("BOTTOMLEFT", 1, 1)
    bottomLine:SetPoint("BOTTOMRIGHT", -1, 1)
    bottomLine:SetHeight(1)
    bottomLine:SetColorTexture(0.005, 0.005, 0.008, 0.95)
    button._ccrtModuleBottomLine = bottomLine

    local leftAccent = button:CreateTexture(nil, "BORDER")
    leftAccent:SetPoint("TOPLEFT", 0, -1)
    leftAccent:SetPoint("BOTTOMLEFT", 0, 1)
    leftAccent:SetWidth(2)
    leftAccent:SetColorTexture(0.451, 0.506, 1, 0.0)
    button._ccrtModuleAccent = leftAccent

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(0.16, 0.13, 0.22, 0.30)
    button._ccrtModuleHover = hover

    button:HookScript("OnEnter", function(self)
        if self._ccrtModuleBg then
            self._ccrtModuleBg:SetColorTexture(0.075, 0.065, 0.10, 0.98)
        end
        if self._ccrtModuleAccent then
            self._ccrtModuleAccent:SetColorTexture(0.451, 0.506, 1, 1)
        end
    end)
    button:HookScript("OnLeave", function(self)
        if self._ccrtModuleBg and not self.selected then
            self._ccrtModuleBg:SetColorTexture(0.018, 0.018, 0.024, 0.96)
        end
        if self._ccrtModuleAccent and not self.selected then
            self._ccrtModuleAccent:SetColorTexture(0.451, 0.506, 1, 0)
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
                iconBg:SetSize(31, 31)
                iconBg:SetPoint("LEFT", button, "LEFT", 1, 0)
                iconBg:SetColorTexture(0.008, 0.008, 0.012, 0.90)
                button._ccrtModuleIconBg = iconBg
            end

            if not button._ccrtModuleIcon then
                local icon = button:CreateTexture(nil, "OVERLAY")
                icon:SetSize(30, 30)
                icon:SetPoint("CENTER", button._ccrtModuleIconBg, "CENTER")
                icon:SetTexture(texturePath)
                icon:SetTexCoord(0, 1, 0, 1)
                button._ccrtModuleIcon = icon
            else
                button._ccrtModuleIcon:SetTexture(texturePath)
                button._ccrtModuleIcon:SetSize(30, 30)
            end

            if button.text then
                button.text:ClearAllPoints()
                button.text:SetPoint("LEFT", button._ccrtModuleIconBg, "RIGHT", 8, 0)
                button.text:SetTextColor(0.96, 0.96, 0.96)
                button.text:SetShadowOffset(1, -1)
                button.text:SetShadowColor(0, 0, 0, 1)
                local font, _, flags = button.text:GetFont()
                if font then
                    button.text:SetFont(font, 12, flags or "OUTLINE")
                end
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
