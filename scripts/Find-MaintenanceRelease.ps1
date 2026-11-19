param([string] $RepositoryRoot = (Split-Path $PSScriptRoot -Parent))

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Maintenance.Common.ps1')
$samples = @(Select-MsalSamples -Samples @(Get-MaintenanceSamples -RepositoryRoot $RepositoryRoot))
$index = Invoke-RestMethod -Uri 'https://api.nuget.org/v3-flatcontainer/microsoft.identity.client/index.json' -TimeoutSec 30 -MaximumRedirection 0
$stable = @($index.versions | Where-Object { $_ -is [string] -and $_ -cmatch '^\d+\.\d+\.\d+$' } |
    Sort-Object { [version] $_ } -Descending)
if (!$stable.Count) { throw 'NuGet returned no supported stable MSAL.NET versions.' }
$target = $stable[0]
$updates = @($samples | Where-Object {
    $_.versionSpec -match '^\d+\.\d+\.\d+$' -and [version] $_.versionSpec -lt [version] $target
})
$floating = @($samples | Where-Object { $_.versionSpec -match '^\d+\.\*$' })
[pscustomobject]@{
    package = 'Microsoft.Identity.Client'
    version = $target
    releaseUrl = "https://github.com/AzureAD/microsoft-authentication-library-for-dotnet/releases/tag/$target"
    updateAvailable = ($updates.Count -gt 0)
    projects = @($updates | ForEach-Object { $_.project })
    unresolvedProjects = @($floating | ForEach-Object { $_.project })
}