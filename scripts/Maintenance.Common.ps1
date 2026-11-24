Set-StrictMode -Version Latest

function Get-MaintenanceSamples {
    param(
        [string] $RepositoryRoot = (Split-Path $PSScriptRoot -Parent),
        [string] $CatalogPath = (Join-Path $PSScriptRoot 'maintenance-samples.json')
    )

    $catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
    if ($catalog.schemaVersion -ne 1) { throw 'Unsupported sample catalog schema.' }
    $ids = @($catalog.samples.id)
    $projects = @($catalog.samples.project)
    if (@($ids | Select-Object -Unique).Count -ne $ids.Count -or
        @($projects | Select-Object -Unique).Count -ne $projects.Count) {
        throw 'Sample IDs and projects must be unique.'
    }
    $actualProjects = @(Get-ChildItem -LiteralPath $RepositoryRoot -Directory |
        Where-Object Name -NotLike '.*' | ForEach-Object {
            $directory = $_
            Get-ChildItem -LiteralPath $directory.FullName -File -Filter '*.csproj' |
                ForEach-Object { "$($directory.Name)/$($_.Name)" }
        })
    if (Compare-Object @($projects | Sort-Object) @($actualProjects | Sort-Object)) {
        throw 'The catalog must inventory every sample project.'
    }
    foreach ($sample in $catalog.samples) {
        if ($sample.id -notmatch '^[a-z][a-z0-9-]+$' -or
            $sample.project -notmatch ('^' + [regex]::Escape($sample.id) + '/[^/\\]+\.csproj$') -or
            $sample.platform -notin @('any', 'windows', 'maui')) {
            throw 'Invalid sample path or platform in catalog.'
        }
        [xml] $project = Get-Content -LiteralPath (Join-Path $RepositoryRoot $sample.project) -Raw
        $frameworks = @($project.SelectNodes('//TargetFramework | //TargetFrameworks') |
            ForEach-Object { $_.InnerText })
        if (Compare-Object @($sample.frameworks) $frameworks) {
            throw "Target frameworks changed for $($sample.id)."
        }
        $direct = @($project.SelectNodes('//PackageReference[@Include="Microsoft.Identity.Client"]'))
        $idweb = @($project.SelectNodes('//PackageReference[starts-with(@Include,"Microsoft.Identity.Web")]'))
        $browser = @($project.SelectNodes('//PackageReference[@Include="Microsoft.Authentication.WebAssembly.Msal"]'))
        $valid = switch ($sample.dependencyKind) {
            'direct-msal-net' { $direct.Count -eq 1 }
            'msal-net-via-idweb' { !$direct.Count -and $idweb.Count -gt 0 }
            'idweb' { !$direct.Count -and $idweb.Count -gt 0 }
            'browser-msal' { !$direct.Count -and $browser.Count -eq 1 }
            'easy-auth' { !$direct.Count -and !$idweb.Count -and !$browser.Count }
            default { $false }
        }
        if (!$valid) { throw "Dependency classification changed for $($sample.id)." }
        $references = @($project.SelectNodes('//PackageReference') | Where-Object {
            $_.GetAttribute('Include') -ceq 'Microsoft.Identity.Client' -or
            $_.GetAttribute('Include') -cmatch '^Microsoft\.Identity\.Web(?:\.[A-Za-z0-9]+)*$'
        } | ForEach-Object {
            $referenceVersion = $_.GetAttribute('Version')
            if ($referenceVersion -notmatch '^\d+\.\d+\.\d+$|^\d+\.\*$') {
                throw "Unsupported identity package reference for $($sample.id)."
            }
            [pscustomobject]@{ package = $_.GetAttribute('Include'); versionSpec = $referenceVersion }
        })
        if (@($references | ForEach-Object { $_.package } | Select-Object -Unique).Count -ne $references.Count) {
            throw "Duplicate identity package references for $($sample.id)."
        }
        $sample | Add-Member -NotePropertyName references -NotePropertyValue $references
        if ($direct.Count) {
            $versionSpec = $direct[0].GetAttribute('Version')
            if ($versionSpec -notmatch '^\d+\.\d+\.\d+$|^\d+\.\*$') {
                throw "Unsupported MSAL version reference for $($sample.id)."
            }
            $sample | Add-Member -NotePropertyName versionSpec -NotePropertyValue $versionSpec
        }
        $sample
    }
}

function Get-MaintenanceSource {
    param([Parameter(Mandatory)][string] $Package)

    $repository = if ($Package -ceq 'Microsoft.Identity.Client') {
        'AzureAD/microsoft-authentication-library-for-dotnet'
    } elseif ($Package -ceq 'Microsoft.Identity.Abstractions') {
        'AzureAD/microsoft-identity-abstractions-for-dotnet'
    } elseif ($Package -cmatch '^Microsoft\.Identity\.Web(?:\.[A-Za-z0-9]+)*$') {
        'AzureAD/microsoft-identity-web'
    } else { throw 'Unsupported identity package.' }
    [pscustomobject]@{
        package = $Package
        repository = $repository
        repositoryUrl = "https://github.com/$repository.git"
        releaseBaseUrl = "https://github.com/$repository/releases/tag/"
    }
}

function Get-MaintenancePackageCommit {
    param([string] $Package, [string] $Version, [string] $PackagePath)

    $source = Get-MaintenanceSource -Package $Package
    $archive = [System.IO.Compression.ZipFile]::OpenRead($PackagePath)
    try {
        $entries = @($archive.Entries | Where-Object FullName -ceq "$Package.nuspec")
        if ($entries.Count -ne 1) { throw 'Package must contain exactly one expected nuspec.' }
        $reader = [System.IO.StreamReader]::new($entries[0].Open())
        try { [xml] $nuspec = $reader.ReadToEnd() } finally { $reader.Dispose() }
    } finally { $archive.Dispose() }
    $metadata = $nuspec.SelectSingleNode('/*[local-name()="package"]/*[local-name()="metadata"]')
    if (!$metadata) { throw 'Package metadata is missing.' }
    $identity = $metadata.SelectSingleNode('*[local-name()="id"]')
    $versionNode = $metadata.SelectSingleNode('*[local-name()="version"]')
    $repository = $metadata.SelectSingleNode('*[local-name()="repository"]')
    if (!$identity -or !$versionNode -or !$repository -or $identity.InnerText -cne $Package -or $versionNode.InnerText -cne $Version) {
        throw 'Unexpected package identity or missing repository metadata.'
    }
    $allowedUrls = @($source.repositoryUrl, $source.repositoryUrl.Substring(0, $source.repositoryUrl.Length - 4))
    if ($repository.GetAttribute('url').TrimEnd('/') -notin $allowedUrls) {
        throw 'Package repository metadata does not identify the selected official upstream repository.'
    }
    $commit = $repository.GetAttribute('commit')
    if ($commit -notmatch '^[0-9a-fA-F]{40}$') { throw 'Package must identify a full source commit.' }
    $commit.ToLowerInvariant()
}

function Test-MaintenanceDependencyEvidence {
    param([Parameter(Mandatory)][string] $EvidenceManifest, [switch] $SetupCheck)

    $path = Join-Path (Split-Path $EvidenceManifest -Parent) 'dependencies/manifest.json'
    if (!(Test-Path -LiteralPath $path)) {
        if (Test-Path -LiteralPath (Split-Path $path -Parent)) { throw 'Supplemental evidence directory is incomplete.' }
        return
    }
    $primary = Get-Content -LiteralPath $EvidenceManifest -Raw | ConvertFrom-Json
    $evidence = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($evidence.schemaVersion -ne 1 -or $evidence.sourceProvenance -cne 'nuget-repository-commit' -or
        $primary.package -cne 'Microsoft.Identity.Web' -or
        (Get-FileHash $EvidenceManifest -Algorithm SHA256).Hash -ine $evidence.primaryManifestSha256) {
        throw 'Supplemental evidence does not match the original Web source manifest.'
    }
    $sample = @(Select-MaintenanceSamples -Samples @(Get-MaintenanceSamples) -Package $primary.package -SampleId $evidence.sampleId)
    $record = @($primary.samples | Where-Object id -CEQ $evidence.sampleId)
    if ($sample.Count -ne 1 -or $record.Count -ne 1 -or $record[0].project -cne $evidence.project -or $sample[0].project -cne $evidence.project -or
        $record[0].status -cnotin @('update', 'current') -or $evidence.graphs.Count -ne 2 -or
        @($evidence.graphs.phase | Select-Object -Unique).Count -ne 2 -or
        @($evidence.artifacts.path | Select-Object -Unique).Count -ne $evidence.artifacts.Count) {
        throw 'Invalid supplemental sample, graph, or artifact inventory.'
    }
    $projectPath = Join-Path (Split-Path $PSScriptRoot -Parent) $sample[0].project
    if ($SetupCheck -and (Get-FileHash $projectPath -Algorithm SHA256).Hash -ine $evidence.originalProjectSha256) {
        throw 'Supplemental setup requires the pristine original sample project.'
    }
    [xml] $original = Get-Content -LiteralPath $projectPath -Raw
    $requiredPaths = @(Join-Path (Split-Path $path -Parent) 'NuGet.Config')
    foreach ($graph in $evidence.graphs) {
        $version = switch ($graph.phase) {
            'baseline' { $record[0].baselineVersion }
            'target' { $primary.targetVersion }
            default { throw 'Unknown supplemental graph phase.' }
        }
        if ($graph.version -cne $version) { throw 'Supplemental graph version does not match original evidence.' }
        [xml] $project = Get-Content -LiteralPath $graph.projectPath -Raw
        $actual = @($project.SelectNodes('//PackageReference'))
        $expected = @($original.SelectNodes('//PackageReference'))
        if ($project.Project.GetAttribute('Sdk') -cne 'Microsoft.NET.Sdk' -or
            $project.SelectSingleNode('//TargetFramework').InnerText -cne $sample[0].frameworks[0] -or
            $actual.Count -ne $expected.Count) { throw 'Supplemental restore project changed framework or reference shape.' }
        foreach ($reference in $expected) {
            $copy = $reference.CloneNode($true)
            if ($copy.GetAttribute('Include') -ceq $primary.package) { $copy.SetAttribute('Version', $version) }
            $match = @($actual | Where-Object { $_.GetAttribute('Include') -ceq $copy.GetAttribute('Include') })
            if ($match.Count -ne 1 -or $match[0].OuterXml -cne $copy.OuterXml) { throw 'Supplemental restore changed an unrelated direct package reference.' }
        }
        $assets = Get-Content -LiteralPath $graph.assetsPath -Raw | ConvertFrom-Json
        if ($assets.libraries.PSObject.Properties.Name -cnotcontains "$($primary.package)/$version" -or
            $assets.libraries.PSObject.Properties.Name -cnotcontains "Microsoft.Identity.Abstractions/$($graph.abstractionsVersion)") {
            throw 'Supplemental dependency graph does not match its exact package identities.'
        }
        $requiredPaths += @($graph.projectPath, $graph.assetsPath)
    }
    if (@($evidence.releases.version | Select-Object -Unique).Count -ne $evidence.releases.Count -or
        (Compare-Object @($evidence.graphs.abstractionsVersion | Sort-Object -Unique) @($evidence.releases.version | Sort-Object -Unique))) {
        throw 'Supplemental source inventory does not cover the resolved Abstractions versions.'
    }
    foreach ($release in $evidence.releases) {
        if ($release.package -cne 'Microsoft.Identity.Abstractions' -or $release.version -notmatch '^\d+\.\d+\.\d+$' -or
            $release.repository -cne (Get-MaintenanceSource -Package $release.package).repositoryUrl -or
            $release.commit -notmatch '^[0-9a-fA-F]{40}$') { throw 'Invalid supplemental source identity.' }
        $head = & git -C $release.sourcePath rev-parse HEAD
        if ($LASTEXITCODE -ne 0 -or $head.Trim() -ine $release.commit) { throw 'Supplemental source does not match its recorded commit.' }
        $changes = @(& git -C $release.sourcePath status --porcelain)
        if ($LASTEXITCODE -ne 0 -or $changes.Count) { throw 'Supplemental source checkout changed.' }
        if ((Get-MaintenancePackageCommit -Package $release.package -Version $release.version -PackagePath $release.packagePath) -ine $release.commit) {
            throw 'Supplemental source does not match the NuGet-recorded commit.'
        }
        $requiredPaths += $release.packagePath
    }
    if (Compare-Object @($requiredPaths | Sort-Object) @($evidence.artifacts.path | Sort-Object)) {
        throw 'Supplemental snapshot inventory is incomplete.'
    }
    foreach ($artifact in $evidence.artifacts) {
        if ((Get-FileHash -LiteralPath $artifact.path -Algorithm SHA256).Hash -ine $artifact.sha256) {
            throw 'Original supplemental evidence artifact changed.'
        }
    }
    Write-Host 'PASS: original supplemental restore graphs, direct references, packages, and NuGet-recorded source commits are unchanged.'
}

function Select-MaintenanceSamples {
    param([object[]] $Samples, [string] $Package = 'Microsoft.Identity.Client', [string[]] $SampleId)

    Get-MaintenanceSource -Package $Package | Out-Null
    if ($Package -cnotin @($Samples | ForEach-Object { $_.references } | ForEach-Object { $_.package })) { throw 'No cataloged sample directly references this package.' }
    foreach ($id in $SampleId) {
        $sample = @($Samples | Where-Object id -CEQ $id)
        if ($sample.Count -ne 1) { throw "Unknown sample: $id" }
        if ($Package -cnotin @($sample[0].references | ForEach-Object { $_.package })) {
            if ($Package -ceq 'Microsoft.Identity.Client') { throw "$id is not a direct MSAL.NET maintenance target; do not add an MSAL reference." }
            throw "$id does not directly reference $Package; do not introduce a dependency."
        }
    }
    foreach ($sample in $Samples) {
        if ($SampleId -and $sample.id -cnotin $SampleId) { continue }
        $reference = @($sample.references | Where-Object package -CEQ $Package)
        if (!$reference.Count) { continue }
        $selection = $sample.PSObject.Copy()
        $selection | Add-Member -NotePropertyName versionSpec -NotePropertyValue $reference[0].versionSpec -Force
        $selection | Add-Member -NotePropertyName package -NotePropertyValue $Package
        $selection
    }
}

function Select-MsalSamples {
    param([object[]] $Samples, [string[]] $SampleId)

    if ($SampleId) {
        foreach ($id in $SampleId) {
            if ($id -notin @($Samples.id)) { throw "Unknown sample: $id" }
            if (($Samples | Where-Object id -EQ $id).dependencyKind -ne 'direct-msal-net') {
                throw "$id is not a direct MSAL.NET maintenance target; do not add an MSAL reference."
            }
        }
    }
    $Samples | Where-Object {
        $_.dependencyKind -eq 'direct-msal-net' -and (!$SampleId -or $_.id -in $SampleId)
    }
}

function Resolve-MsalBaseline {
    param([Parameter(Mandatory)][string] $VersionSpec, [string] $Package = 'Microsoft.Identity.Client')

    Get-MaintenanceSource -Package $Package | Out-Null
    if ($VersionSpec -match '^\d+\.\d+\.\d+$') { return $VersionSpec }
    if ($VersionSpec -notmatch '^\d+\.\*$') { throw 'Unsupported floating MSAL version.' }
    $scratch = Join-Path ([IO.Path]::GetTempPath()) ('msal-resolve-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $scratch | Out-Null
    try {
        $projectPath = Join-Path $scratch 'Resolve.csproj'
        '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="{0}" Version="{1}" /></ItemGroup></Project>' -f $Package, $VersionSpec |
            Set-Content -LiteralPath $projectPath -Encoding utf8
        $configPath = Join-Path $scratch 'NuGet.Config'
        '<configuration><packageSources><clear/><add key="nuget.org" value="https://www.nuget.org/api/v2/"/></packageSources></configuration>' |
            Set-Content -LiteralPath $configPath -Encoding utf8
        & dotnet restore $projectPath --configfile $configPath --force-evaluate --verbosity quiet '-p:NuGetAudit=false' | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve floating MSAL reference using official NuGet.' }
        $assets = Get-Content -LiteralPath (Join-Path $scratch 'obj/project.assets.json') -Raw | ConvertFrom-Json
        $matches = @($assets.libraries.PSObject.Properties.Name | Where-Object { $_ -cmatch ('^' + [regex]::Escape($Package) + '/\d+\.\d+\.\d+$') })
        if ($matches.Count -ne 1) { throw 'Floating MSAL reference did not resolve to one exact stable version.' }
        return $matches[0].Split('/')[1]
    } finally {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}