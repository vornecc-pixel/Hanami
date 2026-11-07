# Hanami

`@abusegpt` suite — silent aim, wall penetration, player ESP, crate ESP, gun mods, hit log — now with an **Atlanta** UI.
The original 1,300-line script is split into **19 short files** (`src/`, biggest is 148 lines) plus a **72-line loader**.

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

## UI: Atlanta

`src/14_ui_aiming.lua` loads the [Atlanta library](https://github.com/i77lhm/Libraries) and builds the window; parts 15–18 build the tabs.

```
Aiming   → Silent Aim / Gun · Target / Wall Penetration
ESP      → Player ESP · Loot Crate ESP
Gun Mods → Gun Mods · State Overrides
Visual   → FOV Circle · Debug
Misc     → Info · Quick Actions
```

* **Every widget writes straight into `CFG`** through its `callback`, and every `default` is read from `CFG`. Building the menu never resets the settings kept in `_G.__saCFG`.
* Flags are prefixed `hn_` so they can't collide with the library's own config flags. `setFlag("someKey", value)` and `setToggle(obj, value)` are what the presets and quick actions use, so the UI stays in sync when values change programmatically.
* **Keys:** `RightShift` toggles silent aim (chained keybind on the master toggle), `Insert` shows/hides the menu (Atlanta default).
* Colourpickers are wired to real code, not decoration: FOV circle colour, player ESP colour, and military/elite/opened crate colours all update the shared locals used by the drawing code.
* The old Shaman `RadioButton` preset is now a `Custom / Legit / Blatant` dropdown ("Custom" is the default so opening the menu doesn't apply a preset). A `Bullet Speed Override` slider was added for the previously unreachable `CFG.gunBulletSpeed`.
* Quick actions still work: Disable All, Apply Blatant, Toggle Manip, Unload Everything (also hides the Atlanta window) — plus Rescan Crates and the three debug print buttons.

Two things from the Atlanta template that were intentionally **not** copied: the duplicated `vis, other` multi-section block, and `window.esp_section:esp_preview({})` (it clones your character and assumes an `Animate` script, so it errors on spawn/respawn). Everything else from the template's init block is kept: `open_tab()`, `config_list_update()`, the theme pass, and `old_config = get_config()` — each guarded with `pcall` where it touches filesystem/config APIs.

## How the loader works

`loader.lua` downloads each file in `PARTS`, joins them with `\n\n`, and calls `loadstring` **once**.
Because it is one chunk, every `local` (CFG, helpers, ESP tables, UI handles) is shared across files — the UI parts can assign `espColor`, `crateColorElite`, `fovColor`, etc. directly.

```
loader.lua  ──fetch──▶  01_config.lua
                       02_shared.lua
                       ...
                       19_banner.lua
             ──join──▶ one chunk ──loadstring──▶ runs, returns CFG
```

Parts 01–13 are slices of the original script with a 5-line comment header (byte-identical when joined). Part 06 gained a `fovColor` local, and parts 14–19 were rewritten for the Atlanta API; the non-UI logic is unchanged.

## Files

| Part | What's in it | Lines |
|---|---|---|
| `src/01_config.lua` | services, `CFG` defaults + backfill, bullet speeds | 110 |
| `src/02_shared.lua` | velocity cache, team/NPC checks, target picking, debug | 134 |
| `src/03_manipulation.lua` | wall peek + `CanQuery` manipulation | 148 |
| `src/04_firing_and_guns.lua` | firing state, gun lookup, cooldown | 73 |
| `src/05_silent_aim.lua` | camera sandwich RenderStep binds | 64 |
| `src/06_fov_circle.lua` | FOV circle + `fovColor` local | 38 |
| `src/07_esp_players.lua` | player ESP objects + box/health bar | 79 |
| `src/08_esp_players_refresh.lua` | player ESP refresh + enable/disable | 87 |
| `src/09_esp_crates.lua` | crate ESP objects + state/labels | 100 |
| `src/10_esp_crates_refresh.lua` | crate refresh, scanners, events | 66 |
| `src/11_render_loop.lua` | master ESP + crate render loop | 23 |
| `src/12_gun_mods.lua` | GC scan gun mods | 88 |
| `src/13_hitlog.lua` | hit log GUI, hit sound, damage tracker | 125 |
| `src/14_ui_aiming.lua` | Atlanta setup, binding helpers, Aiming tab | 129 |
| `src/15_ui_esp.lua` | ESP tab + colourpickers | 69 |
| `src/16_ui_gunmods.lua` | Gun Mods tab | 22 |
| `src/17_ui_visual.lua` | Visual tab (FOV + debug) | 42 |
| `src/18_ui_misc.lua` | Misc tab, quick actions, UI init | 60 |
| `src/19_banner.lua` | startup banner, `return CFG` | 25 |

## Editing

* Parts share one scope: a `local` declared in an earlier part is visible in later ones.
* **Order matters.** Adding/removing a part means updating `PARTS` in `loader.lua` too.
* Never put a top-level `return` in any part except `19_banner.lua` — it would end the joined chunk early.
* Keep a trailing newline on every part (they are concatenated directly).
* Atlanta widgets need a `button_holder()` row before `button()`, and keybinds/colourpickers must be chained onto a toggle.

```bash
python3 tools/verify.py   # checks order, newlines, stray returns, build output
bash build.sh             # optional: make one self-contained dist/Hanami.lua
```

`build.sh` is only needed if you want a single paste-able file; the runtime loader does the same join automatically. `dist/` is gitignored.

---

Executor-only script (`Drawing`, `getgc`, `gethui`, `loadstring`, `getcustomasset`). Use in private/own places; running it in public experiences can violate Roblox's Terms of Use and get an account banned.
