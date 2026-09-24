-- CC RaidTools - Quality of Life
-- Small automations that each save a click. Every one has its own toggle,
-- and holding Shift when a prompt appears leaves that prompt to the player.
--
-- Where Blizzard shows a StaticPopup for something (invite, resurrect, duel),
-- we click the popup's own button rather than calling the API and hiding the
-- popup: the popup's handlers then run exactly as for a real click. This
-- matters — hiding PARTY_INVITE without its accept flag set makes its OnHide
-- call DeclineGroup(). All APIs used here were checked against
-- wow-ui-source (live branch); none of them is protected.
local C = CCRT

local db

-- Only the two role check options (the first features of this module) are
-- on by default; everything added after them is opt-in.
local DEFAULTS = {
    autoRoleCheck = true,
    autoRolePoll = true,
    acceptInvites = false,
    acceptResurrect = false,
    fastLoot = false,
    sellJunk = false,
    autoRepair = false,
    repairGuildFunds = false,
    questAccept = false,
    questTurnIn = false,
    declineDuels = false,
    declinePetDuels = false,
    skipCinematics = false,
    hideTalkingHead = false,
    deleteConfirm = false,
}

local function InitDB()
    C.InitDB()
    CCRaidToolsDB.qol = CCRaidToolsDB.qol or {}
    db = CCRaidToolsDB.qol
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end
end

local function Print(fmt, ...)
    print(string.format(fmt, ...))
end

-- Values coming from events can be secret in restricted content; any API
-- whose arguments are "AllowedWhenUntainted" errors on them from addon code.
local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

-- Clicks button `index` (1 = accept, 2 = decline) of the visible StaticPopup
-- `which`, if there is one and that button is enabled. Returns true if clicked.
local function ClickPopup(which, index)
    local dialog = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
    if not dialog then
        return false
    end
    local button = index == 1 and dialog:GetButton1() or dialog:GetButton2()
    if not button or not button:IsEnabled() then
        return false
    end
    button:Click()
    return true
end

-- Friend check by character name ("Name" or "Name-Realm"), covering both
-- the character friend list and Battle.net friends. Returns nil when the
-- name can't be read, so callers can leave the prompt alone.
local function IsFriendName(name)
    if not name or IsSecret(name) then
        return nil
    end
    local short = name:match("^[^-]+") or name
    if C_FriendList.GetFriendInfo(name) or C_FriendList.GetFriendInfo(short) then
        return true
    end
    for i = 1, (BNGetNumFriends() or 0) do
        local account = C_BattleNet.GetFriendAccountInfo(i)
        local game = account and account.gameAccountInfo
        if game and game.characterName and (game.characterName == short or game.characterName == name) then
            return true
        end
    end
    return false
end

local function RoleList(tank, healer, dps)
    local roles = {}
    if tank then table.insert(roles, TANK or "Tank") end
    if healer then table.insert(roles, HEALER or "Healer") end
    if dps then table.insert(roles, DAMAGER or "DPS") end
    if #roles == 0 then
        return C.L.qolRoleNone
    end
    return table.concat(roles, ", ")
end

-- ===== Queue role check =====
-- When the group leader queues the group (dungeon finder, battleground, or a
-- premade group application), every member gets LFDRoleCheckPopup. Clicking
-- its Accept button lets Blizzard's LFDRoleCheckPopupAccept_OnClick submit
-- the roles already ticked (SetLFGRoles/SetPVPRoles + CompleteLFGRoleCheck).
-- With no valid role ticked the button is disabled and the popup stays up.
-- Applying to a premade group yourself is C_LFGList.ApplyToGroup, which IS
-- protected, so that dialog is deliberately left alone.

local function TryAcceptRoleCheck()
    local popup = LFDRoleCheckPopup
    local accept = LFDRoleCheckPopupAcceptButton
    if not db.autoRoleCheck or IsShiftKeyDown() then
        return
    end
    if not popup or not popup:IsShown() or not accept or not accept:IsEnabled() then
        return
    end
    local tank, healer, dps
    if LFDRoleCheckPopup_GetRolesChecked then
        tank, healer, dps = LFDRoleCheckPopup_GetRolesChecked()
    end
    accept:Click()
    Print(C.L.qolRoleCheckDone, RoleList(tank, healer, dps))
end

-- ===== Leader role poll =====
-- RolePollPopup comes pre-ticked with the player's assigned role; its Accept
-- calls UnitSetRoleEnum("player", role). No role assigned → button disabled.

local function TryAcceptRolePoll()
    local popup = RolePollPopup
    local accept = popup and popup.acceptButton
    if not db.autoRolePoll or IsShiftKeyDown() then
        return
    end
    if not popup:IsShown() or not accept or not accept:IsEnabled() then
        return
    end
    accept:Click()
end

-- ===== Group invites from friends / guild =====
-- PARTY_INVITE_REQUEST: name, tank, healer, damage, isXRealm,
-- allowMultipleRoles, inviterGUID, isQuestSessionActive. Invites that ask
-- for a role (LFGInvitePopup) or come during a quest session use other
-- dialogs and are left to the player, as are invites that would drop the
-- player out of a queue.

local function OnPartyInvite(name, tank, healer, damage, _, _, inviterGUID, isQuestSessionActive)
    if not db.acceptInvites or IsShiftKeyDown() or IsInGroup() then
        return
    end
    if tank or healer or damage or isQuestSessionActive then
        return
    end
    if not inviterGUID or IsSecret(inviterGUID) then
        return
    end
    if WillAcceptInviteRemoveQueues and WillAcceptInviteRemoveQueues() then
        return
    end
    local trusted = C_BattleNet.GetGameAccountInfoByGUID(inviterGUID)
        or C_FriendList.IsFriend(inviterGUID)
        or IsGuildMember(inviterGUID)
    if not trusted then
        return
    end
    -- Blizzard shows the popup from its own handler for this same event;
    -- wait a frame so it exists.
    C_Timer.After(0, function()
        if ClickPopup("PARTY_INVITE", 1) and name and not IsSecret(name) then
            Print(C.L.qolInviteAccepted, name)
        end
    end)
end

-- ===== Resurrection out of combat =====
-- A dead player is never "in combat" themselves, so InCombatLockdown can't
-- tell a mid-fight battle rez from a safe one. The fight counts as live if we
-- saw the player enter combat and not leave it, if an encounter is running,
-- or if the caster is still in combat (dungeon trash). An unreadable caster
-- counts as live. Live fight → the popup is left to the player.
-- RESURRECT can start with its Accept disabled (corpse recovery delay), so
-- we retry for a little while.

local inCombat = false
local RESURRECT_POPUPS = { "RESURRECT", "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER" }

local function FightIsLive(caster)
    if inCombat or (IsEncounterInProgress and IsEncounterInProgress()) then
        return true
    end
    if caster then
        if IsSecret(caster) then
            return true
        end
        if UnitExists(caster) and UnitAffectingCombat(caster) then
            return true
        end
    end
    return false
end

local function TryAcceptResurrect(caster, attemptsLeft)
    if not db.acceptResurrect or IsShiftKeyDown() or FightIsLive(caster) then
        return
    end
    for _, which in ipairs(RESURRECT_POPUPS) do
        if StaticPopup_FindVisible(which) then
            if not ClickPopup(which, 1) and attemptsLeft > 0 then
                C_Timer.After(1, function() TryAcceptResurrect(caster, attemptsLeft - 1) end)
            end
            return
        end
    end
end

-- ===== Fast loot =====
-- Takes every slot as soon as the loot is ready instead of waiting for the
-- loot window. Only when autoloot applies to this loot (the autoloot CVar
-- XOR the autoloot modifier key — Blizzard's rule), never for fishing.

local lastFastLoot = 0

local function OnLootReady()
    if not db.fastLoot then
        return
    end
    local now = GetTime()
    if now - lastFastLoot < 0.3 then
        return
    end
    lastFastLoot = now
    if IsFishingLoot and IsFishingLoot() then
        return
    end
    if C_CVar.GetCVarBool("autoLootDefault") == IsModifiedClick("AUTOLOOTTOGGLE") then
        return
    end
    for i = GetNumLootItems(), 1, -1 do
        LootSlot(i)
    end
end

-- ===== Merchant: sell junk, repair =====
-- The repair cost can be a secret value in restricted content; it is only
-- read (for the chat line and the guild-funds fallback) when it isn't.

local function MoneyText(copper)
    if not copper or IsSecret(copper) then
        return nil
    end
    return GetCoinTextureString and GetCoinTextureString(copper) or tostring(copper)
end

local function OnMerchantShow()
    if IsShiftKeyDown() then
        return
    end

    if db.sellJunk and C_MerchantFrame and C_MerchantFrame.IsSellAllJunkEnabled
        and C_MerchantFrame.IsSellAllJunkEnabled() then
        local count = C_MerchantFrame.GetNumJunkItems()
        if count and count > 0 then
            C_MerchantFrame.SellAllJunkItems()
            Print(C.L.qolJunkSold, count)
        end
    end

    if db.autoRepair and CanMerchantRepair() then
        local cost, canRepair = GetRepairAllCost()
        if not canRepair or (not IsSecret(cost) and cost == 0) then
            return
        end
        local costText = MoneyText(cost)
        if db.repairGuildFunds and CanGuildBankRepair and CanGuildBankRepair() then
            RepairAllItems(true)
            Print(C.L.qolRepairedGuild, costText or "?")
            -- If the guild's daily allowance didn't cover everything, pay
            -- the rest from the player's own money.
            C_Timer.After(0.6, function()
                if not (MerchantFrame and MerchantFrame:IsShown()) then
                    return
                end
                local remaining = GetRepairAllCost()
                if not IsSecret(remaining) and remaining and remaining > 0 then
                    RepairAllItems(false)
                    Print(C.L.qolRepairedRest, MoneyText(remaining) or "?")
                end
            end)
        else
            RepairAllItems(false)
            Print(C.L.qolRepaired, costText or "?")
        end
    end
end

-- ===== Quests: accept, turn in =====
-- Turn-ins go first, then new quests. Trivial (grey) and ignored quests are
-- skipped, and so is anything asking the player to choose between several
-- rewards or to pay money: those need the player. PvP-flagged quests need a
-- confirmation popup and are left alone too.

local function OnGossipShow()
    if IsShiftKeyDown() then
        return
    end
    if db.questTurnIn then
        for _, quest in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if quest.isComplete and quest.questID then
                C_GossipInfo.SelectActiveQuest(quest.questID)
                return
            end
        end
    end
    if db.questAccept then
        for _, quest in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
            if quest.questID and not quest.isTrivial and not quest.isIgnored then
                C_GossipInfo.SelectAvailableQuest(quest.questID)
                return
            end
        end
    end
end

-- Greeting panels (e.g. some trainers) use the index-based globals.
local function OnQuestGreeting()
    if IsShiftKeyDown() then
        return
    end
    if db.questTurnIn then
        for i = 1, GetNumActiveQuests() do
            local _, isComplete = GetActiveTitle(i)
            if isComplete then
                SelectActiveQuest(i)
                return
            end
        end
    end
    if db.questAccept then
        for i = 1, GetNumAvailableQuests() do
            local isTrivial = GetAvailableQuestInfo and GetAvailableQuestInfo(i)
            if not isTrivial then
                SelectAvailableQuest(i)
                return
            end
        end
    end
end

local function OnQuestDetail()
    if not db.questAccept or IsShiftKeyDown() then
        return
    end
    if QuestFlagsPVP and QuestFlagsPVP() then
        return
    end
    -- Same branch as Blizzard's QuestDetailAcceptButton_OnClick.
    if QuestGetAutoAccept() then
        AcknowledgeAutoAcceptQuest()
    else
        AcceptQuest()
    end
end

local function OnQuestProgress()
    if db.questTurnIn and not IsShiftKeyDown() and IsQuestCompletable() then
        CompleteQuest()
    end
end

local function OnQuestComplete()
    if not db.questTurnIn or IsShiftKeyDown() then
        return
    end
    local choices = GetNumQuestChoices()
    if choices > 1 then
        return
    end
    local money = GetQuestMoneyToGet and GetQuestMoneyToGet()
    if money and money > 0 then
        return
    end
    -- Blizzard passes 0 with no reward choice and 1 with a single one.
    GetQuestReward(choices)
end

-- ===== Duels and pet battle duels =====
-- Declined through the popup's own Decline button, unless the challenger is
-- a friend. An unreadable name leaves the popup to the player.

local function OnDuelRequested(which, option, challenger)
    if not db[option] or IsShiftKeyDown() then
        return
    end
    if IsFriendName(challenger) ~= false then
        return
    end
    C_Timer.After(0, function()
        if ClickPopup(which, 2) then
            Print(C.L.qolDuelDeclined, challenger)
        end
    end)
end

-- ===== Cinematics and movies =====
-- Same decision as Blizzard's own cancel path, minus its last-resort
-- VehicleExit(): a real cinematic is stopped, a scripted scene is cancelled
-- only if the client says it can be, anything else plays. Pre-rendered movies
-- are finished through MovieFrame:FinishMovie, what its own "skip" confirm
-- button calls.

local function OnCinematicStart(canBeCancelled)
    if not db.skipCinematics or IsShiftKeyDown() then
        return
    end
    if canBeCancelled then
        StopCinematic()
    elseif CanCancelScene and CanCancelScene() then
        CancelScene()
    end
end

local function OnPlayMovie()
    if not db.skipCinematics or IsShiftKeyDown() then
        return
    end
    C_Timer.After(0, function()
        if MovieFrame and MovieFrame:IsShown() and MovieFrame.FinishMovie then
            MovieFrame:FinishMovie()
        end
    end)
end

-- ===== Delete confirmation =====
-- DELETE_GOOD_ITEM / DELETE_GOOD_QUEST_ITEM (rare quality and above) make
-- the player type a word before "Yes" unlocks. We type the client's own
-- localized word (DELETE_ITEM_CONFIRM_STRING) into the box; the dialog's
-- own text handler then enables "Yes", which the player still has to click.

local DELETE_POPUPS = { DELETE_GOOD_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }

local function OnDeleteItemConfirm()
    if not db.deleteConfirm or not DELETE_ITEM_CONFIRM_STRING then
        return
    end
    C_Timer.After(0, function()
        StaticPopup_ForEachShownDialog(function(dialog)
            if DELETE_POPUPS[dialog.which] and dialog.GetEditBox then
                dialog:GetEditBox():SetText(DELETE_ITEM_CONFIRM_STRING)
            end
        end)
    end)
end

-- ===== Hooks and events =====
-- Hook state lives in locals, never as fields on Blizzard's frames.

local roleCheckHooked, rolePollHooked, talkingHeadHooked = false, false, false

-- Blizzard fills the role popups right before showing them; waiting a frame
-- after OnShow reads their final state.
local function HookFrames()
    if LFDRoleCheckPopup and not roleCheckHooked then
        roleCheckHooked = true
        LFDRoleCheckPopup:HookScript("OnShow", function()
            C_Timer.After(0, TryAcceptRoleCheck)
        end)
    end
    if RolePollPopup and not rolePollHooked then
        rolePollHooked = true
        RolePollPopup:HookScript("OnShow", function()
            C_Timer.After(0, TryAcceptRolePoll)
        end)
    end
    -- The talking head is hidden once it starts playing; its voice line
    -- still plays.
    if TalkingHeadFrame and TalkingHeadFrame.PlayCurrent and not talkingHeadHooked then
        talkingHeadHooked = true
        hooksecurefunc(TalkingHeadFrame, "PlayCurrent", function(frame)
            if db.hideTalkingHead then
                frame:Hide()
            end
        end)
    end
end

local handlers = {
    PARTY_INVITE_REQUEST = OnPartyInvite,
    RESURRECT_REQUEST = function(caster)
        C_Timer.After(0, function() TryAcceptResurrect(caster, 10) end)
    end,
    PLAYER_REGEN_DISABLED = function() inCombat = true end,
    PLAYER_REGEN_ENABLED = function() inCombat = false end,
    LOOT_READY = OnLootReady,
    MERCHANT_SHOW = OnMerchantShow,
    GOSSIP_SHOW = OnGossipShow,
    QUEST_GREETING = OnQuestGreeting,
    QUEST_DETAIL = OnQuestDetail,
    QUEST_PROGRESS = OnQuestProgress,
    QUEST_COMPLETE = OnQuestComplete,
    DUEL_REQUESTED = function(challenger)
        OnDuelRequested("DUEL_REQUESTED", "declineDuels", challenger)
    end,
    PET_BATTLE_PVP_DUEL_REQUESTED = function(challenger)
        OnDuelRequested("PET_BATTLE_PVP_DUEL_REQUESTED", "declinePetDuels", challenger)
    end,
    CINEMATIC_START = OnCinematicStart,
    PLAY_MOVIE = OnPlayMovie,
    DELETE_ITEM_CONFIRM = OnDeleteItemConfirm,
}

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
for event in pairs(handlers) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, ...)
    InitDB()
    if event == "PLAYER_LOGIN" then
        HookFrames()
    elseif event == "ADDON_LOADED" then
        -- LFDRoleCheckPopup lives in Blizzard_GroupFinder; hook it whenever
        -- that shows up, in case it ever becomes load-on-demand.
        local addonName = ...
        if addonName == "Blizzard_GroupFinder" then
            HookFrames()
        end
    else
        handlers[event](...)
    end
end)

-- ===== Settings UI =====

-- Layout: sections with a small header, one toggle per line.
local SECTIONS = {
    { title = "qolSectionGroup", toggles = {
        { key = "autoRoleCheck", label = "qolRoleCheckLabel" },
        { key = "autoRolePoll", label = "qolRolePollLabel" },
        { key = "acceptInvites", label = "qolInvitesLabel" },
        { key = "acceptResurrect", label = "qolResurrectLabel" },
    } },
    { title = "qolSectionLoot", toggles = {
        { key = "fastLoot", label = "qolFastLootLabel" },
        { key = "sellJunk", label = "qolSellJunkLabel" },
        { key = "autoRepair", label = "qolRepairLabel" },
        { key = "repairGuildFunds", label = "qolRepairGuildLabel", indent = true },
    } },
    { title = "qolSectionQuests", toggles = {
        { key = "questAccept", label = "qolQuestAcceptLabel" },
        { key = "questTurnIn", label = "qolQuestTurnInLabel" },
    } },
    { title = "qolSectionMisc", toggles = {
        { key = "declineDuels", label = "qolDuelsLabel" },
        { key = "declinePetDuels", label = "qolPetDuelsLabel" },
        { key = "skipCinematics", label = "qolCinematicsLabel" },
        { key = "hideTalkingHead", label = "qolTalkingHeadLabel" },
        { key = "deleteConfirm", label = "qolDeleteLabel" },
    } },
}

local ROW_H = 28

local function BuildUI(panel)
    InitDB()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
    title:SetText(C.L.qolLabel)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    panel.toggles = {}
    local y = -30
    for _, section in ipairs(SECTIONS) do
        local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, y - 4)
        header:SetText(C.L[section.title])
        header:SetTextColor(0.85, 0.75, 0.45)
        y = y - 20
        for _, toggle in ipairs(section.toggles) do
            local check = CreateFrame("CheckButton", nil, panel, "BackdropTemplate")
            check:SetPoint("TOPLEFT", panel, "TOPLEFT", toggle.indent and 34 or 10, y)
            C.SkinCheckBox(check)
            local label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetPoint("LEFT", check, "RIGHT", 7, 0)
            -- Stop short of the 100px header icon in the top-right corner
            -- (ModuleIcons.lua); a long label wraps instead of running under it.
            label:SetPoint("RIGHT", panel, "RIGHT", -110, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(true)
            label:SetText(C.L[toggle.label])
            check:SetScript("OnClick", function(self)
                db[toggle.key] = self:GetChecked() and true or false
            end)
            check._ccrtKey = toggle.key
            table.insert(panel.toggles, check)
            y = y - ROW_H
        end
        y = y - 6
    end

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, y - 4)
    hint:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(C.L.qolHint)
    hint:SetTextColor(0.7, 0.7, 0.7)
end

local function RefreshUI(panel)
    InitDB()
    if not panel or not panel.toggles then
        return
    end
    for _, check in ipairs(panel.toggles) do
        check:SetChecked(db[check._ccrtKey])
        if check._ccrtRefresh then
            check:_ccrtRefresh()
        end
    end
end

C.RegisterModule("QualityOfLife", BuildUI, RefreshUI)
