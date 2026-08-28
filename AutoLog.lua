-- CC RaidTools - AutoLog
-- Automatically starts/stops the combat log for configured raid and dungeon difficulties.

local C = CCRT

local startedByAddon = false
local recoveringOwnership = false
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

    -- Ownership is session-local. SavedVariables must never be used to decide
    -- whether this addon started the current combat log session.
    if startedByAddon then
        if IsLoggingActive() then
            return
        end

        -- The log was stopped externally, so release stale ownership.
        startedByAddon = false
    end

    if now - lastStartAttempt < ACTION_COOLDOWN then
        return
    end

    lastStartAttempt = now

    if IsLoggingActive() then
        return
    end

    LoggingCombat(true)
    startedByAddon = true
    print(C.L.chatPrefix .. C.L.autoLogStarted)
end

local function StopLogging()
    local now = GetTime()

    if not startedByAddon then
        return
    end

    if now - lastStopAttempt < ACTION_COOLDOWN then
        return
    end

    lastStopAttempt = now
    LoggingCombat(false)
    startedByAddon = false
    print(C.L.chatPrefix .. C.L.autoLogStopped)
end

local function IsLoggingTarget()
    C.InitDB()

    local _, instanceType, difficultyID = GetInstanceInfo()
    local db = AutoPromoteDB.logging

    if instanceType == "raid" then
        return (difficultyID == 17 and db.lfr)
            or (difficultyID == 14 and db.normal)
            or (difficultyID == 15 and db.heroic)
            or (difficultyID == 16 and db.mythic)
    end

    if instanceType == "party" then
        return (difficultyID == 23 or difficultyID == 8) and db.dungeons
    end

    return false
end

local function StartChallengeLogging()
    C.InitDB()

    if not AutoPromoteDB.logging.dungeons or IsLoggingActive() then
        return
    end

    StartLogging()
end

local function CheckAutoLog()
    C.InitDB()

    if IsLoggingTarget() then
        if recoveringOwnership and IsLoggingActive() and not startedByAddon then
            -- A reload resets this local flag while WoW can keep combat logging
            -- active. Reclaim ownership so AutoLog can stop it when we leave.
            startedByAddon = true
            recoveringOwnership = false
            return
        end

        recoveringOwnership = false
        StartLogging()
        return
    end

    recoveringOwnership = false
    StopLogging()
end

C.CheckAutoLog = CheckAutoLog

local checks = {}

local function BuildUI(frame)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    label:SetText(C.L.autoLogLabel)
    label:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    local previous = label
    local options = {
        { C.L.autoLogLFR, "lfr" },
        { C.L.autoLogNormal, "normal" },
        { C.L.autoLogHeroic, "heroic" },
        { C.L.autoLogMythic, "mythic" },
        { C.L.autoLogDungeons, "dungeons" },
    }

    for _, option in ipairs(options) do
        local check = CreateFrame("CheckButton", nil, frame, "BackdropTemplate")
        check:SetSize(48, 24)
        C.SkinCheckBox(check)
        check:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -3)

        local text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", check, "RIGHT", 7, 0)
        text:SetText(option[1])

        check:SetScript("OnClick", function(self)
            AutoPromoteDB.logging[option[2]] = self:GetChecked() and true or false

            if self._ccrtRefresh then
                self:_ccrtRefresh()
            end

            CheckAutoLog()
        end)

        checks[option[2]] = check
        previous = check
    end
end

local function MigrateDungeonSetting()
    C.InitDB()

    local logging = AutoPromoteDB.logging
    if logging.dungeons == nil then
        logging.dungeons = logging.dungeonMythic or logging.dungeonMythicPlus or false
    end
end

local function Refresh()
    C.InitDB()
    MigrateDungeonSetting()

    for key, check in pairs(checks) do
        check:SetChecked(AutoPromoteDB.logging[key] and true or false)
        if check._ccrtRefresh then
            check:_ccrtRefresh()
        end
    end
end

C.RegisterModule("AutoLog", BuildUI, Refresh)

local events = CreateFrame("Frame")
for _, eventName in ipairs({
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "CHALLENGE_MODE_START",
    "PLAYER_DIFFICULTY_CHANGED",
    "UPDATE_INSTANCE_INFO",
}) do
    events:RegisterEvent(eventName)
end

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "CC_RaidTools" then
        C.InitDB()
        MigrateDungeonSetting()
        startedByAddon = false
        recoveringOwnership = true
        C_Timer.After(2, CheckAutoLog)
        return
    end

    if event == "CHALLENGE_MODE_START" then
        C_Timer.After(1, StartChallengeLogging)
        return
    end

    C_Timer.After(2, CheckAutoLog)
end)
