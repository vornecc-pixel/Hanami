# Hanami

`@abusegpt` suite — silent aim, wall penetration, player ESP, crate ESP, gun mods, hit log.
The original 1,300-line script is now split into **19 short files** (`src/`, biggest is 148 lines) plus a **~60-line loader**.

## Load it (one line)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/vornecc-pixel/Hanami/refs/heads/arena/bb927757-hanami/loader.lua"))()
```

If your executor won't follow redirects or blocks that host, use the `github.com` form:

```lua
loadstring(game:HttpGet("https://github.com/vornecc-pixel/Hanami/raw/refs/heads/arena/bb927757-hanami/loader.lua"))()
```

> Changing branches/forking? Edit `REF` (and the two fallback roots) at the top of `loader.lua`.
> e.g. `local REF = "Fuck-Nigga"`.

## How it works

`loader.lua` downloads each file in `PARTS`, joins them with `\n\n`, and calls `loadstring` **once**.
Because it is one chunk, every `local` (CFG, helpers, ESP tables, UI handles) is shared across files exactly like the original — no code was rewritten, so behaviour is unchanged.

```
loader.lua  ──fetch──▶  01_config.lua
                       02_shared.lua
                       ...
                       19_banner.lua
             ──join──▶ one chunk ──loadstring──▶ runs, returns CFG
```

Each part is just a slice of the original script with a 5-line comment header. Reassembling the parts reproduces the original byte-for-byte.

## Files

| Part | What's in it | Lines |
|---|---|---|
| `src/01_config.lua` | services, `CFG` defaults + backfill, bullet speeds | 110 |
| `src/02_shared.lua` | velocity cache, team/NPC checks, target picking, debug | 134 |
| `src/03_manipulation.lua` | wall peek + `CanQuery` manipulation | 148 |
| `src/04_firing_and_guns.lua` | firing state, gun lookup, cooldown | 73 |
| `src/05_silent_aim.lua` | camera sandwich RenderStep binds | 64 |
| `src/06_fov_circle.lua` | FOV circle | 36 |
| `src/07_esp_players.lua` | player ESP objects + box/health bar | 79 |
| `src/08_esp_players_refresh.lua` | player ESP refresh + enable/disable | 87 |
| `src/09_esp_crates.lua` | crate ESP objects + state/labels | 100 |
| `src/10_esp_crates_refresh.lua` | crate refresh, scanners, events | 66 |
| `src/11_render_loop.lua` | master ESP + crate render loop | 23 |
| `src/12_gun_mods.lua` | GC scan gun mods | 88 |
| `src/13_hitlog.lua` | hit log GUI, hit sound, damage tracker | 125 |
| `src/14_ui_aiming.lua` | Shaman library setup + Aiming tab | 98 |
| `src/15_ui_esp.lua` | ESP tab | 45 |
| `src/16_ui_gunmods.lua` | Gun Mods tab | 25 |
| `src/17_ui_visual.lua` | Visual tab | 44 |
| `src/18_ui_misc.lua` | Misc tab + quick actions | 45 |
| `src/19_banner.lua` | startup banner, `return CFG` | 24 |

## Editing

* Parts share one scope: a `local` declared in an earlier part is visible in later ones.
* **Order matters.** Adding/removing a part means updating `PARTS` in `loader.lua` too.
* Never put a top-level `return` in any part except `19_banner.lua` — it would end the joined chunk early.
* Keep a trailing newline on every part (they are concatenated directly).

```bash
python3 tools/verify.py   # checks order, newlines, stray returns, build output
bash build.sh             # optional: make one self-contained dist/Hanami.lua
```

`build.sh` is only needed if you want a single paste-able file; the runtime loader does the same join automatically. `dist/` is gitignored.

---

Executor-only script (`Drawing`, `getgc`, `gethui`, `loadstring`). Use in private/own places; running it in public experiences can violate Roblox's Terms of Use and get an account banned.
