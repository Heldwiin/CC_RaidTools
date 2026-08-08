-- CC RaidTools - Core
local ADDON_NAME = ...
CCRT = CCRT or {}
local C = CCRT

C.BRAND_R, C.BRAND_G, C.BRAND_B = 0.451, 0.506, 1
C.modules = C.modules or {}

local GUI_TEXTURES="Interface\\AddOns\\CC_RaidTools\\TexturesGUI\\"

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

-- SwitchBox
function C.SkinCheckBox(box)
    if not box or box._ccrtSkin then return end
    box._ccrtSkin=true
    box:SetSize(48,24)
    box:EnableMouse(true)
    box:RegisterForClicks("LeftButtonUp")

    local CHECK_TEXTURE=GUI_TEXTURES.."ok-iconBlack.tga"
    local CROSS_TEXTURE=GUI_TEXTURES.."cross-small.png"
    local W,H=48,24
    local HALF=24

    box:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2})
    box:SetBackdropColor(0.01,0.01,0.012,1)
    box:SetBackdropBorderColor(0.01,0.01,0.012,1)

    local left=box:CreateTexture(nil,"ARTWORK")
    left:SetPoint("TOPLEFT",1,-1)
    left:SetSize(HALF-1,H-2)

    local right=box:CreateTexture(nil,"ARTWORK")
    right:SetPoint("TOPRIGHT",-1,-1)
    right:SetSize(HALF-1,H-2)

    local divider=box:CreateTexture(nil,"OVERLAY")
    divider:SetPoint("TOP",box,"TOP",0,-1)
    divider:SetPoint("BOTTOM",box,"BOTTOM",0,1)
    divider:SetWidth(1)
    divider:SetColorTexture(0.01,0.01,0.012,1)

    local checkmark=box:CreateTexture(nil,"OVERLAY")
    checkmark:SetSize(22,22)
    checkmark:SetPoint("CENTER",box,"CENTER",12,0)
    checkmark:SetTexture(CHECK_TEXTURE)
    checkmark:SetVertexColor(0,0,0,1)

    local crossmark=box:CreateTexture(nil,"OVERLAY")
    crossmark:SetSize(22,22)
    crossmark:SetPoint("CENTER",box,"CENTER",-12,0)
    crossmark:SetTexture(CROSS_TEXTURE)
    crossmark:SetVertexColor(0.10,0.10,0.10,1)

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
    hover:SetVertexColor(C.BRAND_R,C.BRAND_G,C.BRAND_B,0.08)
    hover:SetAlpha(0.08)

    local function refresh(self)
        local on=self:GetChecked() and true or false
        if on then
            left:SetColorTexture(0.30,0.31,0.59,1)
            right:SetColorTexture(0.38,0.40,0.76,1)
            checkmark:SetVertexColor(0,0,0,1)
            checkmark:Show()
            crossmark:Hide()
        else
            left:SetColorTexture(0.30,0.30,0.30,1)
            right:SetColorTexture(0.09,0.09,0.09,1)
            crossmark:SetVertexColor(0.10,0.10,0.10,1)
            crossmark:Show()
            checkmark:Hide()
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
    mainFrame:SetSize(320,705)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart",mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing(); SaveMainFramePosition() end)
    C.ApplyPanelSkin(mainFrame)
    RestoreMainFramePosition()
    local title=mainFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    title:SetPoint("TOP",0,-7)
    title:SetText("CC RaidTools")
    title:SetTextColor(C.BRAND_R,C.BRAND_G,C.BRAND_B)
    local close=CreateFrame("Button",nil,mainFrame)
    close:SetSize(22,22)
    close:SetPoint("TOPRIGHT",-4,-4)
    local closeTex=close:CreateTexture(nil,"ARTWORK")
    closeTex:SetPoint("CENTER")
    closeTex:SetSize(13,13)
    closeTex:SetTexture(GUI_TEXTURES.."Close.png")
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
SlashCmdList["CCRAIDTOOLS"]=function(msg)
    C.InitDB()
    if not msg or msg:match("^%s*$") then
        C.ToggleUI()
        return
    end
    print("|cff33ff99CC RaidTools|r - utilise simplement /ccrt pour ouvrir la configuration.")
end

local coreEvents=CreateFrame("Frame")
coreEvents:RegisterEvent("ADDON_LOADED")
coreEvents:SetScript("OnEvent",function(_,event,arg1)
    if event=="ADDON_LOADED" and arg1==ADDON_NAME then
        C.InitDB()
        print("|cff33ff99[CC RaidTools]|r v1.0 chargé")
    end
end)
