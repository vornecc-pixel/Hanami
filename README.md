# Hanami

`@abusegpt` suite — silent aim, wall penetration, player/NPC/crate ESP, entity scanner, aim snapline and gun mods — with an **Atlanta** UI.
The original 1,300-line script is split into **23 short files** (`src/`, largest is 150 lines) plus a short **loader**.

## Load it (one line)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/vornecc-pixel/Hanami/refs/heads/arena/bb927757-hanami/loader.lua"))()
```

If your executor won't follow redirects or blocks that host, use the `github.com` form:

```lua
loadstring(game:HttpGet("https://github.com/vornecc-pixel/Hanami/raw/refs/heads/arena/bb927757-hanami/loader.lua"))()
```

> Changing branches/forking? Edit `REF` (and the fallback roots) at the top of `loader.lua`.
> e.g. `local REF = "Fuck-Nigga"`.

## What's new

| Feature | Where | Notes |
|---|---|---|
| **Player visibility check** | ESP → Player ESP | Box, name, fill and info line turn **green when there is a clear line of sight** and **red when a wall blocks it**. Cached camera raycast (~120 ms) so it costs ~30 raycasts / 0.12 s on a 30-player server, not 30 per frame. |
| **FOV snapline** | Visual → FOV Circle / Snapline | A line + dot drawn to the exact bone `pickBestTarget` would shoot, **green = visible, red = blocked**. Uses a `preview` lookup that skips hit-chance RNG and the wall abort, so the line doesn't flicker. `SA.Target` also stores the model, position, visibility and screen point for the "Print Current Target" debug button. |
| **NPC silent aim** | Aiming → Silent Aim → Target NPCs | ON by default. `pickBestTarget` now selects from players **and** the NPC registry. |
| **NPC ESP** | ESP → NPC ESP | Separate section for `Guard`, `Scavenger`, `Soldier`. Name/distance/health box, visibility colours, and its own scanner options. |
| **Entity scanner** | ESP tab + Misc | Reads an equipped `Tool`, `ItemId` / `Weapon` / `HeldItem` attributes and weapon containers, plus `Downed` / `Knocked` / `Dead` / `State` attributes with a `HumanoidStateType` fallback. `Show Weapon` and `Show State` are options on **both** player and NPC ESP; a third `VIS` / `WALL` tag appears when the visibility check is on. "Scan Players", "Scan NPCs" and "Scan All Entities" dump the same data to the console. |
| **Wall-pen description** | Aiming → Wall Penetration + below | Tooltips, three in-UI labels, and a one-click **Apply Recommended Wall Pen** button. |

NPC detection accepts the literal model names `Guard` / `Scavenger` / `Soldier`, the common `Scavenger`/`IsNpc`/`NPC` attributes, and models inside `Npcs` / `Enemies` folders. The registry scans the **whole workspace** in a background task every 2 s (refreshed ~0.2 s after an NPC spawns), so it isn't limited to an `Npcs` folder and never hitches a render frame. Real player characters are explicitly excluded.

## Best settings for wall penetration

Wall penetration = the **FOV-aware wall peek** (`Aiming → Wall Penetration`). It temporarily disables `CanQuery` on the wall parts in front of you for the hit-scan, then restores them immediately after the shot. It is FOV-gated, so it only spends raycasts on targets that are actually inside your aim cone.

**Recommended all-round setup** (press **Apply Recommended Wall Pen** to set all of it at once):

| Setting | Value | Why |
|---|---|---|
| Enabled (FOV-aware) | **ON** | Turns on the peek/disable-restore cycle. |
| Wall Check | **OFF** | Strict LOS-only mode. It is bypassed automatically while Manipulation is ON anyway — with it ON *and* penetration OFF, shots behind any wall are aborted. |
| Range | **75 studs** | Covers most fights. Pushing to 100 searches a lot more geometry for little gain. |
| Max Peek Offset | **4** | Enough side clearance for thin walls / door frames without teleporting the ray origin far off your crosshair. |
| Max CanQuery Parts | **3** | Handles a wall + a prop + a fence. Higher values make the restore pass heavier and are more noticeable. |
| Ray Budget / Frame | **64** | Good balance between finding a clear peek and staying smooth. Use **32** on low-end devices / big servers. |
| Cache Hysteresis | **5 frames** | Keeps the same peek active instead of re-scanning every frame when you strafe. |
| Max Peek Delta | **6** | Caps how far a cached peek may drift before it is recomputed. |
| Aim / Circle Radius (FOV) | **~150 px** | A narrower cone means fewer candidate peeks per frame — the single biggest CPU saving. |
| Hit Chance | **100 %** | No random skipped shots while you're testing penetration. |
| Cooldown | **0 s** | Fire as fast as the weapon allows. |
| Prediction | **ON** | Compensates moving targets; penetration doesn't help if the shot lands behind them. |
| Target Bone | **Head** | Smaller target → fewer ambiguous multi-part peeks. |

Two useful variants:

* **Strict / legit** — Manipulation `OFF`, Wall Check `ON`, FOV `~120`, Hit Chance `60–80`. Only shoots what you can genuinely see.
* **Heavy cover / static targets** — keep the recommended values but raise `Max CanQuery Parts` to `5` and `Ray Budget` to `96`; keep FOV at `150` so the extra rays stay bounded.

The snapline and the red ESP colour are your penetration indicator: **green = you already have line of sight, no penetration needed; red = a wall is in the way**. Note that with `Hit Chance < 100` the snapline still shows the target it *would* pick — the shot itself may be skipped by the RNG.

## UI: Atlanta

`src/18_ui_aiming.lua` loads the [Atlanta library](https://github.com/i77lhm/Libraries) and builds the window; parts 19–22 build the tabs.

```
Aiming   → Silent Aim / Gun · Target / Wall Penetration
ESP      → Player ESP / NPC ESP · Loot Crate ESP
Gun Mods → Gun Mods · State Overrides
Visual   → FOV Circle / Snapline · Debug
Misc     → Info · Quick Actions
```

* **Every widget writes straight into `CFG`** through its `callback`, and every `default` is read from `CFG`. Building the menu never resets the settings kept in `_G.__saCFG`.
* Flags are prefixed `hn_` so they can't collide with the library's own config flags. `setFlag("someKey", value)` and `setToggle(obj, value)` are what the presets and quick actions use, so the UI stays in sync when values change programmatically.
* **Keys:** `RightShift` toggles silent aim (chained keybind on the master toggle), `Insert` shows/hides the menu (Atlanta default).
* Colourpickers are wired to real code, not decoration: FOV circle, player flat/visible/hidden, NPC visible/hidden, snapline visible/hidden, and military/elite/opened crate colours all update the shared locals used by the drawing code.
* The old Shaman `RadioButton` preset is now a `Custom / Legit / Blatant` dropdown ("Custom" is the default so opening the menu doesn't apply a preset). A `Bullet Speed Override` slider is wired to `CFG.gunBulletSpeed`.
* Quick actions: Disable All (also clears NPC ESP + snapline), Apply Blatant, Toggle Manip, Unload Everything (also hides the Atlanta window), Scan All Entities — plus Rescan NPCs, Rescan Crates and the debug print buttons.

Two things from the Atlanta template that were intentionally **not** copied: the duplicated `vis, other` multi-section block, and `window.esp_section:esp_preview({})` (it clones your character and assumes an `Animate` script, so it errors on spawn/respawn). Everything else from the template's init block is kept: `open_tab()`, `config_list_update()`, the theme pass, and `old_config = get_config()` — each guarded with `pcall` where it touches filesystem/config APIs.

## How the loader works

`loader.lua` downloads each file in `PARTS`, joins them with `\n\n`, and calls `loadstring` **once**.
Because it is one chunk, every `local` (CFG, helpers, ESP tables, UI handles) is shared across files — the UI parts can assign `espColorVisible`, `snapColorHidden`, `fovColor`, etc. directly.

```
loader.lua  ──fetch──▶  01_config.lua
                       02_shared.lua
                       ...
                       23_banner.lua
             ──join──▶ one chunk ──loadstring──▶ runs, returns CFG
```

Parts 01–02, 05–08 and 14–17 are slices of the original script with a 5-line comment header. Parts 03–04 (NPC registry / entity scanner), 09 (snapline), 12–13 (NPC ESP) are new; 10–11 gained visibility colours and scanner labels; 18–23 are the Atlanta UI. The former hit-log / hit-sound part and its config key were removed. Only `23_banner.lua` has a top-level `return`.

## Files

| Part | What's in it | Lines |
|---|---|---|
| `src/01_config.lua` | services, `CFG` defaults + backfill, `SA` state, shared colours, bullet speeds | 149 |
| `src/02_shared.lua` | velocity cache, team/NPC checks, target picking, debug | 147 |
| `src/03_entity_scan.lua` | NPC registry (workspace scan) + LOS visibility cache | 113 |
| `src/04_entity_info.lua` | entity scanner: tool/weapon + state + roster + console dump | 131 |
| `src/05_manipulation.lua` | wall peek + `CanQuery` manipulation | 148 |
| `src/06_firing_and_guns.lua` | firing state, gun lookup, cooldown | 73 |
| `src/07_silent_aim.lua` | camera sandwich RenderStep binds | 68 |
| `src/08_fov_circle.lua` | FOV circle drawing | 37 |
| `src/09_snapline.lua` | aim preview line + target marker | 88 |
| `src/10_esp_players.lua` | player ESP objects, box, health bar, info label | 94 |
| `src/11_esp_players_refresh.lua` | player ESP refresh (visibility + scanner) + enable/disable | 103 |
| `src/12_esp_npcs.lua` | NPC ESP objects + enable/disable + events | 109 |
| `src/13_esp_npcs_refresh.lua` | NPC ESP refresh (visibility + scanner) | 84 |
| `src/14_esp_crates.lua` | crate ESP objects + state/labels | 100 |
| `src/15_esp_crates_refresh.lua` | crate refresh, scanners, events | 66 |
| `src/16_render_loop.lua` | master player/NPC/crate ESP render loop | 29 |
| `src/17_gun_mods.lua` | GC scan gun mods | 88 |
| `src/18_ui_aiming.lua` | Atlanta setup, binding helpers, Aiming tab + wall pen recommendation | 150 |
| `src/19_ui_esp.lua` | ESP tab (players, NPCs, crates) + colourpickers | 121 |
| `src/20_ui_gunmods.lua` | Gun Mods tab | 22 |
| `src/21_ui_visual.lua` | Visual tab (FOV, snapline, debug) | 62 |
| `src/22_ui_misc.lua` | Misc tab, quick actions, UI init | 65 |
| `src/23_banner.lua` | startup banner, `return CFG` | 29 |

## Editing

* Parts share one scope: a `local` declared in an earlier part is visible in later ones.
* **Order matters.** Adding/removing a part means updating `PARTS` in `loader.lua` too.
* Never put a top-level `return` in any part except `23_banner.lua` — it would end the joined chunk early.
* Keep a trailing newline on every part (they are concatenated directly).
* Atlanta widgets need a `button_holder()` row before `button()`, and keybinds/colourpickers must be chained onto a toggle (a colourpicker can be chained onto another colourpicker).
* All 57 `CFG` keys used by the logic must stay bound to a UI widget; `python3 tools/verify.py` checks the join.

```bash
python3 tools/verify.py   # checks order, newlines, stray returns, build output
bash build.sh             # optional: make one self-contained dist/Hanami.lua
```

`build.sh` is only needed if you want a single paste-able file; the runtime loader does the same join automatically. `dist/` is gitignored.

---

Executor-only script (`Drawing`, `getgc`, `loadstring`, `getcustomasset`). Use in private/own places; running it in public experiences can violate Roblox's Terms of Use and get an account banned.
