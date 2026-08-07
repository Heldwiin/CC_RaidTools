-- CC RaidTools - Ready Check
local C=CCRT
local frame,rows,statuses,hideTimer
local ROW_H=20
local FOOD={[308488]=1,[308506]=1,[308434]=1,[308514]=1,[327708]=1,[327706]=1,[327709]=1,[308525]=1,[327707]=1,[308637]=1,[308474]=1,[308504]=1,[308430]=1,[308509]=1,[327704]=1,[327701]=1,[327705]=1,[327702]=1,[382145]=1,[382150]=1,[382146]=1,[382149]=1,[396092]=1,[382246]=1,[382247]=1,[382152]=1,[382153]=1,[382157]=1,[382230]=1,[382231]=1,[382232]=1,[382154]=1,[382155]=1,[382156]=1,[382234]=1,[382235]=1,[382236]=1}
local FLASK={[1236763]=1,[1239355]=1,[1235057]=1,[1239755]=1,[1236767]=1,[1235111]=1,[1235110]=1,[1235108]=1}
local RUNE={[224001]=1,[270058]=1,[317065]=1,[347901]=1,[367405]=1,[393438]=1,[453250]=1,[1234969]=1,[1242347]=1,[1264426]=1}
local INT={[1459]=1,[264760]=1}; local AP={[6673]=1,[264761]=1}; local DRUID={[1126]=1}; local STAM={[21562]=1,[264764]=1}; local SHAM={[462854]=1}
local VANTUS={[269276]=1,[269405]=1,[269408]=1,[269407]=1,[269409]=1,[269411]=1,[269412]=1,[269413]=1,[298622]=1,[298640]=1,[298642]=1,[298643]=1,[298644]=1,[298645]=1,[298646]=1,[302914]=1,[306475]=1,[306480]=1,[306476]=1,[306477]=1,[306478]=1,[306484]=1,[306485]=1,[306479]=1,[313550]=1,[313551]=1,[313554]=1,[313556]=1,[311445]=1,[334132]=1,[311448]=1,[311446]=1,[311447]=1,[311449]=1,[311450]=1,[311451]=1,[311452]=1,[334131]=1,[354384]=1,[354385]=1,[354386]=1,[354387]=1,[354388]=1,[354389]=1,[354390]=1,[354391]=1,[354392]=1,[354393]=1,[384233]=1,[384234]=1,[384235]=1,[384229]=1,[384228]=1,[384227]=1,[384192]=1,[384203]=1,[384201]=1,[384239]=1,[384240]=1,[384241]=1,[384245]=1,[384246]=1,[384247]=1,[384220]=1,[384221]=1,[384222]=1,[384210]=1,[384209]=1,[384208]=1,[384214]=1,[384215]=1,[384216]=1,[384154]=1,[384248]=1,[384306]=1}
local vantusPrefix
local function GetVantusPrefix() if vantusPrefix~=nil then return vantusPrefix end; vantusPrefix=false; local n=C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(237825) or (GetSpellInfo and GetSpellInfo(237825)); if n then local p=n:match("^(.-)[:%-：]"); if p and p~="" then vantusPrefix="^"..p end end; return vantusPrefix end
local function SafeID(a) if not a then return end; if issecretvalue and issecretvalue(a.spellId) then return end; if canaccessvalue and a.spellId~=nil and not canaccessvalue(a.spellId) then return end; return a.spellId end
local function AuraStatus(unit)
    local food,flask,rune,vantus,intel,ap,druid,stam,sham=false,false,false,false,false,false,false,false,false
    if not unit or not UnitExists(unit) or (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) then return food,flask,rune,vantus,intel,ap,druid,stam,sham end
    local prefix=GetVantusPrefix()
    for i=1,80 do local a=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and C_UnitAuras.GetAuraDataByIndex(unit,i,"HELPFUL"); if not a then break end; local id=SafeID(a); if id then food=food or FOOD[id] or a.icon==136000; flask=flask or FLASK[id]; rune=rune or RUNE[id]; vantus=vantus or VANTUS[id] or (prefix and a.name and a.name:find(prefix)); intel=intel or INT[id]; ap=ap or AP[id]; druid=druid or DRUID[id]; stam=stam or STAM[id]; sham=sham or SHAM[id] end end
    return food,flask,rune,vantus,intel,ap,druid,stam,sham
end
local function OK(v)return v and "|cff33ff66OK|r" or "|cffff4444KO|r" end
local function Ready(v) if v==true or v=="ready" then return "|cff33ff66OK|r" elseif v==false or v=="notready" then return "|cffff4444KO|r" end return "|cffff9900WAIT|r" end
local function BuffIcon(row,x,spell)
    local t=row:CreateTexture(nil,"ARTWORK"); t:SetSize(16,16); t:SetPoint("CENTER",row,"LEFT",x+19,0); local icon=C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell) or (GetSpellTexture and GetSpellTexture(spell)); t:SetTexture(icon or 134400); t:SetTexCoord(.1,.9,.1,.9); return t
end
local function NewRow(parent,i)
    local r=CreateFrame("Frame",nil,parent); r:SetSize(615,ROW_H); r:SetPoint("TOPLEFT",0,-(i-1)*ROW_H)
    local function T(x,w,j)local f=r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f:SetPoint("LEFT",x,0); f:SetWidth(w); f:SetJustifyH(j or "CENTER"); return f end
    r.nameText=T(4,125,"LEFT"); r.readyText=T(130,48); r.foodText=T(179,48); r.flaskText=T(228,48); r.runeText=T(277,48); r.vantusText=T(326,52); r.intIcon=BuffIcon(r,380,1459); r.apIcon=BuffIcon(r,419,6673); r.druidIcon=BuffIcon(r,458,1126); r.stamIcon=BuffIcon(r,497,21562); r.shamIcon=BuffIcon(r,536,462854); return r
end
local function SetIcon(t,on)t:SetDesaturated(not on); t:SetAlpha(on and 1 or .4); if on then t:SetVertexColor(1,1,1) else t:SetVertexColor(.65,.65,.65) end end
local function BuildFrame()
    if frame then return end
    frame=CreateFrame("Frame","CCRaidToolsRaidCheckFrame",UIParent); frame:SetSize(625,520); frame:SetPoint("CENTER",320,0); frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton"); frame:SetScript("OnDragStart",frame.StartMoving); frame:SetScript("OnDragStop",frame.StopMovingOrSizing); C.ApplyPanelSkin(frame)
    local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormal"); title:SetPoint("TOP",0,-7); title:SetText("CC RaidTools - Ready Check v1.0"); title:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)
    local close=CreateFrame("Button",nil,frame); close:SetSize(22,22); close:SetPoint("TOPRIGHT",-4,-4); close:SetText("×"); close:SetNormalFontObject("GameFontNormalLarge"); close:SetScript("OnClick",function()frame:Hide()end); frame:Hide()
    local h=CreateFrame("Frame",nil,frame); h:SetPoint("TOPLEFT",12,-30); h:SetSize(590,20)
    local function H(txt,x,w,j)local f=h:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); f:SetPoint("LEFT",x,0); f:SetWidth(w); f:SetJustifyH(j or "CENTER"); f:SetText(txt); f:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B); return f end
    frame.count=H("0/0",4,125,"LEFT"); H("Prêt",130,48); H("Repas",179,48); H("Flacon",228,48); H("Rune",277,48); H("Vantus",326,52); H("Intel",380,38); H("PA",419,38); H("Druid",458,38); H("Endu",497,38); H("Sham",536,38)
    local s=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate"); s:SetPoint("TOPLEFT",12,-52); s:SetSize(580,445); C.SkinScrollBar(s); local child=CreateFrame("Frame",nil,s); child:SetSize(575,445); s:SetScrollChild(child); frame.child=child
end
local function Refresh()
    if not frame or not frame:IsShown() then return end; local count=IsInRaid() and GetNumGroupMembers() or 0; local ready=0
    for i=1,count do local name,_,_,_,_,class=GetRaidRosterInfo(i); local unit="raid"..i; local r=rows[i] or NewRow(frame.child,i); rows[i]=r; local col=class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]; if col then r.nameText:SetTextColor(col.r,col.g,col.b) else r.nameText:SetTextColor(1,1,1) end; r.nameText:SetText(C.StripRealm(name or "?")); local st=statuses[unit] or (name and (statuses[name] or statuses[C.StripRealm(name)])); if GetReadyCheckStatus then local api=GetReadyCheckStatus(unit); if api=="ready" or api=="notready" then st=api; statuses[unit]=api; if name then statuses[name]=api; statuses[C.StripRealm(name)]=api end end end; r.readyText:SetText(Ready(st)); if st=="ready" then ready=ready+1 end; local a,b,c,d,e,f,g,h,j=AuraStatus(unit); r.foodText:SetText(OK(a)); r.flaskText:SetText(OK(b)); r.runeText:SetText(OK(c)); r.vantusText:SetText(OK(d)); SetIcon(r.intIcon,e); SetIcon(r.apIcon,f); SetIcon(r.druidIcon,g); SetIcon(r.stamIcon,h); SetIcon(r.shamIcon,j); r:Show() end
    for i=count+1,#rows do rows[i]:Hide() end; frame.count:SetText("|cff66ff66"..ready.."|r|cff7381FF/"..count.."|r")
end
local function Show(starter)
    C.InitDB(); if not AutoPromoteDB.raidCheckEnabled or not IsInRaid() then return end; wipe(statuses); if starter then statuses[starter]="ready"; local n=UnitExists(starter) and UnitName(starter) or starter; if n then statuses[n]="ready"; statuses[C.StripRealm(n)]="ready" end end; BuildFrame(); if hideTimer then hideTimer:Cancel(); hideTimer=nil end; frame:Show(); Refresh(); C_Timer.After(.2,Refresh); C_Timer.After(.5,Refresh); C_Timer.After(1.5,Refresh); if frame.ticker then frame.ticker:Cancel() end; frame.ticker=C_Timer.NewTicker(.25,function()if frame:IsShown() then Refresh() end end)
end
local function Finish()
    for i=1,(GetNumGroupMembers() or 0) do local u="raid"..i; if UnitExists(u) then local n=UnitName(u); local s=statuses[u] or (n and statuses[n]) or (n and statuses[C.StripRealm(n)]); if s~="ready" and s~="notready" then statuses[u]="notready"; if n then statuses[n]="notready"; statuses[C.StripRealm(n)]="notready" end end end end; Refresh(); if frame and frame.ticker then frame.ticker:Cancel(); frame.ticker=nil end; if hideTimer then hideTimer:Cancel() end; hideTimer=C_Timer.NewTimer(30,function()if frame then frame:Hide() end end)
end
local function Update(unit,response) if not unit then return end; local s=response==true and "ready" or response==false and "notready" or nil; if not s then return end; statuses[unit]=s; local n=UnitExists(unit) and UnitName(unit) or unit; if n then statuses[n]=s; statuses[C.StripRealm(n)]=s end; Refresh() end

local chk
local function BuildUI(f)
    local label=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); label:SetPoint("TOPLEFT",f,"TOPLEFT",10,-585); label:SetText("Ready Check :"); label:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)
    chk=CreateFrame("CheckButton",nil,f,"BackdropTemplate"); chk:SetSize(24,24); C.SkinCheckBox(chk); chk:SetPoint("TOPLEFT",f,"TOPLEFT",10,-605); local t=chk:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); t:SetPoint("LEFT",chk,"RIGHT",2,0); t:SetText("Check Buffs /appel"); chk:SetScript("OnClick",function(self)AutoPromoteDB.raidCheckEnabled=self:GetChecked() and true or false; if self._ccrtRefresh then self:_ccrtRefresh() end; if not AutoPromoteDB.raidCheckEnabled and frame then frame:Hide() end end); f.raidCheckChk=chk
    local test=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); test:SetSize(54,22); test:SetPoint("RIGHT",f,"RIGHT",-16,0); test:SetPoint("CENTER",chk,"CENTER",0,0); test:SetText("Test"); C.SkinButton(test); test:SetScript("OnClick",function() if IsInRaid() then BuildFrame(); frame:Show(); Refresh() else print("|cff33ff99[CC RaidTools]|r Le test du Ready Check nécessite d'être dans un raid.") end end); f.raidCheckTestButton=test
end
local function RefreshUI() C.InitDB(); if chk then chk:SetChecked(AutoPromoteDB.raidCheckEnabled and true or false); if chk._ccrtRefresh then chk:_ccrtRefresh() end end end
C.RegisterModule("ReadyCheck",BuildUI,RefreshUI)
C.modules.ReadyCheck.command=function(cmd) if cmd=="raidcheck" then if IsInRaid() then BuildFrame(); frame:Show(); Refresh() else print("|cff33ff99[CC RaidTools]|r Tu n'es pas en raid.") end; return true end end

local e=CreateFrame("Frame"); for _,ev in ipairs({"READY_CHECK","READY_CHECK_CONFIRM","READY_CHECK_FINISHED","UNIT_AURA"}) do e:RegisterEvent(ev) end
e:SetScript("OnEvent",function(_,ev,a,b) if ev=="READY_CHECK" then Show(a) elseif ev=="READY_CHECK_CONFIRM" then Update(a,b); C_Timer.After(.1,Refresh); C_Timer.After(.5,Refresh) elseif ev=="READY_CHECK_FINISHED" then Finish() elseif ev=="UNIT_AURA" and frame and frame:IsShown() then Refresh() end end)
