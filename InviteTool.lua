-- CC RaidTools - Invite Tool
--
-- Handles the configurable whisper keyword used to request an invite.
-- For non-leaders, the invite request is routed through Blizzard's native
-- invite API so the normal "Suggest Invite" behavior is preserved.

local C = CCRT

local enabledCheck
local keywordEdit

local DEFAULT_KEYWORD = "inv"

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

local function SkinEditBox(editBox)
    editBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    editBox:SetBackdropColor(0.018, 0.018, 0.024, 0.90)
    editBox:SetBackdropBorderColor(0, 0, 0, 1)
    editBox:SetTextColor(1, 1, 1)
end

local function SaveKeyword()
    local value = Normalize(keywordEdit:GetText())
    if value == "" then
        value = DEFAULT_KEYWORD
    end

    AutoPromoteDB.inviteTool.keyword = value
    keywordEdit:SetText(value)
    keywordEdit:ClearFocus()
end

local function BuildUI(frame)
    InitDB()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
    title:SetText(C.L.itLabel)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    enabledCheck = CreateFrame("CheckButton", nil, frame, "BackdropTemplate")
    enabledCheck:SetSize(48, 24)
    enabledCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -50)
    C.SkinCheckBox(enabledCheck)

    local keywordLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    keywordLabel:SetPoint("LEFT", enabledCheck, "RIGHT", 2, 0)
    keywordLabel:SetText(C.L.itKeywordsLabel)

    keywordEdit = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    keywordEdit:SetSize(145, 22)
    keywordEdit:SetPoint("LEFT", keywordLabel, "RIGHT", 6, 0)
    keywordEdit:SetAutoFocus(false)
    keywordEdit:SetMaxLetters(60)
    keywordEdit:SetFontObject("ChatFontNormal")
    keywordEdit:SetTextInsets(5, 5, 0, 0)
    SkinEditBox(keywordEdit)

    enabledCheck:SetScript("OnClick", function(self)
        AutoPromoteDB.inviteTool.enabled = self:GetChecked() and true or false

        if self._ccrtRefresh then
            self:_ccrtRefresh()
        end
    end)

    keywordEdit:SetScript("OnEnterPressed", SaveKeyword)
    keywordEdit:SetScript("OnEditFocusLost", SaveKeyword)
    keywordEdit:SetScript("OnEscapePressed", function(self)
        self:SetText(AutoPromoteDB.inviteTool.keyword or DEFAULT_KEYWORD)
        self:ClearFocus()
    end)
end

local function Refresh()
    InitDB()

    if enabledCheck then
        enabledCheck:SetChecked(AutoPromoteDB.inviteTool.enabled and true or false)
        if enabledCheck._ccrtRefresh then
            enabledCheck:_ccrtRefresh()
        end
    end

    if keywordEdit then
        keywordEdit:SetText(AutoPromoteDB.inviteTool.keyword or DEFAULT_KEYWORD)
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
