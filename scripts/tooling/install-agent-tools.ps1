$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$toolRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../.tools'))
$downloadRoot = Join-Path $toolRoot 'downloads'
$codedbRoot = Join-Path $toolRoot 'codedb'
$lexaRoot = Join-Path $toolRoot 'lexa'
$lspAiRoot = Join-Path $toolRoot 'lsp-ai'

New-Item -ItemType Directory -Force $downloadRoot, $codedbRoot, $lexaRoot, $lspAiRoot | Out-Null

function Get-Sha256([string]$path) {
  return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-ManifestHash([string]$manifestPath, [string]$assetName) {
  $escapedName = [Regex]::Escape($assetName)
  $entry = Get-Content -LiteralPath $manifestPath | Where-Object { $_ -match "\s$escapedName$" } | Select-Object -First 1
  if (!$entry) {
    throw "No checksum entry for $assetName in $manifestPath"
  }

  return (($entry.Trim() -split '\s+')[0]).ToLowerInvariant()
}

function Download([string]$url, [string]$path) {
  Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
}

function Assert-Hash([string]$path, [string]$expected) {
  $actual = Get-Sha256 $path
  if ($actual -ne $expected.ToLowerInvariant()) {
    throw "SHA-256 mismatch for $path. Expected $expected; received $actual."
  }
}

function Remove-ToolCache([string]$path) {
  $resolvedPath = [System.IO.Path]::GetFullPath($path)
  $resolvedDownloads = [System.IO.Path]::GetFullPath($downloadRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
  if (!$resolvedPath.StartsWith($resolvedDownloads, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove a path outside .tools/downloads: $resolvedPath"
  }
  if (Test-Path -LiteralPath $resolvedPath) {
    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
  }
}

$codedbVersion = 'v0.2.5856'
$codedbAsset = 'codedb-windows-x86_64.exe'
$codedbUrl = "https://github.com/justrach/codedb/releases/download/$codedbVersion/$codedbAsset"
$codedbManifestUrl = "https://github.com/justrach/codedb/releases/download/$codedbVersion/checksums.sha256"
$codedbDownload = Join-Path $downloadRoot $codedbAsset
$codedbManifest = Join-Path $downloadRoot 'codedb-checksums.sha256'
Download $codedbUrl $codedbDownload
Download $codedbManifestUrl $codedbManifest
Assert-Hash $codedbDownload (Get-ManifestHash $codedbManifest $codedbAsset)
Copy-Item -LiteralPath $codedbDownload -Destination (Join-Path $codedbRoot 'codedb.exe') -Force

$lexaVersion = 'v0.10.1'
$lexaAsset = 'lexa-windows-x86_64-0.10.1.zip'
$lexaUrl = "https://github.com/anvia-hq/lexa/releases/download/$lexaVersion/$lexaAsset"
$lexaManifestUrl = "https://github.com/anvia-hq/lexa/releases/download/$lexaVersion/SHA256SUMS"
$lexaDownload = Join-Path $downloadRoot $lexaAsset
$lexaManifest = Join-Path $downloadRoot 'lexa-SHA256SUMS'
Download $lexaUrl $lexaDownload
Download $lexaManifestUrl $lexaManifest
Assert-Hash $lexaDownload (Get-ManifestHash $lexaManifest $lexaAsset)
$lexaExtract = Join-Path $downloadRoot 'lexa-extract'
Remove-ToolCache $lexaExtract
Expand-Archive -LiteralPath $lexaDownload -DestinationPath $lexaExtract -Force
Copy-Item -LiteralPath (Join-Path $lexaExtract 'lexa.exe') -Destination (Join-Path $lexaRoot 'lexa.exe') -Force

$lspAiVersion = 'v0.7.1'
$lspAiAsset = 'lsp-ai-x86_64-pc-windows-msvc.zip'
$lspAiUrl = "https://github.com/SilasMarvin/lsp-ai/releases/download/$lspAiVersion/$lspAiAsset"
$lspAiDownload = Join-Path $downloadRoot $lspAiAsset
# Upstream publishes no checksum for this asset. This pin records the reviewed
# official-release archive hash; it is not an upstream signature or attestation.
$lspAiReviewedHash = 'd52a7441025e86f8d18289655ea49207f7d312013757a93df80141ba7012478b'
Download $lspAiUrl $lspAiDownload
Assert-Hash $lspAiDownload $lspAiReviewedHash
$lspAiExtract = Join-Path $downloadRoot 'lsp-ai-extract'
Remove-ToolCache $lspAiExtract
Expand-Archive -LiteralPath $lspAiDownload -DestinationPath $lspAiExtract -Force
Copy-Item -LiteralPath (Join-Path $lspAiExtract 'lsp-ai.exe') -Destination (Join-Path $lspAiRoot 'lsp-ai.exe') -Force

Write-Host "Installed project-local CodeDB $codedbVersion, Lexa $lexaVersion, and LSP-AI $lspAiVersion under .tools/."
