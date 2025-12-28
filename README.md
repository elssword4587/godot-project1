# Idle God RPG (Godot 4.5)

UI-first idle RPG prototype for landscape Android export. Autoload singletons drive data-driven traits/items/locations. Avatar follows orders or acts autonomously while traveling around a procedural placeholder map.

## Requirements
- Godot 4.5.x
- Target viewport 1280x720 (stretch aspect expand). Landscape orientation only.

## Running
1. Open the project in Godot 4.5.
2. Ensure **Main.tscn** is the startup scene (already configured in `project.godot`).
3. Play in editor: autopilot will handle needs, travel, shopping, crafting, and logging.

## Data-driven content
- `res://data/traits.json` : 20+ traits with mods and behavioral biases.
- `res://data/items.json` : 80 items spanning weapon/armor/shield/consumable/material/mount/potion with recipes/effects.
- `res://data/locations.json` : 10+ locations with normalized positions and NPC lists for cities.

Edit JSON and restart the game to reload databases.

## Saving/Loading & Offline Progress
- Save writes to `user://save.json` via the **Save** button.
- Load pulls from that file; offline progress (up to 8 hours) simulates ticks on load.

## Android export
- Android preset already included; confirm `screen/orientation` remains `landscape` (value `0`) to lock landscape-only builds and keep the provided stretch settings.
- Export as APK or AAB after configuring signing.

## Controls
- Time scale buttons: Pause/1x/2x/4x.
- Map markers: tap any marker to queue travel.
- Command tab: queue manual intents (hunt, gather, mine, rest, craft, shop, quest).
- Location tab: shows city NPC list; tapping queues context actions (inn->rest, blacksmith->craft, shops->shop, quest guild->quest).
- Inventory/Log tabs: auto-update as actions occur.

## Assets
- Procedural in-engine gradient map generated at runtime by default.
- `map.txt` placeholder marks where to drop your provided map image. Replace it with your own `map.png` (landscape-friendly) to show a custom map in-game. If `map.png` is missing, the gradient fallback stays active.
- `icon.txt` placeholder indicates where to put your application icon. After replacing it with `icon.png` and pointing `config/icon` in `project.godot` to that path, Godot will use your image for window and export icons.
