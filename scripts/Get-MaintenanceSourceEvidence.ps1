[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string] $TargetVersion,
    [string] $Package = 'Microsoft.Identity.Client',
    [string] $OutputDirectory,
    [string[]] $SampleId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Maintenance.Common.ps1')
$source = Get-MaintenanceSource -Package $Package
$repositoryUrl = $source.repositoryUrl
$samples = @(Get-MaintenanceSamples)
$selected = @(Select-MaintenanceSamples -Samples $samples -Package $Package -SampleId $SampleId)

$evidencePath = if ($OutputDirectory) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    Join-Path ([System.IO.Path]::GetTempPath()) ('msal-source-evidence-' + [guid]::NewGuid())
}
if (Test-Path -LiteralPath $evidencePath) { throw 'Evidence directory already exists; preserve the original evidence rather than overwriting it.' }
$resolved = @{}
$sampleEvidence = @(foreach ($sample in $selected) {
    if (!$resolved.ContainsKey($sample.versionSpec)) {
        $resolved[$sample.versionSpec] = Resolve-MsalBaseline -VersionSpec $sample.versionSpec -Package $Package
    }
    $baselineVersion = $resolved[$sample.versionSpec]
    $status = if ([version] $baselineVersion -gt [version] $TargetVersion) { 'newer' }
        elseif ($baselineVersion -eq $TargetVersion) { 'current' } else { 'update' }
    [ordered]@{
        id = $sample.id
        project = $sample.project
        originalVersion = $sample.versionSpec
        baselineVersion = $baselineVersion
        targetVersion = $TargetVersion
        status = $status
    }
})
$baselineVersions = @($sampleEvidence | Where-Object status -NE 'newer' |
    ForEach-Object { $_.baselineVersion } | Select-Object -Unique)
New-Item -ItemType Directory -Path $evidencePath | Out-Null
$sourcePath = Join-Path $evidencePath 'sdk'
$previousPrompt = $env:GIT_TERMINAL_PROMPT
$env:GIT_TERMINAL_PROMPT = '0'
try {
    & git -c credential.helper= -c http.extraHeader= init --quiet $sourcePath
    if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize source evidence repository.' }
    $releases = @()
    $acquisitionFailures = @{}
    foreach ($version in @(@($TargetVersion) + $baselineVersions | Select-Object -Unique)) {
        try {
            $packageUrl = "https://www.nuget.org/api/v2/package/$Package/$version"
            $packagePath = Join-Path $evidencePath "$version.nupkg"
            Invoke-WebRequest -Uri $packageUrl -OutFile $packagePath -TimeoutSec 60
            $packageCommit = Get-MaintenancePackageCommit -Package $Package -Version $version -PackagePath $packagePath
            & git -c credential.helper= -c http.extraHeader= -C $sourcePath fetch --quiet --no-tags --depth=1 $repositoryUrl $packageCommit
            if ($LASTEXITCODE -ne 0) { throw "Cannot anonymously fetch NuGet-recorded source commit $packageCommit for $version." }
            $actualCommit = (& git -C $sourcePath rev-parse 'FETCH_HEAD^{commit}').Trim()
            if ($LASTEXITCODE -ne 0 -or $actualCommit -ine $packageCommit) { throw 'Fetched source does not match the NuGet-recorded commit.' }
            $checkoutPath = Join-Path $evidencePath $version
            & git -C $sourcePath worktree add --quiet --detach $checkoutPath $packageCommit
            if ($LASTEXITCODE -ne 0) { throw "Cannot materialize source for $version." }
            $tagCommit = $null
            $tagStatus = 'unavailable'
            $tagDiagnostics = @(& git -c credential.helper= -c http.extraHeader= -C $sourcePath fetch --quiet --depth=1 $repositoryUrl "refs/tags/$version`:refs/tags/$version" 2>&1)
            if ($LASTEXITCODE -eq 0) {
                $resolvedTag = @(& git -C $sourcePath rev-parse "$version^{commit}" 2>&1)
                if ($LASTEXITCODE -eq 0) {
                    $tagCommit = ($resolvedTag -join '').Trim()
                    $tagStatus = if ($tagCommit -ieq $packageCommit) { 'matches' } else { 'differs' }
                } else { $tagDiagnostics += $resolvedTag }
            }
            if ($tagStatus -ne 'matches') { Write-Warning "ADVISORY: release tag $version is $tagStatus; source remains pinned to NuGet commit $packageCommit." }
            $releases += [ordered]@{
                version = $version
                tag = $version
                tagObservation = [ordered]@{ status = $tagStatus; commit = $tagCommit; diagnostics = ($tagDiagnostics -join [Environment]::NewLine) }
                commit = $packageCommit
                sourcePath = $checkoutPath
                packageUrl = $packageUrl
                packageSha256 = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
                releaseUrl = $source.releaseBaseUrl + $version
            }
        } catch {
            if ($version -ceq $TargetVersion) { throw }
            $acquisitionFailures[$version] = $_.Exception.Message
            Write-Warning "SETUP_BLOCKED for baseline $version`: $($_.Exception.Message)"
        }
    }
    foreach ($sample in $sampleEvidence) {
        if ($sample.status -ne 'newer' -and $acquisitionFailures.ContainsKey($sample.baselineVersion)) {
            $sample.status = 'setup-blocked'
            $sample['setupError'] = $acquisitionFailures[$sample.baselineVersion]
        }
    }
    $target = $releases | Where-Object version -eq $TargetVersion
    $diffDefinitions = @(
        @{ name = 'sdk-client'; paths = @('src/client') },
        @{ name = 'scenario-apis'; paths = @(
            'src/client/Microsoft.Identity.Client/ApiConfig',
            'src/client/Microsoft.Identity.Client/AppConfig',
            'src/client/Microsoft.Identity.Client/PublicClientApplication.cs',
            'src/client/Microsoft.Identity.Client/IPublicClientApplication.cs',
            'src/client/Microsoft.Identity.Client/ClientApplicationBase.cs',
            'src/client/Microsoft.Identity.Client/IClientApplicationBase.cs',
            'src/client/Microsoft.Identity.Client/AuthenticationResult.cs',
            'src/client/Microsoft.Identity.Client/DeviceCodeResult.cs',
            ':(glob)src/client/Microsoft.Identity.Client/Msal*Exception.cs'
        ) }
    )
    if ($Package -cne 'Microsoft.Identity.Client') {
        $diffDefinitions = @(
            @{ name = 'sdk-client'; paths = @('src') },
            @{ name = 'scenario-apis'; paths = @('src', 'tests') }
        )
    }
    $comparisons = @(foreach ($baselineVersion in $baselineVersions) {
        if ($acquisitionFailures.ContainsKey($baselineVersion)) { continue }
        $baseline = $releases | Where-Object version -EQ $baselineVersion
        $comparisonPath = Join-Path $evidencePath "comparisons/$baselineVersion"
        New-Item -ItemType Directory -Path $comparisonPath -Force | Out-Null
        $changedFiles = @(& git -C $sourcePath diff --name-status $baseline.commit $target.commit)
        if ($LASTEXITCODE -ne 0) { throw 'Cannot compare the verified release source trees.' }
        $sourceDiffs = @(foreach ($definition in $diffDefinitions) {
            $diffPath = Join-Path $comparisonPath ($definition.name + '.diff')
            $diffContent = @(& git --no-pager -C $sourcePath diff --no-ext-diff --no-textconv --unified=3 $baseline.commit $target.commit '--' @($definition.paths))
            if ($LASTEXITCODE -ne 0) { throw "Cannot prepare $($definition.name) source diff." }
            [string]::Join([Environment]::NewLine, $diffContent) | Set-Content -LiteralPath $diffPath -Encoding utf8
            [ordered]@{
                name = $definition.name
                paths = @($definition.paths)
                path = $diffPath
                sha256 = (Get-FileHash -LiteralPath $diffPath -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        })
        [ordered]@{
            baselineVersion = $baselineVersion
            targetVersion = $TargetVersion
            changedFiles = $changedFiles
            sourceDiffs = $sourceDiffs
        }
    })
    $manifestPath = Join-Path $evidencePath 'manifest.json'
    [ordered]@{
        schemaVersion = 2
        sourceProvenance = 'nuget-repository-commit'
        package = $Package
        repository = $repositoryUrl
        targetVersion = $TargetVersion
        samples = $sampleEvidence
        releases = @($releases)
        sourceRepositoryPath = $sourcePath
        comparisons = $comparisons
        limitations = 'Floating references are resolved by an isolated net8.0 NuGet restore during setup, not inferred historical installs. Newer samples remain unchanged. Source inspection and builds do not prove authentication. Never execute SDK code.'
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    Write-Host "PASS: exact NuGet-recorded source commits for $($releases.Count) releases; $($selected.Count) samples referencing $Package inventoried; release tags are advisory."
    Write-Output $manifestPath
} finally {
    $env:GIT_TERMINAL_PROMPT = $previousPrompt
}