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
  'SA.GetWeaponStatus', 'SA.EspHideDuplicateOverlays',
  'SA.EspDuplicateCleanupState', 'SA.NearestWindowResetPosition',
  'SA.NearestDisplay',
  'SA.Connect', 'SA.TrackConnection', 'SA.DisconnectConnections',
  'SA.ConnectionState', 'SA.DrawForget', 'SA.DrawRemove', 'SA.DrawState',
  'SA.DrawDisposeAll', 'SA.DisposeHanamiGuis', 'SA.HanamiGuiState',
  'SA.VisualState', 'SA.FovDispose', 'SA.SnaplineDispose',
  'SA.FullUnloadState',
  'SA.GetStaffRole', 'SA.StaffDetectState', 'SA.UnknownHumanoidKind',
  'SA.UnknownHumanoidEvidence', 'SA.UnknownHumanoidState',
  'SA.UnknownHumanoidListRaw', 'SA.ScanStep', 'SA.ScanPassNow',
  'SA.DetectorReadoutTick',
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
  'armorConsole', 'armorConsoleFov', 'armorConsoleShowTotals',
  'armorConsoleMaxDist', 'armorConsoleScanSec', 'armorConsoleSort',
  'armorConsoleCorner', 'armorConsoleScale', 'armorConsoleTransparency',
  'armorConsoleMaxPlayers',
  'handChams', 'handChamsStyle', 'handChamsIntensity', 'handChamsAura',
  'handChamsSpikes', 'weaponChams', 'weaponChamsStyle',
  'weaponChamsIntensity', 'weaponChamsAura', 'weaponChamsSpikes',
  'gunNoSpread', 'gunShotProbe', 'gunInspectDefs', 'gunInspectScripts',
  'gunInspectGunControl', 'gunInspectLiveGun', 'gunNoRecoil',
  'gunCameraKickFilter', 'gunFireRate', 'gunFireRateMultiplier',
  'gunInfiniteAmmo', 'gunMoveShoot',
  'displayBrightnessEnabled', 'displayBrightness',
  'uiTheme', 'uiFont',
  'espStaffDetect', 'unknownHumanoidScan',
  'fovMode', 'fovDegrees', 'fovHitbox', 'fovStyle', 'fovSegments',
];
assert(newKeys.length === 102, `expected 82 new CFG keys, found ${newKeys.length}`);
const config = read('src/01_config.lua');
const shipped = config.slice(
  config.indexOf('SA_CFG_SHIPPED = {'),
  config.indexOf('CFG = _G.__saCFG')
);
const backfill = config.slice(
  config.indexOf('-- backfill'),
  config.indexOf('-- Older saved configs')
);
// The FOV reference / measurement block is clamped just BEFORE the
// config-profile block, so start the slice at the FOV reference clamp:
// that keeps fovMode / fovDegrees / fovHitbox inside the checked range
// instead of silently escaping the normalisation guard.
const clamps = config.slice(
  config.indexOf('-- FOV reference + visible circle'),
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

// Startup defaults: every shipped/backfilled non-ESP boolean is OFF. The
// ESP-only best preset is the sole fresh-session exception and is applied
// after the immutable shipped literal. No stale `~= false` hatch remains.
const boolAssignment = /^\s*[A-Za-z_][A-Za-z0-9_]*\s*=\s*true\s*,/m;
assert(!boolAssignment.test(shipped),
  'src/01_config.lua still ships a boolean feature default ON');
assert(!boolAssignment.test(backfill),
  'src/01_config.lua still backfills a boolean feature default ON');
const allSource = files.map((name) => read(`src/${name}`)).join('\n');
assert(!/CFG\.[A-Za-z0-9_]+\s*~=\s*false/.test(allSource),
  'src still treats a missing CFG boolean as ON');

// Rollback guard: the old all-in-one curated startup / automatic gun APIs
// must not return. Only the ESP family may be switched ON at load.
for (const banned of [
  'SA.BEST_STARTUP', 'SA.BEST_ESP_KEYS', 'SA.CFG_OFF_BASELINE',
  'SA.ApplyBestSetup', 'SA.ResetToOffBaseline', 'SA.GunAutoRefresh',
  'saRandomHitPart', 'manipRandomHitPart',
]) {
  assert(!allSource.includes(banned),
    `rolled-back all-in-one API returned: ${banned}`);
}
const startupStart = config.indexOf('SA.BEST_ESP_STARTUP = {');
const startupEnd = config.indexOf('for k, v in pairs(SA.BEST_ESP_STARTUP)',
  startupStart);
assert(startupStart > 0 && startupEnd > startupStart,
  'src/01_config.lua: ESP-only startup snapshot missing');
const startupBlock = config.slice(startupStart, startupEnd);
const startupKeys = Array.from(
  startupBlock.matchAll(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=/gm),
  (m) => m[1]);
assert(startupKeys.length >= 20,
  `expected a full ESP startup preset, found ${startupKeys.length} keys`);
for (const key of startupKeys) {
  assert(/^(esp|npc)/.test(key),
    `non-ESP key in BEST_ESP_STARTUP: ${key}`);
}
for (const needle of [
  'espEnabled = true', 'npcEspEnabled = true', 'espCornerBox = true',
  'espShowFill = false', 'espShowTracer = false',
  'espShowOffscreen = false', 'espPreview = true',
  'if saFreshStartup then',
]) {
  assert(startupBlock.includes(needle) || config.includes(needle),
    `ESP-only startup missing ${needle}`);
}
assert(config.includes('local saFreshStartup = _G.__saCFG == nil'),
  'fresh-session marker must be cleared by FullUnload');
assert(allSource.includes('function SA.BestEspState()'),
  'src/22_ui_esp.lua: BestEspState() missing');
assert(allSource.includes('SA.HideEspBillboard = hideEspBillboard'),
  'src/18_esp_fx_colours.lua: legacy-label hide missing');
assert(allSource.includes('cameraTurned and 1'),
  'src/18_esp_fx_frame.lua: camera-turn fresh geometry missing');

// Tag layout: the right-hand tag column must start BELOW the name row,
// and a distant player box must keep a minimum size (it used to collapse
// to a sliver, stacking every label onto one pixel row).
assert(allSource.includes('local sideTop = g.y + rowH + 2'),
  'src/18_esp_fx_draw.lua: side tag column must clear the name row');
assert(!allSource.includes('side and (g.y + (i - 1) * rowH)'),
  'src/18_esp_fx_draw.lua: side tags must not start on the name row');
{
  const fxFrame = read('src/18_esp_fx_frame.lua');
  const floorCount =
    (fxFrame.match(/math\.max\(math\.abs\(hv\.Y - lv\.Y\), 18\)/g) || []).length;
  assert(floorCount >= 2,
    'src/18_esp_fx_frame.lua: player box needs the same height floor as crates');
  assert(fxFrame.includes('math.max(h / 2, 12)'),
    'src/18_esp_fx_frame.lua: player box width floor missing');
}

// Cold start: an enabled kind with no objects must build immediately
// instead of waiting out the Performance Mode interval.
assert(allSource.includes('COLD START GUARD'),
  'src/19_render_loop.lua: cold-start build guard missing');

// A target behind the camera projects to a MIRRORED pixel, and
// WorldToViewportPoint's onScreen flag is true there. Both FOV
// membership helpers must reject non-positive depth or silent aim /
// snapline lock onto people the player has turned away from.
assert(allSource.includes('if (tonumber(sp.Z) or 0) <= 0 then return false end'),
  'src/02_shared.lua: FovPointInside must reject behind-camera points');
assert(allSource.includes('if zHead ~= nil and zHead <= 0 then spHead = nil end'),
  'src/02_shared.lua: FovSegmentInside must reject behind-camera endpoints');

// The snapline owns its own four draws and nothing else. It used to call
// SA.PreviewTargetReset() from hideSnap(), which runs every render frame
// while the toggle is OFF — wiping the shared preview memo 60x/second and
// making the ESP target highlight / nearest-set flicker permanently.
{
  const snapSrc = read('src/11_snapline.lua');
  const hideStart = snapSrc.indexOf('local function hideSnap()');
  const hideEnd = snapSrc.indexOf('function SA.SnaplineDispose()');
  assert(hideStart > 0 && hideEnd > hideStart,
    'src/11_snapline.lua: hideSnap not found');
  // Comments stripped, so the explanatory note above cannot satisfy or
  // defeat this check — only a real call would.
  const hideBody = snapSrc.slice(hideStart, hideEnd)
    .replace(/--[^\n]*/g, '');
  assert(!hideBody.includes('PreviewTargetReset'),
    'src/11_snapline.lua: hideSnap must not clear the shared preview memo');
}
assert(read('src/11_snapline.lua').includes('snapWasOn'),
  'src/11_snapline.lua: disabled path must early-exit without doing work');

// FOV circle is the sole non-ESP startup exception: ON, solid, visible,
// mouse reference, with a separate 1-10 snapline size control.
const fovStart = config.indexOf('SA.FOV_STARTUP = {');
const fovEnd = config.indexOf('for k, v in pairs(SA.FOV_STARTUP)', fovStart);
assert(fovStart > 0 && fovEnd > fovStart,
  'src/01_config.lua: FOV startup snapshot missing');
const fovBlock = config.slice(fovStart, fovEnd);
const fovBody = fovBlock.slice(fovBlock.indexOf('{') + 1,
  fovBlock.indexOf('}'));
const fovKeys = Array.from(
  fovBody.matchAll(/([A-Za-z_][A-Za-z0-9_]*)\s*=/g), (m) => m[1]);
assert(fovKeys.length >= 6,
  `expected a full FOV startup preset, found ${fovKeys.length} keys`);
for (const key of fovKeys) {
  assert(/^(fov|show|snapLine|force)/.test(key),
    `non-FOV key in FOV_STARTUP: ${key}`);
}
for (const needle of [
  'showFov = true', 'fovTransparency = 1', 'fovThickness = 3',
  'fovCenterMode = "Mouse"', 'snapLineThickness = 3',
]) {
  assert(fovBlock.includes(needle), `FOV startup missing ${needle}`);
}
assert(!/CFG\.fovCenterMode\s*~=\s*"Screen Center"/.test(allSource),
  'FOV reference must not fall back to a stale Screen Center mode');
assert(allSource.includes('SA.EspFovSnapshot = espFovSnapshot'),
  'raw FOV projection snapshot missing');
assert(allSource.includes('function SA.EspFovState()'),
  'ESP FOV state API missing');
assert(allSource.includes('function SA.SnaplineState()'),
  'snapline state API missing');
assert(allSource.includes('local drawSig = table.concat'),
  'per-frame draw signature missing');
assert(allSource.includes('SA.EspDrawSignature = drawSig'),
  'draw signature must be stored once per real change');
assert(allSource.includes('SA.EspStyleSweep'),
  'one-shot ESP style sweep missing');
assert(!allSource.includes('tostring(targetModel ~= nil)'),
  'the live aim target must NEVER be part of the draw signature');
assert(allSource.includes('SA.EspFovTransitions'),
  'FOV transition counter missing');
assert(read('src/10_fov_circle.lua').includes('CFG.fovTransparency or 1'),
  'FOV circle must default to the solid 1% transparency');
assert(read('src/10_fov_circle.lua').includes('CFG.fovThickness or 3'),
  'FOV circle must default to the 3px stroke');
assert(config.includes('if _G.__saFovFix ~= 5 then'),
  'FOV migration marker must be bumped for the 3px defaults');
assert(read('src/02_shared.lua').includes('(p.X > 0 or p.Y > 0)'),
  'AimPoint must reject the invalid (0,0) mouse sentinel');
const snapSrc = read('src/11_snapline.lua');
assert(snapSrc.includes('if not CFG.snapLineEnabled then'),
  'snapline must work with its own toggle only');
assert(!snapSrc.includes('CFG.snapLineEnabled and CFG.masterEnabled'),
  'snapline must not require the Silent Aim master gate');
assert(snapSrc.includes('Thickness = 3'),
  'snapline must ship a thick 3px line');
assert(read('src/09_silent_aim.lua').includes('local function saRefreshAimTarget()'),
  'Gun Silent Aim must refresh the shared ESP aim target');
assert(read('src/25_ui_misc.lua').includes('_G.__saFovFix = nil'),
  'FullUnload must clear the FOV migration marker');
assert(read('src/24_ui_visual.lua').includes('Works with just this toggle ON'),
  'snapline tooltip must document the independent toggle');
// FOV duplicate-overlay cleanup + draggable nearest-player profile card.
assert(read('src/04_entity_info.lua').includes('function SA.GetWeaponStatus(model)'),
  'shared Equipped / Holstered / Unknown weapon status missing');
assert(read('src/12_esp_players.lua').includes('purgeGhostEsp'),
  'named ghost BillboardGui / Highlight purge missing');
assert(read('src/13_esp_players_refresh.lua').includes(
  'o.bb.Enabled = not screenSpace'),
  'legacy BillboardGui must stay OFF during the FX-mode refresh');
assert(read('src/18_esp_fx_colours.lua').includes(
  'function SA.EspHideDuplicateOverlays('),
  'FOV duplicate / ghost overlay cleanup missing');
assert(read('src/18_esp_fx_draw.lua').includes('SA.EspHideDuplicateOverlays'),
  'FOV transition must call duplicate-overlay cleanup');
assert(read('src/03_entity_scan.lua').includes('GetUserThumbnailAsync'),
  'nearest-player Roblox headshot missing');
assert(read('src/03_entity_scan.lua').includes('UserInputService.InputChanged'),
  'nearest-player real pointer drag missing');
assert(read('src/03_entity_scan.lua').includes(
  'function SA.NearestWindowResetPosition()'),
  'nearest-player drag reset missing');
assert(read('src/03_entity_scan.lua').includes('SA.NearestDisplay ='),
  'shared nearest display-name formatter missing');
assert(read('src/25_ui_misc.lua').includes('_G.__saNearestWindowPos = nil'),
  'FullUnload must clear the session drag position');
const frameSrc = read('src/18_esp_fx_frame.lua');
for (const needle of [
  'tostring(CFG.masterEnabled)', 'tostring(CFG.gunEnabled)',
  'tostring(CFG.snapLineEnabled)', 'tostring(CFG.showFov)',
]) {
  assert(frameSrc.includes(needle),
    `ESP draw signature must include ${needle}`);
}
// The stutter fix: per-entity FOV state keys on the entity's own
// viewport / FOV membership only, never on the shared draw signature.
// The player builder must register its object even when an OPTIONAL
// widget fails. Wrapping BillboardGui + Highlight + Lines + registration
// in one pcall is what made player ESP dead on clients that reject a
// single property (Highlight.DepthMode) while NPC/crate ESP kept working.
const drawSrc = read('src/18_esp_fx_draw.lua');
const playerSrc = read('src/12_esp_players.lua');
assert(playerSrc.includes('espObjects[plr] = {'),
  'buildESP must register the player object');
assert(!/local ok = pcall\(function\(\)[\s\S]{0,4000}?espObjects\[plr\] = \{/.test(playerSrc),
  'buildESP must not wrap object registration in the widget pcall');
assert(playerSrc.includes('pcall(function() h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)'),
  'Highlight.DepthMode must be individually guarded');
assert(playerSrc.includes('local okLine, d = pcall(function() return SA.NewDraw("Line") end)'),
  'each legacy Line must be created independently');
const refreshSrc = read('src/13_esp_players_refresh.lua');
assert(refreshSrc.includes('if o.bb then o.bb.Enabled = not screenSpace end'),
  'the refresh must be nil-safe about the optional BillboardGui');
assert(refreshSrc.includes('if o.nameLbl then'),
  'the refresh must be nil-safe about the optional labels');
assert(drawSrc.includes('if not l then'),
  'setFxLine must fall through to a pooled draw for a missing legacy line');
assert(drawSrc.includes('local fovState = tostring(fov.onScreen)'),
  'per-entity FOV state key must not include the draw signature');
// REWRITE guard: an FOV crossing may only clear the FOV-owned draw group.
// Calling hideFx() here wiped the whole entity (box, name, chams) on every
// circle crossing, which is the "ESP slides away while you look at it"
// bug. Neither hideFx nor a geometry deferral may come back.
assert(!/if o\.espFovState ~= fovState then[\s\S]{0,400}?pcall\(hideFx, o\)/.test(drawSrc),
  'FOV transition must not hide the whole entity (only the fov draw group)');
assert(drawSrc.includes('pcall(hideFxGroup, o, "fov")'),
  'FOV transition must clear only the fov draw group');
assert(!/o\.geomForceFresh = true/.test(
  drawSrc.slice(drawSrc.indexOf('if o.espFovState ~= fovState'), drawSrc.indexOf('if o.espFovState ~= fovState') + 600)),
  'FOV transition must not defer geometry by a frame');
// NPC ESP is FOV-independent by request: the NPC branch builds a neutral
// snapshot instead of reading the aim circle.
assert(drawSrc.includes('if pal == "npc" then'),
  'NPC ESP must have its own non-FOV snapshot branch');
// The snapline preview is player-only.
const sharedSrc = read('src/02_shared.lua');
assert(sharedSrc.includes('playersOnly'),
  'pickBestTarget must support a players-only preview');
assert(sharedSrc.includes('if CFG.targetNpcs and not playersOnly then'),
  'the players-only preview must skip the NPC candidate list');
assert(!drawSrc.includes('SA.EspDrawSignature or ""'),
  'per-entity FOV state key must not fold in the draw signature');
assert(frameSrc.includes('local function playerFxStale('),
  'dead / teleported / streamed-out player cleanup missing');
assert(frameSrc.includes('stalePlayerCleanup(o, "dead")'),
  'dead-player ESP cleanup branch missing');
assert(frameSrc.includes('stalePlayerCleanup(o, "out of range")'),
  'teleported / out-of-range ESP cleanup branch missing');
assert(frameSrc.includes('SA.EspGhostCleanup'),
  'ghost cleanup counters missing');
// NPC smoothing: the expensive tag / text rebuild is throttled.
assert(read('src/15_esp_npcs_refresh.lua').includes('local function npcFullDue()'),
  'NPC text refresh throttle missing');
assert(read('src/15_esp_npcs_refresh.lua').includes('if not full and o.tx then'),
  'NPC cheap visibility branch missing');
// Shared per-frame target: one candidate scan per frame, not per consumer.
assert(read('src/02_shared.lua').includes('function SA.PreviewTarget(refresh)'),
  'shared per-frame preview target missing');
assert(read('src/02_shared.lua').includes('function SA.PreviewTargetReset()'),
  'shared preview target reset missing');
assert(read('src/11_snapline.lua').includes('SA.PreviewTarget and SA.PreviewTarget()'),
  'snapline must read the shared preview target');
assert(read('src/09_silent_aim.lua').includes('SA.PreviewTarget and SA.PreviewTarget()'),
  'Gun Silent Aim must read the same shared preview target');
assert(read('src/01_config.lua').includes('function SA.FrameClockTick()'),
  'one per-frame clock missing');
// Staff watch: 3 consecutive scans before a role is shown.
assert(read('src/04_entity_info.lua').includes('SA.STAFF_CONFIRM_SCANS = 3'),
  'staff watch must require three consecutive scans');
assert(read('src/04_entity_info.lua').includes(
  'function SA.GetStaffRoleConfirmed(plr, model)'),
  'confirmed staff role API missing');
assert(read('src/04_entity_info.lua').includes('function SA.StaffWatchState()'),
  'staff watch state API missing');
assert(read('src/13_esp_players_refresh.lua').includes(
  'SA.GetStaffRoleConfirmed'),
  'the ESP role tag must use the confirmed classifier');
// Draw pool reuse must reset styling so a recycled draw cannot go stale.
assert(read('src/02_drawing.lua').includes('local function poolReset(d, kind)'),
  'draw-pool styling reset missing');
assert(read('src/24_ui_visual.lua').includes('"snapLineThickness", 1, 10'),
  'customizable snapline size slider missing');

// Both unload paths must remove direct connections, live draws, pooled
// draws, world ESP instances and Hanami-owned GUIs -- not just library.guis.
assert(read('src/01_config.lua').includes('function SA.Connect(signal, fn)'),
  'tracked SA.Connect helper missing');
assert(read('src/01_config.lua').includes('function SA.DisconnectConnections()'),
  'direct connection disconnect sweep missing');
assert(read('src/01_config.lua').includes('function SA.ConnectionState()'),
  'connection state API missing');
assert(read('src/02_drawing.lua').includes('function SA.DrawRemove(d)'),
  'registry-aware draw removal missing');
assert(read('src/02_drawing.lua').includes('function SA.DrawState()'),
  'live draw state API missing');
assert(read('src/06_firing_and_guns.lua').includes('function SA.DrawDisposeAll()'),
  'complete draw disposal missing');
assert(read('src/06_firing_and_guns.lua').includes(
  'function SA.DisposeHanamiGuis()'),
  'Hanami GUI disposal missing');
assert(read('src/06_firing_and_guns.lua').includes('function SA.VisualState()'),
  'combined visual state API missing');
assert(read('src/10_fov_circle.lua').includes('function SA.FovDispose()'),
  'FOV circle disposal missing');
assert(read('src/11_snapline.lua').includes('function SA.SnaplineDispose()'),
  'snapline disposal missing');
assert(read('src/12_esp_players.lua').includes('SA.DrawRemove(d)'),
  'player ESP removals must forget registry keys');
assert(read('src/14_esp_npcs.lua').includes('HanamiNpcGui')
  && read('src/14_esp_npcs.lua').includes('HanamiNpcHighlight'),
  'named NPC orphan cleanup missing');
assert(read('src/21_ui_aiming.lua').includes('library.__saUnloadWrapperInstalled')
  && read('src/21_ui_aiming.lua').includes('"Unload Menu"'),
  'Atlanta built-in Unload Menu wrapper missing');
assert(read('src/21_ui_aiming.lua').includes('HanamiAtlantaBlur'),
  'Atlanta window blur capture missing');
assert(read('src/25_ui_misc.lua').includes('function SA.FullUnloadState()'),
  'unload report state API missing');
assert(read('src/25_ui_misc.lua').includes('function SA.FullUnload(reason)'),
  'trigger-aware full unload missing');
for (const needle of [
  'SA.DrawDisposeAll', 'SA.DisposeHanamiGuis', 'SA.DisconnectConnections',
  '_G.__saConnections, _G.__saDrawGui = nil, nil',
  '_G.__saUnknownHumanoids = nil',
]) {
  assert(read('src/25_ui_misc.lua').includes(needle),
    `FullUnload missing ${needle}`);
}
assert(read('tools/mocks.lua').includes('function library:button(opts)')
  && read('tools/mocks.lua').includes('name = "Unload Menu"'),
  'mock Atlanta built-in Unload Menu button missing');

// The two detectors must stay read-only: no attribute writes, no
// notification / console output, and no aim or gun exclusion path.
const detectorsSource = read('src/04_entity_info.lua');
assert(detectorsSource.includes('function SA.GetStaffRole(plr, model)'),
  'src/04_entity_info.lua: staff / admin classifier missing');
assert(detectorsSource.includes('function SA.StaffDetectState()'),
  'src/04_entity_info.lua: staff detector snapshot missing');
assert(detectorsSource.includes('function SA.UnknownHumanoidState()'),
  'src/04_entity_info.lua: unknown-humanoid snapshot missing');
assert(detectorsSource.includes(
  'SA.RegisterScanHandler("unknownHumanoids"'),
  'src/04_entity_info.lua: unknown-humanoid registry not on the shared walker');
for (const banned of [
  'SetAttribute', 'STAFF IN SERVER', '__fustSuiteNotify', 'LiveBait =',
  'targets.Other', 'S.baitSuspects', 'AdminMovedAt =',
  'GetDescendants', 'Heartbeat',
]) {
  assert(!detectorsSource.includes(banned),
    `src/04_entity_info.lua detector writes / notifies / brute-forces: ${banned}`);
}
const espUiSource = read('src/22_ui_esp.lua');
assert(espUiSource.includes('"Staff / Admin Detector"')
  && espUiSource.includes('"espStaffDetect"'),
  'ESP tab: staff / admin detector toggle missing');
const miscUiSource = read('src/25_ui_misc.lua');
assert(miscUiSource.includes('"Unknown Humanoid Detector"')
  && miscUiSource.includes('"hn_unknownHumanoidScan"'),
  'Misc tab: unknown-humanoid detector toggle missing');
assert(read('src/13_esp_players_refresh.lua').includes('SA.GetStaffRole(plr, char)'),
  'player ESP refresh does not read the staff role tag');
assert(read('src/18_esp_fx_draw.lua').includes('espC("adminTag")')
  && read('src/18_esp_fx_draw.lua').includes('espC("staffTag")'),
  'staff / admin tag colour path missing');

// Inline colour picks must survive native profile save / load / import.
for (const needle of [
  'function SA.EspColorSnapshot()', 'function SA.EspColorRestore',
  '__saEspColors', 'name .. ".colors"',
  'typeof(c) == \"Color3\" or type(c) == \"table\"',
]) {
  assert(allSource.includes(needle), `saved colour picker support missing ${needle}`);
}
const tests = read('tools/tests.lua');
for (const needle of [
  'saEspFovTransitionRegression', 'saNpcFovTransitionRegression',
  'saCrateFovTransitionRegression', 'saFovReferenceRegression',
  'saSnaplineSizeRegression', 'saSnaplineIndependentRegression',
  'saSnapTargetCleanupRegression', 'saColorProfileRegression',
  'WorldToViewportPoint = function',
  'FOV reference follows mouse X despite stale centre mode',
  'FOV enter triggers one-time overlay cleanup',
  'NPC FOV enter triggers one-time overlay cleanup',
  'crate FOV enter triggers one-time overlay cleanup',
  'custom snapline size state',
  'snapline draws with only its own toggle ON',
  'snapline uses thick 3px default',
  'Gun Silent Aim keeps ESP highlight target with snapline OFF',
  'Gun Silent Aim toggle changes ESP draw signature',
  'outside FOV with snapline ON clears stale highlight target',
  'saved profile carries ESP colours',
  'minimising the menu is not an unload',
  'minimised menu keeps ESP / FOV visuals',
  'nearest HUD visible while menu hidden',
  'Misc full-unload button exists',
  'Atlanta built-in Unload Menu exists',
  'Misc full-unload button trigger',
  'Atlanta built-in Unload Menu trigger',
  'all registered drawings removed',
  'no Hanami GUI remains',
  'no tracked connection remains',
  'FOV circle disposed',
  'unload report records zero live drawings',
  'import-only colour block restores pickers',
  'inside FOV: stale FOV-edge box replaced',
  'NPC inside FOV: stale FOV-edge box replaced',
  'leave FOV: name tag follows target out again',
]) {
  assert(tests.includes(needle),
    `tools/tests.lua: FOV enter/leave regression missing ${needle}`);
}

// Every custom colour ships white, has exactly one inline owner, and no
// separate ESP colour mini-tab / section survives.
const palette = config.slice(
  config.indexOf('local ESP_DEFAULT_COLORS = {'),
  config.indexOf('local ESP_COLORS = _G.__saEspColors')
);
const colorArgs = Array.from(palette.matchAll(/Color3\.fromRGB\(([^)]*)\)/g),
  (m) => m[1].trim());
assert(colorArgs.length === 52,
  `expected 52 ESP palette colours, found ${colorArgs.length}`);
assert(colorArgs.every((rgb) => rgb === '255, 255, 255'),
  'every customizable colour must default white');
const bindings = config.slice(
  config.indexOf('SA.INLINE_COLOR_BINDINGS = {'),
  config.indexOf('SA.INLINE_COLOR_OWNER = {}')
);
const boundColors = Array.from(
  bindings.matchAll(/\{\s*"[^"]+"\s*,\s*"([A-Za-z0-9_]+)"\s*\}/g),
  (m) => m[1]);
assert(boundColors.length === 52 && new Set(boundColors).size === 52,
  'expected 52 unique inline colourpicker bindings');
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
  'src/04_entity_info.lua': ['equipped', 'holstered', 'weapon status',
    'tool child fallback', 'shared metres', 'staff', 'admin',
    'unknown humanoid'],
  'src/12_esp_players.lua': ['player esp', 'ghost billboardgui', 'purge',
    're-execution', 'registry-aware removal'],
  'src/01_config.lua': ['themes', 'fonts', 'white', 'startup off',
    'esp-only best startup', 'fov startup', 'snapline size', 'mouse reference',
    'inline colours', 'profiles', 'self-check', 'perf', 'clean',
    'npc manipulation', 'trigger', 'wall check', 'warning', 'force head',
    'crate fov', 'npc hitbox', 'hitbox', 'esp data refresh', 'fust bow',
    'direct connection registry', 'unload disconnect'],
  'src/02_drawing.lua': ['capability', 'draw pool', 'sync batching',
    'per-property', 'live draw registry', 'draw remove'],
  'src/06_firing_and_guns.lua': ['complete unload sweep',
    'hanami gui sweep'],
  'src/03_entity_scan.lua': ['npc registry', 'visibility', 'raw list',
    'profile card', 'avatar', 'headshot', 'draggable', 'weapon state',
    'reset hud position'],
  'src/02_shared.lua': ['fov', 'mouse reference', 'pinned', 'npc classifier', 'force head',
    'trigger bone', 'vis', 'wall check'],
  'src/05_manipulation.lua': ['popup', 'probe', 'npc', 'fire-assist'],
  'src/08_prediction.lua': ['gun diff', 'override'],
  'src/09_silent_aim.lua': ['shared aim target refresh', 'silent aim',
    'guns only', 'trigger', 'auto fire', 'vis', 'wall check',
    'tool-first', 'mouse1click', 'dedicated fust bow part'],
  'src/09_z_fust_bow.lua': ['fust bow', 'ballistic', 'hookfunction',
    'shoot.fireserver', 'peek-origin', 'fov', 'bow specs', 'state'],
  'src/10_fov_circle.lua': ['solid', 'visible', '3px', 'reference point',
    'fov dispose'],
  'src/11_snapline.lua': ['independent', 'fov reference',
    'thick 3px', 'snapline size', 'snapline dispose'],
  'src/13_esp_players_refresh.lua': ['per-player', 'cached player rig', 'vis',
    'legacy billboardgui off', 'shared projection cache', 'geometry cache'],
  'src/14_esp_npcs.lua': ['npc esp', 'cached rig',
    'named orphan cleanup'],
  'src/15_esp_npcs_refresh.lua': ['npc esp', 'cached rig', 'vis',
    'shared projection cache', 'geometry cache'],
  'src/16_esp_crates_registry.lua': ['crate registry', 'raw list'],
  'src/18_esp_fx_colours.lua': ['palette', 'fov snapshot', 'raw projection',
    'live visibility', 'duplicate overlay', 'legacy line', 'usage marks',
    'geometry cache', 'rainbow clock'],
  'src/18_esp_fx_draw.lua': ['clean', 'outline', 'crate fov', 'off-screen',
    'fov enter/leave', 'transition cleanup', 'duplicate overlay',
    'legacy line', 'hoisted helpers', 'usage marks', 'direct segments'],
  'src/18_esp_fx_frame.lua': ['per-frame', 'crate fov', 'team map',
    'fov enter/leave', 'fov transition', 'gun silent aim toggle cleanup',
    'cached rig', 'fps', 'geometry cache', 'geometry slicing',
    'camera signature', 'priority slicing', 'hidden pass',
    'one fewer pcall'],
  'src/19_render_loop.lua': ['adaptive', 'fps', 'data refresh', 'raw list',
    'frame budget', 'geometry budget', 'geometry slicing',
    'rolling fps', 'performance mode'],
  'src/21_ui_aiming.lua': ['preset', 'priority', 'bone', 'npc manipulation',
    'trigger', 'auto fire', 'wall check', 'force head',
    'silent-aim independent', 'npc hitbox', 'hitbox', 'fust bow',
    'inline colourpicker', 'atlanta source sanitizer', 'built-in font fallback',
    'error-page markers', 'unload menu wrapper', 'blur capture'],
  'src/20_hitbox_expander.lua': ['hitbox', 'players + npcs', 'r6/r15',
    'npc', 'hrp fallback', 'self-healing', 'restore'],
  'src/22_esp_preview.lua': ['real-model', 'side-by-side', 'clean'],
  'src/22_ui_esp.lua': ['declutter', 'live count', 'clean', 'crate fov',
    'esp-only best startup', 'staff / admin detector',
    'inline', 'no colour mini-tabs'],
  'src/24_ui_visual.lua': ['fov reference', 'independent', 'thick snapline',
    'snapline size', 'theme', 'font', 'profile card', 'avatar', 'headshot',
    'draggable', 'weapon state', 'reset hud position',
    'top-n', 'performance', 'keybind', 'popup',
    'npc', 'warning', 'fire assist', 'esp data', 'frame budget',
    'utilities'],
  'src/25_ui_misc.lua': ['theme', 'font', 'profile', 'colour profiles',
    'detectors', 'unknown-humanoid', 'name line',
    'self-check', 'full unload', 'drag position', 'both unload paths',
    'full unload state', 'draw sweep', 'connection sweep',
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
  'Read-only staff / admin and unknown-humanoid detectors',
  'Staff / Admin Detector',
  'SA.GetStaffRole()',
  'SA.StaffDetectState()',
  'Unknown Humanoid Detector',
  'SA.UnknownHumanoidState()',
  'SA.UnknownHumanoidListRaw()',
  'both unload paths',
  'plain menu hide',
  'Unload Menu',
  'SA.FullUnloadState()',
  'SA.VisualState()',
  'SA.DrawDisposeAll()',
  'SA.DisconnectConnections()',
  'SA.DisposeHanamiGuis()',
  'draw registry',
  'connection sweep',
  'unload regressions',
  'Atlanta built-in Unload Menu',
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
  '6,990 assertions',
  'all 77 new CFG keys',
  '## Themes, fonts, inline colours and OFF defaults',
  '9 additional themes',
  '10 popular script-community font picks',
  '60-50 FPS',
  'Visual → Theme',
  'all non-ESP feature toggles OFF',
  'default white',
  'no second RenderStepped',
  'event-driven',
  'SA.ApplyTheme()',
  'SA.ApplyFont()',
  'SA.ThemeState()',
  'SA.FontState()',
  'SA.BEST_ESP_STARTUP',
  'SA.BestEspState()',
  'FOV enter/leave',
  'Player, NPC and crate FOV enter/leave',
  'FOV reference point',
  'customizable snapline size',
  'independent thick snapline',
  '3px defaults',
  'Gun Silent Aim toggle cleanup',
  'shared aim target',
  'just its own toggle ON',
  'saved colour pickers',
  'One on-player label on FOV entry',
  'one on-player label',
  'Draggable nearest-player profile card',
  'Roblox headshot',
  'Equipped / Holstered / Unknown',
  'Reset HUD Position',
  'SA.GetWeaponStatus()',
  'SA.EspHideDuplicateOverlays()',
  'SA.EspDuplicateCleanupState()',
  'SA.NearestWindowResetPosition()',
  'FOV duplicate-overlay regressions',
  'SA.PreviewTarget()',
  'SA.PreviewTargetReset()',
  'one candidate scan per frame',
  'SA.EspStyleSweep()',
  'never part of the draw signature',
  'ghost / stale drawing cleanup',
  'SA.EspGhostCleanup',
  'streamed out',
  '3 consecutive scans',
  'SA.StaffWatchState()',
  'SA.GetStaffRoleConfirmed()',
  'NPC refresh throttle',
  'SA.FovMode()',
  'SA.FovDegrees()',
  'SA.FovPointInside',
  'SA.FovSegmentInside',
  'FOV measurement modes',
  'half-angle',
  'nearest point on the projected',
  'fovHitbox',
  'head-to-root segment',
  'FOV Drawing Style',
  'hideFxGroup',
  'NPC ESP is not FOV-aware',
  'Snapline is player-only',
  'SA.EspKey6',
  'ringDraws',
  'MOCK_BAD_PROP',
  'saPlayerEspWorksRegression',
  'registration is unconditional',
  'nearest-player profile regressions',
  'SA.FOV_STARTUP',
  'SA.EspFovSnapshot()',
  'SA.EspFovState()',
  'SA.SnaplineState()',
  'SA.EspColorSnapshot()',
  'SA.EspColorRestore()',
  'SA.EspColorCount()',
  'SA.EspColorEncode()',
  'SA.EspColorDecode()',
  'ESP-only best preset',
  'uiTheme',
  'uiFont',
  '48-part list',
  '### Armor Console',
  'SA.ArmorAnalyze',
  'SA.ArmorTargets()',
  'SA.ArmorConsoleState()',
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
