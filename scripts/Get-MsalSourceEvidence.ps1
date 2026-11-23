[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $TargetVersion,
    [string] $Package = 'Microsoft.Identity.Client',
    [string] $OutputDirectory,
    [string[]] $SampleId
)

& (Join-Path $PSScriptRoot 'Get-MaintenanceSourceEvidence.ps1') @PSBoundParameters
