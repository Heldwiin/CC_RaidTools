-- CC RaidTools - Guild Branding
-- Adds the Caelestis Concilium watermark to the configuration window.

local LOGO_TEXTURE = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\logo.png"

local function ApplyGuildBranding(frame)
    if not frame or frame._ccrtGuildBranding then
        return
    end

    frame._ccrtGuildBranding = true

    local watermark = frame:CreateTexture(nil, "ARTWORK")
    watermark:SetSize(160, 160)
    watermark:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 6)
    watermark:SetTexture(LOGO_TEXTURE)
    watermark:SetAlpha(1.0)

    frame._ccrtWatermark = watermark
end

local function RegisterHook()
    if CCRT and CCRT.RegisterUIHook then
        CCRT.RegisterUIHook(ApplyGuildBranding)
        return
    end

    -- Fallback kept for compatibility with older core revisions.
    if CCRT and CCRT.GetMainFrame then
        ApplyGuildBranding(CCRT.GetMainFrame())
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "CC_RaidTools" then
        RegisterHook()
    end
end)
