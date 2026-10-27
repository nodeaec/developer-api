<#
.SYNOPSIS
    Automates building, packaging, and publishing a .NET Revit plugin to Node.aec.
.PARAMETER ProductSlug
    The human-readable slug of the product on Node.aec.
.PARAMETER Version
    The semantic version string to release (e.g. 1.2.0).
.PARAMETER Configuration
    The build configuration (default: Release).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProductSlug,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$Configuration = "Release",

    [string]$ApiUrl = "https://api.nodeaec.com.br"
)

$ErrorActionPreference = "Stop"

$Token = $env:NODE_AEC_API_TOKEN
if (-not $Token) {
    throw "NODE_AEC_API_TOKEN environment variable is not defined."
}

Write-Host "==> Building solution for configuration: $Configuration" -ForegroundColor Cyan
dotnet build -c $Configuration

$distFolder = Join-Path $PSScriptRoot "dist"
if (-not (Test-Path $distFolder)) {
    New-Item -ItemType Directory -Path $distFolder | Out-Null
}

$zipFileName = "$ProductSlug-$Version.zip"
$zipFilePath = Join-Path $distFolder $zipFileName

Write-Host "==> Packaging release into $zipFilePath" -ForegroundColor Cyan
if (Test-Path $zipFilePath) { Remove-Item $zipFilePath -Force }
Compress-Archive -Path "bin/$Configuration/*" -DestinationPath $zipFilePath -Force

$headers = @{
    "Authorization" = "Bearer $Token"
}

Write-Host "==> 1. Creating version draft $Version on Node.aec..." -ForegroundColor Cyan
$versionBody = @{
    version = $Version
    description = "Release $Version built on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    allowDownload = $true
} | ConvertTo-Json

try {
    $createResult = Invoke-RestMethod -Uri "$ApiUrl/developer/products/$ProductSlug/versions" `
        -Method Post `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $versionBody
    Write-Host "Version draft created: $($createResult.version.publicId)" -ForegroundColor Green
} catch {
    $ex = $_.Exception
    Write-Warning "Version draft creation returned: $($ex.Message)"
}

Write-Host "==> 2. Uploading release binary ($zipFileName)..." -ForegroundColor Cyan
$form = @{
    file = Get-Item $zipFilePath
    name = $zipFileName
    description = "Compiled $Configuration package"
}

$uploadResult = Invoke-RestMethod -Uri "$ApiUrl/developer/products/$ProductSlug/versions/$Version/files/upload" `
    -Method Post `
    -Headers $headers `
    -Form $form

Write-Host "File uploaded: $($uploadResult.file.publicId) (SHA-256: $($uploadResult.file.sha256.Substring(0, 16))...)" -ForegroundColor Green

Write-Host "==> 3. Submitting Security Manifest for curation review..." -ForegroundColor Cyan
$manifestBody = @{
    securityManifest = @{
        network = @{
            hasAccess = $false
            purpose = ""
            domains = @()
        }
        filesystem = @{
            hasAccess = $true
            scope = "Reads open Revit active documents; writes exported clash matrix datasets."
        }
        processes = @{
            hasAccess = $false
            justification = ""
        }
        nativeCalls = @{
            hasAccess = $false
            libraries = @()
        }
        registry = @{
            hasAccess = $false
            keys = @()
        }
        telemetry = @{
            hasAccess = $false
            fields = @()
            purpose = ""
        }
    }
} | ConvertTo-Json -Depth 5

$submitResult = Invoke-RestMethod -Uri "$ApiUrl/developer/products/$ProductSlug/versions/$Version/submissions" `
    -Method Post `
    -Headers $headers `
    -ContentType "application/json" `
    -Body $manifestBody

Write-Host "==> Successfully submitted $ProductSlug v$Version for Node.aec curation review!" -ForegroundColor Green
Write-Host "Submission ID: $($submitResult.submission.publicId) (Status: $($submitResult.submission.status))" -ForegroundColor Yellow
