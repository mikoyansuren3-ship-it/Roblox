# Restore a Planet

A cozy eco-simulator for Roblox by **OneMore**. Plant and grow progressively rarer
trees, clean plastic from beaches and the ocean, and collectively "restore the
planet" — with a live, server-wide Impact Counter that mirrors OneMore's real
tree-planting and plastic-removal reporting.

- **v1:** Forest loop (dig → plant → grow → harvest).
- **Update 1:** Ocean (beach pickup → boats → idle Fisherman).

See the design/economy spec in the Cursor canvas: `onemore-game-content.canvas.tsx`.

## Tech / structure

This is a [Rojo](https://rojo.space) project. Source lives under `src/` and maps
into the Roblox data model:

```
src/
  shared/   -> ReplicatedStorage/Shared      (config, types, networking)
    Config/GameConfig.luau   tuning constants
    Config/Rarities.luau     the 7-tier rarity ladder
    Types.luau               saved-data type definitions
    Net.luau                 remote setup + name-based access
  server/   -> ServerScriptService/Server    (authoritative logic)
    init.server.luau         boot order
    Packages/ProfileStore.luau vendored data-persistence library (MadStudio)
    Data/ProfileTemplate.luau default data for new players
    Data/DataManager.luau     thin wrapper over ProfileStore (load/get/save)
    Services/PlotService.luau  per-player plot allocation
    Services/FarmingService.luau plant/grow/harvest loop + seed-drop gacha
    Services/EconomyService.luau coin/seed mutations (server-authoritative)
    Services/ShopService.luau    buy seeds / upgrade shovels
    Services/PlayerService.luau  player lifecycle orchestration
  client/   -> StarterPlayer/StarterPlayerScripts/Client
    init.client.luau         HUD: coins, seed bar, shop, reveal card
```

**Art assets** (generated tree meshes, etc.) live in the place file under
`ReplicatedStorage/Shared/Assets`, not in this repo — they're binary and are
saved with the `.rbxl`. Save the place (Cmd+S) to persist them.

## Getting it running

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this folder:
   ```
   rokit install
   ```
   (installs the pinned Rojo from `rokit.toml`)
2. Start the server:
   ```
   rojo serve
   ```
3. In Roblox Studio, install the Rojo plugin and click **Connect**.
4. Press **Play**. You should see the debug HUD (Coins / Region) top-left.

### DataStores in Studio

Player data is handled by **ProfileStore** (the 2026 successor to ProfileService:
session locking, retries, autosave, shutdown saves). To persist while testing in
Studio, enable **Game Settings → Security → Enable Studio Access to API
Services**. Without it, the DataManager falls back to `ProfileStore.Mock` (data
resets each session) and logs a warning — so the game still runs, it just won't
save.

## Status

Phase 0 (foundation) and Phase 1 (core Forest loop) complete: data schema,
ProfileStore-backed persistence, server-authoritative networking, per-player
plots, and the full plant → grow → harvest → seed-drop loop with shop, HUD, and
rare-reveal moments. Tree art uses generated low-poly meshes mapped by species.
Phase 2 started: **Tree Dex** collection UI tracks discovered species (harvest
or seed-drop unlocks), shows progress, and toasts on new discoveries. Next up:
animal companions, prestige, or the Ocean biome. Impact Counter saved for last.
