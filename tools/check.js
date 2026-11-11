/* Hanami / tools/check.js — committed static checks for npm test.
 * Verifies Lua syntax, loader/parts synchronisation, the hoisted bundle,
 * README file rows / line counts, the BETTER config-key coverage and that
 * the shipped source contains no console output or print/debug UI.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');

const root = path.resolve(__dirname, '..');
const srcDir = path.join(root, 'src');

function read(relative) {
  return fs.readFileSync(path.join(root, relative), 'utf8');
}

function lines(text) {
  return text.split('\n').length - (text.endsWith('\n') ? 1 : 0);
}

function parseLua(relative, text) {
  try {
    return luaparse.parse(text, { luaVersion: '5.3', locations: true });
  } catch (err) {
    throw new Error(`${relative}: Lua parse error: ${err.message}`);
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const files = fs.readdirSync(srcDir)
  .filter((name) => name.endsWith('.lua'))
  .sort();
const lineCounts = new Map(files.map((name) => [
  name, lines(read(`src/${name}`))
]));

// Every part is syntactically valid Lua 5.3 (Fengari's dialect).
for (const name of files) {
  const text = read(`src/${name}`);
  parseLua(`src/${name}`, text);
  // loader.lua rejects a fetched part that contains an HTML / 404 marker,
  // so those literals must never appear in a src part (split them instead).
  assert(!text.includes('<!DOCTYPE') && !text.includes('<html')
    && !text.includes('404: Not Found'),
    `src/${name} contains a literal loader error-page marker`);
}
parseLua('tools/mocks.lua', read('tools/mocks.lua'));
parseLua('tools/tests.lua', read('tools/tests.lua'));

const loader = read('loader.lua');
const loaderAst = parseLua('loader.lua', loader);
const partsMatch = loader.match(/local PARTS = \{([\s\S]*?)\n\}/);
assert(partsMatch, 'loader.lua: PARTS table not found');
const parts = Array.from(partsMatch[1].matchAll(/"([^"]+\.lua)"/g), (m) => m[1]);
assert(parts.length === files.length,
  `loader lists ${parts.length} parts but src has ${files.length}`);
assert(JSON.stringify(parts) === JSON.stringify(files),
  'loader PARTS order does not match src/*.lua');

const dist = read('dist/Hanami.lua');
const distAst = parseLua('dist/Hanami.lua', dist);
const returns = distAst.body.filter((node) => node.type === 'ReturnStatement');
assert(returns.length === 1,
  `dist must have exactly one top-level return, found ${returns.length}`);
assert(distAst.body[distAst.body.length - 1].type === 'ReturnStatement',
  'dist top-level return must be the final statement');
const columnLocals = Array.from(dist.matchAll(/^local\b/gm));
assert(columnLocals.length === 0,
  `dist has ${columnLocals.length} column-1 locals; hoisting regressed`);
assert(loaderAst.body.length > 0, 'loader parsed to an empty chunk');

const requiredDist = [
  'SA.FullUnload', 'SA.SaveProfile', 'SA.LoadProfile', 'SA.DeleteProfile',
  'SA.ExportConfig', 'SA.ImportConfig', 'SA.TestConfigRoundTrip',
  'SA.ConfigCoverage', 'SA.SelfCheck', 'SA.SelfCheckState',
  'SA.SetAllKeybindModes', 'SA.KeybindConflicts',
  'SA.StartRebind', 'SA.ClearSelectedKeybind', 'SA.DisposePerfOverlay',
  'HanamiPerfOverlay', 'SA.NearestWindowState',
  'SA.EspPassAllowed', 'SA.EspPassStats', 'SA.PerfEffectiveRebuildMs',
  'SA.PerfEffectiveEntityCap', 'SA.DrawPoolStats', 'SA.DrawWriteFailures',
  'SA.GunDiff', 'SA.ApplyGunOverrides', 'SA.SyncGunDefs',
  'SA.PinNearestTarget', 'SA.NoTargetReason', 'SA.ResolveTargetBone',
  'SA.IsNpcModel', 'SA.ManipNpcState',
  'SA.TriggerBonePart', 'SA.TriggerTarget', 'SA.ForceHeadState',
  'SA.FireOnce', 'SA.FireAssistTick',
  'SA.FireAssistState', 'SA.CrateFovState',
  'SA.PlayerWarningState',
  'SA.DisposePlayerWarning', 'SA.DisposeFireAssist',
  'SA.HitboxScan', 'SA.HitboxRestore', 'SA.HitboxState',
  'hitboxNpcs', 'npcParts', 'npcModels', 'fireWallCheck',
  'SA.DrawSyncFlush', 'SA.DrawSyncPending', 'SA.DrawSyncStats',
  'SA.EspDataIntervalFrames', 'SA.EspPerfState',
  'SA.NpcListRaw', 'SA.CrateListRaw',
  'SA.DrawSyncReset', 'SA.ApplyInstProp', 'SA.EspFrameBudget',
  'SA.EspFrameBudgetReset', 'instanceWrites',
  'SA.SanitizeAtlantaSource', 'ATLANTA_ROOTS', 'hanamiFetchAtlanta',
  'SourceSansPro', 'pcall(makefolder,',
  'SA.EspGeom', 'SA.EspGeometryBudget', 'SA.EspGeomState',
  'SA.EspGeomReset', 'SA.EspGeomInvalidate', 'SA.EspHiddenPass',
  'geometryStride', 'geometrySkips', 'geometryUpdates',
  'geometryHiddenPasses', 'geometryBucket', 'geometryFps',
  'geometryLastDtMs', 'cameraKeyBuilds', 'savedW2vCalls',
  'cacheHits', 'w2vCalls', 'geometryBudget', 'rainbowClock',
  'priority', 'stride',
  'instanceSkips', 'frameBudget',
  'SA.FustBowState', 'SA.FustBowRefresh', 'SA.FustBowRestore',
  'SA.FustBowDispose', 'fustBowEnabled', 'hookfunction',
  'SA.GunState', 'SA.GunDispose', 'SA.GunFrame', 'ColorCorrectionEffect',
  'GunControl', 'ShotProbe', 'CameraKickFilter',
  'Shoot.FireServer', 'solveAim', 'findPeek', 'Fust.Items',
  'peek-origin', 'arrowLife',
  'pvFindSourceModel', 'pvCloneModel', 'pvBuildOverlays', 'pvApplyStyleTo',
  'SA.DrawDiag', 'SA.DrawBackend', 'SA.EspPreviewRefresh',
  'SA.ApplyTheme', 'SA.ApplyFont', 'SA.ThemeState', 'SA.FontState',
  'SA.INLINE_COLOR_BINDINGS', 'bindInlineColors',
  'uiTheme', 'uiFont', 'SA.UI_THEME_NAMES', 'SA.UI_FONT_NAMES',
  'SA.CFG_OFF_BASELINE', 'SA.BEST_STARTUP', 'SA.BEST_ESP_KEYS',
  'SA.ApplyBestStartup', 'SA.ApplyBestSetup', 'SA.ResetToOffBaseline',
  'SA.GunAutoRefresh', 'SA.GunAutoState', 'GMP.autoClock',
  'SA.RandomHitPart', 'SA.SilentAimBonePart', 'SA.ManipBonePart',
  'SA.HideEspBillboard', 'hideEspBillboard', 'cameraTurned',
  'saRandomHitPart', 'manipRandomHitPart',
];
for (const needle of requiredDist) {
  assert(dist.includes(needle), `dist/Hanami.lua is missing ${needle}`);
}
assert(!dist.includes('weasely111/beta'),
  'dist/Hanami.lua still references the dead external font repo');

// The shipped bundle must be features-only: no console output, no debug
// config/toggles, no print-only APIs and no self-check panel. The npm /
// Fengari harness in tools/ still prints its own results; that is separate.
const forbiddenDist = [
  'print(', 'warn(', 'dbg(', 'CFG.debug', 'gunDiffOnScan', 'HanamiSelfCheck',
  'SA.Print', 'SA.PlayerEspDiag', 'SA.EspPreviewDiag', 'SA.EspFeatureDiag',
  'SA.FeatureBindDiag', 'SA.NearestWindowDiag', 'SA.ShowSelfCheck',
  'SA.HideSelfCheck', 'SA.DisposeSelfCheckPanel',
  'Debug Log', 'name = "Debug"',
  'Print ESP Frame Budget', 'SA.PrintEspFrameBudget()',
];
for (const needle of forbiddenDist) {
  assert(!dist.includes(needle),
    `dist/Hanami.lua still has print/debug surface: ${needle}`);
}
for (const name of files) {
  const text = read(`src/${name}`);
  assert(!/\bprint\s*\(/.test(text), `${name} still calls print()`);
  assert(!/\bdbg\s*\(/.test(text), `${name} still calls dbg()`);
  assert(!/\bwarn\s*\(/.test(text), `${name} still calls warn()`);
  assert(!/\bCFG\.debug\b/.test(text), `${name} still uses CFG.debug`);
}

// New settings must exist in the shipped defaults, the backfill table,
// the clamp/normalisation pass, and at least one bound UI widget.
const newKeys = [
  'configProfile', 'configName', 'autoLoadConfig', 'keybindMode',
  'keybindSelected', 'nearestTopN',
  'nearestShowHealth', 'nearestShowState', 'nearestShowTeam',
  'nearestCorner', 'nearestScale', 'nearestTransparency',
  'showNoTargetReason', 'espOnlyNearest', 'espNearestCount',
  'espOnlyAimTarget', 'espTeamMode', 'espShowLiveCount', 'targetPriority',
  'fovPreset', 'targetBoneMode', 'espPreviewSource', 'espPreviewCompare',
  'perfMode', 'perfEspRebuildMs', 'perfMaxEntities', 'perfShowFps',
  'gunOverrideString', 'showManipPopup', 'espCleanMode',
  'manipNpcs', 'crateFovAware', 'showPlayerWarning', 'forceHead',
  'triggerbot', 'autoFire', 'triggerHeadOnly', 'triggerRandomPart',
  'triggerPart', 'triggerUseManip',
  'hitboxEnabled', 'hitboxTarget', 'hitboxMode', 'hitboxScale',
  'hitboxCap', 'hitboxMaxDist', 'hitboxTeamCheck', 'hitboxAliveOnly',
  'hitboxVisible', 'hitboxNpcs', 'fireWallCheck', 'espDataRefreshMs',
  'fustBowEnabled', 'fustBowFov', 'fustBowTargetPart',
  'fustBowManipulation', 'fustBowManipPeek', 'fustBowManipMaxDist',
  'fustBowOriginRadius',
  'gunNoSpread', 'gunShotProbe', 'gunInspectDefs', 'gunInspectScripts',
  'gunInspectGunControl', 'gunInspectLiveGun', 'gunNoRecoil',
  'gunCameraKickFilter', 'gunFireRate', 'gunFireRateMultiplier',
  'gunInfiniteAmmo', 'gunMoveShoot',
  'displayBrightnessEnabled', 'displayBrightness',
  'saRandomHitPart', 'manipRandomHitPart',
  'uiTheme', 'uiFont',
];
assert(newKeys.length === 77, `expected 77 new CFG keys, found ${newKeys.length}`);
const config = read('src/01_config.lua');
const shipped = config.slice(
  config.indexOf('SA_CFG_SHIPPED = {'),
  config.indexOf('CFG = _G.__saCFG')
);
const backfill = config.slice(
  config.indexOf('-- backfill'),
  config.indexOf('-- Older saved configs')
);
const clamps = config.slice(
  config.indexOf('CFG.configProfile'),
  config.indexOf('-- The old hardcoded')
);
assert(shipped.length > 100 && backfill.length > 100 && clamps.length > 100,
  'src/01_config.lua: could not isolate defaults/backfill/clamp sections');
const ui = [
  'src/21_ui_aiming.lua', 'src/22_esp_preview_setup.lua',
  'src/22_ui_esp.lua', 'src/23_ui_gunmods.lua',
  'src/24_ui_visual.lua', 'src/25_ui_misc.lua',
].map(read).join('\n');
for (const key of newKeys) {
  const keyAssignment = new RegExp(`(?:^|\\s)${key}\\s*=`, 'm');
  assert(keyAssignment.test(shipped), `shipped defaults missing ${key}`);
  assert(backfill.includes(key), `backfill missing ${key}`);
  assert(clamps.includes(`CFG.${key}`), `clamp/normalisation missing ${key}`);
  assert(ui.includes(`"hn_${key}"`) || ui.includes(`"${key}"`)
    || ui.includes(`CFG.${key}`), `no bound UI widget for ${key}`);
}

// Startup defaults: the shipped literal is a diagnostic OFF baseline,
// while the user-facing default snapshot is that baseline merged with the
// curated best setup. No stale `~= false` default-ON escape hatch remains.
const boolAssignment = /^\s*[A-Za-z_][A-Za-z0-9_]*\s*=\s*true\s*,/m;
assert(!boolAssignment.test(shipped),
  'src/01_config.lua: OFF baseline must not ship a boolean feature ON');
assert(!boolAssignment.test(backfill),
  'src/01_config.lua: backfill must not add a boolean feature ON');
const offBaseline = config.slice(
  config.indexOf('SA.CFG_OFF_BASELINE = {}'),
  config.indexOf('SA.BEST_STARTUP = {')
);
const bestStartup = config.slice(
  config.indexOf('SA.BEST_STARTUP = {'),
  config.indexOf('for k, v in pairs(SA.BEST_STARTUP)')
);
assert(offBaseline.includes('SA.CFG_OFF_BASELINE[k] = v'),
  'OFF baseline must copy the fully OFF shipped literal');
for (const key of [
  'masterEnabled', 'espEnabled', 'espCornerBox', 'gmEnabled', 'showFov',
  'snapLineEnabled', 'espPreview', 'nearestWindow', 'saRandomHitPart',
  'manipRandomHitPart', 'gunInspectDefs', 'gunInspectLiveGun',
]) {
  assert(bestStartup.includes(`${key} = true`),
    `curated best startup is missing ON key ${key}`);
}
for (const key of [
  'triggerbot', 'autoFire', 'bowModsEnabled', 'hitboxEnabled',
  'displayBrightnessEnabled',
]) {
  assert(bestStartup.includes(`${key} = false`),
    `curated best startup is missing OFF key ${key}`);
}
assert(config.includes(
  'for k, v in pairs(SA.BEST_STARTUP) do SA.CFG_DEFAULTS[k] = v end'),
  'curated best startup must be merged into SA.CFG_DEFAULTS');
assert(config.includes('function SA.ApplyBestStartup'),
  'one-time fresh-startup applier is missing');
const allSource = files.map((name) => read(`src/${name}`)).join('\n');
assert(!/CFG\.[A-Za-z0-9_]+\s*~=\s*false/.test(allSource),
  'src still treats a missing CFG boolean as ON');
assert(!allSource.includes('Vector3.zero'),
  'src still uses unsupported Vector3.zero fallbacks');
for (const label of [
  'Enable Inspect', 'Paused (enable', 'Enable live firing',
  'Silent State / Reports', 'Copy All Gun Reports',
  'Capture Gun State Baseline',
]) {
  assert(!allSource.includes(label),
    `src still exposes removed gun inspection/report UI: ${label}`);
}

// Automatic gun work: hidden always-ON flags, no inspect/report UI and a
// silent auto refresh / state API sharing the existing frame hook.
const gunUi = read('src/23_ui_gunmods.lua');
const gunApi = read('src/20_gm_z_api.lua');
for (const label of [
  'Inspect Definitions', 'Inspect Scripts', 'Inspect GunControl Exports',
  'Inspect Live Gun', 'Silent State / Reports', 'Copy All Gun Reports',
  'Capture Gun State Baseline',
]) {
  assert(!gunUi.includes(label),
    `Gun Mods UI still exposes removed control / column: ${label}`);
}
assert(gunUi.includes('Inspections + live scanner run automatically'),
  'automatic inspection UI label is missing');
assert(gunUi.includes('library.visible_flags[flag] = nil'),
  'hidden inspection flags must have no visible widget');
assert(gunUi.includes('library.config_flags[flag] = function()'),
  'hidden inspection flags must force themselves ON');
assert(gunApi.includes('function SA.GunAutoRefresh')
  && gunApi.includes('function SA.GunAutoState')
  && gunApi.includes('auto = GMP.copy(GMP.auto)')
  && gunApi.includes('SA.GunReport("all")'),
  'automatic silent gun refresh / state API is incomplete');

// ESP stuck-overlay / duplicate-tag / corner-box regressions.
const fxColours = read('src/18_esp_fx_colours.lua');
const fxDraw = read('src/18_esp_fx_draw.lua');
const fxFrame = read('src/18_esp_fx_frame.lua');
const drawing = read('src/02_drawing.lua');
assert(drawing.includes('liveMatches'),
  'per-property write cache must verify live Visible / Enabled');
assert(fxColours.includes('SA.HideEspBillboard = hideEspBillboard')
  && fxColours.includes('"Enabled", false')
  && fxColours.includes('local inView = ok == true and v3.Z > 0')
  && fxColours.includes('math.max(math.min(w, h) * 0.3, 8)'),
  'ESP billboard hide / viewport bounds / corner sizing are incomplete');
assert(fxDraw.includes(
  'local showBox    = cleanEsp or CFG.espShowBox == true or cornerBox')
  && fxDraw.includes('SA.HideEspBillboard(o)'),
  'corner boxes must force box segments and legacy labels must hide');
assert(fxFrame.includes('local cameraTurned = espCamSig.fxKey ~= camKey')
  && fxFrame.includes('local stride = cameraTurned and 1')
  && fxFrame.includes('skip and o.geomCache or nil')
  && fxFrame.includes('local inView = ok == true and z > 0'),
  'camera turns must force fresh geometry and cached skip frames must finalise FX');
const preview = read('src/22_esp_preview.lua');
assert(preview.includes(
  'local showBox   = cleanEsp or CFG.espShowBox == true or cornerBox'),
  'ESP preview corner boxes must force their own box style');

// Every custom colour ships white, has exactly one inline owner, and no
// separate ESP colour mini-tab / section survives.
const palette = config.slice(
  config.indexOf('local ESP_DEFAULT_COLORS = {'),
  config.indexOf('local ESP_COLORS = _G.__saEspColors')
);
const colorArgs = Array.from(palette.matchAll(/Color3\.fromRGB\(([^)]*)\)/g),
  (m) => m[1].trim());
assert(colorArgs.length === 48,
  `expected 48 ESP palette colours, found ${colorArgs.length}`);
assert(colorArgs.every((rgb) => rgb === '255, 255, 255'),
  'every customizable colour must default white');
const bindings = config.slice(
  config.indexOf('SA.INLINE_COLOR_BINDINGS = {'),
  config.indexOf('SA.INLINE_COLOR_OWNER = {}')
);
const boundColors = Array.from(
  bindings.matchAll(/\{\s*"[^"]+"\s*,\s*"([A-Za-z0-9_]+)"\s*\}/g),
  (m) => m[1]);
assert(boundColors.length === 48 && new Set(boundColors).size === 48,
  'expected 48 unique inline colourpicker bindings');
const espUi = read('src/22_ui_esp.lua');
const aimingUi = read('src/21_ui_aiming.lua');
assert(!/COLOR_GROUPS|colorCol|groupNames|lbl:colorpicker/.test(espUi),
  'src/22_ui_esp.lua still has a separate colour mini-tab');
assert(/bindInlineColors/.test(aimingUi)
  && /widget:colorpicker\(/.test(aimingUi),
  'inline colourpicker helper is missing');
for (const name of files) {
  if (name === '21_ui_aiming.lua') continue;
  assert(!read(`src/${name}`).includes(':colorpicker('),
    `${name} puts a colourpicker outside the inline helper`);
}

// Theme/font presets, event-driven application and no extra render loop.
const themeNames = config.match(/SA\.UI_THEME_NAMES\s*=\s*\{([\s\S]*?)\}/);
assert(themeNames, 'src/01_config.lua: theme name list missing');
const themeList = Array.from(themeNames[1].matchAll(/"([^"]+)"/g), (m) => m[1]);
assert(themeList.length >= 9,
  `expected at least 9 named themes, found ${themeList.length}`);
for (const name of themeList) {
  assert(config.includes(`["${name}"] = {`),
    `src/01_config.lua: missing full theme preset ${name}`);
}
const fontEntries = config.match(/\{\s*name\s*=\s*"[^"]+"\s*,\s*enum\s*=\s*"/g) || [];
assert(fontEntries.length >= 10,
  `expected at least 10 font picks, found ${fontEntries.length}`);
const themeKeys = config.match(/SA\.UI_THEME_KEYS\s*=\s*\{([\s\S]*?)\}/);
assert(themeKeys, 'src/01_config.lua: Atlanta theme key list missing');
assert((themeKeys[1].match(/"[^"]+"/g) || []).length === 9,
  'a theme preset must apply all 9 Atlanta theme colours');
const applyTheme = config.slice(config.indexOf('function SA.ApplyTheme'),
  config.indexOf('function SA.ThemeState'));
const applyFont = config.slice(config.indexOf('function SA.ApplyFont'),
  config.indexOf('function SA.FontState'));
assert(!/bindRender|RenderStepped|while\s+true/.test(applyTheme),
  'SA.ApplyTheme() must stay event-driven');
assert(!/bindRender|RenderStepped|while\s+true/.test(applyFont),
  'SA.ApplyFont() must stay event-driven');

// README must describe the current source tree, not an older build.
const readme = read('README.md');
const maxLines = Math.max(...lineCounts.values());
const intro = readme.match(/largest is (\d+) lines/);
assert(intro, 'README: largest-source line count not found');
assert(Number(intro[1]) === maxLines,
  `README says largest is ${intro[1]} lines, actual ${maxLines}`);
const rowRe = /^\|\s+`src\/([^`]+\.lua)`\s+\|([^|]*)\|\s*(\d+)\s*\|\s*$/gm;
const rows = Array.from(readme.matchAll(rowRe), (m) => ({
  file: m[1], description: m[2], lines: Number(m[3]),
}));
assert(rows.length === files.length,
  `README Files table has ${rows.length} rows, expected ${files.length}`);
// `files` entries are bare filenames; the required-description table uses
// `src/`-prefixed names. Expose both spellings for the same parsed row.
const rowByName = new Map(rows.flatMap((row) => [
  [row.file, row],
  [`src/${row.file}`, row],
]));
for (const name of files) {
  const row = rowByName.get(name);
  assert(row, `README Files table is missing ${name}`);
  assert(row.lines === lineCounts.get(name),
    `README ${name} says ${row.lines} lines, actual ${lineCounts.get(name)}`);
}
const requiredDescriptions = {
  'src/01_config.lua': ['themes', 'fonts', 'white',
    'curated best startup', 'off baseline', 'random hit parts',
    'automatic gun inspections', 'inline colours', 'profiles', 'self-check',
    'perf', 'clean', 'npc manipulation', 'trigger', 'wall check', 'warning',
    'force head', 'crate fov', 'npc hitbox', 'hitbox', 'esp data refresh',
    'fust bow'],
  'src/02_drawing.lua': ['capability', 'draw pool', 'sync batching',
    'per-property', 'live visibility check'],
  'src/03_entity_scan.lua': ['npc registry', 'visibility', 'raw list'],
  'src/02_shared.lua': ['fov', 'pinned', 'npc classifier', 'force head',
    'trigger bone', 'vis', 'wall check', 'independent random hit parts',
    'silent-aim / manip / trigger scopes'],
  'src/05_manipulation.lua': ['popup', 'probe', 'npc', 'fire-assist',
    'manip random hit part'],
  'src/08_prediction.lua': ['gun diff', 'override'],
  'src/09_silent_aim.lua': ['silent aim', 'guns only', 'trigger', 'auto fire',
    'vis', 'wall check', 'tool-first', 'mouse1click',
    'dedicated fust bow part', 'silent random hit part'],
  'src/09_z_fust_bow.lua': ['fust bow', 'ballistic', 'hookfunction',
    'shoot.fireserver', 'peek-origin', 'fov', 'bow specs', 'state'],
  'src/13_esp_players_refresh.lua': ['per-player', 'cached player rig', 'vis',
    'shared projection cache', 'geometry cache'],
  'src/14_esp_npcs.lua': ['npc esp', 'cached rig'],
  'src/15_esp_npcs_refresh.lua': ['npc esp', 'cached rig', 'vis',
    'shared projection cache', 'geometry cache'],
  'src/16_esp_crates_registry.lua': ['crate registry', 'raw list'],
  'src/18_esp_fx_colours.lua': ['palette', 'legacy line', 'usage marks',
    'geometry cache', 'rainbow clock', 'billboard', 'viewport bounds',
    'minimum corner segments'],
  'src/18_esp_fx_draw.lua': ['clean', 'outline', 'crate fov', 'off-screen',
    'legacy line', 'hoisted helpers', 'usage marks', 'direct segments',
    'corner boxes force box', 'one name tag'],
  'src/18_esp_fx_frame.lua': ['per-frame', 'crate fov', 'team map',
    'cached rig', 'fps', 'geometry cache', 'geometry slicing',
    'camera signature', 'priority slicing', 'hidden pass',
    'one fewer pcall', 'camera-turn fresh geometry',
    'no stale geometry skips'],
  'src/19_render_loop.lua': ['adaptive', 'fps', 'data refresh', 'raw list',
    'frame budget', 'geometry budget', 'geometry slicing',
    'rolling fps', 'performance mode'],
  'src/21_ui_aiming.lua': ['preset', 'priority', 'bone', 'npc manipulation',
    'trigger', 'auto fire', 'wall check', 'force head',
    'silent-aim independent', 'npc hitbox', 'hitbox', 'fust bow',
    'inline colourpicker', 'atlanta source sanitizer', 'built-in font fallback',
    'error-page markers', 'two independent random hit-part toggles'],
  'src/20_hitbox_expander.lua': ['hitbox', 'players + npcs', 'r6/r15',
    'npc', 'hrp fallback', 'self-healing', 'restore'],
  'src/22_esp_preview.lua': ['real-model', 'side-by-side', 'clean',
    'corner boxes force box'],
  'src/22_ui_esp.lua': ['declutter', 'live count', 'clean', 'crate fov',
    'inline', 'no colour mini-tabs', 'curated best esp preset',
    'corner boxes force box'],
  'src/24_ui_visual.lua': ['theme', 'font', 'top-n', 'performance', 'keybind', 'popup',
    'npc', 'warning', 'fire assist', 'esp data', 'frame budget',
    'utilities'],
  'src/25_ui_misc.lua': ['theme', 'font', 'profile', 'self-check', 'full unload',
    'npc manipulation', 'warning', 'fire assist', 'crate fov', 'force head',
    'hitbox state', 'hitbox', 'draw sync', 'esp perf', 'frame budget',
    'fust bow', 'apply best setup', 'off baseline', 'automatic gun refresh'],
};
for (const [name, needles] of Object.entries(requiredDescriptions)) {
  const description = rowByName.get(name).description.toLowerCase();
  for (const needle of needles) {
    assert(description.includes(needle),
      `README ${name} row is missing "${needle}"`);
  }
}
const requiredDocs = [
  '## BETTER quality-of-life pass',
  'Native Atlanta config profiles',
  'Real full unload',
  'Top-N nearest-player HUD',
  'All-keybind manager',
  'ESP decluttering',
  'real-model',
  'side-by-side',
  'Adaptive performance mode',
  'ESP FPS optimization',
  'coalesced',
  'raw list',
  'SA.DrawSyncFlush()',
  'SA.DrawSyncStats()',
  'SA.EspPerfState()',
  'SA.EspDataIntervalFrames()',
  'espDataRefreshMs',
  'Manipulation crosshair popup',
  '### NPC manipulation support',
  'Manipulate NPCs',
  '### Crate ESP FOV-aware',
  'FOV-Aware Crate ESP',
  '### 100 m player warning',
  '100m Player Warning',
  '### Triggerbot / Auto Fire',
  'Triggerbot',
  'Auto Fire',
  'Manipulation Support',
  'VIS player in FOV',
  'Fire Assist Wall Check',
  'CFG.fireWallCheck',
  'VIS target in FOV',
  'Tool:Activate()',
  'mouse1click',
  'silent-aim independent',
  '### Silent aim Force Head',
  'Force Head (Silent Aim)',
  '### Hitbox Expander v2',
  'Enable Hitbox Expander',
  'SA.HitboxState()',
  'SA.SelfCheck()',
  'SA.SelfCheckState()',
  '## Features only (no console output)',
  'no console output',
  'SA.HitboxRestore()',
  'SA.HitboxScan()',
  'R6/R15',
  'self-healing',
  'getgenv().hitbox',
  'SA.CrateFovState()',
  'SA.PlayerWarningState()',
  'SA.FireAssistState()',
  'SA.ForceHeadState()',
  '5,084 assertions',
  'all 77 new CFG keys',
  '## Themes, fonts, inline colours and curated startup',
  'Curated best startup',
  'Automatic gun inspections / reports',
  'Independent random hit parts',
  'ESP stuck-overlay / duplicate-tag / corners fix',
  'SA.ApplyBestSetup()',
  'SA.ResetToOffBaseline()',
  'SA.GunAutoState()',
  'saRandomHitPart',
  'manipRandomHitPart',
  'camera turns force fresh geometry',
  'corner boxes force their own box segments',
  'inspections / scanner / reports run automatically with no tab toggle or column',
  'OFF baseline plus curated best startup',
  '9 additional themes',
  '10 popular script-community font picks',
  '60-50 FPS',
  'Visual → Theme',
  'curated best setup',
  'default white',
  'no second RenderStepped',
  'event-driven',
  'SA.ApplyTheme()',
  'SA.ApplyFont()',
  'SA.ThemeState()',
  'SA.FontState()',
  'uiTheme',
  'uiFont',
  '44-part list',
  '### Fust bow ballistic silent aim',
  'Fust Bow Ballistic Aim',
  'SA.FustBowState()',
  'SA.FustBowRefresh()',
  'SA.FustBowRestore()',
  'SA.FustBowDispose()',
  'fustBowEnabled',
  'hookfunction',
  '### V16.46-style gun mods, brightness and shot probe',
  'SA.GunState()',
  'SA.GunLiveReport()',
  'SA.GunDefinitionReport()',
  'SA.GunControlReport()',
  'SA.GunFireScriptReport()',
  'SA.GunFrame(dt, now)',
  'ColorCorrectionEffect',
  'ShotProbe',
  'CameraKickFilter',
  'GunControl',
  'peek-origin',
  'Fust.Items',
  'ESP 60 FPS frame-budget pass',
  'SA.EspFrameBudget()',
  'per-property instance writes',
  'usage marks',
  'frame budget',
  '### Loader / Atlanta UI font bootstrap fix',
  'dead external font asset',
  'SA.SanitizeAtlantaSource()',
  'ATLANTA_ROOTS',
  'SourceSansPro',
  'error-page markers',
  'dist/Hanami.lua is gitignored',
  'branch-specific loader URL',
  '### Adaptive ESP geometry slicing and cache',
  'adaptive geometry slicing',
  'SA.EspGeom()',
  'SA.EspGeometryBudget()',
  'SA.EspGeomState()',
  'SA.EspGeomReset()',
  'SA.EspGeomInvalidate()',
  'geometry cache',
  'camera signature',
  'cameraKeyBuilds',
  'savedW2vCalls',
  'geometryUpdates',
  'geometryHiddenPasses',
  'geometryBucket',
  'geometryFps',
  'geometryLastDtMs',
  'priority',
  'rainbow clock',
  'one fewer pcall',
  'disabled ESP early-out',
  'geometryStride',
  'geometryBudget',
  'geometrySkips',
  'w2vCalls',
  'cacheHits',
  'rolling FPS only',
  'Performance Mode is explicitly ON',
  'hitboxNpcs',
  'Expand NPC Hitboxes',
  'NPC HRP fallback',
  'NPC hitbox coverage',
  'SA.ManipNpcState()',
  'Clean ESP',
  'outlines only',
  'Live gun diff',
  '## Testing',
  'npm ci && npm test',
  'Fengari',
  'not a real Roblox executor',
];
for (const needle of requiredDocs) {
  assert(readme.includes(needle), `README is missing documentation: ${needle}`);
}

console.log(`[static] ${files.length} parts parsed, loader/dist/README/CFG checks OK`);
console.log(`[static] dist ${lines(dist)} lines, 0 column-1 locals, one final return`);
