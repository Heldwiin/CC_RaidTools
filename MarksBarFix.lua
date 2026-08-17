-- CC RaidTools - Marks Bar visual fixes
-- Loaded after MarksBar.lua so the existing secure buttons are preserved.
local bar = _G.CCRaidToolsMarksBar
if not bar then return end

local MARK_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local MARK_COORDS = {
    [1] = {0, .25, 0, .25},
    [2] = {.25, .5, 0, .25},
    [3] = {.5, .75, 0, .25},
    [4] = {.75, 1, 0, .25},
    [5] = {0, .25, .25, .5},
    [6] = {.25, .5, .25, .5},
    [7] = {.5, .75, .25, .5},
    [8] = {.75, 1, .25, .5},
}

local function ApplyMarksBarFix()
    if not bar then return end

    local children = {bar:GetChildren()}
    if #children < 16 then return end

    -- Blizzard's official raid-marker atlas order:
    -- 1 Star, 2 Circle, 3 Diamond, 4 Triangle,
    -- 5 Moon, 6 Square, 7 Cross, 8 Skull.
    for i = 1, 8 do
        local button = children[i]
        if button and button.icon then
            local c = MARK_COORDS[i]
            button.icon:SetTexture(MARK_TEXTURE)
            button.icon:SetTexCoord(c[1], c[2], c[3], c[4])
            button.icon:SetVertexColor(1, 1, 1, 1)
        end
    end

    local gap = 2
    local raidSize = 30
    local worldSize = 23
    local raidWidth = 8 * raidSize + 7 * gap + 4
    local worldWidth = 8 * worldSize + 7 * gap + 4
    local raidHeight = raidSize + 4
    local worldHeight = worldSize + 4
    local horizontal = bar:GetWidth() >= bar:GetHeight()

    -- Remove the single large background so it cannot protrude around
    -- the smaller second row. We replace it with two row-sized backgrounds.
    bar:SetBackdropColor(0, 0, 0, 0)
    bar:SetBackdropBorderColor(0, 0, 0, 0)

    if not bar._ccrtRaidRowBG then
        bar._ccrtRaidRowBG = bar:CreateTexture(nil, "BACKGROUND")
        bar._ccrtWorldRowBG = bar:CreateTexture(nil, "BACKGROUND")
    end

    local function StyleRowBG(texture, width, height, x, y)
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        texture:SetVertexColor(0.015, 0.015, 0.02, 0.90)
        texture:SetSize(width, height)
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", bar, "TOPLEFT", x, y)
    end

    if horizontal then
        StyleRowBG(bar._ccrtRaidRowBG, raidWidth, raidHeight, 0, 0)
        StyleRowBG(bar._ccrtWorldRowBG, worldWidth, worldHeight, (raidWidth - worldWidth) / 2, -raidHeight)

        for i = 1, 8 do
            local button = children[i]
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", bar, "TOPLEFT", 2 + (i - 1) * (raidSize + gap), -2)
        end

        for i = 1, 8 do
            local button = children[8 + i]
            button:ClearAllPoints()
            button:SetSize(worldSize, worldSize)
            button:SetPoint("TOPLEFT", bar, "TOPLEFT", 2 + (raidWidth - worldWidth) / 2 + (i - 1) * (worldSize + gap), -raidHeight - 2)
            if button.icon then
                button.icon:ClearAllPoints()
                button.icon:SetPoint("TOPLEFT", 3, -3)
                button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
            end
        end
    else
        StyleRowBG(bar._ccrtRaidRowBG, raidHeight, raidWidth, 0, 0)
        StyleRowBG(bar._ccrtWorldRowBG, worldHeight, worldWidth, raidHeight, -(raidWidth - worldWidth) / 2)
    end
end

ApplyMarksBarFix()
bar:HookScript("OnSizeChanged", ApplyMarksBarFix)
