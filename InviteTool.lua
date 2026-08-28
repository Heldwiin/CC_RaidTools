-- CC RaidTools - Invite Tool
local C = CCRT
local enabled, keyword

local ADDON_PREFIX = "CCRTINV"
local INVITE_REQUEST = "REQUEST"
local pendingRequests = {}
local popupActive = false

local function InitDB()
    C.InitDB()
    AutoPromoteDB.inviteTool = AutoPromoteDB.inviteTool or {}
    if AutoPromoteDB.inviteTool.keyword == nil then
        AutoPromoteDB.inviteTool.keyword = "inv"
    end
    if AutoPromoteDB.inviteTool.enabled == nil then
        AutoPromoteDB.inviteTool.enabled = true
    end

    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
    end
end

local function Normalize(msg)
    if not msg then
        return ""
    end
    return msg:gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

local function IsInviteKeyword(message)
    local msg = Normalize(message)
    if msg == "" then
        return false
    end
    local configured = AutoPromoteDB.inviteTool.keyword or "inv"
    for word in configured:gmatch("[^,;]+") do
        if Normalize(word) == msg then
            return true
        end
    end
    return false
end

local function SkinEdit(box)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    box:SetBackdropColor(0.018, 0.018, 0.024, 0.90)
    box:SetBackdropBorderColor(0, 0, 0, 1)
    box:SetTextColor(1, 1, 1)
end

local function GetGroupLeaderName()
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() or 0 do
            local unit = "raid" .. i
            if UnitExists(unit) and UnitIsGroupLeader(unit) then
                local name, realm = UnitName(unit)
                if name and name ~= "" then
                    if realm and realm ~= "" then
                        return name .. "-" .. realm
                    end
                    return name
                end
            end
        end
    elseif IsInGroup() then
        if UnitIsGroupLeader("player") then
            local name, realm = UnitName("player")
            if name and name ~= "" then
                if realm and realm ~= "" then
                    return name .. "-" .. realm
                end
                return name
            end
        end
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitIsGroupLeader(unit) then
                local name, realm = UnitName(unit)
                if name and name ~= "" then
                    if realm and realm ~= "" then
                        return name .. "-" .. realm
                    end
                    return name
                end
            end
        end
    end
    return nil
end

local function WhisperLeader(leaderName, requester)
    if not leaderName or leaderName == "" or not requester or requester == "" then
        return
    end
    local text = C.L.itLeaderWhisper:format(requester)
    if SendChatMessage then
        SendChatMessage(text, "WHISPER", nil, leaderName)
    end
end

local function ShowNextRequest()
    if popupActive then
        return
    end

    local requester = table.remove(pendingRequests, 1)
    if not requester then
        return
    end

    popupActive = true
    StaticPopup_Show("CCRT_INVITE_REQUEST", requester, nil, requester)
end

local function QueueLeaderSuggestion(requester)
    if not requester or requester == "" then
        return
    end
    if not UnitIsGroupLeader("player") then
        return
    end

    pendingRequests[#pendingRequests + 1] = requester
    ShowNextRequest()
end

local function BuildUI(f)
    InitDB()
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
    title:SetText(C.L.itLabel)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
    enabled = CreateFrame("CheckButton", nil, f, "BackdropTemplate")
    enabled:SetSize(48, 24)
    enabled:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -50)
    C.SkinCheckBox(enabled)
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", enabled, "RIGHT", 2, 0)
    label:SetText(C.L.itKeywordsLabel)
    keyword = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    keyword:SetSize(145, 22)
    keyword:SetPoint("LEFT", label, "RIGHT", 6, 0)
    keyword:SetAutoFocus(false)
    keyword:SetMaxLetters(60)
    keyword:SetFontObject("ChatFontNormal")
    keyword:SetTextInsets(5, 5, 0, 0)
    SkinEdit(keyword)
    enabled:SetScript("OnClick", function(self)
        AutoPromoteDB.inviteTool.enabled = self:GetChecked() and true or false
        if enabled._ccrtRefresh then
            enabled:_ccrtRefresh()
        end
    end)
    local function Save()
        local v = Normalize(keyword:GetText())
        if v == "" then
            v = "inv"
        end
        AutoPromoteDB.inviteTool.keyword = v
        keyword:SetText(v)
        keyword:ClearFocus()
    end
    keyword:SetScript("OnEnterPressed", Save)
    keyword:SetScript("OnEditFocusLost", Save)
    keyword:SetScript("OnEscapePressed", function(self)
        self:SetText(AutoPromoteDB.inviteTool.keyword or "inv")
        self:ClearFocus()
    end)
end

local function Refresh()
    InitDB()
    if enabled then
        enabled:SetChecked(AutoPromoteDB.inviteTool.enabled and true or false)
        if enabled._ccrtRefresh then
            enabled:_ccrtRefresh()
        end
    end
    if keyword then
        keyword:SetText(AutoPromoteDB.inviteTool.keyword or "inv")
    end
end
C.RegisterModule("InviteTool", BuildUI, Refresh)

local function Invite(message, sender)
    InitDB()
    if not AutoPromoteDB.inviteTool.enabled then
        return
    end

    -- Midnight 12.0+ can expose whisper message/sender as secret strings in restricted
    -- contexts. Tainted addon code cannot compare or manipulate those values.
    if issecretvalue and (issecretvalue(message) or issecretvalue(sender)) then
        return
    end

    if not sender or sender == "" then
        return
    end
    if not IsInviteKeyword(message) then
        return
    end

    if IsInGroup() and not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then
        local leaderName = GetGroupLeaderName()
        if leaderName then
            -- Route the request through the group/raid addon channel. The previous
            -- implementation used a WHISPER addon message, but the leader's
            -- CHAT_MSG_ADDON handler cannot reliably receive that path in all
            -- Midnight contexts. The regular whisper remains a fallback when the
            -- addon message is unavailable (for example, the leader has no addon).
            local sent = false
            if C_ChatInfo and C_ChatInfo.SendAddonMessage then
                local channel = IsInRaid() and "RAID" or "PARTY"
                local result = C_ChatInfo.SendAddonMessage(ADDON_PREFIX, INVITE_REQUEST, channel)
                sent = (result == nil or result == 0)
            end
            if not sent then
                WhisperLeader(leaderName, sender)
            end
        end
        return
    end

    if not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then
        return
    end

    -- Match Method Raid Tools: do not add our own combat-delay queue or whisper.
    -- Call the Blizzard invite API immediately and let WoW handle the protected call.
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(sender)
    elseif InviteUnit then
        InviteUnit(sender)
    end
end

StaticPopupDialogs["CCRT_INVITE_REQUEST"] = {
    text = C.L.itInviteRequest,
    button1 = C.L.itInviteButton,
    button2 = C.L.itInviteIgnore,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function(self, data)
        local requester = data
        if requester and requester ~= "" then
            if C_PartyInfo and C_PartyInfo.InviteUnit then
                C_PartyInfo.InviteUnit(requester)
            elseif InviteUnit then
                InviteUnit(requester)
            end
        end
    end,
    OnCancel = function()
        popupActive = false
        C_Timer.After(0, ShowNextRequest)
    end,
    OnHide = function()
        popupActive = false
        C_Timer.After(0, ShowNextRequest)
    end,
}

local e = CreateFrame("Frame")
e:RegisterEvent("PLAYER_LOGIN")
e:RegisterEvent("CHAT_MSG_WHISPER")
e:RegisterEvent("CHAT_MSG_ADDON")
e:SetScript("OnEvent", function(_, ev, ...)
    if ev == "PLAYER_LOGIN" then
        InitDB()
    elseif ev == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        Invite(msg, sender)
    elseif ev == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix ~= ADDON_PREFIX or (channel ~= "PARTY" and channel ~= "RAID") then
            return
        end
        if issecretvalue and (issecretvalue(message) or issecretvalue(sender)) then
            return
        end
        if not UnitIsGroupLeader("player") then
            return
        end
        if message == INVITE_REQUEST then
            QueueLeaderSuggestion(sender)
        end
    end
end)
