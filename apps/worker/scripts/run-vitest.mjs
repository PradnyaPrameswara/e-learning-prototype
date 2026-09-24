import { spawnSync } from 'node:child_process';
import process from 'node:process';

const command = process.platform === 'win32' ? 'vitest.cmd' : 'vitest';
const result = spawnSync(command, ['run'], {
  cwd: process.cwd(),
  stdio: 'inherit',
  shell: process.platform === 'win32',
  env: { ...process.env, WRANGLER_WRITE_LOGS: 'false' },
});

if (result.error) {
  console.error(`Could not start Vitest: ${result.error.message}`);
  process.exit(1);
}
process.exit(result.status ?? 1);
