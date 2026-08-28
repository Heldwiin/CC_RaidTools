-- CC RaidTools - Focus
local C = CCRT

local focusDB
local modifier
local mouseButton
local previousModifier
local previousMouseButton
local enabled = true

local function GetBindingKey()
    if not modifier or not mouseButton then return nil end
    return string.upper(modifier) .. "-BUTTON" .. mouseButton
end
local focusButton = CreateFrame("CheckButton", "CCRTFocusButton", UIParent, "SecureUnitButtonTemplate")
focusButton:SetAttribute("type1", "macro")
focusButton:SetAttribute("macrotext", "/focus mouseover")

local unitFrameBindings = setmetatable({}, { __mode = "k" })
local function UnitFocusAttributeName()
    if not modifier or not mouseButton then return nil end
    return string.lower(modifier) .. "-type" .. tostring(mouseButton)
end
local function RestoreUnitFrameBindings()
    if InCombatLockdown() then return end
    for frame, info in pairs(unitFrameBindings) do
        if frame and info and info.attribute then
            local current
            local ok = pcall(function() current = frame:GetAttribute(info.attribute) end)
            -- Only restore our own value. If another addon changed the
            -- attribute after we applied it, never overwrite that new value.
            if ok and current == "focus" then
                pcall(frame.SetAttribute, frame, info.attribute, info.original)
            end
        end
        unitFrameBindings[frame] = nil
    end
end
local function ApplyUnitFrameBindings()
    if InCombatLockdown() or not enabled then return end
    local attribute = UnitFocusAttributeName()
    if not attribute or not EnumerateFrames then return end
    local frame = EnumerateFrames()
    while frame do
        local isButton, unit = false, nil
        local ok = pcall(function()
            isButton = frame:IsObjectType("Button")
            unit = frame:GetAttribute("unit")
        end)
        if ok and isButton and unit and type(unit) == "string" then
            local already = unitFrameBindings[frame]
            if not already then
                local original
                local gotOriginal = pcall(function() original = frame:GetAttribute(attribute) end)
                if gotOriginal and pcall(frame.SetAttribute, frame, attribute, "focus") then
                    unitFrameBindings[frame] = { attribute = attribute, original = original }
                end
            elseif already.attribute ~= attribute then
                local current
                local gotCurrent = pcall(function() current = frame:GetAttribute(already.attribute) end)
                if gotCurrent and current == "focus" then
                    pcall(frame.SetAttribute, frame, already.attribute, already.original)
                end
                unitFrameBindings[frame] = nil
                local original
                local gotOriginal = pcall(function() original = frame:GetAttribute(attribute) end)
                if gotOriginal and pcall(frame.SetAttribute, frame, attribute, "focus") then
                    unitFrameBindings[frame] = { attribute = attribute, original = original }
                end
            end
        end
        frame = EnumerateFrames(frame)
    end
end
local function ApplyFocusBinding()
    if InCombatLockdown() then return end
    RestoreUnitFrameBindings()
    if not enabled then
        ClearOverrideBindings(focusButton); previousModifier=nil; previousMouseButton=nil; return
    end
    if not modifier or not mouseButton then return end
    local newKey = GetBindingKey()
    local oldKey = previousModifier and previousMouseButton and (string.upper(previousModifier) .. "-BUTTON" .. previousMouseButton)
    if oldKey and oldKey ~= newKey then SetOverrideBinding(focusButton, true, oldKey, nil) end
    SetOverrideBindingClick(focusButton, true, newKey, "CCRTFocusButton")
    previousModifier=modifier; previousMouseButton=mouseButton
    ApplyUnitFrameBindings()
end
local function SaveFocusSettings()
    if not focusDB then return end
    focusDB.enabled=enabled; focusDB.modifier=modifier; focusDB.mouseButton=mouseButton
    AutoPromoteDB.focusModifier=modifier; AutoPromoteDB.focusMouseButton=mouseButton
end
local function CreateSwitchMenu(parent, values, currentValue, onSelect)
    local holder=CreateFrame("Frame",nil,parent); holder:SetSize(118,24)
    local button=CreateFrame("Button",nil,holder); button:SetAllPoints()
    local bg=button:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.035,0.035,0.045,0.96)
    local border=button:CreateTexture(nil,"BORDER"); border:SetAllPoints(); border:SetTexture("Interface\\Buttons\\WHITE8X8"); border:SetVertexColor(0,0,0,0.95)
    local text=button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); text:SetPoint("LEFT",9,0); text:SetPoint("RIGHT",-24,0); text:SetJustifyH("LEFT"); text:SetTextColor(0.92,0.92,0.92)
    local arrow=button:CreateTexture(nil,"OVERLAY"); arrow:SetSize(14,10); arrow:SetPoint("RIGHT",-7,0); arrow:SetTexture("Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\arrow.png"); arrow:SetVertexColor(1,1,1,1)
    local menu=CreateFrame("Frame",nil,UIParent,"BackdropTemplate"); menu:SetSize(118,#values*24+2); menu:SetFrameStrata("DIALOG"); menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); menu:SetBackdropColor(0.018,0.018,0.024,0.98); menu:SetBackdropBorderColor(0,0,0,1); menu:Hide()
    for i,entry in ipairs(values) do
        local row=CreateFrame("Button",nil,menu); row:SetSize(116,23); row:SetPoint("TOPLEFT",1,-1-(i-1)*24)
        local rowBg=row:CreateTexture(nil,"BACKGROUND"); rowBg:SetAllPoints(); rowBg:SetColorTexture(0.018,0.018,0.024,1)
        local rowText=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); rowText:SetPoint("LEFT",8,0); rowText:SetText(entry[1]); rowText:SetTextColor(0.92,0.92,0.92)
        row:SetScript("OnEnter",function() rowBg:SetColorTexture(C.BRAND_R*0.35,C.BRAND_G*0.35,C.BRAND_B*0.48,1) end)
        row:SetScript("OnLeave",function() rowBg:SetColorTexture(0.018,0.018,0.024,1) end)
        row:SetScript("OnClick",function() currentValue=entry[2]; text:SetText(entry[1]); menu:Hide(); onSelect(entry[2],entry[1]) end)
    end
    button:SetScript("OnEnter",function() bg:SetColorTexture(0.07,0.07,0.09,0.98) end); button:SetScript("OnLeave",function() bg:SetColorTexture(0.035,0.035,0.045,0.96) end)
    button:SetScript("OnClick",function() if menu:IsShown() then menu:Hide() else menu:ClearAllPoints(); menu:SetPoint("TOPLEFT",holder,"BOTTOMLEFT",0,-1); menu:Show() end end)
    holder._button=button; holder._text=text; holder._menu=menu
    function holder:SetValue(value) for _,entry in ipairs(values) do if entry[2]==value then currentValue=value; text:SetText(entry[1]); return end end end
    holder:SetValue(currentValue); return holder
end
local modifierValues={{"Shift","shift"},{"Alt","alt"},{"Ctrl","ctrl"}}
local mouseValues={{C.L.mouseLeft,"1"},{C.L.mouseRight,"2"},{C.L.mouseMiddle,"3"},{C.L.mouse4,"4"},{C.L.mouse5,"5"}}
local modifierDrop,mouseDrop,enabledCheck
local function BuildUI(f)
    local label=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); label:SetPoint("TOPLEFT",f,"TOPLEFT",12,-30); label:SetText(C.L.focusLabel); label:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)
    enabledCheck=CreateFrame("CheckButton",nil,f,"BackdropTemplate"); enabledCheck:SetSize(48,24); C.SkinCheckBox(enabledCheck); enabledCheck:SetPoint("TOPLEFT",label,"BOTTOMLEFT",0,-8)
    enabledCheck:SetScript("OnClick",function(self) enabled=self:GetChecked() and true or false; SaveFocusSettings(); ApplyFocusBinding() end)
    local enabledLabel=enabledCheck:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); enabledLabel:SetPoint("LEFT",enabledCheck,"RIGHT",7,0); enabledLabel:SetText(C.L.focusEnable)
    local modifierLabel=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); modifierLabel:SetPoint("TOPLEFT",enabledCheck,"BOTTOMLEFT",0,-10); modifierLabel:SetText(C.L.focusKey)
    modifierDrop=CreateSwitchMenu(f,modifierValues,modifier,function(value) modifier=value; SaveFocusSettings(); ApplyFocusBinding() end); modifierDrop:SetPoint("TOPLEFT",modifierLabel,"BOTTOMLEFT",0,-4)
    local mouseLabel=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); mouseLabel:SetPoint("TOPLEFT",modifierLabel,"TOPLEFT",158,0); mouseLabel:SetText(C.L.focusMouseClick)
    mouseDrop=CreateSwitchMenu(f,mouseValues,mouseButton,function(value) mouseButton=value; SaveFocusSettings(); ApplyFocusBinding() end); mouseDrop:SetPoint("TOPLEFT",modifierDrop,"TOPLEFT",158,0)
end
local function RefreshUI()
    if enabledCheck and focusDB then enabledCheck:SetChecked(enabled); if enabledCheck._ccrtRefresh then enabledCheck:_ccrtRefresh() end end
    if modifierDrop and focusDB then modifierDrop:SetValue(focusDB.modifier) end
    if mouseDrop and focusDB then mouseDrop:SetValue(focusDB.mouseButton) end
end
C.RegisterModule("Focus",BuildUI,RefreshUI)
local events=CreateFrame("Frame"); events:RegisterEvent("ADDON_LOADED"); events:RegisterEvent("PLAYER_ENTERING_WORLD"); events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",function(_,event,arg1)
    if event=="ADDON_LOADED" and arg1=="CC_RaidTools" then
        C.InitDB(); focusDB=AutoPromoteDB.focus; enabled=focusDB.enabled; if enabled==nil then enabled=true end; modifier=focusDB.modifier or "shift"; mouseButton=focusDB.mouseButton or "1"
        focusDB.enabled=enabled; focusDB.modifier=modifier; focusDB.mouseButton=mouseButton; AutoPromoteDB.focusModifier=modifier; AutoPromoteDB.focusMouseButton=mouseButton; ApplyFocusBinding(); RefreshUI()
    elseif event=="PLAYER_REGEN_ENABLED" or event=="PLAYER_ENTERING_WORLD" then ApplyFocusBinding() end
end)
