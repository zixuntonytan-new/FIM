#requires -Version 5.1
[CmdletBinding()]
param([string]$ResultPath = (Join-Path ([IO.Path]::GetTempPath()) 'fim-checker-tests.json'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$checker = Join-Path $repoRoot 'scripts/Test-FIMWorkstation.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('FIM checker tests ' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testRoot
$hostExe = (Get-Process -Id $PID).Path
$results = [Collections.Generic.List[object]]::new()

function Git {
    param([string]$Path, [string[]]$Arguments)
    $prior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & git.exe -C $Path @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prior }
    if ($code -ne 0) { throw "Fixture git failed: $($Arguments -join ' '): $output" }
    return (($output | ForEach-Object { "$_" }) -join [Environment]::NewLine).Trim()
}
function Commit-File {
    param([string]$Path, [string]$File, [string]$Content)
    $target = Join-Path $Path $File
    $null = New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force
    Set-Content -LiteralPath $target -Value $Content -Encoding UTF8
    $null = Git $Path @('add', '--', $File)
    $null = Git $Path @('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-m', 'fixture')
}
function New-Fixture {
    param([string]$Name)
    $root = Join-Path $testRoot $Name
    $null = New-Item -ItemType Directory -Path $root
    $fim = Join-Path $root 'FIM with spaces'
    $ops = Join-Path $root 'private context'
    $origin = Join-Path $root 'fork.git'
    $official = Join-Path $root 'official.git'
    $private = Join-Path $root 'private.git'
    $null = Git $root @('init', '-b', 'workflow/shared-context', $fim)
    Commit-File $fim 'source.txt' 'baseline'
    $null = Git $root @('clone', '--bare', $fim, $origin)
    $null = Git $root @('clone', '--bare', $fim, $official)
    $head = Git $fim @('rev-parse', 'HEAD')
    $null = Git $official @('update-ref', 'refs/heads/refactor/clean-data-pipeline', $head)
    $null = Git $fim @('remote', 'add', 'origin', $origin)
    $null = Git $fim @('remote', 'add', 'upstream', $official)
    $null = Git $fim @('remote', 'set-url', '--push', 'upstream', 'DISABLED')
    $null = Git $root @('init', '-b', 'main', $ops)
    foreach ($file in @('FIM/HANDOFF.md', 'FIM/PROJECT_LOG.md', 'FIM/OFFICIAL_UPDATE_LOG.md',
        'FIM/AGENT_OVERLAY.md', 'FIM/WORKING_STYLE.md', 'FIM/README.md',
        'governance/HUTCHINS_AGENT_BYLAW.md', 'skills/CATALOG.md')) {
        $target = Join-Path $ops $file
        $null = New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force
        Set-Content -LiteralPath $target -Value 'fixture'
    }
    $null = Git $ops @('add', '.')
    $null = Git $ops @('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-m', 'context')
    $null = Git $root @('clone', '--bare', $ops, $private)
    $null = Git $ops @('remote', 'add', 'origin', $private)
    return @{ Root = $root; Fim = $fim; Ops = $ops; Origin = $origin; Official = $official; Private = $private }
}
function Snapshot {
    param([hashtable]$Fixture)
    $parts = foreach ($path in @($Fixture.Fim, $Fixture.Ops)) {
        Git $path @('status', '--porcelain')
        Git $path @('show-ref')
        Git $path @('rev-parse', 'HEAD')
        Git $path @('config', '--local', '--list')
    }
    return ($parts -join '|')
}
function Run-Checker {
    param([hashtable]$Fixture, [int]$ExitCode, [string]$Status, [string]$Check, [string]$CheckStatus)
    $before = Snapshot $Fixture
    $output = & $hostExe -NoProfile -NonInteractive -File $checker -FimPath $Fixture.Fim -OpsPath $Fixture.Ops -ReportDirectory (Join-Path $Fixture.Root 'reports') -ExpectedOrigin $Fixture.Origin -ExpectedUpstream $Fixture.Official -ExpectedOpsOrigin $Fixture.Private
    $actualExit = $LASTEXITCODE
    if ($actualExit -ne $ExitCode) { throw "Expected exit $ExitCode, found $actualExit. $output" }
    $reportLine = @($output | Where-Object { "$_" -like 'FIM_CHECK_REPORT:*' })
    if ($reportLine.Count -ne 1) { throw 'Expected exactly one report.' }
    $report = Get-Content -LiteralPath ($reportLine[0].Substring('FIM_CHECK_REPORT:'.Length)) -Raw | ConvertFrom-Json
    if ($report.status -ne $Status) { throw "Expected $Status, got $($report.status)." }
    if ($Check) {
        $match = @($report.checks | Where-Object { $_.name -eq $Check -and $_.status -eq $CheckStatus })
        if ($match.Count -ne 1) { throw "Expected $Check => $CheckStatus." }
    }
    if ((Snapshot $Fixture) -cne $before) { throw 'Checker changed repository status, refs, HEAD or local configuration.' }
}
function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        $results.Add(@{ name = $Name; passed = $true; detail = 'Expected result and unchanged repositories verified.' })
        Write-Host "PASS: $Name"
    } catch {
        $results.Add(@{ name = $Name; passed = $false; detail = $_.Exception.Message })
        Write-Host "FAIL: $Name : $($_.Exception.Message)"
    }
}

Test-Case 'Clean live refs pass, including paths with spaces' {
    $f = New-Fixture 'clean'
    Run-Checker $f 0 'PASS' 'Official FIM version' 'PASS'
}
Test-Case 'Dirty checkout cannot pass' {
    $f = New-Fixture 'dirty'
    Set-Content -LiteralPath (Join-Path $f.Fim 'unfinished.txt') -Value 'preserve this'
    Run-Checker $f 1 'NEEDS_ATTENTION' 'FIM clean checkout' 'FAIL'
}
Test-Case 'Fresh remote advance beats stale remote-tracking refs' {
    $f = New-Fixture 'stale'
    $null = Git $f.Fim @('fetch', 'origin')
    $writer = Join-Path $f.Root 'writer'
    $null = Git $f.Root @('clone', $f.Origin, $writer)
    Commit-File $writer 'new.txt' 'new shared version'
    $null = Git $writer @('push', 'origin', 'HEAD')
    Run-Checker $f 1 'NEEDS_ATTENTION' 'Shared FIM version' 'UNVERIFIED'
    $null = Git $f.Fim @('fetch', 'origin')
    Run-Checker $f 1 'NEEDS_ATTENTION' 'Shared FIM version' 'FAIL'
}
Test-Case 'Unpublished local commit cannot pass branch sync' {
    $f = New-Fixture 'ahead'
    Commit-File $f.Fim 'new.txt' 'local only'
    Run-Checker $f 1 'NEEDS_ATTENTION' 'Current branch sync' 'FAIL'
}
Test-Case 'Fork can match while official source is newer' {
    $f = New-Fixture 'official-newer'
    $writer = Join-Path $f.Root 'writer'
    $null = Git $f.Root @('clone', '-b', 'refactor/clean-data-pipeline', $f.Official, $writer)
    Commit-File $writer 'official.txt' 'new official version'
    $null = Git $writer @('push', 'origin', 'HEAD')
    Run-Checker $f 2 'UNVERIFIED' 'Official FIM version' 'UNVERIFIED'
    $null = Git $f.Fim @('fetch', 'upstream')
    Run-Checker $f 1 'NEEDS_ATTENTION' 'Official FIM version' 'FAIL'
}
Test-Case 'Unavailable remote produces UNVERIFIED, never PASS' {
    $f = New-Fixture 'offline'
    $f.Origin = Join-Path $f.Root 'not-accessible.git'
    $null = Git $f.Fim @('remote', 'set-url', 'origin', $f.Origin)
    Run-Checker $f 2 'UNVERIFIED' 'Shared FIM version' 'UNVERIFIED'
}
Test-Case 'Unexpected remote fails identity' {
    $f = New-Fixture 'identity'
    $null = Git $f.Fim @('remote', 'set-url', 'origin', (Join-Path $f.Root 'wrong.git'))
    Run-Checker $f 1 'NEEDS_ATTENTION' 'FIM fork identity' 'FAIL'
}
Test-Case 'Private context behind live main fails' {
    $f = New-Fixture 'private-stale'
    $writer = Join-Path $f.Root 'writer'
    $null = Git $f.Root @('clone', $f.Private, $writer)
    Commit-File $writer 'FIM/HANDOFF.md' 'new context'
    $null = Git $writer @('push', 'origin', 'HEAD')
    Run-Checker $f 1 'NEEDS_ATTENTION' 'Private context version' 'FAIL'
}
Test-Case 'Missing startup records fail' {
    $f = New-Fixture 'missing'
    Remove-Item -LiteralPath (Join-Path $f.Ops 'FIM/HANDOFF.md')
    Run-Checker $f 1 'NEEDS_ATTENTION' 'Private startup records' 'FAIL'
}
Test-Case 'An additional upstream push URL cannot hide behind DISABLED' {
    $f = New-Fixture 'push-url'
    $null = Git $f.Fim @('remote', 'set-url', '--add', '--push', 'upstream', $f.Official)
    Run-Checker $f 1 'NEEDS_ATTENTION' 'Official push protection' 'FAIL'
}
Test-Case 'Detached checkout cannot pass' {
    $f = New-Fixture 'detached'
    $null = Git $f.Fim @('checkout', '--detach')
    Run-Checker $f 1 'NEEDS_ATTENTION' 'FIM branch' 'FAIL'
}

$failures = @($results | Where-Object { -not $_.passed }).Count
$report = @{
    schema_version = 1; kind = 'tests'; status = $(if ($failures) { 'failed' } else { 'passed' })
    checks = @($results.ToArray()); scope = 'Disposable local Git fixtures; not a work-laptop or R/Haver test.'
    powershell = $PSVersionTable.PSVersion.ToString(); fixtures = $testRoot
    artifacts = @(@{ path = $checker; sha256 = (Get-FileHash -LiteralPath $checker -Algorithm SHA256).Hash.ToLowerInvariant() },
        @{ path = $PSCommandPath; sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant() })
}
$report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
Write-Host "HUTCHINS_RESULT:$([IO.Path]::GetFullPath($ResultPath))"
if ($failures) { exit 1 }
exit 0
