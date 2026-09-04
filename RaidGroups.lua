-- CC RaidTools - Raid Groups
-- Organise le raid en 8 groupes : glisser-déposer, tri automatique par rôle,
-- presets de composition sauvegardés, et application réelle en jeu (leader/assist).
local C = CCRT

local NUM_GROUPS = 8
local NUM_SLOTS = 5
local TOKEN_W, TOKEN_H = 108, 20
local SHARE_PREFIX = "CCRT_RG"
local SHARE_CHUNK_SIZE = 200
local EXPORT_TAG = "CCRTRG1:"

local frame
local groupHeaders = {}
local slotFrames = {} -- slotFrames[g][s]
local poolTokens = {} -- reusable pool token pool
local poolContainer
local presetFlyout
local presetEdit
local countText
local applyButton
local presetsArrowTex
local exportFrame
local importFrame
local sortSettingsFrame

-- Working assignment table, mirrored into CCRaidToolsDB.raidGroups.current
-- assign[strippedName] = groupNumber (1-8)
local assign = {}
local classByName = {}
local rosterSet = {}
local incomingShares = {} -- ["sender#msgId"] = { total, chunks, count }
local shareSeq = 0
local currentPresetName -- name of the last preset loaded/saved, used as a hint when sharing

local dragGhost
local dragging -- { member = name, fromGroup = number|nil }

local function EnsureDB()
    C.InitDB()
    CCRaidToolsDB.raidGroups = CCRaidToolsDB.raidGroups or {}
    CCRaidToolsDB.raidGroups.presets = CCRaidToolsDB.raidGroups.presets or {}
    CCRaidToolsDB.raidGroups.current = CCRaidToolsDB.raidGroups.current or {}
    local s = CCRaidToolsDB.raidGroups.sortSettings
    if not s then
        s = { groups = {}, parts = 2, rule = "consecutive" }
        CCRaidToolsDB.raidGroups.sortSettings = s
    end
    s.groups = s.groups or {}
    for g = 1, NUM_GROUPS do
        if s.groups[g] == nil then
            s.groups[g] = true
        end
    end
    if not s.parts or s.parts < 2 or s.parts > NUM_GROUPS then
        s.parts = 2
    end
    if s.rule ~= "consecutive" and s.rule ~= "alternating" then
        s.rule = "consecutive"
    end
end

local function SaveCurrent()
    EnsureDB()
    wipe(CCRaidToolsDB.raidGroups.current)
    for name, g in pairs(assign) do
        CCRaidToolsDB.raidGroups.current[name] = g
    end
end

local function LoadCurrent()
    EnsureDB()
    wipe(assign)
    for name, g in pairs(CCRaidToolsDB.raidGroups.current) do
        assign[name] = g
    end
end

-- ===== Serialization (used by both in-game share and export/import text) =====

local function SerializeAssign(tbl)
    local parts = {}
    for name, g in pairs(tbl) do
        if name and name ~= "" and tonumber(g) then
            parts[#parts + 1] = name .. "=" .. tonumber(g)
        end
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

local function DeserializeAssign(str)
    local result = {}
    for pair in string.gmatch(str or "", "([^,]+)") do
        local name, g = pair:match("^(.-)=(%d+)$")
        g = tonumber(g)
        if name and name ~= "" and g and g >= 1 and g <= NUM_GROUPS then
            result[name] = g
        end
    end
    return result
end

local function SavePresetNamed(baseName, tbl)
    EnsureDB()
    local presets = CCRaidToolsDB.raidGroups.presets
    local name = baseName
    local i = 2
    while presets[name] do
        name = baseName .. " (" .. i .. ")"
        i = i + 1
    end
    local copy = {}
    for n, g in pairs(tbl) do
        copy[n] = g
    end
    presets[name] = copy
    return name
end

-- ===== Roster helpers =====

local function GetRosterUnits()
    local units = {}
    if IsInRaid() then
        local count = GetNumGroupMembers() or 0
        for i = 1, count do
            units[#units + 1] = "raid" .. i
        end
    elseif IsInGroup() then
        units[#units + 1] = "player"
        for i = 1, 4 do
            if UnitExists("party" .. i) then
                units[#units + 1] = "party" .. i
            end
        end
    else
        units[#units + 1] = "player"
    end
    return units
end

local function RefreshRoster()
    wipe(rosterSet)
    wipe(classByName)
    for _, unit in ipairs(GetRosterUnits()) do
        if UnitExists(unit) then
            local name = UnitName(unit)
            if name then
                local short = C.StripRealm(name)
                rosterSet[short] = true
                local _, class = UnitClass(unit)
                classByName[short] = class
            end
        end
    end
end

local function ClassColor(name)
    local class = classByName[name]
    local col = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if col then
        return col.r, col.g, col.b
    end
    return 1, 1, 1
end

-- ===== Drag & drop =====

local function EnsureGhost()
    if dragGhost then
        return dragGhost
    end
    dragGhost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dragGhost:SetSize(TOKEN_W, TOKEN_H)
    dragGhost:SetFrameStrata("TOOLTIP")
    C.ApplyPanelSkin(dragGhost)
    dragGhost:SetBackdropColor(C.BRAND_R * 0.35, C.BRAND_G * 0.35, C.BRAND_B * 0.35, 0.9)
    dragGhost.text = dragGhost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dragGhost.text:SetPoint("CENTER")
    dragGhost:Hide()
    dragGhost:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        if scale == 0 then return end
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end)
    return dragGhost
end

local Refresh -- forward declaration

local function FindDropTarget()
    for g = 1, NUM_GROUPS do
        for s = 1, NUM_SLOTS do
            local slot = slotFrames[g] and slotFrames[g][s]
            if slot and slot:IsShown() and slot:IsMouseOver() then
                return slot
            end
        end
    end
    if poolContainer and poolContainer:IsShown() and poolContainer:IsMouseOver() then
        return "pool"
    end
    return nil
end

local function ApplyDrop(member, fromGroup, target)
    if target == "pool" then
        assign[member] = nil
    elseif type(target) == "table" then
        local targetGroup = target.group
        local targetMember = target.member
        if targetMember == member then
            return
        end
        assign[member] = targetGroup
        if targetMember then
            assign[targetMember] = fromGroup
        end
    else
        return
    end
    SaveCurrent()
    Refresh()
end

local function StartDrag(member, fromGroup)
    dragging = { member = member, fromGroup = fromGroup }
    local g = EnsureGhost()
    local r, gg, b = ClassColor(member)
    g.text:SetText(member)
    g.text:SetTextColor(r, gg, b)
    g:Show()
end

local function EndDrag()
    if dragGhost then
        dragGhost:Hide()
    end
    if not dragging then
        return
    end
    local target = FindDropTarget()
    local d = dragging
    dragging = nil
    if target then
        ApplyDrop(d.member, d.fromGroup, target)
    end
end

local function MakeDraggableSlot(btn)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if self.member then
            StartDrag(self.member, self.group)
        end
    end)
    btn:SetScript("OnDragStop", EndDrag)
end

local function MakeDraggablePoolToken(btn)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if self.member then
            StartDrag(self.member, nil)
        end
    end)
    btn:SetScript("OnDragStop", EndDrag)
end

-- ===== UI building =====

local function NewSlotFrame(parent, g, s, x, y)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(TOKEN_W, TOKEN_H)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    btn:SetBackdropColor(0.03, 0.03, 0.04, 0.85)
    btn:SetBackdropBorderColor(0, 0, 0, 1)
    btn.group = g
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("CENTER")
    btn.text:SetText("-")
    btn:EnableMouse(true)
    MakeDraggableSlot(btn)
    return btn
end

local function NewGroupColumn(panel, g, x, y)
    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    header:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
    groupHeaders[g] = header
    slotFrames[g] = {}
    for s = 1, NUM_SLOTS do
        slotFrames[g][s] = NewSlotFrame(panel, g, s, x, y - 14 - (s - 1) * (TOKEN_H + 2))
    end
end

local function AcquirePoolToken(i)
    local t = poolTokens[i]
    if t then
        return t
    end
    t = CreateFrame("Button", nil, poolContainer, "BackdropTemplate")
    t:SetSize(TOKEN_W, TOKEN_H)
    t:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    t:SetBackdropColor(0.06, 0.06, 0.08, 0.9)
    t:SetBackdropBorderColor(0, 0, 0, 1)
    t.text = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.text:SetPoint("CENTER")
    t:EnableMouse(true)
    MakeDraggablePoolToken(t)
    poolTokens[i] = t
    return t
end

local function ClosePresetFlyout()
    if presetFlyout then
        presetFlyout:Hide()
    end
    if presetsArrowTex then
        presetsArrowTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    end
end

local function BuildPresetFlyout(panel)
    presetFlyout = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    presetFlyout:SetSize(190, 150)
    C.ApplyPanelSkin(presetFlyout)
    presetFlyout:SetFrameStrata("DIALOG")
    presetFlyout:Hide()
    presetFlyout.rows = {}
end

local function RefreshPresetFlyout()
    if not presetFlyout then
        return
    end
    EnsureDB()
    for _, row in ipairs(presetFlyout.rows) do
        row:Hide()
    end
    local names = {}
    for name in pairs(CCRaidToolsDB.raidGroups.presets) do
        names[#names + 1] = name
    end
    table.sort(names)
    local h = math.max(30, #names * 22 + 10)
    presetFlyout:SetHeight(math.min(h, 220))
    for i, name in ipairs(names) do
        local row = presetFlyout.rows[i]
        if not row then
            row = CreateFrame("Button", nil, presetFlyout)
            row:SetSize(170, 20)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", 4, 0)
            row.label:SetJustifyH("LEFT")
            row.label:SetWidth(130)
            row.del = CreateFrame("Button", nil, row)
            row.del:SetSize(16, 16)
            row.del:SetPoint("RIGHT", -2, 0)
            row.delText = row.del:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.delText:SetPoint("CENTER")
            row.delText:SetText("x")
            row.delText:SetTextColor(1, 0.35, 0.35)
            presetFlyout.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", presetFlyout, "TOPLEFT", 5, -5 - (i - 1) * 22)
        row.label:SetText(name)
        row.label:SetTextColor(0.9, 0.9, 0.9)
        row:SetScript("OnClick", function()
            local p = CCRaidToolsDB.raidGroups.presets[name]
            if p then
                wipe(assign)
                for n, g in pairs(p) do
                    assign[n] = g
                end
                currentPresetName = name
                SaveCurrent()
                Refresh()
                print(string.format(C.L.rgLoaded, name))
            end
            ClosePresetFlyout()
        end)
        row.del:SetScript("OnClick", function()
            CCRaidToolsDB.raidGroups.presets[name] = nil
            RefreshPresetFlyout()
        end)
        row:Show()
    end
end

local function SavePreset()
    local name = presetEdit and presetEdit:GetText()
    name = name and name:gsub("^%s+", ""):gsub("%s+$", "")
    if not name or name == "" then
        return
    end
    EnsureDB()
    local copy = {}
    for n, g in pairs(assign) do
        copy[n] = g
    end
    CCRaidToolsDB.raidGroups.presets[name] = copy
    currentPresetName = name
    presetEdit:SetText("")
    presetEdit:ClearFocus()
    print(string.format(C.L.rgSaved, name))
end

-- ===== Auto sort =====
-- Configurable split: which groups the sort is allowed
-- to touch, how many parts to split them into, and whether those parts are
-- consecutive blocks (1,2,3 vs 4,5,6) or interleaved (1,3,5 vs 2,4,6).
-- Anyone currently sitting in a group excluded from the sort keeps their
-- spot untouched and isn't pulled into the reshuffle.
local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }

-- Splits an ordered list of groups into `parts` buckets following `rule`.
local function BuildSortPartition(groups, parts, rule)
    local result = {}
    for p = 1, parts do
        result[p] = {}
    end
    if rule == "alternating" then
        for i, g in ipairs(groups) do
            local p = ((i - 1) % parts) + 1
            table.insert(result[p], g)
        end
    else
        local len = #groups
        local base = math.floor(len / parts)
        local remainder = len % parts
        local idx = 1
        for p = 1, parts do
            local size = base + (p <= remainder and 1 or 0)
            for _ = 1, size do
                if groups[idx] then
                    table.insert(result[p], groups[idx])
                    idx = idx + 1
                end
            end
        end
    end
    return result
end

-- ===== Auto sort settings popup =====

local function RefreshSortSettingsFrame()
    local f = sortSettingsFrame
    if not f then
        return
    end
    EnsureDB()
    local s = CCRaidToolsDB.raidGroups.sortSettings
    for g = 1, NUM_GROUPS do
        local chip = f.groupChips[g]
        if s.groups[g] then
            chip:SetBackdropColor(C.BRAND_R * 0.55, C.BRAND_G * 0.55, C.BRAND_B * 0.55, 0.95)
            chip.text:SetTextColor(1, 1, 1)
        else
            chip:SetBackdropColor(0.05, 0.05, 0.06, 0.9)
            chip.text:SetTextColor(0.5, 0.5, 0.5)
        end
    end
    for n, chip in pairs(f.partChips) do
        if s.parts == n then
            chip:SetBackdropColor(C.BRAND_R * 0.55, C.BRAND_G * 0.55, C.BRAND_B * 0.55, 0.95)
            chip.text:SetTextColor(1, 1, 1)
        else
            chip:SetBackdropColor(0.05, 0.05, 0.06, 0.9)
            chip.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
    local function HighlightRuleBtn(btn, active)
        if not btn then
            return
        end
        if active then
            btn:SetBackdropColor(C.BRAND_R * 0.55, C.BRAND_G * 0.55, C.BRAND_B * 0.55, 0.95)
            btn.text:SetTextColor(1, 1, 1)
        else
            btn:SetBackdropColor(0.05, 0.05, 0.06, 0.9)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
    HighlightRuleBtn(f.ruleConsecBtn, s.rule == "consecutive")
    HighlightRuleBtn(f.ruleAltBtn, s.rule == "alternating")
end

local function EnsureSortSettingsFrame(panel)
    if sortSettingsFrame then
        return sortSettingsFrame
    end
    local f = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    f:SetSize(300, 268)
    f:SetPoint("CENTER", panel, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    C.ApplyPanelSkin(f)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText(C.L.rgSortSettingsTitle)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    local function NewChip(parent)
        local chip = CreateFrame("Button", nil, parent, "BackdropTemplate")
        chip:SetSize(28, 22)
        chip:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        chip:SetBackdropBorderColor(0, 0, 0, 1)
        chip.text = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        chip.text:SetPoint("CENTER")
        return chip
    end

    -- Groups concerned by the sort
    local groupsLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    groupsLabel:SetPoint("TOPLEFT", 10, -32)
    groupsLabel:SetText(C.L.rgSortGroupsLabel)
    groupsLabel:SetTextColor(0.8, 0.8, 0.8)

    f.groupChips = {}
    for g = 1, NUM_GROUPS do
        local chip = NewChip(f)
        chip.text:SetText(tostring(g))
        local col = (g - 1) % 4
        local row = math.floor((g - 1) / 4)
        chip:SetPoint("TOPLEFT", groupsLabel, "BOTTOMLEFT", col * 34, -6 - row * 26)
        chip:SetScript("OnClick", function()
            EnsureDB()
            local s = CCRaidToolsDB.raidGroups.sortSettings
            s.groups[g] = not s.groups[g]
            RefreshSortSettingsFrame()
        end)
        f.groupChips[g] = chip
    end

    -- Number of parts
    local partsLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    partsLabel:SetPoint("TOPLEFT", groupsLabel, "BOTTOMLEFT", 0, -66)
    partsLabel:SetText(C.L.rgSortPartsLabel)
    partsLabel:SetTextColor(0.8, 0.8, 0.8)

    f.partChips = {}
    for i, n in ipairs({ 2, 3, 4, 5, 6, 7, 8 }) do
        local chip = NewChip(f)
        chip.text:SetText(tostring(n))
        chip:SetPoint("TOPLEFT", partsLabel, "BOTTOMLEFT", (i - 1) * 32, -6)
        chip:SetScript("OnClick", function()
            EnsureDB()
            CCRaidToolsDB.raidGroups.sortSettings.parts = n
            RefreshSortSettingsFrame()
        end)
        f.partChips[n] = chip
    end

    -- Split rule
    local ruleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ruleLabel:SetPoint("TOPLEFT", partsLabel, "BOTTOMLEFT", 0, -52)
    ruleLabel:SetText(C.L.rgSortRuleLabel)
    ruleLabel:SetTextColor(0.8, 0.8, 0.8)

    local ruleConsec = CreateFrame("Button", nil, f, "BackdropTemplate")
    ruleConsec:SetSize(132, 22)
    ruleConsec:SetPoint("TOPLEFT", ruleLabel, "BOTTOMLEFT", 0, -6)
    ruleConsec:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    ruleConsec:SetBackdropBorderColor(0, 0, 0, 1)
    ruleConsec.text = ruleConsec:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ruleConsec.text:SetPoint("CENTER")
    ruleConsec.text:SetText(C.L.rgSortRuleConsecutive)
    ruleConsec:SetScript("OnClick", function()
        EnsureDB()
        CCRaidToolsDB.raidGroups.sortSettings.rule = "consecutive"
        RefreshSortSettingsFrame()
    end)

    local ruleAlt = CreateFrame("Button", nil, f, "BackdropTemplate")
    ruleAlt:SetSize(132, 22)
    ruleAlt:SetPoint("LEFT", ruleConsec, "RIGHT", 4, 0)
    ruleAlt:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    ruleAlt:SetBackdropBorderColor(0, 0, 0, 1)
    ruleAlt.text = ruleAlt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ruleAlt.text:SetPoint("CENTER")
    ruleAlt.text:SetText(C.L.rgSortRuleAlternating)
    ruleAlt:SetScript("OnClick", function()
        EnsureDB()
        CCRaidToolsDB.raidGroups.sortSettings.rule = "alternating"
        RefreshSortSettingsFrame()
    end)
    f.ruleConsecBtn = ruleConsec
    f.ruleAltBtn = ruleAlt

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 22)
    closeBtn:SetPoint("BOTTOM", 0, 10)
    closeBtn:SetText(C.L.rgCloseButton)
    C.SkinButton(closeBtn)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    sortSettingsFrame = f
    return f
end

local function OpenSortSettingsPopup(panel)
    EnsureSortSettingsFrame(panel)
    RefreshSortSettingsFrame()
    sortSettingsFrame:Show()
end

local function SortGroups()
    RefreshRoster()
    EnsureDB()
    local settings = CCRaidToolsDB.raidGroups.sortSettings

    local concernedGroups = {}
    for g = 1, NUM_GROUPS do
        if settings.groups[g] then
            concernedGroups[#concernedGroups + 1] = g
        end
    end

    -- Anyone already sitting in an excluded group keeps their spot and is
    -- removed from the pool of people to redistribute.
    local preserved = {}
    for name, g in pairs(assign) do
        if not settings.groups[g] then
            preserved[name] = g
        end
    end

    wipe(assign)
    local counts = {}
    for g = 1, NUM_GROUPS do
        counts[g] = 0
    end
    for name, g in pairs(preserved) do
        assign[name] = g
        counts[g] = counts[g] + 1
    end

    local buckets = { TANK = {}, HEALER = {}, DAMAGER = {} }
    for _, unit in ipairs(GetRosterUnits()) do
        if UnitExists(unit) then
            local name = C.StripRealm(UnitName(unit))
            if name and not preserved[name] then
                local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
                if role ~= "TANK" and role ~= "HEALER" then
                    role = "DAMAGER"
                end
                table.insert(buckets[role], name)
            end
        end
    end
    for _, list in pairs(buckets) do
        table.sort(list)
    end

    if #concernedGroups == 0 then
        -- Nothing is allowed to be touched; leave everyone where they were.
        currentPresetName = nil
        SaveCurrent()
        Refresh()
        return
    end

    local parts = math.min(settings.parts, #concernedGroups)
    local PARTS_LIST = BuildSortPartition(concernedGroups, parts, settings.rule)

    local function TryGroup(g, name)
        if counts[g] < NUM_SLOTS then
            assign[name] = g
            counts[g] = counts[g] + 1
            return true
        end
        return false
    end

    -- Once a part's own groups are full, spill into any group with room:
    -- the other concerned groups first, then the excluded ones as a last resort.
    local overflowOrder = {}
    for _, g in ipairs(concernedGroups) do
        overflowOrder[#overflowOrder + 1] = g
    end
    for g = 1, NUM_GROUPS do
        if not settings.groups[g] then
            overflowOrder[#overflowOrder + 1] = g
        end
    end
    local overflowPtr = 1
    local function PlaceOverflow(name)
        local len = #overflowOrder
        for i = 0, len - 1 do
            local idx = ((overflowPtr - 1 + i) % len) + 1
            local g = overflowOrder[idx]
            if TryGroup(g, name) then
                overflowPtr = (idx % len) + 1
                return
            end
        end
    end

    -- partPtr[p] remembers which of the part's groups to try first next, so
    -- consecutive placements into the same part rotate through all of them.
    local partPtr = {}
    for p = 1, parts do
        partPtr[p] = 1
    end
    local function PlaceInPart(p, name)
        local list = PARTS_LIST[p]
        local len = #list
        if len == 0 then
            PlaceOverflow(name)
            return
        end
        local start = partPtr[p]
        for i = 0, len - 1 do
            local slot = ((start - 1 + i) % len) + 1
            local g = list[slot]
            if TryGroup(g, name) then
                partPtr[p] = (slot % len) + 1
                return
            end
        end
        PlaceOverflow(name)
    end

    local nextPart = 1
    local function PlaceAlternating(name)
        PlaceInPart(nextPart, name)
        nextPart = (nextPart % parts) + 1
    end

    for _, role in ipairs(ROLE_ORDER) do
        for _, name in ipairs(buckets[role]) do
            PlaceAlternating(name)
        end
    end
    currentPresetName = nil
    SaveCurrent()
    Refresh()
end

local function ResetGroups()
    wipe(assign)
    currentPresetName = nil
    SaveCurrent()
    Refresh()
end

-- ===== In-game sharing (addon message, chunked) =====

local function SanitizeShareName(name)
    name = name or ""
    name = name:gsub("~", "-")
    return name
end

-- Prefer whatever the user has just typed in the name field (even if they
-- haven't clicked "Sauvegarder" yet), then fall back to the last preset
-- actually loaded/saved, then to nothing (receiver falls back to sender name).
local function GetShareName()
    local typed = presetEdit and presetEdit:GetText()
    typed = typed and typed:gsub("^%s+", ""):gsub("%s+$", "")
    if typed and typed ~= "" then
        return typed
    end
    return currentPresetName or ""
end

local function BuildSharePayload()
    return SanitizeShareName(GetShareName()) .. "~" .. SerializeAssign(assign)
end

-- Splits a "name~name=group,name=group,..." payload back into its parts.
local function ParseSharePayload(full)
    local name, data = full:match("^([^~]*)~(.*)$")
    if not name then
        name, data = "", full
    end
    local tbl = DeserializeAssign(data)
    return name, tbl
end

local function ShareGroups()
    if not (IsInRaid() or IsInGroup()) then
        print(C.L.rgNeedGroup)
        return
    end
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        print(C.L.rgNoApi)
        return
    end
    if SerializeAssign(assign) == "" then
        print(C.L.rgNothingToShare)
        return
    end
    local payload = BuildSharePayload()
    local channel = IsInRaid() and "RAID" or "PARTY"
    shareSeq = (shareSeq % 999) + 1
    local msgId = shareSeq
    local chunks = {}
    for i = 1, #payload, SHARE_CHUNK_SIZE do
        chunks[#chunks + 1] = payload:sub(i, i + SHARE_CHUNK_SIZE - 1)
    end
    local total = #chunks
    for idx, chunk in ipairs(chunks) do
        C_ChatInfo.SendAddonMessage(SHARE_PREFIX, msgId .. ":" .. idx .. ":" .. total .. ":" .. chunk, channel)
    end
    print(string.format(C.L.rgShared, total))
end

-- ===== Export / Import as text (works outside of raid too) =====

local function EncodeExportString()
    return EXPORT_TAG .. BuildSharePayload()
end

-- Returns { name = string, assign = table } or nil if the string is invalid.
local function DecodeExportString(str)
    str = str and str:gsub("^%s+", ""):gsub("%s+$", "")
    if not str or str:sub(1, #EXPORT_TAG) ~= EXPORT_TAG then
        return nil
    end
    local name, tbl = ParseSharePayload(str:sub(#EXPORT_TAG + 1))
    if not next(tbl) then
        return nil
    end
    return { name = name, assign = tbl }
end

-- ===== Export / Import popups =====

local function SkinPopupEditBox(editBox)
    editBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    editBox:SetBackdropColor(0.018, 0.018, 0.024, 0.90)
    editBox:SetBackdropBorderColor(0, 0, 0, 1)
    editBox:SetTextColor(1, 1, 1)
    editBox:SetTextInsets(5, 5, 0, 0)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetAutoFocus(false)
end

local function EnsureExportFrame(panel)
    if exportFrame then
        return exportFrame
    end
    local f = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    f:SetSize(320, 110)
    f:SetPoint("CENTER", panel, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    C.ApplyPanelSkin(f)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText(C.L.rgExportTitle)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 10, -28)
    hint:SetText(C.L.rgExportHint)
    hint:SetTextColor(0.75, 0.75, 0.75)

    local box = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    box:SetSize(300, 24)
    box:SetPoint("TOPLEFT", 10, -46)
    SkinPopupEditBox(box)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    f.box = box

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 22)
    closeBtn:SetPoint("BOTTOM", 0, 12)
    closeBtn:SetText(C.L.rgCloseButton)
    C.SkinButton(closeBtn)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    exportFrame = f
    return f
end

local function OpenExportPopup(panel)
    local payload = SerializeAssign(assign)
    if payload == "" then
        print(C.L.rgNothingToShare)
        return
    end
    local f = EnsureExportFrame(panel)
    f.box:SetText(EncodeExportString())
    f:Show()
    f.box:SetFocus()
    f.box:HighlightText()
end

local function EnsureImportFrame(panel)
    if importFrame then
        return importFrame
    end
    local f = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    f:SetSize(320, 150)
    f:SetPoint("CENTER", panel, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    C.ApplyPanelSkin(f)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText(C.L.rgImportTitle)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    local nameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameLabel:SetPoint("TOPLEFT", 10, -30)
    nameLabel:SetText(C.L.rgImportNameLabel)
    nameLabel:SetTextColor(0.75, 0.75, 0.75)

    local nameBox = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    nameBox:SetSize(300, 22)
    nameBox:SetPoint("TOPLEFT", 10, -46)
    SkinPopupEditBox(nameBox)
    nameBox:SetMaxLetters(40)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.nameBox = nameBox

    local pasteLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pasteLabel:SetPoint("TOPLEFT", 10, -74)
    pasteLabel:SetText(C.L.rgImportPasteLabel)
    pasteLabel:SetTextColor(0.75, 0.75, 0.75)

    local pasteBox = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    pasteBox:SetSize(300, 22)
    pasteBox:SetPoint("TOPLEFT", 10, -90)
    SkinPopupEditBox(pasteBox)
    pasteBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    pasteBox:SetScript("OnTextChanged", function(self)
        if nameBox:GetText() == "" then
            local decoded = DecodeExportString(self:GetText())
            if decoded and decoded.name ~= "" then
                nameBox:SetText(decoded.name)
            end
        end
    end)
    f.pasteBox = pasteBox

    local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", 10, -114)
    status:SetTextColor(1, 0.4, 0.4)
    f.status = status

    local confirmBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    confirmBtn:SetSize(90, 22)
    confirmBtn:SetPoint("BOTTOMLEFT", 10, 10)
    confirmBtn:SetText(C.L.rgImportButton)
    C.SkinButton(confirmBtn)
    confirmBtn:SetScript("OnClick", function()
        local decoded = DecodeExportString(pasteBox:GetText())
        if not decoded then
            status:SetText(C.L.rgImportInvalid)
            return
        end
        local baseName = nameBox:GetText()
        baseName = baseName and baseName:gsub("^%s+", ""):gsub("%s+$", "")
        if not baseName or baseName == "" then
            baseName = (decoded.name ~= "" and decoded.name) or C.L.rgImportDefaultName
        end
        local saved = SavePresetNamed(baseName, decoded.assign)
        print(string.format(C.L.rgImportDone, saved))
        RefreshPresetFlyout()
        f:Hide()
    end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    closeBtn:SetText(C.L.rgCloseButton)
    C.SkinButton(closeBtn)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    importFrame = f
    return f
end

local function OpenImportPopup(panel)
    local f = EnsureImportFrame(panel)
    f.nameBox:SetText("")
    f.pasteBox:SetText("")
    f.status:SetText("")
    f:Show()
    f.pasteBox:SetFocus()
end

-- ===== Apply to raid (leader/assist) =====

local function ApplyGroups()
    if not IsInRaid() then
        print(C.L.rgNeedRaid)
        return
    end
    if not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        print(C.L.rgNeedLead)
        return
    end
    if InCombatLockdown() then
        print(C.L.rgCombatBlocked)
        return
    end
    local SwapFn = (C_PartyInfo and C_PartyInfo.SwapRaidSubgroup) or _G.SwapRaidSubgroup
    local SetSubgroupFn = (C_PartyInfo and C_PartyInfo.SetRaidSubgroup) or _G.SetRaidSubgroup
    if not SwapFn or not SetSubgroupFn then
        print(C.L.rgNoApi)
        return
    end
    local nameToIndex, indexToGroup = {}, {}
    local subgroupCount = {}
    for g = 1, NUM_GROUPS do
        subgroupCount[g] = 0
    end
    local n = GetNumGroupMembers() or 0
    for i = 1, n do
        local rname, _, subgroup = GetRaidRosterInfo(i)
        if rname and subgroup then
            local short = C.StripRealm(rname)
            nameToIndex[short] = i
            indexToGroup[i] = subgroup
            subgroupCount[subgroup] = (subgroupCount[subgroup] or 0) + 1
        end
    end

    local moved, attempts = 0, 0
    local changed = true
    while changed and attempts < 60 do
        changed = false
        attempts = attempts + 1
        for name, wantGroup in pairs(assign) do
            local idx = nameToIndex[name]
            if idx and indexToGroup[idx] ~= wantGroup then
                if (subgroupCount[wantGroup] or 0) < NUM_SLOTS then
                    -- Target group has room: plain move, no swap needed.
                    local curGroup = indexToGroup[idx]
                    SetSubgroupFn(idx, wantGroup)
                    subgroupCount[curGroup] = subgroupCount[curGroup] - 1
                    subgroupCount[wantGroup] = subgroupCount[wantGroup] + 1
                    indexToGroup[idx] = wantGroup
                    moved = moved + 1
                    changed = true
                else
                    -- Target group is full: swap with someone in it (prefer
                    -- someone who also wants to leave that group).
                    local partnerIdx
                    for oname, oidx in pairs(nameToIndex) do
                        if oidx ~= idx and indexToGroup[oidx] == wantGroup and assign[oname] and assign[oname] ~= wantGroup then
                            partnerIdx = oidx
                            break
                        end
                    end
                    if not partnerIdx then
                        for oname, oidx in pairs(nameToIndex) do
                            if oidx ~= idx and indexToGroup[oidx] == wantGroup then
                                partnerIdx = oidx
                                break
                            end
                        end
                    end
                    if partnerIdx then
                        local curGroup = indexToGroup[idx]
                        SwapFn(idx, partnerIdx)
                        indexToGroup[idx] = wantGroup
                        indexToGroup[partnerIdx] = curGroup
                        moved = moved + 1
                        changed = true
                    end
                end
            end
        end
    end
    print(string.format(C.L.rgApplyDone, moved))
end

-- ===== Refresh (render) =====

function Refresh()
    if not frame then
        return
    end
    RefreshRoster()

    for g = 1, NUM_GROUPS do
        local members = {}
        for name, grp in pairs(assign) do
            if grp == g and rosterSet[name] then
                members[#members + 1] = name
            end
        end
        table.sort(members)
        for s = 1, NUM_SLOTS do
            local slot = slotFrames[g][s]
            local m = members[s]
            slot.member = m
            if m then
                slot.text:SetText(m)
                local r, gg, b = ClassColor(m)
                slot.text:SetTextColor(r, gg, b)
            else
                slot.text:SetText("-")
                slot.text:SetTextColor(0.4, 0.4, 0.4)
            end
        end
        if groupHeaders[g] then
            groupHeaders[g]:SetText(string.format(C.L.rgGroupHeader, g, #members, NUM_SLOTS))
        end
    end

    local pool = {}
    for name in pairs(rosterSet) do
        if not assign[name] then
            pool[#pool + 1] = name
        end
    end
    table.sort(pool)
    local perRow = 4
    for i, name in ipairs(pool) do
        local t = AcquirePoolToken(i)
        t.member = name
        t.text:SetText(name)
        local r, g, b = ClassColor(name)
        t.text:SetTextColor(r, g, b)
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", poolContainer, "TOPLEFT", col * (TOKEN_W + 6), -row * (TOKEN_H + 4))
        t:Show()
    end
    for i = #pool + 1, #poolTokens do
        poolTokens[i]:Hide()
    end
    local poolRows = math.max(1, math.ceil(#pool / perRow))
    poolContainer:SetHeight(poolRows * (TOKEN_H + 4))

    if countText then
        countText:SetText(string.format(C.L.rgUnassignedCount, #pool))
    end

    if C.RequestResize then
        C.RequestResize()
    end
end

local function BuildUI(panel)
    EnsureDB()
    LoadCurrent()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
    title:SetText(C.L.rgLabel)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    -- Preset row
    presetEdit = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
    presetEdit:SetSize(140, 22)
    presetEdit:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -30)
    presetEdit:SetAutoFocus(false)
    presetEdit:SetMaxLetters(40)
    presetEdit:SetFontObject("ChatFontNormal")
    presetEdit:SetTextInsets(5, 5, 0, 0)
    presetEdit:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    presetEdit:SetBackdropColor(0.018, 0.018, 0.024, 0.90)
    presetEdit:SetBackdropBorderColor(0, 0, 0, 1)
    presetEdit:SetTextColor(1, 1, 1)
    presetEdit:SetScript("OnEnterPressed", function(self) SavePreset(); self:ClearFocus() end)

    local saveBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    saveBtn:SetSize(96, 22)
    saveBtn:SetPoint("LEFT", presetEdit, "RIGHT", 6, 0)
    saveBtn:SetText(C.L.rgSaveButton)
    C.SkinButton(saveBtn)
    saveBtn:SetScript("OnClick", SavePreset)

    local presetsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    presetsBtn:SetSize(104, 22)
    presetsBtn:SetPoint("LEFT", saveBtn, "RIGHT", 6, 0)
    presetsBtn:SetText(C.L.rgPresetsButton)
    C.SkinButton(presetsBtn)
    -- Reuse Blizzard's own scrollbar arrow texture instead of a text glyph
    -- (unicode arrows render poorly in the WoW font).
    local presetsArrow = presetsBtn:CreateTexture(nil, "OVERLAY")
    presetsArrow:SetSize(14, 14)
    presetsArrow:SetPoint("RIGHT", -6, 0)
    presetsArrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    presetsBtn.arrow = presetsArrow
    presetsArrowTex = presetsArrow
    local presetsBtnText = presetsBtn:GetFontString()
    if presetsBtnText then
        presetsBtnText:ClearAllPoints()
        presetsBtnText:SetPoint("LEFT", 10, 0)
        presetsBtnText:SetPoint("RIGHT", presetsArrow, "LEFT", -3, 0)
        presetsBtnText:SetJustifyH("LEFT")
    end

    BuildPresetFlyout(panel)
    presetFlyout:SetPoint("TOPLEFT", presetsBtn, "BOTTOMLEFT", 0, -2)
    presetsBtn:SetScript("OnClick", function()
        if presetFlyout:IsShown() then
            ClosePresetFlyout()
        else
            RefreshPresetFlyout()
            presetFlyout:Show()
            presetsArrowTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
        end
    end)

    -- Action row
    local sortBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    sortBtn:SetSize(96, 22)
    sortBtn:SetPoint("TOPLEFT", presetEdit, "BOTTOMLEFT", 0, -8)
    sortBtn:SetText(C.L.rgSortButton)
    C.SkinButton(sortBtn)
    sortBtn:SetScript("OnClick", SortGroups)

    local sortSettingsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    sortSettingsBtn:SetSize(22, 22)
    sortSettingsBtn:SetPoint("LEFT", sortBtn, "RIGHT", 4, 0)
    C.SkinButton(sortSettingsBtn)
    local gearTex = sortSettingsBtn:CreateTexture(nil, "OVERLAY")
    gearTex:SetSize(14, 14)
    gearTex:SetPoint("CENTER")
    gearTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    sortSettingsBtn:SetScript("OnClick", function() OpenSortSettingsPopup(panel) end)

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(96, 22)
    resetBtn:SetPoint("LEFT", sortSettingsBtn, "RIGHT", 6, 0)
    resetBtn:SetText(C.L.rgResetButton)
    C.SkinButton(resetBtn)
    resetBtn:SetScript("OnClick", ResetGroups)

    local applyBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    applyBtn:SetSize(96, 22)
    applyBtn:SetPoint("LEFT", resetBtn, "RIGHT", 6, 0)
    applyBtn:SetText(C.L.rgApplyButton)
    C.SkinButton(applyBtn)
    applyBtn:SetScript("OnClick", ApplyGroups)
    if InCombatLockdown() then
        applyBtn:Disable()
    end
    applyButton = applyBtn

    -- Share row
    local shareBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    shareBtn:SetSize(96, 22)
    shareBtn:SetPoint("TOPLEFT", sortBtn, "BOTTOMLEFT", 0, -8)
    shareBtn:SetText(C.L.rgShareButton)
    C.SkinButton(shareBtn)
    shareBtn:SetScript("OnClick", ShareGroups)

    local exportBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    exportBtn:SetSize(96, 22)
    exportBtn:SetPoint("LEFT", shareBtn, "RIGHT", 6, 0)
    exportBtn:SetText(C.L.rgExportButton)
    C.SkinButton(exportBtn)
    exportBtn:SetScript("OnClick", function() OpenExportPopup(panel) end)

    local importBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    importBtn:SetSize(96, 22)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 6, 0)
    importBtn:SetText(C.L.rgImportButton)
    C.SkinButton(importBtn)
    importBtn:SetScript("OnClick", function() OpenImportPopup(panel) end)

    -- Pool
    local poolLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    poolLabel:SetPoint("TOPLEFT", shareBtn, "BOTTOMLEFT", 0, -10)
    poolLabel:SetText(C.L.rgUnassignedLabel)
    poolLabel:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
    countText = poolLabel

    poolContainer = CreateFrame("Frame", nil, panel)
    poolContainer:SetPoint("TOPLEFT", poolLabel, "BOTTOMLEFT", 0, -4)
    poolContainer:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    poolContainer:SetHeight(TOKEN_H + 4)
    poolContainer:EnableMouse(true)

    -- Groups grid: 2 rows x 4 columns
    local gridTop = -250
    local colWidth = 118
    local rowGap = 14
    local rowHeight = 14 + NUM_SLOTS * (TOKEN_H + 2) + rowGap
    for g = 1, NUM_GROUPS do
        local col = (g - 1) % 4
        local row = math.floor((g - 1) / 4)
        local x = 10 + col * (colWidth + 6)
        local y = gridTop - row * rowHeight
        NewGroupColumn(panel, g, x, y)
    end

    -- Invisible spacer so the window keeps a comfortable bottom margin
    -- below the last row of group slots instead of feeling cramped.
    local bottomSpacer = CreateFrame("Frame", nil, panel)
    bottomSpacer:SetSize(4, 4)
    local lastRow = math.floor((NUM_GROUPS - 1) / 4)
    bottomSpacer:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, gridTop - lastRow * rowHeight - rowHeight - 24)

    frame = panel
    Refresh()
end

local function RefreshUI()
    EnsureDB()
    LoadCurrent()
    Refresh()
end

C.RegisterModule("RaidGroups", BuildUI, RefreshUI)

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(SHARE_PREFIX)
end

local e = CreateFrame("Frame")
e:RegisterEvent("GROUP_ROSTER_UPDATE")
e:RegisterEvent("PLAYER_ENTERING_WORLD")
e:RegisterEvent("PLAYER_REGEN_DISABLED")
e:RegisterEvent("PLAYER_REGEN_ENABLED")
e:RegisterEvent("CHAT_MSG_ADDON")
e:SetScript("OnEvent", function(_, ev, a, b, c, d)
    if ev == "PLAYER_REGEN_DISABLED" then
        if applyButton then applyButton:Disable() end
        return
    elseif ev == "PLAYER_REGEN_ENABLED" then
        if applyButton then applyButton:Enable() end
        return
    elseif ev == "CHAT_MSG_ADDON" then
        local prefix, msg, sender = a, b, d
        if prefix ~= SHARE_PREFIX or not msg or not sender then
            return
        end
        local msgId, idx, total, chunk = msg:match("^(%d+):(%d+):(%d+):(.*)$")
        if not msgId then
            return
        end
        idx, total = tonumber(idx), tonumber(total)
        if not idx or not total or total < 1 then
            return
        end
        local key = sender .. "#" .. msgId
        local entry = incomingShares[key]
        if not entry then
            entry = { total = total, chunks = {}, count = 0 }
            incomingShares[key] = entry
        end
        if not entry.chunks[idx] then
            entry.chunks[idx] = chunk
            entry.count = entry.count + 1
        end
        if entry.count >= entry.total then
            incomingShares[key] = nil
            local full = table.concat(entry.chunks, "", 1, entry.total)
            local sharedName, tbl = ParseSharePayload(full)
            if next(tbl) then
                local shortSender = C.StripRealm(sender)
                local baseName = (sharedName ~= "" and sharedName) or string.format(C.L.rgReceivedPresetName, shortSender)
                local saved = SavePresetNamed(baseName, tbl)
                print(string.format(C.L.rgReceived, shortSender, saved))
                RefreshPresetFlyout()
            end
        end
        return
    end
    if frame and frame:IsShown() then
        Refresh()
    end
end)
