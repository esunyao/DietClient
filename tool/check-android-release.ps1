[CmdletBinding()]
param(
    [string]$MappingPath
)

# By default, resolve from this script's project root, independent of caller cwd.
# An explicit relative -MappingPath resolves from the caller's current directory.
$ErrorActionPreference = 'Stop'
$requiredClasses = @(
    'kotlin.Unit',
    'kotlin.Result',
    'kotlin.Result$Failure',
    'kotlin.coroutines.Continuation',
    'kotlin.coroutines.intrinsics.CoroutineSingletons',
    'kotlin.coroutines.intrinsics.IntrinsicsKt'
)
$states = @{}
foreach ($className in $requiredClasses) {
    $states[$className] = 'missing'
}

$reader = $null
try {
    if ($PSBoundParameters.ContainsKey('MappingPath')) {
        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($MappingPath)
    } else {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        $resolvedPath = Join-Path $projectRoot 'build/app/outputs/mapping/release/mapping.txt'
    }

    $encoding = [System.Text.UTF8Encoding]::new($false, $true)
    $reader = [System.IO.StreamReader]::new($resolvedPath, $encoding)
    while ($null -ne ($line = $reader.ReadLine())) {
        # R8 class headers start at column zero; comments and member rows do not.
        if ($line -cmatch '^(\S+) -> (\S+):$') {
            $original = $Matches[1]
            $target = $Matches[2]
            if ($requiredClasses -ccontains $original) {
                if ($states[$original] -ne 'missing' -or $target -cne $original) {
                    $states[$original] = 'invalid'
                } else {
                    $states[$original] = 'present'
                }
            }
        }
    }
} catch {
    Write-Output 'FAIL mapping'
    exit 1
} finally {
    if ($null -ne $reader) {
        $reader.Dispose()
    }
}

$failed = $false
foreach ($className in $requiredClasses) {
    if ($states[$className] -eq 'present') {
        Write-Output "PASS $className"
    } else {
        Write-Output "FAIL $className"
        $failed = $true
    }
}

if ($failed) {
    exit 1
}
exit 0
