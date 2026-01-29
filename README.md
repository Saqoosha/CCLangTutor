# CCLangTutor

A macOS app that automatically corrects English grammar in your Claude Code prompts.

## Overview

CCLangTutor integrates with Claude Code via hooks to provide real-time English grammar corrections. When you submit a prompt in Claude Code, the app captures it, sends it to your configured AI provider (Claude, Gemini, or OpenAI) for correction, and displays the results in a native macOS interface.

## Architecture

```
User prompt → Claude Code Hook (UserPromptSubmit)
                    ↓
            english-teacher CLI
                    ↓
            pending.json (stored)
                    ↓
            CCLangTutor.app (processes)
                    ↓
            Claude API (Haiku) → corrections.json
                    ↓
            SwiftUI displays results
```

## Installation

### From DMG (Recommended)

1. Download the latest `.dmg` from [Releases](https://github.com/Saqoosha/CCLangTutor/releases)
2. Open the DMG and drag `CCLangTutor.app` to Applications
3. Run the app once to register the hook

### From Source

```bash
# Clone the repository
git clone https://github.com/Saqoosha/CCLangTutor.git
cd CCLangTutor

# Build release version
./scripts/build.sh Release

# The app is located at:
# build/DerivedData/Build/Products/Release/CCLangTutor.app
```

## Configuration

### API Key

1. Open CCLangTutor.app
2. Go to Settings (⌘,)
3. Enter your API key for your preferred provider (Claude, Gemini, or OpenAI)
4. Click "Save"

The API key is stored securely in macOS Keychain.

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
            "command": "/Applications/CCLangTutor.app/Contents/MacOS/english-teacher"
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

## Data Storage

All data is stored locally in:
- `~/Library/Application Support/CCLangTutor/pending.json` - Prompts awaiting correction
- `~/Library/Application Support/CCLangTutor/corrections.json` - Correction history

## Limitations

### AskUserQuestion Responses Not Captured

When Claude Code uses the `AskUserQuestion` tool to ask you a question with options, and you select "Other" to provide a custom text response, **this input is not captured for correction**.

This is a limitation of Claude Code's hook system - the `UserPromptSubmit` hook only fires for regular prompt submissions, not for responses to tool questions.

**What gets corrected:**
- Regular prompts typed in the main input
- Slash command arguments (e.g., `/commit fix the bug` → "fix the bug" is corrected)

**What does NOT get corrected:**
- Responses to `AskUserQuestion` tool (including "Other" custom text)
- Selecting predefined options (these are not user-written text anyway)

## Development

### Requirements

- macOS 14.0+
- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### Build Commands

```bash
# Debug build
./scripts/build.sh Debug

# Release build
./scripts/build.sh Release

# Package DMG (includes notarization)
./scripts/package_dmg.sh

# Release new version
./scripts/release.sh 1.0.0
```

### Project Structure

```
Sources/
├── CCLangTutor/          # Main app (SwiftUI)
├── CCLangTutorCore/      # Shared models
└── english-teacher/      # CLI hook
```

## License

MIT
