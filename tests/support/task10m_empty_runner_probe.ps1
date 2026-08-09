param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$probeRoot = Join-Path ([IO.Path]::GetTempPath()) ("party-forge-task10m-runner-{0}" -f [Guid]::NewGuid().ToString("N"))
$probeRoot = [IO.Path]::GetFullPath($probeRoot)
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if (-not $probeRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing runner probe outside the temporary directory: $probeRoot"
}

function Invoke-ProbeRunner {
    param(
        [string]$RunnerPath
    )
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $GodotPath
    $startInfo.Arguments = "--headless --path `"$probeRoot`" --script $RunnerPath"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    # Consume both pipes concurrently; sequential ReadToEnd calls can deadlock if
    # Godot fills stderr while the parent is still waiting for stdout EOF.
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not $process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 50
        $process.Refresh()
    }
    if (-not $process.HasExited) {
        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($process.Id)" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*$probeRoot*" })
        foreach ($child in $children) {
            Stop-Process -Id $child.ProcessId -Force -ErrorAction SilentlyContinue
        }
        $live = Get-CimInstance Win32_Process -Filter "ProcessId=$($process.Id)" -ErrorAction SilentlyContinue
        if ($null -ne $live -and $live.CommandLine -like "*$probeRoot*") {
            Stop-Process -Id $process.Id -Force
        }
        throw "Runner probe timed out path=$RunnerPath pid=$($process.Id)"
    }
    $process.WaitForExit()
    $process.Refresh()
    $exitCode = $process.ExitCode
    if ($null -eq $exitCode) {
        throw "Runner probe did not expose an exit code path=$RunnerPath pid=$($process.Id)"
    }
    $output = "$($stdoutTask.Result)`n$($stderrTask.Result)"
    $process.Dispose()
    return [PSCustomObject]@{ ExitCode = [int]$exitCode; Output = $output }
}

try {
    New-Item -ItemType Directory -Path (Join-Path $probeRoot "tests\support") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $probeRoot "project.godot") -Encoding UTF8 -Value @'
[application]
config/name="Party Forge Task 10M Runner Probe"

[rendering]
renderer/rendering_method="gl_compatibility"
'@
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "..\test_runner.gd") -Destination (Join-Path $probeRoot "tests\test_runner.gd")
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "..\focused_test_runner.gd") -Destination (Join-Path $probeRoot "tests\focused_test_runner.gd")
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "test_script_error_capture.gd") -Destination (Join-Path $probeRoot "tests\support\test_script_error_capture.gd")

    $openFailure = Invoke-ProbeRunner "res://tests/test_runner.gd"
    if ($openFailure.ExitCode -isnot [int] -or $openFailure.ExitCode -eq 0 -or $openFailure.Output -notmatch "TEST_RUNNER_DISCOVERY_ERROR: cannot open unit suite directory res://tests/unit") {
        throw "Missing-directory runner probe failed contract. exit=$($openFailure.ExitCode) output=$($openFailure.Output)"
    }

    New-Item -ItemType Directory -Path (Join-Path $probeRoot "tests\unit") -Force | Out-Null
    $zeroFailure = Invoke-ProbeRunner "res://tests/test_runner.gd"
    if ($zeroFailure.ExitCode -isnot [int] -or $zeroFailure.ExitCode -eq 0 -or $zeroFailure.Output -notmatch "TEST_RUNNER_DISCOVERY_ERROR: zero unit suites discovered in res://tests/unit") {
        throw "Zero-suite runner probe failed contract. exit=$($zeroFailure.ExitCode) output=$($zeroFailure.Output)"
    }

    $focusedFailure = Invoke-ProbeRunner "res://tests/focused_test_runner.gd"
    if ($focusedFailure.ExitCode -isnot [int] -or $focusedFailure.ExitCode -eq 0 -or $focusedFailure.Output -notmatch "FOCUSED_TEST_RUNNER_ERROR: no suite path arguments") {
        throw "Argument-free focused-runner probe failed contract. exit=$($focusedFailure.ExitCode) output=$($focusedFailure.Output)"
    }

    Write-Output "TASK10M_EMPTY_RUNNER_PROBE_SUMMARY: PASS open=$($openFailure.ExitCode) zero=$($zeroFailure.ExitCode) focused=$($focusedFailure.ExitCode)"
}
finally {
    if (Test-Path -LiteralPath $probeRoot) {
        Remove-Item -LiteralPath $probeRoot -Recurse -Force
    }
}
