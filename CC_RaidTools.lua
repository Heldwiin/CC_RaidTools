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

-- Checkbox/toggle using the same toggle geometry and textures as Atrocity Essentials.
function C.SkinCheckBox(box)
    if not box or box._ccrtSkin then return end
    box._ccrtSkin=true
    box:SetSize(48,24)
    box:EnableMouse(true)
    box:RegisterForClicks("LeftButtonUp")

    local CHECK_TEXTURE="Interface\\AddOns\\atrocityEssentials\\Media\\GUITextures\\ok-iconBlack.tga"
    local CROSS_TEXTURE="Interface\\AddOns\\atrocityEssentials\\Media\\GUITextures\\cross-small.png"
    local TOGGLE_WIDTH,TOGGLE_HEIGHT=48,24
    local KNOB_SIZE,KNOB_PADDING=22,1
    local OFF_POSITION=KNOB_PADDING
    local ON_POSITION=TOGGLE_WIDTH-KNOB_SIZE-KNOB_PADDING

    box:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    box:SetBackdropColor(0.035,0.035,0.045,1)
    box:SetBackdropBorderColor(0.10,0.10,0.14,1)

    local knob=CreateFrame("Frame",nil,box,"BackdropTemplate")
    knob:SetSize(KNOB_SIZE,KNOB_SIZE)
    knob:SetPoint("LEFT",box,"LEFT",OFF_POSITION,0)
    knob:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    knob:SetBackdropBorderColor(0.08,0.08,0.12,1)

    local knobTexture=knob:CreateTexture(nil,"ARTWORK")
    knobTexture:SetAllPoints()
    knobTexture:SetColorTexture(C.BRAND_R,C.BRAND_G,C.BRAND_B,0.6)

    local checkmark=knob:CreateTexture(nil,"OVERLAY")
    checkmark:SetSize(KNOB_SIZE,KNOB_SIZE)
    checkmark:SetPoint("CENTER",knob,"CENTER",0,0)
    checkmark:SetTexture(CHECK_TEXTURE)
    checkmark:SetVertexColor(1,1,1,1)
    checkmark:Hide()

    local crossmark=knob:CreateTexture(nil,"OVERLAY")
    crossmark:SetSize(KNOB_SIZE,KNOB_SIZE)
    crossmark:SetPoint("CENTER",knob,"CENTER",0,0)
    crossmark:SetTexture(CROSS_TEXTURE)
    crossmark:SetVertexColor(1,1,1,0.8)
    crossmark:Show()

    local click=CreateFrame("Button",nil,box)
    click:SetAllPoints(box)
    click:RegisterForClicks("LeftButtonUp")
    click:SetScript("OnClick",function()
        box:SetChecked(not box:GetChecked())
        if box._ccrtRefresh then box:_ccrtRefresh() end
        local handler=box:GetScript("OnClick")
        if handler then handler(box) end
    end)

    local hover=box:CreateTexture(nil,"HIGHLIGHT")
    hover:SetAllPoints(box)
    hover:SetTexture("Interface\\Buttons\\WHITE8X8")
    hover:SetVertexColor(C.BRAND_R,C.BRAND_G,C.BRAND_B,0.15)
    hover:SetAlpha(0.15)

    local function refresh(self)
        local on=self:GetChecked() and true or false
        if on then
            box:SetBackdropColor(C.BRAND_R*0.55,C.BRAND_G*0.55,C.BRAND_B*0.65,1)
            knob:ClearAllPoints(); knob:SetPoint("LEFT",box,"LEFT",ON_POSITION,0)
            knobTexture:SetColorTexture(C.BRAND_R,C.BRAND_G,C.BRAND_B,0.6)
            checkmark:Show(); crossmark:Hide()
        else
            box:SetBackdropColor(0.035,0.035,0.045,1)
            knob:ClearAllPoints(); knob:SetPoint("LEFT",box,"LEFT",OFF_POSITION,0)
            knobTexture:SetColorTexture(C.BRAND_R,C.BRAND_G,C.BRAND_B,0.6)
            checkmark:Hide(); crossmark:Show()
        end
    end

    box._ccrtRefresh=refresh
    box:HookScript("OnShow",refresh)
    refresh(box)
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
    local close=CreateFrame("Button",nil,mainFrame); close:SetSize(22,22); close:SetPoint("TOPRIGHT",-4,-4)
    local closeTex=close:CreateTexture(nil,"ARTWORK")
    closeTex:SetPoint("CENTER")
    closeTex:SetSize(13,13)
    closeTex:SetTexture("Interface\\AddOns\\atrocityEssentials\\Media\\GUITextures\\aesClose.png")
    closeTex:SetVertexColor(0.851,0.851,0.851,1)
    closeTex:SetTexelSnappingBias(0)
    closeTex:SetSnapToPixelGrid(true)
    close:SetScript("OnEnter",function() closeTex:SetVertexColor(C.BRAND_R,C.BRAND_G,C.BRAND_B,1) end)
    close:SetScript("OnLeave",function() closeTex:SetVertexColor(0.851,0.851,0.851,1) end)
    close:SetScript("OnClick",function() mainFrame:Hide() end)
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
    if event=="ADDON_LOADED" and arg1==ADDON_NAME then C.InitDB(); print("|cff33ff99[CC RaidTools]|r v1.0 chargé") end
end)
