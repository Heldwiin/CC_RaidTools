-- CC RaidTools - Raid Inspect
-- On-demand inspection of raid/party members for item level, enchants and gems.
local C = CCRT

local panelRef
local rows = {}

local ROW_H = 18
local MAX_SCROLL_HEIGHT = 20 * ROW_H

local inspecting = false
local queue = {}
local queueIndex = 0
local results = {} -- keyed by unit GUID, never by party/raid token

local pendingGUID
local pendingQueueIndex = 0
local pendingTimeout
local inventorySettleTimer
local inventoryCapTimer

local inspectButton
local statusText
local scrollFrame
local rowsChild

local ENCHANT_SLOTS = {
    INVSLOT_HEAD,
    INVSLOT_SHOULDER,
    INVSLOT_FINGER1,
    INVSLOT_FINGER2,
    INVSLOT_CHEST,
    INVSLOT_LEGS,      -- Missing from the previous list: leg enchant/armor enchant.
    INVSLOT_FEET,
    INVSLOT_MAINHAND,
    INVSLOT_OFFHAND,
}

local SLOT_NAME_KEYS = {
    [INVSLOT_HEAD] = "riSlotHead",
    [INVSLOT_SHOULDER] = "riSlotShoulder",
    [INVSLOT_FINGER1] = "riSlotFinger1",
    [INVSLOT_FINGER2] = "riSlotFinger2",
    [INVSLOT_CHEST] = "riSlotChest",
    [INVSLOT_FEET] = "riSlotFeet",
    [INVSLOT_MAINHAND] = "riSlotMainHand",
    [INVSLOT_OFFHAND] = "riSlotOffHand",
    [INVSLOT_LEGS] = "riSlotLegs",
    [INVSLOT_NECK] = "riSlotNeck",
    [INVSLOT_WAIST] = "riSlotWaist",
    [INVSLOT_WRIST] = "riSlotWrist",
    [INVSLOT_HAND] = "riSlotHands",
    [INVSLOT_BACK] = "riSlotBack",
    [INVSLOT_TRINKET1] = "riSlotTrinket1",
    [INVSLOT_TRINKET2] = "riSlotTrinket2",
}

local ALL_SLOTS = {}
for i = 1, 19 do
    ALL_SLOTS[#ALL_SLOTS + 1] = i
end

local emptySocketTexts

local function CancelInspectSettleTimers()
    if inventorySettleTimer then
        inventorySettleTimer:Cancel()
        inventorySettleTimer = nil
    end
    if inventoryCapTimer then
        inventoryCapTimer:Cancel()
        inventoryCapTimer = nil
    end
end

local function SlotName(slot)
    local key = SLOT_NAME_KEYS[slot]
    return key and C.L[key] or ("#" .. tostring(slot))
end

local function GetEmptySocketTexts()
    if emptySocketTexts then
        return emptySocketTexts
    end

    emptySocketTexts = {}
    for key, value in pairs(_G) do
        if type(key) == "string" and type(value) == "string" and value ~= "" and key:match("^EMPTY_SOCKET_") then
            emptySocketTexts[value] = true
        end
    end

    return emptySocketTexts
end

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

local function GetInventoryLink(unit, slot)
    if not GetInventoryItemLink then
        return nil
    end

    local ok, link = pcall(GetInventoryItemLink, unit, slot)
    return ok and SafeText(link) or nil
end

local function HasInventoryItem(unit, slot)
    return GetInventoryLink(unit, slot) ~= nil
end

local function IsOffhandWeapon(unit, slot)
    local link = GetInventoryLink(unit, slot)
    if not link then
        return false
    end

    local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, link)
    return ok and classID == Enum.ItemClass.Weapon
end

-- Blizzard exposes one GemSocket line per socket. gemIcon on that line tells
-- us whether that specific socket is occupied. This is important when a piece
-- contains a mixture of filled and empty sockets.
local function CountEmptySocketsOnSlot(unit, slot)
    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then
        return nil
    end

    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, unit, slot)
    if not ok or not data or not data.lines then
        return nil
    end

    SurfaceTooltipData(data)

    local lineTypes = Enum and Enum.TooltipDataLineType
    local gemSocketType = lineTypes and lineTypes.GemSocket
    if not gemSocketType then
        return nil
    end

    local socketCount = 0
    local emptyCount = 0
    local unknownCount = 0

    for _, line in ipairs(data.lines) do
        if line.type == gemSocketType then
            socketCount = socketCount + 1

            -- Blizzard's current TooltipData GemSocket line exposes either:
            --   gemIcon   -> occupied socket
            --   socketType -> empty socket
            -- Do not infer socket state from GemSocketEnchantment line count:
            -- that is a separate tooltip line and is not a 1:1 socket map.
            local gemIcon = SafeText(line.gemIcon)
            local socketType = SafeText(line.socketType)

            if gemIcon then
                -- Filled socket.
            elseif socketType then
                emptyCount = emptyCount + 1
            else
                unknownCount = unknownCount + 1
            end
        end
    end

    if socketCount == 0 then
        return 0
    end

    if unknownCount > 0 then
        return nil
    end

    return emptyCount
end

local function HasEnchantFromItemLink(unit, slot)
    local link = GetInventoryLink(unit, slot)
    if not link then
        return nil
    end

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

-- Inspect data can briefly contain stale item-link information immediately
-- after INSPECT_READY. Prefer Blizzard's structured tooltip result and only
-- use the item link when structured data is unavailable.
local function HasEnchantOnSlot(unit, slot)
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, data = pcall(C_TooltipInfo.GetInventoryItem, unit, slot)
        if ok and data and data.lines then
            SurfaceTooltipData(data)

            local lineTypes = Enum and Enum.TooltipDataLineType
            local permanentEnchantType = lineTypes and lineTypes.ItemEnchantmentPermanent
            if permanentEnchantType then
                local sawStructuredEnchantData = false

                for _, line in ipairs(data.lines) do
                    if line.type == permanentEnchantType then
                        return true
                    end

                    -- Blizzard/other addons expose the enchant ID directly on
                    -- ItemEnchantmentPermanent lines in current TooltipData.
                    local enchantID = SafeText(line.enchantID)
                    if enchantID ~= nil then
                        sawStructuredEnchantData = true
                        if tonumber(enchantID) and tonumber(enchantID) > 0 then
                            return true
                        end
                    end
                end

                -- A complete tooltip with no enchant line is a confirmed
                -- unenchanted item. If we did not get enough structured data to
                -- make that determination, keep it unknown and let the caller
                -- revalidate instead of reporting a false negative.
                if #data.lines > 1 then
                    return false
                end
                return nil
            end

            local fmt = _G.ENCHANTED_TOOLTIP_LINE
            local prefix = fmt and fmt:match("^(.-)%%s")
            if prefix and prefix ~= "" then
                local pattern = "^" .. prefix:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
                local sawText = false

                for _, line in ipairs(data.lines) do
                    local leftText = SafeText(line.leftText)
                    if leftText then
                        sawText = true
                        if leftText:find(pattern) then
                            return true
                        end
                    end
                end

                if sawText then
                    return false
                end
            end
        end
    end

    return HasEnchantFromItemLink(unit, slot)
end

local function CollectUnitData(unit)
    local data = {
        missingEnchants = 0,
        missingGems = 0,
        ilvl = 0,
        missingEnchantSlots = {},
        missingGemSlots = {},
        uncertainEnchantSlots = {},
        uncertainGemSlots = {},
        uncertainItemLevel = false,
    }

    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local ok, ilvl = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
        if ok and ilvl and (not issecretvalue or not issecretvalue(ilvl)) and (not canaccessvalue or canaccessvalue(ilvl)) then
            data.ilvl = math.floor(ilvl + 0.5)
        end
    end
    if data.ilvl <= 0 then
        data.uncertainItemLevel = true
    end

    for _, slot in ipairs(ENCHANT_SLOTS) do
        local isOffhand = slot == INVSLOT_OFFHAND
        if HasInventoryItem(unit, slot) and (not isOffhand or IsOffhandWeapon(unit, slot)) then
            local enchantState = HasEnchantOnSlot(unit, slot)
            if enchantState == false then
                data.missingEnchants = data.missingEnchants + 1
                data.missingEnchantSlots[#data.missingEnchantSlots + 1] = SlotName(slot)
            elseif enchantState == nil then
                data.uncertainEnchantSlots[#data.uncertainEnchantSlots + 1] = SlotName(slot)
            end
        end
    end

    for _, slot in ipairs(ALL_SLOTS) do
        if HasInventoryItem(unit, slot) then
            local missing = CountEmptySocketsOnSlot(unit, slot)
            if missing == nil then
                data.uncertainGemSlots[#data.uncertainGemSlots + 1] = SlotName(slot)
            elseif missing > 0 then
                data.missingGems = data.missingGems + missing
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

local function GetUnitGUID(unit)
    return unit and UnitGUID(unit)
end

local function GetResult(unit)
    local guid = GetUnitGUID(unit)
    return guid and results[guid] or nil
end

local function IsBlizzardInspectActive()
    local inspectFrameActive = InspectFrame and InspectFrame:IsShown()
    local playerSpellsInspectActive = PlayerSpellsFrame and PlayerSpellsFrame.IsInspecting and PlayerSpellsFrame:IsInspecting()
    return inspectFrameActive or playerSpellsInspectActive
end

local function NewRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(420, ROW_H)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_H)

    local function CreateText(x, width, justify)
        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", x, 0)
        text:SetWidth(width)
        text:SetJustifyH(justify or "CENTER")
        text:SetWordWrap(false)
        return text
    end

    row.nameText = CreateText(4, 150, "LEFT")
    row.ilvlText = CreateText(160, 55)
    row.enchantsText = CreateText(222, 95)
    row.gemsText = CreateText(324, 95)

    local function CreateHoverZone(anchor, getLines)
        local zone = CreateFrame("Frame", nil, row)
        zone:SetPoint("LEFT", anchor)
        zone:SetSize(95, ROW_H)
        zone:EnableMouse(true)

        zone:SetScript("OnEnter", function(self)
            local lines = getLines()
            if not lines or #lines == 0 then
                return
            end

            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(lines.header)
            for _, text in ipairs(lines) do
                GameTooltip:AddLine("- " .. text, 1, 1, 1)
            end
            GameTooltip:Show()
        end)

        zone:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        return zone
    end

    row.enchantsHover = CreateHoverZone(row.enchantsText, function()
        local data = GetResult(row._ccrtUnit)
        if not data then
            return nil
        end

        if data.missingEnchantSlots and #data.missingEnchantSlots > 0 then
            local lines = { header = C.L.riMissingEnchantTooltip }
            for _, slotName in ipairs(data.missingEnchantSlots) do
                lines[#lines + 1] = slotName
            end
            return lines
        end

        if data.uncertainEnchantSlots and #data.uncertainEnchantSlots > 0 then
            local lines = { header = C.L.riStatusWaiting }
            for _, slotName in ipairs(data.uncertainEnchantSlots) do
                lines[#lines + 1] = slotName .. " : données non confirmées"
            end
            return lines
        end

        return nil
    end)

    row.gemsHover = CreateHoverZone(row.gemsText, function()
        local data = GetResult(row._ccrtUnit)
        if not data then
            return nil
        end

        if data.missingGemSlots and #data.missingGemSlots > 0 then
            local lines = { header = C.L.riMissingGemTooltip }
            for _, slotName in ipairs(data.missingGemSlots) do
                lines[#lines + 1] = slotName
            end
            return lines
        end

        if data.uncertainGemSlots and #data.uncertainGemSlots > 0 then
            local lines = { header = C.L.riStatusWaiting }
            for _, slotName in ipairs(data.uncertainGemSlots) do
                lines[#lines + 1] = slotName .. " : données non confirmées"
            end
            return lines
        end

        return nil
    end)

    return row
end

local function RefreshRow(index, unit, name)
    local row = rows[index] or NewRow(rowsChild, index)
    rows[index] = row
    row._ccrtUnit = unit

    local _, class = UnitClass(unit)
    local classColor = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if classColor then
        row.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        row.nameText:SetTextColor(1, 1, 1)
    end

    row.nameText:SetText(C.StripRealm(name))

    local data = GetResult(unit)
    if not data then
        row.ilvlText:SetText("|cffff9900" .. C.L.riStatusWaiting .. "|r")
        row.enchantsText:SetText("")
        row.gemsText:SetText("")
    elseif data.status == "outofrange" then
        row.ilvlText:SetText("|cffff4444" .. C.L.riStatusOutOfRange .. "|r")
        row.enchantsText:SetText("")
        row.gemsText:SetText("")
    elseif data.status == "timeout" then
        row.ilvlText:SetText("|cffff4444" .. C.L.riStatusTimeout .. "|r")
        row.enchantsText:SetText("")
        row.gemsText:SetText("")
    else
        row.ilvlText:SetText(tostring(data.ilvl or "?"))

        local uncertainEnchants = #(data.uncertainEnchantSlots or {})
        if (data.missingEnchants or 0) > 0 then
            row.enchantsText:SetText("|cffff4444" .. C.L.riMissingCount:format(data.missingEnchants) .. "|r")
        elseif uncertainEnchants > 0 then
            row.enchantsText:SetText("|cffff9900...|r")
        else
            row.enchantsText:SetText("|cff33ff66" .. C.L.riStatusOK .. "|r")
        end

        local uncertainGems = #(data.uncertainGemSlots or {})
        if (data.missingGems or 0) > 0 then
            row.gemsText:SetText("|cffff4444" .. C.L.riMissingCount:format(data.missingGems) .. "|r")
        elseif uncertainGems > 0 then
            row.gemsText:SetText("|cffff9900...|r")
        else
            row.gemsText:SetText("|cff33ff66" .. C.L.riStatusOK .. "|r")
        end
    end

    row:Show()
end

local function RefreshList()
    if not rowsChild then
        return
    end

    local units = GetGroupUnits()
    for index, unit in ipairs(units) do
        RefreshRow(index, unit, UnitName(unit) or "?")
    end

    for index = #units + 1, #rows do
        rows[index]:Hide()
    end

    local count = #units
    rowsChild:SetHeight(math.max(ROW_H, count * ROW_H))
    if scrollFrame then
        scrollFrame:SetHeight(math.max(ROW_H, math.min(count * ROW_H, MAX_SCROLL_HEIGHT)))
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
    CancelInspectSettleTimers()

    pendingGUID = nil
    pendingQueueIndex = 0

    if inspectButton then
        inspectButton:SetText(C.L.riInspectButton)
        inspectButton:Enable()
    end

    if not IsBlizzardInspectActive() then
        ClearInspectPlayer()
    end
end

local function InspectNext()
    queueIndex = queueIndex + 1
    local unit = queue[queueIndex]

    if not unit then
        StopInspectQueue()

        local inspected = 0
        local total = #queue
        for _, queuedUnit in ipairs(queue) do
            local guid = GetUnitGUID(queuedUnit)
            if guid and results[guid] and not results[guid].status then
                inspected = inspected + 1
            end
        end

        if statusText then
            statusText:SetText(C.L.riDone:format(inspected, total))
        end
        return
    end

    if not UnitExists(unit) or not CanInspect(unit, true) then
        local guid = GetUnitGUID(unit)
        if guid then
            results[guid] = { status = "outofrange" }
        end
        RefreshList()
        C_Timer.After(0.2, InspectNext)
        return
    end

    pendingGUID = GetUnitGUID(unit)
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
        if not IsBlizzardInspectActive() then
            ClearInspectPlayer()
        end

        if requestGUID then
            results[requestGUID] = { status = "timeout" }
        end

        RefreshList()
        C_Timer.After(1.8, InspectNext)
    end)
end

local function FinalizeInspect(unit, guid)
    if not inspecting or pendingGUID ~= guid or queue[queueIndex] ~= unit or pendingQueueIndex ~= queueIndex then
        return
    end

    CancelInspectSettleTimers()

    pendingGUID = nil
    pendingQueueIndex = 0

    local firstPass = nil
    if unit and UnitExists(unit) and UnitGUID(unit) == guid then
        firstPass = CollectUnitData(unit)
        results[guid] = firstPass
    end
    RefreshList()

    -- Only re-read when the first pass contains a warning or incomplete data.
    -- A clean, fully-known result stays fast; a suspicious result gets one
    -- targeted stabilization pass before we trust it.
    local needsRecheck = firstPass and (
        (firstPass.missingEnchants or 0) > 0
        or (firstPass.missingGems or 0) > 0
        or #(firstPass.uncertainEnchantSlots or {}) > 0
        or #(firstPass.uncertainGemSlots or {}) > 0
        or firstPass.uncertainItemLevel
    )

    if needsRecheck then
        C_Timer.After(0.4, function()
            if unit and UnitExists(unit) and UnitGUID(unit) == guid then
                local secondPass = CollectUnitData(unit)
                local firstUnknown = #(firstPass.uncertainEnchantSlots or {}) + #(firstPass.uncertainGemSlots or {})
                    + (firstPass.uncertainItemLevel and 1 or 0)
                local secondUnknown = #(secondPass.uncertainEnchantSlots or {}) + #(secondPass.uncertainGemSlots or {})
                    + (secondPass.uncertainItemLevel and 1 or 0)
                if secondUnknown < firstUnknown
                    or (secondPass.missingEnchants or 0) < (firstPass.missingEnchants or 0)
                    or (secondPass.missingGems or 0) < (firstPass.missingGems or 0)
                    or firstUnknown == 0 then
                    results[guid] = secondPass
                    RefreshList()
                end
            end
            if not IsBlizzardInspectActive() then
                ClearInspectPlayer()
            end
            C_Timer.After(1.8, InspectNext)
        end)
        return
    end

    if not IsBlizzardInspectActive() then
        ClearInspectPlayer()
    end
    C_Timer.After(1.8, InspectNext)
end

local function ScheduleInventorySettle(unit, guid)
    if inventorySettleTimer then
        inventorySettleTimer:Cancel()
    end

    -- Remote inspect data can arrive in several pieces. Give Blizzard a little
    -- more time than the old 0.3s delay before taking the final snapshot.
    inventorySettleTimer = C_Timer.NewTimer(0.8, function()
        inventorySettleTimer = nil
        FinalizeInspect(unit, guid)
    end)
end

local function OnInspectReady(guid)
    if not inspecting or guid ~= pendingGUID or not queue[queueIndex] or pendingQueueIndex ~= queueIndex then
        return
    end

    if pendingTimeout then
        pendingTimeout:Cancel()
        pendingTimeout = nil
    end

    local unit = queue[queueIndex]

    if inventoryCapTimer then
        inventoryCapTimer:Cancel()
    end

    ScheduleInventorySettle(unit, guid)

    -- Safety cap: never leave a player stuck in the inspection queue because
    -- UNIT_INVENTORY_CHANGED or tooltip data never settles.
    inventoryCapTimer = C_Timer.NewTimer(2.0, function()
        inventoryCapTimer = nil
        FinalizeInspect(unit, guid)
    end)
end

local function OnUnitInventoryChanged(unit)
    if not inspecting or not pendingGUID or unit ~= queue[queueIndex] then
        return
    end

    ScheduleInventorySettle(unit, pendingGUID)
end

local function StartInspectQueue()
    if inspecting then
        return
    end

    -- Blizzard inspect APIs are protected during combat. Never start an
    -- inspection queue while in combat; the queue is also cancelled as soon
    -- as combat starts so it cannot remain stuck waiting for INSPECT_READY.
    if InCombatLockdown() then
        if statusText then
            statusText:SetText(C.L.riCombatBlocked)
        end
        return
    end

    if IsBlizzardInspectActive() then
        if statusText then
            statusText:SetText(C.L.riStatusWaiting)
        end
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

local function BuildUI(frame)
    panelRef = frame

    -- Closing the CC RaidTools window must cancel an active inspection queue.
    -- Without this, the queue keeps waiting for INSPECT_READY/timers while the
    -- panel is hidden, leaving the button stuck on "Inspecting..." until /reload.
    frame:SetScript("OnHide", function()
        if inspecting then
            StopInspectQueue()
            if statusText then
                statusText:SetText("")
            end
        end
    end)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
    label:SetText(C.L.riLabel)
    label:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    inspectButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    inspectButton:SetSize(150, 24)
    inspectButton:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -10)
    inspectButton:SetText(C.L.riInspectButton)
    C.SkinButton(inspectButton)
    inspectButton:SetScript("OnClick", StartInspectQueue)
    if InCombatLockdown() then
        inspectButton:Disable()
    end

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("LEFT", inspectButton, "RIGHT", 10, 0)

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", inspectButton, "BOTTOMLEFT", -6, -14)
    header:SetSize(390, 18)

    local function HeaderText(text, x, width, justify)
        local fontString = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fontString:SetPoint("LEFT", x, 0)
        fontString:SetWidth(width)
        fontString:SetJustifyH(justify or "CENTER")
        fontString:SetText(text)
        fontString:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
    end

    HeaderText(C.L.riColName, 4, 150, "LEFT")
    HeaderText(C.L.riColIlvl, 160, 55)
    HeaderText(C.L.riColEnchants, 222, 95)
    HeaderText(C.L.riColGems, 324, 95)

    scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 6, -4)
    scrollFrame:SetSize(420, ROW_H)
    C.SkinScrollBar(scrollFrame)

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

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("INSPECT_READY")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_REGEN_DISABLED" then
        if inspecting then
            StopInspectQueue()
        end
        if inspectButton then
            inspectButton:SetText(C.L.riInspectButton)
            inspectButton:Disable()
        end
        if statusText then
            statusText:SetText(C.L.riCombatBlocked)
        end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        if inspectButton and not inspecting then
            inspectButton:SetText(C.L.riInspectButton)
            inspectButton:Enable()
        end
        return
    end

    if event == "INSPECT_READY" then
        OnInspectReady(arg1)
    elseif event == "UNIT_INVENTORY_CHANGED" then
        OnUnitInventoryChanged(arg1)
    elseif event == "GROUP_ROSTER_UPDATE" then
        if inspecting then
            -- Reconcile the active queue by GUID instead of restarting it.
            -- partyX/raidX tokens can change when someone joins or leaves.
            local currentUnits = GetGroupUnits()
            local currentByGUID = {}
            local pendingUnit

            for _, unit in ipairs(currentUnits) do
                local guid = GetUnitGUID(unit)
                if guid then
                    currentByGUID[guid] = unit
                    if guid == pendingGUID then
                        pendingUnit = unit
                    end
                end
            end

            if pendingGUID and pendingUnit then
                -- Keep the active request alive, but update its unit token.
                queue[queueIndex] = pendingUnit
            elseif pendingGUID then
                -- The player being inspected left. Cancel only that request;
                -- completed results remain valid.
                if pendingTimeout then
                    pendingTimeout:Cancel()
                    pendingTimeout = nil
                end
                CancelInspectSettleTimers()
                pendingGUID = nil
                pendingQueueIndex = 0
                C_Timer.After(0, InspectNext)
            end

            -- Keep the active request first, then append only members that do
            -- not already have a result. This adds newcomers without rescanning
            -- everyone who has already been inspected.
            local newQueue = {}
            local newIndex = 0

            if pendingGUID and currentByGUID[pendingGUID] then
                newIndex = newIndex + 1
                newQueue[newIndex] = currentByGUID[pendingGUID]
            end

            for _, unit in ipairs(currentUnits) do
                local guid = GetUnitGUID(unit)
                if guid and not results[guid] and guid ~= pendingGUID then
                    newIndex = newIndex + 1
                    newQueue[newIndex] = unit
                end
            end

            queue = newQueue
            queueIndex = 0
            if pendingGUID then
                for index, unit in ipairs(queue) do
                    if GetUnitGUID(unit) == pendingGUID then
                        queueIndex = index - 1
                        break
                    end
                end
            end
        else
            RefreshList()
        end
    end
end)
