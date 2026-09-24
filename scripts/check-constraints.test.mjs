import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, it } from 'node:test';
import { collectViolations } from './check-constraints.mjs';

const temporaryRoots = new Set();

function fixture() {
  const root = mkdtempSync(path.join(os.tmpdir(), 'lms-constraints-'));
  temporaryRoots.add(root);
  for (const directory of [
    'apps/student/src',
    'apps/teacher/src',
    'packages/core/src',
  ]) {
    mkdirSync(path.join(root, directory), { recursive: true });
  }
  for (const [directory, name] of [
    ['apps/student', '@lms/student'],
    ['apps/teacher', '@lms/teacher'],
    ['packages/core', '@lms/core'],
  ]) {
    writeJson(path.join(root, directory, 'package.json'), {
      name,
      private: true,
    });
  }
  return root;
}

function writeJson(filePath, value) {
  writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function writeSource(root, relativePath, content) {
  writeFileSync(path.join(root, relativePath), content);
}

afterEach(() => {
  for (const root of temporaryRoots)
    rmSync(root, { recursive: true, force: true });
  temporaryRoots.clear();
});

describe('architecture constraint checker', () => {
  it('accepts a clean dependency graph and source tree', async () => {
    const root = fixture();
    writeSource(
      root,
      'apps/student/src/index.ts',
      'export const ready = true;\n',
    );
    writeSource(
      root,
      'packages/core/src/index.ts',
      'export const value = 1;\n',
    );

    assert.deepEqual(await collectViolations(root), []);
  });

  it('detects direct React useEffect imports, aliases, and namespace calls', async () => {
    const root = fixture();
    writeSource(
      root,
      'apps/student/src/index.tsx',
      'import React, { useEffect as runEffect } from "react";\nrunEffect(() => {});\nReact.useEffect(() => {});\n',
    );

    const violations = (await collectViolations(root)).join('\n');
    assert.match(violations, /direct React useEffect/);
    assert.equal((violations.match(/direct React useEffect/g) ?? []).length, 2);
  });

  it('detects prohibited libraries in manifests and source imports', async () => {
    const root = fixture();
    writeJson(path.join(root, 'apps/student/package.json'), {
      name: '@lms/student',
      dependencies: { '@radix-ui/react-dialog': '1.0.0', formik: '2.0.0' },
    });
    writeSource(
      root,
      'apps/teacher/src/index.ts',
      'import { useForm } from "react-hook-form";\n',
    );

    const violations = (await collectViolations(root)).join('\n');
    assert.match(violations, /@radix-ui\/react-dialog/);
    assert.match(violations, /formik/);
    assert.match(violations, /react-hook-form/);
  });

  it('parses Astro frontmatter and script blocks for forbidden imports and hook calls', async () => {
    const root = fixture();
    writeSource(
      root,
      'apps/student/src/index.astro',
      '---\nimport { useEffect as runEffect } from "react";\nrunEffect(() => {});\n---\n<script>import "@radix-ui/react-dialog";</script>\n',
    );

    const violations = (await collectViolations(root)).join('\n');
    assert.match(violations, /direct React useEffect/);
    assert.match(violations, /@radix-ui\/react-dialog/);
  });

  it('rejects dynamic React loading and namespace destructuring that could bypass hook checks', async () => {
    const root = fixture();
    writeSource(
      root,
      'apps/student/src/index.ts',
      'const React = await import("react");\nconst { useEffect } = React;\n',
    );

    const violations = (await collectViolations(root)).join('\n');
    assert.match(violations, /dynamic React imports are prohibited/);
    assert.match(violations, /direct React useEffect access is prohibited/);
  });

  it('detects app-to-app and package-to-app source imports', async () => {
    const root = fixture();
    writeSource(
      root,
      'apps/student/src/index.ts',
      'import "../../teacher/src/index";\n',
    );
    writeSource(
      root,
      'packages/core/src/index.ts',
      'import "../../../apps/student/src/index";\n',
    );
    writeSource(
      root,
      'apps/teacher/src/index.ts',
      'export const ready = true;\n',
    );

    const violations = (await collectViolations(root)).join('\n');
    assert.match(violations, /applications may not import another app/);
    assert.match(
      violations,
      /shared packages may not import application source/,
    );
  });

  it('detects package dependency cycles', async () => {
    const root = fixture();
    writeJson(path.join(root, 'packages/core/package.json'), {
      name: '@lms/core',
      dependencies: { '@lms/student': 'workspace:*' },
    });
    writeJson(path.join(root, 'apps/student/package.json'), {
      name: '@lms/student',
      dependencies: { '@lms/core': 'workspace:*' },
    });

    assert.match(
      (await collectViolations(root)).join('\n'),
      /workspace dependency cycle/,
    );
  });
});
