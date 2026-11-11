# Hanami

`@abusegpt` suite — silent aim, wall penetration, player/NPC/crate ESP, entity scanner, aim snapline, ballistic prediction and gun mods — with an **Atlanta** UI.
The original 1,300-line script is split into **44 short files** (`src/`, largest is 819 lines) plus a short **loader** and a committed static/Fengari validation harness.

## Features only (no console output)

The loader is **silent**: no startup banner, no `print` / debug log, no Debug section, no Print / Scan / Self-Check buttons and no self-check panel. Every feature toggle, functional button and non-printing state API remains. `SA.SelfCheck()` still returns a report table for code that wants to inspect executor capabilities, and state APIs such as `SA.SelfCheckState()`, `SA.FustBowState()`, `SA.EspPerfState()`, `SA.HitboxState()`, `SA.DrawSyncStats()` and `SA.EspFrameBudget()` are still callable. The separate npm / Fengari harness still prints its own results. Nothing in `src/` calls `print()`, `warn()` or `dbg()`; errors stay inside `pcall` guards, `CFG.debug` and `CFG.gunDiffOnScan` are gone, and Visual keeps only feature sections (the two utility buttons live under **Utilities**).

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
| **Crate ESP FOV-aware** | ESP → Crate ESP | Default ON. Outside the aim circle = one dot; inside = name + distance and an outline-only `Highlight`. No boxes or corners. `SA.CrateFovState()`. |
| **100m player warning** | Visual → Nearest HUD | Fixed-threshold red crosshair badge when any other player is within 100 metres. No team filter. `SA.PlayerWarningState()` / `SA.PlayerWarningRefresh()`. |
| **Triggerbot / Auto Fire** | Aiming → Trigger / Auto Fire | **Fire Assist Wall Check** (`CFG.fireWallCheck`, default ON) requires a **VIS target in FOV** for both features; with it OFF Auto Fire clicks continuously without a target. Independent of silent aim's `CFG.wallCheck`; Manipulation Support cannot bypass it. Head Only, Random Hit Part, Specific Hit Part, Manipulation Support gate, `Tool:Activate()` first with `mouse1click` / `mouse1press` fallback and `SA.FireAssistState()`. |
| **Force Head (Silent Aim)** | Aiming → Target | Default ON override for Target Bone / Per-Weapon Bone, so silent aim resolves Head whenever the rig has one. `SA.ForceHeadState()`. |
| **NPC manipulation support** | Aiming → Manipulation | Default ON. NPC targets (Guard / Scavenger / Soldier, tagged or folder NPCs) now use the same six-slider peek / `CanQuery` wall bypass as players, with a dedicated **Manipulate NPCs** toggle, NPC-aware crosshair popup, `SA.IsNpcModel()`, `SA.ManipNpcState()` and an explicit `SA.ManipPossible(npcModel)` read-only probe. |
| **Clean ESP (outlines only)** | ESP → ESP Features | Default ON. Removes the dark tag pills and chams fill that covered the top of the screen; keeps a thin box outline, chams outline and black text stroke. `Apply Clean ESP` / `SA.CleanEspState()` and a one-click toggle are included. |
| **Manipulation crosshair popup** | Visual → Nearest HUD | Small READY / BLOCKED / OFF badge above `SA.AimPoint()` (the FOV/crosshair reference). `SA.ManipPossible()` is a read-only probe: it checks clear LOS, 8-direction peek and CanQuery wall bypass without spending the ray budget or changing `CanQuery`. Toggle and refresh controls included. |
| **BETTER quality-of-life pass** | all five tabs | See [BETTER quality-of-life pass](#better-quality-of-life-pass). Native config profiles, programmatic self-check state, real full unload, top-N HUD, all-keybind manager, ESP decluttering, aim/FOV UX, real-model side-by-side Preview, committed Fengari tests, adaptive performance and live gun tuning. |
| **Native Atlanta config profiles** | Misc → Config Profiles | Save / load / delete / export / import / reset / auto-load in Atlanta's own `configs` directory. Every `hn_*` flag (including keybind tables) round-trips through `library:get_config()` / `library:load_config()`. |
| **Programmatic self-check state** | `SA.SelfCheck()` | Returns a report table (checks / passed / warned / failed) covering executor capabilities, `hn_*` coverage, keybind conflicts, draw-write failures and a config round-trip. No panel, no button, no console output. |
| **Real full unload** | Misc → System | `SA.FullUnload()` bumps the generation, disconnects render/rebind/character hooks, destroys GUIs, restores camera / bow / manip state and clears shared globals. |
| **Top-N nearest-player HUD** | Visual → Nearest HUD | Up to five players with HP %, `VIS`/`WALL`, team, weapon, metres, corner / scale / transparency, live "why no target?" line and optional FPS / entity counts. |
| **All-keybind manager** | Visual → Keybinds | Rebind ANY key or mouse button, Escape = None, clear selected, hold / toggle / always for every bind, conflict detection and a complete keybind registry. |
| **ESP decluttering + live counts** | ESP → Declutter / Live Counts | Only Nearest N, Only Aim Target, team filter and per-kind on-screen counters. The nearest set is keyed by character model, so the current aim target always keeps a slot. |
| **Aim / FOV UX** | Aiming → Silent Aim / Target | Legit / Blatant / Sniper FOV presets, target priority, per-weapon bone, pin nearest, clear pin and an exact "why no target?" line. |
| **real-model, side-by-side ESP Preview** | floating ESP Preview | Pick Local Character / Nearest Player / Nearest NPC / Aim Target, clone real server models, and compare Player vs NPC ESP with the same live settings. |
| **Adaptive performance mode** | Visual → Performance Mode | FPS-aware rebuild pacing, entity cap, ScreenGui draw-pool reuse, rolling FPS, write-failure tracking, **baseline ESP FPS optimization + shared projection cache / camera signature / adaptive geometry slicing / priority slicing / disabled-ESP early-out** (coalesced GUI sync, throttled text refresh, cached rigs / VIS, off-screen skip) and an independent FPS / entity overlay. |
| **Live gun diff + overrides** | Gun Mods → Live Gun Tuning | Compare the 20-gun baseline with live GC data, register new-gun stubs and apply safe numeric per-gun overrides that survive every sync. |
| **RightShift is the default menu toggle** | Atlanta menu | See [Feature keybinds](#feature-keybinds). Atlanta ships `Insert` for its UI Bind; Hanami rewrites that one call to **RightShift** and moves the aim master to **Insert**, so both stay bound and never fire on the same press. The menu bind gets a real `hn_menu_bind` flag + Keybinds-panel row (**Toggle Menu**), so it can be right-clicked to `None` like every other bind. |
| **Five feature keybinds + None / right-click removal** | Aiming / ESP / Gun Mods | See [Feature keybinds](#feature-keybinds). **P** Player ESP, **N** NPC ESP, **G** Gun Mods, **B** Bow Mods, **M** Manipulation, plus the existing **Insert** aim and **RightShift** menu bind. Any keyboard key or mouse button can be bound; press **Escape** or **right-click** the key widget / Keybinds row to set **None** and remove it from the list without turning the feature off. |
| **Nearest-player HUD while the menu is hidden** | Visual → Nearest HUD | See [Nearest player HUD](#nearest-player-hud). A separate draggable window appears when you minimise / toggle off the Atlanta menu (RightShift) and shows the closest player's **username**, **distance in metres** (1 m ≈ 3.571 studs) and **held gun/tool**. It is deliberately outside `library.guis`, so hiding the menu cannot disable it. |
| **Tracer lines + off-screen arrows are player-only** | ESP → ESP Features | See [New ESP visuals](#new-esp-visuals-all-in-esp--esp-features). The shared toggles stay ON for players but NPC / crate ESP and the NPC ESP Preview never create those drawings. |
| **Every gun's attributes updated (20 guns)** | Aiming → Ballistics | See [Ballistic prediction](#ballistic-prediction). All 20 guns now carry `mag`, `spread`, `adsSpread`, `moveSpread`, `reload`, `recoil`, `rate`, `auto`, `s2Damage`, `scope`, `headGuard`, `shellReload`, `rocket`, `huntOnly` / `duelOnly` plus the new **Arena Rifle** (`duel_rifle` / `duel_ammo`) and the named `Falloff` table. The full per-gun attribute set lives in `SA.GUN_SPECS`; **Sync Gun Defs (GC)** refreshes every numeric field from the live game. |
| **Prediction auto-tunes for attachments** | Aiming → Attachments (Auto) | See [Attachments & auto prediction tuning](#attachments--auto-prediction-tuning). All 12 attachments are auto-detected off the equipped tool; a silencer re-tunes bullet speed (and therefore lead + drop), sights/grips fold aim-time into the one latency term, and the solver adds a refinement pass and stops on convergence. No manual toggle needed — slot overrides are provided as a fallback. |
| **Camera-snap resolver / gun manipulation are guns only** | Aiming → Gun | See [Bow mods](#bow-mods-instant-charge--no-cooldown). The v7.7 camera-snap / tap-fire resolver and gun manipulation skip bows; the dedicated, default-OFF Fust bow hook below handles ballistic arrows separately. |
| **Two bow mods: instant charge + no cooldown** | Gun Mods → Bow Mods | Only those two features from the pasted bow-mods script were ported — instant full draw and `SHOT_GAP`/`REDRAW_GAP`/`MIN_DRAW` + `lastShot` clearing. NoDrop, instant reload, no recoil, infinite ammo, no air block and everything else were **excluded**. See [Bow mods](#bow-mods-instant-charge--no-cooldown). |
| **V16.46-style Gun Mods + local Brightness** | Gun Mods / Visual → Utilities | All 12 `C.Gun` settings (`NoSpread`, `ShotProbe`, `InspectDefs`, `InspectScripts`, `InspectGunControl`, `InspectLiveGun`, `NoRecoil`, `CameraKickFilter`, `FireRate`, `FireRateMultiplier`, `InfiniteAmmo`, `MoveShoot`) plus a clamped 0–0.5 `ColorCorrectionEffect`. See [V16.46-style gun mods](#v1646-style-gun-mods-brightness-and-shot-probe). |
| **Hitbox Expander v2 (silent / R6-R15 / players + NPCs)** | Aiming → Hitbox Expander v2 | See [Hitbox Expander v2](#hitbox-expander-v2). Toggle + target / mode dropdowns and scale / cap / distance / team / alive / visibility controls, plus a default-ON **Expand NPC Hitboxes** switch. Live NPC registry models, **NPC HRP fallback**, self-healing Size hooks, reversible originals and accessory CanQuery restore. |
| **ESP 60 FPS frame-budget pass** | Visual → Performance Mode | See [ESP 60 FPS frame-budget pass](#esp-60-fps-frame-budget-pass). Time-based **60 FPS frame budget** is active with Performance Mode OFF, plus **per-property instance writes**, draw **usage marks**, hoisted helpers, direct box segments, `SA.EspGeometryBudget()` slicing, `SA.EspGeomState()` cache stats and `geometryStride` / `geometryBudget` in `SA.EspFrameBudget()`. `SA.EspFrameBudget()` exposes the frame budget to code. |
| **Fust bow ballistic silent aim + peek-origin wallbang** | Aiming → Fust Bow | See [Fust bow ballistic silent aim](#fust-bow-ballistic-silent-aim). Default-OFF `hookfunction` on `ReplicatedStorage.Fust.Remotes.Shoot.FireServer`: gravity-compensated arrow velocity, FOV target pick, 8-direction peek origin rewrite behind cover. Guns are untouched; hook restores on dispose / unload. |
| **ESP Preview actually works** | floating "ESP Preview" panel · ESP → Player ESP | See [ESP preview](#esp-preview). A real 3D `ViewportFrame` with your live box, corner boxes, name, distance, weapon/state, health bar, `VIS`/`WALL`, skeleton, head dot, tracer, chams tint and rainbow — all driven by `CFG` / `ESP_COLORS`. Now mirrors **either** the Player or NPC pipeline, including archetype colours. Survives spawn, respawn, re-execute and unload. |
| **Best ESP preset for Players + NPCs** | ESP → ESP Features · ESP Preview panel | See [Best ESP](#best-esp-players--npcs). One **Apply Best ESP** button enables the curated readable feature set for BOTH pipelines, and the preview gains **Preview Kind**, **Simulate Aim Target**, a visibility frame, per-tag colours, tag backdrops and an off-screen arrow. |
| **Player ESP works for every player** | ESP → Player ESP | See [Player ESP reliability fix](#player-esp-reliability-fix). The build queue no longer starves players behind failed builds, respawns rebuild, custom/streamed rigs resolve, and one bad character can't abort the whole refresh. A **Rebuild Player ESP** button clears the build queue after a big server change. |
| **Silent Aim v7.7 (tap-fire fixed)** | Aiming → Silent Aim / Gun | See [Silent aim v7.7 & manipulation v4](#silent-aim-v77--manipulation-v4). Render-step-only snapping is no longer the sole path: InputBegan / Tool.Activated connection reorder snaps the camera **before** the game fires, tap window widened to 0.35 s, and one shared shot resolver keeps the FOV circle as the reference point. **Guns only** — bows are skipped. |
| **Tahoma ESP layout (weapon below, flags at the corner)** | ESP → ESP Features | See [ESP text layout](#esp-text-layout-tahoma-weapon-below-flags-at-the-corner). Player/NPC/crate labels are now screen-space Tahoma `TextLabel`s anchored to the box geometry: name above, distance at the top-left corner, **weapon below the box**, and `VIS`/`WALL`, state and HP stacked beside the top-right corner. The world-anchored BillboardGui text is hidden so nothing is drawn twice. The floating ESP Preview mirrors the same layout. Clean ESP mode keeps the same labels but removes their dark background pills, leaving only text outlines. |
| **Classic manip sliders + recommendation back** | Aiming → Wall Penetration | See [Best settings for wall penetration](#best-settings-for-wall-penetration). Six sliders again — **Range 0–300 studs**, **Base Peek 4–6 only**, Parts 0–8, Budget 8–128, Hysteresis 0–12, Max Peek Delta 2–12 — and the old `75 / 4 / 3 / 64 / 5 / 6` recommendation button. The dead "Adaptive Peek Cap" is gone and every remaining slider has a real, clamped effect. |
| **Actually compiles in the executor** | loader | See [Luau 200-local-register fix](#7-the-luau-200-local-register-compile-error). The old join hit `Out of local registers ... exceeded limit 200` at `playerSec` and never ran. The loader now hoists column-1 `local`s into the chunk environment, so the main chunk needs zero local registers. |
| **FOV circle fixed + made the aim reference** | Visual → FOV Circle / Snapline | See [FOV fixes](#fov-fixes--one-reference-point). Now defaults ON, draws through a reliable ScreenGui backend, and its centre + radius are the single reference used by silent aim, snapline, tracers and arrows. |
| **Crate opened / unopened labels fixed** | ESP → Crate ESP | See [Crate state fixes](#crate-state-fixes). The inverted labels came from a Y-rotation destructuring bug plus false-positive state guesses. Added strict state parsing and an `Invert Crate State` toggle. |
| **No more ~3 s frame skip** | everywhere | See [Stability & fixes](#stability--fixes). One shared, yielding Workspace walker replaces both `GetDescendants()` scanners; GUI builds are capped; stale render loops disconnect on re-execute. |
| **One text-size slider for ALL ESP text** | ESP → ESP Features → Text Size | Scales name, distance, weapon, `VIS`/`WALL`, state and health % on players, NPCs **and** crates together, with row spacing derived from the same value. Plus `Show Health %`, `Text Outline`, `Tags On Box Side` and `Tag Backdrops` toggles. |
| **FOV circle actually shows** | Visual → FOV Circle / Snapline | `SA.NewDraw` falls back to real Roblox GUI Frames when the executor has no usable `Drawing` API; no longer gated on aim being ON; transparency slider now means what it says (0 % = solid). ON by default. |
| **Auto Ping Lead** | Aiming → Ballistics | Reads live `lp:GetNetworkPing()` (or `Stats.Network.ServerStatsItem["Data Ping"]`), smooths it, and feeds it into the ballistic solver. `Ping Scale` × ping + `Extra Ping Offset (ms)` = total extra lead. Old manual-only `Extra Lead` is now an offset on top. |
| **No stray crate Highlight** | ESP → Crate ESP | `Crate Chams Highlight` is **OFF** by default. Classification now requires a container-like Model/BasePart with a real crate signal, and the `Highlight` is bound to the crate's own anchor part only — never a whole folder of scenery. |
| **Skeleton / Head Dot / Tracer / arrows work** | ESP → ESP Features | All `Drawing.new` calls now go through the compatibility layer, and skeleton + head dot also render on crate ESP (a spine and a top marker). **Tracer lines + off-screen arrows are PLAYER-ONLY** — NPCs and crates never draw them. |
| **Off-screen arrows follow FOV (PLAYERS ONLY)** | ESP → ESP Features → Arrows Follow FOV | Arrows sit on the FOV circle perimeter using the **same centre and radius** as the drawn circle; change `Aim / Circle Radius` and the arrows move with it. Also points at on-screen targets *outside* the aim cone. Player ESP only. |
| **48 colourpickers** | ESP → Colours | One clearly-labelled picker for **every** drawn element (players, NPCs, crates, snapline, FOV, lead, target). All write into one shared `ESP_COLORS` table that survives re-execution. |
| **Customizable visibility colours** | ESP → Colours · Player / NPC | Green (clear LOS) / red (blocked) are now obvious labelled pickers, not tiny swatches buried on unrelated toggles. They paint an outer frame, a visibility dot and the `VIS` / `WALL` tag even when per-element colours are on. |
| **Ballistic prediction** | Aiming → Ballistics | Replaced the old one-step `distance/speed` guess with an exact quadratic intercept solve using each gun's real `speed`, bullet drop, alt ammo, live ping and range. See the next section. |
| **Player visibility check** | ESP → Player ESP | Box, name, fill and the `VIS` / `WALL` corner tag turn **green when there is a clear line of sight** and **red when a wall blocks it**. Cached camera raycast (~120 ms). |
| **FOV snapline** | Visual → FOV Circle / Snapline | Line + dot to the target, **green = visible, red = blocked**, plus a gold **lead ring** at the exact point the solver aims at. |
| **NPC silent aim / NPC ESP** | Aiming + ESP | `pickBestTarget` selects from players **and** the NPC registry. Separate section for `Guard`, `Scavenger`, `Soldier`, with name/distance/health box, visibility colours and scanner options. |
| **Entity scanner** | ESP tab + Misc | Reads an equipped `Tool`, `ItemId` / `Weapon` / `HeldItem` attributes and weapon containers, plus `Downed` / `Knocked` / `Dead` / `State` attributes with a `HumanoidStateType` fallback. `Show Weapon` and `Show State` are options on **both** player and NPC ESP; `VIS` / `WALL` is a third tag. |
| **Wall-pen description** | Aiming → Wall Penetration + below | Tooltips, three in-UI labels, and a one-click **Apply Recommended Wall Pen** button. |

NPC detection accepts the literal model names `Guard` / `Scavenger` / `Soldier`, the common `Scavenger`/`IsNpc`/`NPC` attributes, and models inside `Npcs` / `Enemies` folders. Real player characters are explicitly excluded.

## BETTER quality-of-life pass

This pass implements the eleven highest-value ideas from the previous audit. It is a UI / reliability upgrade, not a change to the guns-only silent-aim or two-bow-mods scope.

### Native Atlanta config profiles

Misc → **Config Profiles** uses Atlanta's own `Atlanta/configs` directory and `library:get_config()` / `library:load_config()`, so the built-in Configurations list stays in sync. Save, load, delete, export to clipboard, import from clipboard, reset to shipped defaults and auto-load the last profile are all native. `SA.ConfigCoverage()` reports any unbound `hn_*` flag; `SA.TestConfigRoundTrip()` proves the serialised flag snapshot is stable, including keybind `{mode, key, active}` tables and colour pickers.

### Programmatic self-check state

`SA.SelfCheck()` returns a report table (`checks` / `passed` / `warned` / `failed`) covering the render loop, FPS, local character, camera, executor capabilities (`gethui`, `getgc`, `setreadonly`, `getconnections`, `hookfunction`, filesystem / clipboard), drawing backend, write failures, ESP objects, 48 colours, UI flags, `hn_*` coverage, keybind registrations / conflicts, every state API, draw pool, nearest HUD, no-target reason and a config round-trip. `SA.SelfCheckState()` returns the last report. There is no panel, no button and no console output: static checks still cannot prove an executor's real globals, so in-game verification remains manual.

### Real full unload

Misc → **System → Unload Everything (FULL)** calls `SA.FullUnload()`. It disables features, disconnects `RenderStepped` / rebind / preview / character hooks via the generation guard, restores camera / manipulation / bow timings, destroys the Atlanta window, nearest HUD, FPS overlay and ESP Preview, and clears `_G.__saShared`, `_G.__saCFG`, ESP object tables and generation-specific GUI state. A loader re-execute after a full unload starts fresh instead of inheriting stale loops.

### Top-N nearest-player HUD

Visual → **Nearest HUD** expands the hidden-menu companion window to 1–5 players. Each row can show HP %, `VIS`/`WALL`, teammate / enemy, held tool and distance in metres. Corner, scale, transparency, live "why no target?" and FPS / entity lines are configurable. The HUD remains outside `library.guis`, so `window.set_menu_visibility(false)` cannot disable it.

### All-keybind manager

Visual → **Keybinds (All 7)** exposes every wrapped bind: menu, aim master, Player ESP, NPC ESP, Gun Mods, Bow Mods and Manipulation. Rebind accepts any `Enum.KeyCode` or `UserInputType` (mouse buttons included); Escape / right-click / **Clear Selected** set `None` without switching the feature off. **All Binds Mode** changes hold / toggle / always without firing feature callbacks, and `SA.KeybindConflicts()` lists shared keys. The wrapper is now re-execution safe: original library methods are captured in a private scope instead of hoisted globals.

### ESP decluttering

ESP → **Declutter / Live Counts** adds Only Nearest N, Only Current Aim Target, team filtering and optional live player / NPC / crate counters. `SA.EspPassAllowed()` uses a per-frame set keyed by character model (matching what the FX pass actually passes), and the current aim target always keeps a visible slot. `SA.EspPassStats()` reports exactly what the styling pass drew.

### Aim / FOV UX

Aiming gains **FOV Preset** (Custom / Legit / Blatant / Sniper), **Target Priority** (Crosshair / Nearest / Lowest HP / Pinned), **Per-Weapon Bone**, **Pin Nearest Player** and **Clear Pinned Target**. `SA.ResolveTargetBone()`, `SA.PinNearestTarget()`, `SA.PinnedTarget` and `SA.NoTargetReason()` keep the UI, snapline preview and shot resolver on the same rules.

### real-model, side-by-side ESP Preview

The floating Preview can clone a **real-model** source: Local Character, Nearest Player, Nearest NPC or Aim Target. **Side-by-side Player vs NPC** builds a second server-model clone with its own overlay set, shifts the two models to x ± 2.4, widens the orbit camera to 11 studs and rebuilds whenever source / kind / compare changes. `pv.ui2`, `pv.model2` and both part lists are disposed on rebuild and unload. `pv.styleErr` is cleared only on a successful styling pass.

### NPC manipulation support

Aiming → **Manipulation → Manipulate NPCs** is ON by default. When the selected target is an NPC, the existing classic resolver applies the same 8-direction wall peek, `CanQuery` part bypass, ray budget, cache, range and six sliders used for player targets. No NPC-only ray path, extra budget or separate prediction path is introduced. Target selection already had **Target NPCs**; this pass makes the resolver, read-only probe, popup and state checks explicitly NPC-aware.

`SA.IsNpcModel(model)` prefers `SA.GetNpcs()` (the shared incremental Workspace walker), falls back to the literal `Guard` / `Scavenger` / `Soldier` names, `Scavenger` / `IsNpc` / `NPC` attributes and `Npcs` / `Enemies` folders, and rejects anything returned by `Players:GetPlayerFromCharacter()`. `CFG.manipNpcs` is backfilled and clamped like the other new settings. With **Manipulate NPCs** OFF, an NPC shot keeps the original camera origin: no peek is cached and no `CanQuery` write occurs. **Target NPCs** OFF also disables NPC manipulation.

`SA.ManipPossible(npcModel)` accepts an optional explicit model override for diagnostics; without it, the popup still uses the normal FOV/crosshair picker. NPC-aware results are tagged `[NPC]` and the badge reads `MANIP NPC: READY` / `BLOCKED` / `OFF`. `SA.ManipNpcState()` reports the toggle, NPC targeting, registry count, effective range / peek / parts and whether the last real resolver target was an NPC. The probe remains read-only: no `CanQuery` writes, no peek-cache entry and no manipulation ray-budget consumption.

### Crate ESP FOV-aware

**FOV-Aware Crate ESP** is ON by default. It uses the same `SA.AimPoint()` / `SA.FovRadius()` circle as silent aim: a crate outside the circle becomes one small dot at its screen position, while a crate inside the circle shows only its name and distance plus an outline-only `Highlight`. The FOV-aware branch returns before box, corner, fill, skeleton, visibility-dot or off-screen-arrow drawing, so it does not add corners or full boxes. `CFG.crateHighlight` only controls the old non-FOV-aware path. `SA.CrateFovState()` reports the radius, centre, inside/outside counts, dots and outline highlights.

### 100 m player warning

Visual → **Nearest HUD → 100m Player Warning** is ON by default. Any other player within **100 metres** (1 m ≈ 3.571 studs) triggers a small red badge above the crosshair with the nearest player's name and distance. It is a fixed threshold with no team filter, updates at ~10 Hz and follows `SA.AimPoint()`. `SA.PlayerWarningState()`, `SA.PlayerWarningRefresh()` and `SA.PlayerWarningSet()` are the state API. The popup is disposed on re-execute and `SA.FullUnload()`.

### Triggerbot / Auto Fire

Aiming → **Trigger / Auto Fire** adds two independent, default-OFF features. **Triggerbot** clicks only when `SA.TriggerTarget()` finds a valid target inside the FOV circle. **Auto Fire** clicks continuously at about 12.5 Hz; both respect the existing gun cooldown and are **silent-aim independent**: only `SA.Alive` and the guns-only bow gate apply, not `CFG.masterEnabled` / `CFG.gunEnabled`.

**Fire Assist Wall Check** (`CFG.fireWallCheck`) is a dedicated, **default-ON** toggle in the same section. It is completely independent of silent aim's Gun → **Wall Check** (`CFG.wallCheck`). With it ON, Triggerbot and Auto Fire both require a **VIS target in FOV** from the existing FOV / player / NPC target picker, using tolerant `SA.IsVisible()` — the same LOS helper behind the ESP **VIS** tag — so a **VIS player in FOV** is not rejected by a strict ray clipping a hat or accessory. **Manipulation Support cannot bypass this gate**: it may still block via `SA.ManipPossible()`, but a non-VIS target never fires. With it OFF, Auto Fire returns to continuous / no-target clicking (including when both features are ON) and Triggerbot may shoot through walls; `SA.FireAssistState().visible` still reports the ESP VIS status honestly. `SA.FireAssistState()` also exposes `wallCheck` and `autoFireGated`.

`SA.FireOnce()` tries `Tool:Activate()` first, then falls back to `mouse1click()` and `mouse1press()` / `mouse1release()`. Each Triggerbot shot briefly snaps the camera to its chosen aim point and restores it immediately afterwards. Auto Fire never adds a camera snap or aim point, even when the wall check gates its clicks.

Hit-part selection is independent of silent aim: **Head Only** is ON by default, **Random Hit Part** wins when enabled, and the **Hit Part** dropdown offers Head / Hrp / UpperTorso / LowerTorso / arms / legs / Random with R6 + R15 name aliases. **Manipulation Support** is a strict gate: when ON, `CFG.manipulation` must be ON and `SA.ManipPossible(model, true)` must report READY. The `allowNoAim` flag keeps the identical read-only line check without inheriting silent aim's master/gun gate. `SA.TriggerBonePart()`, `SA.TriggerTarget()` and `SA.FireAssistState()` expose VIS status, backend, reason, wall-check state and silent-aim independence; full unload disposes the render bind.

### Silent aim Force Head

**Force Head (Silent Aim)** is ON by default. `SA.ResolveTargetBone()` now returns `Head` before the classic Target Bone dropdown or `Head for snipers` / `Hrp for shotguns` per-weapon modes can select HumanoidRootPart, which was the cause of intermittent non-head shots. Turning the toggle OFF restores the previous per-weapon logic. `SA.ForceHeadState()` and `SA.SilentAimState().forceHead` report the effective bone. Triggerbot / Auto Fire part modes stay separate and never override silent aim's Force Head setting.

### Hitbox Expander v2

**Enable Hitbox Expander** (Aiming → Hitbox Expander v2) is a standalone, default-OFF feature. It covers **R6/R15 player rigs and live NPC models**: `Head`, `UpperTorso`, `LowerTorso` and R6 `Torso`, selected by the **Target Parts** dropdown (`Head` / `Torso` / `Both`). Player scope is unchanged; **Expand NPC Hitboxes** is ON by default. It is **silent** by default — the only visual change, when **Show Expanded Parts (client only)** is ON, is `LocalTransparencyModifier = 0.55`, which never replicates to other clients.

Controls and their `CFG` keys:

| Control | Key | Default | Effect |
|---|---|---|---|
| Enable Hitbox Expander | `hitboxEnabled` | OFF | Master switch; `H` keybind |
| Target Parts | `hitboxTarget` | `Both` | `Head` / `Torso` / `Both` |
| Scale Mode | `hitboxMode` | `fixed` | `fixed` = uniform cube in studs; `multiply` = original size × Scale |
| Scale (studs / x) | `hitboxScale` | 8 | 1–30; cube side or multiplier |
| Multiply Cap (studs) | `hitboxCap` | 8 | 1–30; largest-axis cap in `multiply` mode |
| Max Distance (0 = unlimited) | `hitboxMaxDist` | 300 | 0–2000 studs; skip distant characters |
| Team Check | `hitboxTeamCheck` | ON | Skips `SA.IsTeammate()` / same-`Team` players; NPCs are neutral and never filtered |
| Alive Only | `hitboxAliveOnly` | ON | Skips dead Humanoids |
| Show Expanded Parts | `hitboxVisible` | OFF | Client-only faint tint |
| Expand NPC Hitboxes | `hitboxNpcs` | ON | Expands live NPC registry models; OFF restores NPC originals while player hitboxes stay expanded |

Every affected part gets `CanCollide = false`, `CanTouch = false`, `CanQuery = true`, and an instant `GetPropertyChangedSignal("Size")` hook that re-applies the target size if the server reverts it — the **self-healing** 1–2 frame window. Hat / hair `Accessory` Handles are set `CanQuery = false` so they cannot eat the raycast. All originals (size, collision/query/touch flags, transparency modifier and accessory `CanQuery`) are saved in `_G`, so turning the toggle OFF, **Restore Hitboxes**, or **Unload Everything (FULL)** puts every value back and disconnects the hooks. `getgenv().hitbox` is still published for compatibility with the pasted script's global table; `getgenv().hitbox.npcs` mirrors the NPC switch.

**NPC support** uses the same live registry as NPC ESP: `SA.HitboxScan()` walks the `SA.NpcListRaw()` raw list on the existing generation-guarded `bindRender` pass, with no second loop or per-frame filtered copy. NPC models keep the same Target Parts / Scale Mode / Scale / Cap / Max Distance / Alive Only / Show Expanded Parts controls; **Team Check** applies to players only. An NPC with no `UpperTorso` / `LowerTorso` / `Torso` uses **NPC HRP fallback** (`HumanoidRootPart`) as its torso proxy. NPC-owned sizes, collision / query flags, tint, accessory `CanQuery`, Size hooks and `ChildAdded` hooks are tagged separately: turning **Expand NPC Hitboxes** OFF, removing an NPC from the registry, turning the master OFF, **Restore Hitboxes**, or **Unload Everything (FULL)** restores those originals without touching expanded player parts.

`SA.HitboxScan()` forces one pass, `SA.HitboxRestore()` restores all originals, `SA.HitboxState()` reports every setting plus `npcs` / `npcParts` / `npcModels` / tracked parts / accessories / hooks / scans. The main loop uses the generation-guarded `bindRender` instead of a raw Heartbeat connection, and `table.clear` was replaced with a portable clear loop so the split parts stay Lua 5.3 / Fengari-safe. Validation covers player + NPC scope, fixed / multiply / cap, target and distance filters, team / alive gates, NPC HRP fallback, self-healing, accessory silencing, NPC-toggle restore, OFF restore and full unload; see [Testing](#testing).

### Clean ESP (outlines only)

The screenshot-style ESP showed large dark pills behind every name / state / weapon tag. **Clean ESP** is now ON by default. It removes dark tag backdrops and chams fill, and uses **outlines only**: a thin full box outline, a chams outline and a black text stroke. Corner boxes, skeleton, head dot, tracers, off-screen arrows, rainbow and distance fade are switched off by the `Apply Clean ESP` preset, so the view is no longer covered by stacked rectangles.

`CFG.espCleanMode` uses **effective values** in `src/18_esp_fx_draw.lua` and the floating ESP Preview: an older saved profile with `espTagBackdrop = true` / `espShowFill = true` still renders clean until the user explicitly turns **Clean ESP (outlines only)** OFF. `SA.ApplyCleanEsp()`, `SA.CleanEspState()` and **ESP → Apply Clean ESP** expose the preset; **Apply Best ESP** deliberately turns clean mode OFF for users who want the busy curated look. `SA.CleanEspState()` reports the clean-mode state.

### Manipulation crosshair popup

Visual → **Nearest HUD → Manip Crosshair Popup** adds a small badge just above the crosshair. It follows `SA.AimPoint()` (mouse or screen-centre, the same reference as the FOV circle) and reports whether bullet manipulation can currently find a shot:

- `MANIP: READY` — clear line, successful peek or a CanQuery wall bypass;
- `MANIP: BLOCKED` — wall blocked with no peek / wall-bypass path;
- `MANIP: OFF` / `NO TARGET` / `BOW` / `RANGE` — exact reason manipulation is unavailable.

`SA.ManipPossible()` is a **read-only probe**. It uses a private `RaycastParams`, reuses the same target picker and prediction as the shot resolver, and never calls `saManipResolve()`: no `CanQuery` writes, no peek cache entry and no manipulation ray-budget consumption. The popup updates at ~10 Hz through a generation-guarded `bindRender`, is disposed on re-execute and `SA.FullUnload()`, and is covered by `SA.SelfCheck()`. `SA.ManipPopupState()` / `SA.ManipPopupRefresh()` / `SA.ManipPopupSet()` are the state API.

### V16.46-style gun mods, brightness and shot probe

The old seven-toggle GC gun mods are gone. The replacement keeps the Hanami parts architecture and ports all 12 V16.46 `C.Gun` settings: `NoSpread`, `ShotProbe`, `InspectDefs`, `InspectScripts`, `InspectGunControl`, `InspectLiveGun`, `NoRecoil`, `CameraKickFilter`, `FireRate`, `FireRateMultiplier`, `InfiniteAmmo` and `MoveShoot`. `gmEnabled` remains the master switch and **G** keybind. No whole-script replacement, firing remote, RNG hook, function replacement or protected source read was added.

Brightness is a single local `ColorCorrectionEffect` named `HanamiLocalBrightness` under `Lighting`, clamped 0–0.5, with `Contrast` / `Saturation` zeroed and a white tint. It does not write global `Lighting` properties, character state or weapon state, and is destroyed on disable / `SA.FullUnload()`. `SA.GunDisplayState()` reports the effect, applies, disposals and the clamped value.

`Fust.Items` identity matching, `GunControl` export inspection, visible fire-controller script hints, a one-time source-attributed `getgc` / `debug.getupvalues` controller scan, equipped-Tool named fields, GunControl exports and definition records all contribute strong-keyed originals. Only explicitly named client-local spread, recoil, fire-rate, ammo and movement-permission fields are held. OFF, Disable All and `SA.GunDispose()` restore the cached originals. `SA.GunState()`, `SA.GunLiveReport()`, `SA.GunDefinitionReport()`, `SA.GunControlReport()`, `SA.GunFireScriptReport()`, `SA.GunInspectDefinition()`, `SA.GunObservationBaseline()` / `SA.GunObservationCompare()` and `SA.GunCopyReport(name)` are callable state / clipboard APIs; no report is written to console output. Candidate lists and reports are explicitly **hints only and UNVERIFIED**.

`ShotProbe` observes local visual tracer effects (motion, part axis and beam axis), keeps separate OFF / ON groups, needs 8 motion samples in both groups for a paired visual comparison, and retains completed observations across observer pause / re-execute in the same game session via a validated `_G` checkpoint. **Reset Shot Comparison** clears them. The shot probe never claims bullet spread, hit, damage or server acceptance verification; its verdict says `VISUAL effects only; zero spread on actual bullets NOT verified`.

`CameraKickFilter` is an experimental late upward-pitch correction armed only with `NoRecoil`; it may restrict manual upward aim. All gun-mod frame work, brightness re-application, held-fire polling, pending tracer processing and the camera filter share the existing master `RenderStepped` callback through `SA.GunFrame(dt, now)` — no second render loop was added.

### Committed Fengari validation suite

`npm ci && npm test` runs `build.sh`, `tools/verify.py`, `tools/check.js` and `tools/run.js`. `tools/mocks.lua` models Roblox datatypes, Instances, services, executor filesystem / clipboard, Atlanta widgets / config flags / keybinds and a controllable RenderStepped pump. `tools/tests.lua` executes 3,521 assertions over three runs: fresh startup, auto-load + re-execute, and re-execute after `SA.FullUnload()`, including **NPC hitbox coverage** (players stay in scope, live NPC registry rigs, HRP fallback, filters, self-healing, toggle OFF restore and full unload), Hitbox Expander fixed / multiply / cap / filters / self-healing / restore coverage, dedicated fire-assist wall-check / both-enabled / no-bypass regressions and ESP FPS optimization / coalesced GUI sync / throttled data refresh / ESP 60 FPS frame budget / per-property instance writes / draw usage marks / shared projection cache / camera signature / adaptive geometry stride / teammate-map throttle / disabled-ESP hidden-pass / Atlanta font-bootstrap sanitizer / Fust bow hookfunction / ballistic velocity / peek-origin wallbang / bow-spec / LOS / dispose / full-unload restore regressions. `tools/check.js` parses every source / tool / loader / dist chunk with luaparse, checks the 44-part list, zero column-1 locals in the hoisted bundle, one final `return`, README row / line counts, and shipped-default / backfill / clamp / bound-widget coverage for all 73 new CFG keys, plus a static assertion that no `src/` part calls `print()` / `warn()` / `dbg()` and no print/debug UI survives in the bundle. This is static + Fengari mock validation, **not a real Roblox executor** confirmation.

### Adaptive performance mode

Visual → **Performance Mode** paces new ESP builds by rolling FPS, caps styled entities per frame, reuses hidden ScreenGui drawing proxies through `SA.DrawPool`, tracks native write failures and can show an independent `HanamiPerfOverlay` FPS / entity HUD. `SA.PerfState()`, `SA.PerfEffectiveRebuildMs()`, `SA.PerfEffectiveEntityCap()`, `SA.DrawPoolStats()` and `SA.DrawWriteFailures()` are wired into `SA.SelfCheck()` and the state checks. The baseline **60 FPS frame budget** is active even with Performance Mode OFF; see [ESP 60 FPS frame-budget pass](#esp-60-fps-frame-budget-pass). `SA.PerfState()` additionally exposes `geometry`, `geom` and `esp` so the adaptive geometry budget / cache / rolling FPS state can be inspected without console output.

### ESP FPS optimization pass

ESP dropped frames because the legacy BillboardGui refresh and the unified FX pass repeated the same rig lookups, `WorldToViewportPoint` calls, visibility probes, string formatting and drawing writes **every frame**, while every property write on a ScreenGui proxy triggered a full GUI sync. The baseline path is now optimized even with Performance Mode OFF:

* ScreenGui proxy writes are **coalesced** into one sync per dirty draw by `SA.DrawSyncFlush()` at the end of each render callback. A hide → show toggle inside one frame collapses to its final value, so no redundant Roblox Instance writes are made. `SA.DrawSyncStats()`, `SA.DrawSyncPending()` and `SA.DrawDiag()` report writes, flushes, batches and saved syncs.
* Name / weapon / state / distance text and the legacy BillboardGui lines refresh at `espDataRefreshMs` (default **100 ms**, exposed as **ESP Text Refresh** in Visual → Performance Mode). `SA.EspDataIntervalFrames()` converts it to frames; a new build forces an immediate refresh. Priority box geometry still updates every frame; slow frames slice only low-priority entities, so active targets never freeze.
* Cached player / NPC rigs and `o.vis` are shared between the refresh and FX passes. The old O(n²) teammate loop is a one-pass character → teammate map, and the nearest-N sort is throttled to the same data interval. Off-screen entities with tracers / arrows / crate FOV dots OFF are skipped entirely.
* The render queue iterates `SA.NpcListRaw()` / `SA.CrateListRaw()` **raw list** views instead of allocating filtered copies every frame. `SA.EspPerfState()` exposes FX passes, data refreshes, skips and draw-sync savings.

These changes preserve the ESP visuals and every existing toggle. They reduce CPU work rather than hiding entities: the optional entity cap still belongs to Performance Mode. The newer adaptive geometry slicing and shared geometry cache are documented below.

### ESP 60 FPS frame-budget pass

The 60 → 30 FPS case still had three hot-path costs: every FX entity hid and re-showed all of its draws, the unified styling function allocated three closures plus several geometry tables per entity per frame, and a coalesced proxy flush rewrote every Roblox Instance property even when only `Position` changed. This pass targets a **60 FPS frame budget** without forcing Performance Mode ON or turning any ESP feature off:

* `SA.EspFrameBudget()` / `SA.EspFrameBudgetReset()` expose the **frame budget**. When `RenderStepped` delivers a frame slower than 16.7 ms, new ESP builds and crate refreshes are paced and the text refresh interval is stretched; priority box geometry still renders every frame while low-priority entities may rotate through adaptive geometry slicing. `SA.EspPerfState()` reports budget / build skips and `geometryUpdates` / `geometrySkips`.
* GUI proxies and real ESP Instances now use **per-property instance writes**: `SA.ApplyInstProp()` and `SA.DrawSyncReset()` track the last applied value for each property, so unchanged `Color` / `Text` / `Size` / `Visible` / `Transparency` values are skipped instead of rewritten every frame. `SA.DrawSyncStats()` reports `instanceWrites` / `instanceSkips`.
* Per-frame draw **usage marks** hide only draws that were not used, eliminating the hide → show write pair on every visible element. `src/18_esp_fx_draw.lua` hoists its colour / text / line helpers, writes box and visibility-frame segments directly, and reuses fallback text tables, cutting per-entity garbage-collection churn.

This is a CPU/work-smoothing pass, **not a guarantee** that Roblox's own renderer or every executor will hold 60 FPS. It preserves the ESP visuals and all existing toggles; the optional entity cap still belongs to Performance Mode. Real FPS must be checked in-game; `SA.SelfCheck()` returns the current FPS state to code.

### Loader / Atlanta UI font bootstrap fix

The 44-part loader is the only file to execute. dist/Hanami.lua is gitignored and is not on GitHub; the repository's **branch-specific loader URL** is `https://raw.githubusercontent.com/vornecc-pixel/Hanami/refs/heads/arena/bb927757-hanami/loader.lua`. The default branch (`Fuck-Nigga`) only contains `README.md`, so a generic `/main/loader.lua` or `/Fuck-Nigga/loader.lua` returns 404.

`src/21_ui_aiming.lua` fetches the Atlanta UI library from `ATLANTA_ROOTS` (raw GitHub plus a `github.com` fallback). The upstream library bootstraps a custom TTF from `weasely111/beta`, a **dead external font asset** whose repo now returns 404. On executors that reject `getcustomasset()` on that HTML payload, the library aborts before `library:window()` and the whole script appears not to load. The committed **Atlanta source sanitizer** `SA.SanitizeAtlantaSource()` removes that bootstrap, guards `makefolder`, and installs a **built-in Roblox FontFace** from `rbxasset://fonts/families/SourceSansPro.json` (with `Font.fromEnum` / `Font.new` fallbacks) before `loadstring` compiles the library. No console output is added.

The outer loader rejects any fetched part whose source contains literal HTML / 404 strings. To avoid self-rejection, the sanitizer builds its detection strings at runtime (`"<!DOC" .. "TYPE"`, `"<" .. "html"`, `"404" .. ": Not Found"`); `tools/check.js` enforces that no `src/` part contains those literal **error-page markers**. The Fengari mocks stub the external library load, so this fix also adds direct sanitizer regressions; real executor behaviour still needs an in-game check.

### Adaptive ESP geometry slicing and cache

The ESP hot path now shares one `WorldToViewportPoint` projection set between the throttled BillboardGui refresh and the unified FX pass. `SA.EspGeom()` keys the **geometry cache** by a cached entity root / head anchor, a per-frame **camera signature** (camera CFrame position / look / up / Euler fallback, viewport and FieldOfView) and ESP kind. Static crates keep their `geomAnchor` for their whole lifetime; a static camera and rig produce `cacheHits` instead of three fresh `w2vCalls` per entity per frame. `cameraKeyBuilds` counts signature rebuilds — one per camera change, not one per entity. `SA.EspGeomState()` reports `cacheHits`, `cacheMisses`, `w2vCalls`, `savedW2vCalls` and `cameraKeyBuilds`; `SA.EspGeomReset()` clears the counters, `SA.EspGeomInvalidate()` drops cached projections / anchors / the camera signature, and `SA.DisposeEspFx()` clears cached geometry on disposal.

`SA.EspGeometryBudget()` adds **adaptive geometry slicing**. A healthy frame has `geometryStride = 1` and styles every entity. A slow frame raises `geometryStride` up to 4 and styles only a rotating bucket; the aim target and nearest-N entities keep **priority** full-rate styling, while low-priority entities rotate. Skipped entities keep their last frame's pooled draws and legacy lines, are counted from cached data, and crate FOV counters are maintained from cached screen points without new W2V calls. `SA.EspPerfState()` exposes `geometryUpdates`, `geometrySkips`, `geometryHiddenPasses`, `geometryBudget` and `geom`. `SA.EspFrameBudget()` also carries `geometryStride`, `geometryBucket`, `geometryFps`, `geometryLastDtMs` and a nested `geometryBudget` table; `SA.PerfState()` exposes `geometry` and `geom`. The current frame's dt is authoritative and **rolling FPS only** biases stride when **Performance Mode is explicitly ON**, so a stale FPS sample cannot slice a healthy frame.

The teammate map is rebuilt once per data interval instead of every FX frame, the aim-target lookup no longer scans all player objects, `safeDrawEntity` inlines **one fewer pcall** per entity, and `rainbowColor` uses a per-frame **rainbow clock** instead of calling `tick()` for every colour lookup. A **disabled ESP early-out** hides each object list once instead of walking every object and recomputing aim / FOV / nearest data every frame while Player ESP, NPC ESP and Crate ESP are all OFF; `SA.EspHiddenPass` records the one-shot hidden pass. Performance Mode remains optional: slicing is active only when a frame is already over budget, and no second RenderStepped loop, forced `perfMode`, deleted visual or whole-script replacement was added.

`tools/tests.lua` adds static-camera cache-hit / zero-extra-W2V / camera-invalidation / camera signature / teammate-map throttle / slow-frame `geometryStride` / hidden-pass regressions. This is a CPU / work-smoothing pass, **not a guarantee** of real in-game FPS. `npm test` coverage is static + Fengari mock validation only; real frame pacing must be checked in Roblox. The existing ESP visuals, toggles, profiles, keybinds, gun mods and Fust bow features are preserved.

### Live gun diff + overrides

Gun Mods → **Live Gun Tuning / Overrides** snapshots the shipped 20-gun baseline, reports added guns and changed numeric fields after `SA.SyncGunDefs()`, registers safe stubs for new live guns, and accepts `gun_id.field=value;...` manual overrides. Overrides are re-applied after every GC sync and only numeric ballistics fields are accepted, so a typo cannot corrupt another spec table.

## Stability & fixes

### 1. The periodic ~3 second freeze

Five separate causes were stacking up:

* The NPC scanner called `Workspace:GetDescendants()` every **2 s** and the crate scanner called it again every **1.5 s** — a single synchronous full-workspace snapshot on a big map freezes the render thread.
* `SA.RefreshCrates()` / `SA.RefreshNpcs()` ran that same full scan **inline** when enabling an ESP, clicking a Rescan button, or on `DescendantAdded`.
* Dozens of `BillboardGui` / `Highlight` / `Drawing` instances could be created in one frame.
* Re-executing the loader left **duplicate `RenderStepped` loops** from the previous run still connected.
* The gun-mods `getgc(true)` loop ran every 1 s with a 3 000-iteration yield budget.

**Fix:** `src/02_workspace_scan.lua` is now the *only* workspace walker in the script. It does a breadth-first traversal via `GetChildren()`, inspects at most **120 nodes per frame** and then `task.wait()`s — no `GetDescendants()` anywhere in a loop. Both the NPC and crate registries register a `predicate` + `commit` callback with `SA.RegisterScanHandler`, and `SA.RequestScan()` only queues an early pass. `src/19_render_loop.lua` caps new GUI builds at **2 per ESP type per frame** and refreshes crates at ~20 Hz. `bindRender()` in `src/01_config.lua` binds every `RenderStepped` callback with a generation guard, so old loops disconnect themselves. The bow-mods GC scan is generation-guarded and yields every 1 000 objects; V16.46-style live-controller discovery is one bounded, source-attributed pass with explicit refresh only.

`SA.WorkspacePass()` reports the number of completed passes; `SA.DrawBackend()` / `SA.DrawDiag()` report the drawing backend.

### 2. FOV circle / skeleton / head dot / tracer / arrows not appearing

Every one of those is a `Drawing` object. Executors that expose a partial (or no) `Drawing` API fail `Drawing.new(...)` inside a `pcall`, and the visual silently disappears — while the crate `BillboardGui` text still renders, which is exactly the symptom in the screenshot.

**Fix:** `src/02_drawing.lua` probes native `Drawing.new("Line")` once, checking that `Visible`, `Color`, `Transparency`, `Thickness`, `From` and `To` are actually writable. If that fails (or `Triangle.PointA` isn't writable), `SA.NewDraw(kind)` returns a proxy backed by real Roblox `Frame`s inside a `HanamiOverlay` ScreenGui (CoreGui → PlayerGui → `gethui()`). The proxy implements the exact same `Line` / `Circle` / `Triangle` property interface plus `Remove()`. All five direct callers (`10_fov_circle.lua`, `11_snapline.lua`, `12_esp_players.lua`, `14_esp_npcs.lua`, `18_esp_fx_colours.lua`) now use `SA.NewDraw`.

The FOV circle also had three logic bugs: it was gated on `CFG.masterEnabled`, `fovTransparency = 0` produced `Transparency = 1` (fully invisible), and a dead draw object was never recreated. All fixed; `showFov` now defaults to **true**.

### 3. Extra Lead auto-adjusts to live ping

`src/08_prediction.lua` adds `SA.GetPing()` (0.25 s cached, exponentially smoothed, clamped 0–1000 ms) and `SA.LeadLatencyMs()`:

```
total extra lead (ms) = (auto ping × Ping Scale) + Extra Ping Offset
```

`GetNetworkPing()` returns seconds so it is ×1000; the legacy `Data Ping` value is already milliseconds (both `GetValue()` and a numeric/string `Value` are handled). `Auto Ping Lead` is **ON** by default, `Ping Scale` defaults to **1.0** (full round-trip time — set it to **0.5** if you want one-way latency instead), and the old manual `Extra Lead (ping ms)` slider is now `Extra Ping Offset (ms)` added on top. `SA.GetPing()` / `SA.LeadLatencyMs()` report the measured ping and resulting total. The solver adds this **once** as `tTotal = flightTime + latency`, never once per iteration.

### 4. Highlight on unrelated objects when Crate ESP is ON

The loose classifier accepted *any* instance with an `Opened` / `Looted` attribute (doors, scenery, whole `Loot` folders), and the `Highlight` was parented to the model with `Adornee` set to the whole model.

**Fix:** `crateKind()` now requires `Model` or `BasePart`, excludes player characters / humanoids / our own `Hanami*` instances, and in loose mode requires **both** a container-ish name (`box`, `container`, `parcel`, `pile`, `drop`) **and** a loot-state attribute. `buildCrate()` sets `hl.Enabled = false`, `hl.Adornee = anchor` (one BasePart, not the model), and parents the highlight to that anchor. `refreshCrateESP()` only enables it when the new `Crate Chams Highlight` toggle is ON (default **OFF**). Nested container duplicates are still de-duplicated by `commitCrates()`.

### 5. Off-screen arrows follow the FOV

`src/10_fov_circle.lua` exposes `SA.FovCenter()` (mouse location, with a screen-centre fallback). `src/18_esp_fx_frame.lua` computes `fovR = clamp(CFG.fov, 20, half the smaller viewport side)` once per frame and passes `fovCenter` / `fovRadius` into every `drawEntity` call. `src/18_esp_fx_draw.lua` places the arrow at `centre + dir.Unit × fovR`, scales the triangle with `fovR`, clamps the tracer there too, and also shows the arrow for on-screen targets that are outside the aim cone. Both the tracer and the arrow are gated on `opt.pal == "player"`, so **NPCs and crates never draw them**. Turn `Arrows Follow FOV` OFF to get the old screen-edge behaviour.

### 6. All ESP text scales from one slider

`CFG.espTextSize` (6–30 px, default **11**) is applied in the unified `drawEntity()` styling pass to **every** screen-space `TextLabel` the three ESP types draw: name, distance, weapon badge and corner tags for players / NPCs / crates. Row spacing is `espTextSize + 3` so nothing overlaps at large sizes. `Show Health %` adds an `HP: NN%` tag, `Text Outline` toggles the stroke, `Tags On Box Side` moves the tags between the corner and the bottom stack, and `Tag Backdrops` toggles the dark pill behind them. See the [ESP text layout](#esp-text-layout-tahoma-weapon-below-flags-at-the-corner).

### 7. The Luau 200-local-register compile error

The first executor run failed **before any feature started**:

```
01:17:04 AM [Hanami] compile error: [string "Hanami"]:3904:
Out of local registers when trying to allocate playerSec: exceeded limit 200
```

Line 3904 is `local playerSec, npcSec = ...` in `src/22_ui_esp.lua`. Luau allows at most **200 live local registers in one compiled function**, and joining the parts had put **225 column-1 `local`s** in the single main chunk. `luaparse` (Lua 5.1) does not enforce that cap, so the old `LUA PARSE OK` check missed it entirely.

**Fix (in `loader.lua`, so the one-line loader stays unchanged):** before compiling, `hoist()` rewrites every column-1 `local X = ...` into `X = ...` — a name in the chunk environment instead of a register. Indented `local`s inside functions are untouched, so each function keeps its own upvalues. With `setfenv` available the shared names live in an isolated table; otherwise they fall back to normal globals. Everything the parts share (`CFG`, `SA`, `ESP_COLORS`, gun specs, helpers, UI handles) still resolves exactly as before.

Measured on the fixed build: **0** top-level locals, **~21** loop registers in the main chunk, and a worst-case **55** locals in any single function — all far below 200. `python3 tools/verify.py` now checks that budget explicitly, and `build.sh` uses `tools/hoist.py` to produce the same Luau-safe source for the optional `dist/Hanami.lua`.

## Player ESP reliability fix

Symptom: turning Player ESP on drew boxes for *some* players while others stayed invisible, permanently — typically the same names every round.

There wasn't one bug, there were five, and they compounded:

| # | Cause | Fix |
|---|---|---|
| 1 | **Build-queue starvation.** `19_render_loop.lua` allowed 2 new objects per frame, started at `GetPlayers()[1]` every frame, and incremented the counter even when `buildESP()` bailed out (no character, dead, parts still streaming in). Two unbuildable players at the front consumed both slots forever; nobody after them was ever created. | `buildBatch()` counts **only successful builds**, skips failed attempts within the same frame, and **rotates the start index** each frame. Attempts are capped at 10 so a long run of failures can't stall the frame either. |
| 2 | **Respawns never rebuilt.** `CharacterAdded` was connected *only inside* `PlayerAdded`, so anyone already in the server at injection had no handler. Their `BillboardGui` / `Highlight` stayed parented to the removed character, while `espObjects[plr]` remained truthy — so `buildESP()` was never called again. | All existing players are hooked at load, connections are reused (not stacked) across re-executes, and each object records the character it was built for. A swap detected by `13` or `19` clears the object so the render loop rebuilds it. No fixed `task.wait` delay — the queue retries until the new rig is ready. |
| 3 | **One bad player aborted everything.** `refreshESP()` and `SA.ApplyEspFx()` were single unguarded `pairs()` loops. A failed raycast, destroyed `Head`, or a `Drawing` property write that throws on this executor stopped the loop, so every remaining player silently kept the previous frame. | Every player is refreshed/styled inside its own `pcall`; each of the four render passes is `pcall`-guarded separately. `SA.IsVisible()` also handles degenerate zero-length rays and wraps the raycast. Errors are isolated per entity and per pass. |
| 4 | **Rigid rig requirements.** `buildESP()` demanded `Head` + `HumanoidRootPart` + `Humanoid` by exact name and rejected `hum.Health <= 0`. R6/R15 differences, streamed characters and custom rigs were dropped at build time. | `SA.PlayerRig()` falls back through `RootPart`, `UpperTorso`, `Torso`, `PrimaryPart` and any `BasePart`, with `HeadPart` / root as the head anchor. Dead players are built then **hidden** by the refresh instead of churning the queue. |
| 5 | **Ghosts from a previous execution.** `espObjects` was a fresh table on every run, so old `BillboardGui`s and drawing lines were never removed; their old render loop disconnects, leaving frozen boxes that look like "working" players. | `espObjects` persists through `_G` and is purged on load, including `o.fx` drawings and `Highlight`s. |

A simulation of the old queue with 8 players (2 permanently unbuildable at the front) built **0 of 6** valid players after 30 frames; the new queue builds **6 of 6 within 3 frames**.

**Reliability controls** (ESP → Player ESP):

* **Rebuild Player ESP** — clears every object so the render loop rebuilds them all; handy after a big server change or a config toggle.

The rotating, success-only queue is shared with the NPC and crate passes, so they benefit from fix #1 too. All other behaviour (visibility colours, 48 colourpickers, FOV reference point, one text-size slider) is unchanged.

## ESP text layout (Tahoma, weapon below, flags at the corner)

The old player ESP put everything in one `BillboardGui` line above the head: `W: assault_rifle | S: Running | WALL`. That made the weapon the topmost row and squeezed the `VIS`/`WALL` flag into the same string. `src/18_esp_fx_draw.lua` now renders **every** label as a `TextLabel` in the shared `ScreenGui` overlay, positioned against the box geometry computed by `18_esp_fx_frame.lua`:

```
                  PlayerName                  <- above the box, centred
   [42m]  ┌───────────────────────┐  WALL   <- distance at top-left corner,
          │                       │  S: Running    flags at top-right corner
          │           +           │  HP: 100%
          │                       │
          └───────────────────────┘
              [ assault_rifle ]              <- BELOW the box, centred
```

| Element | Position | Toggle / colour |
|---|---|---|
| Name | centred above the box, 4 px gap | `Show Names` · `Name text` picker |
| Distance | right-aligned just left of the top-left corner | `Show Distance` · `Distance text` picker |
| Weapon | centred below the box, 4 px gap | `Show Weapon` · `Scanner text` picker |
| `VIS` / `WALL` | first tag at the top-right corner | `Visibility Check` · **always** the dynamic green/red colour |
| State | second tag | `Show State` |
| Health % | third tag | `Show Health %` |
| All tags | stacked by `espTextSize + 3` | `Tags On Box Side` (OFF stacks them under the weapon), `Tag Backdrops` |

The refreshes (`13`, `15`, `17`) now write a small structured `o.tx` table — `name`, `dist`, `weapon`, `tags` — instead of only concatenating one string. The old BillboardGui labels are still populated as a fallback/data source but hidden by the FX pass, so no text is drawn twice. Crates use the same layout with their `OPENED` / `UNOPENED` state as the corner tag. The screen-space text also keeps the palette overrides the old BillboardGui labels had: crate kind colours paint the name, crate state uses `crateState` / `crateOpened`, and NPC Guard / Scavenger / Soldier colours paint the name and state tag. The floating **ESP Preview** panel mirrors the layout live, including the `VIS` ↔ `WALL` alternation.

**Tahoma.** Roblox's `Enum.Font` does **not** contain a `Tahoma` member (only Legacy / Arial / Gotham / SourceSans / …), and native `Drawing.new("Text")` fonts are limited to UI / System / Plex / Monospace. `01_config.lua` therefore resolves the font once and exposes `SA.ApplyEspFont(label)`:

1. `Enum.Font.Tahoma` if the executor patches the enum;
2. otherwise `Font.fromName("Tahoma", Regular, Normal)` → `TextLabel.FontFace`;
3. otherwise `Font.new("rbxasset://fonts/families/Tahoma.json", …)`;
4. otherwise the bundled `Enum.Font.ArialBold` so text is **never** invisible.

All four ESP label sets (players, NPCs, crates, preview) and the new screen-space labels go through that helper; `SA.DrawDiag()` reports the resolved font name. If a client cannot load a Tahoma family, ArialBold is used automatically — there is no setting to break the text. `SA.NewDraw("Text")` is deliberately GUI-only, so it works on the same executors as the Line / Circle / Triangle fallback.

## Silent aim v7.7 & manipulation v4

`src/05_manipulation.lua`, `src/06_firing_and_guns.lua` and `src/09_silent_aim.lua` were **rewritten** with the v7.7 camera-snap implementation. The old code is gone: the render-step binds now only cover held-fire snapping and restoration, while taps are handled before the game's fire handlers run.

### Why tap-fire needed fixing

The old build only changed `camera.CFrame` inside a `BindToRenderStep` callback. Games that fire their `Shoot` remote **synchronously from `InputBegan` or `Tool.Activated`** had already sent the shot with the unsnapped camera by the time the render step ran, so single taps missed while holding fire worked. v7.7 adds two reorders:

* **Fix A — `InputBegan` reorder.** Read every existing connection's `Function`, disconnect them, install a snap-first connection, then reattach the originals. The camera is therefore snapped when the game's fire handler runs, and a double `task.defer` restores it after nested `task.spawn(fire)` paths finish. Hanami improves on the extract here: if *any* connection's function cannot be read, it aborts **without disconnecting anything** (the extract disconnected first and could leave the game with no input handlers).
* **Fix B — `Tool.Activated` reorder.** Same idea, per equipped tool, for games that fire from the tool's Activated signal. Tools are marked with `__saTapHooked` so re-executing never double-hooks.
* **Tap window 0.2 → 0.35 s**, and `InputEnded` now also stamps `last`, so a fast press+release is still inside the window.
* **Idempotent tap snap.** Some games dispatch from both signals; only the first snap in an input event is allowed, otherwise the second would capture the already-snapped CFrame as "real" and leave the camera stuck on the target. A 1 s TTL clears stale state if a restore ever fails.

All hooks are installed **once** and dispatch through `SA.TapSnap()` / `SA.TapRestore()` / `SA.InstallTapReorder()`, so re-executing the loader never leaves stale closures or stacks hooks. `Visual → Utilities → Retry Tap Hooks` retries if `getconnections` was unavailable at load; `SA.SilentAimState()` reports the status.

### Bows removed from aim (guns only) & two bow mods

Silent aim and manipulation now work **only for guns**. The whole bow aim path was deleted:

* The three bow ids (`hunting_bow` / `crossbow` / `compound_bow`), their projectile speeds, arrow `Workspace.Gravity` drop and `isBow` fields are gone from `07_gun_specs.lua`; bows resolve to no ballistic spec at all.
* The `Fust.Remotes.Shoot` hook (`hookfunction` + `newcclosure`), `SA.BowShot()`, bow draw/hold state (`BowDrawing` / `BowSnapHold`) and the "Bow Shoot Hook" toggle are gone. A re-execution purge in `09_silent_aim.lua` neutralises any stale hook left by an older run: `SA.BowShot` becomes a pass-through returning the untouched packet, and the retired `SA.*` fields are cleared.
* `saLockActive()` is the single gate — `SA.Alive` + `CFG.masterEnabled` + `CFG.gunEnabled` + **not** `SA.IsEquippedBow()`. `SA.ResolveShot()`, `SA.TapSnap()` and the render-step snap all go through it, and `saManipResolve()` has a second defensive bow check, so no ray is cast for a bow.
* Bow tools are skipped by tap-fire Fix B. `SA.IsEquippedBow()` / `SA.IsBowTool()` are plain name/attribute classifiers (word stems, `elbow` excluded) with no ballistic data — they exist only to *disable* aim.

Instead, bows get exactly two quality-of-life mods from the pasted script. See [Bow mods](#bow-mods-instant-charge--no-cooldown): **Instant Charge** and **No Shot Cooldown**. They change the bow's own timing only, never its aim.

### What was deliberately kept

The extract is a *diagnostic extract* — its `flags["sa_lock"]` is empty, `bowCombatState` / `bowConstants` are nil stubs, and its prediction is a one-step `distance / speed` guess with a 25-entry `saBulletSpeeds` table. Porting those verbatim would have regressed features built earlier:

* **Prediction** stays `SA.Predict()` — exact quadratic intercept with per-gun `speed`, bullet drop, alt ammo, `life`/range bounds and live ping (`08_prediction.lua`).
* **Gun data** stays the exact `u3492` / `u3338` definitions (`07_gun_specs.lua`), not the extract's speed table.
* **FOV is still the one reference point**: `SA.AimPoint()` + `SA.FovRadius()` drive target picking, the circle, snapline, tracers and arrows. The extract measured from `GetMouseLocation()` directly and created its own `Drawing` circle — that duplicate was not ported.
* The master switch is `CFG.masterEnabled` + `CFG.gunEnabled` + `SA.Alive` + `not SA.IsEquippedBow()` (not `flags["sa_lock"]`), so **Unload Everything** stops the tap hooks and a bow never engages aim.

### Fust bow ballistic silent aim

**Fust Bow Ballistic Aim** is a default-OFF, reversible, bow-only intercept for Fust's `ReplicatedStorage.Fust.Remotes.Shoot` `RemoteEvent`. One `hookfunction` wraps `Shoot.FireServer`; the wrapper is generation-guarded and forwards untouched arguments unless `CFG.fustBowEnabled` is ON, a tool with a Fust bow `ItemId` is equipped, and a FOV target resolves. Guns keep the camera-snap resolver and are never rewritten.

The `Fust.Items` bow specs are **hunting_bow** (220 speed / 50 gravity / 0.8 s draw), **compound_bow** (290 / 40 / 1.1 s) and **crossbow** (320 / 28 / full charge), plus `fust_*` ItemId aliases. `ARROW_LIFE` is 4.5 s. The wrapper finds the shot's velocity `Vector3` argument, solves a six-pass gravity-compensated intercept with target velocity / flight time, and rewrites that argument to a unit aim direction times the original speed. With **Peek-Origin Wallbang** ON, `findPeek()` walks eight right / up directions from the camera to the first clear ray to the target (within `CFG.fustBowManipMaxDist`, stepping by 0.5 up to `CFG.fustBowManipPeek`); when a near-camera `Vector3` origin argument exists inside `CFG.fustBowOriginRadius`, it is rewritten to that peek position. With manipulation OFF the FOV pick requires line of sight. No print / warn / debug output is emitted; failures stay inside `pcall`.

`SA.FustBowState()`, `SA.FustBowRefresh()`, `SA.FustBowRestore()` and `SA.FustBowDispose()` expose the hook, counter, spec, last-shot and reason state. `SA.FullUnload()` and a loader re-execute restore the original `FireServer`. Static + Fengari mock validation cannot prove a specific executor's `hookfunction` behaviour or the live Fust remote's argument layout; the hook is best-effort and reports its own readiness.

### New controls

| Control | Where | Default |
|---|---|---|
| Tap-Fire Reorder (Fix A/B) | Aiming → Gun | ON |
| Fust Bow Ballistic Aim | Aiming → Fust Bow | OFF |
| Tap Window (s) | Aiming → Gun | 0.35 |
| Enable Bow Mods | Gun Mods → Bow Mods | OFF |
| Instant Charge (max draw) | Gun Mods → Bow Mods | OFF |
| No Shot Cooldown | Gun Mods → Bow Mods | OFF |
| Base Peek Offset (4–6 only) | Aiming → Wall Penetration | 4 |
| Range / Parts / Budget / Hysteresis / Max Delta | Aiming → Wall Penetration | 30 / 3 / 40 / 3 / 6 |
| Apply Recommended Wall Pen | Aiming → Wall Penetration | 75 / 4 / 3 / 64 / 5 / 6 |
| Tags On Box Side / Tag Backdrops | ESP → ESP Features | ON / ON |
| Retry Tap Hooks / Sync Gun Defs (GC) | Visual → Utilities | — |

A one-time migration in `01_config.lua` pulls saved v7.7 profiles back into the classic ranges; **every load** clamps all six manip values into their slider bounds, retires `manipMaxPeek` and drops the retired `saBowHook` flag. Custom values inside the new ranges are left alone.

## Bow mods (instant charge + no cooldown)

Only the **Bow Mods** part of the pasted `anti-externa.wtf` script was ported, and only **two** of its features. Bows are no longer aimed (see above); these two toggles change the bow's own charge / cooldown timing and nothing else.

| Requested | What it does | Tables touched |
|---|---|---|
| **Instant Charge (max draw)** | Every frame sets `drawStart = os.clock() - 10` on the live bow state, so the game always sees a fully drawn shot. Works whether the game's clock is `os.clock()` or `tick()`. | `u14` live draw state |
| **No Shot Cooldown** | Zeros `SHOT_GAP` / `REDRAW_GAP` / `MIN_DRAW` on the bow config table and keeps `lastShot = -math.huge` on the live state, so the fire gate never blocks. Original constants are saved and restored when the toggle goes off. | `u10` config + `u14` live state |

**Explicitly NOT ported into the bow section:** `NoDrop` / the `Items.BowSpec` wrap, `Instant Reload` (crossbow `u17`), `NoRecoil` / tremble / sway (`u185`), `InfiniteAmmo`, `NoAirBlock` / the `u16.blocked` wrapper, the WindUI, hit log, hit sound, damage tracker, ESP, and the pasted bow-mods script's gun mods. Those two bow toggles remain the only live bow mods. The separate V16.46-style Gun Mods section owns the new named-field holds, not the bow module.

`src/20_bow_mods.lua` follows the same pattern as `src/20_gun_mods.lua`:

* A generation-guarded `getgc(true)` scan every 1.5 s (only while the master switch and at least one mod are on), yielding every 1000 tables. Tables are matched by shape with `rawget` — five numeric constants for `u10`, five typed fields for `u14` — rather than by name.
* `setreadonly(tbl, false)` unfreezes only matched tables; `rawget` / `rawset` bypass `__index` / `__newindex` on plain Lua tables. No metatable is written.
* A per-frame `bindRender` pass rewrites `drawStart` / `lastShot` and re-zeroes the config constants in case the game resets them. Switching a mod off, the master off, or **Unload Everything** calls `SA.BowModsRestore()` to put the saved `SHOT_GAP` / `REDRAW_GAP` / `MIN_DRAW` values back and reset `lastShot` to `0`. The saved originals live in `_G.__saBowSaved`, so re-executing the loader cannot mistake the already-zeroed values for the originals.
* `SA.BowModsState()` reports whether `getgc` / `setreadonly` are available, how many config / live tables were found and how many are patched.

**Controls** — Gun Mods → Bow Mods: `Enable Bow Mods` (master, OFF by default — turn it on first), `Instant Charge (max draw)`, `No Shot Cooldown`, `Restore Bow Timings`. New `CFG` keys `bowModsEnabled` / `bowInstantCharge` / `bowNoCooldown` are backfilled and bound through `hn_` flags; **Disable All** and **Unload Everything** turn them off and restore the timings.

Requires an executor with `getgc` + `setreadonly`; without them the scan simply never runs (no errors, no changes). Table shapes come from the pasted script and are game-specific — if nothing is found, `SA.BowModsState()` reports zero config / live tables.

## FOV fixes & one reference point

### Why the circle did not load / did not show up

| # | Problem | Fix |
|---|---|---|
| 1 | `ensureFov()` required **all** of `Filled` / `Thickness` / `NumSides` / `Visible` to be writable. One unsupported property (commonly `NumSides`) returned `nil` forever, so no circle was ever created. | Each property is written independently and tolerantly; `Visible` is always written last. |
| 2 | Every frame all property writes sat inside **one** `pcall`. A single failure meant `c.Visible = true` was never reached and the object was removed — invisible, recreated forever. | Independent per-property writes, plus a runtime downgrade to the ScreenGui backend. |
| 3 | `SA.NewDraw` probed only `"Line"`. An executor with Line but a broken Circle silently killed the FOV (and ESP rings). `11_snapline.lua` also wrote ~14 native properties **outside** any pcall at load, so a bad write aborted the whole joined chunk — literally "it doesn't load". | Capability is probed **per kind** against every property that kind uses; snapline init is fully guarded and `SA.NewDraw` never returns `nil` (a no-op proxy keeps callers alive). |
| 4 | `showFov` defaulted to `false` in older builds, and `_G.__saCFG` persists — so the new `true` default never applied. The transparency slider was also inverted (`0 %` = fully invisible). | One-time migration forces the circle ON; transparency now means what it says (0 % = solid). |
| 5 | The overlay was parented to `CoreGui` first, which some executors accept but hide. | Parent order is now **PlayerGui → CoreGui → `gethui()`**, the stale overlay is destroyed on re-execute, and `gethui()` is the last resort. |
| 6 | The circle used its own mouse lookup while aim, snapline, tracers and arrows each called `GetMouseLocation()` independently. | One canonical reference point (below). |

**Visual → FOV Circle / Snapline** now has **FOV Centre** (`Mouse` / `Screen Center`), **Force ScreenGui Drawing** (ON by default — turn OFF only to try the native `Drawing` API), and `SA.FovState()` / `SA.DrawDiag()` report the backend, centre, radius, visibility and any write failures. Invalid mouse positions (`0,0` or off-screen) automatically fall back to the screen centre, so the circle can never be drawn off-screen.

### The FOV circle IS the reference point

`src/02_shared.lua` owns both values:

```
SA.AimPoint()    -> centre (mouse, or screen centre when unavailable/chosen)
SA.FovRadius()   -> radius = CFG.fov, capped at half the shorter viewport side
```

Everything measures from them: `pickBestTarget()` (silent aim + snapline preview), `09_silent_aim.lua`, `11_snapline.lua` (`Mouse` line origin), `18_esp_fx_colours.lua` (`Mouse` tracer origin), `18_esp_fx_frame.lua` (off-screen arrows) and `10_fov_circle.lua` (the drawn circle). Change **Aim / Circle Radius** and the target cone, tracers and arrows all move with the circle — targets inside the circle are exactly the ones silent aim picks.

## Crate state fixes

The `[ OPENED ]` / `[ UNOPENED ]` label was showing the exact opposite. Four real bugs in `isCrateOpened()`:

1. **`local _, x = lid.CFrame:ToEulerAnglesXYZ()`** takes the **second** return (`Y` rotation), not X. Crates spawn at random Y rotations, so closed crates were reported opened. It was also measured in world space, so the crate's placement counted as "lid open".
2. Any child named `Opened` / `Looted` that was **not** a `BoolValue` (a Part, a Folder…) returned `true` unconditionally.
3. Any non-empty **string** attribute returned `true` — including `"false"`, `"0"`, `"no"` and `"closed"`.
4. There was no way to flip the label for games whose flag is inverted.

**Fix:** strict `stateTruthy()` (booleans, non-zero numbers and parsed strings), `ValueBase`-only child parsing, explicit "still closed" signals (`Closed` / `Sealed` / `Unopened` / `Available` / `CanOpen` / `HasLoot` …) taking priority, `ProximityPrompt.Enabled` and loot-container contents as reliable secondary signals, and a **conflict check** that auto-corrects games whose `Opened` flag means "available to open" (attribute says opened while the crate is still interactable). The lid-angle guess is now **opt-in** (`Lid Angle Detection`, OFF) and measured relative to the crate with the correct X rotation.

If labels are still backwards in your game, turn on **ESP → Crate ESP → Invert Crate State**. The strict state resolver reads every attribute / ValueBase / Prompt signal the crate exposes. The state filter is now an explicit `if` instead of an `and/or` chain.

## ESP overhaul: crate fix, colours and new features

### Why the Crate ESP didn't work

Four separate bugs in the old parts (now `src/16_esp_crates*.lua`, `src/17_esp_crates_refresh.lua`, `src/19_render_loop.lua`):

1. **Exact-name only.** The old `CRATE_NAMES` table contained just `"Military Crate"` and `"Elite Crate"`. Real revisions use `MilitaryCrate`, `Crate_Military`, `Elite_Crate`, `LootCrate`, hashed ids, or a `Folder` with a `CrateType` attribute — so nothing was ever classified and nothing was ever drawn.
2. **One-shot discovery.** `enableCrateESP()` scanned `Workspace` once. The only follow-up was `DescendantAdded`, which fires for a Model **before** its parts are parented; `buildCrate()` found no anchor and gave up permanently.
3. **Non-recursive anchor.** `FindFirstChildWhichIsA("BasePart")` checks direct children only, so crates whose parts live in nested sub-models had no anchor.
4. **No explicit `Adornee`.** A `BillboardGui` / `Highlight` parented to a `Folder` or a nested model renders nothing without one.

**Fix:** `crateKind()` normalises names (lowercase, punctuation stripped), checks `military` / `elite` / `crate` / `loot` / `supply` / `airdrop` / `cache` / `chest` / `stash`, reads `CrateType` / `Tier` / `Rarity` / `LootTier` / `Opened` / `Looted` attributes, and excludes player characters and NPCs (see [fix #4](#4-highlight-on-unrelated-objects-when-crate-esp-is-on) for the tightened rules). `SA.GetCrates()` is read every frame by the render loop, `SA.RefreshCrates()` queues an early incremental pass, and `buildCrate()` uses `FindFirstChildWhichIsA("BasePart", true)` plus explicit `Adornee`. New `Loot` kind covers supply drops and other containers. **Rescan Crates** is available in the Crate ESP mini-tab.

### Unified colour system

`src/01_config.lua` declares `ESP_DEFAULT_COLORS` (48 keys) and merges it into `ESP_COLORS`, persisted in `_G.__saEspColors`. Every drawing part reads `ESP_COLORS.<key>`; every colourpicker writes `ESP_COLORS.<key>`; `Reset ESP Colours` (Misc) restores the defaults through the library's `config_flags`, so the UI swatches stay in sync. The old scattered `local espColorVisible = ...` / `local crateColorMilitary = ...` variables are gone.

`ESP → Colours` has four mini-tabs (Player / NPC / Crate / Global). Each row is an Atlanta `label` with a chained `colorpicker` — labels expose a `right_holder`, so no dummy toggle is needed. Flags are `hn_col_<key>`, unique per colour.

| Group | Pickers |
|---|---|
| Player | visible, hidden, flat, visibility dot, name, distance, scanner text, box, chams fill, chams outline, health high/low, skeleton, head dot, tracer, off-screen arrow |
| NPC | the same set, plus `Guard` / `Scavenger` / `Soldier` type colours |
| Crate | Military, Elite, Other loot, Opened, state text, distance text, tracer, off-screen arrow (type colour also paints box / fill / name) |
| Global | snapline visible / blocked, lead marker, FOV circle, FOV while wall-pen is on, aim target |

Crates only define a few palette keys; missing ones fall back to the shared `player<Element>` picker, so skeleton / head dot / health bars aren't plain white.

The dynamic **visible / hidden** colour always paints an outer frame around the box, the visibility dot and the `VIS` / `WALL` info tag, so it stays meaningful even with per-element colours enabled. `NPC Type Colours` overrides box/fill/outline for Guard/Scavenger/Soldier; `Highlight Aim Target` paints the entity silent aim is choosing with the `target` colour.

### New ESP visuals (all in `ESP → ESP Features`)

| Feature | What it draws | Default |
|---|---|---|
| Per-Element Colours | each element uses its own picker instead of the dynamic base | ON |
| Box Outline / Corner Boxes | 4 full edges or 8 corner segments | ON / OFF |
| Chams Fill / Outline | `Highlight` fill and outline | ON / OFF |
| Skeleton (bones) | 6 R6/R15-friendly segments; crates get a spine + crossbar | OFF |
| Head Dot | filled circle on `Head` (or the top-centre of a crate) | OFF |
| Tracer Lines (**PLAYERS ONLY**) | line from Mouse / Center / Bottom to each **player** | OFF |
| Off-screen Arrows (**PLAYERS ONLY**) | triangle on the FOV circle perimeter pointing at off-screen **players** | OFF |
| Arrows Follow FOV | arrows share the FOV circle centre / radius | ON |
| **Text Size** | one slider for **all** ESP text (name, distance, weapon, tags) | 11 px |
| Show Health % / Text Outline | `HP: NN%` tag / label stroke | OFF / ON |
| Tags On Box Side | `VIS`/`WALL`, state, HP at the top-right corner (OFF stacks them under the weapon) | ON |
| Tag Backdrops | dark pill behind the weapon badge and each corner tag | ON |
| Highlight Aim Target | target box / fill / outline uses the `target` colour | ON |
| Rainbow Mode + Speed | all colours cycle through HSV (speed slider) | OFF |
| Distance Fade + Fade Start (%) | transparency ramps in over the last N% of `Max Distance` | OFF |
| Line Thickness / Tracer Origin | 1–5 px, Mouse / Center / Bottom | 1 / Bottom |
| Invert Crate State / Lid Angle Detection | flip backwards labels / opt-in lid guess | OFF / OFF |
| NPC Type Colours | Guard / Scavenger / Soldier get distinct colours | OFF |

All extra drawing objects are created **lazily** per entity and destroyed by `SA.DisposeEspFx(o)` when the object is cleared, so a feature that is off costs zero drawings. `SA.ApplyEspFx(cam)` runs once per frame after the player/NPC/crate refreshes. The FX pipeline is split across `18_esp_fx_colours.lua` / `18_esp_fx_draw.lua` / `18_esp_fx_frame.lua`.

## Ballistic prediction

The old prediction was:

```lua
local speed  = getGunSpeed()                         -- wrong hardcoded table, default 1000
local travel = (targetPos - camera.CFrame.Position).Magnitude / speed
local vel    = getVelocity(best.bone)                -- raw single-frame delta, very noisy
if vel.Magnitude > 0.5 then targetPos = targetPos + vel * travel end
```

`GUN_SPEEDS`, `GUN_DEFAULT_SPEED`, `getGunSpeed()`, `getEquippedGunId()` and the single-frame `velCache` are **gone**. In their place:

* `src/07_gun_specs.lua` — **every attribute** of all **20** guns (`mag`, `spread`, `adsSpread`, `moveSpread`, `reload`, `recoil`, `rate`, `auto`, `s2Damage`, optional `scope` / `headGuard` / `shellReload` / `rocket` / `huntOnly` / `duelOnly`), ammo damage, alt ammo, the 8 named `Falloff` profiles, `GUN_RANGE`, `gravity`/`life` and the `u3492.GunDamage` formula. Bows are absent on purpose; `SA.IsEquippedBow()` / `SA.IsBowTool()` are name-only gates that *disable* aim for bows.
* `src/08_attachments.lua` — all 12 attachment defs, `AttFit`, slots/tags, tool scanner and the auto-tune pass. See [Attachments](#attachments--auto-prediction-tuning).
* `src/08_prediction.lua` — smoothed target velocity, live ping, an exact intercept solver, adaptive refinement and the live gun tuning helpers.

### Gun data

`speed` is the projectile speed — it is **not** called `bulletSpeed`. Values already include the `u3338.GUNS` overrides (`bolt_action_rifle` 2600 → **2200**, `lr_sniper` 3000 → **2600**). `hunt_smg` shares the `custom_smg` override. The pasted item table omits `gravity` for the four SMGs, so their previously validated `u3338` drop (`8` / `1 s`) is retained; only the two scoped rifles list gravity in the paste. **Sync Gun Defs (GC)** overwrites any of these with the live game values.

The solver's per-gun inputs are `speed`, `gravity`, `life` and `range`. The remaining attributes are carried on the resolved gun object, folded into the attachment auto-tune and exposed through `SA.GetEquippedGun()` / `SA.AttachmentState()`. `duel_rifle` (**Arena Rifle**, `duel_ammo`) is new; it is a `semi_auto_rifle` clone, so its `duel_ammo` base damage is assumed equal to `rifle_ammo` (40) and it inherits the `semi_auto_rifle` falloff and attachment fit.

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
| `duel_rifle` | 1425 | duel_ammo | 1 | 40 (est.) | 1 | — | 900 |

**All the new attributes, per gun** (identical to the pasted `Guns` table; `SA.GUN_SPECS` holds the same values at runtime):

| Gun id | mag | rate | auto | spread | adsSpread | moveSpread | reload | recoil pitch | scope | s2Damage |
|---|---|---|---|---|---|---|---|---|---|---|
| `assault_rifle` | 30 | 0.133 | yes | 2.8 | 0.25 | 2 | 4 | 1.1 | — | 39 |
| `bolt_action_rifle` | 5 | 1.5 | no | 5 | 0.05 | 3.5 | 4.5 | 5.2 | 8 | 78 |
| `custom_smg` | 24 | 0.1 | yes | 2.2 | 0.45 | 1.2 | 2.8 | 1.15 | — | 22 |
| `double_barrel` | 2 | 0.25 | no | 5.5 | 3.75 | 1.2 | 3.4 | 7 | — | 8 |
| `drum_smg` | 50 | 0.095 | yes | 2.6 | 0.55 | 1.4 | 4.2 | 1.25 | — | 24 |
| `duel_rifle` | 16 | 0.175 | no | 2 | 0.06 | 2 | 4.4 | 1.2 | — | 39 |
| `high_caliber_revolver` | 6 | 0.35 | no | 1.4 | 0.05 | 2 | 4 | 4.5 | — | 51.5 |
| `hunt_smg` | 24 | 0.1 | yes | 2.2 | 0.45 | 1.2 | 2.8 | 1.15 | — | 20 |
| `lever_carbine` | 10 | 0.6 | no | 2.5 | 0.08 | 2.4 | 4.85 | 3.8 | — | 45 |
| `lr_sniper` | 5 | 1.8 | no | 6 | 0.03 | 4 | 5 | 6.3 | 8 | 82 |
| `m249` | 100 | 0.12 | yes | 3.6 | 0.4 | 3 | 6 | 1.4 | — | 40 |
| `pipe_shotgun` | 1 | 0.9 | no | 5 | 3.25 | 1 | 2.2 | 5.75 | — | 11 |
| `pump_shotgun` | 6 | 0.9 | no | 5 | 3.4 | 1.2 | 3.55 | 6.6 | — | 9 |
| `revolver` | 8 | 0.22 | no | 1.2 | 0.1 | 1.8 | 3 | 1.7 | — | 27 |
| `rocket_launcher` | 1 | 1.5 | no | 1.6 | 0.45 | 3 | 6 | 7.5 | — | — |
| `scar` | 20 | 0.16 | yes | 3 | 0.22 | 2.2 | 4.2 | 1.6 | — | 42 |
| `semi_auto_pistol` | 10 | 0.13 | no | 1.5 | 0.18 | 1.6 | 2.2 | 1.3 | — | 24 |
| `semi_auto_rifle` | 16 | 0.175 | no | 2 | 0.06 | 2 | 4.4 | 1.2 | — | 39 |
| `service_pistol` | 12 | 0.15 | no | 1.5 | 0.16 | 1.6 | 2.3 | 1.5 | — | 28 |
| `tactical_smg` | 30 | 0.085 | yes | 1.8 | 0.3 | 1.1 | 2.6 | 0.95 | — | 21 |

The pasted `s2Damage` numbers (11, 27, 22, 20, 39, 39, 40, 24, 78, 82, 42, 8, 9, 28, 21, 24, 45, 51.5, 39) are stored as `balance` for the legacy readout **and** used directly when Saturday2 damage is enabled — they are **not** the normal per-pellet damage. The named `Falloff` table from the paste is kept verbatim: `pistol_family` {60,200,0.6}, `smg_family` {25,100,0.8}, `rifle_family` {150,500,0.75}, `semi_auto_rifle` {250,550,0.75}, `lever_carbine` {200,550,0.75}, `high_cal_revolver` {150,450,0.7}, `lr_sniper` {300,1600,0.7}, `shotgun_pellet` {25,60}. `bolt_action_rifle`, `rocket_launcher` and `duel_rifle` have no custom profile of their own (duel_rifle inherits `semi_auto_rifle`).

### Damage formula

`u3492.GunDamage` = the gun's real `s2Damage` when Saturday2 is on (or the `SA.S2Damage` hook if assigned), otherwise `Defs[ammo].damage * damageMult`. The `damage` field on every gun definition is **0** and is ignored. Ammo base damage: `handmade_shell` 13, `pistol_bullet` 32, `rifle_ammo` 40, `duel_ammo` **40 (estimate)**, `rocket` 1. `rocket_launcher` has `damageMult=nil` / `s2Damage=nil` in the paste; the resolver normalises that to 1 because explosive damage is not modelled.

Alt ammo modifiers applied by the resolver:

| Ammo | Effect |
|---|---|
| `hv_rifle_ammo` | **1.5× speed**, 0.85× damage |
| `explosive_rifle_ammo` | no speed/damage change recorded |
| `buckshot_shell` | 1.35× damage, 0.75× pellets, 0.85 spread |
| `slug_shell` | 1 pellet, `0.7 whole` (interpreted as 70% of the full spread damage), 0.3 spread |
| `hv_rocket` | speed **140** (absolute), drop 2 |
| `incendiary_rocket` | no speed/damage change recorded |

Attachment effects are applied on top of this by `08_attachments.lua`: `muzzle_boost` = +15% fire rate / −10% damage, `mag_extender` = `max(floor(mag), floor(mag × 1.333… + 0.5))`, `silencer` = −10% recoil + slower bullets (the one effect that changes the intercept). The legacy **Muzzle Boost Equipped** toggle in Ballistics remains as a manual fallback. `Saturday2 Damage` forces the `s2Damage` branch; the game can also expose `Saturday2()` / `s2Damage` through `SA.Saturday2` / `SA.S2Damage` hooks (see below).

### The solver

1. **Velocity** — `SA.TargetVelocity(model)` samples `HumanoidRootPart.Position` into a weak-keyed, exponentially smoothed estimate (`alpha = clamp(dt*12, 0.15, 0.6)`, teleports >120 studs/s dropped).
2. **Exact intercept** — solve `|(p₀ − o) + v·t|² = (s·t)²` for the smallest positive root, where `s` is the equipped gun's real speed. For a stationary target this is exactly `distance/speed`; for a moving target it accounts for the target closing/retreating during flight.
3. **Bullet drop** — for guns with `gravity`, aim above by `½·g·t²` and re-derive the flight time from the new aim point (`Solver Iterations`, 1–8, default 4). **Auto tune**: when bullet drop is present or an attachment changed the projectile speed, one extra pass is added (capped at 8), and every pass exits early once the aim point moves less than 0.0001 studs. Guns without gravity and no speed mod converge immediately.
4. **Latency** — `SA.LeadLatencyMs()` (auto ping × scale + manual offset) **plus** the attachment aim-time lead is added **once** as `tTotal = flightTime + latency`, never once per iteration.
5. **Bounds** — flight time is clamped to the gun's `life` (projectile despawn), and the result reports `inRange` against `GUN_RANGE` (default 550).

`SA.Predict(origin, targetPos, model)` returns `aimPoint, info`. `info` carries `t`, `total`, `speed`, `velocity`, `lead`, `drop`, `latency`, `range`, `inRange`, `expired`, `id`, `ammo`, `gravity`, plus the new `iterations`, `aimMs`, `attachments`, `attIds`, `speedMult`, `ads`, `effSpread` and `zoom`. Silent aim uses it on every snap; the snapline uses it to draw the gold lead ring.

### Controls (Aiming → Ballistics / Visual)

| Control | Default | What it does |
|---|---|---|
| Ballistic Prediction | ON | Master toggle for the solver |
| Bullet Drop Compensation | ON | `½gt²` vertical aim offset |
| Detect Alt Ammo | ON | Reads `Ammo`/`AmmoType`/`LoadedAmmo` attributes off the tool |
| Solver Iterations | 4 | Fixed-point refinement passes |
| **Auto Ping Lead** | **ON** | Live `GetNetworkPing()` / `Data Ping`, smoothed and fed into the solver |
| **Ping Scale** | **1.0×** | Multiplier on the measured ping (0–2) |
| Extra Ping Offset (ms) | 0 | Manual offset added on top of auto ping (0–300) |
| Bullet Speed Override | 0 (auto) | Manual speed, 0–3000; overrides the gun table |
| Ammo Override | Auto | Force any of the 4 base + 6 alt ammo types |
| Saturday2 Damage | OFF | Use the real `s2Damage` numbers from the gun table |
| Muzzle Boost Equipped | OFF | Manual fallback for +15% rate / −10% damage (auto-detected normally) |
| **Auto Attachment Tuning** | **ON** | Detect all 12 attachments and fold them into the prediction |
| Force ADS Spread | OFF | Assume ADS. OFF = read right mouse button; spread readout only |
| Aim-Time Lead Tune | ON | Scopes / ACOG / grip add a small time-to-aim lead; reflex removes some |
| Aim-Time Scale | 1.0× | 0 disables the aim-time lead, 2 doubles it |
| Silencer Speed Mult | 0.85× | **Estimate** for "slower bullets"; directly changes lead + drop |
| Sight / Muzzle / Under / Mag Override | Auto | `Auto`, `None`, or an explicit attachment id — fallback when detection can't see the game's storage |
| Show Lead Marker | ON | Gold ring at the predicted aim point (Visual tab, with colourpicker) |

Functional buttons remain: **Rescan Attachments**, **Sync Gun Defs (GC)**, **Rescan Characters**, **Restore Hitboxes**, **Restore Bow Timings**, **Retry Tap Hooks**, **Apply Overrides Now**, **Sync Gun Defs + Diff**, **Refresh Nearest HUD**, **Rebind Selected** and **Cancel Rebind**. None of them produces console output.

### Live game hooks

* `SA.SyncGunDefs()` scans `getgc(true)` for tables containing `GUN_RANGE` / `GUNS` and merges live `speed`, `gravity`, `life`, `range`, `mag`, `spread`, `adsSpread`, `moveSpread`, `reload`, `rate`, `pellets`, `s2Damage` and `damageMult` into the static DB (and refreshes `balance`). It is opt-in (button), `pcall`-guarded, invalidates the gun cache and does nothing if `getgc` is unavailable.
* The equipped tool is resolved via `ItemId` / `WeaponId` / `ToolId` / `Item` / `Weapon` / `Gun` attributes or the tool name, normalised against the `model` names (`SemiAutoPistol`, `LRSniper`, `ScarRifle`, …) and display names. Unknown tools fall back to 1000 studs/s / 550 range and are flagged `[UNKNOWN]`.
* `SA.Saturday2 = fn` and `SA.S2Damage = function(id, spec) ... end` can be assigned at runtime if the game exposes them; `GunDamage` then uses the `s2Damage` branch automatically. Otherwise it uses `Defs[ammo].damage × damageMult`.
* `SA.Predict` assumes the game applies `gravity` as constant downward acceleration on the projectile. If a given gun has no visible drop in-game, turn **Bullet Drop Compensation** off.
* Bows are deliberately excluded: there is no `Fust.Remotes.Shoot` hook and no bow ballistic spec. `saLockActive()` returns false while a bow is equipped, so `SA.ResolveShot()`, `SA.TapSnap()`, the render-step snap and manipulation all stay idle. The two bow mods in `20_bow_mods.lua` only change charge / cooldown timing. An older run's stale `Shoot` wrapper is neutralised on load (`SA.BowShot` becomes a pass-through).

## Attachments & auto prediction tuning

`src/08_attachments.lua` keeps the pasted `Attachments`, `AttFit`, `ATT_SLOTS`, `ATT_SLOT_NAME`, `ATT_TAG` and `MAG_EXT` tables verbatim (12 defs, 7 fit lists). The moment **any** attachment is found on the equipped tool, its effects are folded into `SA.GetEquippedGun()` — and `SA.Predict()` therefore re-tunes itself with no manual toggle.

| Attachment | Slot | Tag | Exact effect from the description |
|---|---|---|---|
| `red_dot_sight` | sight | RED DOT | clear red dot, neutral zoom |
| `holo_sight` | sight | HOLO | wide window, slight zoom, steadier aim (`removed=true` in the paste) |
| `scope_4x` | sight | 4X | 4× zoom |
| `acog_sight` | sight | ACOG | 3× zoom, "a bit slower to aim" |
| `reflex_sight` | sight | REFLEX | Red Dot zoom, "faster to aim, a bit less steady" |
| `muzzle_brake` | muzzle | BRAKE | **−30% recoil**, **+15% spread** |
| `silencer` | muzzle | SUPP | **−10% recoil**, no tracers, **slower bullets**, 300-shot durability |
| `muzzle_boost` | muzzle | BOOST | **+15% fire rate**, **−10% damage**, more recoil |
| `vertical_grip` | under | GRIP | **−25% vertical recoil**, "a bit slower to aim" |
| `laser_sight` | under | LASER | **−40% hip-fire spread** |
| `flashlight` | under | LIGHT | light only; no ballistic effect |
| `mag_extender` | mag | EXT MAG | `max(floor(mag), floor(mag × 1.333… + 0.5))` |

`AttFit` lists which guns accept each muzzle / under / mag attachment; sights fit any non-scoped gun (`bolt_action_rifle` and `lr_sniper` have `scope=8` and are blocked). `SA.AttachmentFits()` is **informational** — a mismatch is ignored rather than silently disabling tuning, because the game may allow a combination the paste omits. `duel_rifle` is treated as a `semi_auto_rifle` clone for fit checks.

### Detection

All reads are `pcall`-guarded and the descendant walk is capped at 400, so a strange tool can never break silent aim. The gun cache is keyed by the **Tool instance** as well as time, so switching weapons (or attaching a mod) changes the prediction on the next frame.

1. Every attribute on the tool — both **keys** (`Silencer = true`, `HasSuppressor = 300`) and **values** (`Muzzle = "silencer"`, `Attachments = "SUPP,GRIP"`), including comma / space-separated lists.
2. Common slot attributes (`Sight`, `Muzzle`, `Under`, `Mag`, `Attachments`, `Mods`, …) as a fallback for executors without `GetAttributes()`.
3. Descendants: attachment model names (`RedDotSight`, `Scope4x`, `Silencer`, …), `ValueBase` values, and `ItemId` / `Attachment` attributes on Models / Folders / ObjectValues. Descendant names use **only strong aliases** (id / display name / model), so a generic gun child called `Grip`, `Light` or `Muzzle` is *not* mistaken for an attachment.
4. Four per-slot overrides (`Auto` / `None` / explicit id) for games that store attachments somewhere else.
5. The legacy **Muzzle Boost Equipped** toggle still works as a manual fallback, but a detected or overridden muzzle always wins.

### What gets tuned

| Effect | Where it lands | Changes the aim point? |
|---|---|---|
| Silencer speed multiplier | `gun.speed` → intercept time `t`, lead, `½gt²` drop, `life` expiry | **Yes** |
| Sight / grip aim-time | one extra latency term (`aimMs`) → target moves further before the shot | **Yes** (moving targets only) |
| Adaptive iterations | +1 pass when speed changed or drop is present; early exit on convergence | **Yes** (refinement) |
| `muzzle_boost` / brake / grip / laser / ext mag | damage, rate, recoil, spread, magazine | No — readouts only |
| ADS / movement | `gun.effSpread`, `gun.ads`, `gun.zoom` | No — state only |

A manual **Bullet Speed Override** always wins over the silencer multiplier. Turning **Auto Attachment Tuning** off leaves the base gun profile untouched (the old manual muzzle-boost behaviour still applies). `SA.ATT_EFFECTS` is exposed so every estimate can be edited at runtime.

### Estimates (tunable, not in the paste)

The paste gives percentages but **no numbers** for "slower bullets", zoom steadiness or aim speed. These are exposed as CFG controls and marked as estimates:

| Estimate | Default | Control |
|---|---|---|
| Silencer bullet speed | `0.85×` | **Silencer Speed Mult** (0.5–1.0) |
| Sight zoom | 1 / 1.25 / 4 / 3 / 1 | `SA.ATT_EFFECTS[id].zoom` |
| ADS spread factor | 0.9–1.1 | `SA.ATT_EFFECTS[id].adsSpread` |
| Aim-time lead | 0 / +20 / +60 / +80 / −30 / +50 ms | **Aim-Time Scale** (0–2×), **Aim-Time Lead Tune** |
| `muzzle_boost` recoil | `1.15×` | `SA.ATT_EFFECTS.muzzle_boost.recoil` |
| `duel_ammo` base damage | 40 | `src/07_gun_specs.lua` |
| SMG `gravity`/`life` | 8 / 1 s | retained from `u3338`; GC sync overrides |

`spread` / `adsSpread` / `moveSpread` are reported but **never** converted into an aim offset — the game's spread units are not documented, and guessing would make the solver worse. `effSpread` is a diagnostic estimate (`ADS ? adsSpread : spread`, plus `moveSpread × movement`).

### State accessors

* `SA.AttachmentState()` — detected ids, speed multiplier, aim-time, mag, damage and rate.
* `SA.RescanAttachments()` — clears the gun cache and re-detects; **Rescan Attachments** calls it.
* `SA.GetEquippedGun()` — every resolved attribute, effective spread / recoil and the attachment list.
* `SA.GUN_SPECS` — one row per gun with all 20 speeds, ammo, mag, pellets, rate, range, s2Damage and spread values.
* `SA.Predict()` — the intercept solution including aim-time, iterations, ADS and effective spread.

If nothing is detected, set the four slot overrides manually. Detection requires a real `Tool` under `lp.Character`; it does not scan the Backpack, so owned-but-not-attached mods are ignored.

## Best settings for wall penetration

Wall penetration = the **FOV-aware wall peek** (`Aiming → Wall Penetration`). It temporarily disables `CanQuery` on the wall parts in front of you for the hit-scan, then restores them in the same frame's restore bind. It is FOV-gated, so it only spends raycasts on targets that are actually inside your aim cone. The engine keeps the 8 peek directions (cardinals + diagonals), the single shared `RaycastParams` with the target model in the filter, and the reused `CanQuery` entries — but the **classic six-slider set** is back.

**Recommended all-round setup** (press **Apply Recommended Wall Pen** to set all of it at once — the original `75 / 4 / 3 / 64 / 5 / 6` recommendation):

| Setting | Value | Why |
|---|---|---|
| Enabled (FOV-aware) | **ON** | Turns on the peek/disable-restore cycle. |
| Wall Check (silent aim) | **OFF** | Strict LOS-only silent-aim mode. It is bypassed automatically while Manipulation is ON anyway — with it ON *and* penetration OFF, shots behind any wall are aborted. **Fire Assist Wall Check** is a separate, independent toggle. |
| Range | **75 studs** | Slider is **0–300 studs** only. 75 covers most fights; pushing to 300 searches a lot more geometry for little gain. |
| Base Peek Offset | **4** | Slider is **4–6** only. Enough side clearance for thin walls / door frames without teleporting the ray origin far off your crosshair. This is now the *actual* maximum peek. |
| Max CanQuery Parts | **3** | Handles a wall + a prop + a fence. Slider `0–8`. Higher values make the restore pass heavier. |
| Ray Budget / Frame | **64** | Slider `8–128`. Good balance between finding a clear peek and staying smooth. Use **32** on low-end devices. |
| Cache Hysteresis | **5 frames** | Slider `0–12`. Keeps the same peek active instead of re-scanning every frame when you strafe. |
| Max Peek Delta | **6** | Slider `2–12`. **Genuinely caps** how far the binary-searched peek may drift before it is recomputed. |
| Aim / Circle Radius (FOV) | **~150 px** | A narrower cone means fewer candidate peeks per frame — the single biggest CPU saving. Also moves the off-screen arrows. |
| Hit Chance | **100 %** | No random skipped shots while you're testing penetration. |
| Cooldown | **0 s** | Fire as fast as the weapon allows. |
| Prediction | **ON** | The ballistic solver compensates moving targets; penetration doesn't help if the shot lands behind them. |
| Target Bone | **Head** | Smaller target → fewer ambiguous multi-part peeks. |

**Why the adaptive peek was removed.** v7.7 scaled the peek with distance and then computed `deltaCap = math.max(CFG.manipMaxPeekDelta, maxPeek)`. Since `maxPeek` was always >= the peek distance, **Max Peek Delta could never reject any peek** — it was a dead slider, and the extra "Adaptive Peek Cap" slider had no analogue in the original recommendation. `05_manipulation.lua` now uses `maxPeek = CFG.manipPeek` directly and compares `peekDist <= CFG.manipMaxPeekDelta`, so all six sliders are functional. `01_config.lua` clamps each value to its UI range on every load (saved profiles, preset imports and manual edits included) and removes `CFG.manipMaxPeek` from old configs.

Two useful variants:

* **Strict / legit** — Manipulation `OFF`, silent-aim Wall Check `ON`, Fire Assist Wall Check `ON`, FOV `~120`, Hit Chance `60–80`. Only shoots what you can genuinely see.
* **Heavier cover** — keep the recommendation but raise `Max CanQuery Parts` to `8` and `Ray Budget` to `128`; keep FOV at `150` so the extra rays stay bounded. For long-range work use `Range 300 / Peek 6 / Delta 12`.

The snapline and the red ESP colour are your penetration indicator: **green = you already have line of sight, no penetration needed; red = a wall is in the way**.

## UI: Atlanta

`src/21_ui_aiming.lua` loads the [Atlanta library](https://github.com/i77lhm/Libraries) and builds the window; parts 22–26 build the tabs.

```
Aiming   → Silent Aim / Gun (incl. Tap-Fire Reorder, Tap Window; GUNS ONLY) · Target / Ballistics / Wall Penetration (classic) · Attachments (Auto) · Overrides
ESP      → Player ESP (incl. Rebuild Player ESP / Show ESP Preview Panel / Rebuild ESP Preview) / NPC ESP · Crate ESP / ESP Features (incl. Clean / Best ESP presets) · Colours (Player / NPC / Crate / Global)
Gun Mods → Gun Mods (V16.46-style) · Controller Field Holds · Silent State / Reports · Bow Mods · Live Gun Tuning
Visual   → FOV Circle / Snapline · Utilities · Nearest HUD (incl. Manip Crosshair Popup) · Performance Mode · Keybinds
Misc     → Info · Quick Actions

floating "ESP Preview" panel (Atlanta window.esp_section)
         → 3D render · Enabled / Rotate Model / Spin Speed
         → Rebuild Character
```

* **Every widget writes straight into `CFG`** through its `callback`, and every `default` is read from `CFG`. Building the menu never resets the settings kept in `_G.__saCFG`.
* Flags are prefixed `hn_` so they can't collide with the library's own config flags. `setFlag("someKey", value)` and `setToggle(obj, value)` are what the presets and quick actions use, so the UI stays in sync when values change programmatically.
* **Keys:** `RightShift` shows/hides the menu (default), `Insert` toggles silent aim (chained keybind on the master toggle). Both are rebindable; right-click any bind to set `None`.
* **48 colourpickers** live in `ESP → Colours` and write straight into `ESP_COLORS`. Chained onto `label` rows (labels expose `right_holder`), each has a unique `hn_col_<key>` flag. FOV / snapline / lead / target colours moved here from the Visual tab so there is exactly one picker per colour. `Reset ESP Colours` restores defaults and syncs the swatches.
* The old Shaman `RadioButton` preset is now a `Custom / Legit / Blatant` dropdown ("Custom" is the default so opening the menu doesn't apply a preset). The `Bullet Speed Override` slider (0–3000) now lives in the Ballistics section.
* **FOV controls:** `Show FOV Circle` (ON), `FOV Centre` (Mouse / Screen Center), `Force ScreenGui Drawing` (ON), `Aim / Circle Radius`, plus `SA.FovState()` / `SA.DrawDiag()` state accessors.
* **Crate controls:** `Invert Crate State`, `Lid Angle Detection` (OFF) and `Rescan Crates` in ESP → Crate ESP.
* Quick actions: Disable All (also clears NPC ESP + snapline + bow mods), Apply Blatant, Toggle Manip, **Reset ESP Colours**, Unload Everything (hides the window, hides the FOV circle, disposes the ESP preview, restores bow timings and stops the scanners via `SA.Alive`), plus Rescan NPCs and Rescan Crates.
* The floating **ESP Preview** panel is populated by `src/22_esp_preview.lua` + `src/22_esp_preview_setup.lua`. **Show ESP Preview Panel** in ESP → Player ESP re-opens it if you closed it with the panel's `X` button.

Only one thing from the Atlanta template is intentionally **not** copied: the duplicated `vis, other` multi-section block. `window.esp_section:esp_preview({})` is also *not* called, but its feature is now implemented natively — see [ESP preview](#esp-preview). Everything else from the template's init block is kept: `open_tab()`, `config_list_update()`, the theme pass, and `old_config = get_config()` — each guarded with `pcall` where it touches filesystem/config APIs.

## ESP preview

Atlanta's `library:window()` always creates a second, draggable 300×325 panel called **"ESP Preview"** and exposes it as `window.esp_section`. Hanami never put anything in it, so the panel sat there empty and looked broken. The template's own `window.esp_section:esp_preview({})` cannot simply be turned on:

| Problem in the built-in | Why it breaks here |
|---|---|
| Reads ~13 template flags | `Name_Color`, `Box_Color`, `Health_Low`, `Enabled`, `Box_Type`, `Distance_Color`, `Weapon_Color`, `Names`, `Healthbar`, `Distance`, `Weapon`, `Boxes`, `Health_High` are all `nil` — Hanami uses `hn_` flags + `CFG` + `ESP_COLORS`. It errors on the first `flags[...].Color`. |
| Blindly clones the character | Does `lp.Character.Archivable = true`, `lp.Character:Clone()` and `character.Animate:Destroy()` with no nil checks, so it errors before the character spawns and on any rig without an `Animate` script. |
| Assumes a standard rig | `character.Humanoid` / `SetPrimaryPartCFrame` need a `PrimaryPart`; custom R6/R15/streamed rigs have neither guaranteed. |
| Leaks on re-execute | Parents a `Camera` to `Workspace`, spawns an infinite `task.spawn` health loop, and calls `task.wait()` from inside a `RenderStepped` connection. |
| Static colours | Its overlay has nothing to do with Hanami's 48-colour palette, so it would not preview *your* settings. |

`src/22_esp_preview.lua` (core, styling) and `src/22_esp_preview_setup.lua` (build, lifecycle, controls) replace it with a self-contained, `pcall`-guarded widget:

* **3D model.** A `ViewportFrame` with its own `Camera` (parented to the viewport, never to `Workspace`). It clones your current character, strips every `Script` / `LocalScript` / `ModuleScript` / `BillboardGui` / `SurfaceGui` / `Highlight` / `ParticleEmitter` / `Sound` / `ForceField`, restores `Archivable`, sets a `PrimaryPart` fallback, and recentres it with `PivotTo` (with a `SetPrimaryPartCFrame` fallback). If there is no character yet, cloning is blocked, or the clone cannot be parented, it falls back to a synthetic R6-style dummy rig — the panel still renders instead of erroring.
* **Respawn / re-execute / unload.** `CharacterAdded` rebuilds the model after a short delay; a load-time teardown disconnects the previous render loop, destroys the old viewport **and the old floating panel**, and the `CharacterAdded` connection is stored in `_G` so it never stacks. `Unload Everything` calls `SA.EspPreviewDispose()`. No yields happen inside `RenderStepped` — rotation is pure `dt` math and restyling is throttled to 10 Hz.
* **Live settings.** Every overlay is restyled through the same `pick(key, base, seed)` helper used by the real ESP, so `CFG.espRainbow`, `CFG.espPerElementColors`, `CFG.espTextSize`, `CFG.espBoxThickness` and all 48 `ESP_COLORS` entries apply instantly. It previews box / corner boxes / outline, name, distance at the left corner, the weapon badge below the box, the `VIS`/`WALL` + state + `HP: NN%` tags at the right corner, health bar (low→high lerp), visibility dot, skeleton, head dot, tracer and chams fill tint. `VIS` / `WALL` alternates every 2.5 s so both green and red visibility colours are visible. ViewportFrames cannot reliably render `Highlight`, so chams are shown by tinting the model's parts.
* **Reachable.** On displays shorter than ~1080 px the template docks this panel *below* the main window, i.e. off-screen. The build clamps the panel into the viewport and docks it top-right when the template position cannot fit. If a future Atlanta revision stops exposing `window.esp_section`, the preview builds itself into a new `ESP Preview` section inside the ESP tab instead; the `embedded` flag keeps unload from hiding the main menu in that case.

**Controls** — in the preview panel: `Enabled`, `Preview Kind` (Player / NPC), `Simulate Aim Target`, `Rotate Model`, `Spin Speed` (0–90 °/s), `Apply Best ESP`, `Rebuild Character`. In ESP → Player ESP: `Show ESP Preview Panel` (re-opens the floating window) and `Rebuild ESP Preview`.

Config keys: `espPreview` (ON), `espPreviewSpin` (ON), `espPreviewSpeed` (25), `espPreviewKind` (`"Player"`), `espPreviewTarget` (OFF), all backfilled for older saved configs and bound to Atlanta widgets. See [Best ESP](#best-esp-players--npcs) for the Player/NPC mirror and the curated preset.


## Best ESP (Players + NPCs)

The ESP tab's **ESP Features** section now has an **Apply Best ESP** button. It addresses the two gaps in the old setup: the best features were scattered across Player / NPC / shared sections with no way to enable the whole readable set at once, and the ESP Preview only mirrored the Player pipeline.

**Apply Best ESP** turns on the curated set for BOTH entity kinds through the Atlanta flags (so every bound widget updates), then re-opens the preview:

| Group | Enabled |
|---|---|
| Player | ESP, Visibility Check, Names, Distance, Health Bar, Weapon, State |
| NPC | ESP, Visibility Check, Names, Distance, Health Bar, Weapon, State, NPC Type Colours |
| Shared | Per-Element Colours, Box Outline (corner boxes), Chams Fill, Skeleton, Head Dot, Tracer Lines, Off-screen Arrows, Highlight Aim Target, Arrows Follow FOV, Show Health %, Text Outline, Tags On Box Side, Tag Backdrops, ESP Preview |

`Rainbow` and `Distance Fade` are deliberately left **OFF** — the first overrides the 48-colour palette and the second hides distant boxes, which defeats a "best" readability preset. `Chams Outline` is also off because the fill + corner-box combination is less noisy. The preset enables every curated Player / NPC / shared flag through the same bound `hn_*` widgets.

**Preview mirrors both pipelines.** `CFG.espPreviewKind` (`Player` / `NPC`, exposed as *Preview Kind*) selects which section's visibility check / name / distance / health / weapon / state flags and which of the `player*` / `npc*` colourpicker keys feed the overlay. In NPC mode the Guard / Scavenger / Soldier archetype colours rotate every three seconds, and the name + state tag use the archetype colour — the same `typeColor` path `drawEntity()` uses in the real ESP. *Simulate Aim Target* paints the box, fill and outline with the global `Target` colour just like *Highlight Aim Target* on a locked target.

The preview also gained the overlays the real ESP already had: a padded **visibility frame** (green/red), a separate label **per corner tag** (so `VIS`/`WALL` stays green/red while state / `HP` use the scanner colour), rounded **tag backdrops**, an **off-screen arrow**, a functional **Chams Outline** second stroke (thickness 0 when disabled — no reliance on the newer `UIStroke.Enabled`), exact `rowH = TextSize + 3` line spacing identical to `drawEntity()`, tracer origin (Center / Mouse), text outline, and a Distance Fade simulation at 85% of the chosen Max Distance. If a future Atlanta build omits `window.esp_section`, the setup now creates its own small `HanamiEspPreviewPanel` ScreenGui instead of failing, and unload destroys it.

**Fixed colour regressions** in `drawEntity()`: crate names keep their kind colour (`keepNameColor`) instead of falling back to the player name picker, crate state tags use `crateState` / `crateOpened`, and NPC archetype colours paint the name and state tag even with the new screen-space Tahoma labels.

`SA.ApplyBestEsp()`, `SA.ConfigCoverage()` (includes `hn_menu_bind`), `SA.NearestWindowState()` and `CFG.espPreviewKind` (`"Player"`), `CFG.espPreviewTarget` (`false`), `CFG.nearestWindow` (`true`) are the new API / config keys; all are backfilled for older saved configs, and the preview kind / speed are clamped on every load so a stale saved value cannot put the mirror into an invalid pipeline. `SA.STUDS_PER_METER = 3.571` is the single studs→metres factor used by the ESP distance labels and the nearest-player HUD.

## Feature keybinds

Every feature master switch now has its own keybind, and the two keybinds that already existed keep working. **RightShift is the default menu toggle**; the aim master moved to **Insert** to avoid a double-fire.

| Feature | Widget | Default key | Flag |
|---|---|---|---|
| Enable Player ESP | ESP → Player ESP → Enabled | `P` | `hn_bind_espEnabled` |
| Enable NPC ESP | ESP → NPC ESP → Enabled | `N` | `hn_bind_npcEspEnabled` |
| Enable Gun Mods | Gun Mods → Gun Mods (V16.46-style) → Enable Gun Mods | `G` | `hn_bind_gmEnabled` |
| Enable Bow Mods | Gun Mods → Bow Mods (GC Scan) → Enable Bow Mods | `B` | `hn_bind_bowModsEnabled` |
| Enable Manipulation | Aiming → Wall Penetration → Enabled (FOV-aware) | `M` | `hn_bind_manipulation` |
| Toggle Aim (existing) | Aiming → Master | `Insert` | `hn_master_bind` |
| Toggle Menu (Atlanta UI Bind) | Settings → Other → UI Bind · Keybinds panel | `RightShift` | `hn_menu_bind` |

`SA.FeatureKeybind()` attaches the bind to the **same toggle** the menu uses, so pressing the key, clicking the toggle, loading a config and the **Disable All** quick action all stay in sync. `SA.KeybindConflicts()` lists shared keys and `SA.FeatureBindClear(flag)` clears one programmatically.

### None / right-click removal

Atlanta already maps `Escape` to `"none"`, but its Keybinds panel leaves the row behind and `MouseButton2Click` only opens the mode selector. `src/21_ui_aiming.lua` wraps `library:keybind` **before** `library:window()` is created, so the built-in UI bind and every feature bind get the same upgrade. The wrapper also recognises Atlanta's unnamed `Enum.KeyCode.Insert` UI Bind call and rewrites it (flag `hn_menu_bind`, name **Toggle Menu**, key `RightShift`, `default = true`) before the stock keybind is built — so the first RightShift press hides the menu and the row is visible/right-clickable in the Keybinds panel.

* left-click / `MouseButton1Down` rebinding accepts **every** `Enum.KeyCode` and `Enum.UserInputType` (no whitelist — F-keys, numpad, mouse buttons, etc.).
* setting a bind to `"none"` (Escape or right-click) does **not** change the feature's ON/OFF state; it just detaches the key.
* **right-click the little key widget on the toggle**, or **right-click its row in the Keybinds panel**, and the bind becomes `none`, its list row is hidden and removed, and the mode selector stays closed (a deferred close handles Roblox event ordering).
* inactive / `none` rows are hidden from the Keybinds panel. Rebinding any key brings the row back.

The wrapper captures Atlanta's 24×14 `TextButton` and the `TextLabel` parented to `library.keybind_list` via a temporary `library:create` hook; the panel rows are made `Active` so `InputBegan` can see `MouseButton2`. No remote library file is modified — the behaviour is patched in Hanami's own chunk. `library.config_flags[flag]` is rewired to the wrapped setter, so saved configs and quick actions use it too.

## Nearest player HUD

Toggle the Atlanta menu off with `RightShift` (or any state where `window.opened == false`) and a compact draggable `HanamiNearestPlayer` `ScreenGui` appears. It reports, refreshed at ~10 Hz by the shared render bind:

```
NEAREST PLAYER
Nearest Display (@NearestGuy)
2.8 m  ·  [ assault_rifle ]
```

* **username** — `DisplayName (@Name)` when a display name exists, otherwise `Name`.
* **distance in metres** — Roblox studs divided by `SA.STUDS_PER_METER = 3.571` (1 m ≈ 3.571 studs, the same conversion the Player / NPC / crate ESP distance labels already used). Both `%.1f m` here and the ESP `[NNm]` labels now read the one shared constant.
* **held gun** — `SA.GetTool(character)` resolves an equipped `Tool` / `ItemId` / `Weapon` attribute / weapon container. The scanner also gained a `GetChildren()` fallback for executors that don't expose `FindFirstChildOfClass("Tool")`.

The HUD is created with `Instance.new("ScreenGui")` directly, **not** `library:create`, so `window.set_menu_visibility(false)` cannot sweep it into `library.guis` and disable it. It is parented to `gethui()` with a `PlayerGui` / `CoreGui` fallback, uses `SA.ApplyEspFont()` for Tahoma-or-`ArialBold` text, and is torn down by `SA.NearestWindowDispose()` on re-execute and **Unload Everything**.

Controls: **Visual → Nearest HUD → Nearest Player HUD** (default ON) and **Refresh Nearest HUD**. `SA.NearestWindowState()` / `SA.NearestWindowSet(on)` / `SA.NearestWindowRefresh()` are the state API. New config key: `CFG.nearestWindow` (`true`, backfilled).

## How the loader works

`loader.lua` downloads each file in `PARTS`, **hoists** the column-1 `local` declarations into the chunk environment (see [§7](#7-the-luau-200-local-register-compile-error)), joins them with `\n\n`, and calls `loadstring` **once**. It is still one script: every shared name (CFG, `ESP_COLORS`, gun specs, helpers, ESP tables, UI handles) resolves across files — the UI parts write `ESP_COLORS.playerVisible = c` and the drawing parts read it in the same frame. Indented `local`s inside functions remain ordinary upvalues. Access between parts that could load in either order goes through the `SA` table instead of forward names.

```
loader.lua  ──fetch──▶  01_config.lua
                       02_drawing.lua
                       02_shared.lua
                       02_workspace_scan.lua
                       ...
                       26_banner.lua
             ──hoist─▶ shared env names, 0 main-chunk locals
             ──join──▶ one chunk ──loadstring──▶ runs, returns CFG
```

`setfenv` (when the executor offers it) keeps those shared names in an isolated table so they don't pollute globals; without it the same names simply go into normal globals. Compile errors now also report **which part** the failing line came from.

Parts 01–02 (shared helpers), 05–06, 10 are slices of the original script with a 5-line comment header. New / rewritten parts: `02_drawing.lua` (Drawing compatibility), `02_workspace_scan.lua` (single yielding walker), `03_entity_scan.lua` (NPC registry), `04_entity_info.lua` (scanner), `07–08` (gun specs / **attachments** / prediction), `14–15` (NPC ESP), `16–17` (crate detection / registry / refresh), `18` (ESP FX, three parts) and `19` (render loop). `09` was rewritten to use `SA.Predict`; `09_z_fust_bow.lua` is the default-OFF **Fust bow ballistic aim / peek-origin wallbang** hook loaded after silent aim; `11–13` gained the lead marker, visibility colours and scanner labels; `08_attachments.lua` is the 12-attachment auto-tune scanner; `20_bow_mods.lua` is the two-feature bow-mods GC scan; `20_gm_a_core.lua` through `20_gm_z_api.lua` are the eight V16.46-style gun-mod, definition, GunControl, live-controller, shot-probe, camera-filter and state-API parts; `20_hitbox_expander.lua` is the silent self-healing **player + NPC hitbox expander**; `22_esp_preview*.lua` are the ESP Preview panel; 21–26 are the Atlanta UI. The old prediction, velocity cache, hardcoded speed table, and the hit-log / hit-sound part were removed. Only `26_banner.lua` has a top-level `return`, and it now contains just that return.

## Files

| Part | What's in it | Lines |
|---|---|---|
| `src/01_config.lua` | services, `CFG` defaults + backfill (**classic manip/tap, NPC manipulation, crate FOV, player warning, trigger / auto fire + dedicated fire-assist wall check, ESP data refresh, Force Head, Fust bow ballistic settings, bow-mods, V16.46 gun / brightness keys, NPC hitbox toggle / player + NPC hitbox expander, attachment keys, Tahoma resolver, Player/NPC preview mirror + clamps, nearest HUD, profiles / self-check / perf / manip-popup / clean-ESP keys**), `SA` state + shared metres factor, `bindRender`, 48-colour palette | 651 |
| `src/02_drawing.lua` | per-kind capability probing, ScreenGui proxy, screen-space Tahoma `Text` draw, no-op fallback, draw state, **coalesced sync batching + per-property write skip + draw pool + write-failure tracking** | 659 |
| `src/02_shared.lua` | **FOV reference point** (`SA.AimPoint` / `SA.FovRadius`), checks, target picking, **pinned target / priority / bone / no-target reason**, **public NPC classifier**, **Force Head**, **Trigger Bone / TriggerTarget + dedicated VIS wall check** | 369 |
| `src/02_workspace_scan.lua` | **single incremental Workspace walker**, `SA.RegisterScanHandler` / `RequestScan` | 116 |
| `src/03_entity_scan.lua` | NPC registry handler + raw list accessor + **guarded** LOS visibility cache | 101 |
| `src/04_entity_info.lua` | entity scanner: tool/weapon + state + roster (**Tool child fallback + shared metres**) | 120 |
| `src/05_manipulation.lua` | **Manipulation (classic sliders, guns only, NPC-aware)**: shared RaycastParams, 8-direction peek, fixed 4–6 peek, clamped functional sliders, target-aware filter, reused CanQuery entries, **read-only crosshair popup probe + fire-assist allowNoAim gate**, NPC toggle / state / explicit probe | 440 |
| `src/06_firing_and_guns.lua` | **v7.7 firing state** (0.35 s tap window, InputEnded stamp; no bow state) + snap cooldown | 56 |
| `src/07_gun_specs.lua` | **all 20 guns + every attribute** (mag / spread / ads / move / reload / recoil / s2 / scope / tags), ammo, damage, alt ammo, 8 named falloffs, ranges + **name-only bow gate** | 326 |
| `src/08_attachments.lua` | **12 attachment defs**, `AttFit` / slots / tags, tolerant tool scanner, **auto-tune effects** + `SA.*Attachments*` state | 395 |
| `src/08_prediction.lua` | **live ping**, smoothed velocity, quadratic intercept, drop, adaptive iterations, attachment aim-time lead, **live gun diff + manual overrides + new-gun stubs** | 310 |
| `src/09_silent_aim.lua` | **Silent Aim v7.7 (guns only)**: Fix A/B connection reorder, idempotent tap snap, bow gate, shared `SA.ResolveShot`, **silent-aim-independent Trigger / Auto Fire, dedicated VIS wall check + no-bypass, Tool-first backend with mouse1click fallback**, render-step camera binds; a **dedicated Fust bow part** owns ballistic hook state | 540 |
| `src/09_z_fust_bow.lua` | **Fust bow ballistic silent aim + peek-origin wallbang**: default-OFF **hookfunction** on **Shoot.FireServer**, Fust.Items bow specs, FOV target pick, gravity-compensated `solveAim`, eight-direction `findPeek`, velocity / origin argument rewrite, LOS gate, generation guard, dispose / restore, `SA.FustBow*` **state** | 376 |
| `src/10_fov_circle.lua` | **FOV circle**, tolerant writes, backend recovery, `SA.FovState` | 144 |
| `src/11_snapline.lua` | aim preview line + target/lead markers | 117 |
| `src/12_esp_players.lua` | **Player ESP v2**: tolerant `SA.PlayerRig`, re-execute purge, char tracking, half-build cleanup | 180 |
| `src/13_esp_players_refresh.lua` | **per-player pcall refresh**, cached player rig / o.vis, **shared projection cache**, **geometry cache** reuse, structured `o.tx` text (weapon / tags), lifecycle hooks | 201 |
| `src/14_esp_npcs.lua` | NPC ESP objects + cached rig + enable/disable + events | 111 |
| `src/15_esp_npcs_refresh.lua` | **NPC ESP refresh** with cached rig / o.vis, **shared projection cache**, **geometry cache** reuse, visibility + scanner + HP + structured `o.tx` text | 110 |
| `src/16_esp_crates.lua` | crate classification, **strict opened-state resolver**, anchors, GUI objects | 326 |
| `src/16_esp_crates_registry.lua` | live crate registry + raw list accessor, **crate-state resolver**, walker handler | 57 |
| `src/17_esp_crates_refresh.lua` | crate refresh (filters, state, structured `o.tx` text, highlight gate) + events | 90 |
| `src/18_esp_fx_colours.lua` | palette helpers, lazy drawing factory, skeleton / screen / box geometry, legacy line / chams hide, **draw usage marks + hide-unused finaliser**, **draw-pool reuse**, **geometry cache invalidation**, per-frame **rainbow clock** | 240 |
| `src/18_esp_fx_draw.lua` | **unified styling**: Tahoma screen-space text, NPC / crate colours, boxes, **clean outline-only mode**, **crate FOV dot / outline-highlight branch**, off-screen skip, FX-owned legacy line / chams visibility, chams, skeleton, tracers, FOV arrows, fade, `SA.Atan2`, **hoisted helpers / draw usage marks / direct segments** | 433 |
| `src/18_esp_fx_frame.lua` | per-frame fps-aware `SA.ApplyEspFx` with error isolation, cached rig / o.vis, throttled team map / nearest sort, **shared geometry cache**, **camera signature**, **adaptive geometry slicing**, **priority slicing**, **hidden pass** for disabled ESP, **one fewer pcall**, crate FOV counters, live per-kind counts | 540 |
| `src/19_render_loop.lua` | master render loop: rotating success-only build queue, 4 guarded passes, FX pass, throttled data refresh, raw list build queues, FPS counters, **60 FPS frame budget / adaptive pacing / rolling FPS / entity cap**, **geometry budget / adaptive geometry slicing**, **rolling FPS** bias only with **performance mode** ON, one shared V16.46 gun-frame hook | 333 |
| `src/20_bow_mods.lua` | **Bow mods (2 features only)**: Instant Charge + No Cooldown, GC scan, originals saved/restored, `SA.BowMods*` state | 191 |
| `src/20_gm_a_core.lua` | V16.46 gun sandbox shared state, helpers, local brightness, equipped-weapon identity | 333 |
| `src/20_gm_b_records.lua` | named-field classifiers, strong-keyed originals, reversible holds, tool inspection, observation baseline / compare | 405 |
| `src/20_gm_c_defs.lua` | Fust.Items definition cache, alias matching, candidate hints, manual selection, definition spread fields | 452 |
| `src/20_gm_d_exports.lua` | opt-in GunControl exports, visible fire-script name hints, silent report strings | 203 |
| `src/20_gm_e_live.lua` | one bounded source-attributed getgc / upvalue controller scanner, cached holds, live report | 385 |
| `src/20_gm_f_probe.lua` | visual tracer A/B shot probe, same-session checkpoint, pause / resume / reset, UNVERIFIED verdict | 593 |
| `src/20_gm_g_camera.lua` | experimental camera-kick pitch correction and UI label rows | 129 |
| `src/20_gm_z_api.lua` | silent `SA.Gun*` state APIs, toggle / slider / label / button helpers, master frame hook, dispose | 388 |
| `src/20_hitbox_expander.lua` | **Hitbox Expander v2 (players + NPCs, R6/R15)**: silent client-side size / collision / query expansion, live NPC raw list, **NPC HRP fallback**, **self-healing** Size hooks, accessory neutralisation, NPC-owned originals + full restore | 490 |
| `src/21_ui_aiming.lua` | Atlanta setup + **re-execution-safe keybind wrapper**, **Atlanta source sanitizer** / **built-in font fallback** / **error-page markers** split, Aiming tab (Target / Ballistics / Wall Pen / attachments / Manipulation), **NPC manipulation**, **Trigger / Auto Fire + Fire Assist Wall Check + hit-part controls + VIS / silent-aim independent labels**, **Force Head**, **Fust bow controls**, **NPC hitbox toggle**, **Hitbox Expander v2 toggles / sliders**, **FOV preset + target priority / bone / pin / no-target UX** | 578 |
| `src/22_esp_preview.lua` | **ESP Preview core**: state/teardown, safe clone + dummy rig, ViewportFrame overlays, **real-model source selection + side-by-side Player vs NPC compare**, **clean-mode mirroring**, per-tag labels, vis frame, arrow, backdrops | 644 |
| `src/22_esp_preview_setup.lua` | **ESP Preview build + lifecycle**: panel clamp, standalone-panel fallback, camera/render bind, respawn hook, Preview Kind / Target / Best ESP controls, source/compare rebuild, `SA.EspPreview*` API | 280 |
| `src/22_ui_esp.lua` | ESP tab: player / NPC / crate / **crate FOV-aware toggle + state** / features / **Clean + Best ESP presets** / 48 colourpickers, **ESP decluttering + live count controls** | 340 |
| `src/23_ui_gunmods.lua` | V16.46-style Gun Mods tab (all 12 Gun settings), silent state labels / report buttons, Bow Mods + feature keybinds, **Live Gun Tuning / Overrides controls** | 138 |
| `src/24_ui_visual.lua` | Visual tab, **top-N nearest HUD + NPC-aware Manip Crosshair Popup + 100m player warning**, **Force Head / Fire Assist state accessors**, **Utilities + local ColorCorrectionEffect brightness**, **Performance Mode + ESP data refresh slider + ESP FPS state + ESP frame budget + FPS overlay + all-keybind manager / rebind / conflicts** | 819 |
| `src/25_ui_misc.lua` | Misc tab, quick actions, **native config profiles + export/import/round-trip**, **self-check state (NPC manipulation, crate FOV, player warning, fire assist, Force Head, Fust bow state, manip popup + clean ESP, draw sync + ESP perf + ESP frame budget + hitbox state)**, **full unload + warning / fire-assist / Fust bow / gun-mod / brightness disposal + hitbox restore**, UI init / auto-load | 583 |
| `src/26_banner.lua` | final `return CFG` only (no startup output) | 9 |
## Testing

```bash
npm ci && npm test
```

`npm test` builds the ignored `dist/Hanami.lua`, runs the Python Luau-safe join verifier, parses every Lua chunk with luaparse, validates the loader / README / CFG coverage, then executes the committed Fengari mock suite. The runner loads `tools/mocks.lua`, executes the bundle three times in one Lua state and asserts startup, native profile auto-load, re-execution, full unload, manipulation popup READY / BLOCKED / bypass states, NPC manipulation, crate FOV dot / outline checks, 100 m warning, Triggerbot / Auto Fire / part modes / VIS FOV with silent aim OFF / Tool-first backend with mouse fallbacks / dedicated Fire Assist Wall Check / both-enabled / Manipulation Support no-bypass regressions, player + NPC hitbox expansion / HRP fallback / NPC toggle restore, ESP FPS optimization / coalesced GUI sync / throttled data refresh / cached rig / off-screen skip / raw list / ESP 60 FPS frame budget / per-property instance writes / draw usage marks / shared projection cache / camera signature / adaptive geometry stride / teammate-map throttle / disabled-ESP hidden-pass / Atlanta font-bootstrap sanitizer / Fust bow hookfunction / ballistic velocity / peek-origin wallbang / bow-spec / LOS / dispose / full-unload restore regressions, Force Head, all new state APIs and the no-console-output / no-print-UI regressions with zero mock callback / event errors.

The suite is static + Fengari mock validation, **not a real Roblox executor** confirmation. Executor-only behaviour (`gethui`, `Drawing`, `getgc`, `getconnections`, real ViewportFrames, filesystem / clipboard and Atlanta's live UI) must still be checked in-game; `SA.SelfCheck()` returns the capability report to code.

## Editing

* Parts share one scope: a column-1 `local` in an earlier part is hoisted and visible in later ones. **Indented** `local`s stay private to their function.
* **Order matters.** Adding/removing a part means updating `PARTS` in `loader.lua` too.
* Never put a top-level `return` in any part except `26_banner.lua` — it would end the joined chunk early.
* Keep a trailing newline on every part (they are concatenated directly), and give column-1 `local`s an initializer — `local a, b = nil, nil`, not `local a, b`.
* Luau caps a function at **200 local registers**: `python3 tools/verify.py` checks the hoisted main chunk and the per-part budget, so don't add lots of new column-1 `local`s without re-running it. A plain `luaparse` parse is *not* enough.
* All new drawing must go through `SA.NewDraw(kind)`; all new workspace discovery must go through `SA.RegisterScanHandler(key, predicate, commit)`. Never call `Workspace:GetDescendants()` in a loop.
* Atlanta widgets need a `button_holder()` row before `button()`, and keybinds/colourpickers can be chained onto a toggle or a `label` (both expose `right_holder`; a colourpicker can also be chained onto another colourpicker). `multi_section({ names = {...} })` accepts any number of mini-tabs.
* All `CFG` keys used by the logic must stay bound to a UI widget; `python3 tools/verify.py` checks the join.

```bash
python3 tools/verify.py   # order, newlines, stray returns, Luau register budget, build output
bash build.sh             # optional: make one self-contained dist/Hanami.lua via tools/hoist.py
```

`build.sh` is only needed if you want a single paste-able file; it applies the **same** hoisting as the runtime loader. `dist/` is gitignored.

---

Executor-only script (`Drawing`, `getgc`, `loadstring`, `getcustomasset`). Use in private/own places; running it in public experiences can violate Roblox's Terms of Use and get an account banned.
