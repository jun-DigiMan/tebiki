#!/bin/bash
# tebiki スキル インストーラー
# Usage: bash install.sh <NOTION_TOKEN>
# 例: bash <(curl -fsSL https://raw.githubusercontent.com/jun-DigiMan/tebiki/main/install.sh) ntn_xxx...
# DigiMan 内部向け

set -euo pipefail

NOTION_TOKEN="${1:-}"
if [ -z "$NOTION_TOKEN" ]; then
  echo "❌ NOTION_TOKENを引数で渡してください"
  echo "例: bash install.sh ntn_xxx..."
  exit 1
fi

SKILL_DIR="$HOME/.claude/skills/tebiki"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "🚀 tebiki スキルをインストール中..."

# ── 1. スキルディレクトリ作成 ──────────────────────────────
mkdir -p "$SKILL_DIR/scripts"

# ── 2. SKILL.md を配置 ────────────────────────────────────
cat > "$SKILL_DIR/SKILL.md" << 'SKILL_EOF'
---
name: tebiki
description: 社内向け手順書をスクリーンショット付きでNotionに作成するスキル。「手順書」「マニュアル」「手順」「ナレッジ」「wiki」「Wiki」という単語が含まれる依頼に使用する。ブラウザ操作の画面キャプチャを撮りながら、DigiMan|WikiDBに構造化された手順書ページを自動作成する。
license: Internal use only - DigiMan
compatibility: Designed for Claude Code. Requires Playwright MCP and Notion MCP. Requires NOTION_TOKEN env var.
allowed-tools: mcp__playwright__browser_navigate mcp__playwright__browser_take_screenshot mcp__playwright__browser_snapshot mcp__claude_ai_Notion__notion-create-pages mcp__notion__API-post-page mcp__notion__API-patch-block-children Bash
---

# 手順書作成スキル（tebiki）

## このスキルでできること
- ブラウザを操作しながら**スクリーンショットを自動撮影**
- **Notion WikiDB**（DigiMan｜Wiki）に手順書ページを自動作成
- Slack通知用のメッセージ文も生成

---

## 実行手順

### STEP 0：キャプチャの受け取り（ユーザーが画像を貼り付けた場合）

ユーザーがClaudeにスクリーンショットを貼り付けた場合：

1. 画像を受け取ったことを確認し、何枚あるか把握する
2. 各画像をローカルに保存する（Bashでbase64デコード）
3. 保存後、`scripts/upload_image.sh` で各画像をNotionにアップロードしてfile_upload_idを取得する
4. 取得したfile_upload_idをステップごとに記録しておく（後でNotionページのimage blockに使用）

---

### STEP 1：情報収集

ユーザーに以下を確認する（すでに分かっている場合はスキップ）：

1. **手順書のタイトル**
2. **対象ツール・URL**（スクリーンショットを撮る対象）
3. **手順のステップ**
4. **対象読者**（全員 / 特定部署 / NewHire など）
5. **難易度**（Level1：易 / Level2：普 / Level3：難）

---

### STEP 2：スクリーンショット撮影

URLがある場合、Playwrightブラウザツールを使って以下を実行する：

1. `mcp__playwright__browser_navigate` でURLを開く
2. 各操作ステップで `mcp__playwright__browser_take_screenshot` を実行
3. 撮影した画像は `/Users/user/projects/screenshots/手順書タイトル/` に保存（step01.png, step02.png ...）

---

### STEP 3：Notion WikiDBにページ作成

`mcp__claude_ai_Notion__notion-create-pages` を使って作成する。

**親データソース**：`2e64e5d9-9eb3-8145-a33b-000bd42d72c7`（DigiMan｜Wiki）

| プロパティ | 設定値 |
|---|---|
| `コンテンツ名` | 手順書タイトル |
| `見てほしい対象` | ユーザー指定（デフォルト: `["全員"]`） |
| `📊ナレッジカテゴリ` | `3p｜全社ツール` |
| `ステータス` | `🔁継続更新` |
| `💗おすすめ度` | `★★★｜絶対見て！` |
| `✍️コンテンツカテゴリ` | `["手順書"]` |
| `🧗‍♂️難易度` | Level1〜3 ユーザー指定 |

#### スクリーンショットの埋め込み

STEP 0でfile_upload_idを取得済みの場合、`mcp__notion__API-patch-block-children` で各ステップ直後にimage blockを追加：

```json
{
  "type": "image",
  "image": { "type": "file_upload", "file_upload": { "id": "<file_upload_id>" } }
}
```

---

### STEP 4：Slack通知文の生成

```
📝 【手順書】[タイトル]
[概要1行]
📖 手順書はこちら（Notion）
[NotionページURL]
```

---

### STEP 5：完了報告

1. 作成したNotionページのURL
2. Slack通知文

---

## 参考情報

- **DigiMan｜Wiki DB**：https://www.notion.so/digiman/2e64e5d99eb3815dab07ef52c5dac026
- **スクリーンショット保存先**：`/Users/user/projects/screenshots/`
SKILL_EOF

# ── 3. upload_image.sh を配置 ─────────────────────────────
cat > "$SKILL_DIR/scripts/upload_image.sh" << 'SCRIPT_EOF'
#!/bin/bash
# Notion Files API に画像をアップロードして file_upload_id を返す
# Usage: ./upload_image.sh <image_path>

set -euo pipefail

IMAGE_PATH="${1:-}"
NOTION_KEY="${NOTION_TOKEN:-}"

if [ -z "$IMAGE_PATH" ]; then
  echo "ERROR: 画像パスを指定してください" >&2
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

INIT_RESPONSE=$(curl -s -X POST "https://api.notion.com/v1/files" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Content-Type: application/json" \
  -H "Notion-Version: 2022-06-28" \
  -d "{\"mode\":\"single_part\",\"filename\":\"$FILENAME\",\"content_type\":\"image/png\",\"size\":$FILESIZE}")

FILE_ID=$(echo "$INIT_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['id'])" 2>/dev/null)
UPLOAD_URL=$(echo "$INIT_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['upload_url'])" 2>/dev/null)

if [ -z "$FILE_ID" ] || [ -z "$UPLOAD_URL" ]; then
  echo "ERROR: アップロードURL取得失敗" >&2
  echo "$INIT_RESPONSE" >&2
  exit 1
fi

curl -s -X PUT "$UPLOAD_URL" \
  -F "file=@$IMAGE_PATH;type=image/png" > /dev/null

echo "$FILE_ID"
SCRIPT_EOF

chmod +x "$SKILL_DIR/scripts/upload_image.sh"

# ── 4. settings.json に NOTION_TOKEN を追加 ────────────────
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{"permissions":{"allow":["Bash(*)","Read(*)","Write(*)","Edit(*)","Glob(*)","Grep(*)","mcp__*(*)"]}}' > "$SETTINGS_FILE"
fi

python3 - "$SETTINGS_FILE" "$NOTION_TOKEN" << 'PYEOF'
import sys, json

settings_path = sys.argv[1]
token = sys.argv[2]

with open(settings_path, 'r') as f:
    settings = json.load(f)

if 'env' not in settings:
    settings['env'] = {}

settings['env']['NOTION_TOKEN'] = token

with open(settings_path, 'w') as f:
    json.dump(settings, f, ensure_ascii=False, indent=2)

print("✅ NOTION_TOKEN を settings.json に登録しました")
PYEOF

echo ""
echo "✅ tebiki スキルのインストールが完了しました！"
echo ""
echo "使い方："
echo "  Claude Code を開いてスクリーンショットを貼り付け、「手順書」と入力するだけ"
echo ""
