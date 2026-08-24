[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$checker = Join-Path $repositoryRoot 'scripts/Test-HutchinsPolicy.ps1'
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("hutchins-policy-test-" + [guid]::NewGuid())
$policyShells = @(
    [pscustomobject]@{
        Name = 'current PowerShell'
        Path = (Get-Process -Id $PID).Path
    }
)
$windowsPowerShell = $null
if (-not [string]::IsNullOrWhiteSpace($env:SystemRoot)) {
    $candidate = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if ((Test-Path -LiteralPath $candidate) -and -not ($policyShells.Path -contains $candidate)) {
        $windowsPowerShell = $candidate
        $policyShells += [pscustomobject]@{
            Name = 'Windows PowerShell 5.1'
            Path = $windowsPowerShell
        }
    }
}

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message Expected $Expected; received $Actual."
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Expected,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Text.Contains($Expected)) {
        throw "$Message Expected output to contain '$Expected'. Actual output: $Text"
    }
}

function Write-Lines {
    param([string]$Path, [int]$Count)

    $parent = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    [System.IO.File]::WriteAllLines($Path, [string[]](1..$Count | ForEach-Object { "line $_" }))
}

function New-FixtureRepository {
    param([int]$LegacyLines = 1)

    $path = Join-Path $temporaryRoot ([guid]::NewGuid().ToString())
    [System.IO.Directory]::CreateDirectory($path) | Out-Null
    & git -C $path init --quiet --initial-branch=main
    & git -C $path config user.email 'policy-test@example.invalid'
    & git -C $path config user.name 'Policy test'
    [System.IO.Directory]::CreateDirectory((Join-Path $path 'governance')) | Out-Null
    $config = [ordered]@{
        defaultBaseRef = 'main'
        sourceExtensions = @('.py')
        sourceRoots = @('src', '.hidden-src')
        includeRootFiles = $true
        excludedPathPrefixes = @('archive/')
        testFilePatterns = @('^tests/test_.*\.py$')
        waiverPathPrefix = 'governance/test-waivers/'
        maxWaiverDays = 30
        warningLines = 500
        maximumLines = 1000
    }
    $config | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $path 'governance/policy-config.json') -NoNewline
    Write-Lines -Path (Join-Path $path 'src/legacy.py') -Count $LegacyLines
    [System.IO.Directory]::CreateDirectory((Join-Path $path 'tests')) | Out-Null
    Set-Content -LiteralPath (Join-Path $path 'tests/keep.txt') -Value 'baseline'
    & git -C $path add .
    & git -C $path commit --quiet -m 'baseline'
    return $path
}

function Add-TestEvidence {
    param([string]$Repository)

    Set-Content -LiteralPath (Join-Path $Repository 'tests/test_policy.py') -Value 'def test_policy(): pass'
}

function Add-NonTestNote {
    param([string]$Repository)

    Set-Content -LiteralPath (Join-Path $Repository 'tests/notes.txt') -Value 'TODO: write a test someday'
}

function Add-Waiver {
    param(
        [string]$Repository,
        [string]$Expiry,
        [string]$AffectedFiles = 'src/legacy.py'
    )

    $directory = Join-Path $Repository 'governance/test-waivers'
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    @(
        '# Test waiver: fixture'
        ''
        "- Affected files: $AffectedFiles"
        '- Reason: fixture purpose'
        '- Compensating evidence: policy checker fixture'
        '- Owner: test suite'
        '- Approval: fixture user approval'
        "- Expires: $Expiry"
    ) | Set-Content -LiteralPath (Join-Path $directory 'fixture.md')
}

function Add-IncompleteWaiver {
    param([string]$Repository)

    $directory = Join-Path $Repository 'governance/test-waivers'
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    @(
        '# Test waiver: incomplete fixture'
        ''
        '- Reason: fixture purpose'
    ) | Set-Content -LiteralPath (Join-Path $directory 'fixture.md')
}

function Invoke-FixtureCheck {
    param(
        [string]$Repository,
        [Parameter(Mandatory = $true)][pscustomobject]$PolicyShell
    )

    Push-Location $Repository
    try {
        $previousErrorActionPreference = $ErrorActionPreference
        $exitCode = 1
        try {
            $ErrorActionPreference = 'Continue'
            $output = & $PolicyShell.Path -NoProfile -File $checker -BaseRef main *>&1
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        return [pscustomobject]@{
            ExitCode = $exitCode
            Output = ($output | Out-String)
        }
    }
    finally {
        Pop-Location
    }
}

function Assert-FixtureExit {
    param(
        [string]$Repository,
        [int]$Expected,
        [string]$Message
    )

    foreach ($policyShell in $policyShells) {
        $result = Invoke-FixtureCheck -Repository $Repository -PolicyShell $policyShell
        Assert-Equal -Actual $result.ExitCode -Expected $Expected -Message "$Message ($($policyShell.Name))."
    }
}

function Assert-FixtureFailureMessages {
    param(
        [string]$Repository,
        [string[]]$ExpectedMessages
    )

    foreach ($policyShell in $policyShells) {
        $result = Invoke-FixtureCheck -Repository $Repository -PolicyShell $policyShell
        Assert-Equal -Actual $result.ExitCode -Expected 1 -Message "Multiple policy failures should fail ($($policyShell.Name))."
        foreach ($message in $ExpectedMessages) {
            Assert-Contains -Text $result.Output -Expected $message -Message "Multiple failures should all be reported ($($policyShell.Name))."
        }
    }
}

try {
    $repository = New-FixtureRepository
    Write-Lines -Path (Join-Path $repository 'src/new.py') -Count 500
    Add-TestEvidence -Repository $repository
    Assert-FixtureExit -Repository $repository -Expected 0 -Message 'A 500-line file should pass without a size warning'
    Write-Lines -Path (Join-Path $repository 'src/new.py') -Count 501
    Assert-FixtureExit -Repository $repository -Expected 0 -Message 'A 501-line file should warn but pass'

    $repository = New-FixtureRepository
    Write-Lines -Path (Join-Path $repository 'src/new.py') -Count 1000
    Add-TestEvidence -Repository $repository
    Assert-FixtureExit -Repository $repository -Expected 0 -Message 'A 1,000-line new file should pass'

    $repository = New-FixtureRepository
    Write-Lines -Path (Join-Path $repository 'src/new.py') -Count 1001
    Add-TestEvidence -Repository $repository
    Assert-FixtureExit -Repository $repository -Expected 1 -Message 'A 1,001-line new file should fail'

    $repository = New-FixtureRepository -LegacyLines 1001
    Write-Lines -Path (Join-Path $repository 'src/legacy.py') -Count 1002
    Add-TestEvidence -Repository $repository
    Assert-FixtureExit -Repository $repository -Expected 1 -Message 'A legacy oversized file must not grow'

    $repository = New-FixtureRepository -LegacyLines 1001
    Write-Lines -Path (Join-Path $repository 'src/legacy.py') -Count 1000
    Add-TestEvidence -Repository $repository
    Assert-FixtureExit -Repository $repository -Expected 0 -Message 'A shrinking legacy oversized file should pass'

    $repository = New-FixtureRepository
    Write-Lines -Path (Join-Path $repository 'analysis_tmp_root.py') -Count 1001
    Add-TestEvidence -Repository $repository
    Assert-FixtureExit -Repository $repository -Expected 1 -Message 'A root-level executable file should be checked'

    $repository = New-FixtureRepository
    Write-Lines -Path (Join-Path $repository '.hidden-src/example.py') -Count 1001
    Add-TestEvidence -Repository $repository
    Assert-FixtureExit -Repository $repository -Expected 1 -Message 'A dot-prefixed configured source root should be checked'

    $repository = New-FixtureRepository
    Write-Lines -Path (Join-Path $repository 'src/legacy.py') -Count 2
    Add-NonTestNote -Repository $repository
    Assert-FixtureExit -Repository $repository -Expected 1 -Message 'A non-test note must not count as test evidence'
    Add-IncompleteWaiver -Repository $repository
    Assert-FixtureExit -Repository $repository -Expected 1 -Message 'A waiver missing required fields should fail'
    Add-Waiver -Repository $repository -Expiry '2000-01-01'
    Assert-FixtureExit -Repository $repository -Expected 1 -Message 'An expired waiver should fail'
    $tooFarInFuture = (Get-Date).Date.AddDays(31).ToString('yyyy-MM-dd')
    Add-Waiver -Repository $repository -Expiry $tooFarInFuture
    Assert-FixtureExit -Repository $repository -Expected 1 -Message 'A waiver beyond the maximum duration should fail'
    $validExpiry = (Get-Date).Date.AddDays(30).ToString('yyyy-MM-dd')
    Add-Waiver -Repository $repository -Expiry $validExpiry -AffectedFiles 'src/some_other_file.py'
    Assert-FixtureExit -Repository $repository -Expected 1 -Message 'A waiver for an unrelated file should fail'
    Add-Waiver -Repository $repository -Expiry $validExpiry -AffectedFiles 'src/legacy.py'
    Assert-FixtureExit -Repository $repository -Expected 0 -Message 'A matching, time-limited waiver should pass'

    $repository = New-FixtureRepository
    Write-Lines -Path (Join-Path $repository 'archive/external.py') -Count 1001
    Assert-FixtureExit -Repository $repository -Expected 0 -Message 'Excluded external material should pass'

    $repository = New-FixtureRepository -LegacyLines 1001
    & git -C $repository mv 'src/legacy.py' 'src/legacy_renamed.py'
    Add-TestEvidence -Repository $repository
    Assert-FixtureExit -Repository $repository -Expected 0 -Message 'Renaming an unchanged legacy oversized file should pass'

    $repository = New-FixtureRepository
    Write-Lines -Path (Join-Path $repository 'src/first.py') -Count 1001
    Write-Lines -Path (Join-Path $repository 'src/second.py') -Count 1001
    Assert-FixtureFailureMessages -Repository $repository -ExpectedMessages @(
        'src/first.py has 1001 lines',
        'src/second.py has 1001 lines',
        'Executable source changed without a matching test change'
    )

    Write-Host "Hutchins policy checker tests passed in $($policyShells.Name -join ' and ')."
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
