-- CC RaidTools - AutoLog
local C=CCRT
local startedByAddon=false
local lastActionAttempt=0
local pendingTimer=nil
local ACTION_RETRY_DELAY=10.5

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
        -- WoW Retail: 23 = Mythic 0, 8 = Mythic Keystone (M+).
        return (difficultyID==23 and d.dungeonMythic)
            or (difficultyID==8 and d.dungeonMythicPlus)
    end

    return false
end

local function ScheduleRetry()
    if pendingTimer then return end
    pendingTimer=true
    C_Timer.After(ACTION_RETRY_DELAY,function()
        pendingTimer=nil
        C.CheckAutoLog(true)
    end)
end

local function CheckAutoLog(forceQuery)
    C.InitDB()
    local shouldLog=IsLoggingTarget()
    local now=GetTime()

    if shouldLog then
        -- If CC already owns the logging session (including after /reload),
        -- do not query or toggle LoggingCombat again.
        if startedByAddon or AutoPromoteDB.loggingStartedByAddon then
            startedByAddon=true
            AutoPromoteDB.loggingStartedByAddon=true
            return
        end

        -- Query the state only when we are entering a logging target. This
        -- avoids exhausting the global LoggingCombat() rate limit with zone
        -- and group events.
        if now-lastActionAttempt<1 then return end
        lastActionAttempt=now
        local active=LoggingCombat()
        if active==nil then
            ScheduleRetry()
            return
        end
        if active then
            -- Logging was already enabled manually. Never claim ownership and
            -- never stop it when the player leaves the instance.
            return
        end

        local result=LoggingCombat(true)
        if result==true then
            startedByAddon=true
            AutoPromoteDB.loggingStartedByAddon=true
            print("|cff33ff99[CC RaidTools]|r Enregistrement des combats démarré.")
        else
            -- nil means the API was rate limited; retry after the documented
            -- cooldown instead of pretending logging started.
            ScheduleRetry()
        end
        return
    end

    -- Only stop logging when CC actually started it. Manual /combatlog usage
    -- is deliberately left untouched.
    if startedByAddon or AutoPromoteDB.loggingStartedByAddon then
        if now-lastActionAttempt<1 then return end
        lastActionAttempt=now
        local result=LoggingCombat(false)
        if result==false then
            startedByAddon=false
            AutoPromoteDB.loggingStartedByAddon=false
            print("|cff33ff99[CC RaidTools]|r Enregistrement des combats arrêté.")
        elseif result==nil then
            ScheduleRetry()
        end
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
        chk:SetScript("OnClick",function(self) AutoPromoteDB.logging[info[2]]=self:GetChecked() and true or false; if self._ccrtRefresh then self:_ccrtRefresh() end; C.CheckAutoLog(true) end)
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
        C_Timer.After(2,function() C.CheckAutoLog(true) end)
    elseif event=="CHALLENGE_MODE_START" then
        -- Mirrors Method Raid Tools: evaluate shortly after the keystone
        -- countdown starts, when GetInstanceInfo() reports difficulty 8.
        C_Timer.After(1,function() C.CheckAutoLog(true) end)
    else
        C_Timer.After(2,C.CheckAutoLog)
    end
end)
