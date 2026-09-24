$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$toolRoot = Join-Path $repoRoot '.tools/codedb'
$binary = Join-Path $toolRoot 'codedb.exe'
if (!(Test-Path -LiteralPath $binary)) {
  [Console]::Error.WriteLine('CodeDB is not installed. Run scripts/tooling/install-agent-tools.ps1.')
  exit 127
}

# CodeDB stores each project index under the platform home cache. Scope that
# cache to this checkout and keep telemetry/semantic downloads disabled.
$env:USERPROFILE = Join-Path $toolRoot 'profile'
New-Item -ItemType Directory -Force $env:USERPROFILE | Out-Null
$env:CODEDB_LAZY_MCP = '1'
$env:CODEDB_NO_TELEMETRY = '1'
$env:CODEDB_NO_AUTO_SEMANTIC_MIGRATION = '1'
$env:CODEDB_MCP_LEAN = '1'

& $binary $repoRoot mcp
exit $LASTEXITCODE
