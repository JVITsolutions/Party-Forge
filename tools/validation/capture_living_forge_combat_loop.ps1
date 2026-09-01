param(
    [ValidateSet('Contract', 'DryRun', 'Capture')]
    [string]$Mode = 'Contract',
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$CandidateHead = '',
    [string]$GodotPath = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe',
    [string]$DestinationRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RunnerPath = 'tests/integration/living_forge_combat_loop_visual_evidence_runner.gd'
$script:OrchestratorPath = 'tools/validation/capture_living_forge_combat_loop.ps1'
$script:EvidenceRelativePath = 'docs/validation/screenshots/living-forge-combat-loop'
$script:ExpectedGodotVersion = '4.7.1.stable.mono.official.a13da4feb'
$script:ExpectedCaptureCount = 58

function Normalize-RelativePath {
    param([string]$Path)
    return $Path.Replace('\', '/')
}

function Get-ResolvedExistingPath {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "CANONICAL_CAPTURE_PATH_MISSING label=$Label path=$Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Invoke-CheckedProcess {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [string]$Label,
        [string]$LogPath = ''
    )
    $text = (& $Executable @Arguments 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE
    if (-not [string]::IsNullOrEmpty($LogPath)) {
        [IO.File]::WriteAllText($LogPath, $text, [Text.UTF8Encoding]::new($false))
    }
    if ($exitCode -ne 0) {
        throw "CANONICAL_CAPTURE_PROCESS_FAILED label=$Label exit=$exitCode output=$text"
    }
    return $text
}

function Get-Lines {
    param([string]$Text)
    return @($Text -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-FileRecord {
    param([string]$Root, [string]$AbsolutePath)
    $resolved = Get-ResolvedExistingPath -Path $AbsolutePath -Label 'inventory-file'
    $relative = Normalize-RelativePath ([IO.Path]::GetRelativePath($Root, $resolved))
    return [pscustomobject][ordered]@{
        path = $relative
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolved).Hash.ToLowerInvariant()
    }
}

function Get-InventoryAggregate {
    param([object[]]$Records)
    $builder = [Text.StringBuilder]::new()
    foreach ($record in @($Records | Sort-Object path)) {
        $path = [string]$record.path
        $hash = [string]$record.sha256
        [void]$builder.Append($path.Length).Append(':').Append($path).Append($hash.Length).Append(':').Append($hash).Append("`n")
    }
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($builder.ToString())
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function New-InventoryDocument {
    param([object[]]$Records)
    $sorted = @($Records | Sort-Object path)
    return [pscustomobject][ordered]@{
        count = $sorted.Count
        aggregate_sha256 = Get-InventoryAggregate -Records $sorted
        records = $sorted
    }
}

function Get-GeneratedUidInventory {
    param([string]$CloneRoot)
    $text = Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('-C', $CloneRoot, 'ls-files', '--others', '--exclude-standard', '--') -Label 'generated-uid-query'
    $records = @()
    foreach ($relative in (Get-Lines $text)) {
        $normalized = Normalize-RelativePath $relative.Trim()
        if (-not $normalized.EndsWith('.uid', [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        $records += Get-FileRecord -Root $CloneRoot -AbsolutePath (Join-Path $CloneRoot $normalized.Replace('/', '\'))
    }
    return New-InventoryDocument -Records $records
}

function Get-RuntimePngImportInventory {
    param([string]$CloneRoot)
    $assetRoot = Join-Path $CloneRoot 'assets'
    $records = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $assetRoot -Recurse -File -Filter '*.png.import' | Sort-Object FullName)) {
        $records += Get-FileRecord -Root $CloneRoot -AbsolutePath $file.FullName
    }
    return New-InventoryDocument -Records $records
}

function Get-ReferencedCtexInventory {
    param([string]$CloneRoot, [object]$PngImportInventory)
    $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($record in @($PngImportInventory.records)) {
        $importPath = Join-Path $CloneRoot ([string]$record.path).Replace('/', '\')
        $content = [IO.File]::ReadAllText($importPath)
        foreach ($match in [regex]::Matches($content, 'res://\.godot/imported/[^"\]]+\.ctex')) {
            [void]$paths.Add(([string]$match.Value).Substring(6))
        }
    }
    $records = @()
    foreach ($relative in @($paths | Sort-Object)) {
        $records += Get-FileRecord -Root $CloneRoot -AbsolutePath (Join-Path $CloneRoot $relative.Replace('/', '\'))
    }
    return New-InventoryDocument -Records $records
}

function Assert-DirectoryBoundary {
    param([string]$Parent, [string]$Child, [string]$Label)
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
    $childFull = [IO.Path]::GetFullPath($Child)
    if (-not $childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "CANONICAL_CAPTURE_BOUNDARY_ERROR label=$Label parent=$parentFull child=$childFull"
    }
}

function Assert-ExactEvidenceSet {
    param([string]$EvidenceRoot, [string[]]$ExpectedNames, [string]$Label)
    if (-not (Test-Path -LiteralPath $EvidenceRoot -PathType Container)) {
        throw "CANONICAL_CAPTURE_EVIDENCE_DIRECTORY_MISSING label=$Label path=$EvidenceRoot"
    }
    $actual = @(Get-ChildItem -LiteralPath $EvidenceRoot -File -Filter '*.png' | ForEach-Object Name | Sort-Object)
    $expected = @($ExpectedNames | Sort-Object)
    if ([string]::Join("`n", $actual) -ne [string]::Join("`n", $expected)) {
        throw "CANONICAL_CAPTURE_EVIDENCE_SET_MISMATCH label=$Label actual=$($actual -join ',') expected=$($expected -join ',')"
    }
}

function Write-ProvenanceEnvelope {
    param([string]$Path, [object]$Payload)
    $payloadJson = $Payload | ConvertTo-Json -Depth 12 -Compress
    $payloadBytes = [Text.UTF8Encoding]::new($false).GetBytes($payloadJson)
    $payloadSha = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = ([BitConverter]::ToString($payloadSha.ComputeHash($payloadBytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $payloadSha.Dispose()
    }
    $envelope = [pscustomobject][ordered]@{
        schema_version = 1
        payload_base64 = [Convert]::ToBase64String($payloadBytes)
        payload_sha256 = $hash
    }
    $json = $envelope | ConvertTo-Json -Depth 4 -Compress
    [IO.File]::WriteAllText($Path, $json + "`n", [Text.UTF8Encoding]::new($false))
}

$repository = Get-ResolvedExistingPath -Path $RepositoryRoot -Label 'repository-root'
$actualTop = (Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('-C', $repository, 'rev-parse', '--show-toplevel') -Label 'repository-top').Trim().Replace('/', '\')
if ([IO.Path]::GetFullPath($actualTop) -ne [IO.Path]::GetFullPath($repository)) {
    throw "CANONICAL_CAPTURE_REPOSITORY_MISMATCH expected=$repository actual=$actualTop"
}
$orchestrator = Get-ResolvedExistingPath -Path (Join-Path $repository $script:OrchestratorPath.Replace('/', '\')) -Label 'orchestrator'
$godot = Get-ResolvedExistingPath -Path $GodotPath -Label 'godot-binary'

if ($Mode -eq 'Contract') {
    Write-Output "CANONICAL_CAPTURE_ORCHESTRATOR_CONTRACT: PASS path=$orchestrator godot=$godot"
    exit 0
}

$head = (Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('-C', $repository, 'rev-parse', 'HEAD') -Label 'candidate-head').Trim()
if ([string]::IsNullOrWhiteSpace($CandidateHead)) {
    $CandidateHead = $head
}
if ($CandidateHead -ne $head -or $CandidateHead -notmatch '^[0-9a-f]{40}$') {
    throw "CANONICAL_CAPTURE_HEAD_MISMATCH requested=$CandidateHead current=$head"
}

$trackedOrchestrator = (Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('-C', $repository, 'ls-files', '--error-unmatch', $script:OrchestratorPath) -Label 'orchestrator-tracked').Trim()
if ($trackedOrchestrator -ne $script:OrchestratorPath) {
    throw "CANONICAL_CAPTURE_ORCHESTRATOR_UNTRACKED path=$trackedOrchestrator"
}
$orchestratorDiff = (& git.exe -C $repository diff --quiet HEAD -- $script:OrchestratorPath 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
    throw "CANONICAL_CAPTURE_ORCHESTRATOR_DIRTY path=$script:OrchestratorPath output=$orchestratorDiff"
}

$godotVersion = (Invoke-CheckedProcess -Executable $godot -Arguments @('--version') -Label 'godot-version').Trim()
if ($godotVersion -ne $script:ExpectedGodotVersion) {
    throw "CANONICAL_CAPTURE_GODOT_VERSION_MISMATCH expected=$script:ExpectedGodotVersion actual=$godotVersion"
}
$godotSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $godot).Hash.ToLowerInvariant()

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$runRoot = Join-Path $tempBase ("party-forge-canonical-capture-{0}-{1}" -f $head.Substring(0, 8), [guid]::NewGuid().ToString('N'))
Assert-DirectoryBoundary -Parent $tempBase -Child $runRoot -Label 'run-root'
[void](New-Item -ItemType Directory -Path $runRoot)
$cloneRoot = Join-Path $runRoot 'source'
Assert-DirectoryBoundary -Parent $runRoot -Child $cloneRoot -Label 'clone-root'
$logsRoot = Join-Path $runRoot 'logs'
[void](New-Item -ItemType Directory -Path $logsRoot)

$commonGitDir = (Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('-C', $repository, 'rev-parse', '--path-format=absolute', '--git-common-dir') -Label 'git-common-dir').Trim()
[void](Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('clone', '--local', '--no-hardlinks', '--no-checkout', '--', $commonGitDir, $cloneRoot) -Label 'local-clone' -LogPath (Join-Path $logsRoot 'clone.log'))
[void](Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('-C', $cloneRoot, 'checkout', '--detach', $head) -Label 'detached-checkout' -LogPath (Join-Path $logsRoot 'checkout.log'))
$cloneHead = (Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('-C', $cloneRoot, 'rev-parse', 'HEAD') -Label 'clone-head').Trim()
if ($cloneHead -ne $head) {
    throw "CANONICAL_CAPTURE_CLONE_HEAD_MISMATCH expected=$head actual=$cloneHead"
}
$symbolic = (& git.exe -C $cloneRoot symbolic-ref -q HEAD 2>&1 | Out-String)
if ($LASTEXITCODE -eq 0) {
    throw "CANONICAL_CAPTURE_CLONE_NOT_DETACHED ref=$symbolic"
}

$trackedBefore = Get-Lines (Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('-C', $cloneRoot, 'status', '--porcelain=v1', '--untracked-files=no') -Label 'pre-import-tracked')
$untrackedBefore = Get-Lines (Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('-C', $cloneRoot, 'ls-files', '--others', '--exclude-standard', '--') -Label 'pre-import-untracked')
$ignoredBefore = Get-Lines (Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('-C', $cloneRoot, 'ls-files', '--others', '--ignored', '--exclude-standard', '--') -Label 'pre-import-ignored')
if ($trackedBefore.Count -ne 0 -or $untrackedBefore.Count -ne 0 -or $ignoredBefore.Count -ne 0) {
    throw "CANONICAL_CAPTURE_PREIMPORT_NOT_CLEAN tracked=$($trackedBefore.Count) untracked=$($untrackedBefore.Count) ignored=$($ignoredBefore.Count)"
}
$preImport = [pscustomobject][ordered]@{
    verified = $true
    tracked_changes = @($trackedBefore)
    untracked = @($untrackedBefore)
    ignored = @($ignoredBefore)
}

$isolatedAppData = Join-Path $runRoot 'appdata'
$isolatedLocalAppData = Join-Path $runRoot 'localappdata'
[void](New-Item -ItemType Directory -Path $isolatedAppData)
[void](New-Item -ItemType Directory -Path $isolatedLocalAppData)
$priorAppData = $env:APPDATA
$priorLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $isolatedAppData
    $env:LOCALAPPDATA = $isolatedLocalAppData
    [void](Invoke-CheckedProcess -Executable $godot -Arguments @('--headless', '--editor', '--import', '--quit', '--path', $cloneRoot) -Label 'cold-import' -LogPath (Join-Path $logsRoot 'cold-import.log'))

    $uidInventory = Get-GeneratedUidInventory -CloneRoot $cloneRoot
    $pngImportInventory = Get-RuntimePngImportInventory -CloneRoot $cloneRoot
    $ctexInventory = Get-ReferencedCtexInventory -CloneRoot $cloneRoot -PngImportInventory $pngImportInventory
    if ($uidInventory.count -le 0 -or $pngImportInventory.count -le 0 -or $ctexInventory.count -le 0) {
        throw "CANONICAL_CAPTURE_IMPORT_INVENTORY_EMPTY uid=$($uidInventory.count) png_import=$($pngImportInventory.count) ctex=$($ctexInventory.count)"
    }

    $cloneOrchestrator = Join-Path $cloneRoot $script:OrchestratorPath.Replace('/', '\')
    $payload = [pscustomobject][ordered]@{
        schema_version = 1
        source_head = $head
        orchestrator = [pscustomobject][ordered]@{
            path = $script:OrchestratorPath
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $cloneOrchestrator).Hash.ToLowerInvariant()
        }
        godot = [pscustomobject][ordered]@{
            version = $godotVersion
            binary_sha256 = $godotSha
        }
        pre_import = $preImport
        generated_uids = $uidInventory
        runtime_png_imports = $pngImportInventory
        referenced_ctex = $ctexInventory
    }
    $provenancePath = Join-Path $runRoot 'capture-provenance.json'
    Write-ProvenanceEnvelope -Path $provenancePath -Payload $payload

    [void](Invoke-CheckedProcess -Executable $godot -Arguments @('--path', $cloneRoot, '--rendering-method', 'gl_compatibility', '--quit-after', '2400', '--script', "res://$($script:RunnerPath)", '--', "--capture-provenance=$provenancePath") -Label 'canonical-capture' -LogPath (Join-Path $logsRoot 'capture.log'))
    [void](Invoke-CheckedProcess -Executable $godot -Arguments @('--path', $cloneRoot, '--rendering-method', 'gl_compatibility', '--quit-after', '900', '--script', "res://$($script:RunnerPath)", '--', '--validate-only') -Label 'canonical-validate' -LogPath (Join-Path $logsRoot 'validate.log'))
}
finally {
    $env:APPDATA = $priorAppData
    $env:LOCALAPPDATA = $priorLocalAppData
}

$cloneEvidence = Join-Path $cloneRoot $script:EvidenceRelativePath.Replace('/', '\')
$manifestPath = Join-Path $cloneEvidence 'manifest.json'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$entries = @($manifest.entries)
if ($entries.Count -ne $script:ExpectedCaptureCount) {
    throw "CANONICAL_CAPTURE_MANIFEST_COUNT expected=$($script:ExpectedCaptureCount) actual=$($entries.Count)"
}
$captureNames = @($entries | ForEach-Object { [string]$_.file })
if (@($captureNames | Sort-Object -Unique).Count -ne $script:ExpectedCaptureCount) {
    throw 'CANONICAL_CAPTURE_MANIFEST_NAMES_NOT_UNIQUE'
}
Assert-ExactEvidenceSet -EvidenceRoot $cloneEvidence -ExpectedNames $captureNames -Label 'clone'

if ($Mode -eq 'Capture') {
    if ([string]::IsNullOrWhiteSpace($DestinationRoot)) {
        $DestinationRoot = Join-Path $repository $script:EvidenceRelativePath.Replace('/', '\')
    }
    $expectedDestination = [IO.Path]::GetFullPath((Join-Path $repository $script:EvidenceRelativePath.Replace('/', '\')))
    $destination = [IO.Path]::GetFullPath($DestinationRoot)
    if ($destination -ne $expectedDestination) {
        throw "CANONICAL_CAPTURE_DESTINATION_MISMATCH expected=$expectedDestination actual=$destination"
    }
    Assert-ExactEvidenceSet -EvidenceRoot $destination -ExpectedNames $captureNames -Label 'destination-before-copy'
    foreach ($name in $captureNames) {
        $source = Join-Path $cloneEvidence $name
        $target = Join-Path $destination $name
        [IO.File]::Copy($source, $target, $true)
        $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash
        $targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash
        if ($sourceHash -ne $targetHash) {
            throw "CANONICAL_CAPTURE_COPY_HASH_MISMATCH file=$name"
        }
    }
    [IO.File]::Copy($manifestPath, (Join-Path $destination 'manifest.json'), $true)
    $sourceManifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $manifestPath).Hash
    $destinationManifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $destination 'manifest.json')).Hash
    if ($sourceManifestHash -ne $destinationManifestHash) {
        throw 'CANONICAL_CAPTURE_COPY_HASH_MISMATCH file=manifest.json'
    }
    Assert-ExactEvidenceSet -EvidenceRoot $destination -ExpectedNames $captureNames -Label 'destination-after-copy'
    Write-Output "CANONICAL_CAPTURE_COPY: PASS files=$($script:ExpectedCaptureCount) destination=$destination"
}

Write-Output "CANONICAL_CAPTURE_DRY_QUALIFICATION: PASS head=$head uid=$($uidInventory.count) png_import=$($pngImportInventory.count) ctex=$($ctexInventory.count) run_root=$runRoot"
