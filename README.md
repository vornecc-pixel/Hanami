# Hanami

`@abusegpt` suite — silent aim, wall penetration, player/NPC/crate ESP, entity scanner, aim snapline, ballistic prediction and gun mods — with an **Atlanta** UI.
The original 1,300-line script is split into **29 short files** (`src/`, largest is 251 lines) plus a short **loader**.

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
| **Crate ESP fixed** | ESP → Crate ESP | Root cause: only two exact model names were matched, discovery ran once at enable, non-recursive part lookup found no anchor, and no `Adornee` was set. Now uses fuzzy name + attribute classification, a live 1.5 s registry, recursive anchors, explicit `Adornee`, and frame-by-frame rediscovery. See the ESP overhaul section. |
| **48 colourpickers** | ESP → Colours | One clearly-labelled picker for **every** drawn element (players, NPCs, crates, snapline, FOV, lead, target). All write into one shared `ESP_COLORS` table that survives re-execution. |
| **Customizable visibility colours** | ESP → Colours · Player / NPC | Green (clear LOS) / red (blocked) are now obvious labelled pickers, not tiny swatches buried on unrelated toggles. They paint an outer frame, a visibility dot and the `VIS` / `WALL` tag even when per-element colours are on. |
| **New ESP visuals** | ESP → ESP Features | Corner boxes, chams fill + outline, R6/R15 skeleton, head dot, tracer lines, off-screen arrows, visibility dot, distance fade, rainbow cycle, per-NPC-type colours and an aim-target highlight — every one has its own colourpicker. |
| **Per-element colour mode** | ESP → ESP Features | `ON` (default): each element uses its own picker. `OFF`: the green/red visibility colour (or crate type colour) paints everything, like the classic ESP. |
| **Crate diagnostics** | ESP → Crate ESP | **Print Crate Names (debug)** lists every container-ish instance with its class, classified kind and parent, so the exact names your game uses can be found. |
| **Ballistic prediction** | Aiming → Ballistics | Replaced the old one-step `distance/speed` guess with an exact quadratic intercept solve using each gun's real `speed`, bullet drop, alt ammo, ping and range. See the next section. |
| **Player visibility check** | ESP → Player ESP | Box, name, fill and info line turn **green when there is a clear line of sight** and **red when a wall blocks it**. Cached camera raycast (~120 ms) so it costs ~30 raycasts / 0.12 s on a 30-player server, not 30 per frame. |
| **FOV snapline** | Visual → FOV Circle / Snapline | Line + dot to the target, **green = visible, red = blocked**, plus a gold **lead ring** at the exact point the solver aims at. Uses a `preview` lookup that skips hit-chance RNG so it doesn't flicker. |
| **NPC silent aim** | Aiming → Silent Aim → Target NPCs | ON by default. `pickBestTarget` selects from players **and** the NPC registry. |
| **NPC ESP** | ESP → NPC ESP | Separate section for `Guard`, `Scavenger`, `Soldier`. Name/distance/health box, visibility colours, and its own scanner options. |
| **Entity scanner** | ESP tab + Misc | Reads an equipped `Tool`, `ItemId` / `Weapon` / `HeldItem` attributes and weapon containers, plus `Downed` / `Knocked` / `Dead` / `State` attributes with a `HumanoidStateType` fallback. `Show Weapon` and `Show State` are options on **both** player and NPC ESP; a third `VIS` / `WALL` tag appears when the visibility check is on. |
| **Wall-pen description** | Aiming → Wall Penetration + below | Tooltips, three in-UI labels, and a one-click **Apply Recommended Wall Pen** button. |

NPC detection accepts the literal model names `Guard` / `Scavenger` / `Soldier`, the common `Scavenger`/`IsNpc`/`NPC` attributes, and models inside `Npcs` / `Enemies` folders. The registry scans the **whole workspace** in a background task every 2 s (refreshed ~0.2 s after an NPC spawns), so it isn't limited to an `Npcs` folder and never hitches a render frame. Real player characters are explicitly excluded.

## ESP overhaul: crate fix, colours and new features

### Why the Crate ESP didn't work

Four separate bugs in the old parts (now `src/16_esp_crates*.lua`, `src/17_esp_crates_refresh.lua`, `src/19_render_loop.lua`):

1. **Exact-name only.** `CRATE_NAMES` contained just `"Military Crate"` and `"Elite Crate"`. Real revisions use `MilitaryCrate`, `Crate_Military`, `Elite_Crate`, `LootCrate`, hashed ids, or a `Folder` with a `CrateType` attribute — so nothing was ever classified and nothing was ever drawn.
2. **One-shot discovery.** `enableCrateESP()` scanned `Workspace` once. The only follow-up was `DescendantAdded`, which fires for a Model **before** its parts are parented; `buildCrate()` found no anchor and gave up permanently. Unlike NPCs, the render loop never retried containers.
3. **Non-recursive anchor.** `FindFirstChildWhichIsA("BasePart")` checks direct children only, so crates whose parts live in nested sub-models had no anchor.
4. **No explicit `Adornee`.** A `BillboardGui` / `Highlight` parented to a `Folder` or a nested model renders nothing without one.

Also `stateOk = opened and crateShowOpened or not opened` silently hid every opened crate when the toggle was off; it is now explicit.

**Fix:** `crateKind()` normalises names (lowercase, punctuation stripped), checks `military` / `elite` / `crate` / `loot` / `supply` / `airdrop` / `cache` / `chest` / `stash`, reads `CrateType` / `Tier` / `Rarity` / `Opened` / `Looted` attributes, and excludes player characters and NPCs. A `_G`-guarded background scanner rebuilds the crate list every 1.5 s; `SA.GetCrates()` is read every frame by the render loop, `SA.RefreshCrates()` forces an immediate rescan, and `buildCrate()` uses `FindFirstChildWhichIsA("BasePart", true)` plus explicit `Adornee`. New `Loot` kind covers supply drops and other containers. **Print Crate Names (debug)** and **Rescan Crates** are buttons in the Crate ESP mini-tab.

### Unified colour system

`src/01_config.lua` declares `ESP_DEFAULT_COLORS` (48 keys) and merges it into `ESP_COLORS`, persisted in `_G.__saEspColors`. Every drawing part reads `ESP_COLORS.<key>`; every colourpicker writes `ESP_COLORS.<key>`; `Reset ESP Colours` (Misc) restores the defaults through the library's `config_flags`, so the UI swatches stay in sync. The old scattered `local espColorVisible = ...` / `local crateColorMilitary = ...` variables are gone.

`ESP → Colours` has four mini-tabs (Player / NPC / Crate / Global). Each row is an Atlanta `label` with a chained `colorpicker` — labels expose a `right_holder`, so no dummy toggle is needed. Flags are `hn_col_<key>`, unique per colour.

| Group | Pickers |
|---|---|
| Player | visible, hidden, flat, visibility dot, name, distance, scanner text, box, chams fill, chams outline, health high/low, skeleton, head dot, tracer, off-screen arrow |
| NPC | the same set, plus `Guard` / `Scavenger` / `Soldier` type colours |
| Crate | Military, Elite, Other loot, Opened, state text, distance text, tracer, off-screen arrow (type colour also paints box / fill / name) |
| Global | snapline visible / blocked, lead marker, FOV circle, FOV while wall-pen is on, aim target |

The dynamic **visible / hidden** colour always paints an outer frame around the box, the visibility dot and the `VIS` / `WALL` info tag, so it stays meaningful even with per-element colours enabled. `NPC Type Colours` overrides box/fill/outline for Guard/Scavenger/Soldier; `Highlight Aim Target` paints the entity silent aim is choosing with the `target` colour.

### New ESP visuals (all in `ESP → ESP Features`)

| Feature | What it draws | Default |
|---|---|---|
| Per-Element Colours | each element uses its own picker instead of the dynamic base | ON |
| Box Outline / Corner Boxes | 4 full edges or 8 corner segments | ON / OFF |
| Chams Fill / Outline | `Highlight` fill and outline | ON / OFF |
| Skeleton (bones) | 6 R6/R15-friendly segments (head→torso→root, arms, legs) | OFF |
| Head Dot | filled circle on `Head` | OFF |
| Tracer Lines | line from Mouse / Center / Bottom to each target | OFF |
| Off-screen Arrows | clamped triangle pointing at targets outside the view | OFF |
| Highlight Aim Target | target box / fill / outline uses the `target` colour | ON |
| Rainbow Mode + Speed | all colours cycle through HSV (speed slider) | OFF |
| Distance Fade + Fade Start (%) | transparency ramps in over the last N% of `Max Distance` | OFF |
| Line Thickness / Tracer Origin | 1–5 px, Mouse / Center / Bottom | 1 / Bottom |
| NPC Type Colours | Guard / Scavenger / Soldier get distinct colours | OFF |

All extra `Drawing` objects are created **lazily** per entity and destroyed by `SA.DisposeEspFx(o)` when the object is cleared, so a feature that is off costs zero drawings. `SA.ApplyEspFx(cam)` runs once per frame after the player/NPC/crate refreshes. The FX pipeline is split across `18_esp_fx_colours.lua` / `18_esp_fx_draw.lua` / `18_esp_fx_frame.lua`.

## Ballistic prediction

The old prediction was:

```lua
local speed  = getGunSpeed()                         -- wrong hardcoded table, default 1000
local travel = (targetPos - camera.CFrame.Position).Magnitude / speed
local vel    = getVelocity(best.bone)                -- raw single-frame delta, very noisy
if vel.Magnitude > 0.5 then targetPos = targetPos + vel * travel end
```

`GUN_SPEEDS`, `GUN_DEFAULT_SPEED`, `getGunSpeed()`, `getEquippedGunId()` and the single-frame `velCache` are **gone**. In their place:

* `src/07_gun_specs.lua` — exact game definitions for all 19 guns, ammo damage, alt-ammo modifiers, falloff profiles, `GUN_RANGE`, `gravity`/`life`, and the `u3492.GunDamage` formula.
* `src/08_prediction.lua` — smoothed target velocity, an exact intercept solver and the debug helpers.

### Gun data

`speed` is the projectile speed — it is **not** called `bulletSpeed`. Values already include the `u3338.GUNS` overrides (`bolt_action_rifle` 2600 → **2200**, `lr_sniper` 3000 → **2600**). `hunt_smg` shares the `custom_smg` override.

| Gun id | Speed | Ammo | dmgMult | Effective dmg / pellet | Pellets | gravity / life | GUN_RANGE |
|---|---|---|---|---|---|---|---|
| `pipe_shotgun` | 560 | handmade_shell | 1 | 13 | 8 | — | 200 |
| `double_barrel` | 520 | handmade_shell | 1 | 13 | 10 | — | 200 |
| `pump_shotgun` | 560 | handmade_shell | 1 | 13 | 9 | — | 200 |
| `revolver` | 950 | pistol_bullet | 1 | 32 | 1 | — | 400 |
| `semi_auto_pistol` | 900 | pistol_bullet | 0.85 | 27.2 | 1 | — | 400 |
| `service_pistol` | 950 | pistol_bullet | 0.9 | 28.8 | 1 | — | 400 |
| `high_caliber_revolver` | 1100 | pistol_bullet | 1.72 | 55.04 | 1 | — | 700 |
| `lever_carbine` | 1250 | pistol_bullet | 1.4 | 44.8 | 1 | — | 700 |
| `custom_smg` | 900 | pistol_bullet | 0.8 | 25.6 | 1 | 8 / 1 | 450 |
| `hunt_smg` | 900 | pistol_bullet | 0.8 | 25.6 | 1 | 8 / 1 | 450 |
| `tactical_smg` | 950 | pistol_bullet | 0.75 | 24 | 1 | 8 / 1 | 450 |
| `drum_smg` | 880 | pistol_bullet | 0.85 | 27.2 | 1 | 8 / 1 | 450 |
| `semi_auto_rifle` | 1425 | rifle_ammo | 1 | 40 | 1 | — | 900 |
| `assault_rifle` | 1350 | rifle_ammo | 0.9 | 36 | 1 | — | 900 |
| `scar` | 1450 | rifle_ammo | 1.15 | 46 | 1 | — | 900 |
| `m249` | 1400 | rifle_ammo | 1.1 | 44 | 1 | — | 900 |
| `bolt_action_rifle` | 2200 | rifle_ammo | 1.9 | 76 | 1 | 30 / 1.9 | 1400 |
| `lr_sniper` | 2600 | rifle_ammo | 2.1 | 84 | 1 | 24 / 1.8 | 1600 |
| `rocket_launcher` | 80 | rocket | 1 | 1 | 1 | — | 550 (default) |

`GUN_BALANCE.damage` (11, 27, 22, 20, 39, 39, 40, 24, 78, 82, 42, 8, 9, 28, 21, 24, 45, 51.5) is stored as `balance` for reference only — **it is not the damage**. `GUN_BALANCE` falloff profiles: `v20` {60,200,0.6}, `v21` {25,100,0.8}, `v22` {150,500,0.75}, pellet {25,60}; customs for `semi_auto_rifle` {250,550,0.75}, `lever_carbine` {200,550,0.75}, `high_caliber_revolver` {150,450,0.7}, `lr_sniper` {300,1600,0.7}.

### Damage formula

`u3492.GunDamage` = `s2Damage` when `Saturday2()` is on, otherwise `Defs[ammo].damage * damageMult`. The `damage` field on every gun definition is **0** and is ignored. Ammo base damage: `handmade_shell` 13, `pistol_bullet` 32, `rifle_ammo` 40, `rocket` 1.

Alt ammo modifiers applied by the resolver:

| Ammo | Effect |
|---|---|
| `hv_rifle_ammo` | **1.5× speed**, 0.85× damage |
| `explosive_rifle_ammo` | no speed/damage change recorded |
| `buckshot_shell` | 1.35× damage, 0.75× pellets, 0.85 spread |
| `slug_shell` | 1 pellet, `0.7 whole` (interpreted as 70% of the full spread damage), 0.3 spread |
| `hv_rocket` | speed **140** (absolute), drop 2 |
| `incendiary_rocket` | no speed/damage change recorded |

`muzzle_boost` = +15% fire rate / −10% damage (toggle in Ballistics). `mag_extender` ×1.3333 mag, `silencer` 300 shots — neither changes projectile speed. `Saturday2 Damage` forces the `s2Damage` branch; the game normally exposes `Saturday2()` / `s2Damage` through `SA.Saturday2` / `SA.S2Damage` hooks (see below).

### The solver

1. **Velocity** — `SA.TargetVelocity(model)` samples `HumanoidRootPart.Position` into a weak-keyed, exponentially smoothed estimate (`alpha = clamp(dt*12, 0.15, 0.6)`, teleports >120 studs/s dropped). No more single-frame spikes.
2. **Exact intercept** — solve `|(p₀ − o) + v·t|² = (s·t)²` for the smallest positive root, where `s` is the equipped gun's real speed. For a stationary target this is exactly `distance/speed`; for a moving target it accounts for the target closing/retreating during flight.
3. **Bullet drop** — for guns with `gravity`, aim above by `½·g·t²` and re-derive the flight time from the new aim point (`Solver Iterations`, 1–8, default 4). Guns without gravity converge in one pass.
4. **Latency** — `Extra Lead (ping ms)` is added **once** as `tTotal = flightTime + latency`, never once per iteration.
5. **Bounds** — flight time is clamped to the gun's `life` (projectile despawn), and the result reports `inRange` against `GUN_RANGE` (default 550). Out-of-range/expires are exposed to the snapline so the lead ring is hidden when the shot can't reach.

`SA.Predict(origin, targetPos, model)` returns `aimPoint, info`. `info` carries `t`, `total`, `speed`, `velocity`, `lead`, `drop`, `latency`, `range`, `inRange`, `expired`, `id`, `ammo`, `gravity`. Silent aim uses it on every snap; the snapline uses it to draw the gold lead ring.

### Controls (Aiming → Ballistics / Visual)

| Control | Default | What it does |
|---|---|---|
| Ballistic Prediction | ON | Master toggle for the solver |
| Bullet Drop Compensation | ON | `½gt²` vertical aim offset |
| Detect Alt Ammo | ON | Reads `Ammo`/`AmmoType`/`LoadedAmmo` attributes off the tool |
| Solver Iterations | 4 | Fixed-point refinement passes |
| Extra Lead (ping ms) | 0 | Extra lead if shots land behind moving targets |
| Bullet Speed Override | 0 (auto) | Manual speed, 0–3000; overrides the gun table |
| Ammo Override | Auto | Force any of the 4 base + 6 alt ammo types |
| Saturday2 Damage | OFF | Use the `s2Damage` branch of `GunDamage` |
| Muzzle Boost Equipped | OFF | Apply +15% rate / −10% damage |
| Show Lead Marker | ON | Gold ring at the predicted aim point (Visual tab, with colourpicker) |

Debug buttons (Visual → Debug): **Print Gun Spec** (id, ammo, speed, drop, range, damage formula, `GUN_BALANCE` note, DPS), **Print Prediction** (flight time, lead, drop, range check), **Sync Gun Defs (GC)** and **Print Current Target**.

### Live game hooks

* `SA.SyncGunDefs()` scans `getgc(true)` for tables containing `GUN_RANGE` / `GUNS` and merges live `speed`, `gravity`, `life` and `range` into the static DB. It is opt-in (button), `pcall`-guarded and does nothing if `getgc` is unavailable.
* The equipped tool is resolved via `ItemId` / `WeaponId` / `ToolId` / `Item` / `Weapon` / `Gun` attributes or the tool name, normalised against the `model` names (`SemiAutoPistol`, `LRSniper`, `ScarRifle`, …) and display names. Unknown tools fall back to 1000 studs/s / 550 range and are flagged `[UNKNOWN]`.
* `SA.Saturday2 = fn` and `SA.S2Damage = function(id, spec) ... end` can be assigned at runtime if the game exposes them; `GunDamage` then uses the `s2Damage` branch automatically. Otherwise it uses `Defs[ammo].damage × damageMult`.
* `SA.Predict` assumes the game applies `gravity` as constant downward acceleration on the projectile. If a given gun has no visible drop in-game, turn **Bullet Drop Compensation** off.

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
| Prediction | **ON** | The ballistic solver compensates moving targets; penetration doesn't help if the shot lands behind them. |
| Target Bone | **Head** | Smaller target → fewer ambiguous multi-part peeks. |

Two useful variants:

* **Strict / legit** — Manipulation `OFF`, Wall Check `ON`, FOV `~120`, Hit Chance `60–80`. Only shoots what you can genuinely see.
* **Heavy cover / static targets** — keep the recommended values but raise `Max CanQuery Parts` to `5` and `Ray Budget` to `96`; keep FOV at `150` so the extra rays stay bounded.

The snapline and the red ESP colour are your penetration indicator: **green = you already have line of sight, no penetration needed; red = a wall is in the way**. Note that with `Hit Chance < 100` the snapline still shows the target it *would* pick — the shot itself may be skipped by the RNG.

## UI: Atlanta

`src/21_ui_aiming.lua` loads the [Atlanta library](https://github.com/i77lhm/Libraries) and builds the window; parts 22–27 build the tabs.

```
Aiming   → Silent Aim / Gun · Target / Ballistics / Wall Penetration
ESP      → Player ESP / NPC ESP · Crate ESP / ESP Features · Colours (Player / NPC / Crate / Global)
Gun Mods → Gun Mods · State Overrides
Visual   → FOV Circle / Snapline · Debug
Misc     → Info · Quick Actions
```

* **Every widget writes straight into `CFG`** through its `callback`, and every `default` is read from `CFG`. Building the menu never resets the settings kept in `_G.__saCFG`.
* Flags are prefixed `hn_` so they can't collide with the library's own config flags. `setFlag("someKey", value)` and `setToggle(obj, value)` are what the presets and quick actions use, so the UI stays in sync when values change programmatically.
* **Keys:** `RightShift` toggles silent aim (chained keybind on the master toggle), `Insert` shows/hides the menu (Atlanta default).
* **48 colourpickers** live in `ESP → Colours` and write straight into `ESP_COLORS`. Chained onto `label` rows (labels expose `right_holder`), each has a unique `hn_col_<key>` flag. FOV / snapline / lead / target colours moved here from the Visual tab so there is exactly one picker per colour. `Reset ESP Colours` restores defaults and syncs the swatches.
* The old Shaman `RadioButton` preset is now a `Custom / Legit / Blatant` dropdown ("Custom" is the default so opening the menu doesn't apply a preset). The `Bullet Speed Override` slider (0–3000) now lives in the Ballistics section.
* Quick actions: Disable All (also clears NPC ESP + snapline), Apply Blatant, Toggle Manip, **Reset ESP Colours**, Unload Everything (also hides the window and stops the NPC/crate scanners via `SA.Alive`), Scan All Entities — plus Rescan NPCs, Rescan Crates, Print Crate Names and the debug print buttons.

Two things from the Atlanta template that were intentionally **not** copied: the duplicated `vis, other` multi-section block, and `window.esp_section:esp_preview({})` (it clones your character and assumes an `Animate` script, so it errors on spawn/respawn). Everything else from the template's init block is kept: `open_tab()`, `config_list_update()`, the theme pass, and `old_config = get_config()` — each guarded with `pcall` where it touches filesystem/config APIs.

## How the loader works

`loader.lua` downloads each file in `PARTS`, joins them with `\n\n`, and calls `loadstring` **once**.
Because it is one chunk, every `local` (CFG, `ESP_COLORS`, gun specs, helpers, ESP tables, UI handles) is shared across files — the UI parts write `ESP_COLORS.playerVisible = c` and the drawing parts read it in the same frame. Access between parts that could load in either order goes through the `SA` table instead of forward locals.

```
loader.lua  ──fetch──▶  01_config.lua
                       02_shared.lua
                       ...
                       26_banner.lua
             ──join──▶ one chunk ──loadstring──▶ runs, returns CFG
```

Parts 01–02, 05–06, 10 are slices of the original script with a 5-line comment header. Parts 03–04 (NPC registry / entity scanner), 07–08 (gun specs / prediction), 14–15 (NPC ESP), 16–17 (crate detection / registry / refresh) and 18 (ESP FX, three parts) are new or rewritten; 09 was rewritten to use `SA.Predict`; 11–13 gained the lead marker, visibility colours and scanner labels; 21–27 are the Atlanta UI. The old prediction, velocity cache, hardcoded speed table, and the hit-log / hit-sound part were removed. Only `26_banner.lua` has a top-level `return`.

## Files

| Part | What's in it | Lines |
|---|---|---|
| `src/01_config.lua` | services, `CFG` defaults + backfill, `SA` state, **48-colour `ESP_COLORS` palette** | 251 |
| `src/02_shared.lua` | team/NPC checks, LOS raycast, target picking, debug | 116 |
| `src/03_entity_scan.lua` | NPC registry (workspace scan) + LOS visibility cache | 116 |
| `src/04_entity_info.lua` | entity scanner: tool/weapon + state + roster + console dump | 131 |
| `src/05_manipulation.lua` | wall peek + `CanQuery` manipulation | 148 |
| `src/06_firing_and_guns.lua` | firing state + snap cooldown | 50 |
| `src/07_gun_specs.lua` | exact gun DB: speeds, ammo, damage, alt ammo, falloff, ranges | 208 |
| `src/08_prediction.lua` | smoothed velocity, quadratic intercept, drop, latency, debug | 172 |
| `src/09_silent_aim.lua` | camera sandwich RenderStep binds using `SA.Predict` | 74 |
| `src/10_fov_circle.lua` | FOV circle drawing | 37 |
| `src/11_snapline.lua` | aim preview line + target/lead markers | 120 |
| `src/12_esp_players.lua` | player ESP objects, box, health bar, info label | 95 |
| `src/13_esp_players_refresh.lua` | player ESP refresh (visibility + scanner) + enable/disable | 103 |
| `src/14_esp_npcs.lua` | NPC ESP objects + enable/disable + events | 110 |
| `src/15_esp_npcs_refresh.lua` | NPC ESP refresh (visibility + scanner) | 84 |
| `src/16_esp_crates.lua` | **crate classification**, opened detection, recursive anchors, GUI objects | 175 |
| `src/16_esp_crates_registry.lua` | **live crate registry**, `SA.GetCrates` / `RefreshCrates` / `PrintCrateCandidates` | 105 |
| `src/17_esp_crates_refresh.lua` | crate refresh (filters, state, colour) + enable/disable + events | 81 |
| `src/18_esp_fx_colours.lua` | palette helpers, lazy `Drawing` factory, skeleton / screen / box geometry | 128 |
| `src/18_esp_fx_draw.lua` | **unified per-entity styling**: boxes, chams, skeleton, tracers, arrows, fade, rainbow | 176 |
| `src/18_esp_fx_frame.lua` | per-frame `SA.ApplyEspFx` for players / NPCs / crates | 121 |
| `src/19_render_loop.lua` | master render loop: ESP refresh + crate rediscovery + FX pass | 38 |
| `src/20_gun_mods.lua` | GC scan gun mods | 88 |
| `src/21_ui_aiming.lua` | Atlanta setup, binding helpers, Aiming tab (Target / Ballistics / Wall Pen) | 173 |
| `src/22_ui_esp.lua` | ESP tab: player / NPC / crate / features / **48 colourpickers** | 195 |
| `src/23_ui_gunmods.lua` | Gun Mods tab | 22 |
| `src/24_ui_visual.lua` | Visual tab (FOV, snapline, lead marker, gun/prediction debug) | 64 |
| `src/25_ui_misc.lua` | Misc tab, quick actions (incl. Reset ESP Colours), UI init | 77 |
| `src/26_banner.lua` | startup banner, `return CFG` | 36 |

## Editing

* Parts share one scope: a `local` declared in an earlier part is visible in later ones.
* **Order matters.** Adding/removing a part means updating `PARTS` in `loader.lua` too.
* Never put a top-level `return` in any part except `26_banner.lua` — it would end the joined chunk early.
* Keep a trailing newline on every part (they are concatenated directly).
* Atlanta widgets need a `button_holder()` row before `button()`, and keybinds/colourpickers can be chained onto a toggle or a `label` (both expose `right_holder`; a colourpicker can also be chained onto another colourpicker). `multi_section({ names = {...} })` accepts any number of mini-tabs.
* All 84 `CFG` keys used by the logic must stay bound to a UI widget; `python3 tools/verify.py` checks the join.

```bash
python3 tools/verify.py   # checks order, newlines, stray returns, build output
bash build.sh             # optional: make one self-contained dist/Hanami.lua
```

`build.sh` is only needed if you want a single paste-able file; the runtime loader does the same join automatically. `dist/` is gitignored.

---

Executor-only script (`Drawing`, `getgc`, `loadstring`, `getcustomasset`). Use in private/own places; running it in public experiences can violate Roblox's Terms of Use and get an account banned.
