param(
    [ValidateSet('Contract', 'SelfTest', 'DryRun', 'Capture')]
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
    $priorErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $text = (& $Executable @Arguments 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $priorErrorAction
    }
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

function Sort-OrdinalStrings {
    param([string[]]$Values)
    $sorted = [string[]]@($Values)
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    return $sorted
}

function Sort-RecordsOrdinal {
    param([object[]]$Records)
    $byPath = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($record in @($Records)) {
        $path = [string]$record.path
        if ($byPath.ContainsKey($path)) {
            throw "CANONICAL_CAPTURE_INVENTORY_DUPLICATE path=$path"
        }
        $byPath.Add($path, $record)
    }
    $result = @()
    foreach ($path in @(Sort-OrdinalStrings -Values ([string[]]$byPath.Keys))) {
        $result += $byPath[$path]
    }
    return $result
}

function Get-FileRecord {
    param([string]$Root, [string]$AbsolutePath)
    $resolved = Get-ResolvedExistingPath -Path $AbsolutePath -Label 'inventory-file'
    $rootPrefix = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $resolvedFull = [IO.Path]::GetFullPath($resolved)
    if (-not $resolvedFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "CANONICAL_CAPTURE_INVENTORY_BOUNDARY root=$rootPrefix path=$resolvedFull"
    }
    $relative = Normalize-RelativePath $resolvedFull.Substring($rootPrefix.Length)
    return [pscustomobject][ordered]@{
        path = $relative
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolved).Hash.ToLowerInvariant()
    }
}

function Get-InventoryAggregate {
    param([object[]]$Records)
    $builder = [Text.StringBuilder]::new()
    foreach ($record in @(Sort-RecordsOrdinal -Records $Records)) {
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
    $sorted = @(Sort-RecordsOrdinal -Records $Records)
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
    $filesByPath = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($file in @(Get-ChildItem -LiteralPath $assetRoot -Recurse -File -Filter '*.png.import')) {
        $filesByPath.Add([string]$file.FullName, $file)
    }
    foreach ($fullName in @(Sort-OrdinalStrings -Values ([string[]]$filesByPath.Keys))) {
        $file = $filesByPath[$fullName]
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
    foreach ($relative in @(Sort-OrdinalStrings -Values ([string[]]$paths))) {
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

function Assert-NoReparsePath {
    param([string]$Path, [string]$Label)
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    $current = $root
    foreach ($segment in @($full.Substring($root.Length).Split([char]'\', [StringSplitOptions]::RemoveEmptyEntries))) {
        $current = Join-Path $current $segment
        if (-not (Test-Path -LiteralPath $current)) {
            continue
        }
        $item = Get-Item -Force -LiteralPath $current
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "CANONICAL_CAPTURE_REPARSE_REJECTED label=$Label path=$current"
        }
    }
}

function Assert-RepositoryContainedPath {
    param([string]$RepositoryRoot, [string]$TargetPath, [string]$Label)
    $repositoryFull = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
    $targetFull = [IO.Path]::GetFullPath($TargetPath)
    Assert-NoReparsePath -Path $repositoryFull -Label 'repository-root'
    $repositoryPrefix = $repositoryFull + '\'
    if ($targetFull -ne $repositoryFull -and -not $targetFull.StartsWith($repositoryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "CANONICAL_CAPTURE_REPOSITORY_ESCAPE label=$Label repository=$repositoryFull target=$targetFull"
    }
    Assert-NoReparsePath -Path $targetFull -Label $Label
    if (Test-Path -LiteralPath $targetFull) {
        $resolved = (Resolve-Path -LiteralPath $targetFull).Path
        if ($resolved -ne $repositoryFull -and -not $resolved.StartsWith($repositoryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "CANONICAL_CAPTURE_RESOLVED_ESCAPE label=$Label repository=$repositoryFull target=$targetFull resolved=$resolved"
        }
    }
    return $targetFull
}

function Assert-ExactEvidenceSet {
    param([string]$EvidenceRoot, [string[]]$ExpectedNames, [string]$Label)
    if (-not (Test-Path -LiteralPath $EvidenceRoot -PathType Container)) {
        throw "CANONICAL_CAPTURE_EVIDENCE_DIRECTORY_MISSING label=$Label path=$EvidenceRoot"
    }
    $nested = @(Get-ChildItem -LiteralPath $EvidenceRoot -Directory -Force)
    if ($nested.Count -ne 0) {
        $nestedPaths = @(Sort-OrdinalStrings -Values ([string[]]@($nested | ForEach-Object FullName)))
        throw "CANONICAL_CAPTURE_EVIDENCE_NESTED_EXTRA label=$Label path=$($nestedPaths[0])"
    }
    $expected = @(Sort-OrdinalStrings -Values $ExpectedNames)
    $expectedSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($name in $expected) {
        if (-not $expectedSet.Add($name)) {
            throw "CANONICAL_CAPTURE_EVIDENCE_DUPLICATE_EXPECTED label=$Label file=$name"
        }
    }
    $actual = @(Sort-OrdinalStrings -Values ([string[]]@(Get-ChildItem -LiteralPath $EvidenceRoot -File -Filter '*.png' | ForEach-Object Name)))
    if ([string]::Join("`n", $actual) -ne [string]::Join("`n", $expected)) {
        throw "CANONICAL_CAPTURE_EVIDENCE_SET_MISMATCH label=$Label actual=$($actual -join ',') expected=$($expected -join ',')"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $EvidenceRoot 'manifest.json') -PathType Leaf)) {
        throw "CANONICAL_CAPTURE_EVIDENCE_MANIFEST_MISSING label=$Label"
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $EvidenceRoot -File -Force)) {
        if ($file.Name -eq 'manifest.json' -or $expectedSet.Contains($file.Name)) {
            continue
        }
        if ($file.Name.EndsWith('.png.import', [StringComparison]::Ordinal) -and $expectedSet.Contains($file.Name.Substring(0, $file.Name.Length - '.import'.Length))) {
            continue
        }
        throw "CANONICAL_CAPTURE_EVIDENCE_EXTRA label=$Label path=$($file.FullName)"
    }
}

function Assert-PreImportClean {
    param([string[]]$Tracked, [string[]]$Untracked, [string[]]$Ignored)
    if ($Tracked.Count -ne 0 -or $Untracked.Count -ne 0 -or $Ignored.Count -ne 0) {
        throw "CANONICAL_CAPTURE_PREIMPORT_NOT_CLEAN tracked=$($Tracked.Count) untracked=$($Untracked.Count) ignored=$($Ignored.Count)"
    }
}

function Remove-ValidatedTransactionDirectory {
    param([string]$RepositoryRoot, [string]$Parent, [string]$Path, [string[]]$AllowedNames)
    Assert-DirectoryBoundary -Parent $Parent -Child $Path -Label 'transaction-cleanup'
    [void](Assert-RepositoryContainedPath -RepositoryRoot $RepositoryRoot -TargetPath $Path -Label 'transaction-cleanup')
    $directories = @(Get-ChildItem -LiteralPath $Path -Directory -Force)
    if ($directories.Count -ne 0) {
        throw "CANONICAL_CAPTURE_TRANSACTION_CLEANUP_NESTED path=$($directories[0].FullName)"
    }
    $allowed = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($name in $AllowedNames) { [void]$allowed.Add($name) }
    foreach ($file in @(Get-ChildItem -LiteralPath $Path -File -Force)) {
        if (-not $allowed.Contains($file.Name)) {
            throw "CANONICAL_CAPTURE_TRANSACTION_CLEANUP_EXTRA path=$($file.FullName)"
        }
        [IO.File]::Delete($file.FullName)
    }
    [IO.Directory]::Delete($Path, $false)
}

function Invoke-EvidencePromotion {
    param(
        [string]$RepositoryRoot,
        [string]$SourceEvidence,
        [string]$Destination,
        [string[]]$ExpectedNames,
        [int]$SelfTestFailureAfter = -1
    )
    $repositoryFull = Assert-RepositoryContainedPath -RepositoryRoot $RepositoryRoot -TargetPath $RepositoryRoot -Label 'repository-root'
    $destinationFull = Assert-RepositoryContainedPath -RepositoryRoot $repositoryFull -TargetPath $Destination -Label 'evidence-destination'
    $destinationParent = Split-Path -Parent $destinationFull
    [void](Assert-RepositoryContainedPath -RepositoryRoot $repositoryFull -TargetPath $destinationParent -Label 'evidence-parent')
    Assert-ExactEvidenceSet -EvidenceRoot $destinationFull -ExpectedNames $ExpectedNames -Label 'destination-before-promotion'
    Assert-ExactEvidenceSet -EvidenceRoot $SourceEvidence -ExpectedNames $ExpectedNames -Label 'promotion-source'

    $outputNames = @((Sort-OrdinalStrings -Values $ExpectedNames) + 'manifest.json')
    $transactionId = [guid]::NewGuid().ToString('N')
    $staging = Join-Path $destinationParent ".living-forge-stage-$transactionId"
    $backup = Join-Path $destinationParent ".living-forge-backup-$transactionId"
    [void](Assert-RepositoryContainedPath -RepositoryRoot $repositoryFull -TargetPath $staging -Label 'promotion-staging')
    [void](Assert-RepositoryContainedPath -RepositoryRoot $repositoryFull -TargetPath $backup -Label 'promotion-backup')
    [void](New-Item -ItemType Directory -Path $staging)
    [void](New-Item -ItemType Directory -Path $backup)

    $sourceHashes = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    $originalHashes = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    foreach ($name in $outputNames) {
        $source = Join-Path $SourceEvidence $name
        $staged = Join-Path $staging $name
        $destinationFile = Join-Path $destinationFull $name
        $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant()
        $sourceHashes.Add($name, $sourceHash)
        $originalHashes.Add($name, (Get-FileHash -Algorithm SHA256 -LiteralPath $destinationFile).Hash.ToLowerInvariant())
        [IO.File]::Copy($source, $staged, $false)
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $staged).Hash.ToLowerInvariant() -ne $sourceHash) {
            throw "CANONICAL_CAPTURE_STAGE_HASH_MISMATCH file=$name"
        }
    }
    Assert-ExactEvidenceSet -EvidenceRoot $staging -ExpectedNames $ExpectedNames -Label 'promotion-staging'

    $promoted = [Collections.Generic.List[string]]::new()
    try {
        foreach ($name in $outputNames) {
            [IO.File]::Move((Join-Path $destinationFull $name), (Join-Path $backup $name))
        }
        foreach ($name in $outputNames) {
            if ($SelfTestFailureAfter -ge 0 -and $promoted.Count -eq $SelfTestFailureAfter) {
                throw "CANONICAL_CAPTURE_INJECTED_PROMOTION_FAILURE after=$SelfTestFailureAfter"
            }
            [IO.File]::Move((Join-Path $staging $name), (Join-Path $destinationFull $name))
            [void]$promoted.Add($name)
        }
        foreach ($name in $outputNames) {
            $destinationHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $destinationFull $name)).Hash.ToLowerInvariant()
            if ($destinationHash -ne $sourceHashes[$name]) {
                throw "CANONICAL_CAPTURE_COPY_HASH_MISMATCH file=$name"
            }
        }
    }
    catch {
        foreach ($name in @($promoted)) {
            $promotedPath = Join-Path $destinationFull $name
            if (Test-Path -LiteralPath $promotedPath -PathType Leaf) {
                [IO.File]::Delete($promotedPath)
            }
        }
        foreach ($name in $outputNames) {
            $backupPath = Join-Path $backup $name
            if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
                [IO.File]::Move($backupPath, (Join-Path $destinationFull $name))
            }
        }
        foreach ($name in $outputNames) {
            $restoredHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $destinationFull $name)).Hash.ToLowerInvariant()
            if ($restoredHash -ne $originalHashes[$name]) {
                throw "CANONICAL_CAPTURE_ROLLBACK_HASH_MISMATCH file=$name original_error=$($_.Exception.Message)"
            }
        }
        throw "CANONICAL_CAPTURE_PROMOTION_ROLLED_BACK cause=$($_.Exception.Message) staging=$staging backup=$backup"
    }

    Remove-ValidatedTransactionDirectory -RepositoryRoot $repositoryFull -Parent $destinationParent -Path $staging -AllowedNames $outputNames
    Remove-ValidatedTransactionDirectory -RepositoryRoot $repositoryFull -Parent $destinationParent -Path $backup -AllowedNames $outputNames
    Assert-ExactEvidenceSet -EvidenceRoot $destinationFull -ExpectedNames $ExpectedNames -Label 'destination-after-promotion'
    return [pscustomobject]@{ staging = $staging; backup = $backup; files = $outputNames.Count }
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

function Invoke-OrchestratorSelfTest {
    $selfTestRoot = Join-Path ([IO.Path]::GetTempPath()) ("party-forge-canonical-orchestrator-self-test-{0}" -f [guid]::NewGuid().ToString('N'))
    Assert-DirectoryBoundary -Parent ([IO.Path]::GetTempPath()) -Child $selfTestRoot -Label 'self-test-root'
    [void](New-Item -ItemType Directory -Path $selfTestRoot)

    $ordinalPaths = [string[]]@(
        'city_access_provider_result.gd.uid',
        'city_access_provider.gd.uid',
        'city_access_provider-result.gd.uid',
        'city_access_provider.gd.UID'
    )
    $expectedOrdinal = [string[]]@(
        'city_access_provider-result.gd.uid',
        'city_access_provider.gd.UID',
        'city_access_provider.gd.uid',
        'city_access_provider_result.gd.uid'
    )
    $priorCulture = [Globalization.CultureInfo]::CurrentCulture
    $priorUiCulture = [Globalization.CultureInfo]::CurrentUICulture
    try {
        [Globalization.CultureInfo]::CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
        [Globalization.CultureInfo]::CurrentUICulture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
        $enDocument = New-InventoryDocument -Records @($ordinalPaths | ForEach-Object { [pscustomobject]@{ path = $_; sha256 = ('a' * 64) } })
        [Globalization.CultureInfo]::CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('tr-TR')
        [Globalization.CultureInfo]::CurrentUICulture = [Globalization.CultureInfo]::GetCultureInfo('tr-TR')
        $trDocument = New-InventoryDocument -Records @($ordinalPaths | ForEach-Object { [pscustomobject]@{ path = $_; sha256 = ('a' * 64) } })
    }
    finally {
        [Globalization.CultureInfo]::CurrentCulture = $priorCulture
        [Globalization.CultureInfo]::CurrentUICulture = $priorUiCulture
    }
    $actualOrdinal = [string[]]@($enDocument.records | ForEach-Object { [string]$_.path })
    if ([string]::Join("`n", $actualOrdinal) -ne [string]::Join("`n", $expectedOrdinal)) {
        throw "CANONICAL_CAPTURE_SELF_TEST_ORDINAL_ORDER actual=$($actualOrdinal -join ',')"
    }
    if ($enDocument.aggregate_sha256 -ne $trDocument.aggregate_sha256) {
        throw 'CANONICAL_CAPTURE_SELF_TEST_ORDINAL_AGGREGATE_CULTURE_DRIFT'
    }
    Write-Output "CANONICAL_CAPTURE_ORDINAL: PASS aggregate=$($enDocument.aggregate_sha256)"

    $junctionRepo = Join-Path $selfTestRoot 'junction-repo'
    $outside = Join-Path $selfTestRoot 'junction-outside'
    [void](New-Item -ItemType Directory -Path $junctionRepo)
    [void](New-Item -ItemType Directory -Path $outside)
    $outsideSentinel = Join-Path $outside 'sentinel.bin'
    [IO.File]::WriteAllBytes($outsideSentinel, [byte[]](1, 3, 3, 7))
    $outsideHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $outsideSentinel).Hash
    $junction = Join-Path $junctionRepo 'evidence'
    [void](New-Item -ItemType Junction -Path $junction -Target $outside)
    $junctionRejected = $false
    try {
        [void](Assert-RepositoryContainedPath -RepositoryRoot $junctionRepo -TargetPath $junction -Label 'self-test-junction')
    }
    catch {
        $junctionRejected = $_.Exception.Message.Contains('CANONICAL_CAPTURE_REPARSE_REJECTED')
    }
    if (-not $junctionRejected -or (Get-FileHash -Algorithm SHA256 -LiteralPath $outsideSentinel).Hash -ne $outsideHash) {
        throw 'CANONICAL_CAPTURE_SELF_TEST_JUNCTION_NOT_FAIL_CLOSED'
    }
    Write-Output 'CANONICAL_CAPTURE_JUNCTION_ESCAPE: PASS'

    $nestedEvidence = Join-Path $selfTestRoot 'nested-evidence'
    [void](New-Item -ItemType Directory -Path $nestedEvidence)
    [IO.File]::WriteAllBytes((Join-Path $nestedEvidence 'expected.png'), [byte[]](1))
    [IO.File]::WriteAllText((Join-Path $nestedEvidence 'manifest.json'), '{}')
    $nestedDirectory = Join-Path $nestedEvidence 'stale'
    [void](New-Item -ItemType Directory -Path $nestedDirectory)
    [IO.File]::WriteAllBytes((Join-Path $nestedDirectory 'old.png'), [byte[]](2))
    $nestedRejected = $false
    try {
        Assert-ExactEvidenceSet -EvidenceRoot $nestedEvidence -ExpectedNames @('expected.png') -Label 'self-test-nested'
    }
    catch {
        $nestedRejected = $_.Exception.Message.Contains('CANONICAL_CAPTURE_EVIDENCE_NESTED_EXTRA')
    }
    if (-not $nestedRejected) { throw 'CANONICAL_CAPTURE_SELF_TEST_NESTED_EXTRA_ACCEPTED' }
    Write-Output 'CANONICAL_CAPTURE_NESTED_EXTRA: PASS'

    $preImportRejected = $false
    try {
        Assert-PreImportClean -Tracked @('dirty.txt') -Untracked @() -Ignored @()
    }
    catch {
        $preImportRejected = $_.Exception.Message.Contains('CANONICAL_CAPTURE_PREIMPORT_NOT_CLEAN tracked=1')
    }
    if (-not $preImportRejected) { throw 'CANONICAL_CAPTURE_SELF_TEST_PREIMPORT_DIRT_ACCEPTED' }
    Write-Output 'CANONICAL_CAPTURE_PREIMPORT_DIRT: PASS'

    $processRejected = $false
    try {
        [void](Invoke-CheckedProcess -Executable 'powershell.exe' -Arguments @('-NoProfile', '-Command', 'exit 23') -Label 'self-test-exit')
    }
    catch {
        $processRejected = $_.Exception.Message.Contains('label=self-test-exit exit=23')
    }
    if (-not $processRejected) { throw 'CANONICAL_CAPTURE_SELF_TEST_PROCESS_EXIT_LOST' }
    Write-Output 'CANONICAL_CAPTURE_PROCESS_EXIT: PASS'

    $promotionRepo = Join-Path $selfTestRoot 'promotion-repo'
    $promotionSource = Join-Path $promotionRepo 'source-evidence'
    $promotionDestination = Join-Path $promotionRepo 'destination-evidence'
    [void](New-Item -ItemType Directory -Path $promotionRepo)
    [void](New-Item -ItemType Directory -Path $promotionSource)
    [void](New-Item -ItemType Directory -Path $promotionDestination)
    $promotionNames = [string[]]@('a.png', 'b.png')
    foreach ($name in @($promotionNames + 'manifest.json')) {
        [IO.File]::WriteAllText((Join-Path $promotionSource $name), "new-$name", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $promotionDestination $name), "old-$name", [Text.UTF8Encoding]::new($false))
    }
    $sidecar = Join-Path $promotionDestination 'a.png.import'
    [IO.File]::WriteAllText($sidecar, 'nonapproval-sidecar', [Text.UTF8Encoding]::new($false))
    $sidecarHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sidecar).Hash
    $rollbackRejected = $false
    try {
        [void](Invoke-EvidencePromotion -RepositoryRoot $promotionRepo -SourceEvidence $promotionSource -Destination $promotionDestination -ExpectedNames $promotionNames -SelfTestFailureAfter 2)
    }
    catch {
        $rollbackRejected = $_.Exception.Message.Contains('CANONICAL_CAPTURE_PROMOTION_ROLLED_BACK')
    }
    if (-not $rollbackRejected) { throw 'CANONICAL_CAPTURE_SELF_TEST_PROMOTION_FAILURE_NOT_PROPAGATED' }
    foreach ($name in @($promotionNames + 'manifest.json')) {
        if ([IO.File]::ReadAllText((Join-Path $promotionDestination $name)) -ne "old-$name") {
            throw "CANONICAL_CAPTURE_SELF_TEST_ROLLBACK_MIXED file=$name"
        }
    }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $sidecar).Hash -ne $sidecarHash) {
        throw 'CANONICAL_CAPTURE_SELF_TEST_SIDECAR_CHANGED'
    }
    $promotionResult = Invoke-EvidencePromotion -RepositoryRoot $promotionRepo -SourceEvidence $promotionSource -Destination $promotionDestination -ExpectedNames $promotionNames
    foreach ($name in @($promotionNames + 'manifest.json')) {
        if ([IO.File]::ReadAllText((Join-Path $promotionDestination $name)) -ne "new-$name") {
            throw "CANONICAL_CAPTURE_SELF_TEST_SUCCESS_MISMATCH file=$name"
        }
    }
    if ((Test-Path -LiteralPath $promotionResult.staging) -or (Test-Path -LiteralPath $promotionResult.backup)) {
        throw 'CANONICAL_CAPTURE_SELF_TEST_SUCCESS_TRANSACTION_DIR_RETAINED'
    }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $sidecar).Hash -ne $sidecarHash) {
        throw 'CANONICAL_CAPTURE_SELF_TEST_SUCCESS_SIDECAR_CHANGED'
    }
    Write-Output 'CANONICAL_CAPTURE_ROLLBACK: PASS'
    Write-Output "CANONICAL_CAPTURE_ORCHESTRATOR_SELF_TEST: PASS root=$selfTestRoot"
}

if ($Mode -eq 'SelfTest') {
    Invoke-OrchestratorSelfTest
    exit 0
}

$repositoryInput = [IO.Path]::GetFullPath($RepositoryRoot)
Assert-NoReparsePath -Path $repositoryInput -Label 'repository-root-input'
$repository = Get-ResolvedExistingPath -Path $repositoryInput -Label 'repository-root'
$actualTop = (Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('-C', $repository, 'rev-parse', '--show-toplevel') -Label 'repository-top').Trim().Replace('/', '\')
if ([IO.Path]::GetFullPath($actualTop) -ne [IO.Path]::GetFullPath($repository)) {
    throw "CANONICAL_CAPTURE_REPOSITORY_MISMATCH expected=$repository actual=$actualTop"
}
[void](Assert-RepositoryContainedPath -RepositoryRoot $repository -TargetPath $repository -Label 'repository-root')
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
$godotEngine = $godot
if ([IO.Path]::GetFileName($godot).EndsWith('_console.exe', [StringComparison]::OrdinalIgnoreCase)) {
    $engineCandidate = $godot.Substring(0, $godot.Length - '_console.exe'.Length) + '.exe'
    $godotEngine = Get-ResolvedExistingPath -Path $engineCandidate -Label 'godot-engine-binary'
}
$godotLauncherSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $godot).Hash.ToLowerInvariant()
$godotEngineSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $godotEngine).Hash.ToLowerInvariant()

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

$trackedBefore = @(Get-Lines (Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('-C', $cloneRoot, 'status', '--porcelain=v1', '--untracked-files=no') -Label 'pre-import-tracked'))
$untrackedBefore = @(Get-Lines (Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('-C', $cloneRoot, 'ls-files', '--others', '--exclude-standard', '--') -Label 'pre-import-untracked'))
$ignoredBefore = @(Get-Lines (Invoke-CheckedProcess -Executable 'git.exe' -Arguments @('-C', $cloneRoot, 'ls-files', '--others', '--ignored', '--exclude-standard', '--') -Label 'pre-import-ignored'))
Assert-PreImportClean -Tracked $trackedBefore -Untracked $untrackedBefore -Ignored $ignoredBefore
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
            launcher_filename = [IO.Path]::GetFileName($godot)
            launcher_sha256 = $godotLauncherSha
            engine_sha256 = $godotEngineSha
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
$captureNameSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($captureName in $captureNames) { [void]$captureNameSet.Add($captureName) }
if ($captureNameSet.Count -ne $script:ExpectedCaptureCount) {
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
    [void](Assert-RepositoryContainedPath -RepositoryRoot $repository -TargetPath (Split-Path -Parent $destination) -Label 'evidence-parent')
    [void](Assert-RepositoryContainedPath -RepositoryRoot $repository -TargetPath $destination -Label 'evidence-destination')
    $promotion = Invoke-EvidencePromotion -RepositoryRoot $repository -SourceEvidence $cloneEvidence -Destination $destination -ExpectedNames $captureNames
    Write-Output "CANONICAL_CAPTURE_COPY: PASS files=$($script:ExpectedCaptureCount) destination=$destination"
}

Write-Output "CANONICAL_CAPTURE_DRY_QUALIFICATION: PASS head=$head uid=$($uidInventory.count) png_import=$($pngImportInventory.count) ctex=$($ctexInventory.count) run_root=$runRoot"
