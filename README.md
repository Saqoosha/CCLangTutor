English | [日本語](README.ja.md)

# CCLangTutor

<p align="center">
  <img src="images/appicon.png" width="128" height="128" alt="CCLangTutor icon">
  <br>
  A macOS app that automatically corrects English grammar in your Claude Code prompts.
</p>

## Installation

1. Download the latest `.dmg` from [Releases](https://github.com/Saqoosha/CCLangTutor/releases)
2. Open the DMG and drag `CCLangTutor.app` to Applications
3. Run the app once to register the hook

## Configuration

### API Key

1. Open CCLangTutor.app
2. Go to Settings (⌘,)
3. Enter your API key for your preferred provider (Claude, Gemini, or OpenAI)
4. Click "Save"

The API key is stored securely in macOS Keychain.

### Response Language

You can choose the language for correction explanations and chat responses:

- English (default)
- 日本語 (Japanese)
- Español (Spanish)
- Français (French)
- Deutsch (German)
- 中文 (Chinese)
- 한국어 (Korean)

Note: The target language for corrections is always English. This setting only affects the language of explanations.

### Claude Code Hook

Add the following to your Claude Code settings (`~/.claude/settings.json`):

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

## Usage

1. Launch CCLangTutor.app (it runs in the background)
2. Use Claude Code as normal
3. Your prompts will be automatically analyzed and corrections displayed in the app
4. Click on any correction to see details and ask follow-up questions

### Slash Commands

When you use slash commands (e.g., `/commit message here`), only the argument portion is corrected, not the command itself.

## Limitations

**What gets corrected:**
- Regular prompts typed in the main input (when Claude is idle)
- Slash command arguments (e.g., `/commit fix the bug` → "fix the bug" is corrected)

**What does NOT get corrected:**
- Messages sent while Claude Code is processing (interrupt messages)
- Responses to `AskUserQuestion` tool (including "Other" custom text)
- Selecting predefined options (these are not user-written text anyway)

This is a limitation of Claude Code's hook system - the `UserPromptSubmit` hook only fires for regular prompt submissions.

## Privacy

All your prompts are sent to the LLM provider you select (Claude, Gemini, or OpenAI) for grammar correction. If you have concerns about sending your prompts to external services, do not use this app.

Correction history is stored locally in `~/Library/Application Support/CCLangTutor/`.

---

## Development

### Architecture

```
User prompt → Claude Code Hook (UserPromptSubmit)
                    ↓
            notifier CLI
                    ↓
            pending.json (stored)
                    ↓
            CCLangTutor.app (processes)
                    ↓
            Claude API (Haiku) → corrections.json
                    ↓
            SwiftUI displays results
```

### Requirements

- macOS 14.0+
- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### Build from Source

```bash
git clone https://github.com/Saqoosha/CCLangTutor.git
cd CCLangTutor
./scripts/build.sh Release

# The app is located at:
# build/DerivedData/Build/Products/Release/CCLangTutor.app
```

### Build Commands

```bash
./scripts/build.sh Debug      # Debug build
./scripts/build.sh Release    # Release build
./scripts/package_dmg.sh      # Package DMG (includes notarization)
./scripts/release.sh 1.0.0    # Release new version
```

### Project Structure

```
Sources/
├── CCLangTutor/          # Main app (SwiftUI)
├── CCLangTutorCore/      # Shared models
└── notifier/             # CLI hook
```

## License

MIT
