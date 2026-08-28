-- CC RaidTools - Auto Promote
--
-- Handles the automatic promotion of configured players and guild ranks,
-- plus the Auto Promote configuration panel.

local C = CCRT

local discoveredRanks = {}
local guildRankByFullName = {}
local guildRankByShort = {}
local nameRows = {}
local rankRows = {}
local mainFrame

local function RequestRoster()
    if not IsInGuild() then
        return
    end

    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

local function RefreshRanksData()
    wipe(discoveredRanks)
    wipe(guildRankByFullName)
    wipe(guildRankByShort)

    if not IsInGuild() then
        return
    end

    local memberCount = GetNumGuildMembers and GetNumGuildMembers() or 0
    for index = 1, memberCount do
        local name, rankName, rankIndex = GetGuildRosterInfo(index)
        if name and rankIndex ~= nil then
            discoveredRanks[rankIndex] = rankName
            guildRankByFullName[name] = rankIndex

            local shortName = C.StripRealm(name)
            if shortName then
                if guildRankByShort[shortName] == nil then
                    guildRankByShort[shortName] = rankIndex
                else
                    -- Multiple guild members can share the same short name.
                    -- Mark the entry as ambiguous rather than guessing a rank.
                    guildRankByShort[shortName] = false
                end
            end
        end
    end
end

local function GetGuildRankIndex(name)
    if not name then
        return nil
    end

    local fullNameRank = guildRankByFullName[name]
    if fullNameRank ~= nil then
        return fullNameRank
    end

    local shortName = C.StripRealm(name)
    local fallbackRank = shortName and guildRankByShort[shortName]
    if fallbackRank ~= false then
        return fallbackRank
    end

    return nil
end

local function ShouldPromote(name)
    local db = CCRaidToolsDB
    if not db then
        return false
    end

    if db.names[name] or db.names[C.StripRealm(name)] then
        return true
    end

    local rankIndex = GetGuildRankIndex(name)
    if not rankIndex then
        return false
    end

    local rankName = discoveredRanks[rankIndex]
    return db.ranks[rankIndex] or (rankName and db.rankNames[rankName]) or false
end

local function CheckAndPromote()
    C.InitDB()

    if not IsInRaid() or not UnitIsGroupLeader("player") then
        return
    end

    for index = 1, GetNumGroupMembers() do
        local name, rank = GetRaidRosterInfo(index)
        if name and rank == 0 and ShouldPromote(name) and not InCombatLockdown() then
            if C_PartyInfo and C_PartyInfo.PromoteToAssistant then
                C_PartyInfo.PromoteToAssistant(name)
            end

            print(C.L.chatPrefix .. name .. C.L.apPromotedSuffix)
        end
    end
end

C.CheckAndPromote = CheckAndPromote

function AutoPromoteUI_RefreshNames()
    if not mainFrame then
        return
    end

    local db = CCRaidToolsDB
    local sortedNames = {}
    for name in pairs(db.names) do
        sortedNames[#sortedNames + 1] = name
    end
    table.sort(sortedNames)

    mainFrame.nameChild:SetHeight(math.max(110, #sortedNames * 20))

    for index, name in ipairs(sortedNames) do
        local row = nameRows[index]
        if not row then
            row = CreateFrame("Frame", nil, mainFrame.nameChild)
            row:SetSize(260, 20)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * 20)

            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 4, 0)
            row.text:SetWidth(210)
            row.text:SetJustifyH("LEFT")

            row.remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
            row.remove:SetSize(20, 20)
            row.remove:SetPoint("RIGHT")
            row.remove:SetScript("OnClick", function()
                db.names[row.name] = nil
                AutoPromoteUI_RefreshNames()
            end)

            nameRows[index] = row
        end

        row.name = name
        row.text:SetText(name)
        row:Show()
    end

    for index = #sortedNames + 1, #nameRows do
        nameRows[index]:Hide()
    end
end

function AutoPromoteUI_RefreshRanks()
    if not mainFrame then
        return
    end

    local db = CCRaidToolsDB
    local ranks = {}
    for index, name in pairs(discoveredRanks) do
        ranks[#ranks + 1] = { index = index, name = name }
    end
    table.sort(ranks, function(left, right)
        return left.index < right.index
    end)

    mainFrame.noGuildText:SetShown(#ranks == 0)

    for index, info in ipairs(ranks) do
        local row = rankRows[index]
        if not row then
            row = CreateFrame("CheckButton", nil, mainFrame.rankChild, "BackdropTemplate")
            row:SetSize(48, 24)
            C.SkinCheckBox(row)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * 26)

            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", row, "RIGHT", 7, 0)

            row:SetScript("OnClick", function(self)
                local enabled = self:GetChecked() and true or false
                db.ranks[self.rankIndex] = enabled
                db.rankNames[self.rankName] = enabled

                if self._ccrtRefresh then
                    self:_ccrtRefresh()
                end

                CheckAndPromote()
            end)

            rankRows[index] = row
        end

        row.rankIndex = info.index
        row.rankName = info.name
        row.text:SetText(info.name)

        local saved = db.rankNames[info.name]
        if saved == nil then
            saved = db.ranks[info.index]
            if saved ~= nil then
                db.rankNames[info.name] = saved and true or false
            end
        end

        db.ranks[info.index] = saved and true or false
        row:SetChecked(saved and true or false)

        if row._ccrtRefresh then
            row:_ccrtRefresh()
        end
        row:Show()
    end

    for index = #ranks + 1, #rankRows do
        rankRows[index]:Hide()
    end

    local height = math.max(26, #ranks * 26)
    mainFrame.rankChild:SetHeight(height)
    mainFrame.rankSection:SetHeight(height)
end

local function BuildUI(frame)
    mainFrame = frame
    local db = CCRaidToolsDB

    local addLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addLabel:SetPoint("TOPLEFT", 16, -30)
    addLabel:SetText(C.L.apAddPlayersLabel)
    addLabel:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
    addLabel:SetWidth(288)
    addLabel:SetHeight(28)
    addLabel:SetJustifyH("LEFT")
    addLabel:SetJustifyV("TOP")

    local input = CreateFrame("ScrollFrame", nil, frame)
    input:SetPoint("TOPLEFT", 16, -62)
    input:SetSize(288, 60)

    local background = input:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.018, 0.018, 0.024, 0.90)

    local border = CreateFrame("Frame", nil, input, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    border:SetBackdropBorderColor(0, 0, 0, 1)

    local editBox = CreateFrame("EditBox", nil, input)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(2000)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetTextColor(1, 1, 1)
    editBox:SetSize(276, 50)
    editBox:SetJustifyH("LEFT")
    editBox:SetJustifyV("TOP")
    editBox:SetPoint("TOPLEFT", 6, -5)
    input:SetScrollChild(editBox)
    input:EnableMouse(true)
    input:SetScript("OnMouseDown", function()
        editBox:SetFocus()
    end)

    local addButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addButton:SetSize(90, 22)
    addButton:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 0, -8)
    addButton:SetText(C.L.apAddButton)
    C.SkinButton(addButton)
    addButton:SetScript("OnClick", function()
        for playerName in editBox:GetText():gmatch("[^,\n]+") do
            local normalizedName = C.NormalizeName(playerName)
            if normalizedName then
                db.names[normalizedName] = true
            end
        end

        editBox:SetText("")
        AutoPromoteUI_RefreshNames()
        CheckAndPromote()
    end)

    local listLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", addButton, "BOTTOMLEFT", 0, -14)
    listLabel:SetText(C.L.apPlayersListLabel)
    listLabel:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    local namesScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    namesScroll:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -6)
    namesScroll:SetSize(268, 110)
    C.SkinScrollBar(namesScroll)

    local namesChild = CreateFrame("Frame", nil, namesScroll)
    namesChild:SetSize(260, 110)
    namesScroll:SetScrollChild(namesChild)
    frame.nameChild = namesChild

    local rankLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankLabel:SetPoint("TOPLEFT", namesScroll, "BOTTOMLEFT", -4, -14)
    rankLabel:SetText(C.L.apGuildRankLabel)
    rankLabel:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    local ranksChild = CreateFrame("Frame", nil, frame)
    ranksChild:SetPoint("TOPLEFT", rankLabel, "BOTTOMLEFT", 4, -6)
    ranksChild:SetSize(256, 182)
    frame.rankChild = ranksChild
    frame.rankSection = ranksChild

    local noGuildText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noGuildText:SetPoint("TOPLEFT", ranksChild)
    noGuildText:SetText(C.L.apNoGuildLabel)
    noGuildText:SetWidth(250)
    noGuildText:SetJustifyH("LEFT")
    frame.noGuildText = noGuildText
end

local function Refresh()
    C.InitDB()
    RequestRoster()
    RefreshRanksData()
    AutoPromoteUI_RefreshNames()
    AutoPromoteUI_RefreshRanks()
end

C.RegisterModule("AutoPromote", BuildUI, Refresh)

local events = CreateFrame("Frame")
for _, eventName in ipairs({
    "GROUP_ROSTER_UPDATE",
    "PLAYER_ENTERING_WORLD",
    "GUILD_ROSTER_UPDATE",
    "PLAYER_REGEN_ENABLED",
}) do
    events:RegisterEvent(eventName)
end

events:SetScript("OnEvent", function(_, eventName)
    if eventName == "GUILD_ROSTER_UPDATE" then
        RefreshRanksData()
        AutoPromoteUI_RefreshRanks()
    elseif eventName == "PLAYER_REGEN_ENABLED" then
        if IsInRaid() and UnitIsGroupLeader("player") then
            CheckAndPromote()
        end
    else
        CheckAndPromote()
    end
end)

RequestRoster()
