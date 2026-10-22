[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+\.\d+(?:\.\d+)?(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$')]
    [string] $ExpectedVersion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectPath = Join-Path $PSScriptRoot '../console-cli/cli.csproj'
[xml] $project = Get-Content -LiteralPath $projectPath -Raw
if ($project.Project.PropertyGroup.TargetFramework -ne 'net8.0') {
    throw 'The pilot must retain its net8.0 target.'
}
$references = @($project.SelectNodes('//PackageReference[@Include="Microsoft.Identity.Client"]'))
if ($references.Count -ne 1) {
    throw 'Expected one direct Microsoft.Identity.Client package reference.'
}
$version = $references[0].GetAttribute('Version')
if ($version -notmatch '^\d+\.\d+\.\d+(?:\.\d+)?(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$') {
    throw 'Microsoft.Identity.Client must use an exact package version.'
}
if ($ExpectedVersion -and $version -cne $ExpectedVersion) {
    throw "Expected Microsoft.Identity.Client $ExpectedVersion but found $version."
}

Write-Host "Validating console-cli with Microsoft.Identity.Client $version."
& dotnet restore $projectPath --verbosity minimal
if ($LASTEXITCODE -ne 0) { throw 'Sample restore failed.' }
& dotnet build $projectPath --configuration Release --no-restore --verbosity minimal
if ($LASTEXITCODE -ne 0) { throw 'Sample build failed.' }
Write-Host 'PASS: project checks, restore, and Release build. Unit tests: NOT AVAILABLE. Sign-in: NOT RUN.'