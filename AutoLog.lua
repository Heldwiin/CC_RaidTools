-- CC RaidTools - AutoLog
local C = CCRT
local startedByAddon = false
local lastStartAttempt = 0
local lastStopAttempt = 0
local ACTION_COOLDOWN = 5

local function IsLoggingActive()
    if C_ChatInfo and C_ChatInfo.IsLoggingCombat then
        return C_ChatInfo.IsLoggingCombat() and true or false
    end
    return false
end

local function StartLogging()
    local now = GetTime()
    -- Ownership is session-local. Never trust SavedVariables for current state.
    if startedByAddon then
        if IsLoggingActive() then
            return
        end
        -- The log was stopped externally; release stale ownership.
        startedByAddon = false
    end
    if (now - lastStartAttempt) < ACTION_COOLDOWN then return end
    lastStartAttempt = now
    if IsLoggingActive() then return end
    LoggingCombat(true)
    startedByAddon = true
    print(C.L.chatPrefix .. C.L.autoLogStarted)
end

local function StopLogging()
    local now = GetTime()
    if not startedByAddon then return end
    if (now - lastStopAttempt) < ACTION_COOLDOWN then return end
    lastStopAttempt = now
    LoggingCombat(false)
    startedByAddon = false
    print(C.L.chatPrefix .. C.L.autoLogStopped)
end

local function IsLoggingTarget()
    C.InitDB()
    local _, instanceType, difficultyID = GetInstanceInfo()
    local d = AutoPromoteDB.logging
    if instanceType == "raid" then
        return (difficultyID == 17 and d.lfr)
            or (difficultyID == 14 and d.normal)
            or (difficultyID == 15 and d.heroic)
            or (difficultyID == 16 and d.mythic)
    end
    if instanceType == "party" then
        return (difficultyID == 23 or difficultyID == 8) and d.dungeons
    end
    return false
end

local function StartChallengeLogging()
    C.InitDB()
    if not AutoPromoteDB.logging.dungeons or IsLoggingActive() then return end
    StartLogging()
end

local function CheckAutoLog()
    C.InitDB()
    if IsLoggingTarget() then StartLogging() else StopLogging() end
end
C.CheckAutoLog = CheckAutoLog

local checks = {}
local function BuildUI(f)
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -30)
    label:SetText(C.L.autoLogLabel)
    label:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
    local previous = label
    for _, info in ipairs({
        { C.L.autoLogLFR, "lfr" },
        { C.L.autoLogNormal, "normal" },
        { C.L.autoLogHeroic, "heroic" },
        { C.L.autoLogMythic, "mythic" },
        { C.L.autoLogDungeons, "dungeons" },
    }) do
        local chk = CreateFrame("CheckButton", nil, f, "BackdropTemplate")
        chk:SetSize(48, 24)
        C.SkinCheckBox(chk)
        chk:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -3)
        local text = chk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", chk, "RIGHT", 7, 0)
        text:SetText(info[1])
        chk:SetScript("OnClick", function(self)
            AutoPromoteDB.logging[info[2]] = self:GetChecked() and true or false
            if self._ccrtRefresh then self:_ccrtRefresh() end
            CheckAutoLog()
        end)
        checks[info[2]] = chk
        previous = chk
    end
end

local function MigrateDungeonSetting()
    C.InitDB()
    if AutoPromoteDB.logging.dungeons == nil then
        AutoPromoteDB.logging.dungeons = AutoPromoteDB.logging.dungeonMythic or AutoPromoteDB.logging.dungeonMythicPlus or false
    end
end

local function Refresh()
    C.InitDB()
    MigrateDungeonSetting()
    for k, chk in pairs(checks) do
        chk:SetChecked(AutoPromoteDB.logging[k] and true or false)
        if chk._ccrtRefresh then chk:_ccrtRefresh() end
    end
end
C.RegisterModule("AutoLog", BuildUI, Refresh)

local e = CreateFrame("Frame")
for _, ev in ipairs({
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "CHALLENGE_MODE_START",
    "PLAYER_DIFFICULTY_CHANGED",
    "UPDATE_INSTANCE_INFO",
}) do e:RegisterEvent(ev) end

e:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "CC_RaidTools" then
        C.InitDB()
        MigrateDungeonSetting()
        startedByAddon = false
        C_Timer.After(2, CheckAutoLog)
    elseif event == "CHALLENGE_MODE_START" then
        C_Timer.After(1, StartChallengeLogging)
    else
        C_Timer.After(2, CheckAutoLog)
    end
end)
