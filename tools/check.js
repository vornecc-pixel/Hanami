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
];
assert(newKeys.length === 73, `expected 73 new CFG keys, found ${newKeys.length}`);
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
  'src/01_config.lua': ['profiles', 'self-check', 'perf', 'clean',
    'npc manipulation', 'trigger', 'wall check', 'warning', 'force head',
    'crate fov', 'npc hitbox', 'hitbox', 'esp data refresh', 'fust bow'],
  'src/02_drawing.lua': ['capability', 'draw pool', 'sync batching',
    'per-property'],
  'src/03_entity_scan.lua': ['npc registry', 'visibility', 'raw list'],
  'src/02_shared.lua': ['fov', 'pinned', 'npc classifier', 'force head',
    'trigger bone', 'vis', 'wall check'],
  'src/05_manipulation.lua': ['popup', 'probe', 'npc', 'fire-assist'],
  'src/08_prediction.lua': ['gun diff', 'override'],
  'src/09_silent_aim.lua': ['silent aim', 'guns only', 'trigger', 'auto fire',
    'vis', 'wall check', 'tool-first', 'mouse1click',
    'dedicated fust bow part'],
  'src/09_z_fust_bow.lua': ['fust bow', 'ballistic', 'hookfunction',
    'shoot.fireserver', 'peek-origin', 'fov', 'bow specs', 'state'],
  'src/13_esp_players_refresh.lua': ['per-player', 'cached player rig', 'vis',
    'shared projection cache', 'geometry cache'],
  'src/14_esp_npcs.lua': ['npc esp', 'cached rig'],
  'src/15_esp_npcs_refresh.lua': ['npc esp', 'cached rig', 'vis',
    'shared projection cache', 'geometry cache'],
  'src/16_esp_crates_registry.lua': ['crate registry', 'raw list'],
  'src/18_esp_fx_colours.lua': ['palette', 'legacy line', 'usage marks',
    'geometry cache', 'rainbow clock'],
  'src/18_esp_fx_draw.lua': ['clean', 'outline', 'crate fov', 'off-screen',
    'legacy line', 'hoisted helpers', 'usage marks', 'direct segments'],
  'src/18_esp_fx_frame.lua': ['per-frame', 'crate fov', 'team map',
    'cached rig', 'fps', 'geometry cache', 'geometry slicing',
    'camera signature', 'priority slicing', 'hidden pass',
    'one fewer pcall'],
  'src/19_render_loop.lua': ['adaptive', 'fps', 'data refresh', 'raw list',
    'frame budget', 'geometry budget', 'geometry slicing',
    'rolling fps', 'performance mode'],
  'src/21_ui_aiming.lua': ['preset', 'priority', 'bone', 'npc manipulation',
    'trigger', 'auto fire', 'wall check', 'force head',
    'silent-aim independent', 'npc hitbox', 'hitbox', 'fust bow',
    'atlanta source sanitizer', 'built-in font fallback',
    'error-page markers'],
  'src/20_hitbox_expander.lua': ['hitbox', 'players + npcs', 'r6/r15',
    'npc', 'hrp fallback', 'self-healing', 'restore'],
  'src/22_esp_preview.lua': ['real-model', 'side-by-side', 'clean'],
  'src/22_ui_esp.lua': ['declutter', 'live count', 'clean', 'crate fov'],
  'src/24_ui_visual.lua': ['top-n', 'performance', 'keybind', 'popup',
    'npc', 'warning', 'fire assist', 'esp data', 'frame budget',
    'utilities'],
  'src/25_ui_misc.lua': ['profile', 'self-check', 'full unload',
    'npc manipulation', 'warning', 'fire assist', 'crate fov', 'force head',
    'hitbox state', 'hitbox', 'draw sync', 'esp perf', 'frame budget',
    'fust bow'],
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
  '3,521 assertions',
  'all 73 new CFG keys',
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
