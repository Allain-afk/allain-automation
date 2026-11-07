# Break and Steal an Egg — Keyless Script by Allain

Keyless automation script for **Break and Steal an Egg** on Roblox. Current version: **v3.2**.

## How to run

Paste this into your executor and run it while in the game:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Allain-afk/allain-automation-release/main/wasd"))()
```

Press **RightShift** to show or hide the menu (you can change this in the **Config** tab).

## Features

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

## Default keybinds

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

## Executor requirements

- `loadstring` and `game:HttpGet` are required.
- Simulated input (`VirtualInputManager`) is used for Auto-Take (holding E) and the pickaxe guardrail.
- `request` / `http_request` is needed for Discord webhooks.
- `queue_on_teleport` is needed for auto-reconnect.

## Credits

Script by Allain (MIT license, see `LICENSE`). The UI is built on the Obsidian / Alexandria UI library by deividcomsono (MIT license, see `LICENSE-UI-LIBRARY`).
