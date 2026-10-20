# Dot-source this script to activate the current PowerShell session.
if ($MyInvocation.InvocationName -ne '.') {
    Write-Warning 'Use dot-sourcing in the current PowerShell session: . ./tool/activate.ps1'
    return
}

& {
    param($ProjectRoot)

    if (Get-Variable -Name DietClientActivationState -Scope Global -ErrorAction SilentlyContinue) {
        return
    }

    $temporaryDirectory = Join-Path $ProjectRoot '.local/tmp'
    $environment = @{
        PUB_CACHE = Join-Path $ProjectRoot '.pub-cache'
        GRADLE_USER_HOME = Join-Path $ProjectRoot '.gradle-cache'
        CI = 'true'
        FLUTTER_SUPPRESS_ANALYTICS = 'true'
        TMPDIR = $temporaryDirectory
        TMP = $temporaryDirectory
        TEMP = $temporaryDirectory
    }
    New-Item -ItemType Directory -Path $temporaryDirectory -Force -ErrorAction Stop | Out-Null

    $originalEnvironment = @{}
    foreach ($name in $environment.Keys) {
        $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    $originalPrompt = Get-Item Function:prompt -ErrorAction SilentlyContinue
    $originalDeactivate = Get-Item Function:deactivate -ErrorAction SilentlyContinue
    $global:DietClientActivationState = @{
        Environment = $originalEnvironment
        Prompt = if ($originalPrompt) { $originalPrompt.ScriptBlock } else { $null }
        Deactivate = if ($originalDeactivate) { $originalDeactivate.ScriptBlock } else { $null }
    }
    foreach ($name in $environment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $environment[$name], 'Process')
    }

    function global:prompt {
        '(DietClient) ' + $(if ($global:DietClientActivationState.Prompt) {
            & $global:DietClientActivationState.Prompt
        })
    }

    function global:deactivate {
        $state = $global:DietClientActivationState
        foreach ($name in $state.Environment.Keys) {
            if ($null -eq $state.Environment[$name]) {
                Remove-Item -LiteralPath "Env:\$name" -ErrorAction SilentlyContinue
            }
            else {
                [Environment]::SetEnvironmentVariable($name, $state.Environment[$name], 'Process')
            }
        }
        if ($state.Prompt) {
            Set-Item Function:global:prompt -Value $state.Prompt
        }
        else {
            Remove-Item Function:prompt
        }
        if ($state.Deactivate) {
            Set-Item Function:global:deactivate -Value $state.Deactivate
        }
        else {
            Remove-Item Function:deactivate
        }
        Remove-Variable -Name DietClientActivationState -Scope Global
    }
} (Split-Path -Parent $PSScriptRoot)
