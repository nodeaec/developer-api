# Node.aec Developer API Reference

Welcome to the **Node.aec Developer API**. The Developer API provides approved developers with programmatic access to manage plugins, BIM assets, version drafts, binary release files, gallery media, documentation, and curation submissions directly from automated CI/CD pipelines, build scripts, or terminal CLI tools.

> [!TIP]
> **Documentation & Ready-to-Clone Examples**
> - **Interactive Documentation Site**: [https://nodeaec.github.io/developer-api/](https://nodeaec.github.io/developer-api/)
> - **Ready-to-Clone CI/CD Examples**: [`examples/`](https://github.com/nodeaec/developer-api/tree/main/examples)
>   - [GitHub Actions Workflow](https://github.com/nodeaec/developer-api/blob/main/examples/github-actions/release.yml) (`examples/github-actions/release.yml`)
>   - [POSIX Bash Release Script](https://github.com/nodeaec/developer-api/blob/main/examples/scripts/release.sh) (`examples/scripts/release.sh`)
>   - [PowerShell Windows / .NET Release Script](https://github.com/nodeaec/developer-api/blob/main/examples/scripts/Release-NodeAec.ps1) (`examples/scripts/Release-NodeAec.ps1`)

---

## Table of Contents

1. [Authentication & Security](authentication.md) — Token provisioning, Bearer headers, lifecycle, expiration, and privilege boundaries.
2. [Products & Media Management](products-and-media.md) — Creating, updating, deleting products, gallery screenshots, and reference PDFs.
3. [Versions & Release Binaries](versions-and-releases.md) — Drafting semantic versions, uploading release files up to 250 MB (.zip, .exe, .rvt, .ifc), and file lifecycle.
4. [Submissions & Security Manifests](submissions-and-manifests.md) — The 6-capability security contract, manifest declarations, curation submission, and revision requests.
5. [CI/CD Pipeline Examples](ci-cd-examples.md) — Copy-pasteable workflows for GitHub Actions, Bash/cURL release scripts, and PowerShell for Windows/.NET builds.

---

## Base URL

| Environment | Base URL |
| :--- | :--- |
| **Production** | `https://api.nodeaec.com.br` |
| **Local Development** | `http://localhost:3000` (Direct API) or via web reverse-proxy |

All API endpoints are mounted under root routes (e.g. `https://api.nodeaec.com.br/developer/products`).

---

## Authentication Summary

Programmatic access requires a Developer API token generated in the **Developer Portal**:

```http
Authorization: Bearer aec_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
```

- Token prefix: `aec_` followed by 64 hexadecimal characters.
- Requires an active, email-verified user account with an **approved** developer profile.
- Tokens can be created with expirations of 30 days, 90 days, 365 days, or never expiring.
- Each authenticated request automatically touches and updates the token's `last_used_at` timestamp.

For comprehensive details on token security, scopes, and revocation, see [Authentication](authentication.md).

---

## Human-Readable Identifiers vs. Base62 Public IDs

To simplify automated CI/CD pipelines and avoid redundant API lookups, all Developer API endpoints accept **dual identifier addressing**:

| Entity | Identifier Formats Accepted | Examples |
| :--- | :--- | :--- |
| **Product** | Human-readable `slug` or 14-character Base62 `publicId` | `revit-smart-exporter`<br>`1a2b3c4d5e6f7g` |
| **Version** | Semantic version string or 14-character Base62 `publicId` | `1.0.0`, `2.1.0-beta.1`<br>`9z8y7x6w5v4u3t` |
| **Category** | Category `slug` or 14-character Base62 `publicId` | `revit-plugins`<br>`3k4j5h6g7f8d9s` |
| **Tags** | Tag `slug` array or Base62 `publicId` array | `["revit", "export", "bim"]` |

### URL Path Examples

```http
# Using human-readable slug and semantic version (recommended for CI/CD):
GET /developer/products/revit-smart-exporter/versions/1.0.0/manifest

# Using internal Base62 public IDs (fully supported):
GET /developer/products/1a2b3c4d5e6f7g/versions/9z8y7x6w5v4u3t/manifest
```

---

## Request & Response Formats

- All JSON requests must supply the `Content-Type: application/json` header.
- Binary and media uploads (`images/upload`, `documents/upload`, `files/upload`) accept `multipart/form-data`.
- All response keys are serialized in **camelCase**.
- Datetime fields are returned in ISO 8601 UTC format (e.g. `2026-10-20T12:00:00.000Z`).

---

## Error Handling

The API uses standard HTTP response status codes. Expected failures return a structured JSON object with an application error code and message:

```json
{
  "error": "The specified product was not found or does not belong to your developer profile.",
  "code": "PRODUCT_NOT_FOUND",
  "data": {}
}
```

### Standard Status Codes

| Code | Status | Meaning |
| :--- | :--- | :--- |
| `200` | **OK** | Request completed successfully. |
| `201` | **Created** | New resource created (product, version, upload, submission). |
| `400` | **Bad Request** | Validation failed (missing required fields, invalid semver, duplicate slug). |
| `401` | **Unauthorized** | Token missing, invalid (`INVALID_TOKEN`), or expired (`TOKEN_EXPIRED`). |
| `403` | **Forbidden** | Account disabled, email unverified, or developer profile not approved (`PROFILE_NOT_APPROVED`). |
| `404` | **Not Found** | Resource not found or not owned by authenticated developer. |
| `409` | **Conflict** | Slug already in use or state conflict. |
| `413` | **Payload Too Large** | Upload exceeds maximum file limit (250 MB for binaries, 10 MB for images, 50 MB for PDFs). |
| `500` | **Internal Server Error** | Unexpected server condition. |

---

## Rate Limits & Usage Guidelines

- Standard programmatic API operations are limited to **120 requests per minute** per developer token.
- High-volume file uploads should be performed sequentially or with a concurrency limit of 2 concurrent uploads per token.
- CI/CD build runs should securely store `NODE_AEC_API_TOKEN` in encrypted pipeline secrets (e.g. GitHub Repository Secrets).
