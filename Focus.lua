-- CC RaidTools - Focus
local C=CCRT

-- SavedVariables are loaded after Lua files execute. Keep these references nil
-- until ADDON_LOADED, then bind them to the real saved table.
local focusDB
local modifier
local mouseButton
local previousModifier
local previousMouseButton

local function GetBindingKey() return string.upper(modifier).."-BUTTON"..mouseButton end
local function SetFocusHotkey(frame)
    if not frame or InCombatLockdown() then return end
    if previousModifier and previousMouseButton then frame:SetAttribute(previousModifier.."-type"..previousMouseButton,nil) end
    frame:SetAttribute(modifier.."-type"..mouseButton,"focus")
end
local function CreateFrame_Hook(type,name,parent,template) if template=="SecureUnitButtonTemplate" and name then SetFocusHotkey(_G[name]) end end
hooksecurefunc("CreateFrame",CreateFrame_Hook)

local focusButton=CreateFrame("CheckButton","CCRTFocusButton",UIParent,"SecureUnitButtonTemplate")
focusButton:SetAttribute("type1","macro"); focusButton:SetAttribute("macrotext","/focus mouseover")
local defaultUnitFrames={PlayerFrame,PetFrame,PartyMemberFrame1,PartyMemberFrame2,PartyMemberFrame3,PartyMemberFrame4,PartyMemberFrame1PetFrame,PartyMemberFrame2PetFrame,PartyMemberFrame3PetFrame,PartyMemberFrame4PetFrame,TargetFrame,TargetofTargetFrame}
function ApplyDefaultUnitFrameBindings() if InCombatLockdown() or not modifier then return end; for _,frame in ipairs(defaultUnitFrames) do SetFocusHotkey(frame) end end
local function ApplyFocusBinding()
    if InCombatLockdown() or not modifier or not mouseButton then return end
    local newKey=GetBindingKey(); local oldKey=previousModifier and previousMouseButton and (string.upper(previousModifier).."-BUTTON"..previousMouseButton)
    if oldKey and oldKey~=newKey then SetOverrideBinding(focusButton,true,oldKey,nil) end
    SetOverrideBindingClick(focusButton,true,newKey,"CCRTFocusButton"); ApplyDefaultUnitFrameBindings(); previousModifier=modifier; previousMouseButton=mouseButton
end
local function SaveFocusSettings()
    if not focusDB then return end
    focusDB.modifier=modifier
    focusDB.mouseButton=mouseButton
    AutoPromoteDB.focusModifier=modifier
    AutoPromoteDB.focusMouseButton=mouseButton
end

local function CreateSwitchMenu(parent, values, currentValue, onSelect)
    local holder=CreateFrame("Frame",nil,parent); holder:SetSize(118,24)
    local button=CreateFrame("Button",nil,holder); button:SetAllPoints()
    local bg=button:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.035,0.035,0.045,0.96)
    local border=button:CreateTexture(nil,"BORDER"); border:SetAllPoints(); border:SetTexture("Interface\\Buttons\\WHITE8X8"); border:SetVertexColor(0,0,0,0.95)
    local text=button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); text:SetPoint("LEFT",9,0); text:SetPoint("RIGHT",-24,0); text:SetJustifyH("LEFT"); text:SetTextColor(0.92,0.92,0.92)
    local arrow=button:CreateTexture(nil,"OVERLAY"); arrow:SetSize(14,10); arrow:SetPoint("RIGHT",-7,0); arrow:SetTexture("Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\arrow.png"); arrow:SetVertexColor(1,1,1,1)
    local menu=CreateFrame("Frame",nil,UIParent,"BackdropTemplate"); menu:SetSize(118,#values*24+2); menu:SetFrameStrata("DIALOG")
    menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); menu:SetBackdropColor(0.018,0.018,0.024,0.98); menu:SetBackdropBorderColor(0,0,0,1); menu:Hide()
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
local mouseValues={{"Left","1"},{"Right","2"},{"Middle","3"},{"Mouse 4","4"},{"Mouse 5","5"}}
local modifierDrop
local mouseDrop
local function BuildUI(f)
    local label=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); label:SetPoint("TOPLEFT",f,"TOPLEFT",12,-30); label:SetText("Focus :"); label:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)
    local modifierLabel=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); modifierLabel:SetPoint("TOPLEFT",label,"BOTTOMLEFT",0,-8); modifierLabel:SetText("Touche")
    modifierDrop=CreateSwitchMenu(f,modifierValues,modifier,function(value) modifier=value; SaveFocusSettings(); ApplyFocusBinding() end); modifierDrop:SetPoint("TOPLEFT",modifierLabel,"BOTTOMLEFT",0,-4)
    local mouseLabel=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); mouseLabel:SetPoint("TOPLEFT",modifierLabel,"TOPLEFT",158,0); mouseLabel:SetText("Clic souris")
    mouseDrop=CreateSwitchMenu(f,mouseValues,mouseButton,function(value) mouseButton=value; SaveFocusSettings(); ApplyFocusBinding() end); mouseDrop:SetPoint("TOPLEFT",modifierDrop,"TOPLEFT",158,0)
end
local function RefreshUI()
    if modifierDrop then modifierDrop:SetValue(focusDB.modifier) end
    if mouseDrop then mouseDrop:SetValue(focusDB.mouseButton) end
end
C.RegisterModule("Focus",BuildUI,RefreshUI)

local events=CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",function(_,event,arg1)
    if event=="ADDON_LOADED" and arg1=="CC_RaidTools" then
        C.InitDB()
        focusDB=AutoPromoteDB.focus
        modifier=focusDB.modifier or "shift"
        mouseButton=focusDB.mouseButton or "1"
        focusDB.modifier=modifier; focusDB.mouseButton=mouseButton
        AutoPromoteDB.focusModifier=modifier; AutoPromoteDB.focusMouseButton=mouseButton
        ApplyDefaultUnitFrameBindings(); ApplyFocusBinding(); RefreshUI()
    elseif event=="PLAYER_REGEN_ENABLED" then
        ApplyDefaultUnitFrameBindings(); ApplyFocusBinding()
    end
end)
