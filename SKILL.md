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
   ```bash
   mkdir -p "/Users/user/projects/screenshots/手順書タイトル"
   # 画像データをstep01.png, step02.png ... として保存
   ```
3. 保存後、`scripts/upload_image.sh` で各画像をNotionにアップロードしてfile_upload_idを取得する
   ```bash
   SKILL_DIR=$(dirname "$(realpath ~/.claude/skills/tebiki/SKILL.md)")
   FILE_ID=$(bash "$SKILL_DIR/scripts/upload_image.sh" "/Users/user/projects/screenshots/手順書タイトル/step01.png")
   ```
4. 取得したfile_upload_idをステップごとに記録しておく（後でNotionページのimage blockに使用）

**注意：** Claude Codeに貼り付けられた画像はbase64形式で受信される。Bashで保存する場合は以下の形式：
```bash
echo "<base64データ>" | base64 --decode > "/path/to/step01.png"
```

---

### STEP 1：情報収集

ユーザーに以下を確認する（すでに分かっている場合はスキップ）：

1. **手順書のタイトル**（例：Googleカレンダーで会議室を予約する方法）
2. **対象ツール・URL**（スクリーンショットを撮る対象）
3. **手順のステップ**（ユーザーが説明するか、ブラウザ操作しながら確認）
4. **対象読者**（全員 / 特定部署 / NewHire など）
5. **難易度**（Level1：易 / Level2：普 / Level3：難）

---

### STEP 2：スクリーンショット撮影

URLがある場合、Playwrightブラウザツールを使って以下を実行する：

1. `mcp__playwright__browser_navigate` でURLを開く
2. 各操作ステップで `mcp__playwright__browser_take_screenshot` を実行
3. スクリーンショットは都度ユーザーに確認を取りながら進める
4. 撮影した画像は `/Users/user/projects/screenshots/手順書タイトル/` に保存
   - ファイル名：`step01.png`, `step02.png` ... と連番で命名
   - Bashコマンドでディレクトリ作成 → base64デコードして保存

スクリーンショット保存コマンド例：
```bash
mkdir -p "/Users/user/projects/screenshots/手順書タイトル"
# base64データをデコードしてpngとして保存
```

---

### STEP 3：Notion WikiDBにページ作成

`mcp__claude_ai_Notion__notion-create-pages` を使って以下の設定で作成する。

**親データソース**：`2e64e5d9-9eb3-8145-a33b-000bd42d72c7`（DigiMan｜Wiki）

#### プロパティ設定

| プロパティ | 設定値 |
|---|---|
| `コンテンツ名` | 手順書タイトル |
| `見てほしい対象` | ユーザー指定（デフォルト: `["全員"]`） |
| `⚡️関連ツール` | 対象ツール名（例: `["🏠️Googleカレンダー"]`） |
| `📊ナレッジカテゴリ` | `3p｜全社ツール` |
| `ステータス` | `🔁継続更新` |
| `💗おすすめ度` | `★★★｜絶対見て！` |
| `✍️コンテンツカテゴリ` | `["手順書"]` |
| `🧗‍♂️難易度` | `Level1：易｜実施推奨` / `Level2：普｜必要に応じて実施` / `Level3：難｜興味があれば実施` |

#### ページコンテンツのテンプレート

以下のNotionマークダウン形式で作成する：

```
<callout icon="📢" color="blue_bg">
	[概要：このページで何ができるか・なぜ必要かを1〜2行で説明]
	**[ツール名]に[操作]するだけ**で、[メリット]。
</callout>
<callout icon="⚙️" color="yellow_bg">
	**手順（約X分）**
	<empty-block/>
	1. [ステップ1の操作説明]
	2. [ステップ2の操作説明]
	3. [ステップ3の操作説明]
		- [補足情報がある場合はネスト]
	4. [最後のステップ] ✅
</callout>
<callout icon="✅" color="green_bg">
	**できること**
	<empty-block/>
	- [効果・メリット1]
	- [効果・メリット2]
	- [効果・メリット3]
	<empty-block/>
	不明点はお気軽に 🙋
</callout>
```

#### スクリーンショットの埋め込み方法

**重要：** 画像はステップブロックの「兄弟」ではなく「子ブロック」として追加すること。
兄弟として挿入すると番号付きリストがリセットされる。子として挿入することで通し番号が維持される。

**手順：**
1. `mcp__notion__API-post-page` でページを作成（テキストコンテンツのみ）
2. 作成したページIDを取得
3. 各ステップブロックのIDを取得（`mcp__notion__API-get-block-children`）
4. **各ステップブロックのID** に対して `mcp__notion__API-patch-block-children` でimage blockを子として追加

```json
// ページIDではなく、各ステップブロックのIDに対して呼び出す
{
  "block_id": "<ステップのブロックID>",
  "children": [
    {
      "type": "image",
      "image": {
        "type": "file_upload",
        "file_upload": { "id": "<file_upload_id>" }
      }
    }
  ]
}
```

これによりステップの直下（インデント）に画像が入り、番号付きリストの通し番号が崩れない。

画像がない場合は、各ステップ下に `> 📸 スクリーンショット：step0X.png を添付してください` というコメントを挿入して場所を明示する。

---

### STEP 4：Slack通知文の生成

以下のフォーマットでSlackに貼り付け可能なメッセージを生成する：

```
📣 **【手順書】[タイトル]**

[概要1行]

📖 手順書はこちら（Notion）
[NotionページURL]

[対象者・難易度など補足があれば追加]
```

---

### STEP 5：完了報告

ユーザーに以下を伝える：
1. 作成したNotionページのURL
2. スクリーンショットの保存先パス（撮影した場合）
3. Notionへのスクリーンショット手動アップロード手順
4. Slack通知文

---

## 参考情報

- **DigiMan｜Wiki DB**：https://www.notion.so/digiman/2e64e5d99eb3815dab07ef52c5dac026
- **作成例（Googleカレンダー手順書）**：https://www.notion.so/digiman/Google-3444e5d99eb381ba9217d7f582fda368
- **スクリーンショット保存先**：`/Users/user/projects/screenshots/`

## キーワード
手順書, マニュアル, スクリーンショット, tebiki, 操作手順, 社内マニュアル, Notion登録, 手引き, 手順, howto
