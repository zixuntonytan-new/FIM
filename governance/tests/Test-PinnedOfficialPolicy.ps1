# Dot-sourced by Test-HutchinsPolicy.ps1; uses its disposable repositories and shells.
function Invoke-PinnedFixtureGit {
    param([string]$Repository, [string[]]$Arguments)
    $output = & git -C $Repository @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Pinned fixture Git failed: $($Arguments -join ' ')" }
    return $output
}

function Write-PinnedText {
    param([string]$Repository, [string]$Path, [string]$Text, [switch]$Bom)
    $fullPath = Join-Path $Repository $Path
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $fullPath)) | Out-Null
    [System.IO.File]::WriteAllText($fullPath, $Text, [System.Text.UTF8Encoding]::new($Bom.IsPresent))
}

function Set-FixturePin {
    param([string]$Repository, $Value, [switch]$Remove)
    $path = Join-Path $Repository 'governance/policy-config.json'
    $config = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($Remove) { $config.PSObject.Properties.Remove('officialSourceCommit') }
    else { $config | Add-Member -NotePropertyName officialSourceCommit -NotePropertyValue $Value -Force }
    Write-PinnedText $Repository 'governance/policy-config.json' ($config | ConvertTo-Json -Depth 3)
}

function New-PinnedFixture {
    $repository = New-FixtureRepository
    Invoke-PinnedFixtureGit $repository @('config', 'core.autocrlf', 'false') | Out-Null
    Invoke-PinnedFixtureGit $repository @('switch', '--quiet', '-c', 'fixture-official') | Out-Null
    $large = ((1..1001 | ForEach-Object { "line $_" }) -join "`n") + "`n"
    $short = '# $Id$' + "`n"
    Write-PinnedText $repository 'src/legacy.py' $large
    Write-PinnedText $repository 'src/short.py' $short
    Write-PinnedText $repository 'src/new-official.py' "answer = 1`n"
    Invoke-PinnedFixtureGit $repository @('add', 'src') | Out-Null
    Invoke-PinnedFixtureGit $repository @('commit', '--quiet', '-m', 'synthetic official source') | Out-Null
    $pin = (Invoke-PinnedFixtureGit $repository @('rev-parse', 'HEAD')).Trim()
    Invoke-PinnedFixtureGit $repository @('switch', '--quiet', '-c', 'candidate', 'main') | Out-Null
    Set-FixturePin $repository $pin
    return [pscustomobject]@{ Repository = $repository; Pin = $pin; Large = $large; Short = $short }
}

function Assert-PinnedResult {
    param($Fixture, [int]$Expected, [string]$Case, [string[]]$Contains = @(), [string[]]$Absent = @())
    foreach ($policyShell in $policyShells) {
        $result = Invoke-FixtureCheck -Repository $Fixture.Repository -PolicyShell $policyShell
        Assert-Equal $result.ExitCode $Expected "$Case ($($policyShell.Name)). $($result.Output)"
        foreach ($message in $Contains) { Assert-Contains $result.Output $message $Case }
        foreach ($message in $Absent) {
            if ($result.Output.Contains($message)) { throw "$Case unexpectedly reported '$message': $($result.Output)" }
        }
        $script:pinnedChecksRun++
        Write-Host "PINNED FIXTURE PASS: $Case ($($policyShell.Name))"
    }
}

function Test-PinnedOfficialPolicy {
    $script:pinnedChecksRun = 0
    $exempt = 'Pinned-official size/test-evidence exemption:'
    $evidence = 'Executable source changed without a matching test change'
    $size = 'src/legacy.py has 1001 lines'

    $f = New-PinnedFixture
    Write-PinnedText $f.Repository 'src/legacy.py' $f.Large
    Assert-PinnedResult $f 0 'F1 exact oversized official import' @("$exempt src/legacy.py") @('has 1001 lines', $evidence)

    $f = New-PinnedFixture
    Write-PinnedText $f.Repository 'src/short.py' $f.Short
    Write-PinnedText $f.Repository 'src/new-official.py' "answer = 1`n"
    Assert-PinnedResult $f 0 'F2 short and new-to-internal official paths' @("$exempt src/short.py", "$exempt src/new-official.py") @($evidence)

    $f = New-PinnedFixture
    Write-PinnedText $f.Repository 'src/legacy.py' ($f.Large.Replace("line 1`n", "line 0`n"))
    Assert-PinnedResult $f 1 'F3 changed official-path oversized content' @($size, $evidence) @($exempt)

    $f = New-PinnedFixture
    Write-PinnedText $f.Repository 'src/short.py' ($f.Short.Replace('Id', 'ID'))
    Assert-PinnedResult $f 1 'F4 changed short official-path content' @($evidence, 'src/short.py') @($exempt)

    $f = New-PinnedFixture
    Write-PinnedText $f.Repository 'src/legacy.py' $f.Large
    Write-PinnedText $f.Repository 'src/local.py' "answer = 2`n"
    Assert-PinnedResult $f 1 'F5 mixed change still needs evidence' @("$exempt src/legacy.py", "${evidence} or a valid, time-limited test waiver: src/local.py") @($size)
    Add-TestEvidence $f.Repository
    Assert-PinnedResult $f 0 'F6 mixed change with existing test evidence' @("$exempt src/legacy.py") @($size, $evidence)
    Write-PinnedText $f.Repository 'src/local.py' $f.Large
    Assert-PinnedResult $f 1 'F7 nonofficial size rule survives test evidence' @('src/local.py has 1001 lines') @($size, $evidence)

    foreach ($renamed in @($false, $true)) {
        $f = New-PinnedFixture
        if ($renamed) { Invoke-PinnedFixtureGit $f.Repository @('mv', 'src/legacy.py', 'src/copied.py') | Out-Null }
        Write-PinnedText $f.Repository 'src/copied.py' $f.Large
        Assert-PinnedResult $f 1 "F8 different path (rename=$renamed)" @('src/copied.py has 1001 lines', $evidence) @($exempt)
    }

    $f = New-PinnedFixture
    Write-PinnedText $f.Repository 'src/legacy.py' $f.Large
    Set-FixturePin $f.Repository -Remove
    Assert-PinnedResult $f 1 'F9 no pin means original enforcement' @($size, $evidence) @($exempt)

    $f = New-PinnedFixture
    Invoke-PinnedFixtureGit $f.Repository @('tag', '-a', 'fixture-tag', '-m', 'fixture tag', $f.Pin) | Out-Null
    $invalidPins = @(
        @{ Name = 'blank'; Value = ''; Message = 'full lowercase commit ID' },
        @{ Name = 'null'; Value = $null; Message = 'full lowercase commit ID' },
        @{ Name = 'branch'; Value = 'fixture-official'; Message = 'full lowercase commit ID' },
        @{ Name = 'abbreviated'; Value = $f.Pin.Substring(0, 7); Message = 'full lowercase commit ID' },
        @{ Name = 'unavailable'; Value = ('0' * 40); Message = 'rev-parse' },
        @{ Name = 'tree'; Value = (Invoke-PinnedFixtureGit $f.Repository @('rev-parse', "$($f.Pin)^{tree}")).Trim(); Message = 'rev-parse' },
        @{ Name = 'blob'; Value = (Invoke-PinnedFixtureGit $f.Repository @('rev-parse', "$($f.Pin):src/legacy.py")).Trim(); Message = 'rev-parse' },
        @{ Name = 'tag-object'; Value = (Invoke-PinnedFixtureGit $f.Repository @('rev-parse', 'refs/tags/fixture-tag')).Trim(); Message = 'commit itself' }
    )
    foreach ($invalid in $invalidPins) {
        Set-FixturePin $f.Repository $invalid.Value
        Assert-PinnedResult $f 1 "F10 invalid pin: $($invalid.Name)" @($invalid.Message) @($exempt)
    }

    $f = New-PinnedFixture
    Invoke-PinnedFixtureGit $f.Repository @('config', 'core.autocrlf', 'true') | Out-Null
    Write-PinnedText $f.Repository 'src/legacy.py' ($f.Large.Replace("`n", "`r`n"))
    Assert-PinnedResult $f 0 'F11 CRLF-only matches normal Git identity' @("$exempt src/legacy.py") @($size, $evidence)
    Write-PinnedText $f.Repository 'src/legacy.py' $f.Large -Bom
    Assert-PinnedResult $f 1 'F11 BOM remains different' @($size, $evidence) @($exempt)
    Write-PinnedText $f.Repository 'src/legacy.py' ($f.Large + "`n")
    Assert-PinnedResult $f 1 'F11 added final newline remains different' @('src/legacy.py has 1002 lines', $evidence) @($exempt)

    # Attributes must be evaluated at the source path, not at a temporary filename.
    $f = New-PinnedFixture
    Write-PinnedText $f.Repository '.gitattributes' "src/legacy.py text eol=lf`n"
    Write-PinnedText $f.Repository 'src/legacy.py' ($f.Large.Replace("`n", "`r`n"))
    Assert-PinnedResult $f 0 'F11 path text attribute enables normalization' @("$exempt src/legacy.py") @($size, $evidence)
    Invoke-PinnedFixtureGit $f.Repository @('config', 'core.autocrlf', 'true') | Out-Null
    Write-PinnedText $f.Repository '.gitattributes' "src/legacy.py -text`n"
    Assert-PinnedResult $f 1 'F11 path binary attribute disables normalization' @($size, $evidence) @($exempt)

    $f = New-PinnedFixture
    Write-PinnedText $f.Repository '.gitattributes' "src/short.py ident`n"
    Write-PinnedText $f.Repository 'src/short.py' ('# $Id: expanded $' + "`n")
    Assert-PinnedResult $f 0 'F11 path-specific ident filter is honored' @("$exempt src/short.py") @($evidence)
    Write-PinnedText $f.Repository '.gitattributes' "other/*.py ident`n"
    Assert-PinnedResult $f 1 'F11 unrelated path attribute grants nothing' @($evidence) @($exempt)

    foreach ($committed in @($false, $true)) {
        $f = New-PinnedFixture
        Write-PinnedText $f.Repository 'src/legacy.py' $f.Large
        Invoke-PinnedFixtureGit $f.Repository @('add', 'src/legacy.py') | Out-Null
        if ($committed) { Invoke-PinnedFixtureGit $f.Repository @('commit', '--quiet', '-m', 'candidate import') | Out-Null }
        Write-PinnedText $f.Repository 'src/legacy.py' ($f.Large.Replace("line 1`n", "line 0`n"))
        Assert-PinnedResult $f 1 "F12 inspect working file (committed=$committed)" @($size, $evidence) @($exempt)
    }

    $f = New-PinnedFixture
    Write-PinnedText $f.Repository 'src/legacy.py' ($f.Large.Replace("line 1`n", "line 0`n"))
    Invoke-PinnedFixtureGit $f.Repository @('add', 'src/legacy.py') | Out-Null
    Invoke-PinnedFixtureGit $f.Repository @('commit', '--quiet', '-m', 'different candidate') | Out-Null
    Invoke-PinnedFixtureGit $f.Repository @('branch', '-f', 'fixture-official', 'HEAD') | Out-Null
    Add-TestEvidence $f.Repository
    Assert-PinnedResult $f 1 'F13 moving branch cannot move configured pin' @($size) @($exempt, $evidence)

    $f = New-PinnedFixture
    Write-PinnedText $f.Repository 'src/legacy.py' $f.Large
    Write-Lines (Join-Path $f.Repository 'src/local.py') 501
    Add-TestEvidence $f.Repository
    Assert-PinnedResult $f 0 'F14 nonofficial size warning remains' @('src/local.py has 501 lines') @('src/legacy.py has', $evidence)

    $f = New-PinnedFixture
    Write-PinnedText $f.Repository 'src/legacy.py' $f.Large
    Add-Waiver $f.Repository -Expiry '2000-01-01'
    Assert-PinnedResult $f 1 'F15 invalid waiver still fails' @('invalid or expired Expires date') @($size, $evidence)

    Write-Host "Pinned-official policy fixtures passed: $script:pinnedChecksRun checker invocations."
}
