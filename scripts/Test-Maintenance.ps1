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

function New-TestPackage {
    param([string] $Path, [string] $Package, [string] $Version, [string] $Commit, [string] $Repository = (Get-MaintenanceSource -Package $Package).repositoryUrl)
    $archive = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $writer = [System.IO.StreamWriter]::new($archive.CreateEntry("$Package.nuspec").Open())
        try { $writer.Write(('<package><metadata><id>{0}</id><version>{1}</version><repository url="{2}" commit="{3}" /></metadata></package>' -f $Package, $Version, $Repository, $Commit)) }
        finally { $writer.Dispose() }
    } finally { $archive.Dispose() }
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
Assert-True (@(Select-MaintenanceSamples -Samples $samples -Package 'Microsoft.Identity.Client').Count -eq 5) 'Shared MSAL selection changed.'
$idweb = @(Select-MaintenanceSamples -Samples $samples -Package 'Microsoft.Identity.Web')
Assert-True ($idweb.Count -gt 0 -and @($idweb | Where-Object dependencyKind -EQ 'direct-msal-net').Count -eq 0) 'Shared IdWeb routing selected MSAL-only samples.'
Assert-True ((Get-MaintenanceSource -Package 'Microsoft.Identity.Web.UI').repository -ceq 'AzureAD/microsoft-identity-web') 'Wrong IdWeb source.'
Assert-True ((Get-MaintenanceSource -Package 'Microsoft.Identity.Client').repository -ceq 'AzureAD/microsoft-authentication-library-for-dotnet') 'Wrong MSAL source.'
Assert-Throws { Select-MaintenanceSamples -Samples $samples -Package 'Microsoft.Identity.Web' -SampleId 'console-cli' } '*does not directly reference*'
Assert-Throws { Select-MaintenanceSamples -Samples $samples -Package 'Microsoft.Identity.Client' -SampleId 'web-app-aspnet' } '*not a direct MSAL.NET*'
Assert-Throws { Get-MaintenanceSource -Package 'Microsoft.Identity.Client.Evil' } '*Unsupported identity package*'
Assert-Throws { Select-MsalSamples -Samples $samples -SampleId 'unknown' } '*Unknown sample*'
Assert-Throws { Select-MsalSamples -Samples $samples -SampleId 'console-daemon' } '*not a direct MSAL.NET*'
Assert-Throws { Select-MsalSamples -Samples $samples -SampleId 'spa-blazor-wasm' } '*not a direct MSAL.NET*'
Assert-Throws { Select-MsalSamples -Samples $samples -SampleId 'web-api-azure-function' } '*not a direct MSAL.NET*'
Assert-True ((Resolve-MsalBaseline -VersionSpec '4.38.0') -ceq '4.38.0') 'Exact baseline changed.'
Assert-Throws { Resolve-MsalBaseline -VersionSpec '../4.*' } '*Unsupported floating*'
& (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -CheckOnly
Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -CheckOnly -RequireAllBuilds } '*Required builds NOT RUN*'
Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -CheckOnly -ExpectedVersion '0.0.1' -SampleId 'console-cli' } '*Expected console-cli*'
Assert-Throws { & (Join-Path $PSScriptRoot 'Get-MaintenanceSourceEvidence.ps1') -TargetVersion '4.91.1' -SampleId 'spa-blazor-wasm' } '*not a direct MSAL.NET*'
Assert-Throws { & (Join-Path $PSScriptRoot 'Get-MsalSourceEvidence.ps1') -TargetVersion '4.91.1' -SampleId 'spa-blazor-wasm' } '*not a direct MSAL.NET*'
Assert-Throws { & (Join-Path $PSScriptRoot 'Get-MsalSourceEvidence.ps1') -Package 'Microsoft.Identity.Web' -TargetVersion '4.18.0' -SampleId 'console-cli' } '*does not directly reference*'

if ($IsWindows) {
    & {
        $global:maintenanceTestDotnetCalls = [System.Collections.Generic.List[object]]::new()
        $global:maintenanceTestMsbuildCalls = [System.Collections.Generic.List[object]]::new()
        function dotnet {
            $global:maintenanceTestDotnetCalls.Add(@($args))
            $global:LASTEXITCODE = 0
        }
        function msbuild {
            $global:maintenanceTestMsbuildCalls.Add(@($args))
            $global:LASTEXITCODE = 0
        }
        try {
            & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -SampleId 'desktop-winforms' -BuildPlatform windows -RequireAllBuilds
            Assert-True ($global:maintenanceTestDotnetCalls.Count -eq 2) 'Expected mocked restore and build.'
            Assert-True ($global:maintenanceTestDotnetCalls[0].Count -eq 5 -and $global:maintenanceTestDotnetCalls[0][-1] -ceq '-p:Platform=x64') 'Restore platform argument was split.'
            Assert-True ($global:maintenanceTestDotnetCalls[1].Count -eq 8 -and $global:maintenanceTestDotnetCalls[1][-1] -ceq '-p:Platform=x64') 'Build platform argument was split.'
            & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -SampleId 'desktop-winui' -BuildPlatform windows -RequireAllBuilds
            Assert-True ($global:maintenanceTestDotnetCalls.Count -eq 3 -and $global:maintenanceTestDotnetCalls[2][0] -ceq 'restore') 'WinUI must not use dotnet build for its CLR4 XAML compiler.'
            Assert-True ($global:maintenanceTestMsbuildCalls.Count -eq 1 -and $global:maintenanceTestMsbuildCalls[0].Count -eq 5 -and $global:maintenanceTestMsbuildCalls[0][-1] -ceq '-p:Platform=x64') 'WinUI must use full-framework MSBuild with intact platform arguments.'
        } finally {
            Remove-Variable maintenanceTestDotnetCalls -Scope Global
            Remove-Variable maintenanceTestMsbuildCalls -Scope Global
        }
    }
}

$scratch = Join-Path ([IO.Path]::GetTempPath()) ('maintenance-tests-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
    $catalogPath = Join-Path $scratch 'samples.json'
    Assert-Throws { & (Join-Path $PSScriptRoot 'Get-MaintenanceSourceEvidence.ps1') -TargetVersion '4.91.1' -SampleId 'console-cli' -OutputDirectory $scratch } '*already exists*'
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
        New-TestPackage -Path (Join-Path $scratch "$version.nupkg") -Package 'Microsoft.Identity.Client' -Version $version -Commit $commit
    }
    $packagePath = Join-Path $scratch '4.91.1.nupkg'
    $manifest = [ordered]@{
        schemaVersion = 2
        sourceProvenance = 'nuget-repository-commit'
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
    $setupManifest = $manifest | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $setupManifest.targetVersion = '4.91.1'
    $setupTarget = $setupManifest.releases[0] | ConvertTo-Json | ConvertFrom-Json
    $setupTarget.version = '4.91.1'
    $setupTarget.packageSha256 = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash
    $setupManifest.releases = @($setupManifest.releases[0], $setupTarget)
    $setupManifest.samples[0].targetVersion = '4.91.1'
    $setupManifest.samples[0].status = 'update'
    $setupManifest.comparisons[0].targetVersion = '4.91.1'
    $setupManifest.comparisons[0].sourceDiffs[1].name = 'scenario-apis'
    $setupManifestPath = Join-Path $scratch 'setup-manifest.json'
    $setupManifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $setupManifestPath
    & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion '4.91.1' -EvidenceManifest $setupManifestPath -CheckOnly -SetupCheck
    Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion '4.91.1' -EvidenceManifest $setupManifestPath -CheckOnly } '*Expected console-cli Microsoft.Identity.Client reference 4.91.1*'
    Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion '4.91.1' -EvidenceManifest $setupManifestPath -SetupCheck } '*SetupCheck requires original evidence and CheckOnly*'
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
    Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion $console.versionSpec -EvidenceManifest $manifestPath -CheckOnly } '*both distinct diff families*'
    $diffs[1].name = 'scenario-apis'
    $diffs[1].sha256 = 'invalid-hash'
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
    Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion $console.versionSpec -EvidenceManifest $manifestPath -CheckOnly } '*Prepared source comparison changed*'
    $webSample = $idweb[0]
    & git -C $sourcePath tag $webSample.versionSpec
    if ($LASTEXITCODE -ne 0) { throw 'Cannot tag IdWeb source fixture.' }
    $webPackagePath = Join-Path $scratch "$($webSample.versionSpec).nupkg"
    New-TestPackage -Path $webPackagePath -Package 'Microsoft.Identity.Web' -Version $webSample.versionSpec -Commit $commit
    $manifest.repository = 'https://github.com/AzureAD/microsoft-identity-web.git'
    $manifest['package'] = 'Microsoft.Identity.Web'
    $manifest.targetVersion = $webSample.versionSpec
    $targetRelease.version = $webSample.versionSpec
    $targetRelease.tag = $webSample.versionSpec
    $targetRelease.packageSha256 = (Get-FileHash -LiteralPath $webPackagePath -Algorithm SHA256).Hash
    $manifest.releases = @($targetRelease)
    $manifest.samples = @([ordered]@{
        id = $webSample.id; project = $webSample.project
        originalVersion = $webSample.versionSpec; baselineVersion = $webSample.versionSpec
        targetVersion = $webSample.versionSpec; status = 'current'
    })
    $diffs[1].sha256 = (Get-FileHash -LiteralPath $diffs[1].path -Algorithm SHA256).Hash
    $manifest.comparisons = @([ordered]@{
        baselineVersion = $webSample.versionSpec; targetVersion = $webSample.versionSpec; sourceDiffs = $diffs
    })
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
    & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -Package 'Microsoft.Identity.Web' -ExpectedVersion $webSample.versionSpec -EvidenceManifest $manifestPath -CheckOnly
    Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -Package 'Microsoft.Identity.Web.UI' -ExpectedVersion $webSample.versionSpec -EvidenceManifest $manifestPath -CheckOnly } '*match the exact target and official repository*'
    Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion $webSample.versionSpec -EvidenceManifest $manifestPath -CheckOnly } '*match the exact target and official repository*'
    Assert-Throws { & (Join-Path $PSScriptRoot 'Get-MaintenanceSourceEvidence.ps1') -Package 'Microsoft.Identity.Web' -TargetVersion $webSample.versionSpec -OutputDirectory $scratch } '*already exists*'
    $invalidPackage = Join-Path $scratch 'invalid.nupkg'
    New-TestPackage -Path $invalidPackage -Package 'Microsoft.Identity.Client' -Version '4.64.0' -Commit $commit -Repository 'https://github.com/other/repository.git'
    Assert-Throws { Get-MaintenancePackageCommit -Package 'Microsoft.Identity.Client' -Version '4.64.0' -PackagePath $invalidPackage } '*official upstream repository*'
    Assert-Throws { Get-MaintenancePackageCommit -Package 'Microsoft.Identity.Client' -Version '0.0.1' -PackagePath $packagePath } '*Unexpected package identity*'
    foreach ($invalidCommit in @('', 'short-commit')) {
        $invalidCommitPath = Join-Path $scratch ('invalid-commit-' + [guid]::NewGuid() + '.nupkg')
        New-TestPackage -Path $invalidCommitPath -Package 'Microsoft.Identity.Client' -Version '4.64.0' -Commit $invalidCommit
        Assert-Throws { Get-MaintenancePackageCommit -Package 'Microsoft.Identity.Client' -Version '4.64.0' -PackagePath $invalidCommitPath } '*must identify a full source commit*'
    }
    & {
        $global:maintenanceSourceFixture = @{ git = (Get-Command git -CommandType Application | Select-Object -First 1).Source; remote = $sourcePath; commit = $commit }
        function git {
            $arguments = @($args | ForEach-Object {
                if ($_ -ceq 'https://github.com/AzureAD/microsoft-authentication-library-for-dotnet.git') { $global:maintenanceSourceFixture.remote } else { $_ }
            })
            & $global:maintenanceSourceFixture.git @arguments
        }
        function Invoke-WebRequest {
            param([string] $Uri, [string] $OutFile, [int] $TimeoutSec)
            Assert-True ($Uri.StartsWith('https://www.nuget.org/api/v2/package/Microsoft.Identity.Client/')) 'Unexpected synthetic package URL.'
            New-TestPackage -Path $OutFile -Package 'Microsoft.Identity.Client' -Version $Uri.Split('/')[-1] -Commit $global:maintenanceSourceFixture.commit
        }
        try {
            foreach ($tagCase in @('matches', 'differs', 'unavailable')) {
                if ($tagCase -ceq 'differs') {
                    'second synthetic commit' | Set-Content -LiteralPath (Join-Path $sourcePath 'second.txt')
                    & git -C $sourcePath add second.txt
                    & git -C $sourcePath -c user.name=MaintenanceTests -c user.email=maintenance@example.invalid commit --quiet -m second
                    if ($LASTEXITCODE -ne 0) { throw 'Cannot create advisory-tag fixture.' }
                    & git -C $sourcePath tag --force $console.versionSpec | Out-Null
                } elseif ($tagCase -ceq 'unavailable') {
                    & git -C $sourcePath tag --delete $console.versionSpec | Out-Null
                }
                $outputPath = Join-Path $scratch "acquire-$tagCase"
                $preparedPath = & (Join-Path $PSScriptRoot 'Get-MaintenanceSourceEvidence.ps1') -TargetVersion $console.versionSpec -SampleId 'console-cli' -OutputDirectory $outputPath
                $prepared = Get-Content -LiteralPath $preparedPath -Raw | ConvertFrom-Json
                Assert-True ($prepared.sourceProvenance -ceq 'nuget-repository-commit' -and $prepared.releases[0].commit -ceq $commit -and $prepared.releases[0].tagObservation.status -ceq $tagCase) 'Advisory tag changed package-commit acquisition.'
                & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -Package 'Microsoft.Identity.Client' -ExpectedVersion $console.versionSpec -EvidenceManifest $preparedPath -CheckOnly
            }
            $wrongCommitPackage = Join-Path $scratch 'wrong-commit.nupkg'
            $secondCommit = (& git -C $sourcePath rev-parse HEAD).Trim()
            New-TestPackage -Path $wrongCommitPackage -Package 'Microsoft.Identity.Client' -Version $console.versionSpec -Commit $secondCommit
            $preparedPackage = Join-Path (Split-Path $preparedPath -Parent) "$($console.versionSpec).nupkg"
            Copy-Item -LiteralPath $wrongCommitPackage -Destination $preparedPackage -Force
            Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion $console.versionSpec -EvidenceManifest $preparedPath -CheckOnly } '*Original NuGet package evidence changed*'
            $prepared.releases[0].packageSha256 = (Get-FileHash -LiteralPath $preparedPackage -Algorithm SHA256).Hash
            $prepared | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $preparedPath
            Assert-Throws { & (Join-Path $PSScriptRoot 'Validate-Maintenance.ps1') -ExpectedVersion $console.versionSpec -EvidenceManifest $preparedPath -CheckOnly } '*does not match the original NuGet-recorded commit*'
            $global:maintenanceSourceFixture.commit = '0000000000000000000000000000000000000000'
            Assert-Throws { & (Join-Path $PSScriptRoot 'Get-MaintenanceSourceEvidence.ps1') -TargetVersion $console.versionSpec -SampleId 'console-cli' -OutputDirectory (Join-Path $scratch 'unavailable-commit') } '*Cannot anonymously fetch NuGet-recorded source commit*'
        } finally {
            Remove-Variable maintenanceSourceFixture -Scope Global
        }
    }
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