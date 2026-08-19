[CmdletBinding()]
param(
    [string]$BaseRef,
    [switch]$SkipTestEvidence
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-RepositoryGit {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = & git -C $script:Repository @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git failed: git $($Arguments -join ' ')"
    }
    return @($output)
}

function Normalize-RepositoryPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return $Path.Replace('\\', '/').TrimStart('./')
}

function Test-PathPrefix {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Prefix
    )

    $normalizedPrefix = (Normalize-RepositoryPath -Path $Prefix).TrimEnd('/')
    return $Path.Equals($normalizedPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
        $Path.StartsWith("$normalizedPrefix/", [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-ExcludedPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    foreach ($prefix in @($script:Config.excludedPathPrefixes)) {
        if (Test-PathPrefix -Path $Path -Prefix $prefix) {
            return $true
        }
    }
    return $false
}

function Test-SourcePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-ExcludedPath -Path $Path) {
        return $false
    }

    $extension = [System.IO.Path]::GetExtension($Path)
    if (@($script:Config.sourceExtensions) -notcontains $extension) {
        return $false
    }

    if ($script:Config.includeRootFiles -and -not $Path.Contains('/')) {
        return $true
    }

    foreach ($root in @($script:Config.sourceRoots)) {
        if (Test-PathPrefix -Path $Path -Prefix $root) {
            return $true
        }
    }
    return $false
}

function Get-FileLineCount {
    param([Parameter(Mandatory = $true)][string]$Path)

    $reader = [System.IO.File]::OpenText($Path)
    try {
        $count = 0
        while ($null -ne $reader.ReadLine()) {
            $count++
        }
        return $count
    }
    finally {
        $reader.Dispose()
    }
}

function Test-PathAtCommit {
    param(
        [Parameter(Mandatory = $true)][string]$Commit,
        [Parameter(Mandatory = $true)][string]$Path
    )

    & git -C $script:Repository cat-file -e "$Commit`:$Path" 2>$null
    return $LASTEXITCODE -eq 0
}

function Get-CommitLineCount {
    param(
        [Parameter(Mandatory = $true)][string]$Commit,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = & git -C $script:Repository show "$Commit`:$Path"
    if ($LASTEXITCODE -ne 0) {
        throw "Could not read $Path at $Commit"
    }
    return @($lines).Count
}

function Test-ValidWaiver {
    param([Parameter(Mandatory = $true)][string]$Path)

    $text = Get-Content -LiteralPath $Path -Raw
    $lines = @($text -split "`r?`n")
    $values = @{}
    foreach ($field in @('Affected files', 'Reason', 'Compensating evidence', 'Owner', 'Expires')) {
        $prefix = "- ${field}:"
        $line = @($lines | Where-Object {
            $_.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
        } | Select-Object -First 1)
        $value = if ($line.Count -eq 1) { $line[0].Substring($prefix.Length).Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($value)) {
            $script:Failures.Add("Waiver $Path is missing '$field'.")
            return $false
        }
        $values[$field] = $value
    }

    $expiry = [datetime]::MinValue
    $parsed = [datetime]::TryParseExact(
        $values['Expires'],
        'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref]$expiry
    )
    if (-not $parsed -or $expiry.Date -lt (Get-Date).Date) {
        $script:Failures.Add("Waiver $Path has an invalid or expired Expires date.")
        return $false
    }
    return $true
}

$repositoryOutput = & git rev-parse --show-toplevel
$repositoryExitCode = $LASTEXITCODE
$Repository = (@($repositoryOutput) | Select-Object -First 1).Trim()
if ($repositoryExitCode -ne 0) {
    throw 'This command must run inside a Git worktree.'
}
$configPath = Join-Path $Repository 'governance/policy-config.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Policy configuration is missing: $configPath"
}
$Config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($BaseRef)) {
    $BaseRef = [string]$Config.defaultBaseRef
}

$baseCommit = (Invoke-RepositoryGit -Arguments @('rev-parse', '--verify', "$BaseRef^{commit}") | Select-Object -First 1).Trim()
$mergeBase = (Invoke-RepositoryGit -Arguments @('merge-base', 'HEAD', $baseCommit) | Select-Object -First 1).Trim()
$changedPaths = @(
    Invoke-RepositoryGit -Arguments @('diff', '--name-only', '--diff-filter=ACMR', $mergeBase, 'HEAD')
    Invoke-RepositoryGit -Arguments @('diff', '--name-only', '--diff-filter=ACMR')
    Invoke-RepositoryGit -Arguments @('diff', '--name-only', '--cached', '--diff-filter=ACMR')
    Invoke-RepositoryGit -Arguments @('ls-files', '--others', '--exclude-standard')
) | ForEach-Object { Normalize-RepositoryPath -Path $_ } | Where-Object { $_ } | Sort-Object -Unique

$Failures = [System.Collections.Generic.List[string]]::new()
$Warnings = [System.Collections.Generic.List[string]]::new()
$sourcePaths = @($changedPaths | Where-Object { Test-SourcePath -Path $_ })
$testChanged = $false
foreach ($path in $changedPaths) {
    foreach ($prefix in @($Config.testPathPrefixes)) {
        if (Test-PathPrefix -Path $path -Prefix $prefix) {
            $testChanged = $true
        }
    }
}

$validWaiver = $false
foreach ($path in $changedPaths) {
    if ((Test-PathPrefix -Path $path -Prefix $Config.waiverPathPrefix) -and [System.IO.Path]::GetFileName($path) -ne 'README.md') {
        $fullPath = Join-Path $Repository ($path.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        if ((Test-Path -LiteralPath $fullPath -PathType Leaf) -and (Test-ValidWaiver -Path $fullPath)) {
            $validWaiver = $true
        }
    }
}

foreach ($path in $sourcePaths) {
    $fullPath = Join-Path $Repository ($path.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        continue
    }

    $currentLines = Get-FileLineCount -Path $fullPath
    $existsAtBase = Test-PathAtCommit -Commit $mergeBase -Path $path
    $baseLines = if ($existsAtBase) { Get-CommitLineCount -Commit $mergeBase -Path $path } else { 0 }

    if ($currentLines -gt [int]$Config.maximumLines) {
        $isAllowedLegacy = $existsAtBase -and $baseLines -gt [int]$Config.maximumLines -and $currentLines -le $baseLines
        if (-not $isAllowedLegacy) {
            $Failures.Add("$path has $currentLines lines; the maximum is $($Config.maximumLines).")
        }
    }
    elseif ($currentLines -gt [int]$Config.warningLines) {
        $Warnings.Add("$path has $currentLines lines; split it when practical to stay near $($Config.warningLines).")
    }
}

if (-not $SkipTestEvidence -and $sourcePaths.Count -gt 0 -and -not $testChanged -and -not $validWaiver) {
    $Failures.Add('Executable source changed without a test change or a valid, time-limited test waiver.')
}

foreach ($warning in $Warnings) {
    Write-Warning $warning
}
if ($Failures.Count -gt 0) {
    foreach ($failure in $Failures) {
        Write-Error $failure
    }
    exit 1
}

Write-Host "Hutchins policy check passed against $BaseRef ($($sourcePaths.Count) changed source file(s))."
exit 0
