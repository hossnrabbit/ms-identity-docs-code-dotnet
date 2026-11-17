[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Maintenance.Common.ps1')

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (!$Condition) { throw $Message }
}

function Assert-Throws {
    param([scriptblock] $Action, [string] $Pattern)
    $caught = $null
    try { & $Action | Out-Null } catch { $caught = $_.Exception.Message }
    Assert-True ($null -ne $caught -and $caught -like $Pattern) "Expected failure matching: $Pattern; actual: $caught"
}

$samples = @(Get-MaintenanceSamples)
$selected = @(Select-MsalSamples -Samples $samples)
Assert-True ($samples.Count -eq 13) 'Expected all thirteen examples.'
Assert-True ($selected.Count -eq 5) 'Expected five direct MSAL.NET examples.'
Assert-True (@($samples | Where-Object dependencyKind -EQ 'idweb').Count -eq 5) 'Expected five IdWeb middleware examples.'
Assert-True (@($samples | Where-Object dependencyKind -EQ 'msal-net-via-idweb').Count -eq 1) 'Expected indirect daemon dependency.'
Assert-True (@($samples | Where-Object dependencyKind -EQ 'browser-msal').Count -eq 1) 'Expected browser MSAL example.'
Assert-True (@($samples | Where-Object dependencyKind -EQ 'easy-auth').Count -eq 1) 'Expected non-MSAL Function.'
foreach ($sample in $selected) {
    Assert-True ($sample.versionSpec -match '^\d+\.\d+\.\d+$|^\d+\.\*$') 'Expected a supported direct reference, including exact pins after maintenance.'
}
Assert-True (@(Select-MsalSamples -Samples $samples -SampleId 'desktop-wpf').Count -eq 1) 'Single-sample selection failed.'
Assert-Throws { Select-MsalSamples -Samples $samples -SampleId 'unknown' } '*Unknown sample*'
Assert-Throws { Select-MsalSamples -Samples $samples -SampleId 'console-daemon' } '*not a direct MSAL.NET*'
Assert-Throws { Select-MsalSamples -Samples $samples -SampleId 'spa-blazor-wasm' } '*not a direct MSAL.NET*'
Assert-Throws { Select-MsalSamples -Samples $samples -SampleId 'web-api-azure-function' } '*not a direct MSAL.NET*'
Assert-True ((Resolve-MsalBaseline -VersionSpec '4.38.0') -ceq '4.38.0') 'Exact baseline changed.'
Assert-Throws { Resolve-MsalBaseline -VersionSpec '../4.*' } '*Unsupported floating*'
& (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -CheckOnly
Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -CheckOnly -RequireAllBuilds } '*Required builds NOT RUN*'
Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -CheckOnly -ExpectedVersion '0.0.1' -SampleId 'console-cli' } '*Expected console-cli*'
Assert-Throws { & (Join-Path $PSScriptRoot 'Get-MsalSourceEvidence.ps1') -TargetVersion '4.91.1' -SampleId 'spa-blazor-wasm' } '*not a direct MSAL.NET*'

$scratch = Join-Path ([IO.Path]::GetTempPath()) ('maintenance-tests-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
    $catalogPath = Join-Path $scratch 'samples.json'
    Assert-Throws { & (Join-Path $PSScriptRoot 'Get-MsalSourceEvidence.ps1') -TargetVersion '4.91.1' -SampleId 'console-cli' -OutputDirectory $scratch } '*already exists*'
    $manifestPath = Join-Path $scratch 'manifest.json'
    $sourcePath = Join-Path $scratch 'sdk'
    $maui = $selected | Where-Object id -EQ 'xplat-maui'
    $mauiBaseline = if ($maui.versionSpec -match '^\d+\.\*$') { $maui.versionSpec.Replace('*', '0.0') } else { $maui.versionSpec }
    $console = $selected | Where-Object id -EQ 'console-cli'
    & git init --quiet $sourcePath
    if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize test source fixture.' }
    'test-only SDK fixture' | Set-Content -LiteralPath (Join-Path $sourcePath 'fixture.txt')
    & git -C $sourcePath add fixture.txt
    & git -C $sourcePath -c user.name=MaintenanceTests -c user.email=maintenance@example.invalid commit --quiet -m fixture
    if ($LASTEXITCODE -ne 0) { throw 'Cannot commit test source fixture.' }
    $commit = (& git -C $sourcePath rev-parse HEAD).Trim()
    foreach ($version in @('4.91.1', '0.0.1', $console.versionSpec) | Select-Object -Unique) {
        & git -C $sourcePath tag $version
        if ($LASTEXITCODE -ne 0) { throw 'Cannot tag test source fixture.' }
        'test-only package fixture' | Set-Content -LiteralPath (Join-Path $scratch "$version.nupkg")
    }
    $packagePath = Join-Path $scratch '4.91.1.nupkg'
    $manifest = [ordered]@{
        schemaVersion = 2
        repository = 'https://github.com/AzureAD/microsoft-authentication-library-for-dotnet.git'
        targetVersion = '4.91.1'
        sourceRepositoryPath = $sourcePath
        releases = @([ordered]@{
            version = '4.91.1'; tag = '4.91.1'; commit = $commit; sourcePath = $sourcePath
            packageSha256 = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash
        })
        comparisons = @()
        samples = @([ordered]@{
            id = 'xplat-maui'; project = 'xplat-maui/XPlat.csproj'
            originalVersion = $maui.versionSpec; baselineVersion = $mauiBaseline; targetVersion = '4.91.1'
            status = 'setup-blocked'; setupError = 'Fixture provenance mismatch'
        })
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
    & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion '4.91.1' -EvidenceManifest $manifestPath -CheckOnly
    Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion '4.91.1' -EvidenceManifest $manifestPath -CheckOnly -RequireAllBuilds } '*Required builds NOT RUN*'
    $manifest.samples[0].originalVersion = '99.0.0'
    $manifest.samples[0].baselineVersion = '99.0.0'
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
    Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion '4.91.1' -EvidenceManifest $manifestPath -CheckOnly } '*must retain its original reference*'
    $manifest.samples[0].originalVersion = $maui.versionSpec
    $manifest.samples[0].baselineVersion = $mauiBaseline
    $manifest.samples[0].status = 'invalid-disposition'
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
    Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion '4.91.1' -EvidenceManifest $manifestPath -CheckOnly } '*Incorrect source-evidence update disposition*'
    $targetRelease = $manifest.releases[0]
    $manifest.releases = @()
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
    Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion '4.91.1' -EvidenceManifest $manifestPath -CheckOnly } '*exactly one verified target release*'
    $manifest.targetVersion = '0.0.1'
    $targetRelease.version = '0.0.1'
    $targetRelease.tag = '0.0.1'
    $targetRelease.packageSha256 = (Get-FileHash -LiteralPath (Join-Path $scratch '0.0.1.nupkg') -Algorithm SHA256).Hash
    $manifest.releases = @($targetRelease)
    $manifest.samples[0].targetVersion = '0.0.1'
    $manifest.samples[0].status = 'newer'
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
    & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion '0.0.1' -EvidenceManifest $manifestPath -CheckOnly

    $manifest.targetVersion = $console.versionSpec
    $targetRelease.version = $console.versionSpec
    $targetRelease.tag = $console.versionSpec
    $targetRelease.packageSha256 = (Get-FileHash -LiteralPath (Join-Path $scratch "$($console.versionSpec).nupkg") -Algorithm SHA256).Hash
    $manifest.samples = @([ordered]@{
        id = $console.id; project = $console.project
        originalVersion = $console.versionSpec; baselineVersion = $console.versionSpec
        targetVersion = $console.versionSpec; status = 'current'
    })
    $diffs = @(foreach ($name in @('sdk-client', 'scenario-apis')) {
        $path = Join-Path $scratch "$name.diff"
        'test-only diff fixture' | Set-Content -LiteralPath $path
        [ordered]@{ name = $name; path = $path; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    })
    $manifest.comparisons = @([ordered]@{
        baselineVersion = $console.versionSpec; targetVersion = $console.versionSpec; sourceDiffs = $diffs
    })
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
    & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion $console.versionSpec -EvidenceManifest $manifestPath -CheckOnly
    $diffs[1].name = 'sdk-client'
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
    Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion $console.versionSpec -EvidenceManifest $manifestPath -CheckOnly } '*both distinct diff families*'
    $diffs[1].name = 'scenario-apis'
    $diffs[1].sha256 = 'invalid-hash'
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
    Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion $console.versionSpec -EvidenceManifest $manifestPath -CheckOnly } '*Prepared source comparison changed*'
    $catalog = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'maintenance-samples.json') -Raw | ConvertFrom-Json
    $catalog.samples = @($catalog.samples) + $catalog.samples[0]
    $catalog | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $catalogPath
    Assert-Throws { Get-MaintenanceSamples -CatalogPath $catalogPath } '*must be unique*'
    $catalog.samples = @($catalog.samples | Select-Object -First 12)
    $catalog | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $catalogPath
    Assert-Throws { Get-MaintenanceSamples -CatalogPath $catalogPath } '*every sample project*'
} finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
Write-Host 'PASS: catalog coverage, dependency routing, framework guards, exact targets, immutable snapshots, blocked-sample protection, and strict missing-build checks.'