param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,
    [switch]$Visual
)

$ErrorActionPreference = 'Stop'
$repoPath = Split-Path -Parent $PSScriptRoot
$runtimePath = Join-Path $repoPath '.godot/weapon_runtime'
New-Item -ItemType Directory -Force -Path $runtimePath | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$testExitCode = 1
try {
    $env:APPDATA = $runtimePath
    $env:LOCALAPPDATA = $runtimePath
    & $GodotPath --headless --path $repoPath --editor --import --quit
    if ($LASTEXITCODE -ne 0) {
        throw 'Godot import failed.'
    }
    $testArguments = @('--path', $repoPath, '--fixed-fps', '60', 'res://tests/test_weapon_system.tscn')
    if (-not $Visual) {
        $testArguments = @('--headless') + $testArguments
    }
    & $GodotPath @testArguments
    $testExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
exit $testExitCode
