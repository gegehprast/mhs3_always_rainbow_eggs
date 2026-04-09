## Always Rainbow Egg

Every egg you pick from a monster den will be a **rainbow (highly potent)** egg, regardless of the nest's rarity. You can configure the interception rate.

Inspired by [this plugin mod](https://www.nexusmods.com/monsterhunterstories3twistedreflection/mods/47) — but as an open-source REFramework Lua script so you can read and verify exactly what it does.

> **Disclaimer:** This mod was developed with LLM assistance, primarily for navigating the REFramework API and the probing process. It has not been thoroughly tested — only verified on mid game free-roaming monster dens across different regions. Behavior during story progression has not been tested.

## How It Works

The game calls `app.NestDungeonControllerData.retrieveEggFromTable()` each time you pick an egg from a nest. It rolls the egg pool and writes the result — including rarity — into a return struct. This mod hooks that function's return and overwrites the `Rarity` field to `SUPERRARE (2)` before the game reads it.

No save data is modified. The change only affects eggs as they are picked.

## Installation

1. Install [REFramework](https://www.nexusmods.com/monsterhunterstories3twistedreflection/mods/12)
2. Copy `AlwaysRainbowEggs.lua` into:
   ```
   <game folder>/reframework/autorun/
   ```
3. Launch the game. The mod is active immediately.

## Usage

Open the REFramework menu (default: `Insert` key) and find **Always Rainbow Eggs**.

- **Enable** — toggles the mod on or off.
- **Rainbow Chance (%)** — slider from 0 to 100 controlling how often a picked egg is forced to rainbow.

All settings are saved automatically to `AlwaysRainbowEggs.json`.

## Requirements

- [REFramework](https://www.nexusmods.com/monsterhunterstories3twistedreflection/mods/12)

