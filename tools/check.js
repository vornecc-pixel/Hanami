/* Hanami / tools/check.js — committed static checks for npm test.
 * Verifies Lua syntax, loader/parts synchronisation, the hoisted bundle,
 * README file rows / line counts, and the BETTER config-key coverage.
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
  parseLua(`src/${name}`, read(`src/${name}`));
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
  'SA.ConfigCoverage', 'SA.SelfCheck', 'SA.ShowSelfCheck',
  'SA.DisposeSelfCheckPanel', 'SA.SetAllKeybindModes', 'SA.KeybindConflicts',
  'SA.StartRebind', 'SA.ClearSelectedKeybind', 'SA.DisposePerfOverlay',
  'HanamiPerfOverlay', 'HanamiSelfCheck', 'SA.NearestWindowState',
  'SA.EspPassAllowed', 'SA.EspPassStats', 'SA.PerfEffectiveRebuildMs',
  'SA.PerfEffectiveEntityCap', 'SA.DrawPoolStats', 'SA.DrawWriteFailures',
  'SA.GunDiff', 'SA.ApplyGunOverrides', 'SA.SyncGunDefs',
  'SA.PinNearestTarget', 'SA.NoTargetReason', 'SA.ResolveTargetBone',
  'SA.IsNpcModel', 'SA.ManipNpcState', 'SA.PrintManipNpcState',
  'pvFindSourceModel', 'pvCloneModel', 'pvBuildOverlays', 'pvApplyStyleTo',
];
for (const needle of requiredDist) {
  assert(dist.includes(needle), `dist/Hanami.lua is missing ${needle}`);
}

// New settings must exist in the shipped defaults, the backfill table,
// the clamp/normalisation pass, and at least one bound UI widget.
const newKeys = [
  'configProfile', 'configName', 'autoLoadConfig', 'keybindMode',
  'keybindConflictWarn', 'keybindSelected', 'nearestTopN',
  'nearestShowHealth', 'nearestShowState', 'nearestShowTeam',
  'nearestCorner', 'nearestScale', 'nearestTransparency',
  'showNoTargetReason', 'espOnlyNearest', 'espNearestCount',
  'espOnlyAimTarget', 'espTeamMode', 'espShowLiveCount', 'targetPriority',
  'fovPreset', 'targetBoneMode', 'espPreviewSource', 'espPreviewCompare',
  'perfMode', 'perfEspRebuildMs', 'perfMaxEntities', 'perfShowFps',
  'gunDiffOnScan', 'gunOverrideString', 'showManipPopup', 'espCleanMode',
  'manipNpcs',
];
assert(newKeys.length === 33, `expected 33 new CFG keys, found ${newKeys.length}`);
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
  'src/01_config.lua': ['profiles', 'self-check', 'perf', 'clean', 'npc manipulation'],
  'src/02_shared.lua': ['fov', 'pinned', 'npc classifier'],
  'src/05_manipulation.lua': ['popup', 'probe', 'npc'],
  'src/08_prediction.lua': ['gun diff', 'override'],
  'src/18_esp_fx_draw.lua': ['clean', 'outline'],
  'src/19_render_loop.lua': ['adaptive', 'fps'],
  'src/21_ui_aiming.lua': ['preset', 'priority', 'bone', 'npc manipulation'],
  'src/22_esp_preview.lua': ['real-model', 'side-by-side', 'clean'],
  'src/22_ui_esp.lua': ['declutter', 'live count', 'clean'],
  'src/24_ui_visual.lua': ['top-n', 'performance', 'keybind', 'popup', 'npc'],
  'src/25_ui_misc.lua': ['profile', 'self-check', 'full unload', 'npc manipulation'],
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
  'In-game self-check panel',
  'Real full unload',
  'Top-N nearest-player HUD',
  'All-keybind console',
  'ESP decluttering',
  'real-model',
  'side-by-side',
  'Adaptive performance mode',
  'Manipulation crosshair popup',
  '### NPC manipulation support',
  'Manipulate NPCs',
  '1,406 assertions',
  'all 33 new CFG keys',
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
