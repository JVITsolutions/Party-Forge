param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$orchestrator = Join-Path $RepositoryRoot 'tools\validation\capture_living_forge_combat_loop.ps1'
if (-not (Test-Path -LiteralPath $orchestrator -PathType Leaf)) {
    throw "ORCHESTRATOR_CONTRACT_MISSING path=$orchestrator"
}

$priorErrorAction = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    $output = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $orchestrator -Mode SelfTest -RepositoryRoot $RepositoryRoot 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $priorErrorAction
}
$output
if ($exitCode -ne 0) {
    throw "ORCHESTRATOR_CONTRACT_EXIT expected=0 actual=$exitCode"
}
foreach ($marker in @(
    'CANONICAL_CAPTURE_ORDINAL: PASS',
    'CANONICAL_CAPTURE_JUNCTION_ESCAPE: PASS',
    'CANONICAL_CAPTURE_NESTED_EXTRA: PASS',
    'CANONICAL_CAPTURE_PREIMPORT_DIRT: PASS',
    'CANONICAL_CAPTURE_PROCESS_EXIT: PASS',
    'CANONICAL_CAPTURE_ROLLBACK: PASS',
    'CANONICAL_CAPTURE_ORCHESTRATOR_SELF_TEST: PASS'
)) {
    if (-not $output.Contains($marker)) {
        throw "ORCHESTRATOR_CONTRACT_MARKER_MISSING marker=$marker"
    }
}

Write-Output 'CANONICAL_CAPTURE_ORCHESTRATOR_TEST: PASS'
