# Forward arguments unchanged; use the Flutter SDK already on PATH.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$flutterProjectRoot = Split-Path -Parent $PSScriptRoot
$flutterTemporaryDirectory = Join-Path $flutterProjectRoot '.local/tmp'
$flutterEnvironment = @{
    PUB_CACHE = Join-Path $flutterProjectRoot '.pub-cache'
    GRADLE_USER_HOME = Join-Path $flutterProjectRoot '.gradle-cache'
    CI = 'true'
    FLUTTER_SUPPRESS_ANALYTICS = 'true'
    TMPDIR = $flutterTemporaryDirectory
    TMP = $flutterTemporaryDirectory
    TEMP = $flutterTemporaryDirectory
}
$flutterOriginalEnvironment = @{}
$flutterExitCode = 1

Push-Location -LiteralPath $flutterProjectRoot
try {
    foreach ($flutterVariable in $flutterEnvironment.Keys) {
        $flutterOriginalEnvironment[$flutterVariable] = [Environment]::GetEnvironmentVariable($flutterVariable, 'Process')
    }
    foreach ($flutterVariable in $flutterEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($flutterVariable, $flutterEnvironment[$flutterVariable], 'Process')
    }
    New-Item -ItemType Directory -Path $flutterTemporaryDirectory -Force | Out-Null
    $flutterCommand = Get-Command flutter -CommandType Application -ErrorAction Stop | Select-Object -First 1
    & $flutterCommand.Source --no-version-check @args
    $flutterExitCode = $LASTEXITCODE
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
}
finally {
    foreach ($flutterVariable in $flutterOriginalEnvironment.Keys) {
        if ($null -eq $flutterOriginalEnvironment[$flutterVariable]) {
            Remove-Item -LiteralPath "Env:\$flutterVariable" -ErrorAction SilentlyContinue
        }
        else {
            [Environment]::SetEnvironmentVariable($flutterVariable, $flutterOriginalEnvironment[$flutterVariable], 'Process')
        }
    }
    Pop-Location
}

exit $flutterExitCode
