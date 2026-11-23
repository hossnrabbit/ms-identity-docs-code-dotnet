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