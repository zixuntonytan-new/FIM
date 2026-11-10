#requires -Version 5.1
<#
Checks this computer against live Git refs. Does not fetch, merge, reset, push,
run FIM, open Excel, or load research data. Reports stay outside both repositories.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$FimPath,
    [string]$OpsPath = $env:HUTCHINS_AGENT_OPS,
    [string]$ReportDirectory = (Join-Path ([IO.Path]::GetTempPath()) 'FIM-workstation-checks'),
    [string]$ExpectedOrigin = 'https://github.com/zixuntonytan-new/FIM.git',
    [string]$ExpectedUpstream = 'https://github.com/Hutchins-RAs/FIM.git',
    [string]$ExpectedOpsOrigin = 'https://github.com/zixuntonytan-new/hutchins-agent-ops.git',
    [ValidateRange(1, 120)][int]$TimeoutSeconds = 30
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$checks = [Collections.Generic.List[object]]::new()
$identities = [ordered]@{}
$started = [DateTime]::UtcNow.ToString('o')
$gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $gitCommand) { throw 'Git is not installed or is not on PATH. No check was completed.' }

function Add-Check {
    param([string]$Name, [string]$Status, [string]$Detail)
    $checks.Add([pscustomobject]@{ name = $Name; status = $Status; detail = $Detail })
}

function Quote-NativeArgument {
    param([string]$Value)
    # Windows native argument quoting, including trailing backslashes and quotes.
    return '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}

function Invoke-GitRead {
    param([string]$Repository, [string[]]$Arguments)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $gitCommand.Source
    $allArguments = @('--no-optional-locks', '-c', 'credential.interactive=never', '-C', $Repository) + $Arguments
    $start.Arguments = (($allArguments | ForEach-Object { Quote-NativeArgument $_ }) -join ' ')
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
    $start.EnvironmentVariables['GIT_NO_LAZY_FETCH'] = '1'
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            throw "Git timed out after $TimeoutSeconds seconds. Freshness is unverified."
        }
        $output = $stdout.GetAwaiter().GetResult().Trim()
        $null = $stderr.GetAwaiter().GetResult()
        return [pscustomobject]@{ Code = $process.ExitCode; Text = $output }
    }
    finally { $process.Dispose() }
}

function Read-Git {
    param([string]$Repository, [string[]]$Arguments)
    $result = Invoke-GitRead $Repository $Arguments
    if ($result.Code -ne 0) { throw "Git $($Arguments[0]) failed (exit $($result.Code))." }
    return $result.Text
}

function Normalize-Remote {
    param([string]$Value)
    return (($Value.Trim() -replace '^git@github\.com:', 'https://github.com/') -replace '\.git/?$', '').TrimEnd('/').ToLowerInvariant()
}

function Check-Remote {
    param([string]$Repository, [string]$Remote, [string]$Expected, [string]$Label)
    $actual = Read-Git $Repository @('remote', 'get-url', $Remote)
    if ((Normalize-Remote $actual) -ne (Normalize-Remote $Expected)) {
        Add-Check $Label 'FAIL' 'Remote identity differs from the configured expected repository. No contact attempted.'
        return $false
    }
    Add-Check $Label 'PASS' 'Remote identity matches the configured expected repository.'
    return $true
}

function Read-LiveTip {
    param([string]$Repository, [string]$Remote, [string]$Ref)
    $result = Invoke-GitRead $Repository @('ls-remote', '--exit-code', $Remote, $Ref)
    if ($result.Code -ne 0) { throw "Cannot read live $Remote $Ref (exit $($result.Code)); check network, sign-in and ref existence." }
    $rows = @($result.Text -split '\r?\n' | Where-Object { ($_ -split '\s+')[1] -eq $Ref })
    if ($rows.Count -ne 1 -or $rows[0] -notmatch '^([0-9a-f]{40,64})\s') { throw 'Live ref response was missing or ambiguous.' }
    return $Matches[1]
}

function Check-ContainsTip {
    param([string]$Repository, [string]$Tip, [string]$Label)
    $exists = Invoke-GitRead $Repository @('cat-file', '-e', "$Tip^{commit}")
    if ($exists.Code -ne 0) {
        Add-Check $Label 'UNVERIFIED' "Live tip $Tip is absent locally. Fetch that remote deliberately, then rerun; do not merge the workbook automatically."
        return
    }
    $ancestor = Invoke-GitRead $Repository @('merge-base', '--is-ancestor', $Tip, 'HEAD')
    if ($ancestor.Code -eq 0) {
        Add-Check $Label 'PASS' "Local HEAD contains the live tip $Tip."
    }
    elseif ($ancestor.Code -eq 1) {
        Add-Check $Label 'FAIL' "Local HEAD does not contain live tip $Tip. Review and integrate the missing version deliberately."
    }
    else { Add-Check $Label 'UNVERIFIED' 'Git could not establish ancestry; no up-to-date claim is possible.' }
}

function Read-Repository {
    param([string]$Path, [string]$Label)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Container)) { throw "$Label folder was not found." }
    $root = Read-Git $Path @('rev-parse', '--show-toplevel')
    $head = Read-Git $root @('rev-parse', 'HEAD')
    $branch = Read-Git $root @('branch', '--show-current')
    $dirty = Read-Git $root @('status', '--porcelain', '--untracked-files=normal')
    $identities[$Label] = [ordered]@{ path = $root; head = $head; branch = $branch }
    if ($dirty) { Add-Check "$Label clean checkout" 'FAIL' 'Uncommitted or untracked work exists. Preserve it; do not reset or overwrite it.' }
    else { Add-Check "$Label clean checkout" 'PASS' 'No uncommitted or untracked files.' }
    return [pscustomobject]@{ Root = $root; Head = $head; Branch = $branch }
}

try {
    $fim = Read-Repository $FimPath 'FIM'
    $allowed = $fim.Branch -eq 'workflow/shared-context' -or $fim.Branch -match '^(codex|claude)/(personal|work)/[^/]+$|^integration/[^/]+$|^release/\d{4}-\d{2}-\d{2}-[^/]+$'
    if ($allowed) { Add-Check 'FIM branch' 'PASS' "Branch: $($fim.Branch)" }
    else { Add-Check 'FIM branch' 'FAIL' 'Detached HEAD or an unsupported/legacy branch. Use the agreed canonical or task checkout.' }
    if (Check-Remote $fim.Root 'origin' $ExpectedOrigin 'FIM fork identity') {
        try {
            $shared = Read-LiveTip $fim.Root 'origin' 'refs/heads/workflow/shared-context'
            $identities['live_shared_tip'] = $shared
            Check-ContainsTip $fim.Root $shared 'Shared FIM version'
        } catch { Add-Check 'Shared FIM version' 'UNVERIFIED' $_.Exception.Message }
        if ($fim.Branch) {
            try {
                $branchTip = Read-LiveTip $fim.Root 'origin' "refs/heads/$($fim.Branch)"
                $identities['live_branch_tip'] = $branchTip
                if ($fim.Head -eq $branchTip) { Add-Check 'Current branch sync' 'PASS' 'Local HEAD exactly matches the live fork branch.' }
                else { Add-Check 'Current branch sync' 'FAIL' "Local HEAD and live fork branch $branchTip differ. Review ahead/behind/diverged history." }
            } catch { Add-Check 'Current branch sync' 'UNVERIFIED' $_.Exception.Message }
        }
    }
    if (Check-Remote $fim.Root 'upstream' $ExpectedUpstream 'Official source identity') {
        $pushUrls = Read-Git $fim.Root @('remote', 'get-url', '--push', '--all', 'upstream')
        if ($pushUrls -ceq 'DISABLED') { Add-Check 'Official push protection' 'PASS' 'Upstream has exactly one push URL: DISABLED.' }
        else { Add-Check 'Official push protection' 'FAIL' 'Upstream push is not fully disabled.' }
        try {
            $official = Read-LiveTip $fim.Root 'upstream' 'refs/heads/refactor/clean-data-pipeline'
            $identities['live_official_tip'] = $official
            Check-ContainsTip $fim.Root $official 'Official FIM version'
        } catch { Add-Check 'Official FIM version' 'UNVERIFIED' $_.Exception.Message }
    }
} catch { Add-Check 'FIM inspection' 'UNVERIFIED' $_.Exception.Message }

try {
    if (-not $OpsPath) {
        $OpsPath = Join-Path (Split-Path ([IO.Path]::GetFullPath($FimPath)) -Parent) 'hutchins-agent-ops'
    }
    $ops = Read-Repository $OpsPath 'Private context'
    if ($ops.Branch -eq 'main') { Add-Check 'Private context branch' 'PASS' 'Private context is on main.' }
    else { Add-Check 'Private context branch' 'FAIL' 'Private context must be on main for startup.' }
    if (Check-Remote $ops.Root 'origin' $ExpectedOpsOrigin 'Private context identity') {
        try {
            $privateTip = Read-LiveTip $ops.Root 'origin' 'refs/heads/main'
            $identities['live_private_tip'] = $privateTip
            if ($ops.Head -eq $privateTip) { Add-Check 'Private context version' 'PASS' 'Local private context exactly matches live main.' }
            else { Add-Check 'Private context version' 'FAIL' "Local private context differs from live main $privateTip." }
        } catch { Add-Check 'Private context version' 'UNVERIFIED' $_.Exception.Message }
    }
    $required = @('FIM/HANDOFF.md', 'FIM/PROJECT_LOG.md', 'FIM/OFFICIAL_UPDATE_LOG.md', 'FIM/AGENT_OVERLAY.md',
        'FIM/WORKING_STYLE.md', 'FIM/README.md', 'governance/HUTCHINS_AGENT_BYLAW.md', 'skills/CATALOG.md')
    $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ops.Root $_) -PathType Leaf) })
    if ($missing.Count) { Add-Check 'Private startup records' 'FAIL' ("Missing: " + ($missing -join ', ')) }
    else { Add-Check 'Private startup records' 'PASS' 'Required startup records exist; their content was not opened.' }
} catch { Add-Check 'Private context inspection' 'UNVERIFIED' $_.Exception.Message }

# Do not write a report inside a checkout: that would dirty the state just checked.
$reportRoot = [IO.Path]::GetFullPath($ReportDirectory).TrimEnd('\', '/')
foreach ($identity in @($identities.Values)) {
    if ($identity -is [Collections.IDictionary] -and $identity.Contains('path')) {
        $repoRoot = [IO.Path]::GetFullPath($identity['path']).TrimEnd('\', '/')
        if ($reportRoot.Equals($repoRoot, [StringComparison]::OrdinalIgnoreCase) -or
            $reportRoot.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Reports must be outside both repositories. Rerun with an external ReportDirectory.'
        }
    }
}
$null = New-Item -ItemType Directory -Path $reportRoot -Force
$stem = 'fim-check-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$jsonPath = Join-Path $reportRoot ($stem + '.json')
$textPath = Join-Path $reportRoot ($stem + '.txt')
$failed = @($checks | Where-Object { $_.status -eq 'FAIL' }).Count
$unknown = @($checks | Where-Object { $_.status -eq 'UNVERIFIED' }).Count
$overall = if ($failed) { 'NEEDS_ATTENTION' } elseif ($unknown) { 'UNVERIFIED' } else { 'PASS' }
$report = [ordered]@{
    schema_version = 1; check = 'FIM workstation version check'; status = $overall
    computer = [Environment]::MachineName; started_utc = $started; finished_utc = [DateTime]::UtcNow.ToString('o')
    scope = 'Live Git version and startup-file checks only. R, Haver, Excel, workbook validity, transfer-receipt agreement and FIM outputs are NOT tested.'
    expected_repositories = @{ fork = $ExpectedOrigin; official = $ExpectedUpstream; private_context = $ExpectedOpsOrigin }
    identities = $identities; checks = @($checks.ToArray())
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$lines = @("FIM VERSION CHECK: $overall", "Computer: $($report.computer)", "Checked: $($report.finished_utc)", '', $report.scope, '')
$lines += @($checks | ForEach-Object { "[$($_.status)] $($_.name): $($_.detail)" })
$lines += @('', 'Keep these reports private; they contain local paths and private repository identifiers.', "JSON report: $jsonPath")
$lines | Set-Content -LiteralPath $textPath -Encoding UTF8
$lines | ForEach-Object { Write-Host $_ }
Write-Host "Readable report: $textPath"
Write-Output "FIM_CHECK_REPORT:$jsonPath"
if ($failed) { exit 1 }
if ($unknown) { exit 2 }
exit 0
