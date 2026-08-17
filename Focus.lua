-- CC RaidTools - Focus
local modifier = "shift"
local mouseButton = "1"

local function SetFocusHotkey(frame)
    if not frame or InCombatLockdown() then return end
    frame:SetAttribute(modifier .. "-type" .. mouseButton, "focus")
end

local function CreateFrame_Hook(type, name, parent, template)
    if template == "SecureUnitButtonTemplate" and name then
        SetFocusHotkey(_G[name])
    end
end

hooksecurefunc("CreateFrame", CreateFrame_Hook)

local focusButton = CreateFrame("CheckButton", "CCRTFocusButton", UIParent, "SecureUnitButtonTemplate")
focusButton:SetAttribute("type1", "macro")
focusButton:SetAttribute("macrotext", "/focus mouseover")

if not InCombatLockdown() then
    SetOverrideBindingClick(focusButton, true, "SHIFT-BUTTON1", "CCRTFocusButton")
end

local defaultUnitFrames = {
    PlayerFrame,
    PetFrame,
    PartyMemberFrame1,
    PartyMemberFrame2,
    PartyMemberFrame3,
    PartyMemberFrame4,
    PartyMemberFrame1PetFrame,
    PartyMemberFrame2PetFrame,
    PartyMemberFrame3PetFrame,
    PartyMemberFrame4PetFrame,
    TargetFrame,
    TargetofTargetFrame,
}

local function ApplyDefaultUnitFrameBindings()
    if InCombatLockdown() then return end
    for _, frame in ipairs(defaultUnitFrames) do
        SetFocusHotkey(frame)
    end
end

ApplyDefaultUnitFrameBindings()

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    ApplyDefaultUnitFrameBindings()
    if not InCombatLockdown() then
        SetOverrideBindingClick(focusButton, true, "SHIFT-BUTTON1", "CCRTFocusButton")
    end
end)
