const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');

const script = fs.readFileSync(path.join(__dirname, '../assets/sources/hongguo.js'), 'utf8');

test('source template loads without BigInt and requires a packaged signing configuration', () => {
  // Android QuickJS without CONFIG_BIGNUM cannot even parse BigInt literals.
  assert.doesNotMatch(script, /\b\d+n\b/);
  const context = vm.createContext({ BigInt: undefined });
  vm.runInContext(script, context);
  assert.equal(vm.runInContext('spider.meta.id', context), 'hongguo');
  assert.equal(vm.runInContext('typeof spider.category', context), 'function');
  assert.throws(() => vm.runInContext('__hongguoLocalSign(null)', context),
    error => error.code === 'SOURCE_CONFIGURATION_MISSING');
  vm.runInContext('__hongguoUseLocalApkProfile(null)', context);
  vm.runInContext('__hongguoUseLocalApkProfile({})', context);
  assert.equal(vm.runInContext('__hongguoHasBuiltInSigning', context), true);
});

test('signing profile preserves exact 64-bit arithmetic without BigInt', () => {
  const context = vm.createContext({ BigInt: undefined });
  const instrumented = script.replace('const builtInConfiguration=',
    'globalThis.profileMath = { bigRead, ror, word64, profileVarint }; const builtInConfiguration=');
  vm.runInContext(instrumented, context);
  assert.equal(vm.runInContext('profileMath.bigRead(Array(8).fill(255), 0).map(n=>n.toString(16).padStart(8,"0")).join("")', context),
    'ffffffffffffffff');
  assert.equal(vm.runInContext('profileMath.ror(profileMath.word64(1), 1).map(n=>n.toString(16).padStart(8,"0")).join("")', context),
    '8000000000000000');
  assert.equal(vm.runInContext('Array.from(profileMath.profileVarint("9007199254740993")).join(",")', context),
    '129,128,128,128,128,128,128,16');
  assert.throws(() => vm.runInContext('__hongguoLocalSign(null)', context),
    error => error.code === 'SOURCE_CONFIGURATION_MISSING');
});

test('packaged source signs playback requests on engines without BigInt', () => {
  const prepared = script
    .replace('__THL_HONGGUO_SIGNING_ID_BASE64__', Buffer.from('synthetic').toString('base64'))
    .replace('__THL_HONGGUO_SIGNING_MATERIAL_BASE64__', Buffer.alloc(32, 1).toString('base64'));
  const context = vm.createContext({ BigInt: undefined });
  vm.runInContext(prepared, context);
  const headers = vm.runInContext(`__hongguoLocalSign(
    'https://reading.snssdk.com/novel/player/multi_video_model/v1/?aid=8662',
    null, 1700000000, {device_id:'123456789012345'})`, context);
  for (const name of ['x-gorgon', 'x-khronos', 'x-ladon', 'x-argus', 'x-helios', 'x-medusa']) {
    assert.equal(typeof headers[name], 'string');
    assert.ok(headers[name].length > 0);
  }
  assert.equal(headers['x-khronos'], '1700000000');
});
