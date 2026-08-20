-- CC RaidTools - Ready Check UI enhancements
-- Adds a visible post-ready-check countdown and resizes the window to fit the raid.
local C = CCRT
local DURATION = 30
local MIN_ROWS = 1
local MAX_ROWS = 40
local ROW_H = 20
local HEADER_H = 52
local TIMER_H = 18
local EXTRA_H = 16

local frame
local timerBar
local timerText
local finishAt
local lastCount

local function GetRaidCount()
    return math.max(0, math.min(GetNumGroupMembers() or 0, MAX_ROWS))
end

local function EnsureTimer()
    if timerBar or not frame then return end
    timerBar = CreateFrame("StatusBar", nil, frame)
    timerBar:SetHeight(TIMER_H)
    timerBar:SetMinMaxValues(0, DURATION)
    timerBar:SetValue(DURATION)
    timerBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
    timerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
    timerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    timerBar:SetStatusBarColor(C.BRAND_R, C.BRAND_G, C.BRAND_B, 0.85)
    timerBar.bg = timerBar:CreateTexture(nil, "BACKGROUND")
    timerBar.bg:SetAllPoints()
    timerBar.bg:SetColorTexture(0.08, 0.08, 0.10, 0.8)
    timerText = timerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerText:SetPoint("CENTER")
    timerText:SetText("Fermeture dans 30s")
end

local function ResizeFrame()
    if not frame or not frame:IsShown() then return end
    local count = GetRaidCount()
    if count == lastCount then return end
    lastCount = count

    local rowsHeight = math.max(ROW_H, count * ROW_H)
    local scrollHeight = rowsHeight
    local frameHeight = HEADER_H + scrollHeight + TIMER_H + EXTRA_H

    frame:SetHeight(frameHeight)
    if frame.scrollFrame then
        frame.scrollFrame:SetHeight(scrollHeight)
    end
    if frame.child then
        frame.child:SetHeight(scrollHeight)
    end
    if timerBar then
        timerBar:ClearAllPoints()
        timerBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
        timerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
    end
end

local function StartCountdown()
    if not frame then return end
    EnsureTimer()
    finishAt = GetTime() + DURATION
    timerBar:SetMinMaxValues(0, DURATION)
    timerBar:SetValue(DURATION)
    timerText:SetText("Fermeture dans 30s")
end

local function StopCountdown()
    finishAt = nil
    if timerBar then
        timerBar:SetValue(0)
        timerText:SetText("")
    end
end

local function FindFrame()
    frame = _G["CCRaidToolsRaidCheckFrame"]
    if not frame then return false end
    EnsureTimer()
    ResizeFrame()
    return true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("READY_CHECK_FINISHED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "READY_CHECK_FINISHED" then
        if FindFrame() then
            ResizeFrame()
            StartCountdown()
        end
    end
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
    if not frame then
        FindFrame()
        return
    end
    if not frame:IsShown() then
        StopCountdown()
        lastCount = nil
        return
    end

    ResizeFrame()

    if finishAt then
        local remaining = math.max(0, finishAt - GetTime())
        if timerBar then
            timerBar:SetValue(remaining)
            timerText:SetText(string.format("Fermeture dans %ds", math.ceil(remaining)))
        end
        if remaining <= 0 then
            StopCountdown()
        end
    end
end)

-- Re-apply sizing whenever the Ready Check is shown, including Test mode.
C_Timer.After(0, function()
    if FindFrame() then
        frame:HookScript("OnShow", function()
            lastCount = nil
            C_Timer.After(0, ResizeFrame)
        end)
        frame:HookScript("OnHide", StopCountdown)
    end
end)
