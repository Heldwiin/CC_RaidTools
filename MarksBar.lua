-- CC RaidTools - Marks Bar
local C = CCRT
C.InitDB()

AutoPromoteDB.marksBar = AutoPromoteDB.marksBar or {}
local db = AutoPromoteDB.marksBar
if db.enabled == nil then db.enabled = false end
if db.locked == nil then db.locked = false end
if db.orientation == nil then db.orientation = "HORIZONTAL" end
if db.scale == nil then db.scale = 1 end
if db.alpha == nil then db.alpha = 1 end
if db.point == nil then db.point = "CENTER" end
if db.relativePoint == nil then db.relativePoint = "CENTER" end
if db.x == nil then db.x = 0 end
if db.y == nil then db.y = -180 end

local MARK_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local MARK_COORDS = {
    [1] = {0, .25, 0, .25}, [2] = {.25, .5, 0, .25}, [3] = {.5, .75, 0, .25}, [4] = {.75, 1, 0, .25},
    [5] = {0, .25, .25, .5}, [6] = {.25, .5, .25, .5}, [7] = {.5, .75, .25, .5}, [8] = {.75, 1, .25, .5},
}

local bar
local buttons = {}
local configRefresh

local function SavePosition()
    if not bar then return end
    local point, _, relativePoint, x, y = bar:GetPoint(1)
    if point then
        db.point = point; db.relativePoint = relativePoint or point; db.x = x or 0; db.y = y or 0
    end
end

local function RestorePosition()
    if not bar then return end
    bar:ClearAllPoints()
    bar:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER", db.x or 0, db.y or -180)
end

local function SetMarkIcon(texture, index)
    texture:SetTexture(MARK_TEXTURE)
    local c = MARK_COORDS[index]
    if c then texture:SetTexCoord(c[1], c[2], c[3], c[4]) end
end

local function GetMarkUnit()
    if UnitExists("mouseover") then return "mouseover" end
    if UnitExists("target") then return "target" end
end

local function ToggleRaidMark(index)
    local unit = GetMarkUnit()
    if not unit then return end
    local current = GetRaidTargetIndex(unit)
    if current == index then SetRaidTarget(unit, 0) else SetRaidTarget(unit, index) end
end

local function ClearRaidMark()
    local unit = GetMarkUnit()
    if unit then SetRaidTarget(unit, 0) end
end

local function PlaceWorldMarker(index)
    if PlaceRaidMarker then PlaceRaidMarker(index) end
end

local function ClearWorldMarkers()
    if ClearRaidMarker then
        for i = 1, 8 do ClearRaidMarker(i) end
    end
end

local function MakeIconButton(parent, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.025, 0.025, 0.035, 0.92); b.bg = bg
    local border = b:CreateTexture(nil, "BORDER"); border:SetAllPoints(); border:SetTexture("Interface\\Buttons\\WHITE8X8"); border:SetVertexColor(0, 0, 0, 0.95)
    local icon = b:CreateTexture(nil, "ARTWORK"); icon:SetPoint("TOPLEFT", 3, -3); icon:SetPoint("BOTTOMRIGHT", -3, 3); b.icon = icon
    return b
end

local function ApplyBarLayout()
    if not bar then return end
    local horizontal = db.orientation == "HORIZONTAL"
    local gap, size = 2, 30
    local children = {}
    for _, b in ipairs(buttons) do children[#children + 1] = b end
    for _, b in ipairs(bar.worldButtons or {}) do children[#children + 1] = b end
    if bar.clearButton then children[#children + 1] = bar.clearButton end
    local x, y = 2, -2
    for _, b in ipairs(children) do
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", bar, "TOPLEFT", x, y)
        if horizontal then x = x + size + gap else y = y - size - gap end
    end
    local count = #children
    if horizontal then bar:SetSize(4 + count * size + math.max(0, count - 1) * gap, size + 4)
    else bar:SetSize(size + 4, 4 + count * size + math.max(0, count - 1) * gap) end
    bar:SetScale(db.scale or 1); bar:SetAlpha(db.alpha or 1)
end

local function CreateBar()
    if bar then return bar end
    bar = CreateFrame("Frame", "CCRaidToolsMarksBar", UIParent, "BackdropTemplate")
    bar:SetMovable(true); bar:SetClampedToScreen(true); bar:EnableMouse(true); bar:RegisterForDrag("LeftButton")
    bar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
    bar:SetBackdropColor(0.015,0.015,0.02,0.90); bar:SetBackdropBorderColor(0,0,0,1)
    bar:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
    bar:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition() end)

    for i = 1, 8 do
        local b = MakeIconButton(bar, 30, 30); SetMarkIcon(b.icon, i)
        b:SetScript("OnClick", function(self, button) if button == "RightButton" then ClearRaidMark() else ToggleRaidMark(i) end end)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("Marque de raid " .. i); GameTooltip:Show()
            self.bg:SetColorTexture(C.BRAND_R*0.22,C.BRAND_G*0.22,C.BRAND_B*0.30,0.98)
        end)
        b:SetScript("OnLeave", function(self) GameTooltip:Hide(); self.bg:SetColorTexture(0.025,0.025,0.035,0.92) end)
        buttons[i] = b
    end

    bar.worldButtons = {}
    for i = 1, 8 do
        local b = MakeIconButton(bar, 30, 30); SetMarkIcon(b.icon, i); b.icon:SetVertexColor(1,0.85,0.35,0.85)
        b:SetScript("OnClick", function(self, button) if button == "RightButton" then ClearWorldMarkers() else PlaceWorldMarker(i) end end)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("Marqueur au sol " .. i); GameTooltip:Show()
            self.bg:SetColorTexture(C.BRAND_R*0.22,C.BRAND_G*0.22,C.BRAND_B*0.30,0.98)
        end)
        b:SetScript("OnLeave", function(self) GameTooltip:Hide(); self.bg:SetColorTexture(0.025,0.025,0.035,0.92) end)
        bar.worldButtons[i] = b
    end

    local clear = MakeIconButton(bar, 30, 30)
    local cross = clear:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); cross:SetPoint("CENTER"); cross:SetText("×"); cross:SetTextColor(0.9,0.9,0.9)
    clear:SetScript("OnClick", ClearWorldMarkers); bar.clearButton = clear
    RestorePosition(); ApplyBarLayout(); bar:SetShown(db.enabled)
    return bar
end

local function SetEnabled(value) db.enabled = value and true or false; CreateBar():SetShown(db.enabled) end
local function SetLocked(value) db.locked = value and true or false; if bar then bar:SetMovable(not db.locked) end end
local function ResetPosition() db.point,db.relativePoint,db.x,db.y="CENTER","CENTER",0,-180; if bar then RestorePosition() end end

local function BuildUI(parent)
    local title = parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -30); title:SetText("Marks Bar :"); title:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)

    local enable = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    enable:SetSize(48,24); enable:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8); C.SkinCheckBox(enable); enable:SetChecked(db.enabled)
    enable:SetScript("OnClick", function(self) SetEnabled(self:GetChecked()) end)
    local enableText=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); enableText:SetPoint("LEFT",enable,"RIGHT",8,0); enableText:SetText("Activer la barre")

    local lock=CreateFrame("CheckButton",nil,parent,"BackdropTemplate")
    lock:SetSize(48,24); lock:SetPoint("TOPLEFT",enable,"BOTTOMLEFT",0,-12); C.SkinCheckBox(lock); lock:SetChecked(db.locked)
    lock:SetScript("OnClick",function(self) SetLocked(self:GetChecked()) end)
    local lockText=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); lockText:SetPoint("LEFT",lock,"RIGHT",8,0); lockText:SetText("Verrouiller la position")

    local orient=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); orient:SetPoint("TOPLEFT",lock,"BOTTOMLEFT",0,-16); orient:SetText("Orientation")
    local horizontal=CreateFrame("Button",nil,parent); horizontal:SetSize(110,26); horizontal:SetPoint("TOPLEFT",orient,"BOTTOMLEFT",0,-5); C.SkinButton(horizontal); horizontal:SetText("Horizontal"); horizontal:SetNormalFontObject("GameFontHighlightSmall")
    local vertical=CreateFrame("Button",nil,parent); vertical:SetSize(110,26); vertical:SetPoint("LEFT",horizontal,"RIGHT",6,0); C.SkinButton(vertical); vertical:SetText("Vertical"); vertical:SetNormalFontObject("GameFontHighlightSmall")
    local function RefreshOrientation()
        local h=db.orientation=="HORIZONTAL"
        horizontal._ccrtBg:SetColorTexture(h and C.BRAND_R*0.28 or 0.045,h and C.BRAND_G*0.28 or 0.045,h and C.BRAND_B*0.30 or 0.055,0.95)
        vertical._ccrtBg:SetColorTexture(not h and C.BRAND_R*0.28 or 0.045,not h and C.BRAND_G*0.28 or 0.045,not h and C.BRAND_B*0.30 or 0.055,0.95)
    end
    horizontal:SetScript("OnClick",function() db.orientation="HORIZONTAL"; RefreshOrientation(); ApplyBarLayout() end)
    vertical:SetScript("OnClick",function() db.orientation="VERTICAL"; RefreshOrientation(); ApplyBarLayout() end); RefreshOrientation()

    local reset=CreateFrame("Button",nil,parent); reset:SetSize(130,26); reset:SetPoint("TOPLEFT",horizontal,"BOTTOMLEFT",0,-14); C.SkinButton(reset); reset:SetText("Recentrer la barre"); reset:SetNormalFontObject("GameFontHighlightSmall"); reset:SetScript("OnClick",ResetPosition)
    local info=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); info:SetPoint("TOPLEFT",reset,"BOTTOMLEFT",0,-12); info:SetWidth(360); info:SetJustifyH("LEFT"); info:SetText("Clic gauche : marque.\nClic droit : retire.\nLa barre est déplaçable tant qu'elle n'est pas verrouillée."); info:SetTextColor(0.65,0.65,0.65)
    configRefresh=function() enable:SetChecked(db.enabled); lock:SetChecked(db.locked); RefreshOrientation() end
end

C.RegisterModule("MarksBar",BuildUI,function() if configRefresh then configRefresh() end end)
CreateBar(); SetLocked(db.locked)
