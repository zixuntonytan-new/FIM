[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Invoke-TestGit {
    param(
        [Parameter(Mandatory = $true)][string]$Repository,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    & git -C $Repository @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Fixture Git command failed: git $($Arguments -join ' ')"
    }
}

function Initialize-FixtureRepository {
    param(
        [Parameter(Mandatory = $true)][string]$Repository,
        [Parameter(Mandatory = $true)][string]$Branch
    )

    New-Item -ItemType Directory -Path $Repository -Force | Out-Null
    Invoke-TestGit -Repository $Repository -Arguments @('init')
    Invoke-TestGit -Repository $Repository -Arguments @('config', 'user.name', 'FIM fixture')
    Invoke-TestGit -Repository $Repository -Arguments @('config', 'user.email', 'fixture@example.invalid')
    Invoke-TestGit -Repository $Repository -Arguments @('commit', '--allow-empty', '-m', 'fixture base')
    Invoke-TestGit -Repository $Repository -Arguments @('branch', '-M', $Branch)
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("fim-preflight-" + [guid]::NewGuid())
$codeRoot = Join-Path $testRoot 'code'
$opsRoot = Join-Path $testRoot 'ops'
$governanceRoot = Split-Path -Path $PSScriptRoot -Parent
$repositoryRoot = Split-Path -Path $governanceRoot -Parent
$sourceScript = Join-Path $repositoryRoot 'scripts\Start-FIM-AgentSession.ps1'

try {
    Initialize-FixtureRepository -Repository $codeRoot -Branch 'codex/personal/fixture'
    New-Item -ItemType Directory -Path (Join-Path $codeRoot 'scripts') -Force | Out-Null
    Copy-Item -LiteralPath $sourceScript -Destination (Join-Path $codeRoot 'scripts\Start-FIM-AgentSession.ps1')
    Invoke-TestGit -Repository $codeRoot -Arguments @('add', 'scripts/Start-FIM-AgentSession.ps1')
    Invoke-TestGit -Repository $codeRoot -Arguments @('commit', '-m', 'add preflight')
    Invoke-TestGit -Repository $codeRoot -Arguments @('remote', 'add', 'origin', 'https://github.com/zixuntonytan-new/FIM.git')
    Invoke-TestGit -Repository $codeRoot -Arguments @('remote', 'add', 'upstream', 'https://github.com/Hutchins-RAs/FIM.git')
    Invoke-TestGit -Repository $codeRoot -Arguments @('remote', 'set-url', '--push', 'upstream', 'DISABLED')
    Invoke-TestGit -Repository $codeRoot -Arguments @('update-ref', 'refs/remotes/origin/workflow/shared-context', 'HEAD')

    Initialize-FixtureRepository -Repository $opsRoot -Branch 'main'
    Invoke-TestGit -Repository $opsRoot -Arguments @('remote', 'add', 'origin', 'https://github.com/zixuntonytan-new/hutchins-agent-ops.git')
    foreach ($relativePath in @(
        'FIM/HANDOFF.md',
        'FIM/PROJECT_LOG.md',
        'FIM/OFFICIAL_UPDATE_LOG.md',
        'FIM/AGENT_OVERLAY.md',
        'FIM/WORKING_STYLE.md',
        'governance/HUTCHINS_AGENT_BYLAW.md',
        'FIM/README.md',
        'skills/CATALOG.md'
    )) {
        $path = Join-Path $opsRoot $relativePath
        New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
        Set-Content -LiteralPath $path -Value 'fixture' -NoNewline
    }
    Invoke-TestGit -Repository $opsRoot -Arguments @('add', '.')
    Invoke-TestGit -Repository $opsRoot -Arguments @('commit', '-m', 'add required context')

    $preflight = Join-Path $codeRoot 'scripts\Start-FIM-AgentSession.ps1'
    Set-Content -LiteralPath (Join-Path $opsRoot 'uncommitted.txt') -Value 'fixture' -NoNewline
    try {
        & $preflight -OpsPath $opsRoot -NoPull
        throw 'Preflight accepted dirty private context.'
    }
    catch {
        if ($_.Exception.Message -notmatch 'Private operations has uncommitted changes') {
            throw
        }
    }
    Remove-Item -LiteralPath (Join-Path $opsRoot 'uncommitted.txt') -Force

    & $preflight -OpsPath $opsRoot -NoPull
    if ($LASTEXITCODE -ne 0) {
        throw 'Preflight rejected an approved personal Codex task branch.'
    }

    Invoke-TestGit -Repository $codeRoot -Arguments @('branch', '-M', 'workflow/shared-context')
    Invoke-TestGit -Repository $codeRoot -Arguments @('update-ref', 'refs/remotes/origin/workflow/shared-context', 'HEAD')
    & $preflight -OpsPath $opsRoot -NoPull
    Set-Content -LiteralPath (Join-Path $codeRoot 'uncommitted.txt') -Value 'fixture' -NoNewline
    try {
        & $preflight -OpsPath $opsRoot -NoPull
        throw 'Preflight accepted a dirty canonical checkout.'
    }
    catch {
        if ($_.Exception.Message -notmatch 'canonical workflow checkout must be clean') {
            throw
        }
    }
    Remove-Item -LiteralPath (Join-Path $codeRoot 'uncommitted.txt') -Force

    Invoke-TestGit -Repository $codeRoot -Arguments @('branch', '-M', 'scratch/invalid')
    try {
        & $preflight -OpsPath $opsRoot -NoPull
        throw 'Preflight accepted a disallowed branch.'
    }
    catch {
        if ($_.Exception.Message -notmatch 'not an approved canonical') {
            throw
        }
    }

    Write-Output 'FIM session preflight fixture tests passed.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
