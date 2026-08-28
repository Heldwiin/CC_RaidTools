-- CC RaidTools - SavedVariables migration
-- CCRaidToolsDB is the canonical database name. AutoPromoteDB is retained
-- for one release as a compatibility source for existing installations.
local function MigrateSavedVariables()
    if CCRaidToolsDB == nil and AutoPromoteDB ~= nil then
        CCRaidToolsDB = AutoPromoteDB
    end
    if CCRaidToolsDB == nil then
        CCRaidToolsDB = {}
    end

    -- Existing modules still reference AutoPromoteDB. Keep it as a runtime
    -- alias so this migration does not require a risky all-module rewrite.
    AutoPromoteDB = CCRaidToolsDB
end

MigrateSavedVariables()
