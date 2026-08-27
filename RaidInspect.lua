-- CC RaidTools - Raid Inspect
-- Original implementation using Blizzard's public inspect API only.
-- Shows, for each raid/party member: average item level, number of missing
-- enchants on the commonly-enchanted slots, number of empty gem sockets,
-- and current specialization. Displayed inline in the module tab, which
-- grows/shrinks dynamically with the main window (with an internal scroll
-- past a comfortable cap, so large raids don't blow up the whole window).
local C = CCRT

local panelRef, rows = nil, {}
local ROW_H = 18
-- Hard cap at 20 rows visible without scrolling; beyond that the list
-- scrolls. Kept well under the ~557px theoretical budget (main window's
-- 705px cap minus overhead) for extra safety margin.
local MAX_SCROLL_HEIGHT = 20 * ROW_H
local inspecting = false
local queue = {}
local queueIndex = 0
local pendingGUID, pendingTimeout
local pendingQueueIndex = 0
local inventorySettleTimer, inventoryCapTimer
local results = {} -- keyed by unit token -> data table
local inspectButton, statusText, scrollFrame, rowsChild

-- Enchantable slots change between expansions (Blizzard periodically shuffles
-- which gear pieces can carry a permanent enchant). As of Midnight (12.x),
-- per Method's own consumables guide: Head, Shoulder, Rings, Boots, Chest and
-- Weapons. Cloak/Back and Bracer/Wrist enchants were removed this expansion;
-- Head and Shoulder enchants came back. Revisit this list each expansion.
local ENCHANT_SLOTS = {
    INVSLOT_HEAD,
    INVSLOT_SHOULDER,
    INVSLOT_FINGER1,
    INVSLOT_FINGER2,
    INVSLOT_CHEST,
    INVSLOT_FEET,
    INVSLOT_MAINHAND,
    INVSLOT_OFFHAND,
}
-- Localized name per slot, used for the "which slot exactly" diagnostic tooltip.
-- Covers every slot that can plausibly carry a gem, not just the enchantable ones.
local SLOT_NAME_KEYS = {
    [INVSLOT_HEAD] = "riSlotHead",
    [INVSLOT_SHOULDER] = "riSlotShoulder",
    [INVSLOT_FINGER1] = "riSlotFinger1",
    [INVSLOT_FINGER2] = "riSlotFinger2",
    [INVSLOT_CHEST] = "riSlotChest",
    [INVSLOT_FEET] = "riSlotFeet",
    [INVSLOT_MAINHAND] = "riSlotMainHand",
    [INVSLOT_OFFHAND] = "riSlotOffHand",
    [INVSLOT_NECK] = "riSlotNeck",
    [INVSLOT_WAIST] = "riSlotWaist",
    [INVSLOT_WRIST] = "riSlotWrist",
    [INVSLOT_HAND] = "riSlotHands",
    [INVSLOT_LEGS] = "riSlotLegs",
    [INVSLOT_BACK] = "riSlotBack",
    [INVSLOT_TRINKET1] = "riSlotTrinket1",
    [INVSLOT_TRINKET2] = "riSlotTrinket2",
}

local function SlotName(slot)
    local key = SLOT_NAME_KEYS[slot]
    return key and C.L[key] or ("#" .. tostring(slot))
end
-- All gear slots are checked for empty gem sockets.
local ALL_SLOTS = {}
for i = 1, 19 do
    ALL_SLOTS[#ALL_SLOTS + 1] = i
end

-- Build (once) a set of localized empty-socket strings from the client.
local emptySocketTexts

local function GetEmptySocketTexts()
    if emptySocketTexts then
        return emptySocketTexts
    end
    emptySocketTexts = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "string" and v ~= "" and k:match("^EMPTY_SOCKET_") then
            emptySocketTexts[v] = true
        end
    end
    return emptySocketTexts
end

-- C_TooltipInfo returns structured tooltip data. SurfaceArgs makes the
-- structured fields (such as leftText/type) available before inspection.
local function SurfaceTooltipData(data)
    if not data or not TooltipUtil or not TooltipUtil.SurfaceArgs then
        return
    end
    pcall(TooltipUtil.SurfaceArgs, data)
    if data.lines then
        for _, line in ipairs(data.lines) do
            pcall(TooltipUtil.SurfaceArgs, line)
        end
    end
end

local function SafeText(value)
    if value == nil then
        return nil
    end
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    if canaccessvalue and not canaccessvalue(value) then
        return nil
    end
    return value
end

local function HasInventoryItem(unit, slot)
    if not GetInventoryItemLink then
        return false
    end
    local ok, link = pcall(GetInventoryItemLink, unit, slot)
    if not ok then
        return false
    end
    return link and true or false
end

-- Off-hand enchants only apply to an actual off-hand *weapon* (melee
-- dual-wielders). Casters/tanks/healers holding an orb, tome, or other
-- "Held In Off-hand" item there can never enchant it — that's not a missing
-- enchant, it's just not an enchantable item, so don't flag it at all.
local function IsOffhandWeapon(unit, slot)
    local ok, link = pcall(GetInventoryItemLink, unit, slot)
    if not ok or not link then
        return false
    end
    local ok2, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, link)
    if not ok2 then
        return false
    end
    return classID == Enum.ItemClass.Weapon
end

local function CountEmptySocketsOnSlot(unit, slot)
    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then
        return 0
    end
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, unit, slot)
    if not ok or not data or not data.lines then
        return 0
    end
    SurfaceTooltipData(data)
    local texts = GetEmptySocketTexts()
    local n = 0
    for _, line in ipairs(data.lines) do
        local leftText = SafeText(line.leftText)
        if leftText and texts[leftText] then
            n = n + 1
        end
    end
    return n
end

-- The item link contains the permanent enchant ID directly after the item ID.
-- This is more reliable than tooltip text or tooltip line availability: the
-- tooltip can still be sparse/uncached on one client while the inspected item
-- link already contains its authoritative enchant field.
--
-- Returns:
--   true  = an enchant ID is present
--   false = the item link explicitly says there is no permanent enchant
--   nil   = the link could not be parsed; caller may use the tooltip fallback
local function HasEnchantFromItemLink(unit, slot)
    if not GetInventoryItemLink then
        return nil
    end

    local ok, link = pcall(GetInventoryItemLink, unit, slot)
    link = ok and SafeText(link) or nil
    if not link then
        return nil
    end

    -- Item links use the form item:itemID:enchantID:gemID1:...
    -- Blank enchant fields are equivalent to zero.
    local itemID, enchantField = link:match("|Hitem:(%d+):([^:]*)")
    if not itemID then
        itemID, enchantField = link:match("item:(%d+):([^:]*)")
    end
    if not itemID then
        return nil
    end

    local enchantID = tonumber(enchantField)
    if enchantID and enchantID > 0 then
        return true
    end
    if enchantField == "" or enchantID == 0 then
        return false
    end

    return nil
end

-- Prefer the item link's enchant field. The structured tooltip type remains a
-- fallback for unusual links/API states where the inspected item link cannot
-- be parsed. Localized tooltip text is the final fallback only.
local function HasEnchantOnSlot(unit, slot)
    local fromLink = HasEnchantFromItemLink(unit, slot)
    if fromLink ~= nil then
        return fromLink
    end

    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then
        return nil
    end

    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, unit, slot)
    if not ok or not data or not data.lines then
        return nil
    end

    SurfaceTooltipData(data)

    local lineTypes = Enum and Enum.TooltipDataLineType
    local permanentEnchantType = lineTypes and lineTypes.ItemEnchantmentPermanent

    if permanentEnchantType then
        for _, line in ipairs(data.lines) do
            if line.type == permanentEnchantType then
                return true
            end
        end
    end

    -- Fallback for clients/API states where the structured line type is not
    -- exposed. This is intentionally last: tooltip text is the least reliable
    -- source because it can differ while inspect data is still settling.
    local fmt = _G.ENCHANTED_TOOLTIP_LINE
    local prefix = fmt and fmt:match("^(.-)%%s")
    if prefix and prefix ~= "" then
        local pattern = "^" .. prefix:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        for _, line in ipairs(data.lines) do
            local leftText = SafeText(line.leftText)
            if leftText and leftText:find(pattern) then
                return true
            end
        end
    end

    return false
end

local function CollectUnitData(unit)
    local data = { missingEnchants = 0, missingGems = 0, ilvl = 0, missingEnchantSlots = {}, missingGemSlots = {} }

    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local ok, ilvl = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
        if ok and ilvl and (not issecretvalue or not issecretvalue(ilvl)) and (not canaccessvalue or canaccessvalue(ilvl)) then
            data.ilvl = math.floor(ilvl + 0.5)
        end
    end

    for _, slot in ipairs(ENCHANT_SLOTS) do
        local isOffhandSlot = (slot == INVSLOT_OFFHAND)
        if HasInventoryItem(unit, slot) and (not isOffhandSlot or IsOffhandWeapon(unit, slot)) then
            local has = HasEnchantOnSlot(unit, slot)
            if has == false then
                data.missingEnchants = data.missingEnchants + 1
                data.missingEnchantSlots[#data.missingEnchantSlots + 1] = SlotName(slot)
            end
        end
    end

    for _, slot in ipairs(ALL_SLOTS) do
        if HasInventoryItem(unit, slot) then
            local n = CountEmptySocketsOnSlot(unit, slot)
            if n > 0 then
                data.missingGems = data.missingGems + n
                data.missingGemSlots[#data.missingGemSlots + 1] = SlotName(slot)
            end
        end
    end

    return data
end

local function GetGroupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() or 0 do
            units[#units + 1] = "raid" .. i
        end
    elseif IsInGroup() then
        units[#units + 1] = "player"
        for i = 1, 4 do
            if UnitExists("party" .. i) then
                units[#units + 1] = "party" .. i
            end
        end
    end
    return units
end

local function NewRow(parent, i)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(420, ROW_H)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    local function T(x, w, j)
        local f = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f:SetPoint("LEFT", x, 0)
        f:SetWidth(w)
        f:SetJustifyH(j or "CENTER")
        f:SetWordWrap(false) -- never let long status text ("En attente"/"Waiting") wrap
        -- to a 2nd line: that inflates the row's real rendered height past the
        -- fixed ROW_H we budget for, which is exactly what pushed rows below
        -- the window edge. Truncating on one line is fine here (there's a
        -- hover tooltip for detail on the enchant/gem columns already).
        return f
    end
    r.nameText = T(4, 150, "LEFT")
    r.ilvlText = T(160, 55)
    r.enchantsText = T(222, 95)
    r.gemsText = T(324, 95)

    -- FontStrings can't catch mouse events directly: invisible hover frames
    -- on top of the enchant/gem columns show which exact slot(s) are flagged,
    -- so nobody has to take our word for a bare count.
    local function HoverZone(anchorText, getLines)
        local z = CreateFrame("Frame", nil, r)
        z:SetPoint("LEFT", anchorText)
        z:SetSize(95, ROW_H)
        z:EnableMouse(true)
        z:SetScript("OnEnter", function(self)
            local lines = getLines()
            if not lines or #lines == 0 then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(lines.header)
            for _, s in ipairs(lines) do
                GameTooltip:AddLine("- " .. s, 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        z:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        return z
    end
    r.enchantsHover = HoverZone(r.enchantsText, function()
        local data = results[r._ccrtUnit]
        if not data or not data.missingEnchantSlots or #data.missingEnchantSlots == 0 then
            return nil
        end
        local t = { header = C.L.riMissingEnchantTooltip }
        for _, s in ipairs(data.missingEnchantSlots) do
            t[#t + 1] = s
        end
        return t
    end)
    r.gemsHover = HoverZone(r.gemsText, function()
        local data = results[r._ccrtUnit]
        if not data or not data.missingGemSlots or #data.missingGemSlots == 0 then
            return nil
        end
        local t = { header = C.L.riMissingGemTooltip }
        for _, s in ipairs(data.missingGemSlots) do
            t[#t + 1] = s
        end
        return t
    end)
    return r
end

local function RefreshRow(i, unit, name)
    local r = rows[i] or NewRow(rowsChild, i)
    rows[i] = r
    r._ccrtUnit = unit
    local _, class = UnitClass(unit)
    local col = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if col then
        r.nameText:SetTextColor(col.r, col.g, col.b)
    else
        r.nameText:SetTextColor(1, 1, 1)
    end
    r.nameText:SetText(C.StripRealm(name))

    local data = results[unit]
    if not data then
        r.ilvlText:SetText("|cffff9900" .. C.L.riStatusWaiting .. "|r")
        r.enchantsText:SetText("")
        r.gemsText:SetText("")
    elseif data.status == "outofrange" then
        r.ilvlText:SetText("|cffff4444" .. C.L.riStatusOutOfRange .. "|r")
        r.enchantsText:SetText("")
        r.gemsText:SetText("")
    elseif data.status == "timeout" then
        r.ilvlText:SetText("|cffff4444" .. C.L.riStatusTimeout .. "|r")
        r.enchantsText:SetText("")
        r.gemsText:SetText("")
    else
        r.ilvlText:SetText(tostring(data.ilvl or "?"))
        if (data.missingEnchants or 0) > 0 then
            r.enchantsText:SetText("|cffff4444" .. C.L.riMissingCount:format(data.missingEnchants) .. "|r")
        else
            r.enchantsText:SetText("|cff33ff66" .. C.L.riStatusOK .. "|r")
        end
        if (data.missingGems or 0) > 0 then
            r.gemsText:SetText("|cffff4444" .. C.L.riMissingCount:format(data.missingGems) .. "|r")
        else
            r.gemsText:SetText("|cff33ff66" .. C.L.riStatusOK .. "|r")
        end
    end
    r:Show()
end

local function RefreshList()
    if not rowsChild then
        return
    end
    local units = GetGroupUnits()
    for i, unit in ipairs(units) do
        local name = UnitName(unit) or "?"
        RefreshRow(i, unit, name)
    end
    for i = #units + 1, #rows do
        rows[i]:Hide()
    end

    local count = #units
    local childHeight = math.max(ROW_H, count * ROW_H)
    rowsChild:SetHeight(childHeight)
    if scrollFrame then
        local visibleHeight = math.min(count * ROW_H, MAX_SCROLL_HEIGHT)
        scrollFrame:SetHeight(math.max(ROW_H, visibleHeight))
    end
    if C.RequestResize then
        C.RequestResize()
    end
end

local function StopInspectQueue()
    inspecting = false
    if pendingTimeout then
        pendingTimeout:Cancel()
        pendingTimeout = nil
    end
    if inventorySettleTimer then
        inventorySettleTimer:Cancel()
        inventorySettleTimer = nil
    end
    if inventoryCapTimer then
        inventoryCapTimer:Cancel()
        inventoryCapTimer = nil
    end
    pendingGUID = nil
    pendingQueueIndex = 0
    if inspectButton then
        inspectButton:SetText(C.L.riInspectButton)
        inspectButton:Enable()
    end
    ClearInspectPlayer()
end

local function InspectNext()
    queueIndex = queueIndex + 1
    local unit = queue[queueIndex]
    if not unit then
        StopInspectQueue()
        local inspected, total = 0, #queue
        for _, u in ipairs(queue) do
            if results[u] and not results[u].status then
                inspected = inspected + 1
            end
        end
        if statusText then
            statusText:SetText(C.L.riDone:format(inspected, total))
        end
        return
    end

    if not UnitExists(unit) or not CanInspect(unit, true) then
        results[unit] = { status = "outofrange" }
        RefreshList()
        C_Timer.After(0.2, InspectNext)
        return
    end

    pendingGUID = UnitGUID(unit)
    pendingQueueIndex = queueIndex
    local requestGUID = pendingGUID
    local requestQueueIndex = queueIndex
    NotifyInspect(unit)

    if pendingTimeout then
        pendingTimeout:Cancel()
    end
    pendingTimeout = C_Timer.NewTimer(5, function()
        pendingTimeout = nil
        if not inspecting or pendingGUID ~= requestGUID or queueIndex ~= requestQueueIndex then
            return
        end
        pendingGUID = nil
        pendingQueueIndex = 0
        ClearInspectPlayer()
        results[unit] = { status = "timeout" }
        RefreshList()
        C_Timer.After(1.8, InspectNext)
    end)
end

local function FinalizeInspect(unit, guid)
    if not inspecting or pendingGUID ~= guid or queue[queueIndex] ~= unit or pendingQueueIndex ~= queueIndex then
        return
    end
    if inventorySettleTimer then
        inventorySettleTimer:Cancel()
        inventorySettleTimer = nil
    end
    if inventoryCapTimer then
        inventoryCapTimer:Cancel()
        inventoryCapTimer = nil
    end
    pendingGUID = nil
    pendingQueueIndex = 0
    if unit and UnitExists(unit) and UnitGUID(unit) == guid then
        results[unit] = CollectUnitData(unit)
    end
    ClearInspectPlayer()
    RefreshList()
    C_Timer.After(1.8, InspectNext)
end

local function OnInspectReady(guid)
    if not inspecting or guid ~= pendingGUID or queue[queueIndex] == nil or pendingQueueIndex ~= queueIndex then
        return
    end
    if pendingTimeout then
        pendingTimeout:Cancel()
        pendingTimeout = nil
    end
    local unit = queue[queueIndex]

    if inventorySettleTimer then
        inventorySettleTimer:Cancel()
    end
    if inventoryCapTimer then
        inventoryCapTimer:Cancel()
    end
    inventorySettleTimer = C_Timer.NewTimer(0.3, function()
        inventorySettleTimer = nil
        FinalizeInspect(unit, guid)
    end)
    inventoryCapTimer = C_Timer.NewTimer(1.5, function()
        inventoryCapTimer = nil
        FinalizeInspect(unit, guid)
    end)
end

local function OnUnitInventoryChanged(unit)
    if not inspecting or not pendingGUID then
        return
    end
    local expected = queue[queueIndex]
    if unit ~= expected then
        return
    end
    if inventorySettleTimer then
        local guid = pendingGUID
        inventorySettleTimer:Cancel()
        inventorySettleTimer = C_Timer.NewTimer(0.3, function()
            inventorySettleTimer = nil
            FinalizeInspect(unit, guid)
        end)
    end
end

local function StartInspectQueue()
    if inspecting then
        return
    end
    if not (IsInRaid() or IsInGroup()) then
        print("|cffff6666[CC RaidTools]|r " .. C.L.riNeedGroup)
        return
    end
    queue = GetGroupUnits()
    queueIndex = 0
    pendingGUID = nil
    pendingQueueIndex = 0
    wipe(results)
    inspecting = true
    if inspectButton then
        inspectButton:SetText(C.L.riInspectingButton)
        inspectButton:Disable()
    end
    if statusText then
        statusText:SetText("")
    end
    RefreshList()
    InspectNext()
end

local function BuildUI(f)
    panelRef = f
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
    label:SetText(C.L.riLabel)
    label:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    inspectButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    inspectButton:SetSize(150, 24)
    inspectButton:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -10)
    inspectButton:SetText(C.L.riInspectButton)
    C.SkinButton(inspectButton)
    inspectButton:SetScript("OnClick", StartInspectQueue)

    statusText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("LEFT", inspectButton, "RIGHT", 10, 0)

    local h = CreateFrame("Frame", nil, f)
    h:SetPoint("TOPLEFT", inspectButton, "BOTTOMLEFT", -6, -14)
    h:SetSize(390, 18)
    local function H(txt, x, w, j)
        local hf = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hf:SetPoint("LEFT", x, 0)
        hf:SetWidth(w)
        hf:SetJustifyH(j or "CENTER")
        hf:SetText(txt)
        hf:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
        return hf
    end
    H(C.L.riColName, 4, 150, "LEFT")
    H(C.L.riColIlvl, 160, 55)
    H(C.L.riColEnchants, 222, 95)
    H(C.L.riColGems, 324, 95)

    scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 6, -4)
    scrollFrame:SetSize(420, ROW_H)
    C.SkinScrollBar(scrollFrame)
    -- Push the scrollbar further right, off the last text column, into the
    -- unused margin on the right side of the panel.
    if scrollFrame.ScrollBar then
        scrollFrame.ScrollBar:ClearAllPoints()
        scrollFrame.ScrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 26, -18)
        scrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 26, 18)
    end
    rowsChild = CreateFrame("Frame", nil, scrollFrame)
    rowsChild:SetSize(414, ROW_H)
    scrollFrame:SetScrollChild(rowsChild)
end

C.RegisterModule("RaidInspect", BuildUI, function()
    if C.RequestResize then
        C.RequestResize()
    end
end)

local e = CreateFrame("Frame")
e:RegisterEvent("INSPECT_READY")
e:RegisterEvent("UNIT_INVENTORY_CHANGED")
e:SetScript("OnEvent", function(_, ev, arg1)
    if ev == "INSPECT_READY" then
        OnInspectReady(arg1)
    elseif ev == "UNIT_INVENTORY_CHANGED" then
        OnUnitInventoryChanged(arg1)
    end
end)