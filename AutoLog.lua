-- CC RaidTools - AutoLog
local C=CCRT
local startedByAddon=false
local lastStartAttempt=0
local lastStopAttempt=0
local ACTION_COOLDOWN=5

local function IsLoggingActive()
    if C_ChatInfo and C_ChatInfo.IsLoggingCombat then
        local enabled=C_ChatInfo.IsLoggingCombat()
        return enabled and true or false
    end
    return nil
end

local function StartLogging()
    local now=GetTime()
    if startedByAddon or AutoPromoteDB.loggingStartedByAddon then return end
    if (now-lastStartAttempt)<ACTION_COOLDOWN then return end

    lastStartAttempt=now
    local wasActive=IsLoggingActive()
    if wasActive==true then
        return
    end

    -- Intentionally do not call LoggingCombat() as a state query.
    -- The M+ path follows Method Raid Tools: CHALLENGE_MODE_START -> 1s -> LoggingCombat(true).
    local result=LoggingCombat(true)
    if result==true or result==nil then
        startedByAddon=true
        AutoPromoteDB.loggingStartedByAddon=true
        print("|cff33ff99[CC RaidTools]|r Enregistrement des combats démarré.")
    end
end

local function StopLogging()
    local now=GetTime()
    if not startedByAddon and not AutoPromoteDB.loggingStartedByAddon then return end
    if (now-lastStopAttempt)<ACTION_COOLDOWN then return end

    lastStopAttempt=now
    local result=LoggingCombat(false)
    if result==false or result==nil then
        startedByAddon=false
        AutoPromoteDB.loggingStartedByAddon=false
        print("|cff33ff99[CC RaidTools]|r Enregistrement des combats arrêté.")
    end
end

local function IsLoggingTarget()
    C.InitDB()
    local _,instanceType,difficultyID=GetInstanceInfo()
    local d=AutoPromoteDB.logging

    if instanceType=="raid" then
        return (difficultyID==17 and d.lfr)
            or (difficultyID==14 and d.normal)
            or (difficultyID==15 and d.heroic)
            or (difficultyID==16 and d.mythic)
    end

    if instanceType=="party" then
        return (difficultyID==23 and d.dungeonMythic)
            or (difficultyID==8 and d.dungeonMythicPlus)
    end

    return false
end

local function StartChallengeLogging()
    C.InitDB()
    if not AutoPromoteDB.logging.dungeonMythicPlus then return end
    if IsLoggingActive()==true then return end

    -- Same trigger/timing as MRT for Mythic+: do not run the generic scan here.
    StartLogging()
end

local function CheckAutoLog()
    C.InitDB()
    if IsLoggingTarget() then
        StartLogging()
    else
        StopLogging()
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
for _,ev in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","CHALLENGE_MODE_START","PLAYER_DIFFICULTY_CHANGED","UPDATE_INSTANCE_INFO"}) do e:RegisterEvent(ev) end
e:SetScript("OnEvent",function(_,event,arg1)
    if event=="ADDON_LOADED" and arg1=="CC_RaidTools" then
        C.InitDB()
        startedByAddon=AutoPromoteDB.loggingStartedByAddon and true or false
        C_Timer.After(2,CheckAutoLog)
    elseif event=="CHALLENGE_MODE_START" then
        C_Timer.After(1,StartChallengeLogging)
    else
        C_Timer.After(2,CheckAutoLog)
    end
end)
