[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExpectedBranch,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedRef,

    [string]$ExpectedOrigin = "https://github.com/zixuntonytan-new/FIM.git",

    [switch]$RequireClean,

    [switch]$RequireRscript,

    [switch]$RequireNonSyncPath
)

$ErrorActionPreference = "Stop"

function Invoke-GitText {
    param([string[]]$Arguments)

    $result = & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed."
    }

    return ($result | Out-String).Trim()
}

$problems = [System.Collections.Generic.List[string]]::new()

try {
    $repoRoot = Invoke-GitText -Arguments @("rev-parse", "--show-toplevel")
} catch {
    Write-Error "This command must run from inside a valid FIM Git clone. $($_.Exception.Message)"
    exit 2
}

$branch = Invoke-GitText -Arguments @("branch", "--show-current")
$head = Invoke-GitText -Arguments @("rev-parse", "HEAD")
$expectedCommit = Invoke-GitText -Arguments @("rev-parse", "$ExpectedRef^{commit}")
$origin = Invoke-GitText -Arguments @("remote", "get-url", "origin")
$status = Invoke-GitText -Arguments @("status", "--porcelain")

if ($branch -ne $ExpectedBranch) {
    $problems.Add("Current branch is '$branch', not expected '$ExpectedBranch'.")
}

if ($head -ne $expectedCommit) {
    $problems.Add("HEAD $head does not match $ExpectedRef ($expectedCommit).")
}

if ($origin -ne $ExpectedOrigin) {
    $problems.Add("origin is '$origin', not expected '$ExpectedOrigin'.")
}

if ($RequireClean -and $status) {
    $problems.Add("Working tree is not clean. Commit, stash, or deliberately resolve it before the transfer run.")
}

$rscript = Get-Command Rscript -ErrorAction SilentlyContinue
if ($RequireRscript -and -not $rscript) {
    $problems.Add("Rscript is not available on PATH, but this transfer requires an R-capable workstation.")
}

$usesSyncPath = $repoRoot -match "(?i)[\\/]OneDrive([\\/]|- )"
if ($usesSyncPath) {
    $message = "Repository path appears to be OneDrive-synced: $repoRoot. R cache/output writes can be interrupted by file locking."
    if ($RequireNonSyncPath) {
        $problems.Add($message)
    } else {
        Write-Warning $message
    }
}

Write-Host "Repository: $repoRoot"
Write-Host "Branch:     $branch"
Write-Host "HEAD:       $head"
Write-Host "Transfer:   $ExpectedRef -> $expectedCommit"
Write-Host "Origin:     $origin"
if ($rscript) {
    Write-Host "Rscript:    $($rscript.Source)"
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Preflight passed. The receiving laptop has the expected branch, exact transfer ref, and required local prerequisites."
