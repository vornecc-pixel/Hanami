/* Hanami / tools/run.js — committed Fengari mock-runtime runner.
 * Loads the mock environment once, executes the generated bundle three
 * times in the SAME Lua state, and runs tools/tests.lua after each pass:
 *   1. fresh execution + auto-load profile preparation
 *   2. loader re-execution + startup auto-load assertions
 *   3. re-execution after SA.FullUnload() + final unload
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const root = path.resolve(__dirname, '..');
const distPath = path.join(root, 'dist', 'Hanami.lua');
if (!fs.existsSync(distPath)) {
  throw new Error('dist/Hanami.lua is missing — run `npm run build` first');
}

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

function chunkName(file) {
  return to_luastring('@' + path.relative(root, file));
}

function loadFile(file) {
  lua.lua_settop(L, 0);
  const source = Buffer.from(fs.readFileSync(file, 'utf8'), 'utf8');
  const loadStatus = lauxlib.luaL_loadbuffer(
    L, source, source.length, chunkName(file)
  );
  if (loadStatus !== lua.LUA_OK) {
    const err = lua.lua_tojsstring(L, -1);
    throw new Error(`${path.relative(root, file)}: Lua load error: ${err}`);
  }
  const callStatus = lua.lua_pcall(L, 0, 0, 0);
  if (callStatus !== lua.LUA_OK) {
    const err = lua.lua_tojsstring(L, -1);
    throw new Error(`${path.relative(root, file)}: Lua runtime error: ${err}`);
  }
  lua.lua_settop(L, 0);
}

function setGlobalNumber(name, value) {
  lua.lua_settop(L, 0);
  lua.lua_pushinteger(L, value);
  lua.lua_setglobal(L, to_luastring(name));
}

function getGlobalNumber(name) {
  lua.lua_settop(L, 0);
  lua.lua_getglobal(L, to_luastring(name));
  const value = lua.lua_tointeger(L, -1) || 0;
  lua.lua_pop(L, 1);
  return value;
}

setGlobalNumber('TEST_ASSERTIONS', 0);
loadFile(path.join(root, 'tools', 'mocks.lua'));
loadFile(distPath);

let previousAssertions = 0;
for (let run = 1; run <= 3; run += 1) {
  if (run > 1) loadFile(distPath); // deliberate re-execute in the same state
  setGlobalNumber('TEST_RUN', run);
  setGlobalNumber('TEST_RUN_OK', 0);
  loadFile(path.join(root, 'tools', 'tests.lua'));

  const assertions = getGlobalNumber('TEST_ASSERTIONS');
  const runOk = getGlobalNumber('TEST_RUN_OK');
  if (runOk !== 1 || assertions <= previousAssertions) {
    throw new Error(`runtime run ${run} did not complete its assertions`);
  }
  console.log(`[runtime] re-execution ${run}/3 verified (${assertions} cumulative assertions)`);
  previousAssertions = assertions;
}

console.log('[runtime] startup, auto-load, re-execute and full-unload paths OK');
