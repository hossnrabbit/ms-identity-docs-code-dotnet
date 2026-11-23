param(
    [string] $Package,
    [string] $RepositoryRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Maintenance.Common.ps1')
$catalog = @(Get-MaintenanceSamples -RepositoryRoot $RepositoryRoot)
$packages = if ($Package) { @($Package) } else {
    @($catalog | ForEach-Object { $_.references } | ForEach-Object { $_.package } | Sort-Object -Unique)
}
foreach ($packageId in $packages) {
    $source = Get-MaintenanceSource -Package $packageId
    $samples = @(Select-MaintenanceSamples -Samples $catalog -Package $packageId)
    $index = Invoke-RestMethod -Uri "https://api.nuget.org/v3-flatcontainer/$($packageId.ToLowerInvariant())/index.json" -TimeoutSec 30 -MaximumRedirection 0
    $stable = @($index.versions | Where-Object { $_ -is [string] -and $_ -cmatch '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version] $_ } -Descending)
    if (!$stable.Count) { throw "NuGet returned no supported stable versions for $packageId." }
    $target = $stable[0]
    $updates = @($samples | Where-Object {
        $_.versionSpec -match '^\d+\.\d+\.\d+$' -and [version] $_.versionSpec -lt [version] $target
    })
    $floating = @($samples | Where-Object { $_.versionSpec -match '^\d+\.\*$' })
    [pscustomobject]@{
        package = $packageId
        repository = $source.repository
        version = $target
        releaseUrl = $source.releaseBaseUrl + $target
        updateAvailable = ($updates.Count -gt 0)
        projects = @($updates | ForEach-Object { $_.project })
        unresolvedProjects = @($floating | ForEach-Object { $_.project })
    }
}