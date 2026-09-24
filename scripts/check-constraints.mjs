import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';
import { parse as parseAstro } from '@astrojs/compiler';
import ts from 'typescript';

const sourceExtensions = new Set([
  '.ts',
  '.tsx',
  '.js',
  '.jsx',
  '.mjs',
  '.cjs',
  '.astro',
]);
const excludedDirectories = new Set([
  'node_modules',
  'dist',
  '.astro',
  '.wrangler',
  '.turbo',
  'coverage',
]);
const forbiddenPackageNames = new Set(['react-hook-form', 'formik']);

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, 'utf8'));
}

function listDirectories(directory) {
  if (!statSync(directory, { throwIfNoEntry: false })?.isDirectory()) return [];

  return readdirSync(directory, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => path.join(directory, entry.name));
}

function isWithin(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return (
    relative === '' ||
    (!relative.startsWith(`..${path.sep}`) &&
      relative !== '..' &&
      !path.isAbsolute(relative))
  );
}

function packageDependencies(manifest) {
  return Object.assign(
    {},
    manifest.dependencies,
    manifest.devDependencies,
    manifest.peerDependencies,
    manifest.optionalDependencies,
  );
}

function findSourceFiles(directory) {
  const files = [];
  if (!statSync(directory, { throwIfNoEntry: false })?.isDirectory())
    return files;

  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!excludedDirectories.has(entry.name)) {
        files.push(...findSourceFiles(path.join(directory, entry.name)));
      }
      continue;
    }

    const filePath = path.join(directory, entry.name);
    if (
      entry.isFile() &&
      sourceExtensions.has(path.extname(entry.name)) &&
      !['worker-configuration.d.ts', 'database.types.ts'].includes(entry.name)
    )
      files.push(filePath);
  }

  return files;
}

function isForbiddenModule(specifier) {
  return (
    specifier.startsWith('@radix-ui/') ||
    forbiddenPackageNames.has(specifier) ||
    [...forbiddenPackageNames].some((name) => specifier.startsWith(`${name}/`))
  );
}

async function getSourceChunks(filePath) {
  const text = readFileSync(filePath, 'utf8');
  if (!filePath.endsWith('.astro')) return [text];

  const { ast } = await parseAstro(text, { position: false });
  const chunks = [];
  function visit(node) {
    if (node.type === 'frontmatter') chunks.push(node.value);
    if (node.type === 'element' && node.name.toLowerCase() === 'script') {
      for (const child of node.children) {
        if (child.type === 'text') chunks.push(child.value);
      }
      return;
    }
    if ('children' in node) node.children.forEach(visit);
  }
  visit(ast);
  return chunks;
}

async function inspectSource(
  filePath,
  owner,
  appPackages,
  violations,
  rootPath,
) {
  const reactNamespaces = new Set();

  function report(message) {
    violations.push(`${path.relative(rootPath, filePath)}: ${message}`);
  }

  function checkModule(specifier) {
    if (isForbiddenModule(specifier))
      report(`prohibited dependency/import "${specifier}"`);

    const importedApp = [...appPackages.entries()].find(
      ([name]) => specifier === name || specifier.startsWith(`${name}/`),
    );
    if (importedApp && importedApp[0] !== owner.name) {
      report(`workspace code may not import another app (${importedApp[0]})`);
    }

    if (specifier.startsWith('.')) {
      const target = path.resolve(path.dirname(filePath), specifier);
      const importedAppPath = [...appPackages.entries()].find(
        ([name, appPath]) => name !== owner.name && isWithin(appPath, target),
      );
      if (importedAppPath && owner.kind === 'package') {
        report('shared packages may not import application source');
      } else if (importedAppPath && owner.kind === 'app') {
        report(
          `applications may not import another app's source (${importedAppPath[0]})`,
        );
      }
    }

    if (specifier === 'react') return;
  }

  function moduleSpecifier(node) {
    return ts.isStringLiteral(node) ? node.text : undefined;
  }

  function registerReactImport(importClause) {
    if (!importClause) return;
    if (importClause.name) reactNamespaces.add(importClause.name.text);

    const bindings = importClause.namedBindings;
    if (bindings && ts.isNamespaceImport(bindings))
      reactNamespaces.add(bindings.name.text);
    if (bindings && ts.isNamedImports(bindings)) {
      for (const element of bindings.elements) {
        const imported = element.propertyName?.text ?? element.name.text;
        if (imported === 'default') reactNamespaces.add(element.name.text);
        if (imported === 'useEffect') {
          report(
            'direct React useEffect imports are prohibited by the frontend architecture contract',
          );
        }
      }
    }
  }

  function checkRequireBinding(declaration, source) {
    if (
      !declaration.initializer ||
      !ts.isCallExpression(declaration.initializer)
    )
      return;
    const call = declaration.initializer;
    if (!ts.isIdentifier(call.expression) || call.expression.text !== 'require')
      return;
    const specifier = call.arguments[0] && moduleSpecifier(call.arguments[0]);
    if (!specifier) return;
    checkModule(specifier);
    if (specifier !== 'react') return;

    if (ts.isIdentifier(declaration.name))
      reactNamespaces.add(declaration.name.text);
    if (ts.isObjectBindingPattern(declaration.name)) {
      for (const element of declaration.name.elements) {
        const imported =
          element.propertyName?.getText(source).replaceAll(/["']/g, '') ??
          element.name.getText(source);
        if (imported === 'useEffect') {
          report(
            'direct React useEffect imports are prohibited by the frontend architecture contract',
          );
        }
      }
    }
  }

  function checkReactDestructuring(declaration, source) {
    if (
      !declaration.initializer ||
      !ts.isIdentifier(declaration.initializer) ||
      !reactNamespaces.has(declaration.initializer.text) ||
      !ts.isObjectBindingPattern(declaration.name)
    ) {
      return;
    }

    for (const element of declaration.name.elements) {
      const imported =
        element.propertyName?.getText(source).replaceAll(/["']/g, '') ??
        element.name.getText(source);
      if (imported === 'useEffect') {
        report(
          'direct React useEffect access is prohibited by the frontend architecture contract',
        );
      }
    }
  }

  function registerDynamicReactNamespace(declaration) {
    const initializer = declaration.initializer;
    const expression =
      initializer && ts.isAwaitExpression(initializer)
        ? initializer.expression
        : initializer;
    if (
      ts.isIdentifier(declaration.name) &&
      expression &&
      ts.isCallExpression(expression) &&
      expression.expression.kind === ts.SyntaxKind.ImportKeyword &&
      expression.arguments[0] &&
      moduleSpecifier(expression.arguments[0]) === 'react'
    ) {
      reactNamespaces.add(declaration.name.text);
    }
  }

  function visit(node, source) {
    if (ts.isImportDeclaration(node) || ts.isExportDeclaration(node)) {
      const specifier =
        node.moduleSpecifier && moduleSpecifier(node.moduleSpecifier);
      if (specifier) {
        checkModule(specifier);
        if (ts.isImportDeclaration(node) && specifier === 'react')
          registerReactImport(node.importClause);
      }
    }

    if (
      ts.isImportEqualsDeclaration(node) &&
      ts.isExternalModuleReference(node.moduleReference)
    ) {
      const specifier =
        node.moduleReference.expression &&
        moduleSpecifier(node.moduleReference.expression);
      if (specifier) {
        checkModule(specifier);
        if (specifier === 'react') reactNamespaces.add(node.name.text);
      }
    }

    if (ts.isImportTypeNode(node) && ts.isLiteralTypeNode(node.argument)) {
      const specifier = moduleSpecifier(node.argument.literal);
      if (specifier) checkModule(specifier);
    }

    if (ts.isVariableDeclaration(node)) {
      checkRequireBinding(node, source);
      registerDynamicReactNamespace(node);
      checkReactDestructuring(node, source);
    }

    if (ts.isPropertyAccessExpression(node)) {
      const isReactNamespace =
        (ts.isIdentifier(node.expression) &&
          reactNamespaces.has(node.expression.text)) ||
        (ts.isCallExpression(node.expression) &&
          ts.isIdentifier(node.expression.expression) &&
          node.expression.expression.text === 'require' &&
          node.expression.arguments[0] &&
          moduleSpecifier(node.expression.arguments[0]) === 'react');
      if (isReactNamespace && node.name.text === 'useEffect') {
        report(
          'direct React useEffect access is prohibited by the frontend architecture contract',
        );
      }
    }

    if (
      ts.isElementAccessExpression(node) &&
      ts.isIdentifier(node.expression) &&
      reactNamespaces.has(node.expression.text) &&
      node.argumentExpression &&
      moduleSpecifier(node.argumentExpression) === 'useEffect'
    ) {
      report(
        'direct React useEffect access is prohibited by the frontend architecture contract',
      );
    }

    if (ts.isCallExpression(node)) {
      if (
        node.expression.kind === ts.SyntaxKind.ImportKeyword &&
        node.arguments[0]
      ) {
        const specifier = moduleSpecifier(node.arguments[0]);
        if (specifier) {
          checkModule(specifier);
          if (specifier === 'react') {
            report(
              'dynamic React imports are prohibited so the useEffect constraint cannot be bypassed',
            );
          }
        }
      }
    }

    ts.forEachChild(node, (child) => visit(child, source));
  }

  const scriptKind =
    filePath.endsWith('.tsx') || filePath.endsWith('.jsx')
      ? ts.ScriptKind.TSX
      : ts.ScriptKind.TS;
  for (const [index, chunk] of (await getSourceChunks(filePath)).entries()) {
    const source = ts.createSourceFile(
      `${filePath}#${index}`,
      chunk,
      ts.ScriptTarget.Latest,
      true,
      scriptKind,
    );
    visit(source, source);
  }
}

export async function collectViolations(root = process.cwd()) {
  const rootPath = path.resolve(root);
  const workspaces = [
    ...listDirectories(path.join(rootPath, 'apps')).map((workspacePath) => ({
      workspacePath,
      kind: 'app',
    })),
    ...listDirectories(path.join(rootPath, 'packages')).map(
      (workspacePath) => ({ workspacePath, kind: 'package' }),
    ),
  ];
  const violations = [];
  const workspacesByName = new Map();
  const appsByName = new Map();

  for (const workspace of workspaces) {
    const manifestPath = path.join(workspace.workspacePath, 'package.json');
    if (!statSync(manifestPath, { throwIfNoEntry: false })?.isFile()) continue;
    const manifest = readJson(manifestPath);
    const item = { ...workspace, name: manifest.name, manifest, manifestPath };
    workspacesByName.set(manifest.name, item);
    if (workspace.kind === 'app')
      appsByName.set(manifest.name, workspace.workspacePath);
  }

  for (const workspace of workspacesByName.values()) {
    for (const dependencyName of Object.keys(
      packageDependencies(workspace.manifest),
    )) {
      if (isForbiddenModule(dependencyName)) {
        violations.push(
          `${path.relative(rootPath, workspace.manifestPath)}: prohibited dependency "${dependencyName}"`,
        );
      }
      if (workspace.kind === 'package' && appsByName.has(dependencyName)) {
        violations.push(
          `${path.relative(rootPath, workspace.manifestPath)}: packages may not depend on apps (${dependencyName})`,
        );
      }
      if (
        workspace.kind === 'app' &&
        appsByName.has(dependencyName) &&
        dependencyName !== workspace.name
      ) {
        violations.push(
          `${path.relative(rootPath, workspace.manifestPath)}: apps may not depend on other apps (${dependencyName})`,
        );
      }
    }

    for (const filePath of findSourceFiles(workspace.workspacePath)) {
      await inspectSource(
        filePath,
        workspace,
        appsByName,
        violations,
        rootPath,
      );
    }
  }

  const graph = new Map();
  for (const workspace of workspacesByName.values()) {
    graph.set(
      workspace.name,
      Object.keys(packageDependencies(workspace.manifest)).filter((name) =>
        workspacesByName.has(name),
      ),
    );
  }
  const active = new Set();
  const complete = new Set();
  const cycleKeys = new Set();
  function visitDependency(name, chain) {
    if (active.has(name)) {
      const cycle = [...chain.slice(chain.indexOf(name)), name];
      const key = [...cycle].sort().join('|');
      if (!cycleKeys.has(key)) {
        cycleKeys.add(key);
        violations.push(`workspace dependency cycle: ${cycle.join(' -> ')}`);
      }
      return;
    }
    if (complete.has(name)) return;
    active.add(name);
    for (const dependency of graph.get(name) ?? [])
      visitDependency(dependency, [...chain, dependency]);
    active.delete(name);
    complete.add(name);
  }
  for (const name of graph.keys()) visitDependency(name, [name]);

  return violations;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
) {
  const violations = await collectViolations();
  if (violations.length > 0) {
    console.error('Architecture constraint violations:');
    for (const violation of violations) console.error(`- ${violation}`);
    process.exitCode = 1;
  } else {
    console.log('Architecture constraints passed.');
  }
}
