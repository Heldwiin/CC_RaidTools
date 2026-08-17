-- CC RaidTools - Focus
local C=CCRT
C.InitDB()

AutoPromoteDB.focusModifier=AutoPromoteDB.focusModifier or "shift"
AutoPromoteDB.focusMouseButton=AutoPromoteDB.focusMouseButton or "1"

local modifier=AutoPromoteDB.focusModifier
local mouseButton=AutoPromoteDB.focusMouseButton
local previousModifier=modifier
local previousMouseButton=mouseButton

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
function ApplyDefaultUnitFrameBindings() if InCombatLockdown() then return end; for _,frame in ipairs(defaultUnitFrames) do SetFocusHotkey(frame) end end
local function ApplyFocusBinding()
    if InCombatLockdown() then return end
    local newKey=GetBindingKey(); local oldKey=previousModifier and previousMouseButton and (string.upper(previousModifier).."-BUTTON"..previousMouseButton)
    if oldKey and oldKey~=newKey then SetOverrideBinding(focusButton,true,oldKey,nil) end
    SetOverrideBindingClick(focusButton,true,newKey,"CCRTFocusButton"); ApplyDefaultUnitFrameBindings(); previousModifier=modifier; previousMouseButton=mouseButton
end
local function SaveFocusSettings() AutoPromoteDB.focusModifier=modifier; AutoPromoteDB.focusMouseButton=mouseButton end

local function BuildUI(f)
    local label=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); label:SetPoint("TOPLEFT",f,"TOPLEFT",12,-30); label:SetText("Focus :"); label:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)
    local modifierLabel=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); modifierLabel:SetPoint("TOPLEFT",label,"BOTTOMLEFT",0,-8); modifierLabel:SetText("Touche")
    local modifierDrop=CreateFrame("Frame","CCRTFocusModifierDropDown",f,"UIDropDownMenuTemplate"); modifierDrop:SetPoint("TOPLEFT",modifierLabel,"BOTTOMLEFT",-15,-2); UIDropDownMenu_SetWidth(modifierDrop,105)
    local mouseLabel=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); mouseLabel:SetPoint("TOPLEFT",modifierDrop,"TOPRIGHT",18,4); mouseLabel:SetText("Clic souris")
    local mouseDrop=CreateFrame("Frame","CCRTFocusMouseDropDown",f,"UIDropDownMenuTemplate"); mouseDrop:SetPoint("TOPLEFT",mouseLabel,"BOTTOMLEFT",-15,-2); UIDropMenu_SetWidth=UIDropMenu_SetWidth or UIDropDownMenu_SetWidth; UIDropDownMenu_SetWidth(mouseDrop,105)
    local modifiers={{"Shift","shift"},{"Alt","alt"},{"Ctrl","ctrl"}}; local mouseButtons={{"Left","1"},{"Right","2"},{"Middle","3"},{"Mouse 4","4"},{"Mouse 5","5"}}
    UIDropDownMenu_Initialize(modifierDrop,function(self,level) for _,info in ipairs(modifiers) do local d=UIDropDownMenu_CreateInfo(); d.text=info[1]; d.value=info[2]; d.checked=(modifier==info[2]); d.func=function() modifier=info[2]; SaveFocusSettings(); UIDropDownMenu_SetText(modifierDrop,info[1]); ApplyFocusBinding() end; UIDropDownMenu_AddButton(d,level) end end)
    UIDropDownMenu_Initialize(mouseDrop,function(self,level) for _,info in ipairs(mouseButtons) do local d=UIDropDownMenu_CreateInfo(); d.text=info[1]; d.value=info[2]; d.checked=(mouseButton==info[2]); d.func=function() mouseButton=info[2]; SaveFocusSettings(); UIDropDownMenu_SetText(mouseDrop,info[1]); ApplyFocusBinding() end; UIDropDownMenu_AddButton(d,level) end end)
    local modifierName="Shift"; local mouseName="Left"; for _,info in ipairs(modifiers) do if info[2]==modifier then modifierName=info[1] end end; for _,info in ipairs(mouseButtons) do if info[2]==mouseButton then mouseName=info[1] end end
    UIDropDownMenu_SetText(modifierDrop,modifierName); UIDropDownMenu_SetText(mouseDrop,mouseName)
end
C.RegisterModule("Focus",BuildUI,function() end)
ApplyDefaultUnitFrameBindings(); ApplyFocusBinding()
local events=CreateFrame("Frame"); events:RegisterEvent("PLAYER_REGEN_ENABLED"); events:RegisterEvent("PLAYER_LOGIN"); events:SetScript("OnEvent",function() ApplyDefaultUnitFrameBindings(); ApplyFocusBinding() end)
