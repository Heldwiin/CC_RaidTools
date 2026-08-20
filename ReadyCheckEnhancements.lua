-- CC RaidTools - Ready Check UI enhancements
-- Adds a visible countdown from the start of the Ready Check and resizes the window to fit the raid.
local C = CCRT
local DURATION = 30
local MAX_ROWS = 40
local ROW_H = 20
local HEADER_H = 52
local TIMER_H = 18
local EXTRA_H = 16
local TIMER_TEXTURE = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\atrocity.tga"

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
    timerBar:SetStatusBarTexture(TIMER_TEXTURE)
    timerBar:SetStatusBarColor(1, 1, 1, 1)
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
    local frameHeight = HEADER_H + rowsHeight + TIMER_H + EXTRA_H

    frame:SetHeight(frameHeight)
    if frame.scrollFrame then
        frame.scrollFrame:SetHeight(rowsHeight)
    end
    if frame.child then
        frame.child:SetHeight(rowsHeight)
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
eventFrame:RegisterEvent("READY_CHECK")
eventFrame:SetScript("OnEvent", function()
    if FindFrame() then
        ResizeFrame()
        StartCountdown()
    end
end)

eventFrame:SetScript("OnUpdate", function()
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
            frame:Hide()
        end
    end
end)

C_Timer.After(0, function()
    if FindFrame() then
        frame:HookScript("OnShow", function()
            lastCount = nil
            C_Timer.After(0, ResizeFrame)
        end)
        frame:HookScript("OnHide", StopCountdown)
    end
end)
