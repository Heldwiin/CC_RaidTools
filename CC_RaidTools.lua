-- CC RaidTools : promeut automatiquement certains joueurs (ou rangs de guilde) en assistant de raid

local ADDON_NAME = ...
local frame = CreateFrame("Frame")

--------------------------------------------------
-- Base de données
--------------------------------------------------
local function InitDB()
    if not AutoPromoteDB then AutoPromoteDB = {} end
    if not AutoPromoteDB.names then AutoPromoteDB.names = {} end -- ["Nom-Royaume"] = true
    if not AutoPromoteDB.ranks then AutoPromoteDB.ranks = {} end -- [guildRankIndex] = true
    if not AutoPromoteDB.rankNames then AutoPromoteDB.rankNames = {} end -- [rankName] = true
    if not AutoPromoteDB.logging then
        AutoPromoteDB.logging = { lfr = false, normal = false, heroic = false, mythic = false }
    end
    if AutoPromoteDB.raidCheckEnabled == nil then AutoPromoteDB.raidCheckEnabled = true end
end

local function NormalizeName(name)
    if not name then return nil end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    return name
end

-- Retire le "-Royaume" d'un nom pour comparer de façon fiable
local function StripRealm(name)
    if not name then return name end
    return name:match("^([^%-]+)") or name
end

--------------------------------------------------
-- Découverte des rangs de guilde existants
-- discoveredRanks[rankIndex] = rankName
-- guildRankByName[NomSansRoyaume] = rankIndex
--------------------------------------------------
local discoveredRanks = {}
local guildRankByName = {}

local function RequestGuildRoster()
    if not IsInGuild() then return end
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

local function RefreshDiscoveredRanks()
    wipe(discoveredRanks)
    wipe(guildRankByName)
    if not IsInGuild() then return end
    local n = GetNumGuildMembers and GetNumGuildMembers() or 0
    for i = 1, n do
        local name, rankName, rankIndex = GetGuildRosterInfo(i)
        if name and rankIndex ~= nil then
            discoveredRanks[rankIndex] = rankName
            guildRankByName[StripRealm(name)] = rankIndex
        end
    end
end

--------------------------------------------------
-- Logique de promotion
--------------------------------------------------
local pendingPromotions = {} -- ["Nom-Royaume"] = true, en attente de sortie de combat

local function CheckAndPromote()
    if not IsInRaid() then return end
    if not UnitIsGroupLeader("player") then return end

    local numMembers = GetNumGroupMembers()

    for i = 1, numMembers do
        local name, rank = GetRaidRosterInfo(i)
        if name and rank == 0 then
            local shouldPromote = false

            if AutoPromoteDB.names[name] then
                shouldPromote = true
            end

            if not shouldPromote then
                local guildRankIndex = guildRankByName[StripRealm(name)]
                if guildRankIndex ~= nil then
                    local guildRankName = discoveredRanks[guildRankIndex]
                    if AutoPromoteDB.ranks[guildRankIndex]
                        or (guildRankName and AutoPromoteDB.rankNames[guildRankName]) then
                        shouldPromote = true
                    end
                end
            end

            if shouldPromote then
                if InCombatLockdown() then
                    -- Bloqué par Blizzard en combat depuis le patch 12.0.5 : on retente à la fin du combat
                    pendingPromotions[name] = true
                else
                    PromoteToAssistant(name)
                    print("|cff33ff99[CC RaidTools]|r " .. name .. " promu(e) assistant de raid.")
                end
            end
        end
    end
end

local function ProcessPendingPromotions()
    if InCombatLockdown() then return end
    for name in pairs(pendingPromotions) do
        PromoteToAssistant(name)
        print("|cff33ff99[CC RaidTools]|r " .. name .. " promu(e) assistant de raid (après combat).")
        pendingPromotions[name] = nil
    end
end

--------------------------------------------------
-- Enregistrement automatique des combats (logging)
--------------------------------------------------
local loggingStartedByAddon = false

-- IDs de difficulté raid (retail) : 17 = LFR, 14 = Normal, 15 = Héroïque, 16 = Mythique
local function CheckAutoLog()
    if not AutoPromoteDB or not AutoPromoteDB.logging then return end

    local _, instanceType, difficultyID = GetInstanceInfo()
    local shouldLog = false

    if instanceType == "raid" then
        if difficultyID == 17 and AutoPromoteDB.logging.lfr then
            shouldLog = true
        elseif difficultyID == 14 and AutoPromoteDB.logging.normal then
            shouldLog = true
        elseif difficultyID == 15 and AutoPromoteDB.logging.heroic then
            shouldLog = true
        elseif difficultyID == 16 and AutoPromoteDB.logging.mythic then
            shouldLog = true
        end
    end

    local currentlyLogging = LoggingCombat()

    if shouldLog and not currentlyLogging then
        LoggingCombat(true)
        loggingStartedByAddon = true
        print("|cff33ff99[CC RaidTools]|r Enregistrement des combats démarré.")
    elseif not shouldLog and currentlyLogging and loggingStartedByAddon then
        LoggingCombat(false)
        loggingStartedByAddon = false
        print("|cff33ff99[CC RaidTools]|r Enregistrement des combats arrêté.")
    end
end


--------------------------------------------------


-- Couleur principale du skin (même bleu/violet que le titre)
local CCRT_BRAND_R, CCRT_BRAND_G, CCRT_BRAND_B = 0.451, 0.506, 1

-- Skin transparent avec bordure pixel 1 px
local function ApplyCharacterPanelSkin(frame)
    if not frame or frame._ccrtSkin then return end
    frame._ccrtSkin = true

    -- Frame volontairement créé SANS template Blizzard.
    -- Aspect proche du menu de jeu : panneau noir translucide + contour sombre net.
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0.025, 0.025, 0.035, 0.82)
    frame._ccrtBg = bg

    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetAllPoints(frame)
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(0, 0, 0, 1)
    frame._ccrtBorder = border

    -- Ligne discrète sous le titre, comme le menu moderne.
    local divider = frame:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -28)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -28)
    divider:SetHeight(1)
    divider:SetColorTexture(0, 0, 0, 0.95)
    frame._ccrtDivider = divider
end

local function CCRTSkinButton(button)
    if not button or button._ccrtSkin then return end
    button._ccrtSkin = true
    if button.Left then button.Left:Hide() end
    if button.Middle then button.Middle:Hide() end
    if button.Right then button.Right:Hide() end
    if button.LeftDisabled then button.LeftDisabled:Hide() end
    if button.MiddleDisabled then button.MiddleDisabled:Hide() end
    if button.RightDisabled then button.RightDisabled:Hide() end
    if button.SetNormalTexture then button:SetNormalTexture("") end
    if button.SetPushedTexture then button:SetPushedTexture("") end
    if button.SetDisabledTexture then button:SetDisabledTexture("") end

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.045, 0.045, 0.055, 0.94)
    button._ccrtBg = bg

    local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    border:SetBackdropBorderColor(0, 0, 0, 1)
    button._ccrtBorder = border

    button:HookScript("OnEnter", function(self)
        if self._ccrtBg then self._ccrtBg:SetColorTexture(0.10, 0.10, 0.13, 0.96) end
    end)
    button:HookScript("OnLeave", function(self)
        if self._ccrtBg then self._ccrtBg:SetColorTexture(0.045, 0.045, 0.055, 0.94) end
    end)
end

local function CCRTSkinEditBox(scroll)
    if not scroll or scroll._ccrtSkin then return end
    scroll._ccrtSkin = true
    if scroll.NineSlice then scroll.NineSlice:Hide() end
    if scroll.Background then scroll.Background:Hide() end

    local bg = scroll:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.025, 0.025, 0.03, 0.88)

    local border = CreateFrame("Frame", nil, scroll, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    border:SetBackdropBorderColor(0, 0, 0, 1)
end

local function CCRTSkinCheckBox(box)
    if not box or box._ccrtSkin then return end
    box._ccrtSkin = true

    box:EnableMouse(true)
    box:RegisterForClicks("LeftButtonUp")

    -- Skin 100% custom : aucun UICheckButtonTemplate Blizzard.
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    box:SetBackdropColor(0.035, 0.035, 0.045, 1)
    box:SetBackdropBorderColor(0, 0, 0, 1)

    local checkedBg = box:CreateTexture(nil, "ARTWORK")
    checkedBg:SetPoint("TOPLEFT", 3, -3)
    checkedBg:SetPoint("BOTTOMRIGHT", -3, 3)
    checkedBg:SetColorTexture(CCRT_BRAND_R * 0.62, CCRT_BRAND_G * 0.62, CCRT_BRAND_B * 0.72, 1)
    checkedBg:Hide()

    -- Croix X propre, dessinée avec deux traits fins.
    local tick = CreateFrame("Frame", nil, box)
    tick:SetAllPoints(box)
    tick:EnableMouse(false)

    local x1 = tick:CreateTexture(nil, "OVERLAY")
    x1:SetColorTexture(1, 1, 1, 1)
    x1:SetSize(2, 13)
    x1:SetPoint("CENTER")
    x1:SetRotation(math.rad(45))

    local x2 = tick:CreateTexture(nil, "OVERLAY")
    x2:SetColorTexture(1, 1, 1, 1)
    x2:SetSize(2, 13)
    x2:SetPoint("CENTER")
    x2:SetRotation(math.rad(-45))

    tick:Hide()

    local hover = box:CreateTexture(nil, "HIGHLIGHT")
    hover:SetPoint("TOPLEFT", 2, -2)
    hover:SetPoint("BOTTOMRIGHT", -2, 2)
    hover:SetColorTexture(CCRT_BRAND_R, CCRT_BRAND_G, CCRT_BRAND_B, 0.15)

    local function Refresh(self)
        if self:GetChecked() then
            checkedBg:Show()
            tick:Show()
        else
            checkedBg:Hide()
            tick:Hide()
        end
    end

    box._ccrtRefresh = Refresh
    box:HookScript("OnShow", Refresh)
    Refresh(box)
end

local function CCRTSkinScrollBar(scroll)
    if not scroll then return end
    local bar = scroll.ScrollBar
    if not bar or bar._ccrtSkin then return end
    bar._ccrtSkin = true
    if bar.Background then bar.Background:Hide() end
    if bar.Track then bar.Track:Hide() end
    if bar.Back then bar.Back:Hide() end
    if bar.Forward then bar.Forward:Hide() end
end

-- Ready Check : fenêtre de consommables au ready check
-- Inspiré du comportement de Method Raid Tools, sans dépendance à MRT
--------------------------------------------------
local raidCheckFrame
local raidCheckRows = {}
local raidCheckReadyStatus = {}
local RAIDCHECK_ROW_HEIGHT = 20

-- IDs Retail repris des tables actuelles de RaidCheck/MRT fourni.
local RAIDCHECK_FOOD = {
    [308488]=true,[308506]=true,[308434]=true,[308514]=true,[327708]=true,[327706]=true,[327709]=true,[308525]=true,[327707]=true,[308637]=true,
    [308474]=true,[308504]=true,[308430]=true,[308509]=true,[327704]=true,[327701]=true,[327705]=true,[327702]=true,
    [382145]=true,[382150]=true,[382146]=true,[382149]=true,[396092]=true,[382246]=true,[382247]=true,
    [382152]=true,[382153]=true,[382157]=true,[382230]=true,[382231]=true,[382232]=true,[382154]=true,[382155]=true,[382156]=true,[382234]=true,[382235]=true,[382236]=true,
}
local RAIDCHECK_FLASK = {
    [1236763]=true,[1239355]=true,[1235057]=true,[1239755]=true,[1236767]=true,
    [1235111]=true,[1235110]=true,[1235108]=true,
}
local RAIDCHECK_RUNE = {
    [224001]=true,[270058]=true,[317065]=true,[347901]=true,[367405]=true,[393438]=true,[453250]=true,[1234969]=true,[1242347]=true,[1264426]=true,
}

-- Buffs de raid Retail (mêmes IDs que le RaidCheck MRT fourni)
local RAIDCHECK_INT   = { [1459]=true, [264760]=true }       -- Intelligence (Mage)
local RAIDCHECK_AP    = { [6673]=true, [264761]=true }       -- Puissance d'attaque (Guerrier)
local RAIDCHECK_DRUID = { [1126]=true }                      -- Marque du fauve (Druide)
local RAIDCHECK_STAM  = { [21562]=true, [264764]=true }      -- Endurance (Prêtre)
local RAIDCHECK_SHAM  = { [462854]=true }                    -- Buff Chaman / Skyfury actuel

-- Vantus : anciens IDs connus + détection générique/localisée par le préfixe du sort.
local RAIDCHECK_VANTUS = {
    [269276]=true,[269405]=true,[269408]=true,[269407]=true,[269409]=true,[269411]=true,[269412]=true,[269413]=true,
    [298622]=true,[298640]=true,[298642]=true,[298643]=true,[298644]=true,[298645]=true,[298646]=true,[302914]=true,
    [306475]=true,[306480]=true,[306476]=true,[306477]=true,[306478]=true,[306484]=true,[306485]=true,[306479]=true,[313550]=true,[313551]=true,[313554]=true,[313556]=true,
    [311445]=true,[334132]=true,[311448]=true,[311446]=true,[311447]=true,[311449]=true,[311450]=true,[311451]=true,[311452]=true,[334131]=true,
    [354384]=true,[354385]=true,[354386]=true,[354387]=true,[354388]=true,[354389]=true,[354390]=true,[354391]=true,[354392]=true,[354393]=true,
    [384233]=true,[384234]=true,[384235]=true,[384229]=true,[384228]=true,[384227]=true,[384192]=true,[384203]=true,[384201]=true,
    [384239]=true,[384240]=true,[384241]=true,[384245]=true,[384246]=true,[384247]=true,[384220]=true,[384221]=true,[384222]=true,
    [384210]=true,[384209]=true,[384208]=true,[384214]=true,[384215]=true,[384216]=true,[384154]=true,[384248]=true,[384306]=true,
}

local raidCheckVantusPrefix
local function GetVantusPrefix()
    if raidCheckVantusPrefix ~= nil then return raidCheckVantusPrefix end
    raidCheckVantusPrefix = false
    local name
    if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(237825)
    elseif GetSpellInfo then name = GetSpellInfo(237825) end
    if name then
        local prefix = name:match("^(.-)[:%-：]")
        if prefix and prefix ~= "" then raidCheckVantusPrefix = "^" .. prefix end
    end
    return raidCheckVantusPrefix
end

local function SafeAuraSpellID(auraData)
    if not auraData then return nil end
    if issecretvalue and issecretvalue(auraData.spellId) then return nil end
    if canaccessvalue and auraData.spellId ~= nil and not canaccessvalue(auraData.spellId) then return nil end
    return auraData.spellId
end

local function GetConsumableStatus(unit)
    local food, flask, rune, vantus = false, false, false, false
    local intel, ap, druid, stam, sham = false, false, false, false, false
    if not unit or not UnitExists(unit) then return food, flask, rune, vantus, intel, ap, druid, stam, sham end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
        return food, flask, rune, vantus, intel, ap, druid, stam, sham
    end
    local vantusPrefix = GetVantusPrefix()
    for i = 1, 80 do
        local auraData = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not auraData then break end
        local spellID = SafeAuraSpellID(auraData)
        if spellID then
            if RAIDCHECK_FOOD[spellID] or auraData.icon == 136000 then food = true end
            if RAIDCHECK_FLASK[spellID] then flask = true end
            if RAIDCHECK_RUNE[spellID] then rune = true end
            if RAIDCHECK_VANTUS[spellID] or (vantusPrefix and auraData.name and auraData.name:find(vantusPrefix)) then vantus = true end
            if RAIDCHECK_INT[spellID] then intel = true end
            if RAIDCHECK_AP[spellID] then ap = true end
            if RAIDCHECK_DRUID[spellID] then druid = true end
            if RAIDCHECK_STAM[spellID] then stam = true end
            if RAIDCHECK_SHAM[spellID] then sham = true end
        end
    end
    return food, flask, rune, vantus, intel, ap, druid, stam, sham
end
local function StatusText(ok)
    return ok and "|cff33ff66OK|r" or "|cffff4444KO|r"
end

local function ReadyText(status)
    -- Statut lisible et identique au reste de la fenêtre.
    if status == true or status == "ready" then return "|cff33ff66OK|r" end
    if status == false or status == "notready" then return "|cffff4444KO|r" end
    return "|cffff9900WAIT|r"
end

local function CreateRaidCheckRow(parent, idx)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(615, RAIDCHECK_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(idx - 1) * RAIDCHECK_ROW_HEIGHT)

    local function NewText(x, width, justify)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", x, 0)
        fs:SetWidth(width)
        fs:SetJustifyH(justify or "CENTER")
        return fs
    end
    row.nameText = NewText(4, 125, "LEFT")
    row.readyText = NewText(130, 48)
    row.foodText = NewText(179, 48)
    row.flaskText = NewText(228, 48)
    row.runeText = NewText(277, 48)
    row.vantusText = NewText(326, 52)
    -- Buffs raid : icône en couleur si présent, grisée si absent.
    local function NewBuffIcon(x, spellID)
        local tex = row:CreateTexture(nil, "ARTWORK")
        tex:SetSize(16, 16)
        tex:SetPoint("CENTER", row, "LEFT", x + 19, 0)
        local icon
        if C_Spell and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(spellID) end
        if not icon and GetSpellTexture then icon = GetSpellTexture(spellID) end
        tex:SetTexture(icon or 134400)
        -- Zoom de 20 % dans l'icône : retire 10 % sur chaque bord.
        tex:SetTexCoord(0.10, 0.90, 0.10, 0.90)
        tex:SetDesaturated(true)
        tex:SetAlpha(0.45)
        return tex
    end
    row.intIcon   = NewBuffIcon(380, 1459)
    row.apIcon    = NewBuffIcon(419, 6673)
    row.druidIcon = NewBuffIcon(458, 1126)
    row.stamIcon  = NewBuffIcon(497, 21562)
    row.shamIcon  = NewBuffIcon(536, 462854)
    return row
end

local function SetBuffIconState(texture, active)
    if not texture then return end
    texture:SetDesaturated(not active)
    texture:SetAlpha(active and 1 or 0.40)
    if active then texture:SetVertexColor(1, 1, 1) else texture:SetVertexColor(0.65, 0.65, 0.65) end
end

local function BuildRaidCheckFrame()
    if raidCheckFrame then return end
    raidCheckFrame = CreateFrame("Frame", "CCRaidToolsRaidCheckFrame", UIParent)
    raidCheckFrame:SetSize(625, 520)
    raidCheckFrame:SetPoint("CENTER", 320, 0)
    raidCheckFrame:SetMovable(true)
    raidCheckFrame:EnableMouse(true)
    raidCheckFrame:RegisterForDrag("LeftButton")
    raidCheckFrame:SetScript("OnDragStart", raidCheckFrame.StartMoving)
    raidCheckFrame:SetScript("OnDragStop", raidCheckFrame.StopMovingOrSizing)
    ApplyCharacterPanelSkin(raidCheckFrame)

    raidCheckFrame.TitleText = raidCheckFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidCheckFrame.TitleText:SetPoint("TOP", raidCheckFrame, "TOP", 0, -7)
    raidCheckFrame.TitleText:SetText("CC RaidTools - Ready Check v1.0")
    raidCheckFrame.TitleText:SetTextColor(CCRT_BRAND_R, CCRT_BRAND_G, CCRT_BRAND_B)

    local raidClose = CreateFrame("Button", nil, raidCheckFrame)
    raidClose:SetSize(22, 22)
    raidClose:SetPoint("TOPRIGHT", -4, -4)
    raidClose:SetText("×")
    raidClose:SetNormalFontObject("GameFontNormalLarge")
    raidClose:SetHighlightFontObject("GameFontHighlightLarge")
    raidClose:SetScript("OnClick", function() raidCheckFrame:Hide() end)
    raidCheckFrame.CloseButton = raidClose

    raidCheckFrame:Hide()

    local header = CreateFrame("Frame", nil, raidCheckFrame)
    header:SetPoint("TOPLEFT", 12, -30)
    header:SetSize(590, 20)
    local function HeaderText(text, x, width, justify)
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", x, 0)
        fs:SetWidth(width)
        fs:SetJustifyH(justify or "CENTER")
        fs:SetText(text)
        fs:SetTextColor(CCRT_BRAND_R, CCRT_BRAND_G, CCRT_BRAND_B)
        return fs
    end

    -- À la place de "Joueur", affiche dynamiquement : joueurs prêts / joueurs du raid.
    raidCheckFrame.readyCountHeader = HeaderText("0/0", 4, 125, "LEFT")
    HeaderText("Prêt", 130, 48)
    HeaderText("Repas", 179, 48)
    HeaderText("Flacon", 228, 48)
    HeaderText("Rune", 277, 48)
    HeaderText("Vantus", 326, 52)
    HeaderText("Intel", 380, 38)
    HeaderText("PA", 419, 38)
    HeaderText("Druid", 458, 38)
    HeaderText("Endu", 497, 38)
    HeaderText("Sham", 536, 38)

    local scroll = CreateFrame("ScrollFrame", nil, raidCheckFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -52)
    scroll:SetSize(580, 445)
    CCRTSkinScrollBar(scroll)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(575, 445)
    scroll:SetScrollChild(child)
    raidCheckFrame.child = child
end

local function RefreshRaidCheck()
    if not raidCheckFrame or not raidCheckFrame:IsShown() then return end
    local count = IsInRaid() and GetNumGroupMembers() or 0
    local readyCount = 0

    for i = 1, count do
        local name, _, _, _, _, classFileName = GetRaidRosterInfo(i)
        local unit = "raid" .. i
        local row = raidCheckRows[i]
        if not row then
            row = CreateRaidCheckRow(raidCheckFrame.child, i)
            raidCheckRows[i] = row
        end
        row.unit = unit
        row.name = name
        local color = classFileName and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFileName]
        if color then row.nameText:SetTextColor(color.r, color.g, color.b) else row.nameText:SetTextColor(1,1,1) end
        row.nameText:SetText(StripRealm(name or "?"))
        -- READY_CHECK_CONFIRM est la source prioritaire : sur certaines versions de WoW,
        -- GetReadyCheckStatus() peut rester à waiting/nil ou être protégé, ce qui écrasait
        -- auparavant la réponse reçue juste avant.
        local status = raidCheckReadyStatus[unit]
        if status == nil and name then status = raidCheckReadyStatus[name] or raidCheckReadyStatus[StripRealm(name)] end
        -- Poll de l'API Blizzard : permet de récupérer les réponses même si READY_CHECK_CONFIRM
        -- ne fournit pas un unit token exploitable sur cette version du client.
        if GetReadyCheckStatus then
            local apiStatus = GetReadyCheckStatus(unit)
            if apiStatus == "ready" or apiStatus == "notready" then
                status = apiStatus
                raidCheckReadyStatus[unit] = apiStatus
                if name then raidCheckReadyStatus[name] = apiStatus; raidCheckReadyStatus[StripRealm(name)] = apiStatus end
            end
        end
        row.readyText:SetText(ReadyText(status))
        if status == "ready" then
            readyCount = readyCount + 1
        end

        local food, flask, rune, vantus, intel, ap, druid, stam, sham = GetConsumableStatus(unit)
        row.foodText:SetText(StatusText(food))
        row.flaskText:SetText(StatusText(flask))
        row.runeText:SetText(StatusText(rune))
        row.vantusText:SetText(StatusText(vantus))
        SetBuffIconState(row.intIcon, intel)
        SetBuffIconState(row.apIcon, ap)
        SetBuffIconState(row.druidIcon, druid)
        SetBuffIconState(row.stamIcon, stam)
        SetBuffIconState(row.shamIcon, sham)
        row:Show()
    end
    for i = count + 1, #raidCheckRows do raidCheckRows[i]:Hide() end

    -- Compteur dynamique dans l'en-tête de la première colonne.
    if raidCheckFrame.readyCountHeader then
        raidCheckFrame.readyCountHeader:SetText(
            "|cff66ff66" .. tostring(readyCount) .. "|r|cff7381FF/" .. tostring(count) .. "|r"
        )
    end
end


local function UpdateReadyCheckResponse(unit, response)
    if not unit then return end
    local normalized
    if response == true then normalized = "ready" elseif response == false then normalized = "notready" else return end
    raidCheckReadyStatus[unit] = normalized
    local unitName = UnitExists(unit) and UnitName(unit) or unit
    if unitName then
        raidCheckReadyStatus[unitName] = normalized
        raidCheckReadyStatus[StripRealm(unitName)] = normalized
    end
    RefreshRaidCheck()
end
local raidCheckHideTimer
local function ShowRaidCheck(starter)
    if not AutoPromoteDB or not AutoPromoteDB.raidCheckEnabled or not IsInRaid() then return end
    wipe(raidCheckReadyStatus)
    -- Le lanceur de l'appel est considéré prêt immédiatement par Blizzard/MRT.
    if starter then
        raidCheckReadyStatus[starter] = "ready"
        local starterName = UnitExists(starter) and UnitName(starter) or starter
        if starterName then raidCheckReadyStatus[starterName] = "ready"; raidCheckReadyStatus[StripRealm(starterName)] = "ready" end
    end
    BuildRaidCheckFrame()
    if raidCheckHideTimer then raidCheckHideTimer:Cancel(); raidCheckHideTimer = nil end
    raidCheckFrame:Show()
    RefreshRaidCheck()
    C_Timer.After(0.2, RefreshRaidCheck)
    C_Timer.After(0.5, RefreshRaidCheck)
    C_Timer.After(1.5, RefreshRaidCheck)
    if raidCheckFrame.readyTicker then raidCheckFrame.readyTicker:Cancel() end
    raidCheckFrame.readyTicker = C_Timer.NewTicker(0.25, function()
        if raidCheckFrame and raidCheckFrame:IsShown() then RefreshRaidCheck() end
    end)
end

local function FinishRaidCheck()
    -- À la fin de l'appel, Blizzard considère les joueurs sans réponse comme absents.
    -- On fige donc tous les WAIT restants en KO avant le dernier rafraîchissement.
    local n = GetNumGroupMembers() or 0
    for i = 1, n do
        local unit = "raid" .. i
        if UnitExists(unit) then
            local name = UnitName(unit)
            local shortName = name and StripRealm(name)
            local status = raidCheckReadyStatus[unit]
                or (name and raidCheckReadyStatus[name])
                or (shortName and raidCheckReadyStatus[shortName])
            if status ~= "ready" and status ~= "notready" then
                raidCheckReadyStatus[unit] = "notready"
                if name then raidCheckReadyStatus[name] = "notready" end
                if shortName then raidCheckReadyStatus[shortName] = "notready" end
            end
        end
    end
    RefreshRaidCheck()
    if raidCheckFrame and raidCheckFrame.readyTicker then
        raidCheckFrame.readyTicker:Cancel()
        raidCheckFrame.readyTicker = nil
    end
    if raidCheckHideTimer then raidCheckHideTimer:Cancel() end
    raidCheckHideTimer = C_Timer.NewTimer(30, function()
        raidCheckHideTimer = nil
        if raidCheckFrame then raidCheckFrame:Hide(); if raidCheckFrame.readyTicker then raidCheckFrame.readyTicker:Cancel(); raidCheckFrame.readyTicker=nil end end
    end)
end

--------------------------------------------------
-- Evénements
--------------------------------------------------
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("READY_CHECK")
frame:RegisterEvent("READY_CHECK_CONFIRM")
frame:RegisterEvent("READY_CHECK_FINISHED")
frame:RegisterEvent("UNIT_AURA")

frame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitDB()
        RequestGuildRoster()
        print("|cff33ff99[CC RaidTools]|r v1.0 chargé - Ready Check actif")
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        CheckAndPromote()
        C_Timer.After(2, CheckAutoLog)
    elseif event == "PLAYER_REGEN_ENABLED" then
        ProcessPendingPromotions()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(2, CheckAutoLog)
    elseif event == "GUILD_ROSTER_UPDATE" then
        RefreshDiscoveredRanks()
        if AutoPromoteUI_RefreshRanks then AutoPromoteUI_RefreshRanks() end
    elseif event == "READY_CHECK" then
        ShowRaidCheck(arg1)
    elseif event == "READY_CHECK_CONFIRM" then
        UpdateReadyCheckResponse(arg1, arg2)
        C_Timer.After(0.10, RefreshRaidCheck)
        C_Timer.After(0.50, RefreshRaidCheck)
    elseif event == "READY_CHECK_FINISHED" then
        FinishRaidCheck()
    elseif event == "UNIT_AURA" then
        if raidCheckFrame and raidCheckFrame:IsShown() then RefreshRaidCheck() end
    end
end)

--------------------------------------------------
-- Interface graphique
--------------------------------------------------
local mainFrame
local nameRows = {}
local rankRows = {}
local ROW_HEIGHT = 20

local function RemoveName(name)
    AutoPromoteDB.names[name] = nil
    if AutoPromoteUI_RefreshNames then AutoPromoteUI_RefreshNames() end
end

local function CreateNameRow(parent, idx)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(260, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(idx - 1) * ROW_HEIGHT)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 4, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWidth(210)

    row.removeBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    row.removeBtn:SetSize(20, 20)
    row.removeBtn:SetPoint("RIGHT", 0, 0)
    row.removeBtn:SetScript("OnClick", function() RemoveName(row.name) end)

    return row
end

local function CreateRankRow(parent, idx)
    local row = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    row:SetSize(24, 24)
    CCRTSkinCheckBox(row)
    row:SetPoint("TOPLEFT", 0, -(idx - 1) * ROW_HEIGHT)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row, "RIGHT", 2, 0)
    row.text:SetJustifyH("LEFT")

    row:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        if self.rankIndex ~= nil then
            AutoPromoteDB.ranks[self.rankIndex] = checked
        end
        if self.rankName then
            AutoPromoteDB.rankNames[self.rankName] = checked
        end
        if self._ccrtRefresh then self:_ccrtRefresh() end
        CheckAndPromote()
    end)

    return row
end

local function BuildUI()
    mainFrame = CreateFrame("Frame", "CCRaidToolsFrame", UIParent)
    mainFrame:SetSize(320, 645)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    ApplyCharacterPanelSkin(mainFrame)

    mainFrame.TitleText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainFrame.TitleText:SetPoint("TOP", mainFrame, "TOP", 0, -7)
    mainFrame.TitleText:SetText("CC RaidTools")
    mainFrame.TitleText:SetTextColor(CCRT_BRAND_R, CCRT_BRAND_G, CCRT_BRAND_B)

    local mainClose = CreateFrame("Button", nil, mainFrame)
    mainClose:SetSize(22, 22)
    mainClose:SetPoint("TOPRIGHT", -4, -4)
    mainClose:SetText("×")
    mainClose:SetNormalFontObject("GameFontNormalLarge")
    mainClose:SetHighlightFontObject("GameFontHighlightLarge")
    mainClose:SetScript("OnClick", function() mainFrame:Hide() end)
    mainFrame.CloseButton = mainClose

    mainFrame:Hide()

    -- Section 1 : ajout de pseudos
    local addLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addLabel:SetPoint("TOPLEFT", 16, -30)
    addLabel:SetText("Ajouter des joueurs (un par ligne, format Nom-Royaume) :")
    addLabel:SetTextColor(CCRT_BRAND_R, CCRT_BRAND_G, CCRT_BRAND_B)
    addLabel:SetWidth(288)
    addLabel:SetHeight(28)
    addLabel:SetJustifyH("LEFT")
    addLabel:SetJustifyV("TOP")

    -- Zone de saisie entièrement custom : aucun InputScrollFrameTemplate Blizzard.
    local inputScroll = CreateFrame("ScrollFrame", nil, mainFrame)
    inputScroll:SetPoint("TOPLEFT", 16, -62)
    inputScroll:SetSize(288, 60)

    local inputBg = inputScroll:CreateTexture(nil, "BACKGROUND")
    inputBg:SetAllPoints()
    inputBg:SetColorTexture(0.018, 0.018, 0.024, 0.90)

    local inputBorder = CreateFrame("Frame", nil, inputScroll, "BackdropTemplate")
    inputBorder:SetAllPoints()
    inputBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    inputBorder:SetBackdropBorderColor(0, 0, 0, 1)

    local editBox = CreateFrame("EditBox", nil, inputScroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(2000)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetTextColor(1, 1, 1)
    editBox:SetWidth(276)
    editBox:SetHeight(50)
    editBox:SetJustifyH("LEFT")
    editBox:SetJustifyV("TOP")
    editBox:SetTextInsets(0, 0, 0, 0)
    inputScroll:SetScrollChild(editBox)
    editBox:SetPoint("TOPLEFT", inputScroll, "TOPLEFT", 6, -5)

    -- Molette si le texte dépasse la hauteur de la zone.
    inputScroll:EnableMouseWheel(true)
    inputScroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        if range and range > 0 then
            local nextScroll = self:GetVerticalScroll() - delta * 18
            self:SetVerticalScroll(math.max(0, math.min(range, nextScroll)))
        end
    end)

    -- Clic dans le panneau = focus sur la zone de texte.
    inputScroll:EnableMouse(true)
    inputScroll:SetScript("OnMouseDown", function()
        editBox:SetFocus()
    end)

    mainFrame.editBox = editBox

    local addButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    addButton:SetSize(90, 22)
    addButton:SetPoint("TOPLEFT", inputScroll, "BOTTOMLEFT", 0, -8)
    addButton:SetText("Ajouter")
    CCRTSkinButton(addButton)
    addButton:SetScript("OnClick", function()
        local text = editBox:GetText()
        for part in text:gmatch("[^,\n]+") do
            local name = NormalizeName(part)
            if name then AutoPromoteDB.names[name] = true end
        end
        editBox:SetText("")
        AutoPromoteUI_RefreshNames()
        CheckAndPromote()
    end)

    -- Section 2 : liste des pseudos ajoutés
    local listLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", addButton, "BOTTOMLEFT", 0, -14)
    listLabel:SetText("Joueurs Auto Promote :")
    listLabel:SetTextColor(CCRT_BRAND_R, CCRT_BRAND_G, CCRT_BRAND_B)

    local nameScroll = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
    nameScroll:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -6)
    nameScroll:SetSize(268, 110)
    CCRTSkinScrollBar(nameScroll)
    local nameChild = CreateFrame("Frame", nil, nameScroll)
    nameChild:SetSize(260, 110)
    nameScroll:SetScrollChild(nameChild)
    mainFrame.nameChild = nameChild

    -- Section 3 : rangs de guilde
    local rankLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankLabel:SetPoint("TOPLEFT", nameScroll, "BOTTOMLEFT", -4, -14)
    rankLabel:SetText("Rang à Auto Promote :")
    rankLabel:SetTextColor(CCRT_BRAND_R, CCRT_BRAND_G, CCRT_BRAND_B)
    rankLabel:SetWidth(288)
    rankLabel:SetJustifyH("LEFT")

    local rankScroll = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
    rankScroll:SetPoint("TOPLEFT", rankLabel, "BOTTOMLEFT", 4, -6)
    rankScroll:SetSize(264, 100)
    CCRTSkinScrollBar(rankScroll)
    local rankChild = CreateFrame("Frame", nil, rankScroll)
    rankChild:SetSize(256, 100)
    rankScroll:SetScrollChild(rankChild)
    mainFrame.rankChild = rankChild

    local noGuildText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noGuildText:SetPoint("TOPLEFT", rankChild, "TOPLEFT", 0, 0)
    noGuildText:SetText("Pas de guilde, ou liste des rangs en cours de chargement...")
    noGuildText:SetWidth(250)
    noGuildText:SetJustifyH("LEFT")
    mainFrame.noGuildText = noGuildText

    -- Section 4 : enregistrement automatique des combats
    local logLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    logLabel:SetPoint("TOPLEFT", rankScroll, "BOTTOMLEFT", -4, -14)
    logLabel:SetText("AutoLog :")
    logLabel:SetTextColor(CCRT_BRAND_R, CCRT_BRAND_G, CCRT_BRAND_B)
    logLabel:SetWidth(288)
    logLabel:SetJustifyH("LEFT")

    local function CreateLoggingCheckbox(anchorTo, labelText, dbKey)
        local chk = CreateFrame("CheckButton", nil, mainFrame, "BackdropTemplate")
        chk:SetSize(24, 24)
        CCRTSkinCheckBox(chk)
        chk:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -2)
        chk.text = chk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        chk.text:SetPoint("LEFT", chk, "RIGHT", 2, 0)
        chk.text:SetText(labelText)
        chk:SetChecked(AutoPromoteDB.logging[dbKey] and true or false)
        if chk._ccrtRefresh then chk:_ccrtRefresh() end
        chk:SetScript("OnClick", function(self)
            if self._ccrtRefresh then self:_ccrtRefresh() end
            AutoPromoteDB.logging[dbKey] = self:GetChecked() and true or false
            CheckAutoLog()
        end)
        return chk
    end

    local chkLFR = CreateLoggingCheckbox(logLabel, "LFR", "lfr")
    local chkNormal = CreateLoggingCheckbox(chkLFR, "Normal", "normal")
    local chkHeroic = CreateLoggingCheckbox(chkNormal, "Héroïque", "heroic")
    local chkMythic = CreateLoggingCheckbox(chkHeroic, "Mythique", "mythic")
    mainFrame.loggingCheckboxes = { lfr = chkLFR, normal = chkNormal, heroic = chkHeroic, mythic = chkMythic }

    local raidCheckChk = CreateFrame("CheckButton", nil, mainFrame, "BackdropTemplate")
    raidCheckChk:SetSize(24, 24)
    CCRTSkinCheckBox(raidCheckChk)
        local raidCheckLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidCheckLabel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -585)
    raidCheckLabel:SetText("Ready Check :")
    raidCheckLabel:SetTextColor(CCRT_BRAND_R, CCRT_BRAND_G, CCRT_BRAND_B)

    raidCheckChk:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -605)
    raidCheckChk.text = raidCheckChk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    raidCheckChk.text:SetPoint("LEFT", raidCheckChk, "RIGHT", 2, 0)
    raidCheckChk.text:SetText("Afficher le Ready Check lors d'un appel")
    raidCheckChk:SetChecked(AutoPromoteDB.raidCheckEnabled and true or false)
    if raidCheckChk._ccrtRefresh then raidCheckChk:_ccrtRefresh() end
    raidCheckChk:SetScript("OnClick", function(self)
        if self._ccrtRefresh then self:_ccrtRefresh() end
        AutoPromoteDB.raidCheckEnabled = self:GetChecked() and true or false
        if not AutoPromoteDB.raidCheckEnabled and raidCheckFrame then raidCheckFrame:Hide() end
    end)
    mainFrame.raidCheckChk = raidCheckChk

    mainFrame:SetScript("OnShow", function()
        RequestGuildRoster()
        RefreshDiscoveredRanks()
        AutoPromoteUI_RefreshNames()
        AutoPromoteUI_RefreshRanks()
        for key, chk in pairs(mainFrame.loggingCheckboxes) do
            chk:SetChecked(AutoPromoteDB.logging[key] and true or false)
        end
        if mainFrame.raidCheckChk then mainFrame.raidCheckChk:SetChecked(AutoPromoteDB.raidCheckEnabled and true or false)
    if raidCheckChk._ccrtRefresh then raidCheckChk:_ccrtRefresh() end end
    end)
end

function AutoPromoteUI_RefreshNames()
    if not mainFrame then return end
    local sorted = {}
    for name in pairs(AutoPromoteDB.names) do table.insert(sorted, name) end
    table.sort(sorted)

    for idx, name in ipairs(sorted) do
        local row = nameRows[idx]
        if not row then
            row = CreateNameRow(mainFrame.nameChild, idx)
            nameRows[idx] = row
        end
        row.text:SetText(name)
        row.name = name
        row:Show()
    end
    for idx = #sorted + 1, #nameRows do
        nameRows[idx]:Hide()
    end
end

function AutoPromoteUI_RefreshRanks()
    if not mainFrame then return end

    local sortedRanks = {}
    for rankIndex, rankName in pairs(discoveredRanks) do
        table.insert(sortedRanks, { index = rankIndex, name = rankName })
    end
    table.sort(sortedRanks, function(a, b) return a.index < b.index end)

    mainFrame.noGuildText:SetShown(#sortedRanks == 0)

    for idx, info in ipairs(sortedRanks) do
        local row = rankRows[idx]
        if not row then
            row = CreateRankRow(mainFrame.rankChild, idx)
            rankRows[idx] = row
        end
        row.text:SetText(info.name)
        row.rankIndex = info.index
        row.rankName = info.name

        -- Le nom du rang est la clé persistante principale.
        -- L'index reste synchronisé pour la logique de promotion.
        local saved = AutoPromoteDB.rankNames[info.name]
        if saved == nil then
            saved = AutoPromoteDB.ranks[info.index]
            -- Migration automatique des anciennes sauvegardes par index.
            if saved ~= nil then
                AutoPromoteDB.rankNames[info.name] = saved and true or false
            end
        end

        row:SetChecked(saved and true or false)
        AutoPromoteDB.ranks[info.index] = saved and true or false
        if row._ccrtRefresh then row:_ccrtRefresh() end
        row:Show()
    end
    for idx = #sortedRanks + 1, #rankRows do
        rankRows[idx]:Hide()
    end
end

local function ToggleUI()
    InitDB()
    if not mainFrame then BuildUI() end
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
    end
end

--------------------------------------------------
-- Commandes slash
--------------------------------------------------
SLASH_CCRAIDTOOLS1 = "/ccrt"
SLASH_CCRAIDTOOLS2 = "/ccraidtools"
SLASH_CCRAIDTOOLS3 = "/ap" -- compatibilité avec l'ancienne commande

SlashCmdList["CCRAIDTOOLS"] = function(msg)
    InitDB()
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    rest = NormalizeName(rest)

    if cmd == "" then
        ToggleUI()

    elseif cmd == "add" and rest then
        AutoPromoteDB.names[rest] = true
        print("|cff33ff99[CC RaidTools]|r " .. rest .. " ajouté à la liste.")
        if AutoPromoteUI_RefreshNames then AutoPromoteUI_RefreshNames() end

    elseif cmd == "remove" and rest then
        AutoPromoteDB.names[rest] = nil
        print("|cff33ff99[CC RaidTools]|r " .. rest .. " retiré de la liste.")
        if AutoPromoteUI_RefreshNames then AutoPromoteUI_RefreshNames() end

    elseif cmd == "raidcheck" then
        if IsInRaid() then
            BuildRaidCheckFrame()
            raidCheckFrame:Show()
            RefreshRaidCheck()
        else
            print("|cff33ff99[CC RaidTools]|r Tu n'es pas en raid.")
        end

    elseif cmd == "debug" then
        if not IsInRaid() then
            print("|cff33ff99[CC RaidTools]|r Tu n'es pas en raid.")
            return
        end
        print("|cff33ff99[CC RaidTools] debug:|r Leader = " .. tostring(UnitIsGroupLeader("player"))
              .. " | Membres de guilde connus = " .. tostring(GetNumGuildMembers and GetNumGuildMembers() or "?"))
        for i = 1, GetNumGroupMembers() do
            local name, rank = GetRaidRosterInfo(i)
            local shortName = StripRealm(name)
            local guildRankIndex = guildRankByName[shortName]
            local guildRankName = guildRankIndex ~= nil and discoveredRanks[guildRankIndex] or nil
            print(string.format("  %s | rang raid=%s | rang guilde=%s (index %s) | pseudo suivi=%s | rang coché=%s",
                tostring(name), tostring(rank), tostring(guildRankName), tostring(guildRankIndex),
                tostring(AutoPromoteDB.names[name] and true or false),
                tostring(guildRankIndex ~= nil and AutoPromoteDB.ranks[guildRankIndex] and true or false)))
        end
        print("|cff33ff99[CC RaidTools] debug:|r Rangs cochés :")
        for rankIndex in pairs(AutoPromoteDB.ranks) do
            print("  index " .. rankIndex .. " -> " .. tostring(discoveredRanks[rankIndex]))
        end
        print("|cff33ff99[CC RaidTools] debug:|r En combat = " .. tostring(InCombatLockdown() and true or false))
        local pendingCount = 0
        for name in pairs(pendingPromotions) do
            pendingCount = pendingCount + 1
            print("  en attente (fin de combat) : " .. name)
        end
        if pendingCount == 0 then
            print("  aucune promotion en attente")
        end

    elseif cmd == "list" then
        print("|cff33ff99[CC RaidTools]|r Liste des joueurs à promouvoir :")
        local empty = true
        for name in pairs(AutoPromoteDB.names) do
            print("  - " .. name)
            empty = false
        end
        if empty then print("  (aucun)") end

    else
        print("|cff33ff99CC RaidTools|r - Commandes disponibles :")
        print("  /ccrt                 - ouvre la fenêtre de configuration")
        print("  /ccrt add Nom-Royaume - ajoute un joueur")
        print("  /ccrt remove Nom-Royaume - retire un joueur")
        print("  /ccrt list            - affiche la liste en texte")
        print("  /ccrt debug           - diagnostic du raid en cours")
        print("  /ccrt raidcheck       - ouvre le Ready Check manuellement")
        print("  (le logging automatique se configure dans la fenêtre /ccrt)")
    end
end
