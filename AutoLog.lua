-- CC RaidTools - AutoLog
local C=CCRT
local startedByAddon=false

local function CheckAutoLog()
    C.InitDB()
    local _,instanceType,difficultyID=GetInstanceInfo()
    local d=AutoPromoteDB.logging
    local shouldLog=instanceType=="raid" and ((difficultyID==17 and d.lfr) or (difficultyID==14 and d.normal) or (difficultyID==15 and d.heroic) or (difficultyID==16 and d.mythic))
    local active=LoggingCombat()
    if shouldLog and not active then LoggingCombat(true); startedByAddon=true; print("|cff33ff99[CC RaidTools]|r Enregistrement des combats démarré.")
    elseif not shouldLog and active and startedByAddon then LoggingCombat(false); startedByAddon=false; print("|cff33ff99[CC RaidTools]|r Enregistrement des combats arrêté.") end
end
C.CheckAutoLog=CheckAutoLog

local checks={}
local function BuildUI(f)
    local label=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); label:SetPoint("TOPLEFT",f,"TOPLEFT",12,-475); label:SetText("AutoLog :"); label:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)
    local previous=label
    for _,info in ipairs({{"LFR","lfr"},{"Normal","normal"},{"Héroïque","heroic"},{"Mythique","mythic"}}) do
        local chk=CreateFrame("CheckButton",nil,f,"BackdropTemplate"); chk:SetSize(24,24); C.SkinCheckBox(chk); chk:SetPoint("TOPLEFT",previous,"BOTTOMLEFT",0,-2)
        local text=chk:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); text:SetPoint("LEFT",chk,"RIGHT",2,0); text:SetText(info[1])
        chk:SetScript("OnClick",function(self) AutoPromoteDB.logging[info[2]]=self:GetChecked() and true or false; if self._ccrtRefresh then self:_ccrtRefresh() end; CheckAutoLog() end)
        checks[info[2]]=chk; previous=chk
    end
end
local function Refresh()
    C.InitDB(); for k,chk in pairs(checks) do chk:SetChecked(AutoPromoteDB.logging[k] and true or false); if chk._ccrtRefresh then chk:_ccrtRefresh() end end
end
C.RegisterModule("AutoLog",BuildUI,Refresh)

local e=CreateFrame("Frame"); e:RegisterEvent("PLAYER_ENTERING_WORLD"); e:RegisterEvent("ZONE_CHANGED_NEW_AREA"); e:RegisterEvent("GROUP_ROSTER_UPDATE")
e:SetScript("OnEvent",function() C_Timer.After(2,CheckAutoLog) end)
