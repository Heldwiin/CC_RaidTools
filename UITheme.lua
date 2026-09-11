-- CC RaidTools - 2026 UI Theme
local C = CCRT or {}
CCRT = C
local ROOT = "Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\"
local ORDER = {"AutoPromote","AutoLog","ReadyCheck","RaidGroups","InviteTool","Focus","MarksBar","RaidInspect","BonusRoll","VersionCheck"}
local PURPLE = {0.62,0.30,1,1}
local GOLD = {1,0.72,0.25,1}
local TEXT = {0.95,0.94,1,1}
local MUTED = {0.60,0.58,0.72,1}
local function Skin(f,bg,br)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(unpack(bg)); f:SetBackdropBorderColor(unpack(br))
end
local function Text(p,s,point,x,y,size,col)
    local f=p:CreateFontString(nil,"OVERLAY","GameFontNormal")
    f:SetPoint(point,x or 0,y or 0); f:SetText(s)
    local font=f:GetFont(); if font then f:SetFont(font,size or 12,"OUTLINE") end
    if col then f:SetTextColor(unpack(col)) end
    f:SetShadowOffset(1,-1); f:SetShadowColor(0,0,0,1)
    return f
end
local function Button(b,selected)
    b:SetSize(148,38)
    if not b._ccrt2026bg then
        b._ccrt2026bg=b:CreateTexture(nil,"BACKGROUND"); b._ccrt2026bg:SetAllPoints()
        b._ccrt2026line=b:CreateTexture(nil,"BORDER"); b._ccrt2026line:SetPoint("TOPLEFT"); b._ccrt2026line:SetPoint("BOTTOMLEFT"); b._ccrt2026line:SetWidth(2)
        local h=b:CreateTexture(nil,"HIGHLIGHT"); h:SetAllPoints(); h:SetColorTexture(0.62,0.30,1,0.10)
    end
    if selected then b._ccrt2026bg:SetColorTexture(0.10,0.055,0.17,0.98); b._ccrt2026line:SetColorTexture(unpack(PURPLE))
    else b._ccrt2026bg:SetColorTexture(0.025,0.022,0.045,0.88); b._ccrt2026line:SetColorTexture(0.62,0.30,1,0) end
    if b.text then b.text:SetTextColor(unpack(selected and TEXT or MUTED)) end
end
local function Apply(frame)
    if not frame or frame._ccrt2026 then return end
    frame._ccrt2026=true; frame:SetSize(860,720)
    Skin(frame,{0.018,0.014,0.035,0.97},{0.30,0.20,0.52,0.85})
    local header=CreateFrame("Frame",nil,frame,"BackdropTemplate"); header:SetPoint("TOPLEFT",1,-1); header:SetPoint("TOPRIGHT",-1,-1); header:SetHeight(70); Skin(header,{0.028,0.020,0.055,0.98},{0.22,0.14,0.38,0.9})
    local logo=header:CreateTexture(nil,"ARTWORK"); logo:SetSize(56,56); logo:SetPoint("LEFT",10,-1); logo:SetTexture(ROOT.."logo.png")
    Text(header,"CC RaidTools","TOPLEFT",76,-12,18,TEXT); Text(header,"CAELESTIS CONCILIUM  •  RAID MANAGEMENT","TOPLEFT",77,-35,9,GOLD)
    local v=(C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("CC_RaidTools","Version")) or "?"; Text(header,"v"..v,"TOPLEFT",77,-51,9,MUTED)
    local pill=CreateFrame("Frame",nil,header,"BackdropTemplate"); pill:SetSize(108,20); pill:SetPoint("RIGHT",-48,13); Skin(pill,{0.10,0.045,0.17,0.95},{0.55,0.25,0.90,0.75}); Text(pill,"MIDNIGHT READY","CENTER",0,0,10,PURPLE)
    local line=frame:CreateTexture(nil,"BORDER"); line:SetPoint("TOPLEFT",10,-70); line:SetPoint("TOPRIGHT",-10,-70); line:SetHeight(1); line:SetColorTexture(0.62,0.30,1,0.65)
    local nav=CreateFrame("Frame",nil,frame,"BackdropTemplate"); nav:SetPoint("TOPLEFT",1,-71); nav:SetPoint("BOTTOMLEFT",1,1); nav:SetWidth(156); Skin(nav,{0.022,0.018,0.040,0.98},{0.12,0.08,0.22,0.95}); Text(nav,"MODULES","TOPLEFT",13,-15,9,MUTED); Text(nav,"CAELESTIS CONCILIUM","BOTTOM",0,24,8,MUTED); Text(nav,"TOGETHER • FURTHER","BOTTOM",0,11,8,PURPLE)
    local shell=CreateFrame("Frame",nil,frame,"BackdropTemplate"); shell:SetPoint("TOPLEFT",164,-78); shell:SetPoint("BOTTOMRIGHT",-8,8); Skin(shell,{0.020,0.018,0.038,0.92},{0.18,0.12,0.30,0.75})
    if frame.content then frame.content:ClearAllPoints(); frame.content:SetPoint("TOPLEFT",shell,"TOPLEFT",8,-8); frame.content:SetPoint("BOTTOMRIGHT",shell,"BOTTOMRIGHT",-8,8) end
    for _,r in ipairs({frame:GetRegions()}) do if r.GetObjectType and r:GetObjectType()=="FontString" then local t=r:GetText(); if t and (t:sub(1,12)=="CC RaidTools" or t=="Modules") then r:Hide() end end end
    local function ApplyButtons()
        if not frame.menuButtons then return end
        for n,name in ipairs(ORDER) do local b=frame.menuButtons[name]; if b then b:ClearAllPoints(); b:SetPoint("TOPLEFT",nav,"TOPLEFT",4,-42-(n-1)*42); Button(b,b.selected); local i=b._ccrtModuleIcon; if i and (name=="RaidGroups" or name=="BonusRoll" or name=="VersionCheck") then i:SetTexture(ROOT..name..".png") end end end
    end
    ApplyButtons(); if C_Timer and C_Timer.After then C_Timer.After(0,ApplyButtons) end
end
if C.RegisterUIHook then C.RegisterUIHook(Apply) else local e=CreateFrame("Frame"); e:RegisterEvent("ADDON_LOADED"); e:SetScript("OnEvent",function(_,_,a) if a=="CC_RaidTools" and CCRT and CCRT.RegisterUIHook then CCRT.RegisterUIHook(Apply) end end) end
