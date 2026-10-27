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
