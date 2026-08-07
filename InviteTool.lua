-- CC RaidTools - Invite Tool intégré à /ccrt
-- Invitation automatique par mot-clé reçu en message privé.

local BRAND_R, BRAND_G, BRAND_B = 0.451, 0.506, 1
local inviteEvent = CreateFrame("Frame")
local uiInjected = false

local function InitInviteDB()
    if not AutoPromoteDB then AutoPromoteDB = {} end
    AutoPromoteDB.inviteTool = AutoPromoteDB.inviteTool or {}
    if AutoPromoteDB.inviteTool.keyword == nil then AutoPromoteDB.inviteTool.keyword = "inv" end
    if AutoPromoteDB.inviteTool.enabled == nil then AutoPromoteDB.inviteTool.enabled = true end
end

local function SkinEditBox(box)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    box:SetBackdropColor(0.018, 0.018, 0.024, 0.90)
    box:SetBackdropBorderColor(0, 0, 0, 1)
    box:SetTextColor(1, 1, 1)
end

local function SkinCheckBox(box)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    box:SetBackdropColor(0.035, 0.035, 0.045, 1)
    box:SetBackdropBorderColor(0, 0, 0, 1)

    local x = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    x:SetPoint("CENTER", 0, 0)
    x:SetText("X")
    x:SetTextColor(1, 1, 1)
    box._ccrtX = x

    local function Refresh(self)
        x:SetShown(self:GetChecked() and true or false)
    end
    box._ccrtRefresh = Refresh
    box:HookScript("OnShow", Refresh)
    Refresh(box)
end

local function InjectInviteUI()
    InitInviteDB()
    local mainFrame = _G.CCRaidToolsFrame
    if not mainFrame or uiInjected then return end
    uiInjected = true

    -- On ajoute une petite zone Invite Tool au bas de la fenêtre /ccrt.
    -- La fenêtre est légèrement agrandie uniquement pour cette section.
    local oldWidth, oldHeight = mainFrame:GetSize()
    mainFrame:SetSize(oldWidth, math.max(oldHeight, 705))

    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -640)
    title:SetText("Invite Tool :")
    title:SetTextColor(BRAND_R, BRAND_G, BRAND_B)

    local enabled = CreateFrame("CheckButton", nil, mainFrame, "BackdropTemplate")
    enabled:SetSize(20, 20)
    enabled:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -660)
    SkinCheckBox(enabled)
    enabled:SetChecked(AutoPromoteDB.inviteTool.enabled and true or false)
    enabled:_ccrtRefresh()

    local enabledText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    enabledText:SetPoint("LEFT", enabled, "RIGHT", 4, 0)
    enabledText:SetText("Invitation par mot-clé")

    local keywordLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    keywordLabel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 165, -663)
    keywordLabel:SetText("Mot-clé :")

    local keyword = CreateFrame("EditBox", nil, mainFrame, "BackdropTemplate")
    keyword:SetSize(70, 20)
    keyword:SetPoint("LEFT", keywordLabel, "RIGHT", 5, 0)
    keyword:SetAutoFocus(false)
    keyword:SetMaxLetters(20)
    keyword:SetFontObject("ChatFontNormal")
    keyword:SetTextInsets(5, 5, 0, 0)
    keyword:SetText(AutoPromoteDB.inviteTool.keyword or "inv")
    SkinEditBox(keyword)

    enabled:SetScript("OnClick", function(self)
        AutoPromoteDB.inviteTool.enabled = self:GetChecked() and true or false
        self:_ccrtRefresh()
    end)

    local function SaveKeyword()
        local value = keyword:GetText() or ""
        value = value:gsub("^%s+", ""):gsub("%s+$", ""):lower()
        if value == "" then value = "inv" end
        AutoPromoteDB.inviteTool.keyword = value
        keyword:SetText(value)
        keyword:ClearFocus()
    end
    keyword:SetScript("OnEnterPressed", SaveKeyword)
    keyword:SetScript("OnEditFocusLost", SaveKeyword)

    mainFrame.inviteEnabled = enabled
    mainFrame.inviteKeyword = keyword

    mainFrame:HookScript("OnShow", function()
        InitInviteDB()
        enabled:SetChecked(AutoPromoteDB.inviteTool.enabled and true or false)
        enabled:_ccrtRefresh()
        keyword:SetText(AutoPromoteDB.inviteTool.keyword or "inv")
    end)
end

local function NormalizeMessage(msg)
    if not msg then return "" end
    return msg:gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

local function InviteByKeyword(message, sender)
    InitInviteDB()
    if not AutoPromoteDB.inviteTool.enabled then return end
    if not sender or sender == "" then return end

    local keyword = NormalizeMessage(AutoPromoteDB.inviteTool.keyword)
    if keyword == "" or NormalizeMessage(message) ~= keyword then return end

    if InCombatLockdown() then
        SendChatMessage("Invitation impossible pendant le combat.", "WHISPER", nil, sender)
        return
    end

    -- Si nous sommes déjà groupés, seul le chef/assistant doit tenter l'invitation.
    if IsInGroup() and not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then
        return
    end

    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(sender)
    elseif InviteUnit then
        InviteUnit(sender)
    end
end

inviteEvent:RegisterEvent("PLAYER_LOGIN")
inviteEvent:RegisterEvent("CHAT_MSG_WHISPER")
inviteEvent:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        InitInviteDB()
        C_Timer.After(1, InjectInviteUI)
    elseif event == "CHAT_MSG_WHISPER" then
        local message, sender = ...
        InviteByKeyword(message, sender)
    end
end)

-- /ccrt construit la fenêtre à la demande. On enveloppe sa commande existante
-- pour injecter la section Invite Tool dès la première ouverture.
local oldCCRTSlash = SlashCmdList and SlashCmdList["CCRAIDTOOLS"]
if oldCCRTSlash then
    SlashCmdList["CCRAIDTOOLS"] = function(msg)
        oldCCRTSlash(msg)
        C_Timer.After(0, InjectInviteUI)
    end
end
