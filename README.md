# Hanami

`@abusegpt` suite — silent aim, wall penetration, player/NPC/crate ESP, entity scanner, aim snapline, ballistic prediction and gun mods — with an **Atlanta** UI.
The original 1,300-line script is split into **31 short files** (`src/`, largest is 353 lines) plus a short **loader**.

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
| **Silent Aim v7.7 (tap-fire fixed)** | Aiming → Silent Aim / Gun | See [Silent aim v7.7 & manipulation v4](#silent-aim-v77--manipulation-v4). Render-step-only snapping is no longer the sole path: InputBegan / Tool.Activated connection reorder snaps the camera **before** the game fires, tap window widened to 0.35 s, bow Shoot remote hook, and one shared shot resolver keeps the FOV circle as the reference point. |
| **Manipulation v4 (patched)** | Aiming → Wall Penetration | 8 peek directions (cardinals + diagonals), peek distance scales with range, target model included in the ray filter, and much higher caps (48 parts / 96 rays). See the same section. |
| **Actually compiles in the executor** | loader | See [Luau 200-local-register fix](#7-the-luau-200-local-register-compile-error). The old join hit `Out of local registers ... exceeded limit 200` at `playerSec` and never ran. The loader now hoists column-1 `local`s into the chunk environment, so the main chunk needs zero local registers. |
| **FOV circle fixed + made the aim reference** | Visual → FOV Circle / Snapline | See [FOV fixes](#fov-fixes--one-reference-point). Now defaults ON, draws through a reliable ScreenGui backend, and its centre + radius are the single reference used by silent aim, snapline, tracers and arrows. |
| **Crate opened / unopened labels fixed** | ESP → Crate ESP | See [Crate state fixes](#crate-state-fixes). The inverted labels came from a Y-rotation destructuring bug plus false-positive state guesses. Added strict state parsing, `Invert Crate State` and a state debug print. |
| **No more ~3 s frame skip** | everywhere | See [Stability & fixes](#stability--fixes). One shared, yielding Workspace walker replaces both `GetDescendants()` scanners; GUI builds are capped; stale render loops disconnect on re-execute. |
| **One text-size slider for ALL ESP text** | ESP → ESP Features → Text Size | Scales name, distance, tool / state, `VIS`/`WALL`, health % on players, NPCs **and** crates, and re-stacks the rows so they never overlap. Plus `Show Health %` and `Text Outline` toggles. |
| **FOV circle actually shows** | Visual → FOV Circle / Snapline | `SA.NewDraw` falls back to real Roblox GUI Frames when the executor has no usable `Drawing` API; no longer gated on aim being ON; transparency slider now means what it says (0 % = solid). ON by default. |
| **Auto Ping Lead** | Aiming → Ballistics | Reads live `lp:GetNetworkPing()` (or `Stats.Network.ServerStatsItem["Data Ping"]`), smooths it, and feeds it into the ballistic solver. `Ping Scale` × ping + `Extra Ping Offset (ms)` = total extra lead. Old manual-only `Extra Lead` is now an offset on top. |
| **No stray crate Highlight** | ESP → Crate ESP | `Crate Chams Highlight` is **OFF** by default. Classification now requires a container-like Model/BasePart with a real crate signal, and the `Highlight` is bound to the crate's own anchor part only — never a whole folder of scenery. |
| **Skeleton / Head Dot / Tracer / arrows work** | ESP → ESP Features | All `Drawing.new` calls now go through the compatibility layer, and skeleton + head dot also render on crate ESP (a spine and a top marker). |
| **Off-screen arrows follow FOV** | ESP → ESP Features → Arrows Follow FOV | Arrows sit on the FOV circle perimeter using the **same centre and radius** as the drawn circle; change `Aim / Circle Radius` and the arrows move with it. Also points at on-screen targets *outside* the aim cone. |
| **48 colourpickers** | ESP → Colours | One clearly-labelled picker for **every** drawn element (players, NPCs, crates, snapline, FOV, lead, target). All write into one shared `ESP_COLORS` table that survives re-execution. |
| **Customizable visibility colours** | ESP → Colours · Player / NPC | Green (clear LOS) / red (blocked) are now obvious labelled pickers, not tiny swatches buried on unrelated toggles. They paint an outer frame, a visibility dot and the `VIS` / `WALL` tag even when per-element colours are on. |
| **Crate diagnostics** | ESP → Crate ESP | **Print Crate Names (debug)** lists every container-ish instance with its class, classified kind and parent, so the exact names your game uses can be found. |
| **Ballistic prediction** | Aiming → Ballistics | Replaced the old one-step `distance/speed` guess with an exact quadratic intercept solve using each gun's real `speed`, bullet drop, alt ammo, live ping and range. See the next section. |
| **Player visibility check** | ESP → Player ESP | Box, name, fill and info line turn **green when there is a clear line of sight** and **red when a wall blocks it**. Cached camera raycast (~120 ms). |
| **FOV snapline** | Visual → FOV Circle / Snapline | Line + dot to the target, **green = visible, red = blocked**, plus a gold **lead ring** at the exact point the solver aims at. |
| **NPC silent aim / NPC ESP** | Aiming + ESP | `pickBestTarget` selects from players **and** the NPC registry. Separate section for `Guard`, `Scavenger`, `Soldier`, with name/distance/health box, visibility colours and scanner options. |
| **Entity scanner** | ESP tab + Misc | Reads an equipped `Tool`, `ItemId` / `Weapon` / `HeldItem` attributes and weapon containers, plus `Downed` / `Knocked` / `Dead` / `State` attributes with a `HumanoidStateType` fallback. `Show Weapon` and `Show State` are options on **both** player and NPC ESP; `VIS` / `WALL` is a third tag. |
| **Wall-pen description** | Aiming → Wall Penetration + below | Tooltips, three in-UI labels, and a one-click **Apply Recommended Wall Pen** button. |

NPC detection accepts the literal model names `Guard` / `Scavenger` / `Soldier`, the common `Scavenger`/`IsNpc`/`NPC` attributes, and models inside `Npcs` / `Enemies` folders. Real player characters are explicitly excluded.

## Stability & fixes

### 1. The periodic ~3 second freeze

Five separate causes were stacking up:

* The NPC scanner called `Workspace:GetDescendants()` every **2 s** and the crate scanner called it again every **1.5 s** — a single synchronous full-workspace snapshot on a big map freezes the render thread.
* `SA.RefreshCrates()` / `SA.RefreshNpcs()` ran that same full scan **inline** when enabling an ESP, clicking a Rescan button, or on `DescendantAdded`.
* Dozens of `BillboardGui` / `Highlight` / `Drawing` instances could be created in one frame.
* Re-executing the loader left **duplicate `RenderStepped` loops** from the previous run still connected.
* The gun-mods `getgc(true)` loop ran every 1 s with a 3 000-iteration yield budget.

**Fix:** `src/02_workspace_scan.lua` is now the *only* workspace walker in the script. It does a breadth-first traversal via `GetChildren()`, inspects at most **120 nodes per frame** and then `task.wait()`s — no `GetDescendants()` anywhere in a loop. Both the NPC and crate registries register a `predicate` + `commit` callback with `SA.RegisterScanHandler`, and `SA.RequestScan()` only queues an early pass. `src/19_render_loop.lua` caps new GUI builds at **2 per ESP type per frame** and refreshes crates at ~20 Hz. `bindRender()` in `src/01_config.lua` binds every `RenderStepped` callback with a generation guard, so old loops disconnect themselves. The GC scan is generation-guarded, yields every 1 000 objects and runs every 2 s (and only when gun mods are ON).

`SA.WorkspacePass()` reports the number of completed passes; **Visual → Debug → Print Draw Backend** reports which drawing backend is in use.

### 2. FOV circle / skeleton / head dot / tracer / arrows not appearing

Every one of those is a `Drawing` object. Executors that expose a partial (or no) `Drawing` API fail `Drawing.new(...)` inside a `pcall`, and the visual silently disappears — while the crate `BillboardGui` text still renders, which is exactly the symptom in the screenshot.

**Fix:** `src/02_drawing.lua` probes native `Drawing.new("Line")` once, checking that `Visible`, `Color`, `Transparency`, `Thickness`, `From` and `To` are actually writable. If that fails (or `Triangle.PointA` isn't writable), `SA.NewDraw(kind)` returns a proxy backed by real Roblox `Frame`s inside a `HanamiOverlay` ScreenGui (CoreGui → PlayerGui → `gethui()`). The proxy implements the exact same `Line` / `Circle` / `Triangle` property interface plus `Remove()`. All five direct callers (`10_fov_circle.lua`, `11_snapline.lua`, `12_esp_players.lua`, `14_esp_npcs.lua`, `18_esp_fx_colours.lua`) now use `SA.NewDraw`.

The FOV circle also had three logic bugs: it was gated on `CFG.masterEnabled`, `fovTransparency = 0` produced `Transparency = 1` (fully invisible), and a dead draw object was never recreated. All fixed; `showFov` now defaults to **true**.

### 3. Extra Lead auto-adjusts to live ping

`src/08_prediction.lua` adds `SA.GetPing()` (0.25 s cached, exponentially smoothed, clamped 0–1000 ms) and `SA.LeadLatencyMs()`:

```
total extra lead (ms) = (auto ping × Ping Scale) + Extra Ping Offset
```

`GetNetworkPing()` returns seconds so it is ×1000; the legacy `Data Ping` value is already milliseconds (both `GetValue()` and a numeric/string `Value` are handled). `Auto Ping Lead` is **ON** by default, `Ping Scale` defaults to **1.0** (full round-trip time — set it to **0.5** if you want one-way latency instead), and the old manual `Extra Lead (ping ms)` slider is now `Extra Ping Offset (ms)` added on top. **Aiming → Ballistics → Print Live Ping** shows the measured ping and resulting total. The solver adds this **once** as `tTotal = flightTime + latency`, never once per iteration.

### 4. Highlight on unrelated objects when Crate ESP is ON

The loose classifier accepted *any* instance with an `Opened` / `Looted` attribute (doors, scenery, whole `Loot` folders), and the `Highlight` was parented to the model with `Adornee` set to the whole model.

**Fix:** `crateKind()` now requires `Model` or `BasePart`, excludes player characters / humanoids / our own `Hanami*` instances, and in loose mode requires **both** a container-ish name (`box`, `container`, `parcel`, `pile`, `drop`) **and** a loot-state attribute. `buildCrate()` sets `hl.Enabled = false`, `hl.Adornee = anchor` (one BasePart, not the model), and parents the highlight to that anchor. `refreshCrateESP()` only enables it when the new `Crate Chams Highlight` toggle is ON (default **OFF**). Nested container duplicates are still de-duplicated by `commitCrates()`.

### 5. Off-screen arrows follow the FOV

`src/10_fov_circle.lua` exposes `SA.FovCenter()` (mouse location, with a screen-centre fallback). `src/18_esp_fx_frame.lua` computes `fovR = clamp(CFG.fov, 20, half the smaller viewport side)` once per frame and passes `fovCenter` / `fovRadius` into every `drawEntity` call. `src/18_esp_fx_draw.lua` places the arrow at `centre + dir.Unit × fovR`, scales the triangle with `fovR`, clamps the tracer there too, and also shows the arrow for on-screen targets that are outside the aim cone. Turn `Arrows Follow FOV` OFF to get the old screen-edge behaviour.

### 6. All ESP text scales from one slider

`CFG.espTextSize` (6–30 px, default **11**) is applied in the unified `drawEntity()` styling pass to **every** `TextLabel` the three ESP types create — player name / distance / info, NPC name / distance / info, crate name / state / distance. Rows are re-stacked and the `BillboardGui` is resized to fit. `Show Health %` appends `HP: NN%` to the player / NPC info line; `Text Outline` toggles the stroke.

### 7. The Luau 200-local-register compile error

The first executor run failed **before any feature started**:

```
01:17:04 AM [Hanami] compile error: [string "Hanami"]:3904:
Out of local registers when trying to allocate playerSec: exceeded limit 200
```

Line 3904 is `local playerSec, npcSec = ...` in `src/22_ui_esp.lua`. Luau allows at most **200 live local registers in one compiled function**, and joining 31 parts had put **225 column-1 `local`s** in the single main chunk. `luaparse` (Lua 5.1) does not enforce that cap, so the old `LUA PARSE OK` check missed it entirely.

**Fix (in `loader.lua`, so the one-line loader stays unchanged):** before compiling, `hoist()` rewrites every column-1 `local X = ...` into `X = ...` — a name in the chunk environment instead of a register. Indented `local`s inside functions are untouched, so each function keeps its own upvalues. With `setfenv` available the shared names live in an isolated table; otherwise they fall back to normal globals. Everything the parts share (`CFG`, `SA`, `ESP_COLORS`, gun specs, helpers, UI handles) still resolves exactly as before.

Measured on the fixed build: **0** top-level locals, **~21** loop registers in the main chunk, and a worst-case **55** locals in any single function — all far below 200. `python3 tools/verify.py` now checks that budget explicitly, and `build.sh` uses `tools/hoist.py` to produce the same Luau-safe source for the optional `dist/Hanami.lua`.

## Silent aim v7.7 & manipulation v4

`src/05_manipulation.lua`, `src/06_firing_and_guns.lua` and `src/09_silent_aim.lua` were **rewritten** with the v7.7 camera-snap implementation. The old code is gone: the render-step binds now only cover held-fire snapping and restoration, while taps are handled before the game's fire handlers run.

### Why tap-fire needed fixing

The old build only changed `camera.CFrame` inside a `BindToRenderStep` callback. Games that fire their `Shoot` remote **synchronously from `InputBegan` or `Tool.Activated`** had already sent the shot with the unsnapped camera by the time the render step ran, so single taps missed while holding fire worked. v7.7 adds two reorders:

* **Fix A — `InputBegan` reorder.** Read every existing connection's `Function`, disconnect them, install a snap-first connection, then reattach the originals. The camera is therefore snapped when the game's fire handler runs, and a double `task.defer` restores it after nested `task.spawn(fire)` paths finish. Hanami improves on the extract here: if *any* connection's function cannot be read, it aborts **without disconnecting anything** (the extract disconnected first and could leave the game with no input handlers).
* **Fix B — `Tool.Activated` reorder.** Same idea, per equipped tool, for games that fire from the tool's Activated signal. Tools are marked with `__saTapHooked` so re-executing never double-hooks.
* **Tap window 0.2 → 0.35 s**, and `InputEnded` now also stamps `last`, so a fast press+release is still inside the window.
* **Idempotent tap snap.** Some games dispatch from both signals; only the first snap in an input event is allowed, otherwise the second would capture the already-snapped CFrame as "real" and leave the camera stuck on the target. A 1 s TTL clears stale state if a restore ever fails.

All hooks are installed **once** and dispatch through `SA.TapSnap()` / `SA.TapRestore()` / `SA.BowShot()` / `SA.InstallTapReorder()` / `SA.InstallBowHook()`, so re-executing the loader never leaves stale closures or stacks hooks. `Visual → Debug → Retry Tap / Bow Hooks` retries if `getconnections` / `hookfunction` was unavailable at load, and **Print Silent Aim (v7.7)** reports the status.

### Bow support

`07_gun_specs.lua` gained the three bow ids from the extract (`hunting_bow` 350, `crossbow` 500, `compound_bow` 400 studs/s), with live `Workspace.Gravity` for arrow drop. `Fust.Remotes.Shoot` is hooked once to rewrite `data.dir` / `data.origin` from the resolved shot; `data.draw` packets track the draw state so the snap is held while drawing and for 5 frames after release. **The bow path now passes the target model to manipulation** (the extract passed `nil`, so the target's own body could be counted as cover).

### What was deliberately kept

The extract is a *debug extract* — its `flags["sa_lock"]` is empty, `bowCombatState` / `bowConstants` are nil stubs, and its prediction is a one-step `distance / speed` guess with a 25-entry `saBulletSpeeds` table. Porting those verbatim would have regressed features built earlier:

* **Prediction** stays `SA.Predict()` — exact quadratic intercept with per-gun `speed`, bullet drop, alt ammo, `life`/range bounds and live ping (`08_prediction.lua`).
* **Gun data** stays the exact `u3492` / `u3338` definitions (`07_gun_specs.lua`), not the extract's speed table.
* **FOV is still the one reference point**: `SA.AimPoint()` + `SA.FovRadius()` drive target picking, the circle, snapline, tracers and arrows. The extract measured from `GetMouseLocation()` directly and created its own `Drawing` circle — that duplicate was not ported.
* The master switch is `CFG.masterEnabled` + `CFG.gunEnabled` + `SA.Alive` (not `flags["sa_lock"]`), so **Unload Everything** actually stops the tap and bow hooks too.

### New controls

| Control | Where | Default |
|---|---|---|
| Tap-Fire Reorder (Fix A/B) | Aiming → Gun | ON |
| Tap Window (s) | Aiming → Gun | 0.35 |
| Bow Shoot Hook | Aiming → Gun | ON |
| Base Peek Offset / Adaptive Peek Cap | Aiming → Wall Penetration | 20 / 120 |
| Range / Parts / Budget / Hysteresis / Max Delta | Aiming → Wall Penetration | 1000 / 48 / 96 / 3 / 40 |
| Print Silent Aim (v7.7), Retry Tap / Bow Hooks, Print Manip State (v4) | Visual → Debug | — |

A one-time migration in `01_config.lua` raises saved profiles that still used the old defaults; custom values are left alone.

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

**Visual → FOV Circle / Snapline** now has **FOV Centre** (`Mouse` / `Screen Center`), **Force ScreenGui Drawing** (ON by default — turn OFF only to try the native `Drawing` API), and **Visual → Debug → Print FOV State** / **Print Draw Backend** which report the backend, centre, radius, visibility and any write failures. Invalid mouse positions (`0,0` or off-screen) automatically fall back to the screen centre, so the circle can never be drawn off-screen.

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

If labels are still backwards in your game, turn on **ESP → Crate ESP → Invert Crate State**. **Print Crate States (debug)** dumps every raw attribute / ValueBase / Prompt signal per crate alongside the resolved label, so the game's real flags can be identified. The state filter is now an explicit `if` instead of an `and/or` chain.

## ESP overhaul: crate fix, colours and new features

### Why the Crate ESP didn't work

Four separate bugs in the old parts (now `src/16_esp_crates*.lua`, `src/17_esp_crates_refresh.lua`, `src/19_render_loop.lua`):

1. **Exact-name only.** The old `CRATE_NAMES` table contained just `"Military Crate"` and `"Elite Crate"`. Real revisions use `MilitaryCrate`, `Crate_Military`, `Elite_Crate`, `LootCrate`, hashed ids, or a `Folder` with a `CrateType` attribute — so nothing was ever classified and nothing was ever drawn.
2. **One-shot discovery.** `enableCrateESP()` scanned `Workspace` once. The only follow-up was `DescendantAdded`, which fires for a Model **before** its parts are parented; `buildCrate()` found no anchor and gave up permanently.
3. **Non-recursive anchor.** `FindFirstChildWhichIsA("BasePart")` checks direct children only, so crates whose parts live in nested sub-models had no anchor.
4. **No explicit `Adornee`.** A `BillboardGui` / `Highlight` parented to a `Folder` or a nested model renders nothing without one.

**Fix:** `crateKind()` normalises names (lowercase, punctuation stripped), checks `military` / `elite` / `crate` / `loot` / `supply` / `airdrop` / `cache` / `chest` / `stash`, reads `CrateType` / `Tier` / `Rarity` / `LootTier` / `Opened` / `Looted` attributes, and excludes player characters and NPCs (see [fix #4](#4-highlight-on-unrelated-objects-when-crate-esp-is-on) for the tightened rules). `SA.GetCrates()` is read every frame by the render loop, `SA.RefreshCrates()` queues an early incremental pass, and `buildCrate()` uses `FindFirstChildWhichIsA("BasePart", true)` plus explicit `Adornee`. New `Loot` kind covers supply drops and other containers. **Print Crate Names (debug)** and **Rescan Crates** are buttons in the Crate ESP mini-tab.

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
| Tracer Lines | line from Mouse / Center / Bottom to each target | OFF |
| Off-screen Arrows | triangle on the FOV circle perimeter pointing at off-targets | OFF |
| Arrows Follow FOV | arrows share the FOV circle centre / radius | ON |
| **Text Size** | one slider for **all** ESP text (name, distance, tool, state, health) | 11 px |
| Show Health % / Text Outline | `HP: NN%` tag / label stroke | OFF / ON |
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

* `src/07_gun_specs.lua` — exact game definitions for all 19 guns, ammo damage, alt-ammo modifiers, falloff profiles, `GUN_RANGE`, `gravity`/`life`, and the `u3492.GunDamage` formula. Also the 3 v7.7 bow ids (`hunting_bow` 350, `crossbow` 500, `compound_bow` 400 studs/s) with live `Workspace.Gravity` and `SA.IsEquippedBow()`.
* `src/08_prediction.lua` — smoothed target velocity, live ping, an exact intercept solver and the debug helpers.

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

1. **Velocity** — `SA.TargetVelocity(model)` samples `HumanoidRootPart.Position` into a weak-keyed, exponentially smoothed estimate (`alpha = clamp(dt*12, 0.15, 0.6)`, teleports >120 studs/s dropped).
2. **Exact intercept** — solve `|(p₀ − o) + v·t|² = (s·t)²` for the smallest positive root, where `s` is the equipped gun's real speed. For a stationary target this is exactly `distance/speed`; for a moving target it accounts for the target closing/retreating during flight.
3. **Bullet drop** — for guns with `gravity`, aim above by `½·g·t²` and re-derive the flight time from the new aim point (`Solver Iterations`, 1–8, default 4). Guns without gravity converge in one pass.
4. **Latency** — `SA.LeadLatencyMs()` (auto ping × scale + manual offset) is added **once** as `tTotal = flightTime + latency`, never once per iteration.
5. **Bounds** — flight time is clamped to the gun's `life` (projectile despawn), and the result reports `inRange` against `GUN_RANGE` (default 550).

`SA.Predict(origin, targetPos, model)` returns `aimPoint, info`. `info` carries `t`, `total`, `speed`, `velocity`, `lead`, `drop`, `latency`, `range`, `inRange`, `expired`, `id`, `ammo`, `gravity`. Silent aim uses it on every snap; the snapline uses it to draw the gold lead ring.

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
| Saturday2 Damage | OFF | Use the `s2Damage` branch of `GunDamage` |
| Muzzle Boost Equipped | OFF | Apply +15% rate / −10% damage |
| Show Lead Marker | ON | Gold ring at the predicted aim point (Visual tab, with colourpicker) |

Debug buttons (Visual → Debug): **Print Silent Aim (v7.7)**, **Retry Tap / Bow Hooks**, **Print Manip State (v4)**, **Print Gun Spec**, **Print Prediction** (now also prints measured ping / scale / offset / total), **Print Live Ping** (Aiming → Ballistics), **Print Draw Backend**, **Sync Gun Defs (GC)** and **Print Current Target**.

### Live game hooks

* `SA.SyncGunDefs()` scans `getgc(true)` for tables containing `GUN_RANGE` / `GUNS` and merges live `speed`, `gravity`, `life` and `range` into the static DB. It is opt-in (button), `pcall`-guarded and does nothing if `getgc` is unavailable.
* The equipped tool is resolved via `ItemId` / `WeaponId` / `ToolId` / `Item` / `Weapon` / `Gun` attributes or the tool name, normalised against the `model` names (`SemiAutoPistol`, `LRSniper`, `ScarRifle`, …) and display names. Unknown tools fall back to 1000 studs/s / 550 range and are flagged `[UNKNOWN]`.
* `SA.Saturday2 = fn` and `SA.S2Damage = function(id, spec) ... end` can be assigned at runtime if the game exposes them; `GunDamage` then uses the `s2Damage` branch automatically. Otherwise it uses `Defs[ammo].damage × damageMult`.
* `SA.Predict` assumes the game applies `gravity` as constant downward acceleration on the projectile. If a given gun has no visible drop in-game, turn **Bullet Drop Compensation** off.
* `Fust.Remotes.Shoot` is hooked once (opt-in via **Bow Shoot Hook**) so the bow's `data.dir` / `data.origin` come from `SA.ResolveShot()`. It also tracks the bow draw state from `data.draw` packets. The hook is `pcall`-guarded and simply never installs if `hookfunction` / the remote is unavailable; guns are unaffected.

## Best settings for wall penetration

Wall penetration = the **FOV-aware wall peek** (`Aiming → Wall Penetration`, now **Manipulation v4**). It temporarily disables `CanQuery` on the wall parts in front of you for the hit-scan, then restores them in the same frame's restore bind. It is FOV-gated, so it only spends raycasts on targets that are actually inside your aim cone. v4 adds 8 peek directions, a target-aware ray filter, and an adaptive peek that grows with distance.

**Recommended all-round setup** (press **Apply Recommended Wall Pen** to set all of it at once) — these are the v7.7 defaults:

| Setting | Value | Why |
|---|---|---|
| Enabled (FOV-aware, v4) | **ON** | Turns on the peek/disable-restore cycle. |
| Wall Check | **OFF** | Strict LOS-only mode. It is bypassed automatically while Manipulation is ON anyway — with it ON *and* penetration OFF, shots behind any wall are aborted. |
| Range | **1000 studs** | Raised from 75; adaptive peek now handles long shots. The distance check is a hard gate, not a search radius. |
| Base Peek Offset | **20** | Starting side clearance. The actual peek is `clamp(20 + 6% of distance, 20, cap)`. |
| Adaptive Peek Cap | **120** | Hard ceiling so the ray origin never drifts arbitrarily far from the crosshair. |
| Max CanQuery Parts | **48** | Raised from 3 so layered cover (wall + props + fences) can be cleared. Entries are reused, so the restore pass stays cheap. |
| Ray Budget / Frame | **96** | Raised from 64 to match the 8 peek directions (each costs up to 7 rays). Drop to **48** on low-end devices. |
| Cache Hysteresis | **3 frames** | Keeps the same peek active instead of re-scanning every frame when you strafe. |
| Max Peek Delta | **40** | Now compared against `max(40, adaptivePeek)`, so a legitimate long-distance peek is never rejected by a tiny delta cap. |
| Aim / Circle Radius (FOV) | **~150 px** | A narrower cone means fewer candidate peeks per frame — the single biggest CPU saving. Also moves the off-screen arrows. |
| Hit Chance | **100 %** | No random skipped shots while you're testing penetration. |
| Cooldown | **0 s** | Fire as fast as the weapon allows. |
| Prediction | **ON** | The ballistic solver compensates moving targets; penetration doesn't help if the shot lands behind them. |
| Target Bone | **Head** | Smaller target → fewer ambiguous multi-part peeks. |

Two useful variants:

* **Strict / legit** — Manipulation `OFF`, Wall Check `ON`, FOV `~120`, Hit Chance `60–80`. Only shoots what you can genuinely see.
* **Heavy cover / static targets** — keep the recommended values but raise `Max CanQuery Parts` to `64` and `Ray Budget` to `128`; keep FOV at `150` so the extra rays stay bounded. If you want the old light-touch behaviour, use `Range 75 / Peek 4 / Parts 3 / Budget 64 / Hyst 5 / Delta 6` — the sliders still cover those values.

The snapline and the red ESP colour are your penetration indicator: **green = you already have line of sight, no penetration needed; red = a wall is in the way**.

## UI: Atlanta

`src/21_ui_aiming.lua` loads the [Atlanta library](https://github.com/i77lhm/Libraries) and builds the window; parts 22–26 build the tabs.

```
Aiming   → Silent Aim / Gun (incl. Tap-Fire Reorder, Tap Window, Bow Shoot Hook) · Target / Ballistics / Wall Penetration (v4)
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
* **FOV controls:** `Show FOV Circle` (ON), `FOV Centre` (Mouse / Screen Center), `Force ScreenGui Drawing` (ON), `Aim / Circle Radius`, plus `Print FOV State` / `Print Draw Backend` in Visual → Debug.
* **Crate controls:** `Invert Crate State`, `Lid Angle Detection` (OFF), `Print Crate States (debug)` in ESP → Crate ESP.
* Quick actions: Disable All (also clears NPC ESP + snapline), Apply Blatant, Toggle Manip, **Reset ESP Colours**, Unload Everything (hides the window, hides the FOV circle and stops the scanners via `SA.Alive`), Scan All Entities — plus Rescan NPCs, Rescan Crates, Print Crate Names and the debug print buttons.

Two things from the Atlanta template that were intentionally **not** copied: the duplicated `vis, other` multi-section block, and `window.esp_section:esp_preview({})` (it clones your character and assumes an `Animate` script, so it errors on spawn/respawn). Everything else from the template's init block is kept: `open_tab()`, `config_list_update()`, the theme pass, and `old_config = get_config()` — each guarded with `pcall` where it touches filesystem/config APIs.

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

Parts 01–02 (shared helpers), 05–06, 10 are slices of the original script with a 5-line comment header. New / rewritten parts: `02_drawing.lua` (Drawing compatibility), `02_workspace_scan.lua` (single yielding walker), `03_entity_scan.lua` (NPC registry), `04_entity_info.lua` (scanner), `07–08` (gun specs / prediction), `14–15` (NPC ESP), `16–17` (crate detection / registry / refresh), `18` (ESP FX, three parts) and `19` (render loop). `09` was rewritten to use `SA.Predict`; `11–13` gained the lead marker, visibility colours and scanner labels; 21–26 are the Atlanta UI. The old prediction, velocity cache, hardcoded speed table, and the hit-log / hit-sound part were removed. Only `26_banner.lua` has a top-level `return`.

## Files

| Part | What's in it | Lines |
|---|---|---|
| `src/01_config.lua` | services, `CFG` defaults + backfill (**v7.7 manip/tap keys**), `SA` state, `bindRender`, **48-colour palette** | 326 |
| `src/02_drawing.lua` | **per-kind capability probing**, ScreenGui proxy, no-op fallback, draw diagnostics | 306 |
| `src/02_shared.lua` | **FOV reference point** (`SA.AimPoint` / `SA.FovRadius`), checks, target picking | 166 |
| `src/02_workspace_scan.lua` | **single incremental Workspace walker**, `SA.RegisterScanHandler` / `RequestScan` | 116 |
| `src/03_entity_scan.lua` | NPC registry handler + LOS visibility cache | 90 |
| `src/04_entity_info.lua` | entity scanner: tool/weapon + state + roster + console dump | 131 |
| `src/05_manipulation.lua` | **Manipulation v4**: shared RaycastParams, 8-direction peek, adaptive peek, target-aware filter, reused CanQuery entries | 215 |
| `src/06_firing_and_guns.lua` | **v7.7 firing state** (0.35 s tap window, InputEnded stamp, bow draw state) + snap cooldown | 65 |
| `src/07_gun_specs.lua` | exact gun DB: speeds, ammo, damage, alt ammo, falloff, ranges + **3 bow ids / SA.IsEquippedBow** | 268 |
| `src/08_prediction.lua` | **live ping**, smoothed velocity, quadratic intercept, drop, latency, debug | 221 |
| `src/09_silent_aim.lua` | **Silent Aim v7.7**: Fix A/B connection reorder, idempotent tap snap, bow remote hook, shared `SA.ResolveShot`, render-step camera binds | 432 |
| `src/10_fov_circle.lua` | **FOV circle**, tolerant writes, backend recovery, `SA.FovState` | 144 |
| `src/11_snapline.lua` | aim preview line + target/lead markers | 117 |
| `src/12_esp_players.lua` | player ESP objects, box, health bar, info label | 95 |
| `src/13_esp_players_refresh.lua` | player ESP refresh (visibility + scanner + HP) + enable/disable | 108 |
| `src/14_esp_npcs.lua` | NPC ESP objects + enable/disable + events | 110 |
| `src/15_esp_npcs_refresh.lua` | NPC ESP refresh (visibility + scanner + HP) | 88 |
| `src/16_esp_crates.lua` | crate classification, **strict opened-state resolver**, anchors, GUI objects | 353 |
| `src/16_esp_crates_registry.lua` | live crate registry, **crate-state debug**, walker diagnostics | 113 |
| `src/17_esp_crates_refresh.lua` | crate refresh (filters, state, highlight gate) + enable/disable + events | 83 |
| `src/18_esp_fx_colours.lua` | palette helpers, lazy drawing factory, skeleton / screen / box geometry | 128 |
| `src/18_esp_fx_draw.lua` | **unified styling**: text size, boxes, chams, skeleton, tracers, FOV arrows, fade | 241 |
| `src/18_esp_fx_frame.lua` | per-frame `SA.ApplyEspFx` for players / NPCs / crates | 128 |
| `src/19_render_loop.lua` | master render loop: ESP refresh + build caps + FX pass | 56 |
| `src/20_gun_mods.lua` | generation-guarded GC scan gun mods | 89 |
| `src/21_ui_aiming.lua` | Atlanta setup, binding helpers, Aiming tab (Target / Ballistics / **Wall Pen v4 / tap-fire controls**) | 193 |
| `src/22_ui_esp.lua` | ESP tab: player / NPC / crate / features / **48 colourpickers** | 209 |
| `src/23_ui_gunmods.lua` | Gun Mods tab | 22 |
| `src/24_ui_visual.lua` | Visual tab (FOV centre/backend, snapline, **v7.7 silent-aim / manip debug**) | 100 |
| `src/25_ui_misc.lua` | Misc tab, quick actions (incl. Reset ESP Colours), UI init, **full v7.7 unload** | 84 |
| `src/26_banner.lua` | startup banner (**v7.7 status**), `return CFG` | 41 |

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
