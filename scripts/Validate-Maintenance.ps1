[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string] $ExpectedVersion,
    [string] $Package = 'Microsoft.Identity.Client',
    [string] $EvidenceManifest,
    [string[]] $SampleId,
    [ValidateSet('host', 'any', 'windows', 'maui', 'all')]
    [string] $BuildPlatform = 'host',
    [switch] $CheckOnly,
    [switch] $RequireAllBuilds
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Maintenance.Common.ps1')
$repositoryRoot = Split-Path $PSScriptRoot -Parent
$samples = @(Get-MaintenanceSamples)
$source = Get-MaintenanceSource -Package $Package
$evidence = $null
$blockedSamples = @{}

if ($EvidenceManifest) {
    if (!$ExpectedVersion) { throw 'Evidence validation requires an exact ExpectedVersion.' }
    $evidence = Get-Content -LiteralPath $EvidenceManifest -Raw | ConvertFrom-Json
    if ($evidence.schemaVersion -ne 2 -or $evidence.targetVersion -cne $ExpectedVersion -or
        $evidence.repository -cne $source.repositoryUrl -or
        ($evidence.PSObject.Properties.Name -contains 'package' -and $evidence.package -cne $Package) -or
        ($Package -cne 'Microsoft.Identity.Client' -and $evidence.PSObject.Properties.Name -notcontains 'package')) {
        throw 'Source evidence must use schema 2 and match the exact target and official repository.'
    }
    if (@($evidence.releases | Where-Object version -CEQ $ExpectedVersion).Count -ne 1) {
        throw 'Source evidence must contain exactly one verified target release.'
    }
    if (!$SampleId) { $SampleId = @($evidence.samples.id) }
    if (!$SampleId -or @($evidence.samples.id | Select-Object -Unique).Count -ne @($evidence.samples).Count) {
        throw 'Source evidence requires unique sample records.'
    }
    foreach ($release in $evidence.releases) {
        if ($release.version -notmatch '^\d+\.\d+\.\d+$' -or $release.tag -cne $release.version -or
            $release.commit -notmatch '^[0-9a-fA-F]{40}$') {
            throw 'Invalid exact source release identity.'
        }
        $actualCommit = & git -C $release.sourcePath rev-parse HEAD
        if ($LASTEXITCODE -ne 0 -or $actualCommit.Trim() -ine $release.commit) {
            throw 'A source evidence checkout does not match its recorded commit.'
        }
        $sourceChanges = @(& git -C $release.sourcePath status --porcelain)
        if ($LASTEXITCODE -ne 0 -or $sourceChanges.Count) { throw 'Source evidence checkout has changed.' }
        $tagCommit = & git -C $evidence.sourceRepositoryPath rev-parse "$($release.tag)^{commit}"
        if ($LASTEXITCODE -ne 0 -or $tagCommit.Trim() -ine $release.commit) { throw 'Source tag identity changed.' }
        $packagePath = Join-Path (Split-Path $EvidenceManifest -Parent) "$($release.version).nupkg"
        if ((Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash -ine $release.packageSha256) {
            throw 'Original NuGet package evidence changed.'
        }
    }
    Write-Host 'PASS: original source/package snapshots and tag identities are unchanged.'
}

$selected = @(Select-MaintenanceSamples -Samples $samples -Package $Package -SampleId $SampleId)
foreach ($sample in $samples | Where-Object { $_.id -cnotin @($selected.id) }) {
    Write-Host "NOT APPLICABLE to $Package updates: $($sample.id) ($($sample.dependencyKind))."
}
foreach ($sample in $selected) {
    $expected = $ExpectedVersion
    if ($evidence) {
        $records = @($evidence.samples | Where-Object id -EQ $sample.id)
        if ($records.Count -ne 1 -or $records[0].project -cne $sample.project -or
            $records[0].targetVersion -cne $ExpectedVersion) {
            throw "Missing or mismatched source evidence for $($sample.id)."
        }
        $record = $records[0]
        if ($record.baselineVersion -notmatch '^\d+\.\d+\.\d+$' -or
            ($record.originalVersion -cne $record.baselineVersion -and
                $record.originalVersion -cne ($record.baselineVersion.Split('.')[0] + '.*'))) {
            throw "Original baseline reference does not match evidence for $($sample.id)."
        }
        if ($record.status -ceq 'setup-blocked') {
            if (!$record.setupError -or $sample.versionSpec -cne $record.originalVersion) {
                throw "SETUP_BLOCKED sample must retain its original reference: $($sample.id)."
            }
            $blockedSamples[$sample.id] = $record.setupError
            Write-Host "SETUP_BLOCKED: $($sample.id): $($record.setupError)"
            continue
        }
        $status = if ([version] $record.baselineVersion -gt [version] $ExpectedVersion) { 'newer' }
            elseif ($record.baselineVersion -ceq $ExpectedVersion) { 'current' } else { 'update' }
        if ($record.status -cne $status) { throw 'Incorrect source-evidence update disposition.' }
        if ($status -eq 'newer') {
            $expected = $record.originalVersion
            Write-Host "NO DOWNGRADE: preserve $($sample.id) at $expected (resolved $($record.baselineVersion))."
        } else {
            foreach ($requiredVersion in @($record.baselineVersion, $ExpectedVersion) | Select-Object -Unique) {
                if (@($evidence.releases | Where-Object version -CEQ $requiredVersion).Count -ne 1) {
                    throw "Missing exact baseline/target source release for $($sample.id)."
                }
            }
            $comparisons = @($evidence.comparisons | Where-Object {
                $_.baselineVersion -ceq $record.baselineVersion -and $_.targetVersion -ceq $ExpectedVersion
            })
            if ($comparisons.Count -ne 1 -or @($comparisons[0].sourceDiffs).Count -ne 2) {
                throw "Missing baseline-specific source diffs for $($sample.id)."
            }
            if (@($comparisons[0].sourceDiffs.name | Select-Object -Unique).Count -ne 2) {
                throw 'Prepared source comparison must include both distinct diff families.'
            }
            foreach ($diff in $comparisons[0].sourceDiffs) {
                if ($diff.name -notin @('scenario-apis', 'sdk-client') -or
                    (Get-FileHash -LiteralPath $diff.path -Algorithm SHA256).Hash -ine $diff.sha256) {
                    throw 'Prepared source comparison changed.'
                }
            }
        }
    }
    if ($expected -and $sample.versionSpec -cne $expected) {
        throw "Expected $($sample.id) $Package reference $expected but found $($sample.versionSpec)."
    }
}

$built = 0
$notRun = @()
foreach ($sample in $selected) {
    if ($blockedSamples.ContainsKey($sample.id)) {
        $notRun += $sample.id
        Write-Host "NOT RUN: $($sample.id) build and update; source evidence is SETUP_BLOCKED."
        continue
    }
    $canBuild = switch ($BuildPlatform) {
        'host' { $sample.platform -eq 'any' -or ($IsWindows -and $sample.platform -eq 'windows') }
        'any' { $sample.platform -eq 'any' }
        'windows' { $IsWindows -and $sample.platform -eq 'windows' }
        'maui' { $IsWindows -and $sample.platform -eq 'maui' }
        'all' { $sample.platform -eq 'any' -or $IsWindows }
    }
    if ($CheckOnly -or !$canBuild) {
        $notRun += $sample.id
        Write-Host "NOT RUN: $($sample.id) build; platform=$($sample.platform), requested=$BuildPlatform, checkOnly=$CheckOnly."
        continue
    }
    $projectPath = Join-Path $repositoryRoot $sample.project
    $properties = @(if ($sample.platform -eq 'windows') { '-p:Platform=x64' })
    Write-Host "Validating $($sample.id) with $Package reference $($sample.versionSpec)."
    & dotnet restore $projectPath --verbosity minimal @properties
    if ($LASTEXITCODE -ne 0) { throw "Sample restore failed: $($sample.id)." }
    & dotnet build $projectPath --configuration Release --no-restore --verbosity minimal @properties
    if ($LASTEXITCODE -ne 0) { throw "Sample build failed: $($sample.id)." }
    $built++
}
Write-Host "PASS: catalog and selected project checks. Builds passed: $built. Builds NOT RUN: $($notRun.Count). Unit tests: NOT AVAILABLE. Sign-in: NOT RUN."
if ($RequireAllBuilds -and $notRun.Count) {
    throw "Required builds NOT RUN: $($notRun -join ', '). Supply the appropriate Windows/legacy MAUI toolchain."
}