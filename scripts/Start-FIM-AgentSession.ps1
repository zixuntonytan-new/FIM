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

function Test-BranchName {
    param([Parameter(Mandatory = $true)][string]$Branch)

    return $Branch -eq 'workflow/shared-context' -or
        $Branch -match '^(codex|claude)/(personal|work)/[^/]+$' -or
        $Branch -match '^integration/[^/]+$' -or
        $Branch -match '^release/\d{4}-\d{2}-\d{2}-[^/]+$'
}

$scriptDirectory = Split-Path -Path $PSCommandPath -Parent
$candidateCodeRoot = Split-Path -Path $scriptDirectory -Parent
$codeRoot = Invoke-CheckedGit -Repository $candidateCodeRoot -Arguments @('rev-parse', '--show-toplevel')
$codeRoot = $codeRoot.Trim()

if ((Split-Path -Path $codeRoot -Leaf) -eq 'Sarah_Chase_FIM') {
    throw 'Sarah_Chase_FIM is legacy reference and Git storage during activation, not a valid FIM task location. Start from a clean FIM-next checkout.'
}

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
    'governance\HUTCHINS_AGENT_BYLAW.md',
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

if (-not $NoPull) {
    Invoke-CheckedGit -Repository $codeRoot -Arguments @('fetch', 'origin') | Out-Null
}

$codeBranch = Invoke-CheckedGit -Repository $codeRoot -Arguments @('branch', '--show-current')
if (-not (Test-BranchName -Branch $codeBranch)) {
    throw "FIM branch '$codeBranch' is not an approved canonical, task, integration, or release branch."
}

$codeCommit = Invoke-CheckedGit -Repository $codeRoot -Arguments @('rev-parse', 'HEAD')
$sharedRef = 'origin/workflow/shared-context'
$sharedCommit = Invoke-CheckedGit -Repository $codeRoot -Arguments @('rev-parse', $sharedRef)
$codeStatus = Invoke-CheckedGit -Repository $codeRoot -Arguments @('status', '--porcelain')

if ($codeBranch -eq 'workflow/shared-context') {
    if ($codeStatus) {
        throw 'The canonical workflow checkout must be clean. Create an owned task worktree before editing.'
    }
    if ($codeCommit -ne $sharedCommit) {
        throw 'The canonical workflow checkout is not at the current origin/workflow/shared-context commit. Fast-forward it before beginning a task.'
    }
}
else {
    $priorErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & git -c "safe.directory=$codeRoot" -C $codeRoot merge-base --is-ancestor $sharedRef HEAD 2>$null
        $isCurrentSharedAncestor = $LASTEXITCODE -eq 0
    }
    finally {
        $ErrorActionPreference = $priorErrorAction
    }
    if (-not $isCurrentSharedAncestor) {
        throw "Task branch '$codeBranch' does not descend from current $sharedRef. Rebase or merge the shared branch deliberately before continuing."
    }
    if ($codeBranch -match '^release/' -and $codeStatus) {
        throw 'A release candidate must be clean before preflight can pass.'
    }
    if ($codeStatus) {
        Write-Warning 'This task worktree has an intended diff. Run the policy checker before review; do not treat this preflight as a clean transfer receipt.'
    }
}

$privateCommit = Invoke-CheckedGit -Repository $privateRoot -Arguments @('rev-parse', 'HEAD')

Write-Host 'FIM private-context preflight passed.'
Write-Host "Public FIM: $codeBranch at $codeCommit"
Write-Host "Shared base: $sharedCommit"
Write-Host "Private context: main at $privateCommit"
Write-Host "Private root: $privateRoot"
Write-Host 'Read private FIM/AGENT_OVERLAY.md and FIM/WORKING_STYLE.md, then HANDOFF.md, recent PROJECT_LOG.md, the latest official-update event, and the task-routed reference before editing.'
