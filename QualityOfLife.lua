-- CC RaidTools - Quality of Life
-- Small automations that each save a click. Every one has its own toggle,
-- and holding Shift when the prompt appears always leaves that prompt to the
-- player.
local C = CCRT

local db

local function InitDB()
    C.InitDB()
    CCRaidToolsDB.qol = CCRaidToolsDB.qol or {}
    db = CCRaidToolsDB.qol
    if db.autoRoleCheck == nil then
        db.autoRoleCheck = true
    end
    if db.autoRolePoll == nil then
        db.autoRolePoll = true
    end
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
-- premade group application), every member gets LFDRoleCheckPopup. We click
-- its Accept button, so Blizzard's own LFDRoleCheckPopupAccept_OnClick
-- submits whatever roles are already ticked (the player's last used ones)
-- through SetLFGRoles/SetPVPRoles + CompleteLFGRoleCheck(true) — none of
-- them protected (checked against wow-ui-source, live branch). When no valid
-- role is ticked Blizzard keeps the button disabled and Click() does nothing,
-- so the popup simply stays up for the player.
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
    print(string.format(C.L.qolRoleCheckDone, RoleList(tank, healer, dps)))
end

-- ===== Leader role poll =====
-- The "Role check" a group/raid leader starts from the raid panel shows
-- RolePollPopup, pre-ticked with the player's currently assigned role. Its
-- Accept (RolePollPopupAccept_OnClick) calls UnitSetRoleEnum("player", role),
-- restricted only for secret arguments, which a plain "player" isn't. With no
-- role assigned yet the button is disabled and the popup stays up.

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

-- Blizzard fills each popup (ticked roles, Accept enabled state) right
-- before showing it; waiting one frame after OnShow makes sure we read the
-- final state rather than racing its own OnShow update.
-- Hook state is kept in locals rather than as fields on Blizzard's frames,
-- so nothing of ours is written onto them.
local roleCheckHooked, rolePollHooked = false, false

local function HookPopups()
    if LFDRoleCheckPopup and not roleCheckHooked then
        roleCheckHooked = true
        LFDRoleCheckPopup:HookScript("OnShow", function()
            InitDB()
            C_Timer.After(0, TryAcceptRoleCheck)
        end)
    end
    if RolePollPopup and not rolePollHooked then
        rolePollHooked = true
        RolePollPopup:HookScript("OnShow", function()
            InitDB()
            C_Timer.After(0, TryAcceptRolePoll)
        end)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, addonName)
    -- LFDRoleCheckPopup lives in Blizzard_GroupFinder; hook it whenever that
    -- shows up, in case a client version ever makes it load on demand.
    if event == "PLAYER_LOGIN" or addonName == "Blizzard_GroupFinder" then
        InitDB()
        HookPopups()
    end
end)

-- ===== Settings UI =====

local function AddToggle(panel, anchor, labelText, key)
    local check = CreateFrame("CheckButton", nil, panel, "BackdropTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, anchor._ccrtIsTitle and -12 or -34)
    C.SkinCheckBox(check)
    local label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", check, "RIGHT", 7, 0)
    label:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(true)
    label:SetText(labelText)
    check:SetScript("OnClick", function(self)
        db[key] = self:GetChecked() and true or false
    end)
    check._ccrtKey = key
    return check
end

local function BuildUI(panel)
    InitDB()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
    title:SetText(C.L.qolLabel)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
    title._ccrtIsTitle = true

    local roleCheck = AddToggle(panel, title, C.L.qolRoleCheckLabel, "autoRoleCheck")
    local rolePoll = AddToggle(panel, roleCheck, C.L.qolRolePollLabel, "autoRolePoll")

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", rolePoll, "BOTTOMLEFT", 0, -20)
    hint:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(C.L.qolHint)
    hint:SetTextColor(0.7, 0.7, 0.7)

    panel.toggles = { roleCheck, rolePoll }
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
