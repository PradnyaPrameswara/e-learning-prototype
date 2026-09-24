import { existsSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const migrationsDirectory = path.join(root, 'supabase', 'migrations');
const hasMigrations =
  existsSync(migrationsDirectory) &&
  readdirSync(migrationsDirectory).some((file) => file.endsWith('.sql'));

if (!hasMigrations) {
  console.error(
    'No schema migrations exist yet. Add a reviewed migration before generating database types.',
  );
  process.exit(1);
}

const command = process.platform === 'win32' ? 'supabase.cmd' : 'supabase';
const result = spawnSync(
  command,
  ['gen', 'types', 'typescript', '--local', '--schema', 'public'],
  { cwd: root, encoding: 'utf8', shell: process.platform === 'win32' },
);

if (result.stdout) process.stdout.write(result.stdout);
if (result.stderr) process.stderr.write(result.stderr);
if (result.error) {
  console.error(`Could not run the Supabase CLI: ${result.error.message}`);
  process.exit(1);
}
if (result.status !== 0 || !result.stdout?.trim()) {
  console.error(
    'Supabase type generation failed or returned empty output; no file was written.',
  );
  process.exit(result.status || 1);
}

const outputPath = path.join(
  root,
  'packages',
  'database',
  'src',
  'database.types.ts',
);
mkdirSync(path.dirname(outputPath), { recursive: true });
writeFileSync(outputPath, `${result.stdout.trimEnd()}\n`, 'utf8');
console.log(
  `Generated ${path.relative(root, outputPath)} from local Supabase schema.`,
);
