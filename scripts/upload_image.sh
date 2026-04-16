#!/bin/bash
# Notion Files API に画像をアップロードして file_upload_id を返す
# Usage: ./upload_image.sh <image_path>
# Output: file_upload_id（成功時）、エラーメッセージ（失敗時）

set -euo pipefail

IMAGE_PATH="${1:-}"
NOTION_KEY="${NOTION_TOKEN:-}"

if [ -z "$IMAGE_PATH" ]; then
  echo "ERROR: 画像パスを指定してください" >&2
  echo "Usage: $0 <image_path>" >&2
  exit 1
fi

if [ ! -f "$IMAGE_PATH" ]; then
  echo "ERROR: ファイルが見つかりません: $IMAGE_PATH" >&2
  exit 1
fi

if [ -z "$NOTION_KEY" ]; then
  echo "ERROR: NOTION_TOKEN が設定されていません" >&2
  exit 1
fi

FILENAME=$(basename "$IMAGE_PATH")
FILESIZE=$(wc -c < "$IMAGE_PATH" | tr -d ' ')

# STEP 1: アップロードURLを取得
INIT_RESPONSE=$(curl -s -X POST "https://api.notion.com/v1/files" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Content-Type: application/json" \
  -H "Notion-Version: 2022-06-28" \
  -d "{
    \"mode\": \"single_part\",
    \"filename\": \"$FILENAME\",
    \"content_type\": \"image/png\",
    \"size\": $FILESIZE
  }")

FILE_ID=$(echo "$INIT_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['id'])" 2>/dev/null)
UPLOAD_URL=$(echo "$INIT_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['upload_url'])" 2>/dev/null)

if [ -z "$FILE_ID" ] || [ -z "$UPLOAD_URL" ]; then
  echo "ERROR: アップロードURL取得失敗" >&2
  echo "$INIT_RESPONSE" >&2
  exit 1
fi

# STEP 2: ファイルをアップロード
UPLOAD_RESPONSE=$(curl -s -X PUT "$UPLOAD_URL" \
  -F "file=@$IMAGE_PATH;type=image/png")

STATUS=$(echo "$UPLOAD_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','unknown'))" 2>/dev/null)

if [ "$STATUS" != "uploaded" ] && [ "$STATUS" != "pending" ]; then
  echo "ERROR: アップロード失敗 (status: $STATUS)" >&2
  echo "$UPLOAD_RESPONSE" >&2
  exit 1
fi

# file_upload_id を出力
echo "$FILE_ID"
