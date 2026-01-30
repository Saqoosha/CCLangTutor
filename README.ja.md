[English](README.md) | 日本語

# CCLangTutor

<p align="center">
  <img src="images/appicon.png" width="128" height="128" alt="CCLangTutor icon">
  <br>
  Claude Code のプロンプトの英文法を自動的に添削する macOS アプリ
</p>

## 機能

- **リアルタイム文法添削** - Claude Code 使用時にプロンプトを自動解析
- **0-100 スコアリング** - 各プロンプトにスコアを付与、色分け表示（緑/黄/赤）
- **詳細な説明** - 各エラーの内容と理由を具体的に解説
- **改善アドバイス** - より良い英語を書くための提案
- **インタラクティブチャット** - 添削内容について質問して詳しく学べる
- **マルチプロバイダー対応** - Claude、Gemini、OpenAI から選択可能
- **7言語対応** - 説明を英語、日本語、スペイン語、フランス語、ドイツ語、中国語、韓国語で表示
- **自動 Hook セットアップ** - ワンクリックで Claude Code hooks をインストール

## インストール

1. [Releases](https://github.com/Saqoosha/CCLangTutor/releases) から最新の `.dmg` をダウンロード
2. DMG を開いて `CCLangTutor.app` を Applications にドラッグ
3. アプリを起動し、プロンプトが表示されたら「Install Hooks」をクリック

## 設定

### API キー

1. CCLangTutor.app を開く
2. Settings (⌘,) を開く
3. 使用する AI プロバイダー（Claude、Gemini、OpenAI）を選択
4. API キーを入力
5. "Save" をクリック

API キーは macOS Keychain に安全に保存されます。

### 応答言語

添削の説明やチャットの応答言語を選択できます：

- English（デフォルト）
- 日本語
- Español（スペイン語）
- Français（フランス語）
- Deutsch（ドイツ語）
- 中文（中国語）
- 한국어（韓国語）

注意：添削対象の言語は常に英語です。この設定は説明文の言語にのみ影響します。

### 手動 Hook 設定

手動で設定する場合は、`~/.claude/settings.json` に以下を追加：

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/Applications/CCLangTutor.app/Contents/MacOS/notifier"
          }
        ]
      }
    ]
  }
}
```

## 使い方

1. CCLangTutor.app を起動（バックグラウンドで動作）
2. Claude Code を普通に使う
3. プロンプトが自動的に解析され、添削結果がアプリに表示される
4. 添削をクリックすると詳細を確認できる
5. チャットで添削内容について質問できる

### スコアリングシステム

| スコア | 色 | 意味 |
|-------|-----|------|
| 90-100 | 🟢 緑 | 優秀 - 問題なしまたは軽微 |
| 70-89 | 🟡 黄 | 良好 - 改善の余地あり |
| 0-69 | 🔴 赤 | 要改善 - 大きな問題あり |

### スラッシュコマンド

スラッシュコマンド（例：`/commit message here`）を使用する場合、コマンド自体ではなく引数部分のみが添削されます。

## 制限事項

**添削されるもの：**
- メイン入力欄に入力した通常のプロンプト（Claude がアイドル状態のとき）
- スラッシュコマンドの引数（例：`/commit fix the bug` → "fix the bug" が添削される）

**添削されないもの：**
- Claude Code が処理中に送信したメッセージ（割り込みメッセージ）
- `AskUserQuestion` ツールへの回答（"Other" のカスタムテキストを含む）
- 定義済みオプションの選択（そもそもユーザーが書いたテキストではない）

これは Claude Code の hook システムの制限です。`UserPromptSubmit` hook は通常のプロンプト送信時にのみ発火します。

## プライバシー

すべてのプロンプトは、文法添削のために選択した LLM プロバイダー（Claude、Gemini、OpenAI）に送信されます。外部サービスへのプロンプト送信に懸念がある場合は、このアプリを使用しないでください。

添削履歴は `~/Library/Application Support/CCLangTutor/` にローカル保存されます。

---

## 開発

### アーキテクチャ

```
User prompt → Claude Code Hook (UserPromptSubmit)
                    ↓
            notifier CLI
                    ↓
            pending.json (stored)
                    ↓
            CCLangTutor.app (processes)
                    ↓
            AI API → corrections.json
                    ↓
            SwiftUI displays results
```

### 必要要件

- macOS 14.0+
- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### ソースからビルド

```bash
git clone https://github.com/Saqoosha/CCLangTutor.git
cd CCLangTutor
./scripts/build.sh Release

# アプリの場所:
# build/DerivedData/Build/Products/Release/CCLangTutor.app
```

### ビルドコマンド

```bash
./scripts/build.sh Debug      # デバッグビルド
./scripts/build.sh Release    # リリースビルド
./scripts/package_dmg.sh      # DMG パッケージ作成（公証含む）
./scripts/release.sh 1.0.0    # 新バージョンリリース
```

### プロジェクト構成

```
Sources/
├── CCLangTutor/          # メインアプリ (SwiftUI)
├── CCLangTutorCore/      # 共有モデル
└── notifier/             # CLI hook
```

## ライセンス

MIT
