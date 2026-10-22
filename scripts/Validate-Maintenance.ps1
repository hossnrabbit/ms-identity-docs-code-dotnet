[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+\.\d+(?:\.\d+)?(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$')]
    [string] $ExpectedVersion,
    [string] $EvidenceManifest
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

if ($EvidenceManifest) {
    $evidence = Get-Content -LiteralPath $EvidenceManifest -Raw | ConvertFrom-Json
    if ($evidence.schemaVersion -ne 1 -or $evidence.targetVersion -cne $version -or
        $evidence.repository -cne 'https://github.com/AzureAD/microsoft-authentication-library-for-dotnet.git') {
        throw 'Source evidence does not match the sample target and official repository.'
    }
    if ([version] $evidence.baselineVersion -gt [version] $version) { throw 'Source evidence describes a downgrade.' }
    foreach ($release in $evidence.releases) {
        $actualCommit = & git -C $release.sourcePath rev-parse HEAD
        if ($LASTEXITCODE -ne 0 -or $actualCommit.Trim() -ine $release.commit) {
            throw 'A source evidence checkout does not match its recorded commit.'
        }
        $sourceChanges = @(& git -C $release.sourcePath status --porcelain)
        if ($LASTEXITCODE -ne 0 -or $sourceChanges.Count) { throw 'Source evidence checkout has changed.' }
    }
    foreach ($requiredVersion in @($evidence.baselineVersion, $evidence.targetVersion)) {
        if (@($evidence.releases | Where-Object version -eq $requiredVersion).Count -ne 1) {
            throw 'Source evidence must identify both exact baseline and target releases.'
        }
    }
    Write-Host 'PASS: original source manifest matches target and unchanged SDK checkouts.'
}

Write-Host "Validating console-cli with Microsoft.Identity.Client $version."
& dotnet restore $projectPath --verbosity minimal
if ($LASTEXITCODE -ne 0) { throw 'Sample restore failed.' }
& dotnet build $projectPath --configuration Release --no-restore --verbosity minimal
if ($LASTEXITCODE -ne 0) { throw 'Sample build failed.' }
Write-Host 'PASS: project checks, restore, and Release build. Unit tests: NOT AVAILABLE. Sign-in: NOT RUN.'