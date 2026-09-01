param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$orchestrator = Join-Path $RepositoryRoot 'tools\validation\capture_living_forge_combat_loop.ps1'
if (-not (Test-Path -LiteralPath $orchestrator -PathType Leaf)) {
    throw "ORCHESTRATOR_CONTRACT_MISSING path=$orchestrator"
}

$source = [IO.File]::ReadAllText($orchestrator)
foreach ($required in @("'clone', '--local', '--no-hardlinks'", 'Assert-DirectoryBoundary', 'CANONICAL_CAPTURE_PREIMPORT_NOT_CLEAN', 'CANONICAL_CAPTURE_COPY_HASH_MISMATCH', 'launcher_sha256', 'engine_sha256')) {
    if (-not $source.Contains($required)) {
        throw "ORCHESTRATOR_CONTRACT_REQUIRED_TEXT_MISSING text=$required"
    }
}
foreach ($forbidden in @('Remove-Item', 'git clean', 'Invoke-WebRequest', 'Start-BitsTransfer', 'GetRelativePath')) {
    if ($source.Contains($forbidden)) {
        throw "ORCHESTRATOR_CONTRACT_FORBIDDEN_TEXT_PRESENT text=$forbidden"
    }
}

$output = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $orchestrator -Mode Contract -RepositoryRoot $RepositoryRoot 2>&1 | Out-String)
$exitCode = $LASTEXITCODE
$output
if ($exitCode -ne 0) {
    throw "ORCHESTRATOR_CONTRACT_EXIT expected=0 actual=$exitCode"
}
if (-not $output.Contains('CANONICAL_CAPTURE_ORCHESTRATOR_CONTRACT: PASS')) {
    throw 'ORCHESTRATOR_CONTRACT_MARKER_MISSING'
}

Write-Output 'CANONICAL_CAPTURE_ORCHESTRATOR_TEST: PASS'
