-- CC RaidTools - MarksBar performance helper
-- Keep the mouseover check lightweight without running it every rendered frame.
local C = CCRT

C.RegisterUIHook(function()
    local bar = _G.CCRaidToolsMarksBar
    if not bar or bar._ccrtMouseoverThrottle then
        return
    end

    bar._ccrtMouseoverThrottle = true
    local elapsedSinceCheck = 0

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
end)
