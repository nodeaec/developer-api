# Products & Media Management

This guide covers endpoints for creating and updating products, uploading gallery screenshots, and attaching reference documentation (PDF user manuals, integration guides).

All endpoints accept either a product's 14-character Base62 `publicId` or its human-readable `slug` in the URL path:
```text
/developer/products/:idOrSlug
```

---

## 1. List Products

Retrieve all products owned by your developer profile with pagination and status filters.

```http
GET /developer/products?status=published&page=1&limit=20 HTTP/1.1
Host: api.nodeaec.com.br
Authorization: Bearer aec_...
```

### Query Parameters

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `status` | string | No | Filter by status: `draft`, `published`, `archived`. Default returns all. |
| `page` | integer | No | Page number (default: `1`). |
| `limit` | integer | No | Results per page (default: `20`, maximum: `100`). |

### Example cURL

```bash
curl -s -X GET "https://api.nodeaec.com.br/developer/products?status=published" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN"
```

### Response `200 OK`

```json
{
  "products": [
    {
      "publicId": "1a2b3c4d5e6f7g",
      "slug": "smart-clash-detector",
      "name": "Smart Clash Detector",
      "summary": "Automated Navisworks and Revit clash detection engine with BCF export.",
      "status": "published",
      "price": "0.00",
      "categoryId": "3k4j5h6g7f8d9s",
      "categoryName": "Quality & Coordination",
      "tags": ["clash-detection", "navisworks", "revit", "bcf"],
      "createdAt": "2026-09-01T10:00:00.000Z",
      "updatedAt": "2026-10-18T14:32:00.000Z"
    }
  ],
  "total": 1,
  "page": 1,
  "limit": 20
}
```

---

## 2. Get Product Details

Inspect a single product, including its current published version, draft versions, gallery images, and reference documents.

```http
GET /developer/products/:idOrSlug HTTP/1.1
Host: api.nodeaec.com.br
Authorization: Bearer aec_...
```

### Example cURL

```bash
curl -s -X GET "https://api.nodeaec.com.br/developer/products/smart-clash-detector" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN"
```

### Response `200 OK`

```json
{
  "product": {
    "publicId": "1a2b3c4d5e6f7g",
    "slug": "smart-clash-detector",
    "name": "Smart Clash Detector",
    "summary": "Automated Navisworks and Revit clash detection engine with BCF export.",
    "description": "## Features\n\n- Real-time geometric intersection tests\n- Rule-based tolerance filters\n- One-click BCF 2.1 reporting",
    "status": "published",
    "price": "0.00",
    "categoryId": "3k4j5h6g7f8d9s",
    "categorySlug": "coordination",
    "categoryName": "Quality & Coordination",
    "tags": ["clash-detection", "revit", "bcf"],
    "createdAt": "2026-09-01T10:00:00.000Z"
  },
  "versions": [
    {
      "publicId": "9z8y7x6w5v4u3t",
      "version": "1.2.0",
      "status": "published",
      "changelog": "Added Revit 2026 support.",
      "publishedAt": "2026-10-10T08:00:00.000Z"
    }
  ],
  "images": [
    {
      "publicId": "4m5n6b7v8c9x0z",
      "url": "https://cdn.nodeaec.com.br/gallery/smart-clash-detector/overview.webp",
      "caption": "Clash grouping dialog",
      "isCover": true,
      "sortOrder": 0
    }
  ],
  "documents": [
    {
      "publicId": "7p8o9i0u1y2t3r",
      "title": "Smart Clash Detector User Guide v1.2",
      "url": "https://cdn.nodeaec.com.br/documents/smart-clash-detector/user-guide.pdf",
      "fileSize": 3450120
    }
  ]
}
```

---

## 3. Create a Product Draft

Create a new product draft. Both `categoryId` and `tags` accept human-readable slugs or 14-char Base62 `publicId`s.

```http
POST /developer/products HTTP/1.1
Host: api.nodeaec.com.br
Authorization: Bearer aec_...
Content-Type: application/json

{
  "name": "Smart Clash Detector",
  "slug": "smart-clash-detector",
  "summary": "Automated Navisworks and Revit clash detection engine with BCF export.",
  "description": "Full product markdown description...",
  "categoryId": "coordination",
  "tags": ["revit", "coordination", "bcf"]
}
```

### Request Body Parameters

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `name` | string | Yes | Product display title (3 to 120 characters). |
| `slug` | string | No | URL-friendly identifier (`[a-z0-9-]+`). Auto-generated from `name` if omitted. |
| `summary` | string | Yes | Short subtitle / tagline (10 to 300 characters). |
| `description` | string | No | Full Markdown overview (up to 10,000 characters). |
| `categoryId` | string | Yes | Category slug (e.g. `coordination`) or Base62 `publicId`. |
| `tags` | string[] | No | Array of tag slugs (e.g. `["revit", "bcf"]`) or Base62 `publicId`s. |
| `price` | string/number | No | Must be `0.00` (free/included tier). |

### Example cURL

```bash
curl -X POST "https://api.nodeaec.com.br/developer/products" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "IFC Property Inspector",
    "slug": "ifc-property-inspector",
    "summary": "Inspect and validate IFC 4x3 custom Pset schemas in seconds.",
    "categoryId": "interoperability",
    "tags": ["ifc", "openbim", "revit"]
  }'
```

### Response `201 Created`

```json
{
  "product": {
    "publicId": "5f6e7d8c9b0a1z",
    "slug": "ifc-property-inspector",
    "name": "IFC Property Inspector",
    "summary": "Inspect and validate IFC 4x3 custom Pset schemas in seconds.",
    "status": "draft",
    "categoryId": "8h7g6f5e4d3c2b",
    "categorySlug": "interoperability",
    "tags": ["ifc", "openbim", "revit"],
    "createdAt": "2026-10-20T03:00:00.000Z"
  }
}
```

---

## 4. Update a Product

Update metadata, description, categories, or tags on an existing product.

```http
PUT /developer/products/:idOrSlug HTTP/1.1
Host: api.nodeaec.com.br
Authorization: Bearer aec_...
Content-Type: application/json

{
  "summary": "Updated summary with support for IFC 4.3 Add2.",
  "tags": ["ifc", "openbim", "revit", "ifc43"]
}
```

### Example cURL

```bash
curl -X PUT "https://api.nodeaec.com.br/developer/products/ifc-property-inspector" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "summary": "Updated summary with support for IFC 4.3 Add2.",
    "tags": ["ifc", "openbim", "revit", "ifc43"]
  }'
```

---

## 5. Delete a Product

Permanently delete an unpublished draft product. Published products cannot be deleted via the API and must undergo decommissioning review.

```http
DELETE /developer/products/:idOrSlug HTTP/1.1
Host: api.nodeaec.com.br
Authorization: Bearer aec_...
```

### Example cURL

```bash
curl -X DELETE "https://api.nodeaec.com.br/developer/products/ifc-property-inspector" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN"
```

### Response `200 OK`

```json
{
  "success": true,
  "message": "Product deleted successfully."
}
```

---

## 6. Gallery Images Management

### Upload Gallery Image
Accepts JPEG, PNG, or WebP images up to 10 MB.

```bash
curl -X POST "https://api.nodeaec.com.br/developer/products/ifc-property-inspector/images/upload" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN" \
  -F "image=@./screenshots/overview.png" \
  -F "caption=Property set editor" \
  -F "isCover=true"
```

### Response `201 Created`

```json
{
  "image": {
    "publicId": "4m5n6b7v8c9x0z",
    "url": "https://cdn.nodeaec.com.br/gallery/ifc-property-inspector/overview.webp",
    "caption": "Property set editor",
    "isCover": true,
    "sortOrder": 0
  }
}
```

### Reorder Gallery Images

```bash
curl -X PUT "https://api.nodeaec.com.br/developer/products/ifc-property-inspector/images/reorder" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "imagePublicIds": [
      "4m5n6b7v8c9x0z",
      "6k7l8m9n0p1q2r",
      "8s9t0u1v2w3x4y"
    ]
  }'
```

### Update or Delete Gallery Image

```bash
# Update caption / cover status
curl -X PUT "https://api.nodeaec.com.br/developer/products/ifc-property-inspector/images/4m5n6b7v8c9x0z" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"caption": "Updated caption", "isCover": false}'

# Delete image
curl -X DELETE "https://api.nodeaec.com.br/developer/products/ifc-property-inspector/images/4m5n6b7v8c9x0z" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN"
```

---

## 7. Reference Documents (PDF)

Attach PDF manuals, user guides, or compliance certificates (up to 50 MB per document).

### Upload Document

```bash
curl -X POST "https://api.nodeaec.com.br/developer/products/ifc-property-inspector/documents/upload" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN" \
  -F "document=@./docs/UserManual.pdf" \
  -F "title=IFC Property Inspector User Guide"
```

### Update or Delete Document

```bash
# Update document title
curl -X PUT "https://api.nodeaec.com.br/developer/products/ifc-property-inspector/documents/7p8o9i0u1y2t3r" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Revised Quick Start Manual"}'

# Delete document
curl -X DELETE "https://api.nodeaec.com.br/developer/products/ifc-property-inspector/documents/7p8o9i0u1y2t3r" \
  -H "Authorization: Bearer $NODE_AEC_API_TOKEN"
```
