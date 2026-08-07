-- CC RaidTools - Core
local ADDON_NAME = ...
CCRT = CCRT or {}
local C = CCRT

C.BRAND_R, C.BRAND_G, C.BRAND_B = 0.451, 0.506, 1
C.modules = C.modules or {}

function C.InitDB()
    if not AutoPromoteDB then AutoPromoteDB = {} end
    AutoPromoteDB.names = AutoPromoteDB.names or {}
    AutoPromoteDB.ranks = AutoPromoteDB.ranks or {}
    AutoPromoteDB.rankNames = AutoPromoteDB.rankNames or {}
    AutoPromoteDB.logging = AutoPromoteDB.logging or { lfr=false, normal=false, heroic=false, mythic=false }
    if AutoPromoteDB.raidCheckEnabled == nil then AutoPromoteDB.raidCheckEnabled = true end
    AutoPromoteDB.windowPos = AutoPromoteDB.windowPos or {}
end

function C.NormalizeName(name)
    if not name then return nil end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name ~= "" and name or nil
end

function C.StripRealm(name)
    if not name then return name end
    return name:match("^([^%-]+)") or name
end

function C.ApplyPanelSkin(frame)
    if not frame or frame._ccrtSkin then return end
    frame._ccrtSkin = true
    local bg = frame:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.025,0.025,0.035,0.82); frame._ccrtBg=bg
    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate"); border:SetAllPoints(); border:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); border:SetBackdropBorderColor(0,0,0,1); frame._ccrtBorder=border
    local divider = frame:CreateTexture(nil,"BORDER"); divider:SetPoint("TOPLEFT",1,-28); divider:SetPoint("TOPRIGHT",-1,-28); divider:SetHeight(1); divider:SetColorTexture(0,0,0,0.95)
end

function C.SkinButton(button)
    if not button or button._ccrtSkin then return end
    button._ccrtSkin=true
    for _,k in ipairs({"Left","Middle","Right","LeftDisabled","MiddleDisabled","RightDisabled"}) do if button[k] then button[k]:Hide() end end
    if button.SetNormalTexture then button:SetNormalTexture(""); button:SetPushedTexture(""); button:SetDisabledTexture("") end
    local bg=button:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.045,0.045,0.055,0.94); button._ccrtBg=bg
    local border=CreateFrame("Frame",nil,button,"BackdropTemplate"); border:SetAllPoints(); border:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); border:SetBackdropBorderColor(0,0,0,1)
    button:HookScript("OnEnter",function(self) self._ccrtBg:SetColorTexture(0.10,0.10,0.13,0.96) end)
    button:HookScript("OnLeave",function(self) self._ccrtBg:SetColorTexture(0.045,0.045,0.055,0.94) end)
end

function C.SkinCheckBox(box)
    if not box or box._ccrtSkin then return end
    box._ccrtSkin=true; box:EnableMouse(true); box:RegisterForClicks("LeftButtonUp")
    box:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); box:SetBackdropColor(0.035,0.035,0.045,1); box:SetBackdropBorderColor(0,0,0,1)
    local checked=box:CreateTexture(nil,"ARTWORK"); checked:SetPoint("TOPLEFT",3,-3); checked:SetPoint("BOTTOMRIGHT",-3,3); checked:SetColorTexture(C.BRAND_R*0.62,C.BRAND_G*0.62,C.BRAND_B*0.72,1)
    local tick=CreateFrame("Frame",nil,box); tick:SetAllPoints(); tick:EnableMouse(false)
    for _,r in ipairs({45,-45}) do local x=tick:CreateTexture(nil,"OVERLAY"); x:SetColorTexture(1,1,1,1); x:SetSize(2,13); x:SetPoint("CENTER"); x:SetRotation(math.rad(r)) end
    local hover=box:CreateTexture(nil,"HIGHLIGHT"); hover:SetPoint("TOPLEFT",2,-2); hover:SetPoint("BOTTOMRIGHT",-2,2); hover:SetColorTexture(C.BRAND_R,C.BRAND_G,C.BRAND_B,0.15)
    local function refresh(self) local on=self:GetChecked() and true or false; checked:SetShown(on); tick:SetShown(on) end
    box._ccrtRefresh=refresh; box:HookScript("OnShow",refresh); refresh(box)
end

function C.SkinScrollBar(scroll)
    local bar=scroll and scroll.ScrollBar
    if not bar or bar._ccrtSkin then return end
    bar._ccrtSkin=true
    for _,k in ipairs({"Background","Track","Back","Forward"}) do if bar[k] then bar[k]:Hide() end end
end

function C.RegisterModule(name, build, refresh)
    C.modules[name]={build=build,refresh=refresh,built=false}
end

local mainFrame
function C.GetMainFrame() return mainFrame end

local function SaveMainFramePosition()
    if not mainFrame or not AutoPromoteDB then return end
    local point,_,relativePoint,x,y = mainFrame:GetPoint(1)
    if point then
        AutoPromoteDB.windowPos.point=point
        AutoPromoteDB.windowPos.relativePoint=relativePoint or point
        AutoPromoteDB.windowPos.x=x or 0
        AutoPromoteDB.windowPos.y=y or 0
    end
end

local function RestoreMainFramePosition()
    if not mainFrame then return end
    mainFrame:ClearAllPoints()
    local p=AutoPromoteDB and AutoPromoteDB.windowPos
    if p and p.point then
        mainFrame:SetPoint(p.point,UIParent,p.relativePoint or p.point,p.x or 0,p.y or 0)
    else
        -- Première ouverture : légèrement décalée à droite du centre pour éviter de masquer le centre de l'écran.
        mainFrame:SetPoint("CENTER",UIParent,"CENTER",260,0)
    end
end

local function BuildMainFrame()
    if mainFrame then return mainFrame end
    C.InitDB()
    mainFrame=CreateFrame("Frame","CCRaidToolsFrame",UIParent)
    mainFrame:SetSize(320,705); mainFrame:SetMovable(true); mainFrame:EnableMouse(true); mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart",mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing(); SaveMainFramePosition() end)
    C.ApplyPanelSkin(mainFrame)
    RestoreMainFramePosition()
    local title=mainFrame:CreateFontString(nil,"OVERLAY","GameFontNormal"); title:SetPoint("TOP",0,-7); title:SetText("CC RaidTools"); title:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)
    local close=CreateFrame("Button",nil,mainFrame); close:SetSize(22,22); close:SetPoint("TOPRIGHT",-4,-4); close:SetText("×"); close:SetNormalFontObject("GameFontNormalLarge"); close:SetHighlightFontObject("GameFontHighlightLarge"); close:SetScript("OnClick",function() mainFrame:Hide() end)
    mainFrame:Hide()
    for _,m in pairs(C.modules) do if m.build and not m.built then m.build(mainFrame); m.built=true end end
    mainFrame:SetScript("OnShow",function() for _,m in pairs(C.modules) do if m.refresh then m.refresh(mainFrame) end end end)
    return mainFrame
end

function C.ToggleUI()
    local f=BuildMainFrame()
    if f:IsShown() then f:Hide() else f:Show() end
end

SLASH_CCRAIDTOOLS1="/ccrt"
SLASH_CCRAIDTOOLS2="/ccraidtools"
SLASH_CCRAIDTOOLS3="/ap"
SlashCmdList["CCRAIDTOOLS"]=function(msg)
    C.InitDB()
    local cmd,rest=msg:match("^(%S*)%s*(.-)$"); cmd=(cmd or ""):lower(); rest=C.NormalizeName(rest)
    if cmd=="" then C.ToggleUI(); return end
    for _,m in pairs(C.modules) do if m.command and m.command(cmd,rest) then return end end
    print("|cff33ff99CC RaidTools|r - Commandes disponibles :")
    print("  /ccrt - ouvre la fenêtre de configuration")
    print("  /ccrt add Nom-Royaume - ajoute un joueur")
    print("  /ccrt remove Nom-Royaume - retire un joueur")
    print("  /ccrt list - affiche la liste en texte")
    print("  /ccrt debug - diagnostic du raid en cours")
    print("  /ccrt raidcheck - ouvre le Ready Check manuellement")
end

local coreEvents=CreateFrame("Frame")
coreEvents:RegisterEvent("ADDON_LOADED")
coreEvents:SetScript("OnEvent",function(_,event,arg1)
    if event=="ADDON_LOADED" and arg1==ADDON_NAME then C.InitDB(); print("|cff33ff99[CC RaidTools]|r v1.1 chargé") end
end)
