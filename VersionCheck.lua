-- CC RaidTools - Version Check
-- Broadcasts the local addon version to raid/party and guild, so outdated
-- clients find out on their own (like DBM's version check), and shows an
-- officer-facing list of who's running which version.
local C = CCRT

local ADDON_NAME = "CC_RaidTools"
local VERSION_PREFIX = "CCRT_VER"
local BROADCAST_COOLDOWN = 60 -- seconds between roster-triggered rebroadcasts

local function GetLocalVersion()
    local v = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"))
        or (GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version"))
    return v or "?"
end

local localVersion = GetLocalVersion()
local known = {} -- known[name] = { version = "1.2.10", ts = epoch }
local warnedThisSession = false
local lastBroadcast = 0

local function ParseVersion(v)
    local parts = {}
    for numStr in tostring(v):gmatch("%d+") do
        parts[#parts + 1] = tonumber(numStr)
    end
    return parts
end

-- Returns true if version `a` is strictly newer than version `b`.
local function VersionGreater(a, b)
    local pa, pb = ParseVersion(a), ParseVersion(b)
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then
            return x > y
        end
    end
    return false
end

local frame
local listChild
local rows = {}
local countText

local function RefreshList()
    if not frame or not frame:IsShown() then
        return
    end

    local entries = {}
    entries[#entries + 1] = { name = C.StripRealm(UnitName("player")), version = localVersion, isSelf = true }
    for name, data in pairs(known) do
        entries[#entries + 1] = { name = name, version = data.version }
    end
    table.sort(entries, function(a, b) return a.name < b.name end)

    local upToDate = 0
    for i, entry in ipairs(entries) do
        local row = rows[i]
        if not row then
            row = CreateFrame("Frame", nil, listChild, "BackdropTemplate")
            row:SetSize(300, 20)
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            row:SetBackdropColor(0.03, 0.03, 0.04, 0.85)
            row:SetBackdropBorderColor(0, 0, 0, 1)
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.name:SetPoint("LEFT", 6, 0)
            row.name:SetWidth(150)
            row.name:SetJustifyH("LEFT")
            row.version = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.version:SetPoint("LEFT", 160, 0)
            row.version:SetWidth(70)
            row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.status:SetPoint("LEFT", 232, 0)
            row.status:SetWidth(80)
            rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -(i - 1) * 22)
        row.name:SetText(entry.name .. (entry.isSelf and (" " .. C.L.vcYouTag) or ""))
        row.name:SetTextColor(entry.isSelf and C.BRAND_R or 1, entry.isSelf and C.BRAND_G or 1, entry.isSelf and C.BRAND_B or 1)
        row.version:SetText(entry.version)
        if VersionGreater(localVersion, entry.version) then
            row.status:SetText(C.L.vcOutdatedTag)
            row.status:SetTextColor(1, 0.35, 0.35)
        elseif VersionGreater(entry.version, localVersion) then
            row.status:SetText(C.L.vcNewerTag)
            row.status:SetTextColor(1, 0.82, 0.2)
            upToDate = upToDate + 1
        else
            row.status:SetText(C.L.vcUpToDateTag)
            row.status:SetTextColor(0.3, 1, 0.3)
            upToDate = upToDate + 1
        end
        row:Show()
    end
    for i = #entries + 1, #rows do
        rows[i]:Hide()
    end
    listChild:SetHeight(math.max(20, #entries * 22))
    if countText then
        countText:SetText(string.format(C.L.vcCount, upToDate, #entries))
    end
end

local function BroadcastVersion()
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return
    end
    if IsInRaid() then
        C_ChatInfo.SendAddonMessage(VERSION_PREFIX, localVersion, "RAID")
    elseif IsInGroup() then
        C_ChatInfo.SendAddonMessage(VERSION_PREFIX, localVersion, "PARTY")
    end
    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(VERSION_PREFIX, localVersion, "GUILD")
    end
end

local function HandleReceived(sender, version)
    if not sender or not version or version == "" then
        return
    end
    local short = C.StripRealm(sender)
    if short == C.StripRealm(UnitName("player")) then
        return
    end
    known[short] = { version = version, ts = time() }

    if VersionGreater(version, localVersion) and not warnedThisSession then
        warnedThisSession = true
        print(string.format(C.L.vcOutdatedWarning, version, localVersion))
    end

    RefreshList()
end

local function BuildUI(panel)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
    title:SetText(C.L.vcLabel)
    title:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    local localLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    localLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    localLabel:SetText(string.format(C.L.vcYourVersion, localVersion))
    localLabel:SetTextColor(0.8, 0.8, 0.8)

    local refreshBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    refreshBtn:SetSize(110, 22)
    refreshBtn:SetPoint("TOPLEFT", localLabel, "BOTTOMLEFT", 0, -8)
    refreshBtn:SetText(C.L.vcRefreshButton)
    C.SkinButton(refreshBtn)
    refreshBtn:SetScript("OnClick", BroadcastVersion)

    countText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("LEFT", refreshBtn, "RIGHT", 10, 0)
    countText:SetTextColor(0.8, 0.8, 0.8)

    local headerRow = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    headerRow:SetPoint("TOPLEFT", refreshBtn, "BOTTOMLEFT", 6, -10)
    headerRow:SetText(C.L.vcListHeader)
    headerRow:SetTextColor(C.BRAND_R, C.BRAND_G, C.BRAND_B)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", -6, -6)
    scroll:SetPoint("RIGHT", panel, "RIGHT", -28, 0)
    scroll:SetPoint("BOTTOM", panel, "BOTTOM", 0, 10)
    C.SkinScrollBar(scroll)
    listChild = CreateFrame("Frame", nil, scroll)
    listChild:SetSize(300, 20)
    scroll:SetScrollChild(listChild)

    frame = panel
    RefreshList()
    BroadcastVersion()
end

local function RefreshUI()
    RefreshList()
    BroadcastVersion()
end

C.RegisterModule("VersionCheck", BuildUI, RefreshUI)

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(VERSION_PREFIX)
end

local e = CreateFrame("Frame")
e:RegisterEvent("PLAYER_ENTERING_WORLD")
e:RegisterEvent("GROUP_ROSTER_UPDATE")
e:RegisterEvent("CHAT_MSG_ADDON")
e:SetScript("OnEvent", function(_, event, a, b, c, d)
    if event == "CHAT_MSG_ADDON" then
        local prefix, msg, sender = a, b, d
        if prefix == VERSION_PREFIX then
            HandleReceived(sender, msg)
        end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        lastBroadcast = GetTime()
        BroadcastVersion()
        return
    end
    -- GROUP_ROSTER_UPDATE: rebroadcast so late joiners find out, but throttled.
    local now = GetTime()
    if now - lastBroadcast >= BROADCAST_COOLDOWN then
        lastBroadcast = now
        BroadcastVersion()
    end
end)
