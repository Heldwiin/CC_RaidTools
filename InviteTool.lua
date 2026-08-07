-- CC RaidTools - Invite Tool intégré à /ccrt
-- Invitation automatique par mot-clé reçu en message privé.

local BRAND_R, BRAND_G, BRAND_B = 0.451, 0.506, 1
local inviteEvent = CreateFrame("Frame")
local uiInjected = false
local uiWatcher

local function InitInviteDB()
    if not AutoPromoteDB then AutoPromoteDB = {} end
    AutoPromoteDB.inviteTool = AutoPromoteDB.inviteTool or {}
    if AutoPromoteDB.inviteTool.keyword == nil then AutoPromoteDB.inviteTool.keyword = "inv" end
    if AutoPromoteDB.inviteTool.enabled == nil then AutoPromoteDB.inviteTool.enabled = true end
end

local function SkinEditBox(box)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    box:SetBackdropColor(0.018, 0.018, 0.024, 0.90)
    box:SetBackdropBorderColor(0, 0, 0, 1)
    box:SetTextColor(1, 1, 1)
end

local function SkinCheckBox(box)
    if not box or box._ccrtSkin then return end
    box._ccrtSkin = true
    box:EnableMouse(true)
    box:RegisterForClicks("LeftButtonUp")
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    box:SetBackdropColor(0.035, 0.035, 0.045, 1)
    box:SetBackdropBorderColor(0, 0, 0, 1)

    local checkedBg = box:CreateTexture(nil, "ARTWORK")
    checkedBg:SetPoint("TOPLEFT", 3, -3)
    checkedBg:SetPoint("BOTTOMRIGHT", -3, 3)
    checkedBg:SetColorTexture(BRAND_R * 0.62, BRAND_G * 0.62, BRAND_B * 0.72, 1)
    checkedBg:Hide()

    local tick = CreateFrame("Frame", nil, box)
    tick:SetAllPoints(box)
    tick:EnableMouse(false)
    local x1 = tick:CreateTexture(nil, "OVERLAY")
    x1:SetColorTexture(1, 1, 1, 1); x1:SetSize(2, 13); x1:SetPoint("CENTER"); x1:SetRotation(math.rad(45))
    local x2 = tick:CreateTexture(nil, "OVERLAY")
    x2:SetColorTexture(1, 1, 1, 1); x2:SetSize(2, 13); x2:SetPoint("CENTER"); x2:SetRotation(math.rad(-45))
    tick:Hide()

    local hover = box:CreateTexture(nil, "HIGHLIGHT")
    hover:SetPoint("TOPLEFT", 2, -2); hover:SetPoint("BOTTOMRIGHT", -2, 2)
    hover:SetColorTexture(BRAND_R, BRAND_G, BRAND_B, 0.15)

    local function Refresh(self)
        checkedBg:SetShown(self:GetChecked() and true or false)
        tick:SetShown(self:GetChecked() and true or false)
    end
    box._ccrtRefresh = Refresh
    box:HookScript("OnShow", Refresh)
    Refresh(box)
end

local function NormalizeMessage(msg)
    if not msg then return "" end
    return msg:gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

local function InjectInviteUI()
    InitInviteDB()
    local mainFrame = _G.CCRaidToolsFrame
    if not mainFrame or uiInjected then return false end
    uiInjected = true

    local oldWidth, oldHeight = mainFrame:GetSize()
    mainFrame:SetSize(oldWidth, math.max(oldHeight, 705))

    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -640)
    title:SetText("Invite Tool :")
    title:SetTextColor(BRAND_R, BRAND_G, BRAND_B)

    local enabled = CreateFrame("CheckButton", nil, mainFrame, "BackdropTemplate")
    enabled:SetSize(24, 24)
    enabled:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -660)
    SkinCheckBox(enabled)

    local keywordLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    keywordLabel:SetPoint("LEFT", enabled, "RIGHT", 2, 0)
    keywordLabel:SetText("Mot-clé :")

    local keyword = CreateFrame("EditBox", nil, mainFrame, "BackdropTemplate")
    keyword:SetSize(90, 22)
    keyword:SetPoint("LEFT", keywordLabel, "RIGHT", 6, 0)
    keyword:SetAutoFocus(false); keyword:SetMaxLetters(20); keyword:SetFontObject("ChatFontNormal"); keyword:SetTextInsets(5,5,0,0)
    SkinEditBox(keyword)

    local function RefreshInviteSettings()
        InitInviteDB()
        enabled:SetChecked(AutoPromoteDB.inviteTool.enabled and true or false)
        if enabled._ccrtRefresh then enabled:_ccrtRefresh() end
        keyword:SetText(AutoPromoteDB.inviteTool.keyword or "inv")
    end

    enabled:SetScript("OnClick", function(self)
        AutoPromoteDB.inviteTool.enabled = self:GetChecked() and true or false
        if self._ccrtRefresh then self:_ccrtRefresh() end
    end)

    local function SaveKeyword()
        local value = NormalizeMessage(keyword:GetText())
        if value == "" then value = "inv" end
        AutoPromoteDB.inviteTool.keyword = value
        keyword:SetText(value); keyword:ClearFocus()
    end
    keyword:SetScript("OnEnterPressed", SaveKeyword)
    keyword:SetScript("OnEscapePressed", function(self) self:SetText(AutoPromoteDB.inviteTool.keyword or "inv"); self:ClearFocus() end)
    keyword:SetScript("OnEditFocusLost", SaveKeyword)

    mainFrame.inviteEnabled = enabled; mainFrame.inviteKeyword = keyword
    mainFrame:HookScript("OnShow", RefreshInviteSettings)
    RefreshInviteSettings()
    return true
end

local function EnsureInviteUI()
    if uiInjected then return end
    if InjectInviteUI() then if uiWatcher then uiWatcher:Cancel(); uiWatcher=nil end return end
    if not uiWatcher then
        uiWatcher = C_Timer.NewTicker(0.25, function()
            if InjectInviteUI() and uiWatcher then uiWatcher:Cancel(); uiWatcher=nil end
        end, 240)
    end
end

local function InviteByKeyword(message, sender)
    InitInviteDB()
    if not AutoPromoteDB.inviteTool.enabled or not sender or sender == "" then return end
    local keyword = NormalizeMessage(AutoPromoteDB.inviteTool.keyword)
    if keyword == "" or NormalizeMessage(message) ~= keyword then return end
    if InCombatLockdown() then SendChatMessage("Invitation impossible pendant le combat.", "WHISPER", nil, sender); return end
    if IsInGroup() and not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then return end
    if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(sender) elseif InviteUnit then InviteUnit(sender) end
end

inviteEvent:RegisterEvent("PLAYER_LOGIN")
inviteEvent:RegisterEvent("CHAT_MSG_WHISPER")
inviteEvent:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then InitInviteDB(); EnsureInviteUI()
    elseif event == "CHAT_MSG_WHISPER" then local message, sender = ...; InviteByKeyword(message, sender) end
end)

C_Timer.After(0, EnsureInviteUI)
