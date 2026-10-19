-- CC RaidTools - UI kit
-- Shared building blocks for the module tabs, so every panel looks and lines
-- up the same way:
--   * UI.Title / UI.Band: the module name (same text as its menu button) in
--     the brand colour, plus a short intro beside the 100px header icon that
--     ModuleIcons.lua places in the panel's top-right corner;
--   * UI.NewLayout(panel): a vertical flow of 26px rows under the band, with
--     :Header, :Toggle, :Choice, :Input, :Button, :Row (custom) and :Note;
--   * UI.CreateSwitchMenu / UI.SkinEditBox: the dropdown and text field looks.
--
-- Each row has a short single-line label on the left and its control on the
-- right, so everything aligns; the detail of an option lives in its tooltip.
-- Rows alternate two dark bands and tint on hover; a toggle's label is muted
-- while it is off and brighter, with a brand accent bar, while it is on.
local C = CCRT
local UI = {}
C.UI = UI

UI.SIDE = 10          -- left margin inside a panel
UI.RIGHT = 12         -- right margin
UI.ROW_H = 26
UI.HEADER_H = 24
UI.SECTION_GAP = 6
UI.BAND_H = 110       -- title + intro band: stays clear of the header icon
UI.ICON_CLEAR = 112   -- right margin that keeps text off the header icon
UI.CONTENT_W = 480    -- 502px content area minus the side margins

local ON_COLOR = { 0.92, 0.93, 0.97 }
local OFF_COLOR = { 0.58, 0.58, 0.65 }
local NOTE_COLOR = { 0.66, 0.66, 0.72 }

-- ===== Title and intro band =====

-- The panel title is the module's menu label, so tab and page always agree.
function UI.Title(panel, moduleKey)
    local labels = C.moduleLabels or {}
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", UI.SIDE, -8)
    title:SetText(labels[moduleKey] or moduleKey)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)
    return title
end

function UI.Band(panel, moduleKey, intro)
    local title = UI.Title(panel, moduleKey)
    if intro and intro ~= "" then
        local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        text:SetPoint("RIGHT", panel, "RIGHT", -UI.ICON_CLEAR, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(true)
        text:SetTextColor(NOTE_COLOR[1], NOTE_COLOR[2], NOTE_COLOR[3])
        text:SetText(intro)
    end
    return title
end

-- ===== Text field and dropdown looks =====

function UI.SkinEditBox(editBox)
    editBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    editBox:SetBackdropColor(0.018, 0.018, 0.024, 0.90)
    editBox:SetBackdropBorderColor(0, 0, 0, 1)
    editBox:SetTextColor(1, 1, 1)
end

-- Dropdown: a button showing the current value, opening a small list.
-- values = { { shownText, value }, ... }. Returns a holder frame with
-- :SetValue(value), plus ._button / ._text / ._menu.
function UI.CreateSwitchMenu(parent, values, currentValue, onSelect, width)
    width = width or 118
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 24)

    local button = CreateFrame("Button", nil, holder)
    button:SetAllPoints()

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.035, 0.035, 0.045, 0.96)

    local border = button:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetVertexColor(0, 0, 0, 0.95)

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", 9, 0)
    text:SetPoint("RIGHT", -24, 0)
    text:SetJustifyH("LEFT")
    text:SetTextColor(0.92, 0.92, 0.92)

    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(14, 10)
    arrow:SetPoint("RIGHT", -7, 0)
    arrow:SetTexture("Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\arrow.png")
    arrow:SetVertexColor(1, 1, 1, 1)

    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetSize(width, #values * 24 + 2)
    menu:SetFrameStrata("DIALOG")
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    menu:SetBackdropColor(0.018, 0.018, 0.024, 0.98)
    menu:SetBackdropBorderColor(0, 0, 0, 1)
    menu:Hide()

    for index, entry in ipairs(values) do
        local row = CreateFrame("Button", nil, menu)
        row:SetSize(width - 2, 23)
        row:SetPoint("TOPLEFT", 1, -1 - (index - 1) * 24)

        local rowBackground = row:CreateTexture(nil, "BACKGROUND")
        rowBackground:SetAllPoints()
        rowBackground:SetColorTexture(0.018, 0.018, 0.024, 1)

        local rowText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rowText:SetPoint("LEFT", 8, 0)
        rowText:SetText(entry[1])
        rowText:SetTextColor(0.92, 0.92, 0.92)

        row:SetScript("OnEnter", function()
            rowBackground:SetColorTexture(C.BRAND_R * 0.35, C.BRAND_G * 0.35, C.BRAND_B * 0.48, 1)
        end)
        row:SetScript("OnLeave", function()
            rowBackground:SetColorTexture(0.018, 0.018, 0.024, 1)
        end)
        row:SetScript("OnClick", function()
            currentValue = entry[2]
            text:SetText(entry[1])
            menu:Hide()
            onSelect(entry[2], entry[1])
        end)
    end

    button:SetScript("OnEnter", function()
        background:SetColorTexture(0.07, 0.07, 0.09, 0.98)
    end)
    button:SetScript("OnLeave", function()
        background:SetColorTexture(0.035, 0.035, 0.045, 0.96)
    end)
    button:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
            return
        end
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -1)
        menu:Show()
    end)

    -- The list lives on UIParent, so it has to be closed by hand when the tab
    -- (and with it this dropdown) goes away.
    holder:SetScript("OnHide", function()
        menu:Hide()
    end)

    holder._button = button
    holder._text = text
    holder._menu = menu

    function holder:SetValue(value)
        for _, entry in ipairs(values) do
            if entry[2] == value then
                currentValue = value
                text:SetText(entry[1])
                return
            end
        end
    end

    holder:SetValue(currentValue)
    return holder
end

-- ===== Layout =====

local Layout = {}
Layout.__index = Layout

-- startY is where the first row goes, relative to the panel's top edge.
function UI.NewLayout(panel, startY)
    return setmetatable({
        panel = panel,
        y = startY or -UI.BAND_H,
        count = 0,
        rows = {},
        hasHeader = false,
    }, Layout)
end

local function ShowTooltip(owner, title, description)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title or "", 1, 1, 1)
    GameTooltip:AddLine(description, 0.8, 0.8, 0.85, true)
    GameTooltip:Show()
end

local function HideTooltip(owner)
    if GameTooltip:GetOwner() == owner then
        GameTooltip:Hide()
    end
end

-- Section header: brand-coloured text over a thin rule.
function Layout:Header(text)
    if self.hasHeader then
        self.y = self.y - UI.SECTION_GAP
    end
    self.hasHeader = true

    local header = CreateFrame("Frame", nil, self.panel)
    header:SetPoint("TOPLEFT", self.panel, "TOPLEFT", UI.SIDE, self.y)
    header:SetPoint("RIGHT", self.panel, "RIGHT", -UI.RIGHT, 0)
    header:SetHeight(UI.HEADER_H)

    local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 2, 4)
    label:SetText(text)
    label:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    line:SetHeight(1)
    line:SetColorTexture(C.BRAND_R * 0.6, C.BRAND_G * 0.6, C.BRAND_B * 0.6, 0.7)

    self.y = self.y - UI.HEADER_H
    return header
end

-- A row's frame: alternating band, hover tint, label on the left, optional
-- tooltip. `reserve` is how many pixels on the right belong to the control.
function Layout:Row(opts, clickable, reserve)
    self.count = self.count + 1
    local row = CreateFrame(clickable and "Button" or "Frame", nil, self.panel)
    row:SetPoint("TOPLEFT", self.panel, "TOPLEFT", UI.SIDE, self.y)
    row:SetPoint("RIGHT", self.panel, "RIGHT", -UI.RIGHT, 0)
    row:SetHeight(UI.ROW_H)
    row:EnableMouse(true)
    self.y = self.y - UI.ROW_H

    local baseAlpha = (self.count % 2 == 0) and 0.55 or 0.30
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.045, 0.045, 0.06, baseAlpha)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row, "LEFT", opts.indent and 34 or 12, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -(reserve or 0), 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.label:SetText(opts.label or "")
    row.label:SetTextColor(ON_COLOR[1], ON_COLOR[2], ON_COLOR[3])

    row:SetScript("OnEnter", function(self_)
        background:SetColorTexture(C.BRAND_R * 0.18, C.BRAND_G * 0.18, C.BRAND_B * 0.30, 0.85)
        if opts.desc then
            ShowTooltip(self_, opts.label, opts.desc)
        end
    end)
    row:SetScript("OnLeave", function(self_)
        background:SetColorTexture(0.045, 0.045, 0.06, baseAlpha)
        HideTooltip(self_)
    end)
    row:HookScript("OnHide", HideTooltip)

    table.insert(self.rows, row)
    return row
end

-- Switch row. opts: label, desc, get(), set(value), indent, parent().
-- The whole row is the click target; the switch only displays the state.
function Layout:Toggle(opts)
    local row = self:Row(opts, true, 62)

    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.accent:SetWidth(3)
    row.accent:SetColorTexture(C.BRAND_R, C.BRAND_G, C.BRAND_B, 1)

    row.check = CreateFrame("CheckButton", nil, row, "BackdropTemplate")
    row.check:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    C.SkinCheckBox(row.check)
    row.check:EnableMouse(false)
    for _, child in ipairs({ row.check:GetChildren() }) do
        child:EnableMouse(false)
    end

    row:SetScript("OnClick", function()
        opts.set(not (opts.get() and true or false))
        self:Refresh()
    end)

    row._paint = function()
        local on = opts.get() and true or false
        row.check:SetChecked(on)
        if row.check._ccrtRefresh then
            row.check:_ccrtRefresh()
        end
        row.accent:SetShown(on)
        local color = on and ON_COLOR or OFF_COLOR
        row.label:SetTextColor(color[1], color[2], color[3])
        -- A sub-option only matters while its parent option is on.
        if opts.parent then
            row:SetAlpha(opts.parent() and 1 or 0.45)
        end
    end
    return row
end

-- Dropdown row. opts: label, desc, values, get(), set(value), width.
function Layout:Choice(opts)
    local width = opts.width or 118
    local row = self:Row(opts, false, width + 18)
    row.drop = UI.CreateSwitchMenu(row, opts.values, opts.get(), function(value)
        opts.set(value)
    end, width)
    row.drop:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row._paint = function()
        row.drop:SetValue(opts.get())
    end
    return row
end

-- Button row. opts: label, desc, text, onClick, width.
function Layout:Button(opts)
    local width = opts.width or 120
    local row = self:Row(opts, false, width + 18)
    row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.button:SetSize(width, 22)
    row.button:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.button:SetText(opts.text or "")
    C.SkinButton(row.button)
    row.button:SetScript("OnClick", opts.onClick)
    return row
end

-- Text field row. opts: label, desc, width, maxLetters, get(), commit(text),
-- where commit may return the text to show instead (e.g. a normalised value).
function Layout:Input(opts)
    local width = opts.width or 200
    local row = self:Row(opts, false, width + 18)
    local edit = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    edit:SetSize(width, 22)
    edit:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(opts.maxLetters or 60)
    edit:SetFontObject("ChatFontNormal")
    edit:SetTextInsets(5, 5, 0, 0)
    UI.SkinEditBox(edit)

    local function Commit()
        local shown = opts.commit(edit:GetText())
        if shown then
            edit:SetText(shown)
        end
        edit:ClearFocus()
    end
    edit:SetScript("OnEnterPressed", Commit)
    edit:SetScript("OnEditFocusLost", Commit)
    edit:SetScript("OnEscapePressed", function(self_)
        self_:SetText(opts.get() or "")
        self_:ClearFocus()
    end)

    row.edit = edit
    row._paint = function()
        if not edit:HasFocus() then
            edit:SetText(opts.get() or "")
        end
    end
    return row
end

-- Wrapped note under the rows. Returns the font string.
function Layout:Note(text, color)
    color = color or NOTE_COLOR
    local note = self.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", self.panel, "TOPLEFT", UI.SIDE + 2, self.y - 8)
    note:SetWidth(UI.CONTENT_W - 4)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetTextColor(color[1], color[2], color[3])
    note:SetText(text)
    self.y = self.y - 8 - math.max(14, note:GetStringHeight() or 14) - 4
    return note
end

-- Re-reads every row's value from its getter.
function Layout:Refresh()
    for _, row in ipairs(self.rows) do
        if row._paint then
            row._paint()
        end
    end
end

-- Call once all rows are added. The main window sizes itself from the
-- panel's child *frames* only, so an empty frame at the bottom makes any
-- trailing note count towards the window height.
function Layout:Finish()
    local spacer = CreateFrame("Frame", nil, self.panel)
    spacer:SetSize(1, 1)
    spacer:SetPoint("TOPLEFT", self.panel, "TOPLEFT", UI.SIDE, self.y)
    self:Refresh()
    return spacer
end
