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
        PoshCommand = $null
        PoshConfig = $env:POSH_CONFIG
        PoshThemeFile = $null
    }
    foreach ($name in $environment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $environment[$name], 'Process')
    }

    $poshCommand = Get-Command oh-my-posh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($poshCommand -and $originalPrompt.ModuleName -like 'oh-my-posh*') {
        $themeFile = Join-Path $temporaryDirectory ('dietclient-' + [guid]::NewGuid().ToString('N') + '.omp.json')
        try {
            $configArguments = @()
            if ($env:POSH_CONFIG) { $configArguments = @('--config', $env:POSH_CONFIG) }
            $themeJson = & $poshCommand.Source config export @configArguments
            if ($LASTEXITCODE -ne 0) { throw 'Could not export the current Oh My Posh theme.' }
            $theme = ($themeJson -join "`n") | ConvertFrom-Json -ErrorAction Stop
            $block = $theme.blocks | Where-Object { $_.type -eq 'prompt' -and $_.alignment -eq 'left' } | Select-Object -First 1
            if (-not $block) { throw 'The current theme has no left prompt block.' }
            $badge = [pscustomobject]@{
                type = 'text'
                style = 'diamond'
                leading_diamond = [string][char]0xe0b6
                trailing_diamond = ([string][char]0xe0b4) + ' '
                foreground = '#E9F5EF'
                background = '#216753'
                template = ' DietClient '
            }
            $block.segments = @($badge) + @($block.segments)
            [IO.File]::WriteAllText($themeFile, ($theme | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))
            $initialization = & $poshCommand.Source init pwsh --config $themeFile
            if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the DietClient theme.' }
            $initialization | Out-String | Invoke-Expression
            $global:DietClientActivationState.PoshCommand = $poshCommand.Source
            $global:DietClientActivationState.PoshThemeFile = $themeFile
        }
        catch {
            Remove-Item -LiteralPath $themeFile -ErrorAction SilentlyContinue
            Write-Warning 'Oh My Posh integration failed; using the plain DietClient prefix.'
        }
    }
    if (-not $global:DietClientActivationState.PoshCommand) {
        function global:prompt {
            '(DietClient) ' + $(if ($global:DietClientActivationState.Prompt) {
                & $global:DietClientActivationState.Prompt
            })
        }
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
        if ($state.PoshCommand) {
            $configArguments = @()
            if ($state.PoshConfig) { $configArguments = @('--config', $state.PoshConfig) }
            if ($null -eq $state.PoshConfig) {
                Remove-Item Env:POSH_CONFIG -ErrorAction SilentlyContinue
            }
            else {
                $env:POSH_CONFIG = $state.PoshConfig
            }
            & $state.PoshCommand init pwsh @configArguments | Out-String | Invoke-Expression
            Remove-Item -LiteralPath $state.PoshThemeFile -ErrorAction SilentlyContinue
        }
        elseif ($state.Prompt) {
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
