-- CC RaidTools - Invite Tool
local C=CCRT
local enabled,keyword

local function InitDB()
    C.InitDB(); AutoPromoteDB.inviteTool=AutoPromoteDB.inviteTool or {}
    if AutoPromoteDB.inviteTool.keyword==nil then AutoPromoteDB.inviteTool.keyword="inv" end
    if AutoPromoteDB.inviteTool.enabled==nil then AutoPromoteDB.inviteTool.enabled=true end
end
local function Normalize(msg) if not msg then return "" end return msg:gsub("^%s+",""):gsub("%s+$",""):lower() end
local function SkinEdit(box) box:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); box:SetBackdropColor(0.018,0.018,0.024,0.90); box:SetBackdropBorderColor(0,0,0,1); box:SetTextColor(1,1,1) end

local function BuildUI(f)
    InitDB()
    local title=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); title:SetPoint("TOPLEFT",f,"TOPLEFT",10,-640); title:SetText("Invite Tool :"); title:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)
    enabled=CreateFrame("CheckButton",nil,f,"BackdropTemplate"); enabled:SetSize(24,24); enabled:SetPoint("TOPLEFT",f,"TOPLEFT",10,-660); C.SkinCheckBox(enabled)
    local label=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); label:SetPoint("LEFT",enabled,"RIGHT",2,0); label:SetText("Mot-clé :")
    keyword=CreateFrame("EditBox",nil,f,"BackdropTemplate"); keyword:SetSize(90,22); keyword:SetPoint("LEFT",label,"RIGHT",6,0); keyword:SetAutoFocus(false); keyword:SetMaxLetters(20); keyword:SetFontObject("ChatFontNormal"); keyword:SetTextInsets(5,5,0,0); SkinEdit(keyword)
    enabled:SetScript("OnClick",function(self) AutoPromoteDB.inviteTool.enabled=self:GetChecked() and true or false; if self._ccrtRefresh then self:_ccrtRefresh() end end)
    local function Save() local v=Normalize(keyword:GetText()); if v=="" then v="inv" end; AutoPromoteDB.inviteTool.keyword=v; keyword:SetText(v); keyword:ClearFocus() end
    keyword:SetScript("OnEnterPressed",Save); keyword:SetScript("OnEditFocusLost",Save); keyword:SetScript("OnEscapePressed",function(self) self:SetText(AutoPromoteDB.inviteTool.keyword or "inv"); self:ClearFocus() end)
end
local function Refresh() InitDB(); if enabled then enabled:SetChecked(AutoPromoteDB.inviteTool.enabled and true or false); if enabled._ccrtRefresh then enabled:_ccrtRefresh() end end; if keyword then keyword:SetText(AutoPromoteDB.inviteTool.keyword or "inv") end end
C.RegisterModule("InviteTool",BuildUI,Refresh)

local function Invite(message,sender)
    InitDB(); if not AutoPromoteDB.inviteTool.enabled or not sender or sender=="" then return end
    local word=Normalize(AutoPromoteDB.inviteTool.keyword); if word=="" or Normalize(message)~=word then return end
    if InCombatLockdown() then SendChatMessage("Invitation impossible pendant le combat.","WHISPER",nil,sender); return end
    if IsInGroup() and not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then return end
    if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(sender) elseif InviteUnit then InviteUnit(sender) end
end
local e=CreateFrame("Frame"); e:RegisterEvent("PLAYER_LOGIN"); e:RegisterEvent("CHAT_MSG_WHISPER")
e:SetScript("OnEvent",function(_,ev,...) if ev=="PLAYER_LOGIN" then InitDB() else local msg,sender=...; Invite(msg,sender) end end)
