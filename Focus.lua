-- CC RaidTools - Focus
--
-- Provides a configurable modifier + mouse-button focus action while preserving
-- the secure behavior of Blizzard and third-party unit frames.

local C = CCRT

local focusDB
local modifier
local mouseButton
local previousModifier
local previousMouseButton
local enabled = false

local function GetBindingKey()
    if not modifier or not mouseButton then
        return nil
    end

    return string.upper(modifier) .. "-BUTTON" .. mouseButton
end

-- This secure button performs the actual /focus action. The override binding
-- points to it instead of calling the protected action directly from Lua.
local focusButton = CreateFrame("CheckButton", "CCRTFocusButton", UIParent, "SecureUnitButtonTemplate")
focusButton:SetAttribute("type1", "macro")
focusButton:SetAttribute("macrotext", "/focus mouseover")

-- Only these known secure unit frames receive an explicit click binding. This
-- keeps Focus compatible with Blizzard and EllesmereUI target/boss frames
-- without scanning or modifying arbitrary addon frames.
local unitFrameBindings = setmetatable({}, { __mode = "k" })

local function GetUnitFocusAttributeName()
    if not modifier or not mouseButton then
        return nil
    end

    return string.lower(modifier) .. "-type" .. tostring(mouseButton)
end

local function AddKnownFrame(frames, seen, frame)
    if frame and not seen[frame] then
        seen[frame] = true
        frames[#frames + 1] = frame
    end
end

local function GetKnownUnitFrames()
    local frames, seen = {}, {}
    AddKnownFrame(frames, seen, _G.TargetFrame)
    for index = 1, 5 do
        AddKnownFrame(frames, seen, _G["Boss" .. index .. "TargetFrame"])
    end

    -- EllesmereUI creates these named secure buttons during its UI setup.
    -- Read them directly instead of relying on its optional configuration API,
    -- which is not populated until its options panel has been initialized.
    AddKnownFrame(frames, seen, _G.EllesmereUIUnitFrames_Player)
    AddKnownFrame(frames, seen, _G.EllesmereUIUnitFrames_Target)
    for index = 1, 5 do
        AddKnownFrame(frames, seen, _G["EllesmereUIUnitFrames_Boss" .. index])
    end

    local eui = _G.EllesmereUI
    local moduleNS = eui and eui._ModuleNS and eui._ModuleNS["EllesmereUIUnitFrames"]
    local euiFrames = moduleNS and moduleNS.frames
    if euiFrames then
        AddKnownFrame(frames, seen, euiFrames.target)
        for index = 1, 5 do
            AddKnownFrame(frames, seen, euiFrames["boss" .. index])
        end
    end

    return frames
end

local function RestoreUnitFrameBindings()
    if InCombatLockdown() then
        return
    end

    for frame, info in pairs(unitFrameBindings) do
        if frame and info and info.attribute and frame:GetAttribute(info.attribute) == "focus" then
            frame:SetAttribute(info.attribute, info.original)
        end
        unitFrameBindings[frame] = nil
    end
end

local function ApplyUnitFrameBindings()
    if InCombatLockdown() or not enabled then
        return
    end

    local attribute = GetUnitFocusAttributeName()
    if not attribute then
        return
    end

    for _, frame in ipairs(GetKnownUnitFrames()) do
        local original = frame:GetAttribute(attribute)
        frame:SetAttribute(attribute, "focus")
        unitFrameBindings[frame] = { attribute = attribute, original = original }
    end
end

local function ApplyFocusOverrideBinding()
    if InCombatLockdown() then
        return
    end

    if not enabled then
        ClearOverrideBindings(focusButton)
        previousModifier = nil
        previousMouseButton = nil
        return
    end

    if not modifier or not mouseButton then
        return
    end

    local newKey = GetBindingKey()
    local oldKey = previousModifier and previousMouseButton
        and (string.upper(previousModifier) .. "-BUTTON" .. previousMouseButton)

    if oldKey and oldKey ~= newKey then
        SetOverrideBinding(focusButton, true, oldKey, nil)
    end

    SetOverrideBindingClick(focusButton, true, newKey, "CCRTFocusButton")
    previousModifier = modifier
    previousMouseButton = mouseButton
end

local function ApplyFocusBinding()
    if InCombatLockdown() then
        return
    end

    RestoreUnitFrameBindings()
    ApplyFocusOverrideBinding()
    ApplyUnitFrameBindings()
end

local function SaveFocusSettings()
    if not focusDB then
        return
    end

    focusDB.enabled = enabled
    focusDB.modifier = modifier
    focusDB.mouseButton = mouseButton

    -- These legacy keys are retained for compatibility with older module code.
    AutoPromoteDB.focusModifier = modifier
    AutoPromoteDB.focusMouseButton = mouseButton
end

local modifierValues = {
    { "Shift", "shift" },
    { "Alt", "alt" },
    { "Ctrl", "ctrl" },
}

local mouseValues = {
    { C.L.mouseLeft, "1" },
    { C.L.mouseRight, "2" },
    { C.L.mouseMiddle, "3" },
    { C.L.mouse4, "4" },
    { C.L.mouse5, "5" },
}

local layout

local function BuildUI(frame)
    local UI = C.UI
    UI.Band(frame, "Focus", C.L.focusIntro)

    layout = UI.NewLayout(frame)
    layout:Header(C.L.uiSectionOptions)
    layout:Toggle({
        label = C.L.focusEnable,
        desc = C.L.focusEnableDesc,
        get = function() return enabled end,
        set = function(value)
            enabled = value
            SaveFocusSettings()
            ApplyFocusBinding()
        end,
    })
    layout:Choice({
        label = C.L.focusKey,
        desc = C.L.focusKeyDesc,
        values = modifierValues,
        get = function() return modifier end,
        set = function(value)
            modifier = value
            SaveFocusSettings()
            ApplyFocusBinding()
        end,
    })
    layout:Choice({
        label = C.L.focusMouseClick,
        desc = C.L.focusMouseDesc,
        values = mouseValues,
        get = function() return mouseButton end,
        set = function(value)
            mouseButton = value
            SaveFocusSettings()
            ApplyFocusBinding()
        end,
    })
    layout:Finish()
end

local function RefreshUI()
    if layout and focusDB then
        layout:Refresh()
    end
end

C.RegisterModule("Focus", BuildUI, RefreshUI)

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "CC_RaidTools" then
        C.InitDB()
        focusDB = AutoPromoteDB.focus
        enabled = focusDB.enabled
        if enabled == nil then
            enabled = false
        end

        modifier = focusDB.modifier or "shift"
        mouseButton = focusDB.mouseButton or "1"
        focusDB.enabled = enabled
        focusDB.modifier = modifier
        focusDB.mouseButton = mouseButton
        AutoPromoteDB.focusModifier = modifier
        AutoPromoteDB.focusMouseButton = mouseButton

        ApplyFocusBinding()
        RefreshUI()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        ApplyFocusOverrideBinding()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        ApplyFocusBinding()
    end
end)
