## Mods

- [Always Rainbow Egg](#always-rainbow-egg)
- [Auto Store Picked Up Eggs](#auto-store-picked-up-eggs)
- [Quick Finish](#quick-finish)

---

## Always Rainbow Egg

Every egg you pick from a monster den will be a **rainbow (highly potent)** egg, regardless of the nest's rarity. You can configure the interception rate.

Inspired by [this plugin mod](https://www.nexusmods.com/monsterhunterstories3twistedreflection/mods/47) — but as an open-source REFramework Lua script so you can read and verify exactly what it does.

> **Disclaimer:** This mod was developed with LLM assistance, primarily for navigating the REFramework API and the probing process. ~It has not been thoroughly tested — only verified on mid game free-roaming monster dens across different regions. Behavior during story progression has not been tested.~

### How It Works

The game calls `app.NestDungeonControllerData.retrieveEggFromTable()` each time you pick an egg from a nest. It rolls the egg pool and writes the result — including rarity — into a return struct. This mod hooks that function's return and overwrites the `Rarity` field to `SUPERRARE (2)` before the game reads it.

No save data is modified. The change only affects eggs as they are picked.

### Installation

1. Install [REFramework](https://www.nexusmods.com/monsterhunterstories3twistedreflection/mods/12)
2. Copy `AlwaysRainbowEggs.lua` into:
   ```
   <game folder>/reframework/autorun/
   ```
3. Launch the game. The mod is active immediately.

### Usage

Open the REFramework menu (default: `Insert` key) and find **Always Rainbow Eggs**.

- **Enable** — toggles the mod on or off.
- **Rainbow Chance (%)** — slider from 0 to 100 controlling how often a picked egg is forced to rainbow.

All settings are saved automatically to `AlwaysRainbowEggs.json`.

### Requirements

- [REFramework](https://www.nexusmods.com/monsterhunterstories3twistedreflection/mods/12)

---

## Auto Store Picked Up Eggs

Every egg you pick from a nest is immediately stored into your Egg Box — no need to walk to the safe zone. The nest stays interactable, so you can keep picking eggs from the same nest as long as there is space in your box.

When the Egg Box is almost full (last auto-storable slot filled), a heads-up overlay is shown on screen. You can still keep picking; eggs just won't be auto-stored past that point.

> **Disclaimer:** This mod was developed with LLM assistance. ~It has not been thoroughly tested — only verified on mid game free-roaming monster dens. Behavior during story progression has not been tested.~

### How It Works

The game normally requires the player to walk to the safe zone to commit a picked egg via `completeGetEgg()`, which locks the nest(s). This mod hooks `sendEggObjToPL()` — called the moment the egg is handed to the player — and directly writes the egg's data into the first empty slot in the Egg Box.

> **Warning:** This mod writes directly into your save data's Egg Box in memory. The data written is identical to what the game would store normally — but it is written earlier than intended. Keep backups of your save.

### Installation

1. Install [REFramework](https://www.nexusmods.com/monsterhunterstories3twistedreflection/mods/12)
2. Copy `AutoStorePickedUpEggs.lua` into:
   ```
   <game folder>/reframework/autorun/
   ```
3. Launch the game. The mod is active immediately.

### Usage

Open the REFramework menu (default: `Insert` key) and find **Auto Store Picked Up Eggs**.

- **Enable** — toggles the mod on or off.

Config file: `<game folder>/reframework/data/AutoStorePickedUpEggs.json`

### Requirements

- [REFramework](https://www.nexusmods.com/monsterhunterstories3twistedreflection/mods/12)

---

## Quick Finish

Makes the Quick Finish (instant kill) option available in all battles, including against high-level enemies and invasive monsters — enemy types where it is normally disabled.

> **Disclaimer:** This mod was developed with LLM assistance. I have not yet tested it on Elder Dragon or Final Boss.

### How It Works

Each turn, the game calls `BattleManager.updateEnableInstantKill(bool)` to decide whether to show the Quick Finish button. For low-level enemies it passes `true`; for high-level or invasive enemies it passes `false`. This mod hooks that call, skips the original body, and instead calls `BattleManager.setUniqueFlag(IsEnableInstantKill, true)` directly — the same underlying flag the game uses, set through the proper API.

### Installation

1. Install [REFramework](https://www.nexusmods.com/monsterhunterstories3twistedreflection/mods/12)
2. Copy `QuickFinish.lua` into:
   ```
   <game folder>/reframework/autorun/
   ```
3. Launch the game. The mod is active immediately.

### Usage

Open the REFramework menu (default: `Insert` key) and find **Quick Finish**.

- **Enable** — toggles the mod on or off.

Config file: `<game folder>/reframework/data/QuickFinish.json`

### Requirements

- [REFramework](https://www.nexusmods.com/monsterhunterstories3twistedreflection/mods/12)
