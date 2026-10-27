# CI/CD Integration Examples

This document provides complete, production-ready, copy-pasteable scripts and workflow templates to automate Node.aec releases directly from your CI/CD pipelines.

Standalone, cloneable template files are available in the [`examples/`](https://github.com/nodeaec/developer-api/tree/main/examples) directory:
- **GitHub Actions Workflow**: [`examples/github-actions/release.yml`](https://github.com/nodeaec/developer-api/blob/main/examples/github-actions/release.yml)
- **POSIX Bash Release Script**: [`examples/scripts/release.sh`](https://github.com/nodeaec/developer-api/blob/main/examples/scripts/release.sh)
- **PowerShell Release Script**: [`examples/scripts/Release-NodeAec.ps1`](https://github.com/nodeaec/developer-api/blob/main/examples/scripts/Release-NodeAec.ps1)

---

## 1. GitHub Actions Workflow (`.github/workflows/release.yml`)

> **Standalone template file**: [`examples/github-actions/release.yml`](https://github.com/nodeaec/developer-api/blob/main/examples/github-actions/release.yml)

The following workflow triggers automatically whenever a new Git release tag (e.g. `v1.2.0`) is pushed to your repository. It builds your plugin, extracts the semantic version number, creates the version draft on Node.aec, uploads the release bundle, and submits the security manifest for curation review.

### Prerequisites in GitHub Repository Settings
- In **Settings** -> **Secrets and variables** -> **Actions**, add a repository secret named `NODE_AEC_API_TOKEN` containing your Developer API token (`aec_...`).

```yaml
name: Release to Node.aec

on:
  push:
    tags:
      - 'v*.*.*'

env:
  PRODUCT_SLUG: 'smart-clash-detector'
  NODE_AEC_API_URL: 'https://api.nodeaec.com.br'

jobs:
  build-and-publish:
    runs-on: windows-latest
    steps:
      - name: Checkout Source Code
        uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Build Plugin Solution
        run: |
          dotnet restore
          dotnet build --configuration Release --no-restore

      - name: Package Release ZIP
        id: package
        shell: pwsh
        run: |
          # Strip 'v' from tag (e.g. v1.2.0 -> 1.2.0)
          $tag = "${{ github.ref_name }}"
          $version = $tag -replace '^v',''
          Write-Host "Releasing version: $version"
          echo "VERSION=$version" >> $env:GITHUB_ENV

          $distDir = "dist"
          New-Item -ItemType Directory -Force -Path $distDir
          $zipPath = "$distDir/SmartClashDetector-$version.zip"
          Compress-Archive -Path "bin/Release/*" -DestinationPath $zipPath -Force
          echo "ZIP_PATH=$zipPath" >> $env:GITHUB_ENV
          echo "ZIP_NAME=SmartClashDetector-$version.zip" >> $env:GITHUB_ENV

      - name: Create Version Draft on Node.aec
        id: create_version
        shell: bash
        env:
          TOKEN: ${{ secrets.NODE_AEC_API_TOKEN }}
        run: |
          set -euo pipefail
          echo "Creating draft version $VERSION for $PRODUCT_SLUG..."
          
          RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
            "$NODE_AEC_API_URL/developer/products/$PRODUCT_SLUG/versions" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
              \"version\": \"$VERSION\",
              \"description\": \"Automated release from GitHub Actions run #${{ github.run_number }}\",
              \"allowDownload\": true
            }")

          HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
          BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

          if [ "$HTTP_STATUS" -ne 201 ]; then
            echo "Failed to create draft version. Status: $HTTP_STATUS"
            echo "$BODY"
            exit 1
          fi

          echo "Draft version created successfully."

      - name: Upload Binary Release File
        id: upload_file
        shell: bash
        env:
          TOKEN: ${{ secrets.NODE_AEC_API_TOKEN }}
        run: |
          set -euo pipefail
          echo "Uploading $ZIP_PATH to $PRODUCT_SLUG version $VERSION..."

          UPLOAD_RESP=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
            "$NODE_AEC_API_URL/developer/products/$PRODUCT_SLUG/versions/$VERSION/files/upload" \
            -H "Authorization: Bearer $TOKEN" \
            -F "file=@$ZIP_PATH" \
            -F "name=$ZIP_NAME" \
            -F "description=Built from Git commit ${{ github.sha }}")

          UPLOAD_STATUS=$(echo "$UPLOAD_RESP" | grep "HTTP_STATUS:" | cut -d':' -f2)
          UPLOAD_BODY=$(echo "$UPLOAD_RESP" | sed '/HTTP_STATUS:/d')

          if [ "$UPLOAD_STATUS" -ne 201 ]; then
            echo "Failed to upload release file. Status: $UPLOAD_STATUS"
            echo "$UPLOAD_BODY"
            exit 1
          fi

          echo "Release file uploaded successfully."

      - name: Submit for Curation Review
        shell: bash
        env:
          TOKEN: ${{ secrets.NODE_AEC_API_TOKEN }}
        run: |
          set -euo pipefail
          echo "Submitting version $VERSION for curation review..."

          SUBMIT_RESP=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
            "$NODE_AEC_API_URL/developer/products/$PRODUCT_SLUG/versions/$VERSION/submissions" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d '{
              "securityManifest": {
                "network": {
                  "hasAccess": false,
                  "purpose": "",
                  "domains": []
                },
                "filesystem": {
                  "hasAccess": true,
                  "scope": "Reads active BIM project models and exports clash matrix tables."
                },
                "processes": {
                  "hasAccess": false,
                  "justification": ""
                },
                "nativeCalls": {
                  "hasAccess": false,
                  "libraries": []
                },
                "registry": {
                  "hasAccess": false,
                  "keys": []
                },
                "telemetry": {
                  "hasAccess": false,
                  "fields": [],
                  "purpose": ""
                }
              }
            }')

          SUBMIT_STATUS=$(echo "$SUBMIT_RESP" | grep "HTTP_STATUS:" | cut -d':' -f2)
          SUBMIT_BODY=$(echo "$SUBMIT_RESP" | sed '/HTTP_STATUS:/d')

          if [ "$SUBMIT_STATUS" -ne 201 ]; then
            echo "Submission failed. Status: $SUBMIT_STATUS"
            echo "$SUBMIT_BODY"
            exit 1
          fi

          echo "Version $VERSION successfully submitted for Node.aec curation review!"
```

---

## 2. Bash / cURL Release Automation Script (`release.sh`)

> **Standalone script file**: [`examples/scripts/release.sh`](https://github.com/nodeaec/developer-api/blob/main/examples/scripts/release.sh)

A standalone, portable POSIX Bash script suitable for Linux, macOS, or WSL release automation.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
PRODUCT_SLUG="${1:-smart-clash-detector}"
VERSION="${2:-}"
FILE_PATH="${3:-}"
API_URL="${NODE_AEC_API_URL:-https://api.nodeaec.com.br}"
TOKEN="${NODE_AEC_API_TOKEN:-}"

if [[ -z "$TOKEN" ]]; then
  echo "Error: NODE_AEC_API_TOKEN environment variable is required." >&2
  exit 1
fi

if [[ -z "$VERSION" || -z "$FILE_PATH" ]]; then
  echo "Usage: ./release.sh <product-slug> <semver-version> <binary-file-path>" >&2
  echo "Example: ./release.sh smart-clash-detector 1.2.0 ./dist/Plugin-1.2.0.zip" >&2
  exit 1
fi

if [[ ! -f "$FILE_PATH" ]]; then
  echo "Error: File not found: $FILE_PATH" >&2
  exit 1
fi

FILENAME=$(basename "$FILE_PATH")

echo "==> 1. Creating Draft Version $VERSION on product '$PRODUCT_SLUG'..."
CREATE_RESP=$(curl -s -w "\n%{http_code}" -X POST \
  "$API_URL/developer/products/$PRODUCT_SLUG/versions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"version\": \"$VERSION\", \"description\": \"Release $VERSION\", \"allowDownload\": true}")

HTTP_CODE=$(echo "$CREATE_RESP" | tail -n1)
BODY=$(echo "$CREATE_RESP" | sed '$d')

if [[ "$HTTP_CODE" != "201" && "$HTTP_CODE" != "200" ]]; then
  echo "Error creating version ($HTTP_CODE): $BODY" >&2
  exit 1
fi
echo "Version container ready."

echo "==> 2. Uploading Binary Release '$FILENAME'..."
UPLOAD_RESP=$(curl -s -w "\n%{http_code}" -X POST \
  "$API_URL/developer/products/$PRODUCT_SLUG/versions/$VERSION/files/upload" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@$FILE_PATH" \
  -F "name=$FILENAME" \
  -F "description=Automated CLI release")

HTTP_CODE=$(echo "$UPLOAD_RESP" | tail -n1)
BODY=$(echo "$UPLOAD_RESP" | sed '$d')

if [[ "$HTTP_CODE" != "201" ]]; then
  echo "Error uploading file ($HTTP_CODE): $BODY" >&2
  exit 1
fi
echo "File uploaded successfully."

echo "==> 3. Submitting Version for Review with Security Manifest..."
SUBMIT_RESP=$(curl -s -w "\n%{http_code}" -X POST \
  "$API_URL/developer/products/$PRODUCT_SLUG/versions/$VERSION/submissions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "securityManifest": {
      "network": { "hasAccess": false, "purpose": "", "domains": [] },
      "filesystem": { "hasAccess": true, "scope": "Reads user CAD/BIM model files." },
      "processes": { "hasAccess": false, "justification": "" },
      "nativeCalls": { "hasAccess": false, "libraries": [] },
      "registry": { "hasAccess": false, "keys": [] },
      "telemetry": { "hasAccess": false, "fields": [], "purpose": "" }
    }
  }')

HTTP_CODE=$(echo "$SUBMIT_RESP" | tail -n1)
BODY=$(echo "$SUBMIT_RESP" | sed '$d')

if [[ "$HTTP_CODE" != "201" ]]; then
  echo "Error submitting review ($HTTP_CODE): $BODY" >&2
  exit 1
fi

echo "==> SUCCESS: Version $VERSION of $PRODUCT_SLUG submitted to Node.aec!"
```

---

## 3. PowerShell Script for Windows / .NET Revit Plugin Builds (`Release-NodeAec.ps1`)

> **Standalone script file**: [`examples/scripts/Release-NodeAec.ps1`](https://github.com/nodeaec/developer-api/blob/main/examples/scripts/Release-NodeAec.ps1)

Ideal for local Windows developer workstations, Azure DevOps pipelines, or Jenkins Windows agents compiling Revit/Navisworks plugins.

```powershell
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
```
