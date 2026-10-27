# Authentication & Authorization

All automated interactions with the Node.aec Developer API use dedicated **Developer API Tokens** passed via standard HTTP `Authorization` headers.

---

## Token Format

Node.aec developer tokens follow a strict format consisting of a fixed prefix and a high-entropy 64-character hexadecimal string:

```text
aec_e2b47cf391d80ac19385038c8dfa8910be2894ca730e0149fbc24a108c3d90ea
```

- **Prefix**: `aec_`
- **Entropy**: 256 bits (64 hexadecimal characters)
- **Hash algorithm**: SHA-256 (only the hash is stored in the Node.aec database; raw tokens are never persisted or retrievable after initial generation)

---

## Generating an API Token

API tokens must be created through an interactive user session in the Node.aec Developer Portal:

1. Log into your account at `https://nodeaec.com.br/login`.
2. Navigate to your Developer Workbench (`/workspace#developer`).
3. Click the **API Tokens** tab in the navigation bar.
4. Click **Generate New Token**.
5. Provide a descriptive label (e.g., `GitHub Actions CI/CD - Revit Exporter`) and select an expiration policy:
   - **30 days**
   - **90 days** (Recommended for CI pipelines)
   - **365 days**
   - **Never expires**
6. Click **Generate**.
7. **Copy your token immediately**. The complete raw token is displayed only once.

---

## Using the Token in HTTP Requests

Pass the token in the `Authorization` header using the `Bearer` scheme:

```http
GET /developer/products HTTP/1.1
Host: api.nodeaec.com.br
Authorization: Bearer aec_e2b47cf391d80ac19385038c8dfa8910be2894ca730e0149fbc24a108c3d90ea
Content-Type: application/json
```

### cURL Example

```bash
curl -X GET "https://api.nodeaec.com.br/developer/products" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN" \
  -H "Content-Type: application/json"
```

---

## Automatic Usage Tracking (`last_used_at`)

Every successful API request authenticated with an `aec_...` token automatically updates the token's `last_used_at` timestamp. This enables developers to monitor token activity and spot dormant or abandoned credentials directly in the Developer Portal tokens table.

---

## Privilege Boundaries & Scopes

To ensure least privilege and protect sensitive developer account settings against potential leakage from CI/CD runners, `aec_...` tokens have strict operational boundaries:

### Permitted Operations (`aec_...` Allowed)
- `GET /account/developer-profile` — Inspect the authenticated developer profile (name, slug, verification status).
- `GET /developer/products` — List products owned by the developer.
- `POST /developer/products` — Create new product drafts.
- `GET /developer/products/:idOrSlug` — Inspect product details, versions, files, and media.
- `PUT /developer/products/:idOrSlug` — Update product metadata, description, categories, and tags.
- `DELETE /developer/products/:idOrSlug` — Delete draft products.
- `POST /developer/products/:idOrSlug/versions` — Create new semantic version drafts.
- `PUT /developer/products/:idOrSlug/versions/:versionOrPublicId` — Update version release notes.
- `DELETE /developer/products/:idOrSlug/versions/:versionOrPublicId` — Delete draft versions.
- `POST /developer/products/:idOrSlug/versions/:versionOrPublicId/files/upload` — Upload binaries and installers (.zip, .exe, .rvt, .ifc).
- `PUT /developer/products/:idOrSlug/versions/:versionOrPublicId/files/:filePublicId` — Set default release binary.
- `DELETE /developer/products/:idOrSlug/versions/:versionOrPublicId/files/:filePublicId` — Delete draft files or request file removals.
- `POST /developer/products/:idOrSlug/images/upload` — Upload gallery screenshots.
- `PUT /developer/products/:idOrSlug/images/reorder` — Reorder gallery media.
- `PUT /developer/products/:idOrSlug/images/:imagePublicId` — Update image captions or cover flags.
- `DELETE /developer/products/:idOrSlug/images/:imagePublicId` — Remove gallery images.
- `POST /developer/products/:idOrSlug/documents/upload` — Upload reference PDF guides.
- `PUT /developer/products/:idOrSlug/documents/:documentPublicId` — Update document titles.
- `DELETE /developer/products/:idOrSlug/documents/:documentPublicId` — Remove reference documents.
- `GET /developer/products/:idOrSlug/versions/:versionOrPublicId/manifest` — Read version security manifest.
- `POST /developer/products/:idOrSlug/versions/:versionOrPublicId/submissions` — Submit version for curation review.
- `POST /developer/products/:idOrSlug/submit-review` — Submit manifest or file revisions on published products.
- `GET /developer/products/submissions` — Query review submission status.

### Prohibited Operations (Interactive User Session Required)
The following administrative actions **CANNOT** be performed using `aec_...` tokens and will return `401 INVALID_TOKEN`:
- `GET /account/developer-tokens` — Listing existing tokens.
- `POST /account/developer-tokens` — Generating new API tokens.
- `DELETE /account/developer-tokens/:publicId` — Revoking API tokens.
- `POST /account/developer-profile` — Creating a new developer profile.
- `PUT /account/developer-profile` — Modifying developer legal organization, payout settings, or public display profile.

> **Security Rule**: API tokens can never be used to mint other API tokens or alter account payout information. If a CI/CD runner is compromised, the attacker cannot escalate privileges or generate persistent backdoors.

---

## Authentication Error Codes

When an API token fails authentication or authorization checks, the API responds with an appropriate HTTP 401 or 403 status code and machine-readable error payload:

| HTTP Status | Error Code | Description | Recommended Action |
| :--- | :--- | :--- | :--- |
| `401` | `INVALID_TOKEN` | The token header is missing, malformed, unknown, or used on a session-only route. | Verify the `Authorization: Bearer aec_...` header is correctly formatted and that the token has not been revoked. |
| `401` | `TOKEN_EXPIRED` | The token reached its configured expiration date. | Generate a fresh token in the Developer Portal and update your CI/CD secret. |
| `403` | `PROFILE_NOT_APPROVED` | The user account does not have an approved developer profile (`pending`, `rejected`, or unsubmitted). | Check your developer profile status at `/workspace#developer`. Only approved developers may use the Developer API. |
| `403` | `ACCOUNT_DISABLED` | The user account has been disabled or suspended. | Contact Node.aec support (`dev@nodeaec.com.br`). |
| `403` | `EMAIL_NOT_VERIFIED` | The account owner's email address has not been verified. | Complete email verification via the confirmation link sent during registration. |

### Example Error Response

```json
{
  "error": "Developer API token has expired.",
  "code": "TOKEN_EXPIRED",
  "data": {
    "expiredAt": "2026-10-15T00:00:00.000Z"
  }
}
```

---

## Token Revocation & Rotation

1. To revoke a token at any time, open the Developer Portal at `/workspace#developer` -> **API Tokens**.
2. Locate the token by its label and preview (`aec_...[4 chars]`).
3. Click the **Revoke** action button and confirm the modal prompt.
4. Revocation is instantaneous; any subsequent API call with the revoked token will be rejected immediately with `401 INVALID_TOKEN`.
