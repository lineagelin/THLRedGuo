const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');

const script = fs.readFileSync(path.join(__dirname, '../assets/sources/hongguo.js'), 'utf8');

test('standard source loads without BigInt and keeps the standard signer available', () => {
  // Android QuickJS without CONFIG_BIGNUM cannot even parse BigInt literals.
  assert.doesNotMatch(script, /\b\d+n\b/);
  const context = vm.createContext({ BigInt: undefined });
  vm.runInContext(script, context);
  assert.equal(vm.runInContext('spider.meta.id', context), 'hongguo');
  assert.equal(vm.runInContext('typeof spider.category', context), 'function');
  assert.equal(vm.runInContext('__hongguoLocalSign(null)', context), null);
  vm.runInContext('__hongguoUseLocalApkProfile(null)', context);
  assert.throws(() => vm.runInContext('__hongguoUseLocalApkProfile({})', context),
    error => error.code === 'LOCAL_PROFILE_UNSUPPORTED');
});

test('BigInt-capable engines preserve exact 64-bit profile arithmetic', () => {
  const context = vm.createContext({});
  const instrumented = script.replace('let activeLocalProfile = null;',
    'globalThis.profileMath = { bigRead, ror, profileVarint }; let activeLocalProfile = null;');
  vm.runInContext(instrumented, context);
  assert.equal(vm.runInContext('profileMath.bigRead(Array(8).fill(255), 0).toString()', context),
    '18446744073709551615');
  assert.equal(vm.runInContext('profileMath.ror(BigInt(1), 1).toString()', context),
    '9223372036854775808');
  assert.equal(vm.runInContext('Array.from(profileMath.profileVarint(BigInt("9007199254740993"))).join(",")', context),
    '129,128,128,128,128,128,128,16');
  assert.equal(vm.runInContext('__hongguoLocalSign(null)', context), null);
});
