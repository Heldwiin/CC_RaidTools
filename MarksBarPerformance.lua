-- CC RaidTools - Marks Bar performance helper
-- Apply the mouseover throttle as soon as the Marks Bar is created.
-- This must not depend on opening /ccrt: the bar is created independently
-- from the configuration window during ADDON_LOADED.
local elapsedSinceCheck = 0

local function ApplyMouseoverThrottle()
    local bar = _G.CCRaidToolsMarksBar
    if not bar or bar._ccrtMouseoverThrottle then
        return
    end

    bar._ccrtMouseoverThrottle = true
    bar:SetScript("OnUpdate", function(self, elapsed)
        if not AutoPromoteDB or not AutoPromoteDB.marksBar
            or not AutoPromoteDB.marksBar.enabled
            or not AutoPromoteDB.marksBar.mouseoverDisplay then
            return
        end

        elapsedSinceCheck = elapsedSinceCheck + elapsed
        if elapsedSinceCheck < 0.03 then
            return
        end
        elapsedSinceCheck = 0

        local db = AutoPromoteDB.marksBar
        local wanted = self:IsMouseOver() and (db.alpha or 1) or 0
        if self:GetAlpha() ~= wanted then
            self:SetAlpha(wanted)
        end
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "CC_RaidTools" then
        ApplyMouseoverThrottle()
    end
end)
