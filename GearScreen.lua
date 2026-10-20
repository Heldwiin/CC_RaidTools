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
    gemHelper = true,             -- row of socket buttons under the window
    gemEnchantHelper = true,      -- "apply an enchant from your bags" button on that row
    gemOnlyEmpty = false,
    gemButtonSize = 24,
    gemButtonSpacing = 1,
    omniumButton = false,         -- Omnium Foil proxy button (hides the minimap one)
    vaultButton = false,          -- Great Vault button
    windowButtonSize = 24,
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

-- ===== Socket helper =====
-- A row of buttons under the character window, one per gem socket on the
-- equipped gear (the meta socket first). Hovering one lists the gems in your
-- bags that you can put there; clicking a gem does it through Blizzard's own
-- socketing calls. A last button lists the enchants in your bags and starts
-- Blizzard's "now click the item" flow.

local EMPTY_SOCKET_TYPES = {
    { name = "Prismatic",  stat = "EMPTY_SOCKET_PRISMATIC",  icon = 458977 },
    { name = "Meta",       stat = "EMPTY_SOCKET_META",       icon = 136257 },
    { name = "Tinker",     stat = "EMPTY_SOCKET_TINKER",     icon = 2958630 },
    { name = "Cogwheel",   stat = "EMPTY_SOCKET_COGWHEEL",   icon = 407324 },
    { name = "Primordial", stat = "EMPTY_SOCKET_PRIMORDIAL", icon = 4095404 },
    { name = "Fiber",      stat = "EMPTY_SOCKET_FIBER",      icon = 136260 },
}
local SOCKETABLE_SLOTS = { 1, 2, 5, 6, 9, 10, 11, 12, 13, 14, 15 }
local MAX_ITEM_SOCKETS = 4
-- Gem item subclasses of the "other" kind that hold the meta-style gems.
local GEM_SUBCLASS_DIAMOND, GEM_SUBCLASS_CLASSIC_META = 9, 1
local GEM_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Gem) or 3
local ENHANCEMENT_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.ItemEnhancement) or 8
local REAGENT_BAG = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
local LAST_BAG = math.max(REAGENT_BAG, NUM_BAG_SLOTS or 4)
local ENCHANT_BUTTON_ICON = "Interface\\Icons\\Trade_Engraving"
local QUALITY_ATLAS_PATTERN = "|A:(Professions%-ChatIcon%-Quality%-[^:]+):%d+:%d+"

local POPUP_W, POPUP_TITLE_H, POPUP_ICON, POPUP_PAD, ROW_PAD = 280, 24, 24, 2, 4

local SLOT_BUTTON = {}
for _, slot in ipairs(SLOTS) do
    SLOT_BUTTON[slot.id] = "Character" .. slot.name .. "Slot"
end

local sockets = { container = nil, buttons = {}, popup = nil, popupRows = {}, enchantButton = nil, current = nil }
local socketCache = {}
local socketRetries, socketRetryRunning, socketGuardExpired = 0, false, false

local function QualityAtlasOf(link)
    return type(link) == "string" and link:match(QUALITY_ATLAS_PATTERN) or nil
end

local function SetAtlas(texture, atlas)
    if atlas then
        texture:SetAtlas(atlas, false)
        texture:Show()
    else
        texture:Hide()
    end
end

local function GemStats(link)
    if not (link and C_TooltipInfo and C_TooltipInfo.GetHyperlink) then
        return nil
    end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
        return nil
    end
    for _, line in ipairs(data.lines) do
        local text = Plain(line.leftText)
        if type(text) == "string" and text:match("^%+%d+") then
            return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
        end
    end
end

-- Sockets of one equipped item: filled ones from the item link, empty ones
-- from the item's stats (which count the TOTAL, so the empty ones are what the
-- filled pass did not account for). Item data right after a reload can be
-- missing, and then every socket would look empty; that case is returned as
-- `pending` and drawn later, bounded by the retry below.
local function ScanItemSockets(slotID)
    local link = GetInventoryItemLink("player", slotID)
    if not link then
        return nil
    end
    local result = { slotID = slotID, sockets = {}, filled = 0 }

    for index = 1, MAX_ITEM_SOCKETS do
        local gemName, gemLink = C_Item.GetItemGem(link, index)
        if gemLink then
            result.filled = result.filled + 1
            local gemID, _, _, _, _, _, subclass = C_Item.GetItemInfoInstant(gemLink)
            local socketType
            if subclass == GEM_SUBCLASS_DIAMOND or subclass == GEM_SUBCLASS_CLASSIC_META then
                socketType = "Meta"
            end
            table.insert(result.sockets, {
                index = index, filled = true, gemLink = gemLink, gemID = gemID,
                socketType = socketType, icon = gemID and C_Item.GetItemIconByID(gemID),
            })
        end
    end

    local stats = C_Item.GetItemStats and C_Item.GetItemStats(link)
    if stats and result.filled == 0 then
        local any = false
        for _, kind in ipairs(EMPTY_SOCKET_TYPES) do
            if (tonumber(stats[kind.stat]) or 0) > 0 then
                any = true
                break
            end
        end
        local ok, cached = pcall(C_Item.IsItemDataCachedByID, link)
        if any and ok and cached == false and not socketGuardExpired then
            result.pending = true
            return result
        end
    end
    if stats then
        local kinds = {}
        for _, kind in ipairs(EMPTY_SOCKET_TYPES) do
            for _ = 1, tonumber(stats[kind.stat]) or 0 do
                if #kinds < MAX_ITEM_SOCKETS then
                    kinds[#kinds + 1] = kind
                end
            end
        end
        for i = result.filled + 1, #kinds do
            table.insert(result.sockets, {
                index = #result.sockets + 1, filled = false,
                socketType = kinds[i].name, icon = kinds[i].icon,
            })
        end
    end
    if result.pending or #result.sockets > 0 then
        return result
    end
end

local function ScanEquippedSockets()
    wipe(socketCache)
    for _, slotID in ipairs(SOCKETABLE_SLOTS) do
        local info = ScanItemSockets(slotID)
        if info then
            table.insert(socketCache, info)
        end
    end
    return socketCache
end

local function AnySocketPending()
    for _, info in ipairs(socketCache) do
        if info.pending then
            return true
        end
    end
    return false
end

local function ScanBags(wantedClass, withTargets)
    local found = {}
    for bag = 0, LAST_BAG do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local classID = select(6, C_Item.GetItemInfoInstant(info.itemID))
                if classID == wantedClass then
                    local entry = found[info.itemID]
                    if entry then
                        entry.count = entry.count + (info.stackCount or 1)
                    else
                        found[info.itemID] = {
                            itemID = info.itemID, icon = info.iconFileID, count = info.stackCount or 1,
                            link = info.hyperlink, bagID = bag, slotID = slot,
                        }
                    end
                end
            end
        end
    end
    return found
end

-- Which equipment slot an enchant is for. There is no API for it, so the
-- English wording of its tooltip is read; an unrecognised one is still listed
-- (it just gets no slot glow and no one-click apply).
local ENCHANT_SLOT_KEYWORDS = {
    ["chest"] = { 5 }, ["cloak"] = { 15 }, ["back"] = { 15 }, ["cape"] = { 15 },
    ["legs"] = { 7 }, ["leg"] = { 7 }, ["boot"] = { 8 }, ["feet"] = { 8 },
    ["bracer"] = { 9 }, ["wrist"] = { 9 }, ["ring"] = { 11, 12 },
    ["2h weapon"] = { 16 }, ["weapon"] = { 16, 17 }, ["staff"] = { 16 },
    ["glove"] = { 10 }, ["hand"] = { 10 }, ["helm"] = { 1 }, ["head"] = { 1 },
    ["shoulder"] = { 3 }, ["belt"] = { 6 }, ["waist"] = { 6 }, ["neck"] = { 2 },
    ["trinket"] = { 13, 14 },
}
local KEYWORD_ORDER = {}
for keyword in pairs(ENCHANT_SLOT_KEYWORDS) do
    KEYWORD_ORDER[#KEYWORD_ORDER + 1] = keyword
end
-- Longest first, so "2h weapon" is tried before "weapon".
table.sort(KEYWORD_ORDER, function(a, b) return #a > #b end)

-- Leg enchants are armour kits that do not apply reliably through this flow.
local UNOFFERABLE_SLOTS = { [7] = true }
-- An item that raises ADDON_ACTION_FORBIDDEN when used from an addon.
local BLOCKED_ENCHANT_ITEMS = { [210494] = true }

local function EnchantTargetSlots(link)
    if not (link and C_TooltipInfo and C_TooltipInfo.GetHyperlink) then
        return nil
    end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
        return nil
    end
    local best
    for _, line in ipairs(data.lines) do
        local text = Plain(line.leftText)
        if type(text) == "string" then
            local lower = text:lower()
            for _, keyword in ipairs(KEYWORD_ORDER) do
                -- Whole words only: "ring" must not match "Engineering".
                if #keyword > #(best or "") and lower:find("%f[%w]" .. keyword .. "%f[%W]") then
                    best = keyword
                end
            end
        end
    end
    return best and ENCHANT_SLOT_KEYWORDS[best] or nil
end

local function IsOfferableEnchant(itemID, targets)
    if BLOCKED_ENCHANT_ITEMS[itemID] then
        return false
    end
    if not targets then
        return true
    end
    for _, slotID in ipairs(targets) do
        if not UNOFFERABLE_SLOTS[slotID] then
            return true
        end
    end
    return false
end

local WEAPON_SLOTS = { [16] = true, [17] = true }
local WEAPON_EQUIP_LOCS = {
    INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true,
}

local function SlotCanTakeEnchant(slotID)
    local link = GetInventoryItemLink("player", slotID)
    if not link then
        return false
    end
    if not WEAPON_SLOTS[slotID] then
        return true
    end
    local ok, _, _, _, equipLoc = pcall(C_Item.GetItemInfoInstant, link)
    if not ok or Plain(equipLoc) == nil then
        return true
    end
    return WEAPON_EQUIP_LOCS[equipLoc] == true
end

-- The one slot an enchant can possibly mean, or nil when it is a judgement
-- call (two rings, a weapon in each hand, an unreadable tooltip). Only then do
-- we finish the job ourselves; otherwise the cursor stays loaded for the player.
local function UnambiguousEnchantSlot(targets)
    if not targets then
        return nil
    end
    local found
    for _, slotID in ipairs(targets) do
        if SlotCanTakeEnchant(slotID) then
            if found then
                return nil
            end
            found = slotID
        end
    end
    return found
end

local function FirstEquippedTarget(targets)
    for _, slotID in ipairs(targets or {}) do
        if GetInventoryItemLink("player", slotID) then
            return slotID
        end
    end
end

-- Glow over the slot a hovered gem/enchant would go to.
local highlight
local function ShowSlotHighlight(slotID)
    if highlight then
        highlight:Hide()
    end
    local button = slotID and _G[SLOT_BUTTON[slotID] or ""]
    if not button then
        return
    end
    if not highlight then
        highlight = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        highlight:SetFrameStrata("DIALOG")
        highlight:EnableMouse(false)
        highlight:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        highlight:SetBackdropColor(C.BRAND_R, C.BRAND_G, C.BRAND_B, 0.35)
        highlight:SetBackdropBorderColor(C.BRAND_R, C.BRAND_G, C.BRAND_B, 1)
    end
    highlight:ClearAllPoints()
    highlight:SetAllPoints(button)
    highlight:Show()
end

local function HideSlotHighlight()
    if highlight then
        highlight:Hide()
    end
end

local function MouseOverHelper()
    local popup = sockets.popup
    if popup and popup:IsShown() and popup:IsMouseOver() then
        return true
    end
    if sockets.enchantButton and sockets.enchantButton:IsShown() and sockets.enchantButton:IsMouseOver() then
        return true
    end
    for _, button in ipairs(sockets.buttons) do
        if button:IsShown() and button:IsMouseOver() then
            return true
        end
    end
    return false
end

local function HidePopup()
    if sockets.popup then
        sockets.popup:Hide()
    end
end

-- Closes the list shortly after the cursor leaves every part of the helper, so
-- moving from a button into the list does not close it under the cursor.
local function CloseWhenAway()
    C_Timer.After(0.05, function()
        if not MouseOverHelper() then
            HidePopup()
            HideSlotHighlight()
        end
    end)
end

local RefreshSockets

local function DarkBox(frame, r, g, b, a)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(r or 0.018, g or 0.018, b or 0.024, a or 0.96)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
end

local function CreatePopup()
    if sockets.popup then
        return sockets.popup
    end
    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    DarkBox(popup, 0.018, 0.018, 0.024, 0.97)
    popup:SetSize(POPUP_W, 50)
    popup:SetFrameStrata("TOOLTIP")
    popup:EnableMouse(true)
    popup:Hide()

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.title:SetPoint("TOPLEFT", 8, -7)
    popup.title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    popup.separator = popup:CreateTexture(nil, "ARTWORK")
    popup.separator:SetHeight(1)
    popup.separator:SetPoint("TOPLEFT", popup, "TOPLEFT", 0, -POPUP_TITLE_H)
    popup.separator:SetPoint("TOPRIGHT", popup, "TOPRIGHT", 0, -POPUP_TITLE_H)
    popup.separator:SetColorTexture(C.BRAND_R * 0.6, C.BRAND_G * 0.6, C.BRAND_B * 0.6, 0.7)

    popup.empty = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.empty:SetPoint("CENTER", 0, -8)
    popup.empty:SetTextColor(0.66, 0.66, 0.72)
    popup.empty:Hide()

    popup:SetScript("OnEnter", function()
        if sockets.current and sockets.current.info then
            ShowSlotHighlight(sockets.current.info.slotID)
        end
    end)
    popup:SetScript("OnLeave", CloseWhenAway)

    sockets.popup = popup
    return popup
end

local function CreatePopupRow(index)
    if sockets.popupRows[index] then
        return sockets.popupRows[index]
    end
    local popup = sockets.popup
    local row = CreateFrame("Button", nil, popup)
    row:SetHeight(POPUP_ICON + ROW_PAD)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(POPUP_ICON, POPUP_ICON)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.quality = row:CreateTexture(nil, "OVERLAY")
    row.quality:SetSize(16, 16)
    row.quality:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -4, 4)
    row.quality:Hide()

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetWidth(POPUP_W - 90)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)

    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.count:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.count:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    local wash = row:CreateTexture(nil, "BACKGROUND")
    wash:SetAllPoints()
    wash:SetColorTexture(C.BRAND_R * 0.35, C.BRAND_G * 0.35, C.BRAND_B * 0.48, 0)
    row.wash = wash

    row:SetScript("OnEnter", function(self)
        self.wash:SetColorTexture(C.BRAND_R * 0.35, C.BRAND_G * 0.35, C.BRAND_B * 0.48, 0.85)
        if self.targetSlot then
            ShowSlotHighlight(self.targetSlot)
        end
        local link = self.payload and self.payload.link
        if link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 40, 0)
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        self.wash:SetColorTexture(0, 0, 0, 0)
        GameTooltip:Hide()
        CloseWhenAway()
    end)
    row:SetScript("OnClick", function(self)
        if InCombatLockdown() then
            UIErrorsFrame:AddExternalErrorMessage(C.L.gsNoCombat)
            return
        end
        local data = self.payload
        if not data then
            return
        end
        if self.kind == "enchant" then
            -- Blizzard takes over: the cursor becomes "now click the item".
            C_Container.UseContainerItem(data.bagID, data.slotID)
            local only = UnambiguousEnchantSlot(data.targets)
            -- An enchant in progress is a spell waiting for a target, not an
            -- item on the cursor; both are tested so we never pick up (and
            -- unequip) a worn item when nothing is pending.
            local pending = CursorHasItem() or (SpellIsTargeting and SpellIsTargeting())
            if only and pending then
                PickupInventoryItem(only)
            end
            HidePopup()
            HideSlotHighlight()
        elseif self.kind == "gem" and self.targetSlot and self.targetSocket then
            SocketInventoryItem(self.targetSlot)
            C_Container.PickupContainerItem(data.bagID, data.slotID)
            C_ItemSocketInfo.ClickSocketButton(self.targetSocket)
            ClearCursor()
            C_ItemSocketInfo.AcceptSockets()
            C_ItemSocketInfo.CloseSocketInfo()
            if ItemSocketingFrame then
                HideUIPanel(ItemSocketingFrame)
            end
            HidePopup()
            HideSlotHighlight()
            C_Timer.After(0.1, function()
                if not InCombatLockdown() then
                    RefreshSockets()
                end
            end)
        end
    end)

    sockets.popupRows[index] = row
    return row
end

-- entries: list of { payload, icon, text, count, targetSlot, targetSocket }.
local function ShowPopup(anchor, title, kind, entries, emptyText)
    local popup = CreatePopup()
    popup.title:SetText(title)
    for _, row in pairs(sockets.popupRows) do
        row:Hide()
    end

    local height
    if #entries == 0 then
        popup.empty:SetText(emptyText)
        popup.empty:Show()
        popup.separator:Hide()
        popup:SetWidth(math.max(200, popup.title:GetStringWidth() + 26))
        height = 50
    else
        popup.empty:Hide()
        popup.separator:Show()
        popup:SetWidth(POPUP_W)
        local y = POPUP_TITLE_H
        for i, entry in ipairs(entries) do
            local row = CreatePopupRow(i)
            row.kind = kind
            row.payload = entry.payload
            row.targetSlot = entry.targetSlot
            row.targetSocket = entry.targetSocket
            row.icon:SetTexture(entry.icon)
            row.text:SetText(entry.text or "")
            row.count:SetText(entry.count .. "x")
            SetAtlas(row.quality, QualityAtlasOf(entry.payload.link))
            row.wash:SetColorTexture(0, 0, 0, 0)
            local rowHeight = math.max(POPUP_ICON + ROW_PAD, (row.text:GetStringHeight() or 0) + ROW_PAD)
            row:SetHeight(rowHeight)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", popup, "TOPLEFT", POPUP_PAD, -y)
            row:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -POPUP_PAD, -y)
            row:Show()
            y = y + rowHeight
        end
        height = y + POPUP_PAD
    end
    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -1)
    popup:SetHeight(height)
    popup:Show()
end

local function ShowGemPopup(button)
    if not button.socket then
        HidePopup()
        return
    end
    local entries = {}
    local currentGem = button.socket.gemID
    for _, gem in pairs(ScanBags(GEM_CLASS)) do
        if gem.itemID ~= currentGem then
            table.insert(entries, {
                payload = gem, icon = gem.icon, text = GemStats(gem.link) or "", count = gem.count,
                targetSlot = button.info.slotID, targetSocket = button.socket.index,
            })
        end
    end
    table.sort(entries, function(a, b) return a.payload.itemID < b.payload.itemID end)
    ShowPopup(button,
        button.socket.filled and C.L.gsReplaceGem or C.L.gsSocketGem, "gem", entries,
        button.socket.filled and C.L.gsNoReplacement or C.L.gsNoGems)
end

local function ShowEnchantPopup(button)
    sockets.current = nil
    HideSlotHighlight()
    local entries = {}
    for itemID, item in pairs(ScanBags(ENHANCEMENT_CLASS)) do
        item.targets = EnchantTargetSlots(item.link)
        if IsOfferableEnchant(itemID, item.targets) then
            table.insert(entries, {
                payload = item, icon = item.icon, count = item.count,
                text = item.link and item.link:match("%[(.-)%]") or "",
                targetSlot = FirstEquippedTarget(item.targets),
            })
        end
    end
    table.sort(entries, function(a, b) return a.payload.itemID < b.payload.itemID end)
    ShowPopup(button, C.L.gsApplyEnchant, "enchant", entries, C.L.gsNoEnchants)
end

-- The row sits just under the window's bottom edge, starting right after the
-- last tab. Anchored by an EDGE (not a centre) so it stays on whole pixels.
local function PlaceContainer(container)
    local cf = _G.CharacterFrame
    local tab = _G.CharacterFrameTab3 or _G.CharacterFrameTab2 or _G.CharacterFrameTab1
    if not (cf and tab) then
        return
    end
    local left, right = Plain(cf:GetLeft()), Plain(tab:GetRight())
    if not (left and right) then
        return
    end
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", (right - left) - 1, -1)
end

local function CreateIconButton(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    button:SetBackdropBorderColor(0, 0, 0, 1)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetPoint("TOPLEFT", 1, -1)
    hover:SetPoint("BOTTOMRIGHT", -1, 1)
    hover:SetColorTexture(1, 1, 1, 0.2)
    hover:SetBlendMode("ADD")
    return button
end

local function CreateContainer()
    if sockets.container then
        return sockets.container
    end
    local container = CreateFrame("Frame", nil, PaperDollFrame)
    container:SetSize(200, db.gemButtonSize)
    container:Hide()
    sockets.container = container
    return container
end

local function CreateSocketButton(index)
    if sockets.buttons[index] then
        return sockets.buttons[index]
    end
    local button = CreateIconButton(CreateContainer())
    button:SetScript("OnEnter", function(self)
        sockets.current = self
        ShowGemPopup(self)
        if self.info then
            ShowSlotHighlight(self.info.slotID)
        end
        if self.socket and self.socket.filled and self.socket.gemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 40, 0)
            GameTooltip:SetHyperlink(self.socket.gemLink)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
        CloseWhenAway()
    end)
    button:SetScript("OnClick", function(self)
        if InCombatLockdown() then
            UIErrorsFrame:AddExternalErrorMessage(C.L.gsNoCombat)
            return
        end
        if self.info then
            SocketInventoryItem(self.info.slotID)
        end
    end)
    sockets.buttons[index] = button
    return button
end

local function CreateEnchantButton()
    if sockets.enchantButton then
        return sockets.enchantButton
    end
    local button = CreateIconButton(CreateContainer())
    button.icon:SetTexture(ENCHANT_BUTTON_ICON)
    button.icon:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    button:SetScript("OnEnter", function(self)
        HidePopup()
        ShowEnchantPopup(self)
    end)
    button:SetScript("OnLeave", CloseWhenAway)
    sockets.enchantButton = button
    return button
end

local function HideSocketRow()
    if sockets.container then
        sockets.container:Hide()
    end
    HidePopup()
    HideSlotHighlight()
end

local function ScheduleSocketRetry()
    if socketRetryRunning then
        return
    end
    socketRetryRunning = true
    socketRetries = 0
    local function tick()
        if not AnySocketPending() or socketRetries >= 20 then
            socketRetryRunning = false
            -- Give up cleanly: draw what is known rather than a blank row.
            if AnySocketPending() then
                socketGuardExpired = true
                RefreshSockets()
            end
            return
        end
        socketRetries = socketRetries + 1
        RefreshSockets()
        C_Timer.After(0.5, tick)
    end
    C_Timer.After(0.5, tick)
end

RefreshSockets = function()
    if not (db and db.enabled and db.gemHelper) or not (PaperDollFrame and PaperDollFrame:IsShown()) then
        HideSocketRow()
        return
    end
    local container = CreateContainer()
    local size, gap = db.gemButtonSize, db.gemButtonSpacing
    container:SetHeight(size)
    PlaceContainer(container)

    -- Flattened first, then the meta socket hoisted to the front; two passes
    -- rather than a sort, which is not stable and would shuffle the rest.
    local ordered = {}
    for _, info in ipairs(ScanEquippedSockets()) do
        for _, socket in ipairs(info.sockets) do
            if not db.gemOnlyEmpty or not socket.filled then
                ordered[#ordered + 1] = { info = info, socket = socket }
            end
        end
    end
    if AnySocketPending() then
        ScheduleSocketRetry()
    end

    local shown = 0
    local previous
    for pass = 1, 2 do
        for _, entry in ipairs(ordered) do
            if (entry.socket.socketType == "Meta") == (pass == 1) then
                shown = shown + 1
                local button = CreateSocketButton(shown)
                button.info, button.socket = entry.info, entry.socket
                button:SetSize(size, size)
                button:ClearAllPoints()
                if previous then
                    button:SetPoint("LEFT", previous, "RIGHT", gap, 0)
                else
                    button:SetPoint("LEFT", container, "LEFT", 0, 0)
                end
                button.icon:SetTexture(entry.socket.icon or 458977)
                button:SetAlpha(entry.socket.filled and 1 or 0.6)
                button:Show()
                previous = button
            end
        end
    end
    for i = shown + 1, #sockets.buttons do
        sockets.buttons[i]:Hide()
    end

    -- The enchant button rides on the end of the same row, shown whenever it is
    -- switched on so an empty bag answers "No enchants" instead of hiding it.
    local total = shown
    if db.gemEnchantHelper then
        local button = CreateEnchantButton()
        button:SetSize(size, size)
        button:ClearAllPoints()
        button:SetPoint("LEFT", previous or container, previous and "RIGHT" or "LEFT", previous and gap or 0, 0)
        button:Show()
        total = total + 1
    elseif sockets.enchantButton then
        sockets.enchantButton:Hide()
    end

    container:SetWidth(math.max(1, total * (size + gap)))
    container:SetShown(total > 0)
    if total == 0 then
        HidePopup()
    end
end

-- ===== Window buttons (Omnium Foil, Great Vault) =====
-- Hung 1px under the window's right edge: the stat list is never in their way.
-- Parented to the stats pane so they hide with it (Titles and Equipment
-- Manager are views of the same tab), and only at max level, because Blizzard's
-- landing-page tooltip errors below it.
local OMNIUM_ICON, VAULT_ICON = 7554214, 2744751
local omniumButton, vaultButton
local minimapHooked, minimapHidByUs = false, false

local function PlaceWindowButton(button, slot)
    local cf = _G.CharacterFrame
    if not (button and cf) then
        return
    end
    local size = db.windowButtonSize
    button:SetSize(size, size)
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT", -(slot * (size + db.gemButtonSpacing)), -1)
end

local function CreateWindowButton(icon, slot)
    local host = _G.CharacterStatsPane or _G.PaperDollFrame
    local button = CreateIconButton(host)
    button:SetFrameLevel(PaperDollFrame:GetFrameLevel() + 10)
    button.icon:SetTexture(icon)
    PlaceWindowButton(button, slot)
    return button
end

local function ShowButtonTooltip(button, drawer)
    GameTooltip:SetOwner(button, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMRIGHT", button, "TOPLEFT", 0, 4)
    drawer()
    GameTooltip:Show()
end

local function EnsureOmniumButton()
    if omniumButton then
        return omniumButton
    end
    if not _G.PaperDollFrame then
        return nil
    end
    omniumButton = CreateWindowButton(OMNIUM_ICON, 0)
    -- Click the real minimap button rather than reimplementing its toggle, and
    -- reuse its tooltip so it stays localized.
    omniumButton:SetScript("OnClick", function()
        local mm = _G.ExpansionLandingPageMinimapButton
        if mm then
            mm:Click()
        end
    end)
    omniumButton:SetScript("OnEnter", function(self)
        local mm = _G.ExpansionLandingPageMinimapButton
        local onEnter = mm and mm:GetScript("OnEnter")
        if onEnter then
            pcall(onEnter, mm)
            GameTooltip:ClearAllPoints()
            GameTooltip:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", 0, 4)
        end
    end)
    omniumButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return omniumButton
end

local function EnsureVaultButton()
    if vaultButton then
        return vaultButton
    end
    if not _G.PaperDollFrame then
        return nil
    end
    vaultButton = CreateWindowButton(VAULT_ICON, 1)
    vaultButton:SetScript("OnClick", function()
        -- Load-on-demand: the vault frame does not exist until asked for.
        if C_AddOns and C_AddOns.LoadAddOn then
            C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")
        end
        local frame = _G.WeeklyRewardsFrame
        if frame then
            frame:SetShown(not frame:IsShown())
        end
    end)
    vaultButton:SetScript("OnEnter", function(self)
        ShowButtonTooltip(self, function()
            GameTooltip:SetText(_G.GREAT_VAULT_REWARDS or "Great Vault")
        end)
    end)
    vaultButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return vaultButton
end

local function RefreshWindowButtons()
    if not db then
        return
    end
    local allowed = db.enabled and AtMaxLevel("player")
    local wantOmnium = allowed and db.omniumButton
    local wantVault = allowed and db.vaultButton

    if wantOmnium then
        PlaceWindowButton(EnsureOmniumButton(), 0)
    end
    if wantVault then
        PlaceWindowButton(EnsureVaultButton(), 1)
    end
    if omniumButton then
        omniumButton:SetShown(wantOmnium and true or false)
    end
    if vaultButton then
        vaultButton:SetShown(wantVault and true or false)
    end

    -- The minimap button is hidden while the proxy is on, and only shown again
    -- if it was us who hid it (the player's minimap addon may hide it too).
    local mm = _G.ExpansionLandingPageMinimapButton
    if mm and not minimapHooked then
        minimapHooked = true
        hooksecurefunc(mm, "Show", function(self)
            if db and db.enabled and db.omniumButton and AtMaxLevel("player") then
                self:Hide()
            end
        end)
    end
    if mm then
        if wantOmnium then
            if mm:IsShown() then
                minimapHidByUs = true
            end
            mm:Hide()
        elseif minimapHidByUs then
            minimapHidByUs = false
            mm:Show()
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
    RefreshSockets()
    RefreshWindowButtons()
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
        if db and db.enabled then
            RefreshSockets()
            RefreshWindowButtons()
        end
    end)
    PaperDollFrame:HookScript("OnHide", function()
        ApplyWiden()
        HideSocketRow()
    end)
    if _G.CharacterFrame then
        CharacterFrame:HookScript("OnShow", RefreshWindowButtons)
    end
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
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        InitDB()
        HookCharacter()
        HookInspect()
        StyleCompareHeaders()
        -- The shopping tooltips can be created lazily on first use.
        -- and the landing-page minimap button may not exist yet at login.
        C_Timer.After(2, function()
            StyleCompareHeaders()
            RefreshWindowButtons()
        end)
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
    elseif event == "BAG_UPDATE_DELAYED" then
        if sockets.container and sockets.container:IsShown() then
            RefreshSockets()
        end
    else
        Queue("character")
        if event == "GET_ITEM_INFO_RECEIVED" then
            Queue("inspect", 0.3)
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            RefreshSockets()
        end
    end
end)

-- ===== Settings UI =====

local layout

local function Enabled()
    return db.enabled
end

local function GemHelper()
    return db.enabled and db.gemHelper
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

    layout:Header(C.L.gsSectionGems)
    layout:Toggle({
        label = C.L.gsGemLabel, desc = C.L.gsGemDesc, parent = Enabled,
        get = function() return db.gemHelper end,
        set = function(value) db.gemHelper = value; Apply() end,
    })
    layout:Toggle({
        label = C.L.gsGemEnchantLabel, desc = C.L.gsGemEnchantDesc, parent = GemHelper, indent = true,
        get = function() return db.gemEnchantHelper end,
        set = function(value) db.gemEnchantHelper = value; Apply() end,
    })
    layout:Toggle({
        label = C.L.gsGemEmptyLabel, desc = C.L.gsGemEmptyDesc, parent = GemHelper, indent = true,
        get = function() return db.gemOnlyEmpty end,
        set = function(value) db.gemOnlyEmpty = value; Apply() end,
    })
    layout:Slider({
        label = C.L.gsGemSizeLabel, desc = C.L.gsGemSizeDesc, parent = GemHelper,
        min = 16, max = 48, step = 1,
        get = function() return db.gemButtonSize end,
        set = function(value) db.gemButtonSize = value; Apply() end,
    })
    layout:Slider({
        label = C.L.gsGemSpacingLabel, desc = C.L.gsGemSpacingDesc, parent = GemHelper,
        min = 0, max = 12, step = 1,
        get = function() return db.gemButtonSpacing end,
        set = function(value) db.gemButtonSpacing = value; Apply() end,
    })
    layout:Note(C.L.gsGemNote)

    layout:Header(C.L.gsSectionButtons)
    layout:Toggle({
        label = C.L.gsOmniumLabel, desc = C.L.gsOmniumDesc, parent = Enabled,
        get = function() return db.omniumButton end,
        set = function(value) db.omniumButton = value; Apply() end,
    })
    layout:Toggle({
        label = C.L.gsVaultLabel, desc = C.L.gsVaultDesc, parent = Enabled,
        get = function() return db.vaultButton end,
        set = function(value) db.vaultButton = value; Apply() end,
    })
    layout:Slider({
        label = C.L.gsButtonSizeLabel, desc = C.L.gsButtonSizeDesc, parent = Enabled,
        min = 16, max = 48, step = 1,
        get = function() return db.windowButtonSize end,
        set = function(value) db.windowButtonSize = value; Apply() end,
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
