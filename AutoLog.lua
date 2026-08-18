-- CC RaidTools - AutoLog
local C=CCRT
local startedByAddon=false

local function CheckAutoLog()
    C.InitDB()
    local _,instanceType,difficultyID=GetInstanceInfo()
    local d=AutoPromoteDB.logging
    local shouldLog=instanceType=="raid" and ((difficultyID==17 and d.lfr) or (difficultyID==14 and d.normal) or (difficultyID==15 and d.heroic) or (difficultyID==16 and d.mythic))
    if instanceType=="party" then
        if difficultyID==23 and d.dungeonMythic then shouldLog=true elseif difficultyID==8 and d.dungeonMythicPlus then shouldLog=true end
    end
    local active=LoggingCombat()
    if shouldLog and not active then
        LoggingCombat(true); startedByAddon=true; AutoPromoteDB.loggingStartedByAddon=true
        print("|cff33ff99[CC RaidTools]|r Enregistrement des combats démarré.")
    elseif not shouldLog and active and (startedByAddon or AutoPromoteDB.loggingStartedByAddon) then
        LoggingCombat(false); startedByAddon=false; AutoPromoteDB.loggingStartedByAddon=false
        print("|cff33ff99[CC RaidTools]|r Enregistrement des combats arrêté.")
    elseif not active and not shouldLog then
        startedByAddon=false; AutoPromoteDB.loggingStartedByAddon=false
    end
end
C.CheckAutoLog=CheckAutoLog

local checks={}
local function BuildUI(f)
    local label=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); label:SetPoint("TOPLEFT",f,"TOPLEFT",12,-30); label:SetText("AutoLog :"); label:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)
    local previous=label
    for _,info in ipairs({{"LFR","lfr"},{"Normal","normal"},{"Héroïque","heroic"},{"Mythique","mythic"},{"Donjon Mythique","dungeonMythic"},{"Donjon Mythique+","dungeonMythicPlus"}}) do
        local chk=CreateFrame("CheckButton",nil,f,"BackdropTemplate"); chk:SetSize(48,24); C.SkinCheckBox(chk); chk:SetPoint("TOPLEFT",previous,"BOTTOMLEFT",0,-3)
        local text=chk:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); text:SetPoint("LEFT",chk,"RIGHT",7,0); text:SetText(info[1])
        chk:SetScript("OnClick",function(self) AutoPromoteDB.logging[info[2]]=self:GetChecked() and true or false; if self._ccrtRefresh then self:_ccrtRefresh() end; CheckAutoLog() end)
        checks[info[2]]=chk; previous=chk
    end
end
local function Refresh()
    C.InitDB(); for k,chk in pairs(checks) do chk:SetChecked(AutoPromoteDB.logging[k] and true or false); if chk._ccrtRefresh then chk:_ccrtRefresh() end end
end
C.RegisterModule("AutoLog",BuildUI,Refresh)

local e=CreateFrame("Frame")
for _,ev in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","GROUP_ROSTER_UPDATE","CHALLENGE_MODE_START","PLAYER_DIFFICULTY_CHANGED","UPDATE_INSTANCE_INFO"}) do e:RegisterEvent(ev) end
e:SetScript("OnEvent",function(_,event,arg1)
    if event=="ADDON_LOADED" and arg1=="CC_RaidTools" then
        C.InitDB(); startedByAddon=AutoPromoteDB.loggingStartedByAddon and true or false
        if not LoggingCombat() then startedByAddon=false; AutoPromoteDB.loggingStartedByAddon=false end
        C_Timer.After(2,CheckAutoLog)
    elseif event=="CHALLENGE_MODE_START" then C_Timer.After(1,CheckAutoLog)
    else C_Timer.After(2,CheckAutoLog) end
end)
