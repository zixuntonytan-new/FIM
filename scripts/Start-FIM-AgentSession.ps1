[CmdletBinding()]
param(
    [string]$OpsPath,
    [switch]$NoPull,
    [switch]$AllowDirtyOps
)

$ErrorActionPreference = 'Stop'

function Invoke-CheckedGit {
    param(
        [Parameter(Mandatory = $true)][string]$Repository,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $priorErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -c "safe.directory=$Repository" -C $Repository @Arguments 2>$null
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $priorErrorAction
    }
    if ($exitCode -ne 0) {
        throw ("Git failed in {0}: git {1}" -f $Repository, ($Arguments -join ' '))
    }
    return ($output -join [Environment]::NewLine).Trim()
}

function Find-OpsRepository {
    param([Parameter(Mandatory = $true)][string]$CodeRoot)

    if ($OpsPath) {
        return $OpsPath
    }
    if ($env:HUTCHINS_AGENT_OPS) {
        return $env:HUTCHINS_AGENT_OPS
    }

    $probe = $CodeRoot
    for ($level = 0; $level -lt 7; $level++) {
        $candidate = Join-Path $probe 'hutchins-agent-ops'
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return $candidate
        }
        $parent = Split-Path -Path $probe -Parent
        if (-not $parent -or $parent -eq $probe) {
            break
        }
        $probe = $parent
    }
    throw 'Private hutchins-agent-ops clone was not found. Set HUTCHINS_AGENT_OPS or pass -OpsPath.'
}

$scriptDirectory = Split-Path -Path $PSCommandPath -Parent
$candidateCodeRoot = Split-Path -Path $scriptDirectory -Parent
$codeRoot = Invoke-CheckedGit -Repository $candidateCodeRoot -Arguments @('rev-parse', '--show-toplevel')
$codeRoot = $codeRoot.Trim()
$privateRoot = Find-OpsRepository -CodeRoot $codeRoot
$privateRoot = (Resolve-Path -LiteralPath $privateRoot).Path

$expectedOrigin = 'github.com/zixuntonytan-new/hutchins-agent-ops'
$privateOrigin = Invoke-CheckedGit -Repository $privateRoot -Arguments @('remote', 'get-url', 'origin')
if ($privateOrigin -notmatch $expectedOrigin) {
    throw "Private operations origin is unexpected: $privateOrigin"
}

$privateBranch = Invoke-CheckedGit -Repository $privateRoot -Arguments @('branch', '--show-current')
if ($privateBranch -ne 'main') {
    throw "Private operations must be on main, found: $privateBranch"
}

$privateStatus = Invoke-CheckedGit -Repository $privateRoot -Arguments @('status', '--porcelain')
if ($privateStatus -and -not $AllowDirtyOps) {
    throw 'Private operations has uncommitted changes. Commit, stash deliberately, or resolve them before syncing shared FIM context.'
}

if (-not $NoPull) {
    Invoke-CheckedGit -Repository $privateRoot -Arguments @('fetch', 'origin') | Out-Null
    $localHead = Invoke-CheckedGit -Repository $privateRoot -Arguments @('rev-parse', 'HEAD')
    $remoteHead = Invoke-CheckedGit -Repository $privateRoot -Arguments @('rev-parse', 'origin/main')
    $mergeBase = Invoke-CheckedGit -Repository $privateRoot -Arguments @('merge-base', 'HEAD', 'origin/main')
    if ($localHead -ne $mergeBase) {
        throw 'Private operations has local commits or diverged history. Resolve this through Git before a shared FIM session.'
    }
    if ($localHead -ne $remoteHead) {
        Invoke-CheckedGit -Repository $privateRoot -Arguments @('merge', '--ff-only', 'origin/main') | Out-Null
    }
}

$requiredPrivateFiles = @(
    'FIM\HANDOFF.md',
    'FIM\PROJECT_LOG.md',
    'FIM\OFFICIAL_UPDATE_LOG.md',
    'FIM\AGENT_OVERLAY.md',
    'FIM\WORKING_STYLE.md',
    'FIM\README.md',
    'skills\CATALOG.md'
)
foreach ($relativeFile in $requiredPrivateFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $privateRoot $relativeFile) -PathType Leaf)) {
        throw "Required private context file is missing: $relativeFile"
    }
}

$codeOrigin = Invoke-CheckedGit -Repository $codeRoot -Arguments @('remote', 'get-url', 'origin')
if ($codeOrigin -notmatch 'github.com/zixuntonytan-new/FIM') {
    throw "FIM origin is unexpected: $codeOrigin"
}

$upstreamPush = Invoke-CheckedGit -Repository $codeRoot -Arguments @('remote', 'get-url', '--push', 'upstream')
if ($upstreamPush -notmatch 'DISABLED') {
    throw "FIM upstream push URL is not disabled: $upstreamPush"
}

$codeBranch = Invoke-CheckedGit -Repository $codeRoot -Arguments @('branch', '--show-current')
$codeCommit = Invoke-CheckedGit -Repository $codeRoot -Arguments @('rev-parse', 'HEAD')
$privateCommit = Invoke-CheckedGit -Repository $privateRoot -Arguments @('rev-parse', 'HEAD')

Write-Host 'FIM private-context preflight passed.'
Write-Host "Public FIM: $codeBranch at $codeCommit"
Write-Host "Private context: main at $privateCommit"
Write-Host "Private root: $privateRoot"
Write-Host 'Read private FIM/AGENT_OVERLAY.md and FIM/WORKING_STYLE.md, then HANDOFF.md, recent PROJECT_LOG.md, the latest official-update event, and the task-routed reference before editing.'
