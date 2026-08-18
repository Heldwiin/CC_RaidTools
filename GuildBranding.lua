-- CC RaidTools - Guild Logo
-- Adds a visible but unobtrusive guild watermark to the CC RaidTools configuration window.
local ADDON_NAME = "CC_RaidTools"
local LOGO = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\logo_ccraidtools.png"

local function ApplyGuildBranding()
    if not CCRT or not CCRT.GetMainFrame then return end
    local frame = CCRT.GetMainFrame()
    if not frame or frame._ccrtGuildBranding then return end
    frame._ccrtGuildBranding = true

    -- More visible guild watermark in the lower-right of the configuration window.
    local watermark = frame:CreateTexture(nil, "BACKGROUND")
    watermark:SetSize(145, 145)
    watermark:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 22)
    watermark:SetTexture(LOGO)
    watermark:SetAlpha(0.50)
    frame._ccrtWatermark = watermark
end

local events = CreateFrame("Frame")
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
