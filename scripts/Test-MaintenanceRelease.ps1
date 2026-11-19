$ErrorActionPreference = 'Stop'
$state = @{ versions = @('4.9.0', '4.100.0', '99.0.0-preview.1') }
function Invoke-RestMethod {
    param($Uri, $TimeoutSec, $MaximumRedirection)
    if ($Uri -cne 'https://api.nuget.org/v3-flatcontainer/microsoft.identity.client/index.json' -or
        $TimeoutSec -ne 30 -or $MaximumRedirection -ne 0) { throw 'Unexpected network request.' }
    @{ versions = $state.versions }
}
function dotnet { throw 'SDK execution is forbidden in discovery tests.' }
function Assert-Release {
    param([bool] $Condition, [string] $Message)
    if (!$Condition) { throw $Message }
}
$result = & (Join-Path $PSScriptRoot 'Find-MaintenanceRelease.ps1')
Assert-Release ($result.package -ceq 'Microsoft.Identity.Client' -and $result.version -ceq '4.100.0') 'Wrong package or stable numeric version.'
Assert-Release ($result.releaseUrl -ceq 'https://github.com/AzureAD/microsoft-authentication-library-for-dotnet/releases/tag/4.100.0') 'Wrong SDK release URL.'
Assert-Release ($result.updateAvailable -and $result.projects.Count -gt 0) 'Exact outdated samples were not selected.'
$allowed = @('console-cli/cli.csproj', 'desktop-winforms/MsalExample.csproj', 'desktop-winui/WinUIApp.csproj', 'desktop-wpf/MsalExample.csproj', 'xplat-maui/XPlat.csproj')
Assert-Release (@(@($result.projects) + @($result.unresolvedProjects) | Where-Object { $_ -cnotin $allowed }).Count -eq 0) 'Non-direct sample selected.'
. (Join-Path $PSScriptRoot 'Maintenance.Common.ps1')
$floating = @(Get-MaintenanceSamples | Where-Object { $_.dependencyKind -eq 'direct-msal-net' -and $_.versionSpec -match '^\d+\.\*$' })
Assert-Release ($result.unresolvedProjects.Count -eq $floating.Count) 'Floating references must remain unresolved without restores.'
$state.versions = @('0.0.1')
$result = & (Join-Path $PSScriptRoot 'Find-MaintenanceRelease.ps1')
Assert-Release (!$result.updateAvailable -and $result.projects.Count -eq 0) 'Discovery must never downgrade.'
$state.versions = @('99.0.0-preview', 'invalid')
$failed = $false
try { & (Join-Path $PSScriptRoot 'Find-MaintenanceRelease.ps1') | Out-Null } catch { $failed = $true }
Assert-Release $failed 'Unsupported feed versions must fail closed.'
function Invoke-RestMethod { throw 'Simulated feed failure' }
$failed = $false
try { & (Join-Path $PSScriptRoot 'Find-MaintenanceRelease.ps1') | Out-Null } catch { $failed = $true }
Assert-Release $failed 'Feed failure must not imply no update.'
'PASS: offline MSAL.NET discovery checks (mocked feed; no SDK execution).'