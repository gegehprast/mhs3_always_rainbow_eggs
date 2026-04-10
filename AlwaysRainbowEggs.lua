-- AlwaysRainbowEggs.lua v1.2

local enabled          = true
-- Percentage chance (0–100) that a picked egg is forced to SUPERRARE.
-- At 100 every egg is rainbow; at 0 the hook does nothing even if enabled.
local superrare_chance = 100
-- app.EggDef.EGG_RARITY enum: NORMAL=0, RARE=1, SUPERRARE=2
local SUPERRARE        = 2
-- Byte offset of the Rarity field inside the EggInfo struct's managed object boxing.
-- Confirmed by calling sdk.find_type_definition("app.EggDef.EggInfo"):get_field("Rarity"):get_offset_from_base()
-- which returned 72, and cross-checking that read_dword(72) on the hooked return value
-- matched the actual rarity of eggs received in-game (0=Normal, 1=Rare, 2=SuperRare).
local RARITY_OFFSET    = 72
local CONFIG_PATH      = "AlwaysRainbowEggs.json"

local function save_config()
    if json then json.dump_file(CONFIG_PATH, { enabled = enabled, superrare_chance = superrare_chance }) end
end

local function load_config()
    if not json then return end
    local c = json.load_file(CONFIG_PATH)
    if c and type(c.enabled) == "boolean" then enabled = c.enabled end
    if c and type(c.superrare_chance) == "number" then
        superrare_chance = math.max(0, math.min(100, math.floor(c.superrare_chance)))
    end
end

load_config()

-- Look up the data controller type that owns the egg table logic.
-- app.NestDungeonControllerData holds the nest's egg pool and probability methods.
local td_ctrl = sdk.find_type_definition("app.NestDungeonControllerData")
if td_ctrl then
    -- retrieveEggFromTable(System.Int32) is called once per egg pick attempt.
    -- It rolls the egg pool and returns a fully-decided app.EggDef.EggInfo struct.
    local m = td_ctrl:get_method("retrieveEggFromTable")
    if m then
        -- Post-hook: runs after the game has already filled in the EggInfo return value.
        -- `retval` is a pointer to the sret (struct return) buffer on the caller's stack.
        sdk.hook(m, nil, function(retval)
            if not enabled then return retval end
            -- Roll against the configured chance before modifying.
            if superrare_chance < 100 and math.random(1, 100) > superrare_chance then return retval end

            -- REFramework boxes the raw sret pointer into a managed object we can inspect.
            -- This gives us a stable, typed handle to the EggInfo data.
            local ok, mo = pcall(function() return sdk.to_managed_object(retval) end)
            if ok and mo then
                -- write_dword writes 4 bytes directly into process memory at (mo's address + 72 bytes).
                -- Because this is the live buffer the caller is about to read,
                -- the game sees SUPERRARE when it consumes the return value.
                pcall(function() mo:write_dword(RARITY_OFFSET, SUPERRARE) end)
            end

            -- REFramework requires the post-hook to return a retval pointer.
            -- We return the same one we received because we already modified the memory it points to —
            -- we don't need to substitute a different pointer.
            return retval
        end)
        log.info("[AlwaysRainbowEggs] hook installed")
    else
        log.error("[AlwaysRainbowEggs] retrieveEggFromTable not found")
    end
else
    log.error("[AlwaysRainbowEggs] NestDungeonControllerData not found")
end

re.on_draw_ui(function()
    if imgui.tree_node("Always Rainbow Eggs") then
        local changed, new_val = imgui.checkbox("Enable", enabled)
        if changed then
            enabled = new_val
            save_config()
        end
        local chance_changed, new_chance = imgui.slider_int("Rainbow Chance (%)", superrare_chance, 0, 100)
        if chance_changed then
            superrare_chance = new_chance
            save_config()
        end
        imgui.tree_pop()
    end
end)
