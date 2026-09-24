$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$binary = Join-Path $repoRoot '.tools/lexa/lexa.exe'
$graph = Join-Path $repoRoot '.tools/lexa/index.sqlite'
if (!(Test-Path -LiteralPath $binary)) {
  [Console]::Error.WriteLine('Lexa is not installed. Run scripts/tooling/install-agent-tools.ps1.')
  exit 127
}
if (!(Test-Path -LiteralPath $graph)) {
  [Console]::Error.WriteLine('Lexa index is missing. Run the documented `lexa index` command for this repository.')
  exit 2
}

& $binary --graph $graph mcp $repoRoot
exit $LASTEXITCODE
