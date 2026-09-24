import { defineConfig } from 'oxlint';

export default defineConfig({
  ignorePatterns: [
    '.agent/**',
    '.agents/**',
    '.claude/**',
    '.codex/**',
    '.continue/**',
    '.cursor/**',
    '.gemini/**',
    '.opencode/**',
    '.pi/**',
    '.roo/**',
    '.windsurf/**',
    '.tools/**',
    'tools/oxlint/anti-slop/**',
    '**/node_modules/**',
    '**/dist/**',
    '**/.astro/**',
    '**/.wrangler/**',
    '**/.turbo/**',
    '**/coverage/**',
    '**/worker-configuration.d.ts',
    '**/database.types.ts',
  ],
  jsPlugins: [
    {
      name: 'anti-slop',
      specifier: './tools/oxlint/anti-slop/index.ts',
    },
  ],
  rules: {
    'oxc/no-accumulating-spread': 'error',
    'anti-slop/no-array-filter-map': 'error',
    'anti-slop/no-reduce-accumulator-copy': 'error',
    'anti-slop/no-chained-type-assertions': 'error',
    'anti-slop/no-conditional-empty-object-spread': 'error',
    'anti-slop/no-known-value-widening': 'error',
    'anti-slop/no-module-mocking': 'error',
    'anti-slop/no-object-parameters': 'error',
    'anti-slop/no-reflect-apply': 'error',
    'anti-slop/no-reflect-get': 'error',
    'anti-slop/no-runtime-typeof': 'error',
    'anti-slop/no-shape-in-symbol-names': 'error',
    // The Worker JSON response helper intentionally accepts `unknown` because
    // it serializes without inspecting input. The rule overreaches this safe use.
    'anti-slop/no-unknown-parameters': 'off',
    'anti-slop/no-unknown-returns': 'error',
    'anti-slop/no-unknown-type-aliases': 'error',
    'anti-slop/no-unsafe-dictionary-type': 'error',
    'anti-slop/no-widen-then-assert': 'error',
    // Prettier is the repository formatter; this rule would add blank lines
    // throughout existing valid source and create unrelated formatting churn.
    'anti-slop/require-readable-spacing': 'off',
    'anti-slop/require-safety-comment-for-type-assertion': 'error',
  },
});
