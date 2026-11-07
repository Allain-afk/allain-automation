# Allain Automation — Keyless Scripts by Allain

Keyless automation scripts for Roblox. One loadstring works for every supported game: it detects which game you're in and loads the right script.

| Game | Version |
| --- | --- |
| Break and Steal an Egg | v3.2 |
| Steal a Balut | v0.2 (beta) |

## How to run

Paste this into your executor and run it while in a supported game:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Allain-afk/allain-automation-release/main/wasd"))()
```

Press **RightShift** to show or hide the menu (you can change this in the **Config** tab).

## Break and Steal an Egg

### Features

**Automation**
- **Zone Auto-Farm**: runs to eggs in the zone you pick and breaks them with the in-game Auto Swing. Filter by egg type, minimum luck and priority (closest, highest luck, lowest HP).
- **Auto-Take Hatched Pets**: runs to hatched pets and holds E to take them. Filter by pet, rarity and minimum Cash/s, or only take pets that earn more than the worst pet on your plot.
- **Guard avoidance**: skips eggs and pets near guards and backs off when a guard chases you.
- **Pickaxe guardrail**: switches back to your pickaxe (hotbar slot 1) if you're holding something else.
- **Auto-Progression**: equips your best pet, buys pickaxes and trails, and upgrades your plot and treadmill when you can afford them. It also turns on the in-game Auto Swing.

All movement uses your character's normal in-game speed. The script never changes WalkSpeed and never teleports.

**Visuals**
- Player, pet, egg and guard ESP, with rarity colors and Cash/s filters.

**AFK & Alerts**
- Anti-AFK (WASD mover) and auto-reconnect.
- Low Power mode.
- Discord webhook alerts for rare pets, progress reports and farm summaries.

### Default keybinds

| Key | Toggles |
| --- | --- |
| RightShift | Menu |
| H | Zone Auto-Farm |
| Q | Anti-AFK mover |
| T | Player ESP |
| P | Pet ESP |
| G | Egg ESP |
| L | Low Power mode |

Change any keybind in the menu. Your settings are saved automatically.

## Steal a Balut

### Features

**Automation**
- **Egg Auto-Farm**: runs to baluts and breaks them with the in-game Auto Swing (or by clicking with your Asarol). Filter by zone, rarity and max HP; pick the closest, lowest HP or highest rarity egg first.
- **Auto-Steal Pets**: runs to wild pets, holds E on them and walks them home to your base. Filter by rarity and minimum income; pets that would despawn before you get there are skipped.
- **Always Take Pets I Hatch**: takes the pet from every egg the farm breaks, even with only Egg Auto-Farm on.
- **Auto Equip Best** after each pet reaches your base.
- **Auto Equip Best Asarol**: equips your strongest owned Asarol before farming, since your Asarol's power sets your egg damage. The first time, it equips each Asarol once to measure it, then remembers the results.
- **Guard avoidance**: skips eggs and pets near guards and backs off when a guard is alerted or chasing.
- Gets off the Trisikad before walking.

All movement uses your character's normal in-game speed. The script never changes WalkSpeed and never teleports.

**Visuals**
- Egg ESP (rarity, HP, zone) and wild pet ESP (rarity, income, mutation, time left), with a rarity filter.

**Alerts & Scan**
- Rare wild pet alerts (in-game and Discord), and an optional Discord message for each stored pet.
- Game Data Scan: sends the game's structure and a live capture of your actions to a Discord webhook as a .txt file.

### Default keybinds

| Key | Toggles |
| --- | --- |
| RightShift | Menu |
| H | Egg Auto-Farm |
| J | Auto-Steal |
| G | Egg ESP |
| P | Wild Pet ESP |

## Executor requirements

- `loadstring` and `game:HttpGet` are required.
- Simulated input (`VirtualInputManager`) is used for Auto-Take (holding E) and the pickaxe guardrail.
- `request` / `http_request` is needed for Discord webhooks.
- `queue_on_teleport` is needed for auto-reconnect.

## Credits

Script by Allain (MIT license, see `LICENSE`). The UI is built on the Obsidian / Alexandria UI library by deividcomsono (MIT license, see `LICENSE-UI-LIBRARY`).
