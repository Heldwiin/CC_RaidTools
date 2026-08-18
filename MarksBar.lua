-- CC RaidTools - Marks Bar
local C = CCRT
local db
local MARK_ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
-- Display order follows the Blizzard target-marker order:
-- 1 star, 2 circle, 3 diamond, 4 triangle, 5 moon, 6 square, 7 cross, 8 skull.
-- /wm command mapping supplied for CC:
-- 1 square, 2 triangle, 3 diamond, 4 cross, 5 star, 6 circle, 7 moon, 8 skull.
local WORLD_MARK_COMMAND = { [1]=5, [2]=6, [3]=3, [4]=2, [5]=7, [6]=1, [7]=4, [8]=8 }
local bar; local buttons={}; local worldButtons={}; local configRefresh; local layoutPending=false
local function SavePosition() if not bar or not db or InCombatLockdown() then return end; local point,_,relativePoint,x,y=bar:GetPoint(1); if point then db.point=point; db.relativePoint=relativePoint or point; db.x=x or 0; db.y=y or 0 end end
local function RestorePosition() if not bar or not db or InCombatLockdown() then return end; bar:ClearAllPoints(); bar:SetPoint(db.point or "CENTER",UIParent,db.relativePoint or "CENTER",db.x or 0,db.y or -180) end
local function SetMarkIcon(texture,index) texture:SetTexture(MARK_ICON_TEXTURE..index); texture:SetTexCoord(0,1,0,1) end
local function MakeIconButton(parent,width,height) local b=CreateFrame("Button",nil,parent,"SecureActionButtonTemplate"); b:SetSize(width,height); b:SetMouseClickEnabled(true); b:RegisterForClicks("AnyUp","AnyDown"); local bg=b:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.025,0.025,0.035,0.92); b.bg=bg; local border=b:CreateTexture(nil,"BORDER"); border:SetAllPoints(); border:SetTexture("Interface\\Buttons\\WHITE8X8"); border:SetVertexColor(0,0,0,0.95); local icon=b:CreateTexture(nil,"ARTWORK"); icon:SetPoint("TOPLEFT",3,-3); icon:SetPoint("BOTTOMRIGHT",-3,3); b.icon=icon; return b end
local function AddTooltip(b,title,line1) b:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:SetText(title); if line1 then GameTooltip:AddLine(line1,0.75,0.75,0.75) end; GameTooltip:Show(); self.bg:SetColorTexture(C.BRAND_R*0.22,C.BRAND_G*0.22,C.BRAND_B*0.30,0.98) end); b:SetScript("OnLeave",function(self) GameTooltip:Hide(); self.bg:SetColorTexture(0.025,0.025,0.035,0.92) end) end
local function SetupSecureRaidButton(button,index) button:SetAttribute("type1","macro"); button:SetAttribute("macrotext1","/tm [@target,exists] "..index); button:SetAttribute("type2","macro"); button:SetAttribute("macrotext2","/tm [@target,exists] 0") end
local function SetupSecureWorldButton(button,index) button:SetAttribute("type1","worldmarker"); button:SetAttribute("marker1",index); button:SetAttribute("action1","set"); button:SetAttribute("type2","worldmarker"); button:SetAttribute("marker2",index); button:SetAttribute("action2","clear") end
local function CreateRowBackground(parent) local bg=parent:CreateTexture(nil,"BACKGROUND"); bg:SetTexture("Interface\\Buttons\\WHITE8X8"); bg:SetVertexColor(0.015,0.015,0.02,0.90); return bg end
local function ApplyBarLayoutNow()
    if not bar or not db or InCombatLockdown() then layoutPending=true; return end
    layoutPending=false
    local horizontal=db.orientation=="HORIZONTAL"; local gap,raidSize,worldSize,count=2,30,23,8; local raidWidth=4+count*raidSize+(count-1)*gap; local worldWidth=4+count*worldSize+(count-1)*gap; local raidHeight,worldHeight=raidSize+4,worldSize+4; local worldOffset=(raidWidth-worldWidth)/2
    if not bar._raidRowBG then bar._raidRowBG=CreateRowBackground(bar); bar._worldRowBG=CreateRowBackground(bar) end
    bar._raidRowBG:ClearAllPoints(); bar._worldRowBG:ClearAllPoints()
    if horizontal then
        bar:SetSize(raidWidth,raidHeight+gap+worldHeight); bar._raidRowBG:SetSize(raidWidth,raidHeight); bar._raidRowBG:SetPoint("TOPLEFT",bar,"TOPLEFT",0,0); bar._worldRowBG:SetSize(worldWidth,worldHeight); bar._worldRowBG:SetPoint("TOPLEFT",bar,"TOPLEFT",worldOffset,-raidHeight-gap)
        for i,button in ipairs(buttons) do button:ClearAllPoints(); button:SetSize(raidSize,raidSize); button:SetPoint("TOPLEFT",bar,"TOPLEFT",2+(i-1)*(raidSize+gap),-2) end
        for i,button in ipairs(worldButtons) do button:ClearAllPoints(); button:SetSize(worldSize,worldSize); button:SetPoint("TOPLEFT",bar,"TOPLEFT",worldOffset+2+(i-1)*(worldSize+gap),-raidHeight-gap-2); button.icon:ClearAllPoints(); button.icon:SetPoint("TOPLEFT",3,-3); button.icon:SetPoint("BOTTOMRIGHT",-3,3) end
    else
        bar:SetSize(raidHeight+gap+worldHeight,raidWidth); bar._raidRowBG:SetSize(raidHeight,raidWidth); bar._raidRowBG:SetPoint("TOPLEFT",bar,"TOPLEFT",0,0); bar._worldRowBG:SetSize(worldHeight,worldWidth); bar._worldRowBG:SetPoint("TOPLEFT",bar,"TOPLEFT",raidHeight+gap,-worldOffset)
        for i,button in ipairs(buttons) do button:ClearAllPoints(); button:SetSize(raidSize,raidSize); button:SetPoint("TOPLEFT",bar,"TOPLEFT",2,-2-(i-1)*(raidSize+gap)) end
        for i,button in ipairs(worldButtons) do button:ClearAllPoints(); button:SetSize(worldSize,worldSize); button:SetPoint("TOPLEFT",bar,"TOPLEFT",raidHeight+gap+2,-worldOffset-2-(i-1)*(worldSize+gap)); button.icon:ClearAllPoints(); button.icon:SetPoint("TOPLEFT",3,-3); button.icon:SetPoint("BOTTOMRIGHT",-3,3) end
    end
    bar:SetBackdropColor(0,0,0,0); bar:SetBackdropBorderColor(0,0,0,0); bar:SetScale(db.scale or 1)
end
local function ApplyBarLayout() if InCombatLockdown() then layoutPending=true else ApplyBarLayoutNow() end end
local function ApplyDisplayMode() if not bar or not db then return end; if db.enabled then bar:Show(); if db.mouseoverDisplay then bar:SetAlpha(bar:IsMouseOver() and (db.alpha or 1) or 0) else bar:SetAlpha(db.alpha or 1) end else bar:Hide() end end
local function CreateBar()
    if bar then return bar end
    bar=CreateFrame("Frame","CCRaidToolsMarksBar",UIParent,"BackdropTemplate"); bar:SetMovable(true); bar:SetClampedToScreen(true); bar:EnableMouse(true); bar:RegisterForDrag("LeftButton"); bar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); bar:SetBackdropColor(0,0,0,0); bar:SetBackdropBorderColor(0,0,0,0)
    bar:SetScript("OnDragStart",function(self) if not db.locked and not InCombatLockdown() then self:StartMoving() end end); bar:SetScript("OnDragStop",function(self) if not InCombatLockdown() then self:StopMovingOrSizing(); SavePosition() end end)
    bar:SetScript("OnUpdate",function(self) if not db or not db.enabled or not db.mouseoverDisplay then return end; local wanted=self:IsMouseOver() and (db.alpha or 1) or 0; if self:GetAlpha()~=wanted then self:SetAlpha(wanted) end end)
    for i=1,8 do local b=MakeIconButton(bar,30,30); SetMarkIcon(b.icon,i); SetupSecureRaidButton(b,i); AddTooltip(b,"Marque de raid "..i,"Clic gauche : poser   |   Clic droit : retirer"); buttons[i]=b end
    for i=1,8 do
        local b=MakeIconButton(bar,23,23)
        local wm=WORLD_MARK_COMMAND[i]
        -- The icon uses Blizzard's target-marker index (same order as the target marker row).
        -- Only the secure world-marker action uses the /wm command mapping.
        SetMarkIcon(b.icon,i)
        b.icon:SetVertexColor(1,0.85,0.35,0.85)
        SetupSecureWorldButton(b,wm)
        AddTooltip(b,"Marqueur au sol "..i,"Clic gauche : placer   |   Clic droit : retirer")
        worldButtons[i]=b
    end
    RestorePosition(); ApplyBarLayout(); ApplyDisplayMode(); return bar
end
local function SetEnabled(value) if not db then return end; db.enabled=value and true or false; if InCombatLockdown() then return end; CreateBar(); ApplyDisplayMode() end
local function SetLocked(value) if not db then return end; db.locked=value and true or false; if bar and not InCombatLockdown() then bar:SetMovable(not db.locked) end end
local function SetMouseoverDisplay(value) if not db then return end; db.mouseoverDisplay=value and true or false; if bar and not InCombatLockdown() then ApplyDisplayMode() end end
local function ResetPosition() if InCombatLockdown() or not db then return end; db.point,db.relativePoint,db.x,db.y="CENTER","CENTER",0,-180; if bar then RestorePosition() end end
local function BuildUI(parent)
    local title=parent:CreateFontString(nil,"OVERLAY","GameFontNormal"); title:SetPoint("TOPLEFT",parent,"TOPLEFT",12,-30); title:SetText("Marks Bar :"); title:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)
    local enable=CreateFrame("CheckButton",nil,parent,"BackdropTemplate"); enable:SetSize(48,24); enable:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-8); C.SkinCheckBox(enable); enable:SetChecked(db.enabled); enable:SetScript("OnClick",function(self) SetEnabled(self:GetChecked()) end); local enableText=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); enableText:SetPoint("LEFT",enable,"RIGHT",8,0); enableText:SetText("Activer la barre")
    local lock=CreateFrame("CheckButton",nil,parent,"BackdropTemplate"); lock:SetSize(48,24); lock:SetPoint("TOPLEFT",enable,"BOTTOMLEFT",0,-12); C.SkinCheckBox(lock); lock:SetChecked(db.locked); lock:SetScript("OnClick",function(self) SetLocked(self:GetChecked()) end); local lockText=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); lockText:SetPoint("LEFT",lock,"RIGHT",8,0); lockText:SetText("Verrouiller la position")
    local mouse=CreateFrame("CheckButton",nil,parent,"BackdropTemplate"); mouse:SetSize(48,24); mouse:SetPoint("TOPLEFT",lock,"BOTTOMLEFT",0,-12); C.SkinCheckBox(mouse); mouse:SetChecked(db.mouseoverDisplay); mouse:SetScript("OnClick",function(self) SetMouseoverDisplay(self:GetChecked()) end); local mouseText=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); mouseText:SetPoint("LEFT",mouse,"RIGHT",8,0); mouseText:SetText("Afficher uniquement au mouseover")
    local orient=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); orient:SetPoint("TOPLEFT",mouse,"BOTTOMLEFT",0,-16); orient:SetText("Orientation")
    local horizontal=CreateFrame("Button",nil,parent); horizontal:SetSize(110,26); horizontal:SetPoint("TOPLEFT",orient,"BOTTOMLEFT",0,-5); C.SkinButton(horizontal); horizontal:SetText("Horizontal"); horizontal:SetNormalFontObject("GameFontHighlightSmall")
    local vertical=CreateFrame("Button",nil,parent); vertical:SetSize(110,26); vertical:SetPoint("LEFT",horizontal,"RIGHT",6,0); C.SkinButton(vertical); vertical:SetText("Vertical"); vertical:SetNormalFontObject("GameFontHighlightSmall")
    local function RefreshOrientation() local h=db.orientation=="HORIZONTAL"; horizontal._ccrtBg:SetColorTexture(h and C.BRAND_R*0.28 or 0.045,h and C.BRAND_G*0.28 or 0.045,h and C.BRAND_B*0.30 or 0.055,0.95); vertical._ccrtBg:SetColorTexture(not h and C.BRAND_R*0.28 or 0.045,not h and C.BRAND_G*0.28 or 0.045,not h and C.BRAND_B*0.30 or 0.055,0.95) end
    horizontal:SetScript("OnClick",function() db.orientation="HORIZONTAL"; RefreshOrientation(); ApplyBarLayout() end); vertical:SetScript("OnClick",function() db.orientation="VERTICAL"; RefreshOrientation(); ApplyBarLayout() end); RefreshOrientation()
    local reset=CreateFrame("Button",nil,parent); reset:SetSize(130,26); reset:SetPoint("TOPLEFT",horizontal,"BOTTOMLEFT",0,-14); C.SkinButton(reset); reset:SetText("Recentrer la barre"); reset:SetNormalFontObject("GameFontHighlightSmall"); reset:SetScript("OnClick",ResetPosition)
    local info=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); info:SetPoint("TOPLEFT",reset,"BOTTOMLEFT",0,-12); info:SetWidth(360); info:SetJustifyH("LEFT"); info:SetText("Ligne 1 : marques de raid.\nLigne 2 : marqueurs au sol.\nClic droit : retirer.\nLa barre est déplaçable tant qu'elle n'est pas verrouillée."); info:SetTextColor(0.65,0.65,0.65)
    configRefresh=function() enable:SetChecked(db.enabled); lock:SetChecked(db.locked); mouse:SetChecked(db.mouseoverDisplay); RefreshOrientation() end
end
C.RegisterModule("MarksBar",BuildUI,function() if configRefresh then configRefresh() end end)
local events=CreateFrame("Frame"); events:RegisterEvent("ADDON_LOADED"); events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",function(_,event,arg1)
    if event=="ADDON_LOADED" and arg1=="CC_RaidTools" then
        C.InitDB(); db=AutoPromoteDB.marksBar; db.scale=db.scale or 1; db.alpha=db.alpha or 1; db.point=db.point or "CENTER"; db.relativePoint=db.relativePoint or "CENTER"; db.x=db.x or 0; db.y=db.y or -180; db.orientation=db.orientation or "HORIZONTAL"; db.mouseoverDisplay=db.mouseoverDisplay or false; db.locked=db.locked or false; db.enabled=db.enabled or false; CreateBar(); SetLocked(db.locked); ApplyBarLayout(); ApplyDisplayMode(); if configRefresh then configRefresh() end
    elseif event=="PLAYER_REGEN_ENABLED" then
        if layoutPending then ApplyBarLayoutNow() end
        if bar then ApplyDisplayMode() end
    end
end)
