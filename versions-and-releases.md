# Versions & Release Binaries

This guide documents how to manage version drafts and distribution files. You can identify the product and version using either human-readable names (`:idOrSlug` and `:versionOrPublicId`) or Base62 `publicId`s.

---

## 1. Create a Version Draft

Create a new draft version for a product using a semantic version number (e.g. `1.2.0`).

```http
POST /developer/products/:idOrSlug/versions HTTP/1.1
Host: api.nodeaec.com.br
Authorization: Bearer aec_...
Content-Type: application/json

{
  "version": "1.2.0",
  "description": "Release notes and changelog: added Revit 2026 support and improved BCF export performance.",
  "allowDownload": true
}
```

### Request Fields

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `version` | string | Yes | Semantic version string (up to 50 characters, e.g. `1.2.0` or `2.0.0-beta.1`). Must be unique per product. |
| `description` | string | No | Release notes / changelog (up to 5,000 characters). |
| `allowDownload` | boolean | No | Whether binary downloads are enabled upon publication (default: `false`). |

### Example cURL

```bash
curl -X POST "https://api.nodeaec.com.br/developer/products/smart-clash-detector/versions" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "version": "1.3.0",
    "description": "Added multi-threading for collision testing."
  }'
```

### Response `201 Created`

```json
{
  "version": {
    "publicId": "9z8y7x6w5v4u3t",
    "version": "1.3.0",
    "description": "Added multi-threading for collision testing.",
    "status": "draft",
    "allowDownload": false,
    "files": [],
    "createdAt": "2026-10-20T03:15:00.000Z"
  }
}
```

---

## 2. Update Version Metadata

Update the version string, release notes, or download availability for a draft version.

```http
PUT /developer/products/:idOrSlug/versions/:versionOrPublicId HTTP/1.1
Host: api.nodeaec.com.br
Authorization: Bearer aec_...
Content-Type: application/json

{
  "description": "Updated release notes with bug fix details.",
  "allowDownload": true
}
```

### Example cURL

```bash
curl -X PUT "https://api.nodeaec.com.br/developer/products/smart-clash-detector/versions/1.3.0" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "allowDownload": true
  }'
```

---

## 3. Delete a Version Draft

Delete an unreleased draft version and its associated staged files. Published versions cannot be deleted and return `400 VERSION_LOCKED`.

```bash
curl -X DELETE "https://api.nodeaec.com.br/developer/products/smart-clash-detector/versions/1.3.0" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN"
```

---

## 4. Upload Release Binaries (`files/upload`)

Upload distributable binary files, MSI/EXE installers, plugin ZIP packages, Revit families, or IFC reference models.

- **Maximum file size**: **250 MB** per file.
- **Allowed extensions**: `.exe`, `.zip`, `.pdf`, `.rvt`, `.ifc`
- **Integrity**: The server computes and records the SHA-256 hash automatically.
- **Review status**: Uploaded files default to `pending` review.
- **Published version rule**: If uploading a file to an already-published version, you **must** supply `changeReason` explaining why a new binary is being added.

```http
POST /developer/products/:idOrSlug/versions/:versionOrPublicId/files/upload HTTP/1.1
Host: api.nodeaec.com.br
Authorization: Bearer aec_...
Content-Type: multipart/form-data
```

### Form-Data Parameters

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `file` | Binary | Yes | The file stream (up to 250 MB). |
| `name` | string | Yes | Display name for the file (e.g. `SmartClashDetector-1.3.0-Setup.exe`). |
| `description` | string | No | Optional description of this binary (e.g. `Installer for Revit 2024-2026`). |
| `changeReason` | string | Conditional | **Required** if version is already `published` (10 to 500 characters). |

### Example cURL (Draft Version)

```bash
curl -X POST "https://api.nodeaec.com.br/developer/products/smart-clash-detector/versions/1.3.0/files/upload" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN" \
  -F "file=@./dist/SmartClashDetector-1.3.0.zip" \
  -F "name=SmartClashDetector-1.3.0.zip" \
  -F "description=Portable ZIP archive with addin manifest"
```

### Example cURL (Adding File to Published Version)

```bash
curl -X POST "https://api.nodeaec.com.br/developer/products/smart-clash-detector/versions/1.2.0/files/upload" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN" \
  -F "file=@./dist/SmartClashDetector-1.2.0-ARM64.zip" \
  -F "name=SmartClashDetector-1.2.0-ARM64.zip" \
  -F "changeReason=Added native ARM64 binary build for Windows on Snapdragon workstations."
```

### Response `201 Created`

```json
{
  "file": {
    "publicId": "2d3e4f5g6h7j8k",
    "name": "SmartClashDetector-1.3.0.zip",
    "description": "Portable ZIP archive with addin manifest",
    "isDefault": true,
    "reviewStatus": "pending",
    "fileSizeBytes": 15482910,
    "sha256": "3a7bd3e2360a3d29eea436cdfb27d37feeacab6035460f6ee8002d790f32ae48",
    "contentType": "application/zip",
    "createdAt": "2026-10-20T03:20:00.000Z"
  }
}
```

---

## 5. Update Release File Metadata & Default Binary

Set a file as the primary default download for users, or edit its display name/description.

```http
PUT /developer/products/:idOrSlug/versions/:versionOrPublicId/files/:filePublicId HTTP/1.1
Host: api.nodeaec.com.br
Authorization: Bearer aec_...
Content-Type: application/json

{
  "isDefault": true
}
```

> **Note**: For a published version, only an **approved** file can be marked as default (`isDefault: true`). Files pending removal cannot become the default.

---

## 6. Delete or Request Removal of Release Files

- **Draft versions**: Deletes the file immediately from storage and the catalog.
- **Pending revision files**: Withdraws the unreviewed file from the revision immediately.
- **Approved files on published versions**: File removal requires curation review to avoid breaking existing users. You must provide `changeReason`; the file remains active until curators approve removal.

### Example cURL (Requesting File Removal on Published Version)

```bash
curl -X DELETE "https://api.nodeaec.com.br/developer/products/smart-clash-detector/versions/1.2.0/files/2d3e4f5g6h7j8k" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "changeReason": "Deprecating 32-bit MSI installer in favor of universal 64-bit package."
  }'
```

### Response `200 OK`

```json
{
  "file": {
    "publicId": "2d3e4f5g6h7j8k",
    "name": "SmartClashDetector-1.2.0-x86.msi",
    "removalRequested": true,
    "reviewStatus": "approved"
  }
}
```

---

## 7. Public Latest Published Release (`GET /products/:slug/latest`)

Retrieve the latest published release for a product based on semantic versioning rules (`major.minor.patch`, where pre-releases sort below final releases).

The release must be published with `allowDownload: true`, have an approved default file (`isDefault: true`), and contain a verified `sha256` checksum.

```http
GET /products/:slug/latest HTTP/1.1
Host: api.nodeaec.com.br
```

### Response `200 OK`

```json
{
  "slug": "nodeaec-connector",
  "version": "0.4.0",
  "releasedAt": "2026-10-25T12:00:00.000Z",
  "notes": "Official release of Node.aec Connector with automatic update verification.",
  "file": {
    "versionPublicId": "VerConnect0001",
    "filePublicId": "FilConnect0001",
    "name": "NodeAecConnector-0.4.0-Setup.exe",
    "sizeBytes": 12345678,
    "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  }
}
```

> [!NOTE]
> Connector versions must be published as plain `major.minor.patch[-prerelease]` without `+build`. The Connector rejects `+build` metadata suffixes (e.g. `0.4.1+5` would cause version check failures).

### Error Responses

- `404 Not Found` (`PRODUCT_NOT_FOUND`): The product slug does not exist or is not published.
- `404 Not Found` (`NO_PUBLISHED_VERSION`): No published downloadable version with an approved default file and SHA-256 is available.

