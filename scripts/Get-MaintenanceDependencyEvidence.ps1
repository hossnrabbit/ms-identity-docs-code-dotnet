[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $EvidenceManifest,
    [Parameter(Mandatory)][string] $SampleId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Maintenance.Common.ps1')
$primary = Get-Content -LiteralPath $EvidenceManifest -Raw | ConvertFrom-Json
if ($primary.schemaVersion -ne 2 -or $primary.sourceProvenance -cne 'nuget-repository-commit' -or
    $primary.package -cne 'Microsoft.Identity.Web' -or
    $primary.repository -cne (Get-MaintenanceSource -Package $primary.package).repositoryUrl) {
    throw 'Supplemental evidence requires original verified Microsoft.Identity.Web evidence.'
}
$sample = @(Select-MaintenanceSamples -Samples @(Get-MaintenanceSamples) -Package $primary.package -SampleId $SampleId)
$record = @($primary.samples | Where-Object id -CEQ $SampleId)
if ($sample.Count -ne 1 -or $record.Count -ne 1 -or $record[0].project -cne $sample[0].project -or
    $record[0].originalVersion -cne $sample[0].versionSpec -or $record[0].status -cnotin @('update', 'current') -or
    $sample[0].platform -cne 'any' -or $sample[0].frameworks.Count -ne 1) {
    throw 'Supplemental evidence requires one pristine applicable cross-platform sample.'
}
$output = Join-Path (Split-Path $EvidenceManifest -Parent) 'dependencies'
if (Test-Path -LiteralPath $output) { throw 'Supplemental evidence already exists; do not replace original evidence.' }
$originalPath = Join-Path (Split-Path $PSScriptRoot -Parent) $sample[0].project
$originalHash = (Get-FileHash -LiteralPath $originalPath -Algorithm SHA256).Hash
[xml] $original = Get-Content -LiteralPath $originalPath -Raw
$references = @($original.SelectNodes('//PackageReference'))
if (@($references | Where-Object { $_.HasAttribute('Condition') -or $_.ParentNode.HasAttribute('Condition') -or
    !$_.HasAttribute('Include') -or !$_.HasAttribute('Version') }).Count) {
    throw 'Conditional or externally versioned references need an explicitly scoped restore strategy.'
}
New-Item -ItemType Directory -Path $output | Out-Null
$configPath = Join-Path $output 'NuGet.Config'
'<configuration><packageSources><clear/><add key="nuget.org" value="https://www.nuget.org/api/v2/"/></packageSources></configuration>' |
    Set-Content -LiteralPath $configPath -Encoding utf8
$artifacts = [System.Collections.Generic.List[object]]::new()
$artifacts.Add([ordered]@{ path = $configPath; sha256 = (Get-FileHash $configPath -Algorithm SHA256).Hash })
$releases = @{}
$graphs = @()
$auxiliaryPackage = 'Microsoft.Identity.Abstractions'
$source = Get-MaintenanceSource -Package $auxiliaryPackage
$sourcePath = Join-Path $output 'sdk'
$previousPrompt = $env:GIT_TERMINAL_PROMPT
$env:GIT_TERMINAL_PROMPT = '0'
try {
    & git -c credential.helper= -c http.extraHeader= init --quiet $sourcePath
    if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize supplemental source repository.' }
    foreach ($phase in @('baseline', 'target')) {
        $version = if ($phase -ceq 'baseline') { $record[0].baselineVersion } else { $primary.targetVersion }
        $graphDirectory = Join-Path $output $phase
        New-Item -ItemType Directory -Path $graphDirectory | Out-Null
        [xml] $project = '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework /></PropertyGroup><ItemGroup /></Project>'
        $project.Project.PropertyGroup.TargetFramework = [string] $sample[0].frameworks[0]
        foreach ($reference in $references) {
            $copy = $project.ImportNode($reference, $true)
            if ($copy.GetAttribute('Include') -ceq $primary.package) { $copy.SetAttribute('Version', $version) }
            $project.SelectSingleNode('//ItemGroup').AppendChild($copy) | Out-Null
        }
        $projectPath = Join-Path $graphDirectory 'Resolve.csproj'
        $project.Save($projectPath)
        & dotnet restore $projectPath --configfile $configPath --packages (Join-Path $output 'packages') --force-evaluate --verbosity minimal '-p:NuGetAudit=false' | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Supplemental $phase dependency restore failed; do not infer compatibility." }
        $assetsPath = Join-Path $graphDirectory 'obj/project.assets.json'
        $assets = Get-Content -LiteralPath $assetsPath -Raw | ConvertFrom-Json
        $matches = @($assets.libraries.PSObject.Properties.Name | Where-Object { $_ -cmatch '^Microsoft\.Identity\.Abstractions/\d+\.\d+\.\d+$' })
        if ($matches.Count -ne 1 -or $assets.libraries.PSObject.Properties.Name -cnotcontains "$($primary.package)/$version") {
            throw 'Restore did not resolve the expected exact Web and Abstractions package identities.'
        }
        $auxiliaryVersion = $matches[0].Split('/')[1]
        foreach ($path in @($projectPath, $assetsPath)) {
            $artifacts.Add([ordered]@{ path = $path; sha256 = (Get-FileHash $path -Algorithm SHA256).Hash })
        }
        $graphs += [ordered]@{ phase = $phase; version = $version; projectPath = $projectPath; assetsPath = $assetsPath; abstractionsVersion = $auxiliaryVersion }
        if (!$releases.ContainsKey($auxiliaryVersion)) {
            $packagePath = Join-Path $output ("packages/microsoft.identity.abstractions/$auxiliaryVersion/microsoft.identity.abstractions.$auxiliaryVersion.nupkg")
            $commit = Get-MaintenancePackageCommit -Package $auxiliaryPackage -Version $auxiliaryVersion -PackagePath $packagePath
            & git -c credential.helper= -c http.extraHeader= -C $sourcePath fetch --quiet --no-tags --depth=1 $source.repositoryUrl $commit
            if ($LASTEXITCODE -ne 0) { throw 'Cannot anonymously fetch NuGet-recorded Abstractions source commit.' }
            $actual = (& git -C $sourcePath rev-parse 'FETCH_HEAD^{commit}').Trim()
            if ($LASTEXITCODE -ne 0 -or $actual -ine $commit) { throw 'Supplemental source commit does not match NuGet metadata.' }
            $checkout = Join-Path $output "sources/$auxiliaryVersion"
            & git -C $sourcePath worktree add --quiet --detach $checkout $commit
            if ($LASTEXITCODE -ne 0) { throw 'Cannot materialize supplemental Abstractions source.' }
            $artifacts.Add([ordered]@{ path = $packagePath; sha256 = (Get-FileHash $packagePath -Algorithm SHA256).Hash })
            $releases[$auxiliaryVersion] = [ordered]@{ package = $auxiliaryPackage; version = $auxiliaryVersion; repository = $source.repositoryUrl; commit = $commit; sourcePath = $checkout; packagePath = $packagePath }
        }
    }
    if ((Get-FileHash -LiteralPath $originalPath -Algorithm SHA256).Hash -cne $originalHash) { throw 'Original sample project changed during supplemental setup.' }
    $manifestPath = Join-Path $output 'manifest.json'
    [ordered]@{
        schemaVersion = 1
        sourceProvenance = 'nuget-repository-commit'
        primaryManifestSha256 = (Get-FileHash $EvidenceManifest -Algorithm SHA256).Hash
        sampleId = $SampleId
        project = $sample[0].project
        originalProjectSha256 = $originalHash
        graphs = $graphs
        releases = @($releases.Values | Sort-Object version)
        artifacts = @($artifacts.ToArray())
        limitations = 'Isolated package-only restore graphs preserve direct references except the selected Web version. No application or downloaded SDK build scripts execute. Source/contracts and restore success are not runtime compatibility proof. Release tags are not used as source substitutes.'
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    Write-Host "PASS: baseline/target dependency graphs and NuGet-recorded Abstractions source for $SampleId; original project unchanged."
    Write-Output $manifestPath
} finally { $env:GIT_TERMINAL_PROMPT = $previousPrompt }