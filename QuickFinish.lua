-- QuickFinish.lua v1.1
--
-- Purpose:
--   Makes the Quick Finish (instant kill) option available in all battles,
--   including against high-level enemies and invasive monsters.
--
-- Unmodded behavior:
--   Each turn, the game calls updateEnableInstantKill(bool) on BattleManager.
--   For regular low-level enemies it passes true, and the Quick Finish button
--   appears in the battle menu. For high-level or invasive enemies it passes
--   false, and the button is hidden.
--
-- What this mod does instead:
--   We hook updateEnableInstantKill and skip its original body (calling it
--   with true crashes the game for enemy types it doesn't expect). Instead,
--   in the post-hook we call BattleManager.setUniqueFlag() directly with the
--   IsEnableInstantKill flag set to true — the same underlying flag the game
--   uses to show the button, but set through the proper API.
--
-- The IsEnableInstantKill enum value is resolved from the BattleSysUniqueFlag
-- type at script load time, so no magic numbers are hardcoded here.

local CONFIG_PATH = "QuickFinish.json"
local enabled = true

local function save_config()
    if json then json.dump_file(CONFIG_PATH, { enabled = enabled }) end
end

local function load_config()
    if not json then return end
    local c = json.load_file(CONFIG_PATH)
    if c and type(c.enabled) == "boolean" then enabled = c.enabled end
end

load_config()

re.on_draw_ui(function()
    if imgui.tree_node("Quick Finish") then
        local changed, val = imgui.checkbox("Always enable Quick Finish", enabled)
        if changed then enabled = val; save_config() end
        imgui.tree_pop()
    end
end)

local td = sdk.find_type_definition("app.BattleManager")
if not td then
    log.error("[QuickFinish] app.BattleManager NOT FOUND"); return
end

-- Resolve the IsEnableInstantKill enum value from BattleSysUniqueFlag at load time.
local flag_IsEnableInstantKill = sdk.find_type_definition("app.BattleManager.BattleSysUniqueFlag")
    :get_field("IsEnableInstantKill"):get_data(nil)
log.info("[QuickFinish] IsEnableInstantKill flag value = " .. tostring(flag_IsEnableInstantKill))

local m_update = td:get_method("updateEnableInstantKill")
if not m_update then
    log.error("[QuickFinish] updateEnableInstantKill NOT FOUND"); return
end

sdk.hook(m_update, function(args)
    -- Skip original to prevent crash (reason unknown).
    if enabled then
        return sdk.PreHookResult.SKIP_ORIGINAL
    end
end, function(retval)
    if not enabled then return retval end
    local bm = sdk.get_managed_singleton("app.BattleManager")
    if bm then
        bm:call("setUniqueFlag", flag_IsEnableInstantKill, true)
    end
    return retval
end)

log.info("[QuickFinish] v1.1 loaded")
