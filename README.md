# Hanami

`@abusegpt` suite — silent aim, wall penetration, player/NPC/crate ESP, entity scanner, aim snapline, ballistic prediction and gun mods — with an **Atlanta** UI.
The original 1,300-line script is split into **35 short files** (`src/`, largest is 417 lines) plus a short **loader**.

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
| **Every gun's attributes updated (20 guns)** | Aiming → Ballistics | See [Ballistic prediction](#ballistic-prediction). All 20 guns now carry `mag`, `spread`, `adsSpread`, `moveSpread`, `reload`, `recoil`, `rate`, `auto`, `s2Damage`, `scope`, `headGuard`, `shellReload`, `rocket`, `huntOnly` / `duelOnly` plus the new **Arena Rifle** (`duel_rifle` / `duel_ammo`) and the named `Falloff` table. **Print Gun Table** dumps all of them; **Sync Gun Defs (GC)** now refreshes every numeric field from the live game. |
| **Prediction auto-tunes for attachments** | Aiming → Attachments (Auto) | See [Attachments & auto prediction tuning](#attachments--auto-prediction-tuning). All 12 attachments are auto-detected off the equipped tool; a silencer re-tunes bullet speed (and therefore lead + drop), sights/grips fold aim-time into the one latency term, and the solver adds a refinement pass and stops on convergence. No manual toggle needed — slot overrides are provided as a fallback. |
| **Silent aim / manipulation are guns only** | Aiming → Gun | See [Bow mods](#bow-mods-instant-charge--no-cooldown). The bow Shoot remote hook, bow gun specs, arrow prediction and draw/hold state are gone; `saLockActive()` bails out while any bow is equipped. |
| **Two bow mods: instant charge + no cooldown** | Gun Mods → Bow Mods | Only those two features from the pasted bow-mods script were ported — instant full draw and `SHOT_GAP`/`REDRAW_GAP`/`MIN_DRAW` + `lastShot` clearing. NoDrop, instant reload, no recoil, infinite ammo, no air block and everything else were **excluded**. See [Bow mods](#bow-mods-instant-charge--no-cooldown). |
| **ESP Preview actually works** | floating "ESP Preview" panel · ESP → Player ESP | See [ESP preview](#esp-preview). A real 3D `ViewportFrame` with your live box, corner boxes, name, distance, weapon/state, health bar, `VIS`/`WALL`, skeleton, head dot, tracer, chams tint and rainbow — all driven by `CFG` / `ESP_COLORS`. Survives spawn, respawn, re-execute and unload. |
| **Player ESP works for every player** | ESP → Player ESP | See [Player ESP reliability fix](#player-esp-reliability-fix). The build queue no longer starves players behind failed builds, respawns rebuild, custom/streamed rigs resolve, and one bad character can't abort the whole refresh. New **Print Player ESP State** / **Rebuild Player ESP** buttons. |
| **Silent Aim v7.7 (tap-fire fixed)** | Aiming → Silent Aim / Gun | See [Silent aim v7.7 & manipulation v4](#silent-aim-v77--manipulation-v4). Render-step-only snapping is no longer the sole path: InputBegan / Tool.Activated connection reorder snaps the camera **before** the game fires, tap window widened to 0.35 s, and one shared shot resolver keeps the FOV circle as the reference point. **Guns only** — bows are skipped. |
| **Tahoma ESP layout (weapon below, flags at the corner)** | ESP → ESP Features | See [ESP text layout](#esp-text-layout-tahoma-weapon-below-flags-at-the-corner). Player/NPC/crate labels are now screen-space Tahoma `TextLabel`s anchored to the box geometry: name above, distance at the top-left corner, **weapon below the box**, and `VIS`/`WALL`, state and HP stacked beside the top-right corner. The world-anchored BillboardGui text is hidden so nothing is drawn twice. The floating ESP Preview mirrors the same layout. |
| **Classic manip sliders + recommendation back** | Aiming → Wall Penetration | See [Best settings for wall penetration](#best-settings-for-wall-penetration). Six sliders again — **Range 0–300 studs**, **Base Peek 4–6 only**, Parts 0–8, Budget 8–128, Hysteresis 0–12, Max Peek Delta 2–12 — and the old `75 / 4 / 3 / 64 / 5 / 6` recommendation button. The dead "Adaptive Peek Cap" is gone and every remaining slider has a real, clamped effect. |
| **Actually compiles in the executor** | loader | See [Luau 200-local-register fix](#7-the-luau-200-local-register-compile-error). The old join hit `Out of local registers ... exceeded limit 200` at `playerSec` and never ran. The loader now hoists column-1 `local`s into the chunk environment, so the main chunk needs zero local registers. |
| **FOV circle fixed + made the aim reference** | Visual → FOV Circle / Snapline | See [FOV fixes](#fov-fixes--one-reference-point). Now defaults ON, draws through a reliable ScreenGui backend, and its centre + radius are the single reference used by silent aim, snapline, tracers and arrows. |
| **Crate opened / unopened labels fixed** | ESP → Crate ESP | See [Crate state fixes](#crate-state-fixes). The inverted labels came from a Y-rotation destructuring bug plus false-positive state guesses. Added strict state parsing, `Invert Crate State` and a state debug print. |
| **No more ~3 s frame skip** | everywhere | See [Stability & fixes](#stability--fixes). One shared, yielding Workspace walker replaces both `GetDescendants()` scanners; GUI builds are capped; stale render loops disconnect on re-execute. |
| **One text-size slider for ALL ESP text** | ESP → ESP Features → Text Size | Scales name, distance, weapon, `VIS`/`WALL`, state and health % on players, NPCs **and** crates together, with row spacing derived from the same value. Plus `Show Health %`, `Text Outline`, `Tags On Box Side` and `Tag Backdrops` toggles. |
| **FOV circle actually shows** | Visual → FOV Circle / Snapline | `SA.NewDraw` falls back to real Roblox GUI Frames when the executor has no usable `Drawing` API; no longer gated on aim being ON; transparency slider now means what it says (0 % = solid). ON by default. |
| **Auto Ping Lead** | Aiming → Ballistics | Reads live `lp:GetNetworkPing()` (or `Stats.Network.ServerStatsItem["Data Ping"]`), smooths it, and feeds it into the ballistic solver. `Ping Scale` × ping + `Extra Ping Offset (ms)` = total extra lead. Old manual-only `Extra Lead` is now an offset on top. |
| **No stray crate Highlight** | ESP → Crate ESP | `Crate Chams Highlight` is **OFF** by default. Classification now requires a container-like Model/BasePart with a real crate signal, and the `Highlight` is bound to the crate's own anchor part only — never a whole folder of scenery. |
| **Skeleton / Head Dot / Tracer / arrows work** | ESP → ESP Features | All `Drawing.new` calls now go through the compatibility layer, and skeleton + head dot also render on crate ESP (a spine and a top marker). |
| **Off-screen arrows follow FOV** | ESP → ESP Features → Arrows Follow FOV | Arrows sit on the FOV circle perimeter using the **same centre and radius** as the drawn circle; change `Aim / Circle Radius` and the arrows move with it. Also points at on-screen targets *outside* the aim cone. |
| **48 colourpickers** | ESP → Colours | One clearly-labelled picker for **every** drawn element (players, NPCs, crates, snapline, FOV, lead, target). All write into one shared `ESP_COLORS` table that survives re-execution. |
| **Customizable visibility colours** | ESP → Colours · Player / NPC | Green (clear LOS) / red (blocked) are now obvious labelled pickers, not tiny swatches buried on unrelated toggles. They paint an outer frame, a visibility dot and the `VIS` / `WALL` tag even when per-element colours are on. |
| **Crate diagnostics** | ESP → Crate ESP | **Print Crate Names (debug)** lists every container-ish instance with its class, classified kind and parent, so the exact names your game uses can be found. |
| **Ballistic prediction** | Aiming → Ballistics | Replaced the old one-step `distance/speed` guess with an exact quadratic intercept solve using each gun's real `speed`, bullet drop, alt ammo, live ping and range. See the next section. |
| **Player visibility check** | ESP → Player ESP | Box, name, fill and the `VIS` / `WALL` corner tag turn **green when there is a clear line of sight** and **red when a wall blocks it**. Cached camera raycast (~120 ms). |
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
| 3 | **One bad player aborted everything.** `refreshESP()` and `SA.ApplyEspFx()` were single unguarded `pairs()` loops. A failed raycast, destroyed `Head`, or a `Drawing` property write that throws on this executor stopped the loop, so every remaining player silently kept the previous frame. | Every player is refreshed/styled inside its own `pcall`; each of the four render passes is `pcall`-guarded separately. `SA.IsVisible()` also handles degenerate zero-length rays and wraps the raycast. Errors are throttled to one console line per 5 s. |
| 4 | **Rigid rig requirements.** `buildESP()` demanded `Head` + `HumanoidRootPart` + `Humanoid` by exact name and rejected `hum.Health <= 0`. R6/R15 differences, streamed characters and custom rigs were dropped at build time. | `SA.PlayerRig()` falls back through `RootPart`, `UpperTorso`, `Torso`, `PrimaryPart` and any `BasePart`, with `HeadPart` / root as the head anchor. Dead players are built then **hidden** by the refresh instead of churning the queue. |
| 5 | **Ghosts from a previous execution.** `espObjects` was a fresh table on every run, so old `BillboardGui`s and drawing lines were never removed; their old render loop disconnects, leaving frozen boxes that look like "working" players. | `espObjects` persists through `_G` and is purged on load, including `o.fx` drawings and `Highlight`s. |

A simulation of the old queue with 8 players (2 permanently unbuildable at the front) built **0 of 6** valid players after 30 frames; the new queue builds **6 of 6 within 3 frames**.

**Diagnostics** (ESP → Player ESP):

* **Print Player ESP State** — one console line per player with the exact reason (`NO CHARACTER`, `NO ROOT PART`, `DEAD`, `NOT BUILT (waiting for build slot)`, `STALE (character changed)`, `STALE GUI (destroyed)` or `BUILT`), plus built/total count and the active draw backend.
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

The refreshes (`13`, `15`, `17`) now write a small structured `o.tx` table — `name`, `dist`, `weapon`, `tags` — instead of only concatenating one string. The old BillboardGui labels are still populated as a fallback/data source but hidden by the FX pass, so no text is drawn twice. Crates use the same layout with their `OPENED` / `UNOPENED` state as the corner tag. The floating **ESP Preview** panel mirrors the layout live, including the `VIS` ↔ `WALL` alternation.

**Tahoma.** Roblox's `Enum.Font` does **not** contain a `Tahoma` member (only Legacy / Arial / Gotham / SourceSans / …), and native `Drawing.new("Text")` fonts are limited to UI / System / Plex / Monospace. `01_config.lua` therefore resolves the font once and exposes `SA.ApplyEspFont(label)`:

1. `Enum.Font.Tahoma` if the executor patches the enum;
2. otherwise `Font.fromName("Tahoma", Regular, Normal)` → `TextLabel.FontFace`;
3. otherwise `Font.new("rbxasset://fonts/families/Tahoma.json", …)`;
4. otherwise the bundled `Enum.Font.ArialBold` so text is **never** invisible.

All four ESP label sets (players, NPCs, crates, preview) and the new screen-space labels go through that helper; `Print Draw Backend` in Visual → Debug reports the resolved font name. If a client cannot load a Tahoma family, ArialBold is used automatically — there is no setting to break the text. `SA.NewDraw("Text")` is deliberately GUI-only, so it works on the same executors as the Line / Circle / Triangle fallback.

## Silent aim v7.7 & manipulation v4

`src/05_manipulation.lua`, `src/06_firing_and_guns.lua` and `src/09_silent_aim.lua` were **rewritten** with the v7.7 camera-snap implementation. The old code is gone: the render-step binds now only cover held-fire snapping and restoration, while taps are handled before the game's fire handlers run.

### Why tap-fire needed fixing

The old build only changed `camera.CFrame` inside a `BindToRenderStep` callback. Games that fire their `Shoot` remote **synchronously from `InputBegan` or `Tool.Activated`** had already sent the shot with the unsnapped camera by the time the render step ran, so single taps missed while holding fire worked. v7.7 adds two reorders:

* **Fix A — `InputBegan` reorder.** Read every existing connection's `Function`, disconnect them, install a snap-first connection, then reattach the originals. The camera is therefore snapped when the game's fire handler runs, and a double `task.defer` restores it after nested `task.spawn(fire)` paths finish. Hanami improves on the extract here: if *any* connection's function cannot be read, it aborts **without disconnecting anything** (the extract disconnected first and could leave the game with no input handlers).
* **Fix B — `Tool.Activated` reorder.** Same idea, per equipped tool, for games that fire from the tool's Activated signal. Tools are marked with `__saTapHooked` so re-executing never double-hooks.
* **Tap window 0.2 → 0.35 s**, and `InputEnded` now also stamps `last`, so a fast press+release is still inside the window.
* **Idempotent tap snap.** Some games dispatch from both signals; only the first snap in an input event is allowed, otherwise the second would capture the already-snapped CFrame as "real" and leave the camera stuck on the target. A 1 s TTL clears stale state if a restore ever fails.

All hooks are installed **once** and dispatch through `SA.TapSnap()` / `SA.TapRestore()` / `SA.InstallTapReorder()`, so re-executing the loader never leaves stale closures or stacks hooks. `Visual → Debug → Retry Tap Hooks` retries if `getconnections` was unavailable at load, and **Print Silent Aim (v7.7)** reports the status.

### Bows removed from aim (guns only) & two bow mods

Silent aim and manipulation now work **only for guns**. The whole bow aim path was deleted:

* The three bow ids (`hunting_bow` / `crossbow` / `compound_bow`), their projectile speeds, arrow `Workspace.Gravity` drop and `isBow` fields are gone from `07_gun_specs.lua`; bows resolve to no ballistic spec at all.
* The `Fust.Remotes.Shoot` hook (`hookfunction` + `newcclosure`), `SA.BowShot()`, bow draw/hold state (`BowDrawing` / `BowSnapHold`) and the "Bow Shoot Hook" toggle are gone. A re-execution purge in `09_silent_aim.lua` neutralises any stale hook left by an older run: `SA.BowShot` becomes a pass-through returning the untouched packet, and the retired `SA.*` fields are cleared.
* `saLockActive()` is the single gate — `SA.Alive` + `CFG.masterEnabled` + `CFG.gunEnabled` + **not** `SA.IsEquippedBow()`. `SA.ResolveShot()`, `SA.TapSnap()` and the render-step snap all go through it, and `saManipResolve()` has a second defensive bow check, so no ray is cast for a bow.
* Bow tools are skipped by tap-fire Fix B. `SA.IsEquippedBow()` / `SA.IsBowTool()` are plain name/attribute classifiers (word stems, `elbow` excluded) with no ballistic data — they exist only to *disable* aim.

Instead, bows get exactly two quality-of-life mods from the pasted script. See [Bow mods](#bow-mods-instant-charge--no-cooldown): **Instant Charge** and **No Shot Cooldown**. They change the bow's own timing only, never its aim.

### What was deliberately kept

The extract is a *debug extract* — its `flags["sa_lock"]` is empty, `bowCombatState` / `bowConstants` are nil stubs, and its prediction is a one-step `distance / speed` guess with a 25-entry `saBulletSpeeds` table. Porting those verbatim would have regressed features built earlier:

* **Prediction** stays `SA.Predict()` — exact quadratic intercept with per-gun `speed`, bullet drop, alt ammo, `life`/range bounds and live ping (`08_prediction.lua`).
* **Gun data** stays the exact `u3492` / `u3338` definitions (`07_gun_specs.lua`), not the extract's speed table.
* **FOV is still the one reference point**: `SA.AimPoint()` + `SA.FovRadius()` drive target picking, the circle, snapline, tracers and arrows. The extract measured from `GetMouseLocation()` directly and created its own `Drawing` circle — that duplicate was not ported.
* The master switch is `CFG.masterEnabled` + `CFG.gunEnabled` + `SA.Alive` + `not SA.IsEquippedBow()` (not `flags["sa_lock"]`), so **Unload Everything** stops the tap hooks and a bow never engages aim.

### New controls

| Control | Where | Default |
|---|---|---|
| Tap-Fire Reorder (Fix A/B) | Aiming → Gun | ON |
| Tap Window (s) | Aiming → Gun | 0.35 |
| Enable Bow Mods | Gun Mods → Bow Mods | OFF |
| Instant Charge (max draw) | Gun Mods → Bow Mods | OFF |
| No Shot Cooldown | Gun Mods → Bow Mods | OFF |
| Base Peek Offset (4–6 only) | Aiming → Wall Penetration | 4 |
| Range / Parts / Budget / Hysteresis / Max Delta | Aiming → Wall Penetration | 30 / 3 / 40 / 3 / 6 |
| Apply Recommended Wall Pen | Aiming → Wall Penetration | 75 / 4 / 3 / 64 / 5 / 6 |
| Tags On Box Side / Tag Backdrops | ESP → ESP Features | ON / ON |
| Print Silent Aim (v7.7), Retry Tap Hooks, Print Manip State (classic), Print Bow Mods State | Visual → Debug | — |

A one-time migration in `01_config.lua` pulls saved v7.7 profiles back into the classic ranges; **every load** clamps all six manip values into their slider bounds, retires `manipMaxPeek` and drops the retired `saBowHook` flag. Custom values inside the new ranges are left alone.

## Bow mods (instant charge + no cooldown)

Only the **Bow Mods** part of the pasted `anti-externa.wtf` script was ported, and only **two** of its features. Bows are no longer aimed (see above); these two toggles change the bow's own charge / cooldown timing and nothing else.

| Requested | What it does | Tables touched |
|---|---|---|
| **Instant Charge (max draw)** | Every frame sets `drawStart = os.clock() - 10` on the live bow state, so the game always sees a fully drawn shot. Works whether the game's clock is `os.clock()` or `tick()`. | `u14` live draw state |
| **No Shot Cooldown** | Zeros `SHOT_GAP` / `REDRAW_GAP` / `MIN_DRAW` on the bow config table and keeps `lastShot = -math.huge` on the live state, so the fire gate never blocks. Original constants are saved and restored when the toggle goes off. | `u10` config + `u14` live state |

**Explicitly NOT ported:** `NoDrop` / the `Items.BowSpec` wrap, `Instant Reload` (crossbow `u17`), `NoRecoil` / tremble / sway (`u185`), `InfiniteAmmo`, `NoAirBlock` / the `u16.blocked` wrapper, the WindUI, hit log, hit sound, damage tracker, ESP, and the script's gun mods. None of those behaviours are implemented — they are only named in the "not copied" comment; the only live toggles are the two requested ones.

`src/20_bow_mods.lua` follows the same pattern as `src/20_gun_mods.lua`:

* A generation-guarded `getgc(true)` scan every 1.5 s (only while the master switch and at least one mod are on), yielding every 1000 tables. Tables are matched by shape with `rawget` — five numeric constants for `u10`, five typed fields for `u14` — rather than by name.
* `setreadonly(tbl, false)` unfreezes only matched tables; `rawget` / `rawset` bypass `__index` / `__newindex` on plain Lua tables. No metatable is written.
* A per-frame `bindRender` pass rewrites `drawStart` / `lastShot` and re-zeroes the config constants in case the game resets them. Switching a mod off, the master off, or **Unload Everything** calls `SA.BowModsRestore()` to put the saved `SHOT_GAP` / `REDRAW_GAP` / `MIN_DRAW` values back and reset `lastShot` to `0`. The saved originals live in `_G.__saBowSaved`, so re-executing the loader cannot mistake the already-zeroed values for the originals.
* `SA.BowModsState()` reports whether `getgc` / `setreadonly` are available, how many config / live tables were found and how many are patched. **Print Bow Mods State** (Gun Mods → Bow Mods and Visual → Debug) prints it.

**Controls** — Gun Mods → Bow Mods: `Enable Bow Mods` (master, OFF by default — turn it on first), `Instant Charge (max draw)`, `No Shot Cooldown`, `Print Bow Mods State`, `Restore Bow Timings`. New `CFG` keys `bowModsEnabled` / `bowInstantCharge` / `bowNoCooldown` are backfilled and bound through `hn_` flags; **Disable All** and **Unload Everything** turn them off and restore the timings.

Requires an executor with `getgc` + `setreadonly`; without them the scan simply never runs (no errors, no changes). Table shapes come from the pasted script and are game-specific — if nothing is found, **Print Bow Mods State** reports `u10=0 u14=0`.

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
* `src/08_prediction.lua` — smoothed target velocity, live ping, an exact intercept solver, adaptive refinement and the debug helpers.

### Gun data

`speed` is the projectile speed — it is **not** called `bulletSpeed`. Values already include the `u3338.GUNS` overrides (`bolt_action_rifle` 2600 → **2200**, `lr_sniper` 3000 → **2600**). `hunt_smg` shares the `custom_smg` override. The pasted item table omits `gravity` for the four SMGs, so their previously validated `u3338` drop (`8` / `1 s`) is retained; only the two scoped rifles list gravity in the paste. **Sync Gun Defs (GC)** overwrites any of these with the live game values.

The solver's per-gun inputs are `speed`, `gravity`, `life` and `range`. The remaining attributes are carried on the resolved gun object, folded into the attachment auto-tune, and printed by **Print Gun Spec** / **Print Gun Table** / **Print Attachments**. `duel_rifle` (**Arena Rifle**, `duel_ammo`) is new; it is a `semi_auto_rifle` clone, so its `duel_ammo` base damage is assumed equal to `rifle_ammo` (40) and it inherits the `semi_auto_rifle` falloff and attachment fit.

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

**All the new attributes, per gun** (identical to the pasted `Guns` table; **Print Gun Table** prints the same values at runtime):

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

Debug buttons: **Print Gun Spec** (Aiming → Ballistics), **Print Gun Table**, **Print Attachments**, **Rescan Attachments**, **Sync Gun Defs (GC)** and **Print Live Ping** (Aiming → Attachments / Visual → Debug), plus **Print Silent Aim (v7.7)**, **Retry Tap Hooks**, **Print Manip State (classic)**, **Print Bow Mods State**, **Print Prediction** (now also prints ping / scale / offset / aim-time / attachments / iterations), **Print Draw Backend** and **Print Current Target** in Visual → Debug.

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

`AttFit` lists which guns accept each muzzle / under / mag attachment; sights fit any non-scoped gun (`bolt_action_rifle` and `lr_sniper` have `scope=8` and are blocked). `SA.AttachmentFits()` is **informational** — a mismatch is printed as a warning rather than silently disabling tuning, because the game may allow a combination the paste omits. `duel_rifle` is treated as a `semi_auto_rifle` clone for fit checks.

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
| ADS / movement | `gun.effSpread`, `gun.ads`, `gun.zoom` | No — diagnostics only |

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

### Diagnostics

* **Print Attachments** — detected id, slot, tag, `AttFit` warning and the exact source (`attr:Muzzle`, `child:Silencer`, `override:attOverrideSight`, …), plus base → effective speed / aim-time / mag / damage / rate.
* **Rescan Attachments** — clears the gun cache and re-detects.
* **Print Gun Spec** — every new attribute, the effective spread / recoil, and the attachment list.
* **Print Gun Table** — one row per gun with all 20 speeds, ammo, mag, pellets, rate, range, s2Damage and spread values.
* **Print Prediction** — now also prints aim-time, attachment ids, speed multiplier, iterations, ADS and effective spread.

If nothing is detected, set the four slot overrides manually (or check the tool's attributes/children with `Print Attachments`). Detection requires a real `Tool` under `lp.Character`; it does not scan the Backpack, so owned-but-not-attached mods are ignored.

## Best settings for wall penetration

Wall penetration = the **FOV-aware wall peek** (`Aiming → Wall Penetration`). It temporarily disables `CanQuery` on the wall parts in front of you for the hit-scan, then restores them in the same frame's restore bind. It is FOV-gated, so it only spends raycasts on targets that are actually inside your aim cone. The engine keeps the 8 peek directions (cardinals + diagonals), the single shared `RaycastParams` with the target model in the filter, and the reused `CanQuery` entries — but the **classic six-slider set** is back.

**Recommended all-round setup** (press **Apply Recommended Wall Pen** to set all of it at once — the original `75 / 4 / 3 / 64 / 5 / 6` recommendation):

| Setting | Value | Why |
|---|---|---|
| Enabled (FOV-aware) | **ON** | Turns on the peek/disable-restore cycle. |
| Wall Check | **OFF** | Strict LOS-only mode. It is bypassed automatically while Manipulation is ON anyway — with it ON *and* penetration OFF, shots behind any wall are aborted. |
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

**Why the adaptive peek was removed.** v7.7 scaled the peek with distance and then computed `deltaCap = math.max(CFG.manipMaxPeekDelta, maxPeek)`. Since `maxPeek` was always >= the peek distance, **Max Peek Delta could never reject any peek** — it was a dead slider, and the extra "Adaptive Peek Cap" slider had no analogue in the original recommendation. `05_manipulation.lua` now uses `maxPeek = CFG.manipPeek` directly and compares `peekDist <= CFG.manipMaxPeekDelta`, so all six sliders are functional. `01_config.lua` clamps each value to its UI range on every load (saved profiles, preset imports and console edits included) and removes `CFG.manipMaxPeek` from old configs.

Two useful variants:

* **Strict / legit** — Manipulation `OFF`, Wall Check `ON`, FOV `~120`, Hit Chance `60–80`. Only shoots what you can genuinely see.
* **Heavier cover** — keep the recommendation but raise `Max CanQuery Parts` to `8` and `Ray Budget` to `128`; keep FOV at `150` so the extra rays stay bounded. For long-range work use `Range 300 / Peek 6 / Delta 12`.

The snapline and the red ESP colour are your penetration indicator: **green = you already have line of sight, no penetration needed; red = a wall is in the way**.

## UI: Atlanta

`src/21_ui_aiming.lua` loads the [Atlanta library](https://github.com/i77lhm/Libraries) and builds the window; parts 22–26 build the tabs.

```
Aiming   → Silent Aim / Gun (incl. Tap-Fire Reorder, Tap Window; GUNS ONLY) · Target / Ballistics / Wall Penetration (classic) · Attachments (Auto) · Overrides & Diagnostics
ESP      → Player ESP (incl. Print Player ESP State / Rebuild Player ESP / Show ESP Preview Panel / Rebuild ESP Preview) / NPC ESP · Crate ESP / ESP Features · Colours (Player / NPC / Crate / Global)
Gun Mods → Gun Mods · State Overrides · Bow Mods (Enable / Instant Charge / No Cooldown)
Visual   → FOV Circle / Snapline · Debug
Misc     → Info · Quick Actions

floating "ESP Preview" panel (Atlanta window.esp_section)
         → 3D render · Enabled / Rotate Model / Spin Speed
         → Rebuild Character · Print Preview State
```

* **Every widget writes straight into `CFG`** through its `callback`, and every `default` is read from `CFG`. Building the menu never resets the settings kept in `_G.__saCFG`.
* Flags are prefixed `hn_` so they can't collide with the library's own config flags. `setFlag("someKey", value)` and `setToggle(obj, value)` are what the presets and quick actions use, so the UI stays in sync when values change programmatically.
* **Keys:** `RightShift` toggles silent aim (chained keybind on the master toggle), `Insert` shows/hides the menu (Atlanta default).
* **48 colourpickers** live in `ESP → Colours` and write straight into `ESP_COLORS`. Chained onto `label` rows (labels expose `right_holder`), each has a unique `hn_col_<key>` flag. FOV / snapline / lead / target colours moved here from the Visual tab so there is exactly one picker per colour. `Reset ESP Colours` restores defaults and syncs the swatches.
* The old Shaman `RadioButton` preset is now a `Custom / Legit / Blatant` dropdown ("Custom" is the default so opening the menu doesn't apply a preset). The `Bullet Speed Override` slider (0–3000) now lives in the Ballistics section.
* **FOV controls:** `Show FOV Circle` (ON), `FOV Centre` (Mouse / Screen Center), `Force ScreenGui Drawing` (ON), `Aim / Circle Radius`, plus `Print FOV State` / `Print Draw Backend` in Visual → Debug.
* **Crate controls:** `Invert Crate State`, `Lid Angle Detection` (OFF), `Print Crate States (debug)` in ESP → Crate ESP.
* Quick actions: Disable All (also clears NPC ESP + snapline + bow mods), Apply Blatant, Toggle Manip, **Reset ESP Colours**, Unload Everything (hides the window, hides the FOV circle, disposes the ESP preview, restores bow timings and stops the scanners via `SA.Alive`), Scan All Entities — plus Rescan NPCs, Rescan Crates, Print Crate Names and the debug print buttons.
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

**Controls** — in the preview panel: `Enabled`, `Rotate Model`, `Spin Speed` (0–90 °/s), `Rebuild Character`, `Print Preview State`. In ESP → Player ESP: `Show ESP Preview Panel` (re-opens the floating window) and `Rebuild ESP Preview`. `Print Preview State` reports whether the model is a clone or the dummy rig, the part count, the panel/viewport visibility and why a fallback was used.

New config keys: `espPreview` (ON), `espPreviewSpin` (ON), `espPreviewSpeed` (25), all backfilled for older saved configs and bound to Atlanta widgets.

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

Parts 01–02 (shared helpers), 05–06, 10 are slices of the original script with a 5-line comment header. New / rewritten parts: `02_drawing.lua` (Drawing compatibility), `02_workspace_scan.lua` (single yielding walker), `03_entity_scan.lua` (NPC registry), `04_entity_info.lua` (scanner), `07–08` (gun specs / **attachments** / prediction), `14–15` (NPC ESP), `16–17` (crate detection / registry / refresh), `18` (ESP FX, three parts) and `19` (render loop). `09` was rewritten to use `SA.Predict`; `11–13` gained the lead marker, visibility colours and scanner labels; `08_attachments.lua` is the 12-attachment auto-tune scanner; `20_bow_mods.lua` is the two-feature bow-mods GC scan; `22_esp_preview*.lua` are the ESP Preview panel; 21–26 are the Atlanta UI. The old prediction, velocity cache, hardcoded speed table, and the hit-log / hit-sound part were removed. Only `26_banner.lua` has a top-level `return`.

## Files

| Part | What's in it | Lines |
|---|---|---|
| `src/01_config.lua` | services, `CFG` defaults + backfill (**classic manip/tap, bow-mods, attachment keys, Tahoma font resolver**), `SA` state, `bindRender`, **48-colour palette** | 411 |
| `src/02_drawing.lua` | **per-kind capability probing**, ScreenGui proxy, **screen-space Tahoma `Text` draw**, no-op fallback, draw diagnostics | 413 |
| `src/02_shared.lua` | **FOV reference point** (`SA.AimPoint` / `SA.FovRadius`), checks, target picking | 166 |
| `src/02_workspace_scan.lua` | **single incremental Workspace walker**, `SA.RegisterScanHandler` / `RequestScan` | 116 |
| `src/03_entity_scan.lua` | NPC registry handler + **guarded** LOS visibility cache | 97 |
| `src/04_entity_info.lua` | entity scanner: tool/weapon + state + roster + console dump | 131 |
| `src/05_manipulation.lua` | **Manipulation (classic sliders, guns only)**: shared RaycastParams, 8-direction peek, fixed 4–6 peek, clamped functional sliders, target-aware filter, reused CanQuery entries | 231 |
| `src/06_firing_and_guns.lua` | **v7.7 firing state** (0.35 s tap window, InputEnded stamp; no bow state) + snap cooldown | 56 |
| `src/07_gun_specs.lua` | **all 20 guns + every attribute** (mag / spread / ads / move / reload / recoil / s2 / scope / tags), ammo, damage, alt ammo, 8 named falloffs, ranges + **name-only bow gate** | 326 |
| `src/08_attachments.lua` | **12 attachment defs**, `AttFit` / slots / tags, tolerant tool scanner, **auto-tune effects** + `SA.*Attachments*` diagnostics | 417 |
| `src/08_prediction.lua` | **live ping**, smoothed velocity, quadratic intercept, drop, adaptive iterations, attachment aim-time lead, debug / gun table | 297 |
| `src/09_silent_aim.lua` | **Silent Aim v7.7 (guns only)**: Fix A/B connection reorder, idempotent tap snap, `saLockActive()` bow gate, stale-hook purge, shared `SA.ResolveShot`, render-step camera binds | 375 |
| `src/10_fov_circle.lua` | **FOV circle**, tolerant writes, backend recovery, `SA.FovState` | 144 |
| `src/11_snapline.lua` | aim preview line + target/lead markers | 117 |
| `src/12_esp_players.lua` | **Player ESP v2**: tolerant `SA.PlayerRig`, re-execute purge, char tracking, half-build cleanup, diagnostics | 213 |
| `src/13_esp_players_refresh.lua` | **per-player pcall refresh**, structured `o.tx` text (weapon / tags), respawn detection, lifecycle hooks | 197 |
| `src/14_esp_npcs.lua` | NPC ESP objects + enable/disable + events | 110 |
| `src/15_esp_npcs_refresh.lua` | NPC ESP refresh (visibility + scanner + HP + structured `o.tx` text) | 104 |
| `src/16_esp_crates.lua` | crate classification, **strict opened-state resolver**, anchors, GUI objects | 353 |
| `src/16_esp_crates_registry.lua` | live crate registry, **crate-state debug**, walker diagnostics | 113 |
| `src/17_esp_crates_refresh.lua` | crate refresh (filters, state, structured `o.tx` text, highlight gate) + events | 90 |
| `src/18_esp_fx_colours.lua` | palette helpers, lazy drawing factory, skeleton / screen / box geometry | 128 |
| `src/18_esp_fx_draw.lua` | **unified styling**: Tahoma screen-space text (name / dist / weapon / corner tags), boxes, chams, skeleton, tracers, FOV arrows, fade | 287 |
| `src/18_esp_fx_frame.lua` | per-frame `SA.ApplyEspFx` with **per-player error isolation** | 141 |
| `src/19_render_loop.lua` | master render loop: **rotating success-only build queue**, 4 guarded passes, FX pass | 103 |
| `src/20_bow_mods.lua` | **Bow mods (2 features only)**: Instant Charge + No Cooldown, GC scan, originals saved/restored, `SA.BowMods*` diagnostics | 190 |
| `src/20_gun_mods.lua` | generation-guarded GC scan gun mods (7 toggles) | 89 |
| `src/21_ui_aiming.lua` | Atlanta setup, binding helpers, Aiming tab (Target / Ballistics / **classic Wall Pen sliders + recommendation / tap-fire controls / guns-only note / attachment auto-tune column**) | 238 |
| `src/22_esp_preview.lua` | **ESP Preview core**: state/teardown, safe clone + dummy rig, ViewportFrame overlays, Tahoma labels mirroring the new layout | 397 |
| `src/22_esp_preview_setup.lua` | **ESP Preview build + lifecycle**: panel clamp, camera/render bind, respawn hook, controls, `SA.EspPreview*` API | 223 |
| `src/22_ui_esp.lua` | ESP tab: player / NPC / crate / features (**Tahoma layout toggles**) / **48 colourpickers** / diagnostics buttons | 231 |
| `src/23_ui_gunmods.lua` | Gun Mods tab + **Bow Mods section (2 toggles + diagnostics)** | 45 |
| `src/24_ui_visual.lua` | Visual tab (FOV centre/backend, snapline, **guns-only debug, bow-mods state, attachment / gun-table prints**) | 107 |
| `src/25_ui_misc.lua` | Misc tab, quick actions (incl. Reset ESP Colours), UI init, **full v7.7 unload + preview dispose + bow timing restore** | 91 |
| `src/26_banner.lua` | startup banner (**v7.7 + guns-only + bow mods + attachment status**), `return CFG` | 54 |
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
