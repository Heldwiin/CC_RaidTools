-- CC RaidTools - Raid Inspect
-- Inspects raid/party members for item level, missing enchants and empty gem sockets.
local C = CCRT

local panelRef, rows = nil, {}
local ROW_H = 18
local MAX_SCROLL_HEIGHT = 20 * ROW_H
local inspecting = false
local queue = {}
local queueIndex = 0
local pendingGUID, pendingTimeout
local pendingQueueIndex = 0
local inventorySettleTimer, inventoryCapTimer
local results = {}
local inspectButton, statusText, scrollFrame, rowsChild

local ENCHANT_SLOTS = { INVSLOT_HEAD, INVSLOT_SHOULDER, INVSLOT_FINGER1, INVSLOT_FINGER2, INVSLOT_CHEST, INVSLOT_FEET, INVSLOT_MAINHAND, INVSLOT_OFFHAND }
local SLOT_NAME_KEYS = {
    [INVSLOT_HEAD] = "riSlotHead", [INVSLOT_SHOULDER] = "riSlotShoulder", [INVSLOT_FINGER1] = "riSlotFinger1", [INVSLOT_FINGER2] = "riSlotFinger2",
    [INVSLOT_CHEST] = "riSlotChest", [INVSLOT_FEET] = "riSlotFeet", [INVSLOT_MAINHAND] = "riSlotMainHand", [INVSLOT_OFFHAND] = "riSlotOffHand",
    [INVSLOT_NECK] = "riSlotNeck", [INVSLOT_WAIST] = "riSlotWaist", [INVSLOT_WRIST] = "riSlotWrist", [INVSLOT_HAND] = "riSlotHands",
    [INVSLOT_LEGS] = "riSlotLegs", [INVSLOT_BACK] = "riSlotBack", [INVSLOT_TRINKET1] = "riSlotTrinket1", [INVSLOT_TRINKET2] = "riSlotTrinket2",
}
local function SlotName(slot)
    local key = SLOT_NAME_KEYS[slot]
    return key and C.L[key] or ("#" .. tostring(slot))
end
local ALL_SLOTS = {}
for i = 1, 19 do ALL_SLOTS[#ALL_SLOTS + 1] = i end

local emptySocketTexts
local function GetEmptySocketTexts()
    if emptySocketTexts then return emptySocketTexts end
    emptySocketTexts = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "string" and v ~= "" and k:match("^EMPTY_SOCKET_") then emptySocketTexts[v] = true end
    end
    return emptySocketTexts
end
local function SurfaceTooltipData(data)
    if not data or not TooltipUtil or not TooltipUtil.SurfaceArgs then return end
    pcall(TooltipUtil.SurfaceArgs, data)
    if data.lines then for _, line in ipairs(data.lines) do pcall(TooltipUtil.SurfaceArgs, line) end end
end
local function SafeText(value)
    if value == nil then return nil end
    if issecretvalue and issecretvalue(value) then return nil end
    if canaccessvalue and not canaccessvalue(value) then return nil end
    return value
end
local function GetInventoryLink(unit, slot)
    if not GetInventoryItemLink then return nil end
    local ok, link = pcall(GetInventoryItemLink, unit, slot)
    return ok and SafeText(link) or nil
end
local function HasInventoryItem(unit, slot) return GetInventoryLink(unit, slot) ~= nil end
local function IsOffhandWeapon(unit, slot)
    local link = GetInventoryLink(unit, slot)
    if not link then return false end
    local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, link)
    return ok and classID == Enum.ItemClass.Weapon
end

-- GemSocket is emitted once per socket. gemIcon on that same line tells us
-- whether that particular socket is occupied. Do not use GemSocketEnchantment
-- when gemIcon data is available: mixed filled/empty sockets must be counted
-- from the individual GemSocket lines themselves.
local function CountEmptySocketsOnSlot(unit, slot)
    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then return 0 end
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, unit, slot)
    if not ok or not data or not data.lines then return 0 end
    SurfaceTooltipData(data)

    local lineTypes = Enum and Enum.TooltipDataLineType
    local gemSocketType = lineTypes and lineTypes.GemSocket
    local gemEnchantmentType = lineTypes and lineTypes.GemSocketEnchantment

    if gemSocketType then
        local socketCount = 0
        local filledCount = 0
        local emptyCount = 0
        local unknownCount = 0
        local filledByEnchantment = 0

        for _, line in ipairs(data.lines) do
            if line.type == gemSocketType then
                socketCount = socketCount + 1
                local gemIcon = SafeText(line.gemIcon)
                if gemIcon ~= nil then
                    if gemIcon then
                        filledCount = filledCount + 1
                    else
                        emptyCount = emptyCount + 1
                    end
                else
                    unknownCount = unknownCount + 1
                end
            elseif gemEnchantmentType and line.type == gemEnchantmentType then
                filledByEnchantment = filledByEnchantment + 1
            end
        end

        if socketCount > 0 then
            if unknownCount == 0 then
                return emptyCount
            end

            -- If Blizzard did not expose gemIcon for some sockets, retain the
            -- previous structured fallback for the unknown sockets only.
            local knownFilled = filledCount
            local knownEmpty = emptyCount
            local fallbackFilled = math.min(filledByEnchantment, unknownCount)
            local fallbackEmpty = unknownCount - fallbackFilled
            return knownEmpty + fallbackEmpty
        end
    end

    local texts, n = GetEmptySocketTexts(), 0
    for _, line in ipairs(data.lines) do
        local leftText = SafeText(line.leftText)
        if leftText and texts[leftText] then n = n + 1 end
    end
    return n
end

local function HasEnchantFromItemLink(unit, slot)
    local link = GetInventoryLink(unit, slot)
    if not link then return nil end
    local itemID, enchantField = link:match("|Hitem:(%d+):([^:]*)")
    if not itemID then itemID, enchantField = link:match("item:(%d+):([^:]*)") end
    if not itemID then return nil end
    local enchantID = tonumber(enchantField)
    if enchantID and enchantID > 0 then return true end
    if enchantField == "" or enchantID == 0 then return false end
    return nil
end
local function HasEnchantOnSlot(unit, slot)
    local fromLink = HasEnchantFromItemLink(unit, slot)
    if fromLink ~= nil then return fromLink end
    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then return nil end
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, unit, slot)
    if not ok or not data or not data.lines then return nil end
    SurfaceTooltipData(data)
    local lineTypes = Enum and Enum.TooltipDataLineType
    local permanentEnchantType = lineTypes and lineTypes.ItemEnchantmentPermanent
    if permanentEnchantType then for _, line in ipairs(data.lines) do if line.type == permanentEnchantType then return true end end end
    local fmt = _G.ENCHANTED_TOOLTIP_LINE
    local prefix = fmt and fmt:match("^(.-)%%s")
    if prefix and prefix ~= "" then
        local pattern = "^" .. prefix:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        for _, line in ipairs(data.lines) do
            local leftText = SafeText(line.leftText)
            if leftText and leftText:find(pattern) then return true end
        end
    end
    return false
end
local function CollectUnitData(unit)
    local data = { missingEnchants = 0, missingGems = 0, ilvl = 0, missingEnchantSlots = {}, missingGemSlots = {} }
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local ok, ilvl = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
        if ok and ilvl and (not issecretvalue or not issecretvalue(ilvl)) and (not canaccessvalue or canaccessvalue(ilvl)) then data.ilvl = math.floor(ilvl + 0.5) end
    end
    for _, slot in ipairs(ENCHANT_SLOTS) do
        local off = slot == INVSLOT_OFFHAND
        if HasInventoryItem(unit, slot) and (not off or IsOffhandWeapon(unit, slot)) and HasEnchantOnSlot(unit, slot) == false then
            data.missingEnchants = data.missingEnchants + 1
            data.missingEnchantSlots[#data.missingEnchantSlots + 1] = SlotName(slot)
        end
    end
    for _, slot in ipairs(ALL_SLOTS) do
        if HasInventoryItem(unit, slot) then
            local n = CountEmptySocketsOnSlot(unit, slot)
            if n > 0 then data.missingGems = data.missingGems + n; data.missingGemSlots[#data.missingGemSlots + 1] = SlotName(slot) end
        end
    end
    return data
end
local function GetGroupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() or 0 do units[#units + 1] = "raid" .. i end
    elseif IsInGroup() then
        units[#units + 1] = "player"
        for i = 1, 4 do if UnitExists("party" .. i) then units[#units + 1] = "party" .. i end end
    end
    return units
end
local function GetUnitGUID(unit) return unit and UnitGUID(unit) end
local function GetResult(unit)
    local guid = GetUnitGUID(unit)
    return guid and results[guid] or nil
end

local function IsBlizzardInspectActive()
    local inspectFrameActive = InspectFrame and InspectFrame:IsShown()
    local playerSpellsInspectActive = PlayerSpellsFrame and PlayerSpellsFrame.IsInspecting and PlayerSpellsFrame:IsInspecting()
    return inspectFrameActive or playerSpellsInspectActive
end

local function NewRow(parent, i)
    local r = CreateFrame("Frame", nil, parent); r:SetSize(420, ROW_H); r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    local function T(x, w, justify)
        local f = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f:SetPoint("LEFT", x, 0); f:SetWidth(w); f:SetJustifyH(justify or "CENTER"); f:SetWordWrap(false); return f
    end
    r.nameText, r.ilvlText, r.enchantsText, r.gemsText = T(4,150,"LEFT"), T(160,55), T(222,95), T(324,95)
    local function HoverZone(anchorText, getLines)
        local z = CreateFrame("Frame", nil, r); z:SetPoint("LEFT", anchorText); z:SetSize(95, ROW_H); z:EnableMouse(true)
        z:SetScript("OnEnter", function(self)
            local lines = getLines(); if not lines or #lines == 0 then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(lines.header); for _, s in ipairs(lines) do GameTooltip:AddLine("- " .. s,1,1,1) end; GameTooltip:Show()
        end); z:SetScript("OnLeave", function() GameTooltip:Hide() end); return z
    end
    r.enchantsHover = HoverZone(r.enchantsText, function()
        local data = GetResult(r._ccrtUnit); if not data or #data.missingEnchantSlots == 0 then return nil end
        local t = { header = C.L.riMissingEnchantTooltip }; for _, s in ipairs(data.missingEnchantSlots) do t[#t+1] = s end; return t
    end)
    r.gemsHover = HoverZone(r.gemsText, function()
        local data = GetResult(r._ccrtUnit); if not data or #data.missingGemSlots == 0 then return nil end
        local t = { header = C.L.riMissingGemTooltip }; for _, s in ipairs(data.missingGemSlots) do t[#t+1] = s end; return t
    end)
    return r
end
local function RefreshRow(i, unit, name)
    local r = rows[i] or NewRow(rowsChild, i); rows[i] = r; r._ccrtUnit = unit
    local _, class = UnitClass(unit); local col = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if col then r.nameText:SetTextColor(col.r,col.g,col.b) else r.nameText:SetTextColor(1,1,1) end
    r.nameText:SetText(C.StripRealm(name))
    local data = GetResult(unit)
    if not data then
        r.ilvlText:SetText("|cffff9900"..C.L.riStatusWaiting.."|r"); r.enchantsText:SetText(""); r.gemsText:SetText("")
    elseif data.status == "outofrange" then
        r.ilvlText:SetText("|cffff4444"..C.L.riStatusOutOfRange.."|r"); r.enchantsText:SetText(""); r.gemsText:SetText("")
    elseif data.status == "timeout" then
        r.ilvlText:SetText("|cffff4444"..C.L.riStatusTimeout.."|r"); r.enchantsText:SetText(""); r.gemsText:SetText("")
    else
        r.ilvlText:SetText(tostring(data.ilvl or "?"))
        r.enchantsText:SetText((data.missingEnchants or 0)>0 and ("|cffff4444"..C.L.riMissingCount:format(data.missingEnchants).."|r") or ("|cff33ff66"..C.L.riStatusOK.."|r"))
        r.gemsText:SetText((data.missingGems or 0)>0 and ("|cffff4444"..C.L.riMissingCount:format(data.missingGems).."|r") or ("|cff33ff66"..C.L.riStatusOK.."|r"))
    end
    r:Show()
end
local function RefreshList()
    if not rowsChild then return end
    local units = GetGroupUnits()
    for i, unit in ipairs(units) do RefreshRow(i, unit, UnitName(unit) or "?") end
    for i = #units + 1, #rows do rows[i]:Hide() end
    local count = #units; rowsChild:SetHeight(math.max(ROW_H,count*ROW_H)); if scrollFrame then scrollFrame:SetHeight(math.max(ROW_H,math.min(count*ROW_H,MAX_SCROLL_HEIGHT))) end
    if C.RequestResize then C.RequestResize() end
end
local function StopInspectQueue()
    inspecting=false
    if pendingTimeout then pendingTimeout:Cancel(); pendingTimeout=nil end
    if inventorySettleTimer then inventorySettleTimer:Cancel(); inventorySettleTimer=nil end
    if inventoryCapTimer then inventoryCapTimer:Cancel(); inventoryCapTimer=nil end
    pendingGUID=nil; pendingQueueIndex=0
    if inspectButton then inspectButton:SetText(C.L.riInspectButton); inspectButton:Enable() end
    if not IsBlizzardInspectActive() then ClearInspectPlayer() end
end
local function InspectNext()
    queueIndex=queueIndex+1; local unit=queue[queueIndex]
    if not unit then
        StopInspectQueue(); local inspected,total=0,#queue
        for _,u in ipairs(queue) do local g=GetUnitGUID(u); if g and results[g] and not results[g].status then inspected=inspected+1 end end
        if statusText then statusText:SetText(C.L.riDone:format(inspected,total)) end; return
    end
    if not UnitExists(unit) or not CanInspect(unit,true) then
        local g=GetUnitGUID(unit); if g then results[g]={status="outofrange"} end; RefreshList(); C_Timer.After(0.2,InspectNext); return
    end
    pendingGUID=GetUnitGUID(unit); pendingQueueIndex=queueIndex; local requestGUID=pendingGUID; local requestQueueIndex=queueIndex
    NotifyInspect(unit)
    if pendingTimeout then pendingTimeout:Cancel() end
    pendingTimeout=C_Timer.NewTimer(5,function()
        pendingTimeout=nil; if not inspecting or pendingGUID~=requestGUID or queueIndex~=requestQueueIndex then return end
        pendingGUID=nil; pendingQueueIndex=0
        if not IsBlizzardInspectActive() then ClearInspectPlayer() end
        if requestGUID then results[requestGUID]={status="timeout"} end
        RefreshList(); C_Timer.After(1.8,InspectNext)
    end)
end
local function FinalizeInspect(unit,guid)
    if not inspecting or pendingGUID~=guid or queue[queueIndex]~=unit or pendingQueueIndex~=queueIndex then return end
    if inventorySettleTimer then inventorySettleTimer:Cancel(); inventorySettleTimer=nil end; if inventoryCapTimer then inventoryCapTimer:Cancel(); inventoryCapTimer=nil end
    pendingGUID=nil; pendingQueueIndex=0
    if unit and UnitExists(unit) and UnitGUID(unit)==guid then results[guid]=CollectUnitData(unit) end
    if not IsBlizzardInspectActive() then ClearInspectPlayer() end
    RefreshList(); C_Timer.After(1.8,InspectNext)
end
local function OnInspectReady(guid)
    if not inspecting or guid~=pendingGUID or not queue[queueIndex] or pendingQueueIndex~=queueIndex then return end
    if pendingTimeout then pendingTimeout:Cancel(); pendingTimeout=nil end
    local unit=queue[queueIndex]
    if inventorySettleTimer then inventorySettleTimer:Cancel() end; if inventoryCapTimer then inventoryCapTimer:Cancel() end
    inventorySettleTimer=C_Timer.NewTimer(0.3,function() inventorySettleTimer=nil; FinalizeInspect(unit,guid) end)
    inventoryCapTimer=C_Timer.NewTimer(1.5,function() inventoryCapTimer=nil; FinalizeInspect(unit,guid) end)
end
local function OnUnitInventoryChanged(unit)
    if not inspecting or not pendingGUID or unit~=queue[queueIndex] then return end
    if inventorySettleTimer then local guid=pendingGUID; inventorySettleTimer:Cancel(); inventorySettleTimer=C_Timer.NewTimer(0.3,function() inventorySettleTimer=nil; FinalizeInspect(unit,guid) end) end
end
local function StartInspectQueue()
    if inspecting then return end
    if IsBlizzardInspectActive() then
        if statusText then statusText:SetText(C.L.riStatusWaiting) end
        return
    end
    if not (IsInRaid() or IsInGroup()) then print("|cffff6666[CC RaidTools]|r "..C.L.riNeedGroup); return end
    queue=GetGroupUnits(); queueIndex=0; pendingGUID=nil; pendingQueueIndex=0; wipe(results); inspecting=true
    if inspectButton then inspectButton:SetText(C.L.riInspectingButton); inspectButton:Disable() end; if statusText then statusText:SetText("") end
    RefreshList(); InspectNext()
end
local function BuildUI(f)
    panelRef=f
    local label=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); label:SetPoint("TOPLEFT",f,"TOPLEFT",10,-30); label:SetText(C.L.riLabel); label:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)
    inspectButton=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); inspectButton:SetSize(150,24); inspectButton:SetPoint("TOPLEFT",label,"BOTTOMLEFT",0,-10); inspectButton:SetText(C.L.riInspectButton); C.SkinButton(inspectButton); inspectButton:SetScript("OnClick",StartInspectQueue)
    statusText=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); statusText:SetPoint("LEFT",inspectButton,"RIGHT",10,0)
    local h=CreateFrame("Frame",nil,f); h:SetPoint("TOPLEFT",inspectButton,"BOTTOMLEFT",-6,-14); h:SetSize(390,18)
    local function H(txt,x,w,justify) local hf=h:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); hf:SetPoint("LEFT",x,0); hf:SetWidth(w); hf:SetJustifyH(justify or "CENTER"); hf:SetText(txt); hf:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B); return hf end
    H(C.L.riColName,4,150,"LEFT"); H(C.L.riColIlvl,160,55); H(C.L.riColEnchants,222,95); H(C.L.riColGems,324,95)
    scrollFrame=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); scrollFrame:SetPoint("TOPLEFT",h,"BOTTOMLEFT",6,-4); scrollFrame:SetSize(420,ROW_H); C.SkinScrollBar(scrollFrame)
    if scrollFrame.ScrollBar then scrollFrame.ScrollBar:ClearAllPoints(); scrollFrame.ScrollBar:SetPoint("TOPLEFT",scrollFrame,"TOPRIGHT",26,-18); scrollFrame.ScrollBar:SetPoint("BOTTOMLEFT",scrollFrame,"BOTTOMRIGHT",26,18) end
    rowsChild=CreateFrame("Frame",nil,scrollFrame); rowsChild:SetSize(414,ROW_H); scrollFrame:SetScrollChild(rowsChild)
end
C.RegisterModule("RaidInspect",BuildUI,function() if C.RequestResize then C.RequestResize() end end)
local e=CreateFrame("Frame"); e:RegisterEvent("INSPECT_READY"); e:RegisterEvent("UNIT_INVENTORY_CHANGED"); e:RegisterEvent("GROUP_ROSTER_UPDATE")
e:SetScript("OnEvent",function(_,ev,arg1)
    if ev=="INSPECT_READY" then OnInspectReady(arg1)
    elseif ev=="UNIT_INVENTORY_CHANGED" then OnUnitInventoryChanged(arg1)
    elseif ev=="GROUP_ROSTER_UPDATE" then
        if inspecting then StopInspectQueue() end
        wipe(results); queue={}; queueIndex=0; pendingGUID=nil; pendingQueueIndex=0
        RefreshList()
    end
end)