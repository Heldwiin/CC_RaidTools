-- CC RaidTools - Invite Tool
-- Invitation des membres de guilde par rang, sans dépendance à MRT.

local BRAND_R, BRAND_G, BRAND_B = 0.451, 0.506, 1
local inviteFrame
local rankChecks = {}
local discoveredInviteRanks = {}

local function InitInviteDB()
    if not AutoPromoteDB then AutoPromoteDB = {} end
    AutoPromoteDB.inviteTool = AutoPromoteDB.inviteTool or {}
    AutoPromoteDB.inviteTool.ranks = AutoPromoteDB.inviteTool.ranks or {}
    if AutoPromoteDB.inviteTool.onlineOnly == nil then AutoPromoteDB.inviteTool.onlineOnly = true end
    if AutoPromoteDB.inviteTool.autoRaid == nil then AutoPromoteDB.inviteTool.autoRaid = true end
end

local function SkinPanel(f)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.025, 0.025, 0.035, 0.92)
    f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropBorderColor(0, 0, 0, 1)
end

local function SkinButton(b)
    if b.Left then b.Left:Hide() end
    if b.Middle then b.Middle:Hide() end
    if b.Right then b.Right:Hide() end
    if b.SetNormalTexture then b:SetNormalTexture("") end
    if b.SetPushedTexture then b:SetPushedTexture("") end
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.045, 0.045, 0.055, 0.96)
    local border = CreateFrame("Frame", nil, b, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    border:SetBackdropBorderColor(0, 0, 0, 1)
    b:HookScript("OnEnter", function() bg:SetColorTexture(0.10, 0.10, 0.13, 0.98) end)
    b:HookScript("OnLeave", function() bg:SetColorTexture(0.045, 0.045, 0.055, 0.96) end)
end

local function CreateCheck(parent, label, x, y)
    local b = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    b:SetSize(18, 18)
    b:SetPoint("TOPLEFT", x, y)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    b:SetBackdropColor(0.035, 0.035, 0.045, 1)
    b:SetBackdropBorderColor(0, 0, 0, 1)

    local mark = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mark:SetPoint("CENTER", 0, 0)
    mark:SetText("X")
    mark:SetTextColor(1, 1, 1)
    mark:Hide()

    local function Refresh(self)
        if self:GetChecked() then mark:Show() else mark:Hide() end
    end
    b._ccrtRefresh = Refresh
    b:HookScript("OnClick", Refresh)
    b:HookScript("OnShow", Refresh)

    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", b, "RIGHT", 7, 0)
    text:SetText(label)
    text:SetTextColor(0.9, 0.9, 0.92)
    return b, text
end

local function RefreshRanks()
    wipe(discoveredInviteRanks)
    if not IsInGuild() then return end
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
    local n = GetNumGuildMembers and GetNumGuildMembers() or 0
    for i = 1, n do
        local _, rankName, rankIndex = GetGuildRosterInfo(i)
        if rankName and rankIndex ~= nil then
            discoveredInviteRanks[rankIndex] = rankName
        end
    end
end

local function IsAlreadyGrouped(name)
    local short = name and name:match("^([^%-]+)")
    if not short then return false end
    if UnitName("player") == short then return true end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if UnitName("raid" .. i) == short then return true end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            if UnitName("party" .. i) == short then return true end
        end
    end
    return false
end

local function InviteSelectedRanks()
    InitInviteDB()
    RefreshRanks()
    if not IsInGuild() then
        print("|cff33ff99[CC RaidTools]|r Vous n'êtes pas dans une guilde.")
        return
    end
    if InCombatLockdown() then
        print("|cff33ff99[CC RaidTools]|r Impossible d'inviter pendant le combat.")
        return
    end

    local invited = 0
    local n = GetNumGuildMembers and GetNumGuildMembers() or 0
    for i = 1, n do
        local name, _, rankIndex, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name and AutoPromoteDB.inviteTool.ranks[rankIndex] and (online or not AutoPromoteDB.inviteTool.onlineOnly) then
            if not IsAlreadyGrouped(name) then
                if C_PartyInfo and C_PartyInfo.InviteUnit then
                    C_PartyInfo.InviteUnit(name)
                elseif InviteUnit then
                    InviteUnit(name)
                end
                invited = invited + 1
            end
        end
    end

    if AutoPromoteDB.inviteTool.autoRaid and not IsInRaid() then
        C_Timer.After(2, function()
            if IsInGroup() and not IsInRaid() and UnitIsGroupLeader("player") and ConvertToRaid then
                ConvertToRaid()
            end
        end)
    end
    print("|cff33ff99[CC RaidTools]|r " .. invited .. " invitation(s) envoyée(s).")
end

local function BuildInviteFrame()
    if inviteFrame then return inviteFrame end
    InitInviteDB()

    inviteFrame = CreateFrame("Frame", "CCRTInviteToolFrame", UIParent, "BackdropTemplate")
    inviteFrame:SetSize(390, 470)
    inviteFrame:SetPoint("CENTER")
    inviteFrame:SetFrameStrata("DIALOG")
    inviteFrame:SetMovable(true)
    inviteFrame:EnableMouse(true)
    inviteFrame:RegisterForDrag("LeftButton")
    inviteFrame:SetScript("OnDragStart", inviteFrame.StartMoving)
    inviteFrame:SetScript("OnDragStop", inviteFrame.StopMovingOrSizing)
    inviteFrame:SetClampedToScreen(true)
    SkinPanel(inviteFrame)

    local title = inviteFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("CC RaidTools  •  Invite Tool")
    title:SetTextColor(BRAND_R, BRAND_G, BRAND_B)

    local close = CreateFrame("Button", nil, inviteFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local info = inviteFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 18, -48)
    info:SetText("Sélectionne les rangs de guilde à inviter :")

    local scroll = CreateFrame("ScrollFrame", nil, inviteFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -72)
    scroll:SetPoint("BOTTOMRIGHT", -38, 105)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(320, 320)
    scroll:SetScrollChild(child)
    inviteFrame.rankChild = child

    local online = CreateCheck(inviteFrame, "Uniquement les joueurs en ligne", 18, -380)
    online:SetChecked(AutoPromoteDB.inviteTool.onlineOnly)
    if online._ccrtRefresh then online:_ccrtRefresh() end
    online:SetScript("OnClick", function(self)
        AutoPromoteDB.inviteTool.onlineOnly = self:GetChecked() and true or false
        if self._ccrtRefresh then self:_ccrtRefresh() end
    end)

    local raid = CreateCheck(inviteFrame, "Convertir automatiquement en raid", 18, -407)
    raid:SetChecked(AutoPromoteDB.inviteTool.autoRaid)
    if raid._ccrtRefresh then raid:_ccrtRefresh() end
    raid:SetScript("OnClick", function(self)
        AutoPromoteDB.inviteTool.autoRaid = self:GetChecked() and true or false
        if self._ccrtRefresh then self:_ccrtRefresh() end
    end)

    local invite = CreateFrame("Button", nil, inviteFrame, "UIPanelButtonTemplate")
    invite:SetSize(160, 28)
    invite:SetPoint("BOTTOM", 0, 16)
    invite:SetText("Inviter")
    SkinButton(invite)
    invite:SetScript("OnClick", InviteSelectedRanks)

    inviteFrame:Hide()
    return inviteFrame
end

local function PopulateRanks()
    local f = BuildInviteFrame()
    RefreshRanks()

    for _, row in ipairs(rankChecks) do
        row.box:Hide()
        row.text:Hide()
    end
    wipe(rankChecks)

    local indexes = {}
    for idx in pairs(discoveredInviteRanks) do indexes[#indexes + 1] = idx end
    table.sort(indexes)

    local y = -4
    for _, idx in ipairs(indexes) do
        local rankName = discoveredInviteRanks[idx]
        local box, text = CreateCheck(f.rankChild, rankName, 4, y)
        box:SetChecked(AutoPromoteDB.inviteTool.ranks[idx] and true or false)
        if box._ccrtRefresh then box:_ccrtRefresh() end
        box:SetScript("OnClick", function(self)
            AutoPromoteDB.inviteTool.ranks[idx] = self:GetChecked() and true or nil
            if self._ccrtRefresh then self:_ccrtRefresh() end
        end)
        rankChecks[#rankChecks + 1] = { box = box, text = text }
        y = y - 27
    end
    f.rankChild:SetHeight(math.max(320, -y + 10))
end

local function ToggleInviteTool()
    local f = BuildInviteFrame()
    if f:IsShown() then
        f:Hide()
    else
        PopulateRanks()
        f:Show()
    end
end

-- Slash command. Le nom de SlashCmdList est volontairement unique.
SLASH_CCRTINVITETOOL1 = "/ccinvite"
SlashCmdList["CCRTINVITETOOL"] = function()
    ToggleInviteTool()
end

_G.CCRT_ToggleInviteTool = ToggleInviteTool
_G.CCRT_InviteSelectedRanks = InviteSelectedRanks

local event = CreateFrame("Frame")
event:RegisterEvent("PLAYER_LOGIN")
event:RegisterEvent("GUILD_ROSTER_UPDATE")
event:SetScript("OnEvent", function(_, evt)
    InitInviteDB()
    if evt == "PLAYER_LOGIN" or evt == "GUILD_ROSTER_UPDATE" then
        RefreshRanks()
    end
end)

print("|cff7381FF[CC RaidTools]|r Invite Tool chargé. Commande : /ccinvite")
