-- CC RaidTools - Invite Tool
--
-- Handles the configurable whisper keyword used to request an invite.
-- For non-leaders, the invite request is routed through Blizzard's native
-- invite API so the normal "Suggest Invite" behavior is preserved.

local C = CCRT

local DEFAULT_KEYWORD = "+1, inv, 123"

local function InitDB()
    C.InitDB()

    AutoPromoteDB.inviteTool = AutoPromoteDB.inviteTool or {}
    local db = AutoPromoteDB.inviteTool

    if db.keyword == nil then
        db.keyword = DEFAULT_KEYWORD
    end

    if db.enabled == nil then
        db.enabled = true
    end
end

local function Normalize(message)
    if not message then
        return ""
    end

    return message:gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

local function IsInviteKeyword(message)
    local normalizedMessage = Normalize(message)
    if normalizedMessage == "" then
        return false
    end

    local configuredKeywords = AutoPromoteDB.inviteTool.keyword or DEFAULT_KEYWORD
    for keyword in configuredKeywords:gmatch("[^,;]+") do
        if Normalize(keyword) == normalizedMessage then
            return true
        end
    end

    return false
end

local layout

local function BuildUI(frame)
    InitDB()
    local UI = C.UI
    UI.Band(frame, "InviteTool", C.L.itIntro)

    layout = UI.NewLayout(frame)

    layout:Header(C.L.uiSectionOptions)
    layout:Toggle({
        label = C.L.itEnableLabel,
        desc = C.L.itEnableDesc,
        get = function() return AutoPromoteDB.inviteTool.enabled end,
        set = function(value) AutoPromoteDB.inviteTool.enabled = value end,
    })
    layout:Input({
        label = C.L.itKeywordsLabel,
        desc = C.L.itKeywordsDesc,
        width = 220,
        maxLetters = 60,
        get = function() return AutoPromoteDB.inviteTool.keyword or DEFAULT_KEYWORD end,
        commit = function(text)
            local value = Normalize(text)
            if value == "" then
                value = DEFAULT_KEYWORD
            end
            AutoPromoteDB.inviteTool.keyword = value
            return value
        end,
    })

    layout:Finish()
end

local function Refresh()
    InitDB()

    if layout then
        layout:Refresh()
    end
end

C.RegisterModule("InviteTool", BuildUI, Refresh)

local function InvitePlayer(message, sender)
    InitDB()

    local db = AutoPromoteDB.inviteTool
    if not db.enabled then
        return
    end

    -- Midnight can expose whisper data as secret values in restricted contexts.
    -- Do not attempt to compare or manipulate those values from addon code.
    if issecretvalue and (issecretvalue(message) or issecretvalue(sender)) then
        return
    end

    if not sender or sender == "" or not IsInviteKeyword(message) then
        return
    end

    -- C_PartyInfo.InviteUnit follows Blizzard's native invite path. In a group
    -- where we are not the leader, Blizzard handles the request as a suggestion
    -- to the leader, matching the native UnitPopup "Suggest Invite" action.
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(sender)
    elseif InviteUnit then
        InviteUnit(sender)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CHAT_MSG_WHISPER")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        InitDB()
        return
    end

    if event == "CHAT_MSG_WHISPER" then
        local message, sender = ...
        InvitePlayer(message, sender)
    end
end)
