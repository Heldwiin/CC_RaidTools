-- CC RaidTools - Auto Promote
local C=CCRT
local discoveredRanks,guildRankByName,pending={},{},{}
local nameRows,rankRows={},{}

local function RequestRoster() if not IsInGuild() then return end; if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end end
local function RefreshRanksData()
    wipe(discoveredRanks); wipe(guildRankByName); if not IsInGuild() then return end
    for i=1,(GetNumGuildMembers and GetNumGuildMembers() or 0) do local name,rankName,rankIndex=GetGuildRosterInfo(i); if name and rankIndex~=nil then discoveredRanks[rankIndex]=rankName; guildRankByName[C.StripRealm(name)]=rankIndex end end
end
local function CheckAndPromote()
    C.InitDB(); if not IsInRaid() or not UnitIsGroupLeader("player") then return end
    for i=1,GetNumGroupMembers() do
        local name,rank=GetRaidRosterInfo(i)
        if name and rank==0 then
            local should=AutoPromoteDB.names[name] and true or false
            if not should then local idx=guildRankByName[C.StripRealm(name)]; local rn=idx and discoveredRanks[idx]; should=idx and (AutoPromoteDB.ranks[idx] or (rn and AutoPromoteDB.rankNames[rn])) end
            if should then if InCombatLockdown() then pending[name]=true else PromoteToAssistant(name); print("|cff33ff99[CC RaidTools]|r "..name.." promu(e) assistant de raid.") end end
        end
    end
end
C.CheckAndPromote=CheckAndPromote

local mainFrame
function AutoPromoteUI_RefreshNames()
    if not mainFrame then return end
    local sorted={}; for n in pairs(AutoPromoteDB.names) do table.insert(sorted,n) end; table.sort(sorted)
    for i,n in ipairs(sorted) do local r=nameRows[i]; if not r then r=CreateFrame("Frame",nil,mainFrame.nameChild); r:SetSize(260,20); r:SetPoint("TOPLEFT",0,-(i-1)*20); r.text=r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); r.text:SetPoint("LEFT",4,0); r.text:SetWidth(210); r.text:SetJustifyH("LEFT"); r.remove=CreateFrame("Button",nil,r,"UIPanelCloseButton"); r.remove:SetSize(20,20); r.remove:SetPoint("RIGHT"); r.remove:SetScript("OnClick",function() AutoPromoteDB.names[r.name]=nil; AutoPromoteUI_RefreshNames() end); nameRows[i]=r end; r.name=n; r.text:SetText(n); r:Show() end
    for i=#sorted+1,#nameRows do nameRows[i]:Hide() end
end
function AutoPromoteUI_RefreshRanks()
    if not mainFrame then return end
    local list={}; for idx,n in pairs(discoveredRanks) do table.insert(list,{index=idx,name=n}) end; table.sort(list,function(a,b)return a.index<b.index end); mainFrame.noGuildText:SetShown(#list==0)
    for i,info in ipairs(list) do
        local r=rankRows[i]
        if not r then r=CreateFrame("CheckButton",nil,mainFrame.rankChild,"BackdropTemplate"); r:SetSize(48,24); C.SkinCheckBox(r); r:SetPoint("TOPLEFT",0,-(i-1)*26); r.text=r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); r.text:SetPoint("LEFT",r,"RIGHT",7,0); r:SetScript("OnClick",function(self) local on=self:GetChecked() and true or false; AutoPromoteDB.ranks[self.rankIndex]=on; AutoPromoteDB.rankNames[self.rankName]=on; if self._ccrtRefresh then self:_ccrtRefresh() end; CheckAndPromote() end); rankRows[i]=r end
        r.rankIndex=info.index; r.rankName=info.name; r.text:SetText(info.name); local saved=AutoPromoteDB.rankNames[info.name]; if saved==nil then saved=AutoPromoteDB.ranks[info.index]; if saved~=nil then AutoPromoteDB.rankNames[info.name]=saved and true or false end end; AutoPromoteDB.ranks[info.index]=saved and true or false; r:SetChecked(saved and true or false); if r._ccrtRefresh then r:_ccrtRefresh() end; r:Show()
    end
    for i=#list+1,#rankRows do rankRows[i]:Hide() end
end

local function BuildUI(f)
    mainFrame=f
    local addLabel=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); addLabel:SetPoint("TOPLEFT",16,-30); addLabel:SetText("Ajouter des joueurs (un par ligne, format Nom-Royaume) :"); addLabel:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B); addLabel:SetWidth(288); addLabel:SetHeight(28); addLabel:SetJustifyH("LEFT"); addLabel:SetJustifyV("TOP")
    local input=CreateFrame("ScrollFrame",nil,f); input:SetPoint("TOPLEFT",16,-62); input:SetSize(288,60); local bg=input:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.018,0.018,0.024,0.90); local border=CreateFrame("Frame",nil,input,"BackdropTemplate"); border:SetAllPoints(); border:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); border:SetBackdropBorderColor(0,0,0,1)
    local edit=CreateFrame("EditBox",nil,input); edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetMaxLetters(2000); edit:SetFontObject("ChatFontNormal"); edit:SetTextColor(1,1,1); edit:SetSize(276,50); edit:SetJustifyH("LEFT"); edit:SetJustifyV("TOP"); input:SetScrollChild(edit); edit:SetPoint("TOPLEFT",6,-5); input:EnableMouse(true); input:SetScript("OnMouseDown",function()edit:SetFocus()end)
    local add=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); add:SetSize(90,22); add:SetPoint("TOPLEFT",input,"BOTTOMLEFT",0,-8); add:SetText("Ajouter"); C.SkinButton(add); add:SetScript("OnClick",function() for p in edit:GetText():gmatch("[^,\n]+") do local n=C.NormalizeName(p); if n then AutoPromoteDB.names[n]=true end end; edit:SetText(""); AutoPromoteUI_RefreshNames(); CheckAndPromote() end)
    local listLabel=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); listLabel:SetPoint("TOPLEFT",add,"BOTTOMLEFT",0,-14); listLabel:SetText("Joueurs Auto Promote :"); listLabel:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)
    local ns=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); ns:SetPoint("TOPLEFT",listLabel,"BOTTOMLEFT",0,-6); ns:SetSize(268,110); C.SkinScrollBar(ns); local nc=CreateFrame("Frame",nil,ns); nc:SetSize(260,110); ns:SetScrollChild(nc); f.nameChild=nc
    local rankLabel=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); rankLabel:SetPoint("TOPLEFT",ns,"BOTTOMLEFT",-4,-14); rankLabel:SetText("Rang à Auto Promote :"); rankLabel:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)
    local rs=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); rs:SetPoint("TOPLEFT",rankLabel,"BOTTOMLEFT",4,-6); rs:SetSize(264,100); C.SkinScrollBar(rs); local rc=CreateFrame("Frame",nil,rs); rc:SetSize(256,100); rs:SetScrollChild(rc); f.rankChild=rc
    local ng=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); ng:SetPoint("TOPLEFT",rc); ng:SetText("Pas de guilde, ou liste des rangs en cours de chargement..."); ng:SetWidth(250); ng:SetJustifyH("LEFT"); f.noGuildText=ng
end
local function Refresh() C.InitDB(); RequestRoster(); RefreshRanksData(); AutoPromoteUI_RefreshNames(); AutoPromoteUI_RefreshRanks() end
C.RegisterModule("AutoPromote",BuildUI,Refresh)

local e=CreateFrame("Frame"); for _,ev in ipairs({"GROUP_ROSTER_UPDATE","PLAYER_ENTERING_WORLD","GUILD_ROSTER_UPDATE","PLAYER_REGEN_ENABLED"}) do e:RegisterEvent(ev) end
e:SetScript("OnEvent",function(_,ev) if ev=="GUILD_ROSTER_UPDATE" then RefreshRanksData(); AutoPromoteUI_RefreshRanks() elseif ev=="PLAYER_REGEN_ENABLED" then for n in pairs(pending) do PromoteToAssistant(n); print("|cff33ff99[CC RaidTools]|r "..n.." promu(e) assistant de raid (après combat)."); pending[n]=nil end else CheckAndPromote() end end)

C.modules.AutoPromote.command=function(cmd,rest)
    if cmd=="add" and rest then AutoPromoteDB.names[rest]=true; print("|cff33ff99[CC RaidTools]|r "..rest.." ajouté à la liste."); AutoPromoteUI_RefreshNames(); return true end
    if cmd=="remove" and rest then AutoPromoteDB.names[rest]=nil; print("|cff33ff99[CC RaidTools]|r "..rest.." retiré de la liste."); AutoPromoteUI_RefreshNames(); return true end
    if cmd=="list" then print("|cff33ff99[CC RaidTools]|r Liste des joueurs à promouvoir :"); local empty=true; for n in pairs(AutoPromoteDB.names) do print("  - "..n); empty=false end; if empty then print("  (aucun)") end; return true end
    if cmd=="debug" then print("|cff33ff99[CC RaidTools] debug:|r Leader = "..tostring(UnitIsGroupLeader("player")).." | En combat = "..tostring(InCombatLockdown() and true or false)); return true end
end
RequestRoster()
