[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$checker = Join-Path (Split-Path -Parent $PSScriptRoot) '..\scripts\Test-HutchinsPolicy.ps1'
$shell = (Get-Process -Id $PID).Path
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("hutchins-policy-test-" + [guid]::NewGuid())

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
    @'
{
  "defaultBaseRef": "main",
  "sourceExtensions": [".py"],
  "sourceRoots": ["src"],
  "includeRootFiles": false,
  "excludedPathPrefixes": ["archive/"],
  "testPathPrefixes": ["tests/"],
  "waiverPathPrefix": "governance/test-waivers/",
  "warningLines": 500,
  "maximumLines": 1000
}
'@ | Set-Content -LiteralPath (Join-Path $path 'governance/policy-config.json') -NoNewline
    Write-Lines -Path (Join-Path $path 'src/legacy.py') -Count $LegacyLines
    [System.IO.Directory]::CreateDirectory((Join-Path $path 'tests')) | Out-Null
    Set-Content -LiteralPath (Join-Path $path 'tests/keep.txt') -Value 'baseline'
    & git -C $path add .
    & git -C $path commit --quiet -m 'baseline'
    return $path
}

function Add-TestEvidence {
    param([string]$Repository)
    Set-Content -LiteralPath (Join-Path $Repository 'tests/changed.txt') -Value 'test evidence'
}

function Add-Waiver {
    param([string]$Repository, [string]$Expiry)
    $directory = Join-Path $Repository 'governance/test-waivers'
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    @"
# Test waiver: fixture

- Affected files: `src/legacy.py`
- Reason: fixture purpose
- Compensating evidence: policy checker fixture
- Owner: test suite
- Expires: $Expiry
"@ | Set-Content -LiteralPath (Join-Path $directory 'fixture.md') -NoNewline
}

function Add-IncompleteWaiver {
    param([string]$Repository)
    $directory = Join-Path $Repository 'governance/test-waivers'
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    @'
# Test waiver: incomplete fixture

- Reason: fixture purpose
'@ | Set-Content -LiteralPath (Join-Path $directory 'fixture.md') -NoNewline
}

function Invoke-FixtureCheck {
    param([string]$Repository)
    Push-Location $Repository
    try {
        & $shell -NoProfile -File $checker -BaseRef main *> $null
        return $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}

try {
    $repository = New-FixtureRepository
    Write-Lines -Path (Join-Path $repository 'src/new.py') -Count 500
    Add-TestEvidence -Repository $repository
    Assert-Equal -Actual (Invoke-FixtureCheck -Repository $repository) -Expected 0 -Message 'A 500-line file should pass without a size warning.'
    Write-Lines -Path (Join-Path $repository 'src/new.py') -Count 501
    Assert-Equal -Actual (Invoke-FixtureCheck -Repository $repository) -Expected 0 -Message 'A 501-line file should warn but pass.'

    $repository = New-FixtureRepository
    Write-Lines -Path (Join-Path $repository 'src/new.py') -Count 1000
    Add-TestEvidence -Repository $repository
    Assert-Equal -Actual (Invoke-FixtureCheck -Repository $repository) -Expected 0 -Message 'A 1,000-line new file should pass.'

    $repository = New-FixtureRepository
    Write-Lines -Path (Join-Path $repository 'src/new.py') -Count 1001
    Add-TestEvidence -Repository $repository
    Assert-Equal -Actual (Invoke-FixtureCheck -Repository $repository) -Expected 1 -Message 'A 1,001-line new file should fail.'

    $repository = New-FixtureRepository -LegacyLines 1001
    Write-Lines -Path (Join-Path $repository 'src/legacy.py') -Count 1002
    Add-TestEvidence -Repository $repository
    Assert-Equal -Actual (Invoke-FixtureCheck -Repository $repository) -Expected 1 -Message 'A legacy oversized file must not grow.'

    $repository = New-FixtureRepository -LegacyLines 1001
    Write-Lines -Path (Join-Path $repository 'src/legacy.py') -Count 1000
    Add-TestEvidence -Repository $repository
    Assert-Equal -Actual (Invoke-FixtureCheck -Repository $repository) -Expected 0 -Message 'A shrinking legacy oversized file should pass.'

    $repository = New-FixtureRepository
    Write-Lines -Path (Join-Path $repository 'src/legacy.py') -Count 2
    Assert-Equal -Actual (Invoke-FixtureCheck -Repository $repository) -Expected 1 -Message 'Changed source without evidence should fail.'
    Add-IncompleteWaiver -Repository $repository
    Assert-Equal -Actual (Invoke-FixtureCheck -Repository $repository) -Expected 1 -Message 'A waiver missing required fields should fail.'
    Add-Waiver -Repository $repository -Expiry '2000-01-01'
    Assert-Equal -Actual (Invoke-FixtureCheck -Repository $repository) -Expected 1 -Message 'An expired waiver should fail.'
    Add-Waiver -Repository $repository -Expiry '2099-12-31'
    Assert-Equal -Actual (Invoke-FixtureCheck -Repository $repository) -Expected 0 -Message 'A valid waiver should pass.'

    $repository = New-FixtureRepository
    Write-Lines -Path (Join-Path $repository 'archive/external.py') -Count 1001
    Assert-Equal -Actual (Invoke-FixtureCheck -Repository $repository) -Expected 0 -Message 'Excluded external material should pass.'
    Write-Host 'Hutchins policy checker tests passed.'
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
