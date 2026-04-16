-- AutoStorePickedUpEggs.lua v1.1
--
-- Purpose:
--   When the player interacts with a nest and picks up an egg, this mod
--   immediately stores that egg directly into their Egg Box in inventory.
--   This means the player never needs to walk to the safe zone to "commit"
--   the egg — the nest remains interactable and the player can keep picking.
--
-- How egg picking works in the game (unmodded):
--   1. Player interacts with a nest → game calls retrieveEggFromTable()
--      which rolls the RNG and returns the egg's data (EggInfo).
--   2. Game calls sendEggObjToPL() to hand the egg object to the player.
--      The player is now physically "carrying" the egg.
--   3. Player walks into the safe zone → game calls completeGetEgg()
--      which writes the egg into the Egg Box and locks the nest.
--
-- What this mod does instead:
--   At step 2 (sendEggObjToPL), we intercept the EggInfo captured at step 1
--   and directly write all its fields into the first empty slot in the Egg Box.
--   The player is still left carrying the egg (game state unchanged), but the
--   slot in the Egg Box is now filled — so when they eventually leave, the game
--   commits to the last reserved slot, and the box shows the correct count.
--
-- Egg Box layout (app.cEggWork managed array):
--   - get_Length() reports 12, but the backing array silently has 14 entries
--     (indices 0 to 13), matching the game's "N/12" UI counter.
--   - Indices 0 and 1 are always null pointers — the game never uses them?
--   - Indices 2–13 are the 12 real egg slots.
--   - An empty slot has its OtID field set to SENTINEL_OTID (a magic value).
--     Writing a real OtID into that field "activates" the slot.
--
-- Capacity management:
--   A den has at most 2 nests, so the player can carry up to MAX_CARRY=2 eggs
--   at once. We reserve that many slots at the top of the array for the game's
--   own commit path (completeGetEgg). We only auto-fill up to index 11, leaving
--   indices 12 and 13 for the game. When we fill index 11 (the last safe slot),
--   we show a warning and let the game handle the rest normally.
--
-- ── Constants ─────────────────────────────────────────────────────────────────

-- Magic value stored in the OtID field of an empty cEggWork slot.
-- When this value is present, we know the slot is available to write into.
local SENTINEL_OTID = 2615765376

-- Maximum number of eggs the player can carry simultaneously.
-- One per nest, and a den has at most 2 nests. We reserve this many slots
-- at the high end of the Egg Box array for the game's own commit path.
local MAX_CARRY = 2

-- ── Config ───────────────────────────────────────────────────────────────────

local CONFIG_PATH = "AutoStorePickedUpEggs.json"
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

-- ── UI state ──────────────────────────────────────────────────────────────────

-- When we fill the last auto-add slot, show a heads-up to the player.
local notify_almost_timer = 0
local NOTIFY_DURATION = 15 * 60 -- assuming 60 FPS

re.on_frame(function()
    if notify_almost_timer > 0 then
        notify_almost_timer = notify_almost_timer - 1
        -- Draw a small overlay in the top-left corner of the screen.
        -- Window flags: NoTitleBar | NoResize | NoMove | NoScrollbar | NoCollapse | NoNav
        imgui.set_next_window_pos(Vector2f.new(60, 120), 1)
        imgui.set_next_window_size(Vector2f.new(600, 70), 1)
        if imgui.begin_window("##aspue_almost", true, 1071) then
            imgui.text("Egg Box is almost full.")
            imgui.text("Picking up more eggs will not auto-store them.")
            imgui.end_window()
        end
    end
end)

re.on_draw_ui(function()
    if imgui.tree_node("Auto Store Picked Up Eggs") then
        local changed, val = imgui.checkbox("Enable", enabled)
        if changed then enabled = val; save_config() end
        imgui.tree_pop()
    end
end)

-- ── Egg Box access ────────────────────────────────────────────────────────────

-- Navigate the save data object hierarchy to reach the Egg Box array.
-- The path is: SaveDataManager → UserSaveData → EggParam → EggBox (cEggWork[]).
local function get_egg_box()
    local ok_s, sdm = pcall(function() return sdk.get_managed_singleton("app.SaveDataManager") end)
    if not (ok_s and sdm) then return nil end
    local ok_u, usd = pcall(function() return sdm:call("get_UserSaveData") end)
    if not (ok_u and usd) then return nil end
    local ok_e, ep = pcall(function() return usd:call("get_EggParam") end)
    if not (ok_e and ep) then return nil end
    local ok_b, box = pcall(function() return ep:call("get_EggBox") end)
    return (ok_b and box) and box or nil
end

-- Read a single cEggWork element from the array by index.
-- The array stores object references as 8-byte pointers starting at byte offset 16,
-- one pointer per entry (16 + i*8). Returns nil if the slot is null or unavailable.
local function get_slot(box, i)
    local ok_ptr, ptr = pcall(function() return box:read_qword(16 + i * 8) end)
    if not (ok_ptr and ptr and ptr ~= 0) then return nil end
    local ok_mo, mo = pcall(function() return sdk.to_managed_object(ptr) end)
    return (ok_mo and mo) and mo or nil
end

-- Scan the Egg Box for the first empty (sentinel) slot available for auto-fill.
-- We scan indices 0..len+1-MAX_CARRY to leave the top MAX_CARRY entries free
-- for the game's own commit path when the player reaches the safe zone.
local function find_sentinel_idx(box)
    local ok_len, len = pcall(function() return box:call("get_Length") end)
    if not ok_len then return -1 end
    -- len = 12 (reported), but backing array is 0..13 (14 entries).
    -- We auto-fill at most up to index: len+1 - MAX_CARRY = 11.
    for i = 0, len + 1 - MAX_CARRY do
        local mo = get_slot(box, i)
        if mo then
            local ok_id, id = pcall(function() return mo:read_dword(44) end)
            if ok_id and id == SENTINEL_OTID then return i end
        end
    end
    return -1 -- no free slot in the auto-fill range
end

-- Debug helper: log the OtID of every slot in the Egg Box.
-- Useful for diagnosing unexpected full/overflow states.
local function log_box_state(box)
    local ok_len, len = pcall(function() return box:call("get_Length") end)
    if not ok_len then
        log.info("[AutoStorePickedUpEggs] cannot read box length"); return
    end
    local parts = {}
    for i = 0, len + 1 do -- log all 14 entries (0..13)
        local mo = get_slot(box, i)
        if mo then
            local ok_id, id = pcall(function() return mo:read_dword(44) end)
            local label = ok_id and tostring(id) or "ERR"
            if ok_id and id == SENTINEL_OTID then label = "EMPTY" end
            parts[#parts + 1] = "[" .. i .. "]=" .. label
        else
            parts[#parts + 1] = "[" .. i .. "]=null"
        end
    end
    log.info("[AutoStorePickedUpEggs] box len=" .. len .. ": " .. table.concat(parts, "  "))
end

-- ── Core write logic ──────────────────────────────────────────────────────────

-- Copy all relevant fields from an EggInfo struct into a sentinel cEggWork slot,
-- effectively storing the egg into the Egg Box without going through the safe zone.
--
-- Field mapping (EggInfo byte offset → cEggWork byte offset):
--   The two structs share the same fields but store them in a slightly different
--   order. All values are confirmed by comparing raw memory dumps of both objects
--   from the same egg pick across multiple runs.
--
--   EggInfo[36] → cEggWork[32]  AreaID_Fixed
--   EggInfo[32] → cEggWork[36]  RegionID_Fixed       (note: these two are swapped)
--   EggInfo[40] → cEggWork[40]  NestRarity_Fixed
--   EggInfo[44] → cEggWork[44]  OtID_Fixed           (written LAST to activate slot)
--   EggInfo[52] → cEggWork[48]  DualElemType_Fixed
--   EggInfo[56] → cEggWork[52]  EcoRank_Fixed
--   constant    → cEggWork[56]  GeneLotteryMainStoryFlag  (same value on every egg)
--   (skip)      → cEggWork[60]  GeneSeed             (unmatched; leave as 0)
--   EggInfo[72] → cEggWork[66]  Rarity               (packed as hi-int16 at offset 64)
--   constant 2  → cEggWork[64]  FieldBonusRank       (packed as lo-int16 at offset 64)
--
-- Returns true if the egg was written and should NOT be committed normally.
-- Returns false if the box was full or this was the last auto-fill slot —
--   in both cases the game's normal completeGetEgg path should still run.
local function write_egg_to_box(ei)
    local box = get_egg_box()
    if not box then
        log.info("[AutoStorePickedUpEggs] cannot access EggBox")
        return false
    end

    local ok_len, len = pcall(function() return box:call("get_Length") end)
    if not ok_len then len = 12 end
    -- The very last index we will auto-fill. Higher indices are reserved for the
    -- game to commit the eggs the player is currently carrying (via completeGetEgg).
    local last_auto_idx = len + 1 - MAX_CARRY -- = 11 with len=12, MAX_CARRY=2

    local idx = find_sentinel_idx(box)
    if idx < 0 then
        -- All auto-fill slots are taken; the game must handle the rest itself.
        log_box_state(box)
        log.info("[AutoStorePickedUpEggs] EggBox auto-fill range is full")
        return false
    end

    local slot = get_slot(box, idx)
    if not slot then return false end

    local ok, err = pcall(function()
        -- Write every field except OtID first.
        slot:write_dword(32, ei:read_dword(36)) -- AreaID_Fixed
        slot:write_dword(36, ei:read_dword(32)) -- RegionID_Fixed
        slot:write_dword(40, ei:read_dword(40)) -- NestRarity_Fixed
        slot:write_dword(48, ei:read_dword(52)) -- DualElemType_Fixed
        slot:write_dword(52, ei:read_dword(56)) -- EcoRank_Fixed
        slot:write_dword(56, 3536347904)        -- GeneLotteryMainStoryFlag (constant)
        -- GeneSeed (offset 60): left as 0. It affects which gene layout is displayed
        -- but does not determine the egg's identity or rarity.
        local rarity = ei:read_dword(72) -- Rarity (0=Normal, 1=Rare, 2=SuperRare)
        -- FieldBonusRank and Rarity are packed into a single dword at offset 64:
        --   bits 0–15  = FieldBonusRank (observed constant: 2)
        --   bits 16–31 = Rarity
        slot:write_dword(64, 2 + rarity * 65536)
        -- Write OtID last. This is what the game checks to determine whether a slot
        -- is occupied. Writing a real OtID here "activates" the slot — before this
        -- write the slot still looks empty to the game.
        slot:write_dword(44, ei:read_dword(44)) -- OtID_Fixed
    end)

    if not ok then
        log.info("[AutoStorePickedUpEggs] write error: " .. tostring(err))
        return false
    end

    log.info("[AutoStorePickedUpEggs] stored egg OtID=" .. ei:read_dword(44)
        .. "  Rarity=" .. ei:read_dword(72)
        .. "  -> slot[" .. idx .. "]")

    -- The last auto-fill slot was just used. Any further eggs the player picks
    -- will not be auto-stored (no free slots left in our range). Warn them now.
    -- They can still keep picking — we just let them know.
    -- When the player eventually leaves the nest, the game will commit to the next
    -- available slot (idx=12 or 13) via the normal completeGetEgg path.
    if idx == last_auto_idx then
        notify_almost_timer = NOTIFY_DURATION
        return false
    end

    return true
end

-- ── Game type lookups ─────────────────────────────────────────────────────────

-- NestDungeonControllerData manages the egg table and probability logic for a nest.
local td_ndcd = sdk.find_type_definition("app.NestDungeonControllerData")
-- NestDungeonController is the per-nest controller that drives the pick-up flow.
local td_nc   = sdk.find_type_definition("app.NestDungeonController")

if not td_ndcd then
    log.error("[AutoStorePickedUpEggs] NestDungeonControllerData NOT FOUND"); return
end
if not td_nc then
    log.error("[AutoStorePickedUpEggs] NestDungeonController NOT FOUND"); return
end

-- ── Mod state ─────────────────────────────────────────────────────────────────

-- The EggInfo captured from the most recent retrieveEggFromTable call.
-- Held here briefly until sendEggObjToPL fires, at which point we consume it.
local last_egg_info = nil

re.on_script_reset(function()
    last_egg_info = nil
end)

-- ── Hooks ─────────────────────────────────────────────────────────────────────

-- Hook 1: retrieveEggFromTable (post-hook)
--   Called when the player interacts with a nest to receive an egg.
--   The return value IS the EggInfo struct (as a managed object pointer).
--   We save it so the sendEggObjToPL hook can use it a moment later.
local m_retrieve = td_ndcd:get_method("retrieveEggFromTable")
if m_retrieve then
    sdk.hook(m_retrieve, nil, function(retval)
        local ok, mo = pcall(function() return sdk.to_managed_object(retval) end)
        if ok and mo then last_egg_info = mo end
        return retval
    end)
    log.info("[AutoStorePickedUpEggs] hooked retrieveEggFromTable")
end

-- Hook 2: sendEggObjToPL (post-hook)
--   Called immediately after the player picks up the egg from the nest.
--   We write the egg directly into the Egg Box here.
local m_send = td_nc:get_method("sendEggObjToPL")
if m_send then
    sdk.hook(m_send, nil, function(retval)
        if not enabled then return retval end
        if last_egg_info then
            write_egg_to_box(last_egg_info)
            last_egg_info = nil
        end
        return retval
    end)
    log.info("[AutoStorePickedUpEggs] hooked sendEggObjToPL")
end

log.info("[AutoStorePickedUpEggs] v1.1 loaded")
