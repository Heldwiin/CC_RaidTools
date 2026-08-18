-- CC RaidTools - Guild Logo
-- Adds a visible guild watermark to the CC RaidTools configuration window.
local ADDON_NAME = "CC_RaidTools"
local LOGO = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\logo.png"

local function ApplyGuildBranding()
    if not CCRT or not CCRT.GetMainFrame then return end
    local frame = CCRT.GetMainFrame()
    if not frame or frame._ccrtGuildBranding then return end
    frame._ccrtGuildBranding = true

    local watermark = frame:CreateTexture(nil, "ARTWORK")
    -- Keep the guild watermark clearly separated from the module header icon.
    watermark:SetSize(160, 160)
    watermark:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 6)
    watermark:SetTexture(LOGO)
    watermark:SetAlpha(1.0)
    frame._ccrtWatermark = watermark
end

events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, addonName)
    if addonName ~= ADDON_NAME then return end
    if CCRT and CCRT.ToggleUI then
        local originalToggle = CCRT.ToggleUI
        CCRT.ToggleUI = function(...)
            originalToggle(...)
            ApplyGuildBranding()
        end
    end
end)
