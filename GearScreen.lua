-- CC RaidTools - Gear Screen
-- Information on the Character window (and the Inspect window): item level,
-- upgrade progress and track, enchant name or a "missing enchant" warning on
-- every slot, rarity-coloured slot borders, a wider window, and a nicer
-- header on the compare tooltips.
--
-- Everything is drawn with regions/frames of our own placed over Blizzard's
-- slot buttons; nothing is written into Blizzard's frames beyond moving a few
-- anchors for the optional wider window. All reads go through
-- C_TooltipInfo / the item link, and every value read from them is checked
-- with issecretvalue first, because they can be secret in restricted content.
local C = CCRT

local db

local DEFAULTS = {
    enabled = false,              -- opt-in: it restyles a window every player uses
    missingEnchants = true,
    enchantNameStyle = "stat",    -- "stat" | "verbose" | "full"
    showEnchantRank = false,
    qualityBorders = true,
    showUpgrade = true,
    showTrackLetters = true,
    inspectInfo = true,
    widerFrame = false,
    compareHeader = true,
}

local STYLE_VALUES = { stat = true, verbose = true, full = true }

local function InitDB()
    C.InitDB()
    CCRaidToolsDB.gearScreen = CCRaidToolsDB.gearScreen or {}
    db = CCRaidToolsDB.gearScreen
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end
    if not STYLE_VALUES[db.enchantNameStyle] then
        db.enchantNameStyle = "stat"
    end
end

-- A value read from the game, or nil if it is secret.
local function Plain(value)
    if value == nil or (issecretvalue and issecretvalue(value)) then
        return nil
    end
    return value
end

-- ===== Slots =====
-- side: where the text goes relative to the slot's icon (it always extends
-- away from the slot column, towards the middle of the window).
local SLOTS = {
    { id = 1,  name = "Head",          side = "left" },
    { id = 2,  name = "Neck",          side = "left" },
    { id = 3,  name = "Shoulder",      side = "left" },
    { id = 15, name = "Back",          side = "left" },
    { id = 5,  name = "Chest",         side = "left" },
    { id = 9,  name = "Wrist",         side = "left" },
    { id = 10, name = "Hands",         side = "right" },
    { id = 6,  name = "Waist",         side = "right" },
    { id = 7,  name = "Legs",          side = "right" },
    { id = 8,  name = "Feet",          side = "right" },
    { id = 11, name = "Finger0",       side = "right" },
    { id = 12, name = "Finger1",       side = "right" },
    { id = 13, name = "Trinket0",      side = "right" },
    { id = 14, name = "Trinket1",      side = "right" },
    { id = 16, name = "MainHand",      side = "right" },
    { id = 17, name = "SecondaryHand", side = "left" },
}

-- Slots that take an enchant. EXPANSION-SPECIFIC: update this list (and the
-- one in RaidInspect.lua, ENCHANT_SLOTS) when a new expansion changes which
-- slots can be enchanted. The off hand only counts when it holds a weapon.
local ENCHANTABLE = {
    [1] = true, [3] = true, [5] = true, [7] = true, [8] = true,
    [11] = true, [12] = true, [16] = true, [17] = true,
}

local NO_ITEM_COLOR = "|cffffffff"
local ENCHANT_COLOR = "|cff1ae640"
local MISSING_COLOR = "|cffff3030"

local ENCHANTED_PREFIX = ((_G.ENCHANTED_TOOLTIP_LINE or "Enchanted: %s"):gsub("%s*%%s.*$", ""))

-- ===== Upgrade tracks =====
-- Keywords are matched (lowercase, plain) against the tooltip's upgrade line,
-- in English and French. Another locale still gets the "cur/max" progress, just
-- without a letter. Order matters: "mythe" must be tried before the others.
local TRACKS = {
    { letter = "M", color = { 1.00, 0.50, 0.00 }, words = { "myth" } },
    { letter = "H", color = { 0.78, 0.30, 0.78 }, words = { "hero", "héros", "heros" } },
    { letter = "C", color = { 0.00, 0.70, 1.00 }, words = { "champion" } },
    { letter = "V", color = { 0.00, 0.80, 0.00 }, words = { "veteran", "vétéran" } },
    { letter = "A", color = { 0.70, 0.70, 0.70 }, words = { "adventurer", "aventurier" } },
}

local function FindTrack(text)
    local lower = text:lower()
    for _, track in ipairs(TRACKS) do
        for _, word in ipairs(track.words) do
            if lower:find(word, 1, true) then
                return track
            end
        end
    end
end

-- ===== Enchant names =====
-- The tooltip names an enchant after its effect ("Hex of Leeching"), which
-- says nothing about the stat it gives. This maps the English effect names of
-- the current expansion to what they actually grant. Other locales (and any
-- enchant not listed) fall back to the effect text or a keyword.
local ENCHANT_STATS = {
    ["Bright Linen Spellthread"] = "Minor Int",
    ["Sunfire Silk Spellthread"] = "Int/Stam",
    ["Arcanoweave Spellthread"] = "Int/Mana",
    ["Thalassian Scout Armor Kit"] = "Minor Stat",
    ["Forest Hunter's Armor Kit"] = "Stat/Stam",
    ["Blood Knight's Armor Kit"] = "Stat/Armor",
    ["Farstrider's Hunt"] = "Speed",
    ["Lynx's Dexterity"] = "Avoidance",
    ["Shaladrassil's Roots"] = "Leech",
    ["Mark of the Worldsoul"] = "Primary Stat",
    ["Mark of the Magister"] = "Stat/Mana",
    ["Blessing of Speed"] = "Minor Speed",
    ["Empowered Blessing of Speed"] = "Speed",
    ["Hex of Leeching"] = "Minor Leech",
    ["Empowered Hex of Leeching"] = "Leech",
    ["Rune of Avoidance"] = "Minor Avoidance",
    ["Empowered Rune of Avoidance"] = "Avoidance",
    ["Amani Mastery"] = "Minor Mastery",
    ["Eyes of the Eagle"] = "Crit %",
    ["Nature's Fury"] = "Crit",
    ["Nature's Wrath"] = "Minor Crit",
    ["Silvermoon's Alacrity"] = "Haste",
    ["Silvermoon's Tenacity"] = "Versatility",
    ["Thalassian Haste"] = "Minor Haste",
    ["Thalassian Versatility"] = "Minor Versatility",
    ["Zul'jin's Mastery"] = "Mastery",
    ["Akil'zon's Swiftness"] = "Speed",
    ["Amirdrassil's Grace"] = "Avoidance",
    ["Flight of the Eagle"] = "Minor Speed",
    ["Nature's Grace"] = "Minor Avoidance",
    ["Silvermoon's Mending"] = "Leech",
    ["Thalassian Recovery"] = "Minor Leech",
    ["Acuity of the Ren'dorei"] = "Primary Stat",
    ["Arcane Mastery"] = "Mastery",
    ["Berserker's Rage"] = "Haste",
    ["Flames of the Sin'dorei"] = "Fire Dmg",
    ["Jan'alai's Precision"] = "Crit",
    ["Strength of Halazzi"] = "Bleed Dmg",
}

-- Some enchants print their effect instead of a name ("+41 Intellect & +4%
-- Mana", the leg enchants), so the stat can be read straight off the text.
local EFFECT_STATS = {
    { "Critical Strike", "Crit" }, { "Versatility", "Vers" }, { "Intellect", "Int" },
    { "Agility", "Agi" }, { "Strength", "Str" }, { "Stamina", "Stam" },
    { "Avoidance", "Avoidance" }, { "Mastery", "Mastery" }, { "Haste", "Haste" },
    { "Leech", "Leech" }, { "Speed", "Speed" }, { "Armor", "Armor" }, { "Mana", "Mana" },
}

local FILLER = { ["of"] = true, ["the"] = true, ["and"] = true, ["a"] = true }

-- Separators between the "Enchant <slot>" preamble and the effect, as byte
-- sequences matched plain (an en/em dash is multi-byte and must never go in a
-- character class).
local SEPARATORS = { " - ", " \226\128\147 ", " \226\128\148 " }

local function StatsFromEffect(text)
    if not text:find("%+%d") then
        return nil
    end
    local found = {}
    for _, pair in ipairs(EFFECT_STATS) do
        local at = text:find(pair[1], 1, true)
        if at then
            table.insert(found, { at = at, label = pair[2] })
        end
    end
    if #found == 0 then
        return nil
    end
    table.sort(found, function(a, b) return a.at < b.at end)
    local seen, parts = {}, {}
    for _, entry in ipairs(found) do
        if not seen[entry.label] then
            seen[entry.label] = true
            table.insert(parts, entry.label)
        end
    end
    return table.concat(parts, "/")
end

-- The head noun of an effect name: "Empowered Hex of Leeching" -> "Leeching".
-- Words are split by exclusion of ASCII separators, never with %w, which
-- matches no Cyrillic byte at all.
local function Keyword(name)
    local keyword
    for word in name:gmatch("[^%s,:;/%.%(%)]+") do
        if not FILLER[word:lower()] then
            keyword = word
        end
    end
    return keyword or name
end

-- "Enchanted: Enchant Helm - Hex of Leeching |A:...Tier2|a" -> "Hex of Leeching", 2
local function ParseEnchantLine(text)
    local rank = tonumber(text:match("Quality%-Tier(%d)"))
    local body = text
    if body:sub(1, #ENCHANTED_PREFIX) == ENCHANTED_PREFIX then
        body = body:sub(#ENCHANTED_PREFIX + 1)
    end
    body = body:gsub("^%s+", "")
    for _, separator in ipairs(SEPARATORS) do
        local _, stop = body:find(separator, 1, true)
        if stop then
            body = body:sub(stop + 1)
            break
        end
    end
    body = body:gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+$", "")
    return body, rank
end

local function EnchantLabel(effect, rank)
    if not effect or effect == "" then
        return nil
    end
    local style = db.enchantNameStyle
    local label
    if style == "full" then
        label = effect
    elseif style == "verbose" then
        label = Keyword(effect)
    else
        label = ENCHANT_STATS[effect] or StatsFromEffect(effect) or Keyword(effect)
    end
    -- Only when a tier was actually read: an unranked enchant must not read
    -- as rank one.
    if rank and db.showEnchantRank then
        label = label .. " " .. rank
    end
    return label
end

-- ===== Reading a slot =====

local ENCHANT_TYPE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent
local UPGRADE_TYPE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemUpgradeLevel

local function Surface(tableWithArgs)
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        pcall(TooltipUtil.SurfaceArgs, tableWithArgs)
    end
end

-- Returns the enchant line and the upgrade line of an equipped item's tooltip,
-- by their structured line types, with a wording fallback for the upgrade line.
local function ReadTooltip(unit, slotID)
    local enchantLine, upgradeLine
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then
        return nil, nil
    end
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, unit, slotID)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
        return nil, nil
    end
    Surface(data)
    for _, line in ipairs(data.lines) do
        Surface(line)
        local text = Plain(line.leftText)
        if type(text) == "string" then
            local kind = Plain(line.type)
            if ENCHANT_TYPE and kind == ENCHANT_TYPE then
                enchantLine = enchantLine or text
            elseif UPGRADE_TYPE and kind == UPGRADE_TYPE then
                upgradeLine = upgradeLine or text
            elseif not ENCHANT_TYPE and text:sub(1, #ENCHANTED_PREFIX) == ENCHANTED_PREFIX then
                enchantLine = enchantLine or text
            elseif not upgradeLine and text:find("%d+%s*/%s*%d+") and FindTrack(text) then
                -- Wording fallback: "<label>: <track> 4/6".
                upgradeLine = text
            end
        end
    end
    return enchantLine, upgradeLine
end

local function LinkHasEnchant(link)
    local field = link:match("item:%d+:([^:]*)")
    local id = tonumber(field)
    return id ~= nil and id > 0
end

local function AtMaxLevel(unit)
    local level = Plain(UnitLevel(unit))
    local rules = _G.GameRulesUtil
    if not level or not rules or not rules.GetEffectiveMaxLevelForPlayer then
        return false
    end
    local ok, max = pcall(rules.GetEffectiveMaxLevelForPlayer)
    return ok and max and level >= max or false
end

local function CanEnchant(link, slotID)
    if not ENCHANTABLE[slotID] then
        return false
    end
    if slotID == 17 then
        local equipLoc = select(4, C_Item.GetItemInfoInstant(link))
        if equipLoc == "INVTYPE_HOLDABLE" or equipLoc == "INVTYPE_SHIELD" then
            return false
        end
    end
    return true
end

local function HexColor(r, g, b)
    return string.format("|cff%02x%02x%02x",
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function QualityColor(quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        return color.r, color.g, color.b
    end
end

-- The two lines of text for a slot, plus its quality for the border.
local function ReadSlot(unit, slotID)
    local link = GetInventoryItemLink(unit, slotID)
    if not link then
        return nil
    end
    local info = { link = link }
    info.quality = Plain(GetInventoryItemQuality(unit, slotID))
    info.ilvl = C_Item.GetDetailedItemLevelInfo(link)

    local enchantLine, upgradeLine = ReadTooltip(unit, slotID)

    -- Line 1: item level in its quality colour, then track letter / progress.
    local parts = {}
    if info.ilvl then
        local r, g, b = QualityColor(info.quality)
        table.insert(parts, (r and HexColor(r, g, b) or NO_ITEM_COLOR) .. info.ilvl .. "|r")
    end
    if upgradeLine and (db.showUpgrade or db.showTrackLetters) then
        local track = FindTrack(upgradeLine)
        local current, max = upgradeLine:match("(%d+)%s*/%s*(%d+)")
        if track and db.showTrackLetters then
            table.insert(parts, HexColor(track.color[1], track.color[2], track.color[3]) .. track.letter .. "|r")
        end
        if current and db.showUpgrade then
            table.insert(parts, "|cffcccccc" .. current .. "/" .. max .. "|r")
        end
    end
    info.line1 = table.concat(parts, " ")

    -- Line 2: the enchant, or a warning when an enchantable slot has none.
    if db.missingEnchants then
        local hasEnchant = enchantLine ~= nil or LinkHasEnchant(link)
        if hasEnchant then
            local effect, rank = nil, nil
            if enchantLine then
                effect, rank = ParseEnchantLine(enchantLine)
            end
            local label = EnchantLabel(effect, rank)
            info.line2 = label and (ENCHANT_COLOR .. label .. "|r") or ""
        elseif CanEnchant(link, slotID) and AtMaxLevel(unit) then
            info.line2 = MISSING_COLOR .. C.L.gsNoEnchant .. "|r"
        end
    end
    return info
end

-- ===== Overlays =====
-- One set of regions per slot button, kept in a weak table keyed by the
-- button rather than written onto Blizzard's frame.

local overlays = setmetatable({}, { __mode = "k" })

local function FontSettings()
    local path, _, flags = GameFontHighlightSmall:GetFont()
    return path or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE"
end

local function GetOverlay(button, side)
    local overlay = overlays[button]
    if overlay then
        return overlay
    end
    overlay = {}
    local path, size, flags = FontSettings()

    overlay.line1 = button:CreateFontString(nil, "OVERLAY")
    overlay.line1:SetFont(path, size, flags)
    overlay.line1:SetWordWrap(false)
    overlay.line2 = button:CreateFontString(nil, "OVERLAY")
    overlay.line2:SetFont(path, size - 1, flags)
    overlay.line2:SetWordWrap(false)

    if side == "left" then
        overlay.line1:SetPoint("TOPLEFT", button, "TOPRIGHT", 6, -3)
        overlay.line1:SetJustifyH("LEFT")
        overlay.line2:SetPoint("TOPLEFT", overlay.line1, "BOTTOMLEFT", 0, -2)
        overlay.line2:SetJustifyH("LEFT")
    else
        overlay.line1:SetPoint("TOPRIGHT", button, "TOPLEFT", -6, -3)
        overlay.line1:SetJustifyH("RIGHT")
        overlay.line2:SetPoint("TOPRIGHT", overlay.line1, "BOTTOMRIGHT", 0, -2)
        overlay.line2:SetJustifyH("RIGHT")
    end
    overlay.line1:SetWidth(170)
    overlay.line2:SetWidth(170)

    -- Rarity border: a thin coloured frame over the icon that lets clicks
    -- through to the button underneath.
    overlay.border = CreateFrame("Frame", nil, button, "BackdropTemplate")
    overlay.border:SetAllPoints(button)
    overlay.border:SetFrameLevel(button:GetFrameLevel() + 3)
    overlay.border:EnableMouse(false)
    overlay.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    overlay.border:Hide()

    overlays[button] = overlay
    return overlay
end

local function HideOverlay(button)
    local overlay = overlays[button]
    if overlay then
        overlay.line1:SetText("")
        overlay.line2:SetText("")
        overlay.border:Hide()
    end
end

local function PaintSlot(button, unit, slot)
    if not button then
        return
    end
    local overlay = GetOverlay(button, slot.side)
    local info = unit and ReadSlot(unit, slot.id)
    if not info then
        HideOverlay(button)
        return
    end
    overlay.line1:SetText(info.line1 or "")
    overlay.line2:SetText(info.line2 or "")

    local r, g, b = QualityColor(info.quality)
    if db.qualityBorders and r then
        overlay.border:SetBackdropBorderColor(r, g, b, 1)
        overlay.border:Show()
    else
        overlay.border:Hide()
    end
end

-- kind: "character" (the player's own window) or "inspect".
local function ButtonName(kind, slot)
    return (kind == "inspect" and "Inspect" or "Character") .. slot.name .. "Slot"
end

local function PaintWindow(kind)
    local unit
    if kind == "inspect" then
        unit = InspectFrame and InspectFrame.unit
        if unit and not UnitExists(unit) then
            unit = nil
        end
    else
        unit = "player"
    end
    local enabled = db.enabled and (kind ~= "inspect" or db.inspectInfo)
    for _, slot in ipairs(SLOTS) do
        local button = _G[ButtonName(kind, slot)]
        if button then
            if enabled and unit then
                PaintSlot(button, unit, slot)
            else
                HideOverlay(button)
            end
        end
    end
end

-- ===== Refresh scheduling =====
-- Many Blizzard updates and item-data events arrive in bursts; coalesce them.

local pending = {}

local function Queue(kind, delay)
    if pending[kind] then
        return
    end
    pending[kind] = true
    C_Timer.After(delay or 0.1, function()
        pending[kind] = false
        if kind == "inspect" then
            if InspectFrame and InspectFrame:IsShown() then
                PaintWindow("inspect")
            end
        elseif CharacterFrame and CharacterFrame:IsShown() then
            PaintWindow("character")
        end
    end)
end

-- ===== Wider window =====
-- Moves the right-hand slot column and the stat pane outward by a fixed
-- amount. Every value is set ABSOLUTELY (never as a delta from the current
-- state), so running it any number of times, from any of the hooks below,
-- gives the same layout. The numbers are Blizzard's own from
-- CharacterFrame.xml / PaperDollFrame.xml (checked on 12.1.5), used to put
-- everything back when the option is switched off.
local WIDEN_BY = 40
local widenApplied = false
local widenHooked = false

local function ApplyWiden()
    local cf = _G.CharacterFrame
    local inset, insetRight = _G.CharacterFrameInset, _G.CharacterFrameInsetRight
    local hands, mainHand = _G.CharacterHandsSlot, _G.CharacterMainHandSlot
    local model, items, paperDoll = _G.CharacterModelScene, _G.PaperDollItemsFrame, _G.PaperDollFrame
    if not (cf and inset and insetRight and hands and mainHand and model and items and paperDoll) then
        return
    end

    local on = db and db.enabled and db.widerFrame and paperDoll:IsShown()
    if not on and not widenApplied then
        return -- never touched: leave Blizzard's layout alone
    end
    local add = on and WIDEN_BY or 0

    -- On other tabs Blizzard's own UpdateSize owns the width: only touch it
    -- while the character page is showing.
    if paperDoll:IsShown() then
        local baseWidth = cf.Expanded and (_G.CHARACTERFRAME_EXPANDED_WIDTH or 540) or (_G.PANEL_DEFAULT_WIDTH or 384)
        cf:SetWidth(baseWidth + add)
    end

    insetRight:ClearAllPoints()
    insetRight:SetPoint("TOPLEFT", inset, "TOPRIGHT", 1 + add, 0)
    insetRight:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -4, 4)

    -- The right column hangs off the stat pane's left edge while widened, so
    -- the two cannot meet.
    hands:ClearAllPoints()
    if on then
        hands:SetPoint("TOPRIGHT", insetRight, "TOPLEFT", -4, -2)
    else
        hands:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -4, -2)
    end

    model:ClearAllPoints()
    model:SetPoint("TOPLEFT", paperDoll, "TOPLEFT", 52 + add / 2, -66)

    mainHand:ClearAllPoints()
    mainHand:SetPoint("BOTTOMLEFT", items, "BOTTOMLEFT", 130 + add / 2, 16)

    widenApplied = on and true or false
end

local function HookWiden()
    local cf = _G.CharacterFrame
    if not cf or widenHooked then
        return
    end
    widenHooked = true
    -- These four are what Blizzard calls when it recomputes the width; all of
    -- them just re-apply, because ApplyWiden is absolute.
    for _, method in ipairs({ "Expand", "Collapse", "UpdateSize", "ShowSubFrame" }) do
        if type(cf[method]) == "function" then
            hooksecurefunc(cf, method, ApplyWiden)
        end
    end
end

-- ===== Compare tooltip header =====
-- Replaces the header's stock art with a flat dark backdrop and keeps the
-- "Equipped" label. Frame-region styling only, done once per tooltip.

local styledHeaders = setmetatable({}, { __mode = "k" })

local function StyleCompareHeaders()
    if not db or not db.compareHeader then
        return
    end
    for _, base in ipairs({ "ShoppingTooltip", "ItemRefShoppingTooltip" }) do
        for i = 1, 2 do
            local tooltip = _G[base .. i]
            local header = tooltip and tooltip.CompareHeader
            if header and not styledHeaders[header] then
                styledHeaders[header] = true
                for _, region in ipairs({ header:GetRegions() }) do
                    if region:IsObjectType("Texture") then
                        region:SetAlpha(0)
                    end
                end
                local back = CreateFrame("Frame", nil, header, "BackdropTemplate")
                back:SetAllPoints(header)
                back:SetFrameLevel(math.max(0, header:GetFrameLevel() - 1))
                back:EnableMouse(false)
                back:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                })
                back:SetBackdropColor(0.018, 0.018, 0.024, 0.92)
                back:SetBackdropBorderColor(0, 0, 0, 1)
            end
        end
    end
end

-- ===== Applying settings =====

local function Apply()
    InitDB()
    if CharacterFrame and CharacterFrame:IsShown() then
        PaintWindow("character")
    end
    if InspectFrame and InspectFrame:IsShown() then
        PaintWindow("inspect")
    end
    ApplyWiden()
    StyleCompareHeaders()
end

-- ===== Hooks and events =====

local hookedCharacter, hookedInspect = false, false

local function HookCharacter()
    if hookedCharacter or not _G.PaperDollFrame then
        return
    end
    hookedCharacter = true
    PaperDollFrame:HookScript("OnShow", function()
        if db and db.enabled then
            Queue("character", 0.05)
        end
        ApplyWiden()
    end)
    PaperDollFrame:HookScript("OnHide", ApplyWiden)
    -- Blizzard refreshes each slot button through this; a post-hook only
    -- schedules our own (coalesced) repaint.
    if type(_G.PaperDollItemSlotButton_Update) == "function" then
        hooksecurefunc("PaperDollItemSlotButton_Update", function()
            if db and db.enabled then
                Queue("character")
            end
        end)
    end
    HookWiden()
end

local function HookInspect()
    if hookedInspect or not _G.InspectPaperDollFrame then
        return
    end
    hookedInspect = true
    InspectPaperDollFrame:HookScript("OnShow", function()
        if db and db.enabled and db.inspectInfo then
            Queue("inspect", 0.2)
        end
    end)
    if type(_G.InspectPaperDollFrame_UpdateButtons) == "function" then
        hooksecurefunc("InspectPaperDollFrame_UpdateButtons", function()
            if db and db.enabled and db.inspectInfo then
                Queue("inspect", 0.2)
            end
        end)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("INSPECT_READY")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        InitDB()
        HookCharacter()
        HookInspect()
        StyleCompareHeaders()
        -- The shopping tooltips can be created lazily on first use.
        C_Timer.After(2, StyleCompareHeaders)
        return
    end
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_InspectUI" then
            HookInspect()
        end
        return
    end
    if not db or not db.enabled then
        return
    end
    if event == "INSPECT_READY" then
        -- The inspected unit's gear arrives a moment after the event, and its
        -- tooltips a little later still.
        for _, delay in ipairs({ 0.3, 1, 2.5 }) do
            C_Timer.After(delay, function()
                if InspectFrame and InspectFrame:IsShown() and db.inspectInfo then
                    PaintWindow("inspect")
                end
            end)
        end
    else
        Queue("character")
        if event == "GET_ITEM_INFO_RECEIVED" then
            Queue("inspect", 0.3)
        end
    end
end)

-- ===== Settings UI =====

local layout

local function Enabled()
    return db.enabled
end

local function BuildUI(panel)
    InitDB()
    local UI = C.UI
    UI.Band(panel, "GearScreen", C.L.gsIntro)

    layout = UI.NewScrollLayout(panel)

    layout:Toggle({
        label = C.L.gsEnableLabel,
        desc = C.L.gsEnableDesc,
        get = function() return db.enabled end,
        set = function(value)
            db.enabled = value
            Apply()
        end,
    })

    layout:Header(C.L.gsSectionEnchants)
    layout:Toggle({
        label = C.L.gsMissingLabel, desc = C.L.gsMissingDesc, parent = Enabled,
        get = function() return db.missingEnchants end,
        set = function(value) db.missingEnchants = value; Apply() end,
    })
    layout:Choice({
        label = C.L.gsStyleLabel, desc = C.L.gsStyleDesc, parent = Enabled, width = 200,
        values = {
            { C.L.gsStyleStat, "stat" },
            { C.L.gsStyleVerbose, "verbose" },
            { C.L.gsStyleFull, "full" },
        },
        get = function() return db.enchantNameStyle end,
        set = function(value) db.enchantNameStyle = value; Apply() end,
    })
    layout:Toggle({
        label = C.L.gsRankLabel, desc = C.L.gsRankDesc, parent = Enabled,
        get = function() return db.showEnchantRank end,
        set = function(value) db.showEnchantRank = value; Apply() end,
    })
    layout:Toggle({
        label = C.L.gsBordersLabel, desc = C.L.gsBordersDesc, parent = Enabled,
        get = function() return db.qualityBorders end,
        set = function(value) db.qualityBorders = value; Apply() end,
    })
    layout:Note(C.L.gsEnchantNote)

    layout:Header(C.L.gsSectionTrack)
    layout:Toggle({
        label = C.L.gsUpgradeLabel, desc = C.L.gsUpgradeDesc, parent = Enabled,
        get = function() return db.showUpgrade end,
        set = function(value) db.showUpgrade = value; Apply() end,
    })
    layout:Toggle({
        label = C.L.gsLettersLabel, desc = C.L.gsLettersDesc, parent = Enabled,
        get = function() return db.showTrackLetters end,
        set = function(value) db.showTrackLetters = value; Apply() end,
    })
    layout:Note(C.L.gsTrackLegend)

    layout:Header(C.L.gsSectionInspect)
    layout:Toggle({
        label = C.L.gsInspectLabel, desc = C.L.gsInspectDesc, parent = Enabled,
        get = function() return db.inspectInfo end,
        set = function(value) db.inspectInfo = value; Apply() end,
    })

    layout:Header(C.L.gsSectionWindow)
    layout:Toggle({
        label = C.L.gsWiderLabel, desc = C.L.gsWiderDesc, parent = Enabled,
        get = function() return db.widerFrame end,
        set = function(value) db.widerFrame = value; Apply() end,
    })

    -- Independent of the master switch: it styles a tooltip, not the window.
    layout:Header(C.L.gsSectionTooltips)
    layout:Toggle({
        label = C.L.gsCompareLabel, desc = C.L.gsCompareDesc,
        get = function() return db.compareHeader end,
        set = function(value) db.compareHeader = value; Apply() end,
    })

    layout:Finish()
end

local function RefreshUI()
    InitDB()
    if layout then
        layout:Refresh()
    end
end

C.RegisterModule("GearScreen", BuildUI, RefreshUI)
