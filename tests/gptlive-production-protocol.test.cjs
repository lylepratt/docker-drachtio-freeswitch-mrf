const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { mkdtempSync, readFileSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { resolve, join } = require('node:path');
const { test, after } = require('node:test');

const root = resolve(__dirname, '..');
const files = join(root, 'deployment-tools/packer/files');
const staging = mkdtempSync(join(tmpdir(), 'gptlive-protocol-test-'));
after(() => rmSync(staging, { recursive: true, force: true }));
execFileSync('tar', ['--warning=no-unknown-keyword', '-xzf', join(files, 'freeswitch-modules-2.5.24.tar.gz'), '-C', staging]);
const source = join(staging, 'freeswitch-modules-2.5.24/modules/mod_gptlive_s2s');
for (const patch of ['mod_gptlive_s2s.c-abi.patch', 'mod_gptlive_s2s.production.patch']) {
  execFileSync('patch', ['--batch', '--fuzz=0', '-d', source, '-p1'], { input: readFileSync(join(files, patch)) });
}
const pipe = readFileSync(join(source, 'audio_pipe.cpp'), 'utf8');
const glue = readFileSync(join(source, 'gptlive_glue.cpp'), 'utf8');

test('packaged module sends and consumes production audio envelopes', () => {
  const install = readFileSync(join(root, 'deployment-tools/packer/scripts/install_freeswitch.sh'), 'utf8');
  assert.ok(install.includes('< /tmp/mod_gptlive_s2s.production.patch'));
  assert.ok(pipe.includes('session.input_audio.append'));
  assert.match(glue, /strcmp\(type, "session\.output_audio\.delta"\)/);
  assert.match(glue, /cJSON_GetObjectCstr\(json, "delta"\)/);
});

test('production handshake keeps authorization without alpha header or browser origin', () => {
  assert.ok(pipe.includes('"Authorization:"'));
  assert.ok(!pipe.includes('GPTLIVE_ALPHA_HEADER'));
  assert.doesNotMatch(pipe, /^\s*i\.origin\s*=/m);
});

test('playback lifecycle remains local, never inferred from transcript projections', () => {
  assert.ok(glue.includes('output_audio.playback_started'));
  assert.ok(glue.includes('output_audio.playback_stopped'));
  assert.ok(glue.includes('"session.started"'));
  assert.ok(!glue.includes('handleTurnCreated'));
});

test('continuous output silence does not hold speech activity open', () => {
  const binary = join(staging, 'output-activity-test');
  execFileSync('c++', ['-std=c++17', '-Wall', '-Wextra', '-Werror', '-I', source,
    join(__dirname, 'gptlive-output-activity.cpp'), '-o', binary]);
  execFileSync(binary);
});
