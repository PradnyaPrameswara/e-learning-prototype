import { mkdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import process from 'node:process';

const argumentsByCommand = {
  types: ['types'],
  build: ['deploy', '--dry-run', '--outdir', 'dist'],
};
const commandName = process.argv[2];
const argumentsForCommand = argumentsByCommand[commandName];

if (!argumentsForCommand) {
  console.error('Usage: node scripts/run-wrangler.mjs <types|build>');
  process.exit(2);
}

const logDirectory = path.resolve('.wrangler', 'logs');
mkdirSync(logDirectory, { recursive: true });

const command = process.platform === 'win32' ? 'wrangler.cmd' : 'wrangler';
const result = spawnSync(command, argumentsForCommand, {
  cwd: process.cwd(),
  stdio: 'inherit',
  shell: process.platform === 'win32',
  env: { ...process.env, WRANGLER_LOG_PATH: logDirectory },
});

if (result.error) {
  console.error(`Could not start Wrangler: ${result.error.message}`);
  process.exit(1);
}
process.exit(result.status ?? 1);
