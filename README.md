# Hanami

`@abusegpt` suite — silent aim, wall penetration, player/NPC/crate ESP, entity scanner, aim snapline, ballistic prediction and gun mods — with an **Atlanta** UI.
The original 1,300-line script is split into **44 short files** (`src/`, largest is 1296 lines) plus a short **loader** and a committed static/Fengari validation harness.

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
| **Crate ESP FOV-aware** | ESP → Crate ESP | Default OFF. Outside the aim circle = one dot; inside = name + distance and an outline-only `Highlight`. No boxes or corners. `SA.CrateFovState()`. |
| **100m player warning** | Visual → Nearest HUD | Fixed-threshold red crosshair badge when any other player is within 100 metres. No team filter. `SA.PlayerWarningState()` / `SA.PlayerWarningRefresh()`. |
| **Triggerbot / Auto Fire** | Aiming → Trigger / Auto Fire | **Fire Assist Wall Check** (`CFG.fireWallCheck`, default OFF) requires a **VIS target in FOV** for both features; with it OFF Auto Fire clicks continuously without a target. Independent of silent aim's `CFG.wallCheck`; Manipulation Support cannot bypass it. Head Only, Random Hit Part, Specific Hit Part, Manipulation Support gate, `Tool:Activate()` first with `mouse1click` / `mouse1press` fallback and `SA.FireAssistState()`. |
| **Force Head (Silent Aim)** | Aiming → Target | Default OFF override for Target Bone / Per-Weapon Bone, so silent aim resolves Head whenever the rig has one. `SA.ForceHeadState()`. |
| **NPC manipulation support** | Aiming → Manipulation | Default OFF. NPC targets (Guard / Scavenger / Soldier, tagged or folder NPCs) now use the same six-slider peek / `CanQuery` wall bypass as players, with a dedicated **Manipulate NPCs** toggle, NPC-aware crosshair popup, `SA.IsNpcModel()`, `SA.ManipNpcState()` and an explicit `SA.ManipPossible(npcModel)` read-only probe. |
| **Clean ESP (outlines only)** | ESP → ESP Features | Default OFF. Removes the dark tag pills and chams fill that covered the top of the screen; keeps a thin box outline, chams outline and black text stroke. `Apply Clean ESP` / `SA.CleanEspState()` and a one-click toggle are included. |
| **Manipulation crosshair popup** | Visual → Nearest HUD | Small READY / BLOCKED / OFF badge above `SA.AimPoint()` (the FOV/crosshair reference). `SA.ManipPossible()` is a read-only probe: it checks clear LOS, 8-direction peek and CanQuery wall bypass without spending the ray budget or changing `CanQuery`. Toggle and refresh controls included. |
| **BETTER quality-of-life pass** | all five tabs | See [BETTER quality-of-life pass](#better-quality-of-life-pass). Native config profiles, programmatic self-check state, real full unload, top-N HUD, all-keybind manager, ESP decluttering, aim/FOV UX, real-model side-by-side Preview, committed Fengari tests, adaptive performance and live gun tuning. |
| **Native Atlanta config profiles + saved colour pickers** | Misc → Config Profiles | Save / load / delete / export / import / reset / auto-load in Atlanta's own `configs` directory. Every `hn_*` flag (including keybind tables) round-trips through `library:get_config()` / `library:load_config()`, and all 50 inline colour picks are saved in the profile JSON + a sidecar. |
| **Programmatic self-check state** | `SA.SelfCheck()` | Returns a report table (checks / passed / warned / failed) covering executor capabilities, `hn_*` coverage, keybind conflicts, draw-write failures and a config round-trip. No panel, no button, no console output. |
| **Real full unload** | Misc → System + Atlanta → Configurations → Options → Unload Menu | Both unload paths call `SA.FullUnload()`: direct render / service hooks, native Drawing objects, GUI proxies, world BillboardGuis / Highlights, Hanami ScreenGuis and the Atlanta blur are all removed; a plain menu hide keeps ESP active. |
| **Staff / admin ESP detector (read-only)** | ESP → Player ESP → Staff / Admin Detector | One role tag per player — `STAFF` / `ADMIN` / `NONE` — plus the separate `AdminESP` flag. Reads the Fust StaffState attributes, the `AdminMovedAt` heuristic and public team / rank text. Off by default; no warnings, no notifications, no attribute writes, no aim or gun changes. |
| **Unknown humanoid detector (read-only)** | Misc → Detectors (read-only) | Count and names of humanoids that are neither a real player nor a known NPC class, reported as `UNKNOWN`. A replicated `Bait` / `LiveBait` attribute is shown as evidence only. Off by default; never labels `LiveBait`, never removes anything from silent aim, never warns. |
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
| **Tracer lines + off-screen arrows are player-only** | ESP → ESP Features | See [New ESP visuals](#new-esp-visuals-all-in-esp--esp-features). When their toggles are ON, only players draw them; NPC / crate ESP and the NPC ESP Preview never create those drawings. |
| **Every gun's attributes updated (20 guns)** | Aiming → Ballistics | See [Ballistic prediction](#ballistic-prediction). All 20 guns now carry `mag`, `spread`, `adsSpread`, `moveSpread`, `reload`, `recoil`, `rate`, `auto`, `s2Damage`, `scope`, `headGuard`, `shellReload`, `rocket`, `huntOnly` / `duelOnly` plus the new **Arena Rifle** (`duel_rifle` / `duel_ammo`) and the named `Falloff` table. The full per-gun attribute set lives in `SA.GUN_SPECS`; **Sync Gun Defs (GC)** refreshes every numeric field from the live game. |
| **Prediction auto-tunes for attachments** | Aiming → Attachments (Auto) | See [Attachments & auto prediction tuning](#attachments--auto-prediction-tuning). When **Auto Attachment Tuning** is ON, all 12 attachments are auto-detected off the equipped tool; a silencer re-tunes bullet speed (and therefore lead + drop), sights/grips fold aim-time into the one latency term, and the solver adds a refinement pass and stops on convergence. It starts OFF by default; slot overrides are provided as a fallback. |
| **Camera-snap resolver / gun manipulation are guns only** | Aiming → Gun | See [Bow mods](#bow-mods-instant-charge--no-cooldown). The v7.7 camera-snap / tap-fire resolver and gun manipulation skip bows; the dedicated, default-OFF Fust bow hook below handles ballistic arrows separately. |
| **Two bow mods: instant charge + no cooldown** | Gun Mods → Bow Mods | Only those two features from the pasted bow-mods script were ported — instant full draw and `SHOT_GAP`/`REDRAW_GAP`/`MIN_DRAW` + `lastShot` clearing. NoDrop, instant reload, no recoil, infinite ammo, no air block and everything else were **excluded**. See [Bow mods](#bow-mods-instant-charge--no-cooldown). |
| **V16.46-style Gun Mods + local Brightness** | Gun Mods / Visual → Utilities | All 12 `C.Gun` settings (`NoSpread`, `ShotProbe`, `InspectDefs`, `InspectScripts`, `InspectGunControl`, `InspectLiveGun`, `NoRecoil`, `CameraKickFilter`, `FireRate`, `FireRateMultiplier`, `InfiniteAmmo`, `MoveShoot`) plus a clamped 0–0.5 `ColorCorrectionEffect`. See [V16.46-style gun mods](#v1646-style-gun-mods-brightness-and-shot-probe). |
| **Hitbox Expander v2 (silent / R6-R15 / players + NPCs)** | Aiming → Hitbox Expander v2 | See [Hitbox Expander v2](#hitbox-expander-v2). Toggle + target / mode dropdowns and scale / cap / distance / team / alive / visibility controls, plus a default-OFF **Expand NPC Hitboxes** switch. Live NPC registry models, **NPC HRP fallback**, self-healing Size hooks, reversible originals and accessory CanQuery restore. |
| **ESP 60 FPS frame-budget pass** | Visual → Performance Mode | See [ESP 60 FPS frame-budget pass](#esp-60-fps-frame-budget-pass). Time-based **60 FPS frame budget** is active with Performance Mode OFF, plus **per-property instance writes**, draw **usage marks**, hoisted helpers, direct box segments, `SA.EspGeometryBudget()` slicing, `SA.EspGeomState()` cache stats and `geometryStride` / `geometryBudget` in `SA.EspFrameBudget()`. `SA.EspFrameBudget()` exposes the frame budget to code. |
| **Fust bow ballistic silent aim + peek-origin wallbang** | Aiming → Fust Bow | See [Fust bow ballistic silent aim](#fust-bow-ballistic-silent-aim). Default-OFF `hookfunction` on `ReplicatedStorage.Fust.Remotes.Shoot.FireServer`: gravity-compensated arrow velocity, FOV target pick, 8-direction peek origin rewrite behind cover. Guns are untouched; hook restores on dispose / unload. |
| **ESP Preview actually works** | floating "ESP Preview" panel · ESP → Player ESP | See [ESP preview](#esp-preview). A real 3D `ViewportFrame` with your live box, corner boxes, name, distance, weapon/state, health bar, `VIS`/`WALL`, skeleton, head dot, tracer, chams tint and rainbow — all driven by `CFG` / `ESP_COLORS`. Now mirrors **either** the Player or NPC pipeline, including archetype colours. Survives spawn, respawn, re-execute and unload. |
| **ESP-only best preset + fixed FOV overlays** | ESP → ESP Features · ESP Preview panel | See [Best ESP](#best-esp-players--npcs). A fresh session applies the readable Player/NPC ESP preset automatically; **Apply Best ESP** re-applies it. Player, NPC and crate ESP use the live FOV reference point and clear stale edge overlays instantly, including a one-time cleanup when Gun Silent Aim or the snapline toggles. Gun mods, Visual, Misc and every non-ESP feature except the visible FOV circle stay OFF. |
| **Player ESP works for every player** | ESP → Player ESP | See [Player ESP reliability fix](#player-esp-reliability-fix). The build queue no longer starves players behind failed builds, respawns rebuild, custom/streamed rigs resolve, and one bad character can't abort the whole refresh. A **Rebuild Player ESP** button clears the build queue after a big server change. |
| **Silent Aim v7.7 (tap-fire fixed)** | Aiming → Silent Aim / Gun | See [Silent aim v7.7 & manipulation v4](#silent-aim-v77--manipulation-v4). Render-step-only snapping is no longer the sole path: InputBegan / Tool.Activated connection reorder snaps the camera **before** the game fires, tap window widened to 0.35 s, and one shared shot resolver keeps the FOV circle as the reference point. **Guns only** — bows are skipped. |
| **Live-font ESP layout (weapon below, flags at the corner)** | ESP → ESP Features | See [ESP text layout](#esp-text-layout-tahoma-weapon-below-flags-at-the-corner). Player/NPC/crate labels are now selected-font screen-space `TextLabel`s anchored to the box geometry: name above, distance at the top-left corner, **weapon below the box**, and `VIS`/`WALL`, state and HP stacked beside the top-right corner. The world-anchored BillboardGui text is hidden so nothing is drawn twice. The floating ESP Preview mirrors the same layout. Clean ESP mode keeps the same labels but removes their dark background pills, leaving only text outlines. |
| **Classic manip sliders + recommendation back** | Aiming → Wall Penetration | See [Best settings for wall penetration](#best-settings-for-wall-penetration). Six sliders again — **Range 0–300 studs**, **Base Peek 4–6 only**, Parts 0–8, Budget 8–128, Hysteresis 0–12, Max Peek Delta 2–12 — and the old `75 / 4 / 3 / 64 / 5 / 6` recommendation button. The dead "Adaptive Peek Cap" is gone and every remaining slider has a real, clamped effect. |
| **Actually compiles in the executor** | loader | See [Luau 200-local-register fix](#7-the-luau-200-local-register-compile-error). The old join hit `Out of local registers ... exceeded limit 200` at `playerSec` and never ran. The loader now hoists column-1 `local`s into the chunk environment, so the main chunk needs zero local registers. |
| **FOV circle fixed + made the aim reference** | Visual → FOV Circle / Snapline | See [FOV fixes](#fov-fixes--one-reference-point). Now **ON at load / 1% transparent / solid / 3px thick**, draws through a reliable ScreenGui backend, and its live mouse / crosshair centre + radius are the single reference used by silent aim, snapline, tracers and arrows. |
| **Crate opened / unopened labels fixed** | ESP → Crate ESP | See [Crate state fixes](#crate-state-fixes). The inverted labels came from a Y-rotation destructuring bug plus false-positive state guesses. Added strict state parsing and an `Invert Crate State` toggle. |
| **No more ~3 s frame skip** | everywhere | See [Stability & fixes](#stability--fixes). One shared, yielding Workspace walker replaces both `GetDescendants()` scanners; GUI builds are capped; stale render loops disconnect on re-execute. |
| **One text-size slider for ALL ESP text** | ESP → ESP Features → Text Size | Scales name, distance, weapon, `VIS`/`WALL`, state and health % on players, NPCs **and** crates together, with row spacing derived from the same value. Plus `Show Health %`, `Text Outline`, `Tags On Box Side` and `Tag Backdrops` toggles. |
| **Visible FOV reference circle + thick independent snapline** | Visual → FOV Circle / Snapline | `SA.NewDraw` falls back to real Roblox GUI Frames when the executor has no usable `Drawing` API; the circle is **ON at load**, **1% transparent / solid**, 3px thick and always centred on the live mouse / crosshair FOV reference point. The snapline is **3px by default**, works with **just its own toggle ON** (no Silent Aim master / gun prerequisite) and has a separate 1–10 size slider. |
| **One on-player label on FOV entry** | ESP → Player ESP · Visual → FOV Circle / Snapline | When a target enters the aim circle, `SA.EspHideDuplicateOverlays()` hides orphan `HanamiPlayerGui` BillboardGuis, duplicate `espObjects` slots and stale edge labels once, leaving exactly **one on-player label** at the real projection. `SA.EspDuplicateCleanupState()` reports hidden objects / ghosts / labels. |
| **Draggable nearest-player profile card** | Visual → Nearest HUD | Default-OFF companion HUD now shows a **Roblox headshot** with initials fallback, display / account name, UserId, distance, HP, VIS / team, weapon name and a separate **Equipped / Holstered / Unknown** state chip. Real pointer drag on the header persists for the session; **Reset HUD Position** restores the selected corner. `SA.GetWeaponStatus()`, `SA.NearestWindowState()` and `SA.NearestWindowResetPosition()` are the state APIs. |
| **Auto Ping Lead** | Aiming → Ballistics | Reads live `lp:GetNetworkPing()` (or `Stats.Network.ServerStatsItem["Data Ping"]`), smooths it, and feeds it into the ballistic solver. `Ping Scale` × ping + `Extra Ping Offset (ms)` = total extra lead. Old manual-only `Extra Lead` is now an offset on top. |
| **No stray crate Highlight** | ESP → Crate ESP | `Crate Chams Highlight` is **OFF** by default. Classification now requires a container-like Model/BasePart with a real crate signal, and the `Highlight` is bound to the crate's own anchor part only — never a whole folder of scenery. |
| **Skeleton / Head Dot / Tracer / arrows work** | ESP → ESP Features | All `Drawing.new` calls now go through the compatibility layer, and skeleton + head dot also render on crate ESP (a spine and a top marker). **Tracer lines + off-screen arrows are PLAYER-ONLY** — NPCs and crates never draw them. |
| **Off-screen arrows follow FOV (PLAYERS ONLY)** | ESP → ESP Features → Arrows Follow FOV | Arrows sit on the FOV circle perimeter using the **same centre and radius** as the drawn circle; change `Aim / Circle Radius` and the arrows move with it. Also points at on-screen targets *outside* the aim cone. Player ESP only. |
| **9 additional themes + 10 font picks** | Visual → Theme / Font | Ten named Atlanta presets (9 additional beyond the original) and 10 popular script-community font picks. One **Visual → Theme** dropdown applies all 9 Atlanta theme colours at once; the font dropdown restyles the menu and live ESP / preview labels. |
| **Inline white colourpickers + ESP-only best startup** | beside their own controls | All 48 customizable colours are **default white**; every non-ESP feature except the visible FOV circle starts OFF. The ESP-only best preset is applied on a fresh session and config profiles save the picked colours. Pickers sit beside the toggle / slider / dropdown they belong to, never in a separate tab or section. |
| **50 inline colourpickers** | Player / NPC / Crate / ESP Features / Visual controls | One picker for **every** drawn element, chained onto its own control row. All write into one shared `ESP_COLORS` table that survives re-execution. |
| **Customizable visibility colours** | Visibility Check / crate / snapline rows | VIS / WALL, crate type and global overlay pickers are white until customised. They paint an outer frame, a visibility dot and the `VIS` / `WALL` tag even when per-element colours are on. |
| **Ballistic prediction** | Aiming → Ballistics | Replaced the old one-step `distance/speed` guess with an exact quadratic intercept solve using each gun's real `speed`, bullet drop, alt ammo, live ping and range. See the next section. |
| **Player visibility check** | ESP → Player ESP | Box, name, fill and the `VIS` / `WALL` corner tag use the chosen visibility colours (white by default) for clear LOS / behind a wall. Cached camera raycast (~120 ms). |
| **FOV snapline** | Visual → FOV Circle / Snapline | Line + dot to the target in the chosen VIS / WALL colours, plus a **lead ring** in the chosen lead colour at the exact point the solver aims at. |
| **NPC silent aim / NPC ESP** | Aiming + ESP | `pickBestTarget` selects from players **and** the NPC registry. Separate section for `Guard`, `Scavenger`, `Soldier`, with name/distance/health box, visibility colours and scanner options. |
| **Entity scanner** | ESP tab + Misc | Reads an equipped `Tool`, `ItemId` / `Weapon` / `HeldItem` attributes and weapon containers, plus `Downed` / `Knocked` / `Dead` / `State` attributes with a `HumanoidStateType` fallback. `Show Weapon` and `Show State` are options on **both** player and NPC ESP; `VIS` / `WALL` is a third tag. |
| **Wall-pen description** | Aiming → Wall Penetration + below | Tooltips, three in-UI labels, and a one-click **Apply Recommended Wall Pen** button. |

NPC detection accepts the literal model names `Guard` / `Scavenger` / `Soldier`, the common `Scavenger`/`IsNpc`/`NPC` attributes, and models inside `Npcs` / `Enemies` folders. Real player characters are explicitly excluded.

## BETTER quality-of-life pass

This pass implements the eleven highest-value ideas from the previous audit. It is a UI / reliability upgrade, not a change to the guns-only silent-aim or two-bow-mods scope.

### Native Atlanta config profiles

Misc → **Config Profiles** uses Atlanta's own `Atlanta/configs` directory and `library:get_config()` / `library:load_config()`, so the built-in Configurations list stays in sync. Save, load, delete, export to clipboard, import from clipboard, reset to shipped defaults and auto-load the last profile are all native. `SA.ConfigCoverage()` reports any unbound `hn_*` flag; `SA.TestConfigRoundTrip()` proves the serialised flag snapshot is stable, including keybind `{mode, key, active}` tables and colour pickers. **Saved colour pickers** are now explicit: `SA.EspColorSnapshot()` writes all 48 `#RRGGBB` values into the config JSON under `__saEspColors` and into a `<profile>.colors` sidecar; `SA.EspColorRestore()` re-applies them through the inline `hn_col_*` setters on load / import. This does not depend on an Atlanta build that happens to serialise colourpicker flags.

### Programmatic self-check state

`SA.SelfCheck()` returns a report table (`checks` / `passed` / `warned` / `failed`) covering the render loop, FPS, local character, camera, executor capabilities (`gethui`, `getgc`, `setreadonly`, `getconnections`, `hookfunction`, filesystem / clipboard), drawing backend, write failures, ESP objects, 48 white colours, UI flags, `hn_*` coverage, keybind registrations / conflicts, every state API, draw pool, nearest HUD, no-target reason and a config round-trip. `SA.SelfCheckState()` returns the last report. There is no panel, no button and no console output: static checks still cannot prove an executor's real globals, so in-game verification remains manual.

### Real full unload

Both Misc → **System → Unload Everything (FULL)** and Atlanta's Configurations → **Options → Unload Menu** call `SA.FullUnload()`. A plain RightShift / Insert **menu hide is not an unload**: ESP, the FOV circle and the nearest-player HUD remain visible while the menu is minimised.

Atlanta's built-in **Unload Menu** only destroys `library.guis` and disconnects `library.connections`; Hanami's ESP uses direct `RenderStepped` / service hooks, native `Drawing` objects, GUI proxies, world `BillboardGui` / `Highlight` instances and ScreenGuis outside that registry. A wrapper on that one button preserves Atlanta's stock behaviour and then runs the same complete teardown as the Misc button. `SA.FullUnload()` turns every visual feature OFF, disposes the FOV circle / snapline / draw pool via `SA.DrawDisposeAll()`, destroys named orphan ESP instances and Hanami-owned GUIs via `SA.DisposeHanamiGuis()`, disconnects every direct hook via `SA.DisconnectConnections()`, unbinds the aim render steps, restores camera / manipulation / bow / gun / hitbox state and clears shared globals. `SA.VisualState()` reports live / visible / pooled draws, Hanami GUIs and tracked connections; `SA.FullUnloadState()` records the trigger and post-cleanup report. A loader re-execute starts fresh instead of inheriting stale loops or overlays.

### Read-only staff / admin and unknown-humanoid detectors

Both detectors are **passive**: they read replicated data, draw one ESP tag or one Misc readout, and change nothing else. Neither writes an attribute, starts a notification, prints to the console, or alters silent aim, gun state or world visuals. Both ship **OFF**.

**ESP → Player ESP → Staff / Admin Detector** adds one role tag per player. `SA.GetStaffRole()` (`player, character`) classifies from (1) the Fust StaffState attribute list — `AdminRole`, `AdminESP`, `AdminFly`, `AdminGhost`, `AdminMasterOff`, `FustTester`, `StaffPvP`, `StaffPvPLockUntil`, `StaffPvPExempt`, `AdminGod`, `FustStaffAv` — plus the `AdminMovedAt` heuristic, and (2) public rank text: the player's `Team.Name` and the ordinary replicated `StaffRank` / `GroupRank` / `Rank` / `Role` / `TeamRole` attributes. The tag is `ADMIN` when the evidence is admin-level (`AdminRole`, `AdminGod`, `AdminMasterOff`, `AdminFly`, `AdminGhost`, an admin team, or an admin word in the rank), `STAFF` for the remaining staff evidence, and `NONE` for an ordinary player — so the control answers "admin or not" for every slot. A replicated `AdminESP` attribute is appended as a separate ` · ADMINESP` suffix instead of being folded into the role. The two tag colours have their own inline pickers (`staffTag`, `adminTag`, both shipped white, bound to the toggle). `SA.StaffDetectState()` returns `players` / `staff` / `admins` / `names` / `adminNames` for other players only, and the ESP tab shows a 1 Hz `staff N · admins N (of M players)` line.

**Misc → Detectors (read-only) → Unknown Humanoid Detector** drives `SA.UnknownHumanoidState()`: every humanoid that is not a real player and not a known NPC class is reported as `UNKNOWN` with its name. Known classes are recognised by the NPC name patterns (`Guard`, `Scavenger`, `Soldier`, `Sleeper_`, `Dino` / `Raptor` / `Rex` and the animal set) and by the shared NPC classifier, so the existing NPC ESP keeps owning them. A replicated `Bait` / `LiveBait` attribute is surfaced only as **evidence** under a separate `game-tagged N` counter — the model is never renamed, never labelled `LiveBait`, and never excluded from silent aim, triggerbot or any targeting path. The registry is fed by the same incremental workspace walker as the NPC / crate registries (`SA.RegisterScanHandler("unknownHumanoids", …)`), so no `GetDescendants()` call and no second render loop is added; the Misc readout shares the existing 1 Hz ESP tab tick. `SA.ScanStep()` / `SA.ScanPassNow()` drive that shared walker deterministically for tests, and `SA.UnknownHumanoidKind()` / `SA.UnknownHumanoidEvidence()` / `SA.UnknownHumanoidListRaw()` expose the same read-only data. Turning the toggle OFF clears the list immediately, and `SA.FullUnload()` clears `_G.__saUnknownHumanoids`.

### Player ESP no longer dies on one unsupported property

**Symptom:** player ESP never appeared and its toggles did nothing, while NPC ESP and crate ESP worked normally.

**Cause:** `buildESP()` in `src/12_esp_players.lua` wrapped the *entire* player build in a single `pcall` — BillboardGui, three TextLabels, `Highlight`, six `Line` draws **and** the `espObjects[plr] = {...}` registration. A client that rejects any one property (the usual suspect is `Highlight.DepthMode`, which does not exist on older clients; a strict executor rejecting a `TextLabel` write does the same) threw out of that pcall, so **no object was ever registered**. The render loop then retried the same doomed build every frame, forever: no player box, no name, and the Enabled toggle appeared dead because there was nothing to toggle. NPC and crate ESP have their own builders, which is why they were unaffected.

**Fix — every optional part is isolated, and registration is unconditional:**

* the legacy BillboardGui + its three labels are built in their own `pcall`; if the GUI ends up with missing labels it is destroyed rather than left half-built;
* `Highlight` is built in its own `pcall`, and `DepthMode` is guarded *inside* that, so a client without the enum keeps the cham;
* each of the six legacy `Line` draws is created independently, and a partial pool is allowed (`lines` may be `nil`);
* `espObjects[plr]` is now written **outside** every pcall, so the object always exists and the screen-space FX pass can always draw the player — it needs no Instance text at all.

Every consumer was made nil-safe to match: `refreshOnePlayer` writes `o.bb` / `o.nameLbl` / `o.distLbl` / `o.infoLbl` / `o.lines` only when present, and `setFxLine()` falls through to a pooled draw when a legacy line slot is missing (previously that edge of the box simply disappeared).

**Regression coverage:** `tools/mocks.lua` gained `MOCK_BAD_PROP`, which makes a named instance property throw like a real client would, so this class of bug is now reproducible. `saPlayerEspWorksRegression` asserts that player ESP builds, draws a box and a name, hides everything on OFF, and — with `Highlight.DepthMode` rejected, then with a `TextLabel` property rejected — still builds *and* still draws.

### Silent aim / snapline locking onto players who are BEHIND you

**Symptom:** with the snapline (or Gun Silent Aim) on, the target highlight and the aim target jumped to somebody the player had just turned their back on — the ESP target flickered, and the snapline briefly pointed at a person who was not in view.

**Cause:** `WorldToViewportPoint` returns `(position, onScreen)`, and that second value only means **"inside the viewport rectangle"**. It is **true for a point behind the camera** — where X and Y are mirrored through the screen centre. `SA.FovPointInside` in Pixels mode trusted it and never looked at `Z`, so a player behind the camera whose mirrored pixel happened to land near the crosshair counted as "inside the FOV". `SA.FovSegmentInside` (the `FOV Hitbox` widened path) was worse: it never looked at `Z` at all, so a target straddling the camera plane passed unconditionally.

**Measured effect:** sweeping the camera through 120 frames with `FOV Hitbox` on, the old code selected a target **22 times while that player was entirely behind the camera**. After the fix: **0**.

**Fix:** both helpers now reject non-positive depth — `SA.FovPointInside` returns false when `sp.Z <= 0`, and `SA.FovSegmentInside` drops any endpoint whose `Z <= 0` before measuring the segment (so a visible head with a hidden root still counts, while a fully-behind segment does not).

`saEspBehindCameraRegression()` covers it, and was verified to fail against the pre-fix sources (`a segment with both ends behind the camera is rejected: got true, want false`).

**How this relates to the snapline.** The snapline is the feature that made the bug visible, for two reasons: it is the only consumer that *draws* the pick on screen (so a wrong pick is instant and obvious), and while it is ON it becomes the sole owner of `SA.Target.model` — `saRefreshAimTarget()` returns early, and `hideSnap()` clears the shared target on any frame with no pick. A picker that flipped on the mirrored behind-camera pixel therefore flipped the ESP's target highlight with it. With the picker corrected, snapline-on and snapline-off now measure identically on target flips, FOV transitions, style sweeps and label tracking.

### Player tag labels no longer stack, and a distant box no longer collapses

**Symptom:** a player tag rendered its name, distance and state / type rows piled into one band over the top-left corner of the box, with the tags running off past the box edge — the screenshot report.

**Cause (measured, not guessed).** Two separate defects, both reproduced by dumping every text draw's absolute rectangle in the mock:

1. **The right-hand tag column started on the name row.** With `espTagSide = true`, `18_esp_fx_draw.lua` placed tag *i* at `g.y + (i - 1) * rowH`. But `g.y` is exactly where the centred **name** sits (anchor `0.5,1`) and where the right-aligned **distance** sits (anchor `1,0`). All three landed in the same horizontal band: measured `txName` at x 598.9–681.1 and `txTag1` at x 664.4–746.6, both y 309.6–323.6 — a 16.7 × 12.0 px overlap, with the tag column then continuing outside the box. The column now starts at `g.y + rowH + 2`, below the name row.
2. **The player box had no minimum size.** `h = math.abs(hv.Y - lv.Y)` for players, while the crate path already clamped to `math.max(..., 18)`. At 200+ studs the two projections round together and `h` approaches zero, so the whole tag collapsed onto a sliver. Player boxes now clamp to the same 18 px height floor, with `w = math.max(h / 2, 12)`.

**Evidence.** `saEspTagLayoutRegression()` walks every visible text draw of a real player tag, computes each rectangle from its `Anchor`, and asserts zero overlap in **both** tag modes plus that the right-column rows start below the name row. `saEspBoxFloorRegression()` projects a player at 5 / 60 / 200 / 600 studs and asserts the box keeps its floor. Both were confirmed to **fail** against the pre-fix sources (`player tags do not overlap in right column mode: got 12.0, want 0`) and pass after.

### Player ESP switches on immediately in Performance Mode

**Symptom:** with Performance Mode ON, player ESP could stay completely empty after being switched on.

**Cause:** the frame budget paces rebuilds with `SA.PerfEffectiveRebuildMs()`, which is `clamp(base * 60 / fps, 16, 500)` — up to **300–500 ms** on a slow client. Every skipped frame also reset the accumulator, so the interval could keep restarting before it was ever reached: the observed trace was `buildSkips=12, objects=0` — twelve consecutive frames with zero player objects built. Pacing exists to spread out work once ESP is already on screen; it must never delay the *first* objects.

**Fix:** a cold-start guard in `19_render_loop.lua` forces `buildOk = true` whenever an enabled kind (`espEnabled`, `npcEspEnabled`, `crateEnabled`) still has an empty object table.

### What "stuck when turning" actually is — and what it is not

The turn-stuck report was investigated by measurement rather than assumption, and the initially suspected mechanism turned out **not** to exist:

* Sliced entities were thought to redraw stale cached projections during a fast turn (`dueGeometry()` returning a cached geometry). They do not: `18_esp_fx_frame.lua` already forces `stride = 1` on any camera change (`local stride = cameraTurned and 1`), so slicing is disabled on every turn frame, and the skipped path still runs the full FX draw pass using the cached **geometry** (never a cached *draw*), so unused draws are swept by `hideUnusedFx()` either way.
* A direct measurement — whipping the camera through nine large angles one frame each, for **both player and NPC ESP**, in **both** normal and Performance Mode, comparing the drawn name position against a fresh `WorldToViewportPoint` — gives a **0.0 px** worst-case error in all four combinations. The tag tracks the camera exactly.
* The real turn-related failure was the Performance Mode build starvation described above: after a long turn the ESP could be missing entirely rather than stale.

Both facts are now **locked in by tests** rather than by argument: `saEspCameraFollowRegression()` fails if any tag lags the camera by more than 1.5 px, and `saEspWhipRegression()` drives the real render loop through eight large angles in both modes.

### ESP rewrite: FOV crossings no longer erase an entity, NPC ESP is FOV-independent, snapline is player-only, and eight FOV drawing styles

**Root cause of "the ESP moves away while I look at it and comes back when I look away".**

Two independent defects stacked into that one symptom.

1. **An FOV crossing hid the whole entity.** `18_esp_fx_draw.lua` keys each entity on `fov.onScreen .. fov.inside` and, on any change, called `hideFx(o)` — which sets `Visible = false` on **every** pooled draw the entity owns: box, name, distance, chams. The redraw then only happened on the next frame's `getDraw()` pass. So a target sliding along the circle edge, or a camera sweep carrying the circle over a standing target, blinked the entire ESP off for a frame and back on. The same branch also set `geomForceFresh = true` and cleared `geomKey`, which deferred the fresh projection by **another** frame — that is the visible drift, not motion blur.
   **Fix:** a crossing now calls `hideFxGroup(o, "fov")`, which clears only the draws tagged into the `fov` group (the off-screen arrow, the FOV-clamped tracer, the crate dot). The box and text are re-styled from this frame's projection like any other frame. No geometry deferral, no whole-entity hide.

2. **The camera cache key was too coarse.** `espCameraKey` quantised the camera look vector with `espNum`, which rounds to `0.01`. On a unit look vector that is `asin(0.01) = 0.57°` of camera rotation silently treated as "nothing changed" — about **6 px** of stale box position at 720p / 70° FOV on every slow sweep, snapping into place when the key finally ticked over.
   **Fix:** camera keys now use a 1e-6 quantisation (`SA.EspNum6` / `SA.EspKey6` in `18_esp_fx_colours.lua`), i.e. 0.00006°, far below one pixel. Rig anchors keep the cheap 0.01 key — only the camera needs the precision.

**NPC ESP is not FOV-aware.** `18_esp_fx_draw.lua` builds a neutral snapshot for `pal == "npc"`: `onScreen` comes from the NPC's own projection, and `inside` is always `false`, so nothing in the NPC path can read the aim circle. The circle can no longer hide, clamp or re-colour a guard. `15_esp_npcs_refresh.lua` also stopped writing (and making visible) the legacy Instance box lines on every data refresh while the FX pass hid them again — that was a second writer with a different, refresh-time projection, which is why NPC boxes lagged separately from player boxes.

**Snapline is player-only.** `pickBestTarget` gained a `playersOnly` argument and `SA.PreviewTarget` passes it, so the shared preview target — the snapline, its lead marker and the ESP highlight — can never resolve to an NPC regardless of `targetNpcs`. Silent aim itself still honours `targetNpcs`.

**Every FOV drawing method is now a real option.** `Visual → FOV Circle → FOV Drawing Style`:

| Style | Primitives | Notes |
| --- | --- | --- |
| `Circle` | native Circle | the original, smoothest |
| `Segments` | Line only | polygon of `fovSegments` slices |
| `Corners` | Line only | four ~41° corner arcs |
| `Dots` | Line only | dotted ring |
| `Dashes` | Line only | dashed ring |
| `Double` | Circle + Line | concentric inner ring at 50 % |
| `Cross` | Circle + Line | ring plus four radial ticks |
| `Pulse` | Circle | radius breathes with the frame clock |

All styles read the same `SA.AimPoint()` + `SA.FovRadius()`, so a style can never desync from what silent aim uses. Line-only styles are the executorsafe path: they need `Drawing.new("Line")` and nothing else. The ring pool is rebuilt only when the style or segment count changes (`fovSegments`, 8–128, floor-normalised so a float cannot churn the key), and every draw is released through `SA.RecycleDraw`. `SA.FovState()` now reports `style`, `segments`, `ringDraws` (lines actually visible) and `ringAllocated`.

### Two FOV measurement modes (Pixels / Degrees) and hitbox-wide membership

The FOV circle used to be pixels only: `CFG.fov` was a radius around the crosshair, so 220 px meant a different cone on 1080p and on 4K and had no relation to the camera's own `FieldOfView`. The circle is now the *display* of a measurement you choose:

**`Pixels` mode (default, unchanged).** `SA.FovRadius()` returns `CFG.fov`, capped at half the shorter viewport side. Every existing profile, preset and screenshot behaves exactly as before — the pixel path is byte-for-byte the old one.

**`Degrees` mode.** `CFG.fovDegrees` is the half-angle of a cone around `cam.CFrame.LookVector` (1-89 deg). Membership is the **angle**, not a screen distance:

```
dot = (worldPos - camPos).Unit : Dot(cam.CFrame.LookVector)
inside = dot >= cos(rad(fovDegrees))
```

so the same number is the same cone at every resolution and every camera zoom, and no `WorldToViewportPoint` is needed to decide it. The circle is still drawn, at the pixel radius that angle covers on the live viewport:

```
r_px = (viewport.Y / 2) * tan(rad(deg)) / tan(rad(cam.FieldOfView / 2))
```

A 35 deg setting on Roblox's default 70 deg camera is exactly half the screen height (360 px at 720p). Narrowing `FieldOfView` (scoping in) enlarges the drawn circle, exactly as the real cone appears larger. `SA.FovRadius()` is still the single source of truth, so the circle, the silent-aim pick, the snapline, the tracers, the off-screen arrows and the crate FOV check all stay in agreement — nothing else had to learn about the mode.

**`fovHitbox` (OFF by default).** Membership used to be a single bone. With this ON, `SA.FovSegmentInside()` tests the **nearest point on the projected head-to-root segment** instead of just the bone (`SA.FovSegDist2()` is the underlying point-to-segment distance), and in Degrees mode it accepts the head, the root or the midpoint. That fixes the classic "the box is obviously inside the circle but the head bone is 3 px outside" miss. A degenerate segment (head == root) falls back to a point test, so nothing divides by zero.

New public API: `SA.FovMode()`, `SA.FovDegrees()`, `SA.FovPointInside(camera, worldPos, sp, onScreen, aimPx, radius)`, `SA.FovSegmentInside(camera, headPos, rootPos, spHead, spRoot, aimPx, radius)`, `SA.FovSegDist2(...)` and `SA.FovState2()` → `{ mode, degrees, pixels, hitbox }`. `SA.FovState()` and `SA.EspFovState()` gained `mode` / `degrees`, and the per-frame draw signature includes the mode and angle, so switching either one triggers exactly one style sweep instead of leaving a stale circle.

### Gun Silent Aim / Snapline ESP stutter, ghost drawings, staff-watch scans and NPC smoothing

Four separate bugs were fixed in this pass. All of the work lives in existing parts — **no new source / loader part** was added.

**1. ESP stuck / stuttering while Gun Silent Aim or the snapline is ON.** `src/18_esp_fx_frame.lua` builds one FOV / draw-state signature per frame and `src/18_esp_fx_draw.lua` folded it into **every entity's** own state key. That shared signature used to contain a *live-target* flag, and the aim target appears / disappears many times a second (FOV enter-leave, hit-chance roll, a `pickBestTarget` nil frame). Every flip made every player, NPC and crate run `hideFx()` + duplicate-overlay cleanup + a forced fresh-geometry pass — several full-ESP rebuilds per second, which is exactly the reported freeze. The signature is now **toggles only** and is compared **once per frame**: a real style change runs exactly one `SA.EspStyleSweep()` (one hide + one cleanup + one fresh geometry rebuild for the whole set, recorded in `SA.EspLastStyleSweep` and `styleSweeps` / `styleSweepObjects`), and the per-entity key covers only the entity's own `onScreen` / `inside` transition. The live aim target is **never part of the draw signature**.

**2. Two (three) target scans per frame.** `src/11_snapline.lua`, `src/09_silent_aim.lua` and `src/05_manipulation.lua` each called `pickBestTarget()` on their own — every player plus every NPC, one `WorldToViewportPoint` per candidate, two or three times per frame — and they could disagree about who the target was. `src/02_shared.lua` now owns **one memoised preview target per frame**: `SA.PreviewTarget()` runs the pick at most once per frame (and at most once per 20 ms), invalidates itself when the FOV centre / radius changes, and is read by the snapline, the Gun Silent Aim ESP highlight and the manipulation probe alike. `SA.PreviewTargetReset()` drops the memo; `SA.PreviewTargetState()` reports `cached` / `hit` / `stamp` / `frame` / `ttl` / `fovKey`. `01_config.lua` also gained **one per-frame clock** (`SA.FrameClock()` / `SA.FrameClockTick()`, advanced once in `bindRender`) so the 20 Hz aim refresh, the 120 ms LOS cache and the 250 ms scan cache all agree on "now" instead of expiring at different points inside one frame. With the target memo on the hot path, geometry slicing is also no longer defeated by target churn: the `espNearestSet` no longer makes a rotating member "priority", and `SA.EspPassAllowed()` no longer mutates the nearest set while it is being read.

**3. Ghost / stale drawings after a player died, teleported or streamed out.** `drawPlayerFx()` only hid an entity when its character changed or its rig vanished, so a corpse, a teleported rig and a streamed-out character kept their last box / name / tracer on screen. It now has explicit **dead** (`Humanoid.Health <= 0`), **streamed out** (`model.Parent` gone, incomplete rig) and **out of range** (teleport) branches that hide the drawings and drop the object's pooled draws, legacy-line cache and cached projection in the **same frame** (`SA.EspGhostCleanup` counts them, `lastReason` names the trigger). `13_esp_players_refresh.lua` also watches `Humanoid.Died`, `Humanoid.HealthChanged`, `Character.AncestryChanged` and `CharacterRemoving`, hiding immediately instead of waiting for the next data refresh. `hideAllOnce()` used to bail out after the first hidden pass, leaving later-built objects visible with ESP OFF — it is now per object (`fxHidden`, re-armed by `startFxFrame`), so **ghost / stale drawing cleanup** covers late objects too. `SA.DisposeEspFx()` hides before it recycles, and `SA.RecycleDraw()` / `SA.DrawPoolTake()` reset a pooled draw's `Color` / `Thickness` / `Transparency` / points so a recycled proxy cannot inherit the old owner's style.

**4. Staff watch false "INVIS" from StreamingEnabled.** The role tag was drawn from **one** read of the replicated data, so a character whose rig (or attributes) had not finished streaming in could be tagged for one frame. `src/04_entity_info.lua` now requires **3 consecutive scans** with the same positive evidence: `SA.STAFF_CONFIRM_SCANS = 3`, `SA.StaffScanOne()`, `SA.GetStaffRoleConfirmed()` and `SA.StaffWatchState()` (`raw` vs `confirmed` vs `pending`). A missing Humanoid / Head, a missing character or a clean ordinary read resets the streak to zero, so one bad frame can never accumulate. The tag shows `SCAN` / `SCAN n/3` while unconfirmed and only prints the role once it is confirmed; `SA.StaffDetectState()` counts confirmed roles only; `SA.StaffWatchReset()` clears the streaks. Still **read-only**: no attribute writes, no notifications, no warnings, no console output, no aim / gun changes.

**5. NPC ESP smoothing.** `15_esp_npcs_refresh.lua` ran `SA.ScanEntity` plus a full tag/text rebuild for every NPC on every data refresh and then let the FX pass draw the same NPC again on the same frame. The rebuild is now throttled to the ESP data interval (`npcFullDue()`); every other refresh only re-reads rig validity, distance and LOS visibility. Out-of-range NPCs drop their cached projection (no frozen label), and the legacy BillboardGui / labels stay hidden. That is the **NPC refresh throttle** covered by its own regression.

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

Aiming → **Manipulation → Manipulate NPCs** is OFF by default. When the selected target is an NPC, the existing classic resolver applies the same 8-direction wall peek, `CanQuery` part bypass, ray budget, cache, range and six sliders used for player targets. No NPC-only ray path, extra budget or separate prediction path is introduced. Target selection already had **Target NPCs**; this pass makes the resolver, read-only probe, popup and state checks explicitly NPC-aware.

`SA.IsNpcModel(model)` prefers `SA.GetNpcs()` (the shared incremental Workspace walker), falls back to the literal `Guard` / `Scavenger` / `Soldier` names, `Scavenger` / `IsNpc` / `NPC` attributes and `Npcs` / `Enemies` folders, and rejects anything returned by `Players:GetPlayerFromCharacter()`. `CFG.manipNpcs` is backfilled and clamped like the other new settings. With **Manipulate NPCs** OFF, an NPC shot keeps the original camera origin: no peek is cached and no `CanQuery` write occurs. **Target NPCs** OFF also disables NPC manipulation.

`SA.ManipPossible(npcModel)` accepts an optional explicit model override for diagnostics; without it, the popup still uses the normal FOV/crosshair picker. NPC-aware results are tagged `[NPC]` and the badge reads `MANIP NPC: READY` / `BLOCKED` / `OFF`. `SA.ManipNpcState()` reports the toggle, NPC targeting, registry count, effective range / peek / parts and whether the last real resolver target was an NPC. The probe remains read-only: no `CanQuery` writes, no peek-cache entry and no manipulation ray-budget consumption.

### Crate ESP FOV-aware

**FOV-Aware Crate ESP** is OFF by default. It uses the same `SA.AimPoint()` / `SA.FovRadius()` circle as silent aim: a crate outside the circle becomes one small dot at its screen position, while a crate inside the circle shows only its name and distance plus an outline-only `Highlight`. The FOV-aware branch returns before box, corner, fill, skeleton, visibility-dot or off-screen-arrow drawing, so it does not add corners or full boxes. `CFG.crateHighlight` only controls the old non-FOV-aware path. `SA.CrateFovState()` reports the radius, centre, inside/outside counts, dots and outline highlights.

### 100 m player warning

Visual → **Nearest HUD → 100m Player Warning** is OFF by default. Any other player within **100 metres** (1 m ≈ 3.571 studs) triggers a small red badge above the crosshair with the nearest player's name and distance. It is a fixed threshold with no team filter, updates at ~10 Hz and follows `SA.AimPoint()`. `SA.PlayerWarningState()`, `SA.PlayerWarningRefresh()` and `SA.PlayerWarningSet()` are the state API. The popup is disposed on re-execute and `SA.FullUnload()`.

### Triggerbot / Auto Fire

Aiming → **Trigger / Auto Fire** adds two independent, default-OFF features. **Triggerbot** clicks only when `SA.TriggerTarget()` finds a valid target inside the FOV circle. **Auto Fire** clicks continuously at about 12.5 Hz; both respect the existing gun cooldown and are **silent-aim independent**: only `SA.Alive` and the guns-only bow gate apply, not `CFG.masterEnabled` / `CFG.gunEnabled`.

**Fire Assist Wall Check** (`CFG.fireWallCheck`) is a dedicated, **default-OFF** toggle in the same section. It is completely independent of silent aim's Gun → **Wall Check** (`CFG.wallCheck`). With it ON, Triggerbot and Auto Fire both require a **VIS target in FOV** from the existing FOV / player / NPC target picker, using tolerant `SA.IsVisible()` — the same LOS helper behind the ESP **VIS** tag — so a **VIS player in FOV** is not rejected by a strict ray clipping a hat or accessory. **Manipulation Support cannot bypass this gate**: it may still block via `SA.ManipPossible()`, but a non-VIS target never fires. With it OFF, Auto Fire returns to continuous / no-target clicking (including when both features are ON) and Triggerbot may shoot through walls; `SA.FireAssistState().visible` still reports the ESP VIS status honestly. `SA.FireAssistState()` also exposes `wallCheck` and `autoFireGated`.

`SA.FireOnce()` tries `Tool:Activate()` first, then falls back to `mouse1click()` and `mouse1press()` / `mouse1release()`. Each Triggerbot shot briefly snaps the camera to its chosen aim point and restores it immediately afterwards. Auto Fire never adds a camera snap or aim point, even when the wall check gates its clicks.

Hit-part selection is independent of silent aim: **Head Only** is OFF by default, **Random Hit Part** wins when enabled, and the **Hit Part** dropdown offers Head / Hrp / UpperTorso / LowerTorso / arms / legs / Random with R6 + R15 name aliases. **Manipulation Support** is a strict gate: when ON, `CFG.manipulation` must be ON and `SA.ManipPossible(model, true)` must report READY. The `allowNoAim` flag keeps the identical read-only line check without inheriting silent aim's master/gun gate. `SA.TriggerBonePart()`, `SA.TriggerTarget()` and `SA.FireAssistState()` expose VIS status, backend, reason, wall-check state and silent-aim independence; full unload disposes the render bind.

### Silent aim Force Head

**Force Head (Silent Aim)** is OFF by default. `SA.ResolveTargetBone()` now returns `Head` before the classic Target Bone dropdown or `Head for snipers` / `Hrp for shotguns` per-weapon modes can select HumanoidRootPart, which was the cause of intermittent non-head shots. Turning the toggle OFF restores the previous per-weapon logic. `SA.ForceHeadState()` and `SA.SilentAimState().forceHead` report the effective bone. Triggerbot / Auto Fire part modes stay separate and never override silent aim's Force Head setting.

### Hitbox Expander v2

**Enable Hitbox Expander** (Aiming → Hitbox Expander v2) is a standalone, default-OFF feature. It covers **R6/R15 player rigs and live NPC models**: `Head`, `UpperTorso`, `LowerTorso` and R6 `Torso`, selected by the **Target Parts** dropdown (`Head` / `Torso` / `Both`). Player scope is unchanged; **Expand NPC Hitboxes** is OFF by default. It is **silent** by default — the only visual change, when **Show Expanded Parts (client only)** is ON, is `LocalTransparencyModifier = 0.55`, which never replicates to other clients.

Controls and their `CFG` keys:

| Control | Key | Default | Effect |
|---|---|---|---|
| Enable Hitbox Expander | `hitboxEnabled` | OFF | Master switch; `H` keybind |
| Target Parts | `hitboxTarget` | `Both` | `Head` / `Torso` / `Both` |
| Scale Mode | `hitboxMode` | `fixed` | `fixed` = uniform cube in studs; `multiply` = original size × Scale |
| Scale (studs / x) | `hitboxScale` | 8 | 1–30; cube side or multiplier |
| Multiply Cap (studs) | `hitboxCap` | 8 | 1–30; largest-axis cap in `multiply` mode |
| Max Distance (0 = unlimited) | `hitboxMaxDist` | 300 | 0–2000 studs; skip distant characters |
| Team Check | `hitboxTeamCheck` | OFF | Skips `SA.IsTeammate()` / same-`Team` players; NPCs are neutral and never filtered |
| Alive Only | `hitboxAliveOnly` | OFF | Skips dead Humanoids |
| Show Expanded Parts | `hitboxVisible` | OFF | Client-only faint tint |
| Expand NPC Hitboxes | `hitboxNpcs` | OFF | Expands live NPC registry models; OFF restores NPC originals while player hitboxes stay expanded |

Every affected part gets `CanCollide = false`, `CanTouch = false`, `CanQuery = true`, and an instant `GetPropertyChangedSignal("Size")` hook that re-applies the target size if the server reverts it — the **self-healing** 1–2 frame window. Hat / hair `Accessory` Handles are set `CanQuery = false` so they cannot eat the raycast. All originals (size, collision/query/touch flags, transparency modifier and accessory `CanQuery`) are saved in `_G`, so turning the toggle OFF, **Restore Hitboxes**, or **Unload Everything (FULL)** puts every value back and disconnects the hooks. `getgenv().hitbox` is still published for compatibility with the pasted script's global table; `getgenv().hitbox.npcs` mirrors the NPC switch.

**NPC support** uses the same live registry as NPC ESP: `SA.HitboxScan()` walks the `SA.NpcListRaw()` raw list on the existing generation-guarded `bindRender` pass, with no second loop or per-frame filtered copy. NPC models keep the same Target Parts / Scale Mode / Scale / Cap / Max Distance / Alive Only / Show Expanded Parts controls; **Team Check** applies to players only. An NPC with no `UpperTorso` / `LowerTorso` / `Torso` uses **NPC HRP fallback** (`HumanoidRootPart`) as its torso proxy. NPC-owned sizes, collision / query flags, tint, accessory `CanQuery`, Size hooks and `ChildAdded` hooks are tagged separately: turning **Expand NPC Hitboxes** OFF, removing an NPC from the registry, turning the master OFF, **Restore Hitboxes**, or **Unload Everything (FULL)** restores those originals without touching expanded player parts.

`SA.HitboxScan()` forces one pass, `SA.HitboxRestore()` restores all originals, `SA.HitboxState()` reports every setting plus `npcs` / `npcParts` / `npcModels` / tracked parts / accessories / hooks / scans. The main loop uses the generation-guarded `bindRender` instead of a raw Heartbeat connection, and `table.clear` was replaced with a portable clear loop so the split parts stay Lua 5.3 / Fengari-safe. Validation covers player + NPC scope, fixed / multiply / cap, target and distance filters, team / alive gates, NPC HRP fallback, self-healing, accessory silencing, NPC-toggle restore, OFF restore and full unload; see [Testing](#testing).

### Clean ESP (outlines only)

The screenshot-style ESP showed large dark pills behind every name / state / weapon tag. **Clean ESP** is now OFF by default. It removes dark tag backdrops and chams fill, and uses **outlines only**: a thin full box outline, a chams outline and a black text stroke. Corner boxes, skeleton, head dot, tracers, off-screen arrows, rainbow and distance fade are switched off by the `Apply Clean ESP` preset, so the view is no longer covered by stacked rectangles.

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

`npm ci && npm test` runs `build.sh`, `tools/verify.py`, `tools/check.js` and `tools/run.js`. `tools/mocks.lua` models Roblox datatypes, Instances, services, executor filesystem / clipboard, Atlanta widgets / config flags / keybinds, theme updates, live font instances, inline colourpicker owners and a controllable RenderStepped pump. `tools/tests.lua` executes 6,489 assertions over three runs: fresh startup, auto-load + re-execute, and re-execute after `SA.FullUnload()`, including **9 additional themes / 10 font picks**, all-nine-colour theme application, live menu + ESP label font refresh, 50 unique inline white colourpickers, ESP-only best startup with non-ESP OFF defaults, no extra render listeners / forced `perfMode`, preserved 60 FPS budget, **NPC hitbox coverage** (players stay in scope, live NPC registry rigs, HRP fallback, filters, self-healing, toggle OFF restore and full unload), Hitbox Expander fixed / multiply / cap / filters / self-healing / restore coverage, dedicated fire-assist wall-check / both-enabled / no-bypass regressions and ESP FPS optimization / coalesced GUI sync / throttled data refresh / ESP 60 FPS frame budget / per-property instance writes / live-property coherence / draw usage marks / shared projection cache / camera signature / adaptive geometry stride / teammate-map throttle / disabled-ESP hidden-pass / camera-turn fresh geometry / stale-overlay / Player, NPC and crate FOV enter/leave regressions / FOV reference point / independent thick snapline / 3px defaults / Gun Silent Aim toggle cleanup / shared aim target / customizable snapline size / saved colour pickers / Atlanta font-bootstrap sanitizer / Fust bow hookfunction / ballistic velocity / peek-origin wallbang / bow-spec / LOS / dispose / full-unload restore regressions, FOV duplicate-overlay / orphan BillboardGui cleanup, one on-player label, nearest-player Roblox headshot / initials fallback, Equipped / Holstered / Unknown weapon state, real pointer drag / session position / reset and full-unload drag cleanup, plus both unload paths / plain menu hide / draw registry / connection sweep regressions, the **shared per-frame aim-target** regression (one candidate scan per frame, draw signature immune to aim-target flicker, one sweep per style toggle), the **ghost drawing** regression (dead / teleported / streamed-out player cleanup and a late object hidden after the first hidden pass), the **3-consecutive-scan staff watch** regression (streaming-safe, read-only, streak reset) and the **NPC refresh throttle** regression (throttled tag/text rebuild, out-of-range projection drop). `tools/check.js` parses every source / tool / loader / dist chunk with luaparse, checks the 44-part list, zero column-1 locals in the hoisted bundle, one final `return`, README row / line counts, shipped / backfill / clamp / bound-widget coverage for all 77 new CFG keys, non-ESP OFF-only boolean defaults, ESP-only best startup snapshot, 50 white inline colours, no colour mini-tab, complete theme / font tables and event-driven `SA.ApplyTheme()` / `SA.ApplyFont()`, plus a static assertion that no `src/` part calls `print()` / `warn()` / `dbg()` and no print/debug UI survives in the bundle. This is static + Fengari mock validation, **not a real Roblox executor** confirmation.

## Themes, fonts, inline colours and OFF defaults

Hanami ships **9 additional themes** (10 named presets total, including the original Atlanta look) and **10 popular script-community font picks**. **Visual → Theme** is one dropdown: `SA.ApplyTheme()` applies all 9 Atlanta theme keys (`outline`, `inline`, `accent`, `contrast`, `high_contrast`, `low_contrast`, `text`, `text_outline`, `glow`) at once through `library:update_theme`. **Visual → Font** is one dropdown: `SA.ApplyFont()` resolves a built-in `FontFace` / enum, restyles Atlanta menu text and refreshes live ESP / preview labels from a weak registry. `SA.ThemeState()` / `SA.FontState()` expose the applied preset, font, counts and registered labels. The two `uiTheme` / `uiFont` CFG keys are clamped, backfilled and bound to their dropdowns, bringing coverage to all 77 new CFG keys.

Every one of the 48 customizable colours is **default white**, including VIS / WALL, NPC archetype and crate type colours. A one-time migration clears older semantic palettes; saved profiles and explicit user choices still win. Pickers are chained inline onto the exact toggle / slider / dropdown they belong to, in the same row and section — there is no separate colour tab or mini-tab.

At startup **all non-ESP feature toggles OFF** except the visible FOV circle: silent aim, trigger / auto fire, gun mods, hitbox expander, snapline, crate ESP, HUD, performance mode and every other non-ESP boolean feature stay OFF. **The ESP-only best preset** (`SA.BEST_ESP_STARTUP`) applies Player/NPC ESP, readable corner boxes, thin outlines, names, distances, health, tool / state tags, highlight target and the preview on a fresh session. `SA.FOV_STARTUP` is the only non-ESP startup exception: the FOV circle is ON, 1% transparent (solid), **3px thick**, and always centred on the live mouse / crosshair **FOV reference point**. The snapline ships **3px thick**, starts at that same reference and has a separate **customizable snapline size** (1–10), but it is **independent**: turning on Visual → Snapline alone draws the preview without enabling Silent Aim master or Gun Silent Aim. `SA.SnaplineState().independent` reports this. `SA.ResetToDefaults()` keeps this split; `SA.FullUnload()` clears the fresh-session and FOV migration markers so the next load applies it again. Explicit presets / buttons may still change features. The RightShift menu bind stays active because it is UI navigation, not a feature.

This pass is **ESP-only**: the old V16.46 Gun Mods tab (including Inspect / Report controls), old Visual / Misc sections, theme / font dropdowns and inline colourpicker behaviour are restored from the pre-all-in-one build. No automatic gun inspection, hidden gun flag, curated all-feature startup or independent random-hit-part switch was reintroduced.

Theme and font changes are **event-driven**: one pass per dropdown change and one pass at startup, never a per-frame callback and **no second RenderStepped**. The existing shared projection cache, adaptive geometry slicing, coalesced GUI sync and 60 FPS frame budget remain unchanged, targeting **60-50 FPS** without forcing `perfMode`. Static + Fengari validation can verify no extra render listeners and preserved budget state, but real Roblox FPS must still be checked in-game.

`npm test` now executes 6,489 assertions over three runs, including 9-theme / 10-font coverage, all-nine-colour application, live menu + ESP font refresh, 50 unique inline picker owners, all-white defaults, ESP-only best startup, non-ESP OFF defaults, live-property coherence, camera-turn fresh geometry, stale-overlay cleanup and the Player, NPC and crate FOV enter/leave regressions / FOV reference point / independent thick snapline / 3px defaults / Gun Silent Aim toggle cleanup / shared aim target / customizable snapline size / saved colour pickers, shared per-frame aim target / stable draw signature, ghost drawing cleanup, 3-scan staff watch, NPC refresh throttle, no extra render listeners, no forced `perfMode` and the preserved 60 FPS budget.
The **FOV duplicate-overlay regressions** cover orphan `HanamiPlayerGui` cleanup, duplicate `espObjects` slots and exactly one on-player name after FOV entry. The **nearest-player profile regressions** cover Roblox headshots, initials fallback, display / account name, UserId, weapon name + Equipped / Holstered / Unknown chip, real pointer drag, session position persistence, Reset HUD Position and full-unload cleanup. `SA.GetWeaponStatus()`, `SA.EspHideDuplicateOverlays()`, `SA.EspDuplicateCleanupState()` and `SA.NearestWindowResetPosition()` are covered by the kept-state API checks.

The **unload regressions** prove that a plain menu hide keeps ESP visible, then exercise both the Misc full-unload button and the Atlanta built-in Unload Menu button. They assert zero live drawings, zero visible drawings, an empty draw pool, zero Hanami GUIs, zero tracked connections, a disposed FOV circle and `SA.SnaplineState().enabled == false`. `SA.Connect()`, `SA.DisconnectConnections()`, `SA.DrawDisposeAll()`, `SA.DisposeHanamiGuis()`, `SA.VisualState()` and `SA.FullUnloadState()` are covered by the kept-state API checks.

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

`src/21_ui_aiming.lua` fetches the Atlanta UI library from `ATLANTA_ROOTS` (raw GitHub plus a `github.com` fallback). The upstream library bootstraps a custom TTF from `weasely111/beta`, a **dead external font asset** whose repo now returns 404. On executors that reject `getcustomasset()` on that HTML payload, the library aborts before `library:window()` and the whole script appears not to load. The committed **Atlanta source sanitizer** `SA.SanitizeAtlantaSource()` removes that bootstrap, guards `makefolder`, and installs a **built-in Roblox FontFace** from `rbxasset://fonts/families/SourceSansPro.json` (with `Font.fromEnum` / `Font.new` fallbacks) before `loadstring` compiles the library. No console output is added. The built-in SourceSansPro face is also the reliable startup default for the new 10-font selector.

The outer loader rejects any fetched part whose source contains literal HTML / 404 strings. To avoid self-rejection, the sanitizer builds its detection strings at runtime (`"<!DOC" .. "TYPE"`, `"<" .. "html"`, `"404" .. ": Not Found"`); `tools/check.js` enforces that no `src/` part contains those literal **error-page markers**. The Fengari mocks stub the external library load, so this fix also adds direct sanitizer regressions; real executor behaviour still needs an in-game check.

### Adaptive ESP geometry slicing and cache

The ESP hot path now shares one `WorldToViewportPoint` projection set between the throttled BillboardGui refresh and the unified FX pass. `SA.EspGeom()` keys the **geometry cache** by a cached entity root / head anchor, a per-frame **camera signature** (camera CFrame position / look / up / Euler fallback, viewport and FieldOfView) and ESP kind. Static crates keep their `geomAnchor` for their whole lifetime; a static camera and rig produce `cacheHits` instead of three fresh `w2vCalls` per entity per frame. `cameraKeyBuilds` counts signature rebuilds — one per camera change, not one per entity. `SA.EspGeomState()` reports `cacheHits`, `cacheMisses`, `w2vCalls`, `savedW2vCalls` and `cameraKeyBuilds`; `SA.EspGeomReset()` clears the counters, `SA.EspGeomInvalidate()` drops cached projections / anchors / the camera signature, and `SA.DisposeEspFx()` clears cached geometry on disposal.

`SA.EspGeometryBudget()` adds **adaptive geometry slicing**. A healthy frame has `geometryStride = 1` and styles every entity. A slow frame raises `geometryStride` up to 4 and styles only a rotating bucket; the aim target and nearest-N entities keep **priority** full-rate styling, while low-priority entities rotate. Skipped entities keep their last frame's pooled draws and legacy lines, are counted from cached data, and crate FOV counters are maintained from cached screen points without new W2V calls. `SA.EspPerfState()` exposes `geometryUpdates`, `geometrySkips`, `geometryHiddenPasses`, `geometryBudget` and `geom`. `SA.EspFrameBudget()` also carries `geometryStride`, `geometryBucket`, `geometryFps`, `geometryLastDtMs` and a nested `geometryBudget` table; `SA.PerfState()` exposes `geometry` and `geom`. The current frame's dt is authoritative and **rolling FPS only** biases stride when **Performance Mode is explicitly ON**, so a stale FPS sample cannot slice a healthy frame.

The teammate map is rebuilt once per data interval instead of every FX frame, the aim-target lookup no longer scans all player objects, `safeDrawEntity` inlines **one fewer pcall** per entity, and `rainbowColor` uses a per-frame **rainbow clock** instead of calling `tick()` for every colour lookup. A **disabled ESP early-out** hides each object list once instead of walking every object and recomputing aim / FOV / nearest data every frame while Player ESP, NPC ESP and Crate ESP are all OFF; `SA.EspHiddenPass` records the one-shot hidden pass. Performance Mode remains optional: slicing is active only when a frame is already over budget, and no second RenderStepped loop, forced `perfMode`, deleted visual or whole-script replacement was added. Theme / font application is event-driven and adds zero per-frame work.

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

`GetNetworkPing()` returns seconds so it is ×1000; the legacy `Data Ping` value is already milliseconds (both `GetValue()` and a numeric/string `Value` are handled). `Auto Ping Lead` is **OFF** by default, `Ping Scale` defaults to **1.0** (full round-trip time — set it to **0.5** if you want one-way latency instead), and the old manual `Extra Lead (ping ms)` slider is now `Extra Ping Offset (ms)` added on top. `SA.GetPing()` / `SA.LeadLatencyMs()` report the measured ping and resulting total. The solver adds this **once** as `tTotal = flightTime + latency`, never once per iteration.

### 4. Highlight on unrelated objects when Crate ESP is ON

The loose classifier accepted *any* instance with an `Opened` / `Looted` attribute (doors, scenery, whole `Loot` folders), and the `Highlight` was parented to the model with `Adornee` set to the whole model.

**Fix:** `crateKind()` now requires `Model` or `BasePart`, excludes player characters / humanoids / our own `Hanami*` instances, and in loose mode requires **both** a container-ish name (`box`, `container`, `parcel`, `pile`, `drop`) **and** a loot-state attribute. `buildCrate()` sets `hl.Enabled = false`, `hl.Adornee = anchor` (one BasePart, not the model), and parents the highlight to that anchor. `refreshCrateESP()` only enables it when the new `Crate Chams Highlight` toggle is ON (default **OFF**). Nested container duplicates are still de-duplicated by `commitCrates()`.

### 5. Off-screen arrows follow the FOV

`src/10_fov_circle.lua` exposes `SA.FovCenter()` / `SA.AimPoint()` (live mouse location, with a screen-centre fallback). `src/18_esp_fx_colours.lua` computes `SA.EspFovSnapshot()` from the **real WorldToViewportPoint projection**, not from `screenPoint()`'s border-clamped pixel: that clamped pixel was why a target entering the circle kept the old outside direction. `src/18_esp_fx_frame.lua` builds one FOV / draw-state signature per frame; `src/18_esp_fx_draw.lua` hides every pooled arrow, tracer, box, chams draw and legacy BillboardGui label on a FOV enter/leave transition, then redraws from fresh geometry. `SA.EspFovState()` exposes the reference, radius, signature and transition count. Player, NPC and crate FOV enter/leave regressions cover all three pipelines. Both the tracer and arrow are gated on `opt.pal == "player"`; crates use the FOV-aware dot / outline branch instead. Turn `Arrows Follow FOV` OFF to get the old screen-edge behaviour.

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

The rotating, success-only queue is shared with the NPC and crate passes, so they benefit from fix #1 too. All other behaviour (visibility colours, 50 inline colourpickers, FOV reference point, one text-size slider) is unchanged.

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
| `VIS` / `WALL` | first tag at the top-right corner | `Visibility Check` · chosen VIS/WALL colour (white by default) |
| State | second tag | `Show State` |
| Health % | third tag | `Show Health %` |
| All tags | stacked by `espTextSize + 3` | `Tags On Box Side` (OFF stacks them under the weapon), `Tag Backdrops` |

The refreshes (`13`, `15`, `17`) now write a small structured `o.tx` table — `name`, `dist`, `weapon`, `tags` — instead of only concatenating one string. The old BillboardGui labels are still populated as a fallback/data source but hidden by the FX pass, so no text is drawn twice. Crates use the same layout with their `OPENED` / `UNOPENED` state as the corner tag. The screen-space text also keeps the palette overrides the old BillboardGui labels had: crate kind colours paint the name, crate state uses `crateState` / `crateOpened`, and NPC Guard / Scavenger / Soldier colours paint the name and state tag. The floating **ESP Preview** panel mirrors the layout live, including the `VIS` ↔ `WALL` alternation.

**Tahoma and ten font picks.** Roblox's `Enum.Font` does **not** contain a `Tahoma` member (only Legacy / Arial / Gotham / SourceSans / …), and native `Drawing.new("Text")` fonts are limited to UI / System / Plex / Monospace. `01_config.lua` keeps Tahoma as one of the 10 popular script-community font picks and resolves each selection through `Font.fromEnum` / `Font.fromName` / `Font.new`, with a built-in `Enum.Font` fallback so text is **never** invisible. The other picks are Arial Bold, Arial, Gotham Bold, Gotham, Source Sans Bold, Source Sans Pro, Roboto Mono, Ubuntu and Code.

The **Visual → Font** dropdown calls `SA.ApplyFont()`, which restyles Atlanta menu text and refreshes every existing player / NPC / crate / preview / screen-space label through the weak registry behind `SA.ApplyEspFont(label)`. `SA.DrawDiag()` reports the selected font name. The font is applied once per change and once at startup, never per frame. `SA.NewDraw("Text")` is deliberately GUI-only, so it works on the same executors as the Line / Circle / Triangle fallback.

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
| Tap-Fire Reorder (Fix A/B) | Aiming → Gun | OFF |
| Fust Bow Ballistic Aim | Aiming → Fust Bow | OFF |
| Tap Window (s) | Aiming → Gun | 0.35 |
| Enable Bow Mods | Gun Mods → Bow Mods | OFF |
| Instant Charge (max draw) | Gun Mods → Bow Mods | OFF |
| No Shot Cooldown | Gun Mods → Bow Mods | OFF |
| Base Peek Offset (4–6 only) | Aiming → Wall Penetration | 4 |
| Range / Parts / Budget / Hysteresis / Max Delta | Aiming → Wall Penetration | 30 / 3 / 40 / 3 / 6 |
| Apply Recommended Wall Pen | Aiming → Wall Penetration | 75 / 4 / 3 / 64 / 5 / 6 |
| Tags On Box Side / Tag Backdrops | ESP → ESP Features | OFF / OFF |
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
| 4 | `showFov` defaulted to `false` in older builds, and `_G.__saCFG` persists — so the new `true` default never applied. The circle was also 50% transparent and hard to see. | `SA.FOV_STARTUP` forces the circle ON at **1% transparent / solid** with a **3px stroke**; transparency still means what it says (0 % = solid). The snapline also ships 3px thick. |
| 5 | The overlay was parented to `CoreGui` first, which some executors accept but hide. | Parent order is now **PlayerGui → CoreGui → `gethui()`**, the stale overlay is destroyed on re-execute, and `gethui()` is the last resort. |
| 6 | The circle used its own mouse lookup while aim, snapline, tracers and arrows each called `GetMouseLocation()` independently. | `SA.AimPoint()` is the single canonical FOV reference point for the circle, silent aim, snapline and every ESP FOV check. |

**Visual → FOV Circle / Snapline** now has **FOV Reference** (always `Mouse` / crosshair), **Transparency (%)** (1 = solid), **Thickness** (3px default), **Force ScreenGui Drawing**, and a separate **Snapline Size / Thickness** slider (1–10, 3px default). `SA.SnaplineState().independent` confirms the snapline works with just its own toggle ON; no Silent Aim master / gun gate remains. `SA.FovState()` / `SA.DrawDiag()` / `SA.SnaplineState()` report the backend, centre, radius, visibility, thickness, reference and any write failures. Invalid mouse positions automatically fall back to the screen centre. The FOV circle is ON at load so the reference is actually visible.

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

`src/01_config.lua` declares `ESP_DEFAULT_COLORS` (48 keys, all **default white**) and merges it into `ESP_COLORS`, persisted in `_G.__saEspColors`. A one-time migration clears older saved green / red / crate palettes; later user choices and saved profiles still win. Every drawing part reads `ESP_COLORS.<key>`; every inline colourpicker writes `ESP_COLORS.<key>`; `Reset ESP Colours` (Misc) restores the white defaults through the library's `config_flags`, so the UI swatches stay in sync. The old scattered `local espColorVisible = ...` / `local crateColorMilitary = ...` variables are gone.

There is **no `ESP → Colours` mini-tab and no separate colour section**. `bindToggle` / `bindSlider` / `bindDropdown` in `src/21_ui_aiming.lua` chain each picker onto the exact control that owns it, in the same row: `| OFF | Corners | COLOR PICKER |`. Flags are `hn_col_<key>`, unique per colour.

| Owner control | Inline pickers |
|---|---|
| Player / NPC Visibility Check | VIS, WALL, Flat, visibility dot |
| Player / NPC name / distance / weapon / health | text, weapon and HP high / low colours |
| ESP Features box / fill / outline / skeleton / head / tracer / arrows | player + NPC element colours |
| NPC Type Colours | Guard / Scavenger / Soldier |
| Crate type / state / distance / FOV-aware controls | Military, Elite, Loot, Opened, state, distance, tracer, arrow |
| Visual FOV / snapline / lead + Highlight Aim Target | FOV, wall-pen FOV, snap VIS / WALL, lead, target |

All missing crate keys fall back to the shared white element pickers until the user customises them.

The chosen **visible / hidden** colour always paints an outer frame around the box, the visibility dot and the `VIS` / `WALL` info tag, so it stays meaningful even with per-element colours enabled. `NPC Type Colours` overrides box/fill/outline for Guard/Scavenger/Soldier; `Highlight Aim Target` paints the entity silent aim is choosing with the `target` colour.

### New ESP visuals (all in `ESP → ESP Features`)

| Feature | What it draws | Default |
|---|---|---|
| Per-Element Colours | each element uses its own picker instead of the dynamic base | OFF |
| Box Outline / Corner Boxes | 4 full edges or 8 corner segments | OFF / OFF |
| Chams Fill / Outline | `Highlight` fill and outline | OFF / OFF |
| Skeleton (bones) | 6 R6/R15-friendly segments; crates get a spine + crossbar | OFF |
| Head Dot | filled circle on `Head` (or the top-centre of a crate) | OFF |
| Tracer Lines (**PLAYERS ONLY**) | line from Mouse / Center / Bottom to each **player** | OFF |
| Off-screen Arrows (**PLAYERS ONLY**) | triangle on the FOV circle perimeter pointing at off-screen **players** | OFF |
| Arrows Follow FOV | arrows share the FOV circle centre / radius | OFF |
| **Text Size** | one slider for **all** ESP text (name, distance, weapon, tags) | 11 px |
| Show Health % / Text Outline | `HP: NN%` tag / label stroke | OFF / OFF |
| Tags On Box Side | `VIS`/`WALL`, state, HP at the top-right corner (OFF stacks them under the weapon) | OFF |
| Tag Backdrops | dark pill behind the weapon badge and each corner tag | OFF |
| Highlight Aim Target | target box / fill / outline uses the `target` colour | OFF |
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

`SA.Predict(origin, targetPos, model)` returns `aimPoint, info`. `info` carries `t`, `total`, `speed`, `velocity`, `lead`, `drop`, `latency`, `range`, `inRange`, `expired`, `id`, `ammo`, `gravity`, plus the new `iterations`, `aimMs`, `attachments`, `attIds`, `speedMult`, `ads`, `effSpread` and `zoom`. Silent aim uses it on every snap; the snapline uses it to draw the lead ring.

### Controls (Aiming → Ballistics / Visual)

| Control | Default | What it does |
|---|---|---|
| Ballistic Prediction | OFF | Master toggle for the solver |
| Bullet Drop Compensation | OFF | `½gt²` vertical aim offset |
| Detect Alt Ammo | OFF | Reads `Ammo`/`AmmoType`/`LoadedAmmo` attributes off the tool |
| Solver Iterations | 4 | Fixed-point refinement passes |
| **Auto Ping Lead** | **OFF** | Live `GetNetworkPing()` / `Data Ping`, smoothed and fed into the solver |
| **Ping Scale** | **1.0×** | Multiplier on the measured ping (0–2) |
| Extra Ping Offset (ms) | 0 | Manual offset added on top of auto ping (0–300) |
| Bullet Speed Override | 0 (auto) | Manual speed, 0–3000; overrides the gun table |
| Ammo Override | Auto | Force any of the 4 base + 6 alt ammo types |
| Saturday2 Damage | OFF | Use the real `s2Damage` numbers from the gun table |
| Muzzle Boost Equipped | OFF | Manual fallback for +15% rate / −10% damage (auto-detected normally) |
| **Auto Attachment Tuning** | **OFF** | Detect all 12 attachments and fold them into the prediction |
| Force ADS Spread | OFF | Assume ADS. OFF = read right mouse button; spread readout only |
| Aim-Time Lead Tune | OFF | Scopes / ACOG / grip add a small time-to-aim lead; reflex removes some |
| Aim-Time Scale | 1.0× | 0 disables the aim-time lead, 2 doubles it |
| Silencer Speed Mult | 0.85× | **Estimate** for "slower bullets"; directly changes lead + drop |
| Sight / Muzzle / Under / Mag Override | Auto | `Auto`, `None`, or an explicit attachment id — fallback when detection can't see the game's storage |
| Show Lead Marker | OFF | Ring in the chosen lead colour (Visual tab, inline colourpicker) |

Functional buttons remain: **Rescan Attachments**, **Sync Gun Defs (GC)**, **Rescan Characters**, **Restore Hitboxes**, **Restore Bow Timings**, **Retry Tap Hooks**, **Apply Overrides Now**, **Sync Gun Defs + Diff**, **Refresh Nearest HUD**, **Reset HUD Position**, **Rebind Selected** and **Cancel Rebind**. None of them produces console output.

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
| Enabled (FOV-aware) | **OFF** | Turns on the peek/disable-restore cycle. |
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
| Prediction | **OFF** | The ballistic solver compensates moving targets; penetration doesn't help if the shot lands behind them. |
| Target Bone | **Head** | Smaller target → fewer ambiguous multi-part peeks. |

**Why the adaptive peek was removed.** v7.7 scaled the peek with distance and then computed `deltaCap = math.max(CFG.manipMaxPeekDelta, maxPeek)`. Since `maxPeek` was always >= the peek distance, **Max Peek Delta could never reject any peek** — it was a dead slider, and the extra "Adaptive Peek Cap" slider had no analogue in the original recommendation. `05_manipulation.lua` now uses `maxPeek = CFG.manipPeek` directly and compares `peekDist <= CFG.manipMaxPeekDelta`, so all six sliders are functional. `01_config.lua` clamps each value to its UI range on every load (saved profiles, preset imports and manual edits included) and removes `CFG.manipMaxPeek` from old configs.

Two useful variants:

* **Strict / legit** — Manipulation `OFF`, silent-aim Wall Check `ON`, Fire Assist Wall Check `ON`, FOV `~120`, Hit Chance `60–80`. Only shoots what you can genuinely see.
* **Heavier cover** — keep the recommendation but raise `Max CanQuery Parts` to `8` and `Ray Budget` to `128`; keep FOV at `150` so the extra rays stay bounded. For long-range work use `Range 300 / Peek 6 / Delta 12`.

The snapline and the chosen WALL colour are your penetration indicator: **clear LOS uses the VIS colour, a wall uses the WALL colour**. Both are white until customised.

## UI: Atlanta

`src/21_ui_aiming.lua` loads the [Atlanta library](https://github.com/i77lhm/Libraries) and builds the window; parts 22–26 build the tabs.

```
Aiming   → Silent Aim / Gun (incl. Tap-Fire Reorder, Tap Window; GUNS ONLY) · Target / Ballistics / Wall Penetration (classic) · Attachments (Auto) · Overrides
ESP      → Player ESP (incl. Rebuild Player ESP / Show ESP Preview Panel / Rebuild ESP Preview) / NPC ESP · Crate ESP / ESP Features (incl. Clean / Best ESP presets and inline colour pickers)
Gun Mods → Gun Mods (V16.46-style) · Controller Field Holds · Silent State / Reports · Bow Mods · Live Gun Tuning
Visual   → FOV Circle / Snapline · Theme / Font · Utilities · Nearest HUD (incl. Manip Crosshair Popup) · Performance Mode · Keybinds
Misc     → Info · Quick Actions

floating "ESP Preview" panel (Atlanta window.esp_section)
         → 3D render · Enabled / Rotate Model / Spin Speed
         → Rebuild Character
```

* **Every widget writes straight into `CFG`** through its `callback`, and every `default` is read from `CFG`. Building the menu never resets the settings kept in `_G.__saCFG`.
* Flags are prefixed `hn_` so they can't collide with the library's own config flags. `setFlag("someKey", value)` and `setToggle(obj, value)` are what the presets and quick actions use, so the UI stays in sync when values change programmatically.
* **Keys:** `RightShift` shows/hides the menu (default), `Insert` toggles silent aim (chained keybind on the master toggle). Both are rebindable; right-click any bind to set `None`.
* **50 inline colourpickers** live on the exact toggle / slider / dropdown they style and write straight into `ESP_COLORS`. Each has a unique `hn_col_<key>` flag, starts **default white**, and is chained onto its owner's `right_holder`. There is no colour mini-tab / separate section. `Reset ESP Colours` restores the white defaults and syncs the swatches.
* **Visual → Theme** is one dropdown with 10 named presets; **Visual → Font** is one dropdown with 10 font picks. Both are event-driven and add no second RenderStepped loop.
* The old Shaman `RadioButton` preset is now a `Custom / Legit / Blatant` dropdown ("Custom" is the default so opening the menu doesn't apply a preset). The `Bullet Speed Override` slider (0–3000) now lives in the Ballistics section.
* **FOV controls:** `Show FOV Circle` (**ON**, 1% transparent / solid, 3px), `FOV Reference` (always Mouse / crosshair), `Transparency (%)`, `Thickness` (3px default), `Snapline (aim preview)` (**works with just this toggle ON**), `Snapline Size / Thickness` (1–10, 3px default), `Force ScreenGui Drawing` (OFF), `Aim / Circle Radius`, plus `SA.FovState()` / `SA.DrawDiag()` / `SA.SnaplineState()` state accessors.
* **Crate controls:** `Invert Crate State`, `Lid Angle Detection` (OFF) and `Rescan Crates` in ESP → Crate ESP.
* Quick actions: Disable All (also clears NPC ESP + snapline + bow mods), Apply Blatant, Toggle Manip, **Reset ESP Colours**, Unload Everything (hides the window, hides the FOV circle, disposes the ESP preview, restores bow timings and stops the scanners via `SA.Alive`), plus Rescan NPCs and Rescan Crates.
* The floating **ESP Preview** panel is populated by `src/22_esp_preview.lua` + `src/22_esp_preview_setup.lua`. **Show ESP Preview Panel** in ESP → Player ESP re-opens it if you closed it with the panel's `X` button.

Only one thing from the Atlanta template is intentionally **not** copied: the duplicated `vis, other` multi-section block. `window.esp_section:esp_preview({})` is also *not* called, but its feature is now implemented natively — see [ESP preview](#esp-preview). Everything else from the template's init block is kept: `open_tab()`, `config_list_update()`, the theme / font startup pass, and `old_config = get_config()` — each guarded with `pcall` where it touches filesystem/config APIs.

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
* **Live settings.** Every overlay is restyled through the same `pick(key, base, seed)` helper used by the real ESP, so `CFG.espRainbow`, `CFG.espPerElementColors`, `CFG.espTextSize`, `CFG.espBoxThickness` and all 48 `ESP_COLORS` entries apply instantly. It previews box / corner boxes / outline, name, distance at the left corner, the weapon badge below the box, the `VIS`/`WALL` + state + `HP: NN%` tags at the right corner, health bar (low→high lerp), visibility dot, skeleton, head dot, tracer and chams fill tint. `VIS` / `WALL` alternates every 2.5 s so both visibility colours are visible. ViewportFrames cannot reliably render `Highlight`, so chams are shown by tinting the model's parts.
* **Reachable.** On displays shorter than ~1080 px the template docks this panel *below* the main window, i.e. off-screen. The build clamps the panel into the viewport and docks it top-right when the template position cannot fit. If a future Atlanta revision stops exposing `window.esp_section`, the preview builds itself into a new `ESP Preview` section inside the ESP tab instead; the `embedded` flag keeps unload from hiding the main menu in that case.

**Controls** — in the preview panel: `Enabled`, `Preview Kind` (Player / NPC), `Simulate Aim Target`, `Rotate Model`, `Spin Speed` (0–90 °/s), `Apply Best ESP`, `Rebuild Character`. In ESP → Player ESP: `Show ESP Preview Panel` (re-opens the floating window) and `Rebuild ESP Preview`.

Config keys: the shipped literal has `espPreview` OFF, `espPreviewSpin` OFF and `espPreviewSpeed` 25; the ESP-only startup preset applies `espPreview` ON, `espPreviewSpin` OFF, `espPreviewKind` (`"Player"`) and `espPreviewTarget` OFF. All are backfilled for older saved configs and bound to Atlanta widgets. See [Best ESP](#best-esp-players--npcs) for the Player/NPC mirror and the curated preset.


## Best ESP (Players + NPCs)

The ESP tab's **ESP Features** section keeps its **Apply Best ESP** button. A fresh load now applies the same **ESP-only best preset automatically** through `SA.BEST_ESP_STARTUP` / `SA.BestEspState()`; the button re-applies it after user changes. No gun mods, Visual or Misc setting is turned ON. This addresses the old scattered Player/NPC settings and keeps the ESP Preview mirroring both pipelines.

**Apply Best ESP** turns on the curated set for BOTH entity kinds through the Atlanta flags (so every bound widget updates), then re-opens the preview. Startup applies the same values directly to `CFG` before the widgets are built:

| Group | Enabled |
|---|---|
| Player | ESP, Visibility Check, Names, Distance, Health Bar, Weapon, State |
| NPC | ESP, Visibility Check, Names, Distance, Health Bar, Weapon, State, NPC Type Colours |
| Shared | Per-Element Colours, Box Outline (corner boxes), Thin Chams Outline, Head Dot, Highlight Aim Target, Show Health %, Text Outline, Tags On Box Side, ESP Preview |

`Rainbow`, `Distance Fade`, Chams Fill, Skeleton, Tracer Lines, Off-screen Arrows and Tag Backdrops are deliberately left **OFF**: they wash out the 48-colour palette, hide distant boxes, clutter the screen or can leave stale edge overlays. `SA.BEST_ESP_STARTUP` contains only `esp*` / `npc*` keys; `SA.FOV_STARTUP` is the separate, sole non-ESP exception that turns the visible 3px FOV circle ON and ships a 3px snapline. The snapline itself still starts OFF, but works independently once toggled. Every gun-mod / Visual / Misc feature otherwise stays OFF. The button enables every curated Player / NPC / shared flag through the same bound `hn_*` widgets.

**Preview mirrors both pipelines.** `CFG.espPreviewKind` (`Player` / `NPC`, exposed as *Preview Kind*) selects which section's visibility check / name / distance / health / weapon / state flags and which of the `player*` / `npc*` colourpicker keys feed the overlay. In NPC mode the Guard / Scavenger / Soldier archetype colours rotate every three seconds, and the name + state tag use the archetype colour — the same `typeColor` path `drawEntity()` uses in the real ESP. *Simulate Aim Target* paints the box, fill and outline with the global `Target` colour just like *Highlight Aim Target* on a locked target.

The preview also gained the overlays the real ESP already had: a padded **visibility frame** (chosen VIS/WALL colour), a separate label **per corner tag** (so `VIS`/`WALL` keeps its chosen colour while state / `HP` use the scanner colour), rounded **tag backdrops**, an **off-screen arrow**, a functional **Chams Outline** second stroke (thickness 0 when disabled — no reliance on the newer `UIStroke.Enabled`), exact `rowH = TextSize + 3` line spacing identical to `drawEntity()`, tracer origin (Center / Mouse), text outline, and a Distance Fade simulation at 85% of the chosen Max Distance. If a future Atlanta build omits `window.esp_section`, the setup now creates its own small `HanamiEspPreviewPanel` ScreenGui instead of failing, and unload destroys it.

**Fixed FOV-enter/leave overlay sticking for Player + NPC ESP.** The main player/NPC box, name tag and chams no longer remain clamped at the old FOV edge after a camera turn brings the target into the FOV circle. `SA.EspGeom()` and `screenPoint()` use explicit viewport bounds, camera turns force stride-1 fresh geometry, the FX pass hides legacy BillboardGui labels / duplicate name tags and unused pooled draws, and the edge arrow is hidden as soon as the target is inside the FOV. `tools/tests.lua` overrides `WorldToViewportPoint` for deterministic Player and NPC outside → inside → outside regressions that check the real box and name coordinates, not just `Visible` flags. **Fixed colour regressions** in `drawEntity()`: crate names keep their kind colour (`keepNameColor`) instead of falling back to the player name picker, crate state tags use `crateState` / `crateOpened`, and NPC archetype colours paint the name and state tag even with the new screen-space selected-font labels.

`SA.BEST_ESP_STARTUP`, `SA.ApplyBestEsp()` and `SA.BestEspState()` are the ESP preset / API; `SA.ConfigCoverage()` (includes `hn_menu_bind`), `SA.NearestWindowState()` and `CFG.espPreviewKind` (`"Player"`), `CFG.espPreviewTarget` (`false`), `CFG.nearestWindow` (`true`) are the existing state / config keys. Every CFG key is backfilled for older saved configs, and the preview kind / speed are clamped on every load so a stale saved value cannot put the mirror into an invalid pipeline. `SA.STUDS_PER_METER = 3.571` is the single studs→metres factor used by the ESP distance labels and the nearest-player HUD.

## ESP FOV reference, no stuck overlays and saved colours

The screenshot-style duplicate name is handled at the same FOV / viewport / draw-signature transition: **one on-player label** survives at the live raw projection. `SA.EspHideDuplicateOverlays()` disables orphan `HanamiPlayerGui` BillboardGuis from an older chunk, hides duplicate `espObjects` slots for the same character, and verifies the live `Visible` / `Enabled` properties after cached writes. `src/12_esp_players.lua` purges named ghost BillboardGuis / Highlights before a fresh build, and `src/13_esp_players_refresh.lua` never re-enables the legacy BillboardGui while the screen-space FX pass exists. `SA.EspDuplicateCleanupState()` exposes the cleanup counters; this is transition-only, not a per-frame sweep.

`SA.EspFovSnapshot()` is the single source of truth for FOV membership: it uses the raw projected point, the live `SA.AimPoint()` and `SA.FovRadius()`, and returns `inside`, `outside`, `onScreen`, `point`, `clamped` and `edge`. The border-clamped point is used only to anchor an off-screen arrow / crate dot. `SA.EspFovState()` and `SA.SnaplineState()` report the shared reference; `SA.FOV_STARTUP` makes the circle visible at load (1% transparent, 3px stroke) and ships the snapline 3px thick. A per-entity state signature now also includes the Silent Aim master / Gun Silent Aim / snapline / FOV-circle toggles and whether a live aim target exists. Toggling **Gun Silent Aim** or the snapline therefore forces exactly one `hideFx()` + fresh-geometry pass, so the reported ESP-stuck-at-FOV-edge bug cannot survive the toggle. `saRefreshAimTarget()` in `09_silent_aim.lua` keeps `SA.Target.model` aligned with Gun Silent Aim at 20 Hz when the snapline is OFF, while `hideSnap()` clears only the snapline pixel fields and drops a stale model when the snapline is ON. Stale `espNearestSet` slots are cleared every frame. Ordinary mouse movement only repositions the edge anchor; it does not rebuild every ESP object, so the adaptive geometry slicing and 60-50 FPS budget remain intact.

`SA.EspColorSnapshot()` / `SA.EspColorRestore()` make **saved colour pickers** part of every native config profile. All 48 `#RRGGBB` values are embedded in the profile JSON and a `<profile>.colors` sidecar, then restored through the inline `hn_col_*` setters on load and import. `SA.EspColorCount()`, `SA.EspColorEncode()`, `SA.EspColorDecode()`, `SA.EspColorText()`, `SA.EspColorFromText()`, `SA.EspColorHex()` and `SA.EspColorFromHex()` expose the same helpers to the self-check and tests. `SA.TestConfigRoundTrip()` verifies the flags and colours together.

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

The HUD is now a **draggable nearest-player profile card**. It loads a **Roblox headshot** with `Players:GetUserThumbnailAsync(UserId, HeadShot, Size150x150)` off the render frame and falls back to two initials if the thumbnail API fails. The card shows `DisplayName (@Name)`, UserId, distance, HP, VIS / WALL, team, weapon name and a separate **Equipped / Holstered / Unknown** state chip driven by `SA.GetWeaponStatus()`. Dragging the header uses real `InputBegan` / `InputChanged` / `InputEnded` pointer events; the position persists for the session and **Reset HUD Position** restores the selected corner. `SA.NearestWindowResetPosition()` clears the saved drag position, and **Unload Everything** clears it too.

The HUD is created with `Instance.new("ScreenGui")` directly, **not** `library:create`, so `window.set_menu_visibility(false)` cannot sweep it into `library.guis` and disable it. It is parented to `gethui()` with a `PlayerGui` / `CoreGui` fallback, uses `SA.ApplyEspFont()` for selected-font text, and is torn down by `SA.NearestWindowDispose()` on re-execute and **Unload Everything**.

Controls: **Visual → Nearest HUD → Nearest Player HUD** (default OFF), **Refresh Nearest HUD** and **Reset HUD Position**. `SA.NearestWindowState()` / `SA.NearestWindowSet(on)` / `SA.NearestWindowRefresh()` / `SA.NearestWindowResetPosition()` are the state API. No new CFG key was added; the session drag position lives in `_G.__saNearestWindowPos` and is cleared by full unload. New config key: `CFG.nearestWindow` (`false`, backfilled).

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
| `src/01_config.lua` | **10 themes, 10 fonts, white defaults, startup off, ESP-only best startup, FOV startup, snapline size, mouse reference, inline colours**, services, `CFG` defaults + backfill (**classic manip/tap, NPC manipulation, crate FOV, player warning, trigger / auto fire + dedicated fire-assist wall check, ESP data refresh, Force Head, Fust bow ballistic settings, bow-mods, V16.46 gun / brightness keys, NPC hitbox toggle / player + NPC hitbox expander, attachment keys, 10 font resolver, Player/NPC preview mirror + clamps, nearest HUD, profiles / self-check / perf / manip-popup / clean-ESP keys**), `SA` state + shared metres factor, **direct connection registry / unload disconnect**, `bindRender`, 48-colour palette | 1296 |
| `src/02_drawing.lua` | per-kind capability probing, ScreenGui proxy, selected-font screen-space `Text` draw, no-op fallback, **live draw registry / draw remove / draw state**, **coalesced sync batching + per-property write skip + live Instance-property coherence check + draw pool with styling reset + write-failure tracking** | 757 |
| `src/02_shared.lua` | **FOV reference point / mouse reference** (`SA.AimPoint` / `SA.FovRadius`), **two FOV measurement modes (`Pixels` / `Degrees`) + hitbox-wide segment membership + behind-camera rejection (`sp.Z <= 0`)** (`SA.FovMode()` / `SA.FovDegrees()` / `SA.FovPointInside()` / `SA.FovSegmentInside()` / `SA.FovState2()`), checks, target picking, **one shared per-frame preview target** (`SA.PreviewTarget()` / `SA.PreviewTargetReset()` / `SA.PreviewTargetState()`), **pinned target / priority / bone / no-target reason**, **public NPC classifier**, **Force Head**, **Trigger Bone / TriggerTarget + dedicated VIS wall check** | 607 |
| `src/02_workspace_scan.lua` | **single incremental Workspace walker**, `SA.RegisterScanHandler` / `RequestScan`, deterministic `SA.ScanStep()` / `SA.ScanPassNow()` test drivers | 136 |
| `src/03_entity_scan.lua` | entity scan, NPC registry, visibility + raw list, **draggable nearest-player profile card**, **Roblox headshot / initials avatar**, **Equipped / Holstered / Unknown weapon state**, session drag position + **Reset HUD Position**, `SA.NearestWindowState()` / `SA.NearestWindowResetPosition()` | 783 |
| `src/04_entity_info.lua` | entity scanner: tool/weapon + state + roster, **equipped / holstered / unknown weapon status**, `SA.GetWeaponStatus()`, **Tool child fallback + shared metres**, read-only **staff / admin role classifier** with a **3 consecutive scans** confirmation gate (`SA.GetStaffRoleConfirmed()` / `SA.StaffWatchState()`), **UNKNOWN humanoid** registry (no writes, no warnings) | 534 |
| `src/05_manipulation.lua` | **Manipulation (classic sliders, guns only, NPC-aware)**: shared RaycastParams, 8-direction peek, fixed 4–6 peek, clamped functional sliders, target-aware filter, reused CanQuery entries, **read-only crosshair popup probe + fire-assist allowNoAim gate**, NPC toggle / state / explicit probe | 440 |
| `src/06_firing_and_guns.lua` | **v7.7 firing state** (0.35 s tap window, InputEnded stamp; no bow state) + snap cooldown, **complete unload sweep / Hanami GUI sweep / draw pool disposal / visual state** | 186 |
| `src/07_gun_specs.lua` | **all 20 guns + every attribute** (mag / spread / ads / move / reload / recoil / s2 / scope / tags), ammo, damage, alt ammo, 8 named falloffs, ranges + **name-only bow gate** | 326 |
| `src/08_attachments.lua` | **12 attachment defs**, `AttFit` / slots / tags, tolerant tool scanner, **auto-tune effects** + `SA.*Attachments*` state | 395 |
| `src/08_prediction.lua` | **live ping**, smoothed velocity, quadratic intercept, drop, adaptive iterations, attachment aim-time lead, **live gun diff + manual overrides + new-gun stubs** | 310 |
| `src/09_silent_aim.lua` | **shared aim target refresh** for ESP when Gun Silent Aim is ON and the snapline is OFF, **Silent Aim v7.7 (guns only)**: Fix A/B connection reorder, idempotent tap snap, bow gate, shared `SA.ResolveShot`, **silent-aim-independent Trigger / Auto Fire, dedicated VIS wall check + no-bypass, Tool-first backend with mouse1click fallback**, render-step camera binds; a **dedicated Fust bow part** owns ballistic hook state | 592 |
| `src/09_z_fust_bow.lua` | **Fust bow ballistic silent aim + peek-origin wallbang**: default-OFF **hookfunction** on **Shoot.FireServer**, Fust.Items bow specs, FOV target pick, gravity-compensated `solveAim`, eight-direction `findPeek`, velocity / origin argument rewrite, LOS gate, generation guard, dispose / restore, `SA.FustBow*` **state** | 376 |
| `src/10_fov_circle.lua` | **solid visible 3px FOV circle + reference point**, tolerant writes, backend recovery, **FOV dispose**, `SA.FovState` | 388 |
| `src/11_snapline.lua` | **independent FOV reference snapline + thick 3px default + customizable snapline size**, aim preview line + target/lead markers from the **shared per-frame preview target**, **snapline dispose** | 191 |
| `src/12_esp_players.lua` | Player ESP objects, box, health bar, **ghost BillboardGui / Highlight purge**, **registry-aware removal**, cached rig + re-execution cleanup | 221 |
| `src/13_esp_players_refresh.lua` | per-player refresh, cached player rig, VIS, **legacy BillboardGui OFF in FX mode**, **death / stream-out / respawn cleanup hooks**, shared projection cache + geometry cache | 300 |
| `src/14_esp_npcs.lua` | NPC ESP objects + cached rig + enable/disable + events + **named orphan cleanup** | 117 |
| `src/15_esp_npcs_refresh.lua` | **NPC ESP refresh** with cached rig / o.vis, **shared projection cache**, **geometry cache** reuse, visibility + scanner + HP + structured `o.tx` text, **NPC refresh throttle** (tag/text rebuild only at the ESP data interval) | 160 |
| `src/16_esp_crates.lua` | crate classification, **strict opened-state resolver**, anchors, GUI objects | 326 |
| `src/16_esp_crates_registry.lua` | live crate registry + raw list accessor, **crate-state resolver**, walker handler | 57 |
| `src/17_esp_crates_refresh.lua` | crate refresh (filters, state, structured `o.tx` text, highlight gate) + events | 90 |
| `src/18_esp_fx_colours.lua` | palette helpers, lazy drawing factory, FOV snapshot / raw projection, skeleton / screen / box geometry, explicit viewport bounds + minimum corner size, **live visibility hide**, legacy line / chams / BillboardGui hide, **duplicate overlay / ghost cleanup**, draw usage marks + hide-unused finaliser, draw-pool reuse, geometry cache invalidation, per-frame rainbow clock | 428 |
| `src/18_esp_fx_draw.lua` | **unified styling + per-entity transition cleanup** (keyed on the entity's own FOV / viewport state, never the shared signature): selected-font screen-space text, NPC / crate colours, boxes, corner-box forces a box, **clean outline-only mode**, **crate FOV dot / outline-highlight branch**, **FOV enter/leave edge-arrow cleanup + duplicate overlay cleanup**, off-screen skip, FX-owned legacy line / chams visibility, chams, skeleton, tracers, FOV arrows, fade, `SA.Atan2`, **hoisted helpers / draw usage marks / direct segments**, **tag-column offset so side tags never collide with the name row** | 513 |
| `src/18_esp_fx_frame.lua` | per-frame fps-aware `SA.ApplyEspFx` with error isolation, **toggles-only draw signature / fov transition + Gun Silent Aim toggle cleanup** + **one-shot `SA.EspStyleSweep()`** (no live-target churn) + **ghost / stale drawing cleanup** (`SA.EspGhostCleanup`, dead / teleported / streamed out) + per-object hidden pass, cached rig / o.vis, throttled team map / nearest sort, **shared geometry cache + viewport bounds**, **camera signature**, **camera-turn fresh geometry for FOV enter/leave**, **adaptive geometry slicing**, **priority slicing**, **hidden pass** for disabled ESP, **one fewer pcall**, crate FOV counters, live per-kind counts, **box min-size floor at long range** | 817 |
| `src/19_render_loop.lua` | master render loop: rotating success-only build queue, 4 guarded passes, FX pass, throttled data refresh, raw list build queues, FPS counters, **60 FPS frame budget / adaptive pacing / rolling FPS / entity cap**, **geometry budget / adaptive geometry slicing**, **rolling FPS** bias only with **performance mode** ON, one shared V16.46 gun-frame hook, **cold-start guard (an enabled kind with no objects builds immediately instead of waiting out the perf-mode interval)** | 348 |
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
| `src/21_ui_aiming.lua` | Atlanta setup + **inline colourpicker helper** + **re-execution-safe keybind wrapper** + **Unload Menu wrapper / blur capture**, **Atlanta source sanitizer** / **built-in font fallback** / **error-page markers** split, Aiming tab (Target / Ballistics / Wall Pen / attachments / Manipulation), **NPC manipulation**, **Trigger / Auto Fire + Fire Assist Wall Check + hit-part controls + VIS / silent-aim independent labels**, **Force Head**, **Fust bow controls**, **NPC hitbox toggle**, **Hitbox Expander v2 toggles / sliders**, **FOV preset + target priority / bone / pin / no-target UX** | 632 |
| `src/22_esp_preview.lua` | **ESP Preview core**: state/teardown, safe clone + dummy rig, ViewportFrame overlays, **real-model source selection + side-by-side Player vs NPC compare**, **clean-mode mirroring**, per-tag labels, vis frame, arrow, backdrops | 644 |
| `src/22_esp_preview_setup.lua` | **ESP Preview build + lifecycle**: panel clamp, standalone-panel fallback, camera/render bind, respawn hook, Preview Kind / Target / Best ESP controls, source/compare rebuild, `SA.EspPreview*` API | 280 |
| `src/22_ui_esp.lua` | ESP tab: player / NPC / crate / **crate FOV-aware toggle + state** / features / **Clean + Best ESP presets + ESP-only best startup API** / **48 inline pickers / no colour mini-tabs**, **ESP decluttering + live count controls**, Player ESP **staff / admin detector** toggle with inline staff + admin tag colours | 272 |
| `src/23_ui_gunmods.lua` | V16.46-style Gun Mods tab (all 12 Gun settings), silent state labels / report buttons, Bow Mods + feature keybinds, **Live Gun Tuning / Overrides controls** | 138 |
| `src/24_ui_visual.lua` | Visual tab, **FOV reference circle + independent thick snapline + customizable snapline size**, **theme / font dropdowns**, **draggable nearest-player profile card with Roblox headshot / initials avatar**, display + account name, UserId, **weapon name + Equipped / Holstered / Unknown weapon state chip**, session drag position + **Reset HUD Position**, **top-N nearest HUD + NPC-aware Manip Crosshair Popup + 100m player warning**, **Force Head / Fire Assist state accessors**, **Utilities + local ColorCorrectionEffect brightness**, **Performance Mode + ESP data refresh slider + ESP FPS state + ESP frame budget + FPS overlay + all-keybind manager / rebind / conflicts** | 561 |
| `src/25_ui_misc.lua` | Misc tab, quick actions, **native config profiles + colour profiles + export/import/round-trip**, **both unload paths / full unload state / draw sweep / connection sweep**, **self-check state (NPC manipulation, crate FOV, player warning, fire assist, Force Head, Fust bow state, manip popup + clean ESP, draw sync + ESP perf + ESP frame budget + hitbox state)**, **full unload clears FOV migration marker + HUD drag position**, **warning / fire-assist / Fust bow / gun-mod / brightness disposal + hitbox restore**, **theme / font startup apply**, UI init / auto-load, Misc **Detectors (read-only)** unknown-humanoid toggle, count and name line | 712 |
| `src/26_banner.lua` | final `return CFG` only (no startup output) | 9 |
## Testing

```bash
npm ci && npm test
```

`npm test` builds the ignored `dist/Hanami.lua`, runs the Python Luau-safe join verifier, parses every Lua chunk with luaparse, validates the loader / README / CFG coverage, then executes the committed Fengari mock suite. The runner loads `tools/mocks.lua`, executes the bundle three times in one Lua state and asserts startup, native profile auto-load, re-execution, full unload, manipulation popup READY / BLOCKED / bypass states, NPC manipulation, crate FOV dot / outline checks, 100 m warning, Triggerbot / Auto Fire / part modes / VIS FOV with silent aim OFF / Tool-first backend with mouse fallbacks / dedicated Fire Assist Wall Check / both-enabled / Manipulation Support no-bypass regressions, player + NPC hitbox expansion / HRP fallback / NPC toggle restore, ESP FPS optimization / coalesced GUI sync / throttled data refresh / cached rig / off-screen skip / raw list / ESP 60 FPS frame budget / per-property instance writes / draw usage marks / shared projection cache / camera signature / adaptive geometry stride / teammate-map throttle / disabled-ESP hidden-pass / Atlanta font-bootstrap sanitizer / Fust bow hookfunction / ballistic velocity / peek-origin wallbang / bow-spec / LOS / dispose / full-unload restore regressions, Force Head, 9 additional themes / 10 font picks, all-nine-colour theme application, live menu + ESP label font refresh, 50 unique inline white colourpickers, ESP-only best startup, non-ESP OFF defaults, live-property coherence, camera-turn fresh geometry / stale-overlay / Player, NPC and crate FOV enter/leave regressions, FOV reference point, independent thick snapline, 3px defaults, Gun Silent Aim toggle cleanup, shared aim target, customizable snapline size, saved colour pickers, no extra render listeners / forced `perfMode`, preserved 60 FPS budget, all new state APIs and the no-console-output / no-print-UI regressions with zero mock callback / event errors.

The suite is static + Fengari mock validation, **not a real Roblox executor** confirmation. Executor-only behaviour (`gethui`, `Drawing`, `getgc`, `getconnections`, real ViewportFrames, filesystem / clipboard and Atlanta's live UI) must still be checked in-game; `SA.SelfCheck()` returns the capability report to code.

## Editing

* Parts share one scope: a column-1 `local` in an earlier part is hoisted and visible in later ones. **Indented** `local`s stay private to their function.
* **Order matters.** Adding/removing a part means updating `PARTS` in `loader.lua` too.
* Never put a top-level `return` in any part except `26_banner.lua` — it would end the joined chunk early.
* Keep a trailing newline on every part (they are concatenated directly), and give column-1 `local`s an initializer — `local a, b = nil, nil`, not `local a, b`.
* Luau caps a function at **200 local registers**: `python3 tools/verify.py` checks the hoisted main chunk and the per-part budget, so don't add lots of new column-1 `local`s without re-running it. A plain `luaparse` parse is *not* enough.
* All new drawing must go through `SA.NewDraw(kind)`; all new workspace discovery must go through `SA.RegisterScanHandler(key, predicate, commit)`. Never call `Workspace:GetDescendants()` in a loop.
* Atlanta widgets need a `button_holder()` row before `button()`. Keybinds and inline colourpickers chain onto toggles / sliders / dropdowns (`right_holder`); colourpickers are never placed on label rows in a separate colour mini-tab. `multi_section({ names = {...} })` still accepts mini-tabs for non-colour sections.
* All `CFG` keys used by the logic must stay bound to a UI widget; `python3 tools/verify.py` checks the join.

```bash
python3 tools/verify.py   # order, newlines, stray returns, Luau register budget, build output
bash build.sh             # optional: make one self-contained dist/Hanami.lua via tools/hoist.py
```

`build.sh` is only needed if you want a single paste-able file; it applies the **same** hoisting as the runtime loader. `dist/` is gitignored.

---

Executor-only script (`Drawing`, `getgc`, `loadstring`, `getcustomasset`). Use in private/own places; running it in public experiences can violate Roblox's Terms of Use and get an account banned.
