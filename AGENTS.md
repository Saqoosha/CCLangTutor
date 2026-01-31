# CCLangTutor - Agent Instructions

## Project Overview

CCLangTutor is a macOS app that automatically corrects English grammar in Claude Code prompts.

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

### Components

1. **notifier** (CLI) - Located in app bundle at `Contents/MacOS/notifier`
   - Receives hook input from stdin (JSON)
   - Saves to `~/Library/Application Support/CCLangTutor/pending.json`
   - Launches app, sends Distributed Notification

2. **CCLangTutor.app** (SwiftUI)
   - Listens for Distributed Notifications
   - Processes pending prompts via Claude API
   - Displays correction history

### Build Commands

```bash
# Debug build (kill existing app first!)
pkill -x CCLangTutor; ./scripts/build.sh Debug

# Release build
pkill -x CCLangTutor; ./scripts/build.sh Release

# Package DMG (includes notarization)
./scripts/package_dmg.sh

# Release new version
./scripts/release.sh 1.0.0
```

**Note:** Always kill the running app before building, otherwise the old version keeps running.

### Key Files

- `project.yml` - XcodeGen project definition
- `Sources/CCLangTutor/` - App source code
- `Sources/CCLangTutorCore/` - Shared models
- `Sources/notifier/` - CLI hook

### Dependencies

- **CCHookInstaller** - Shared library for Claude Code hook management (GitHub: `Saqoosha/CCHookInstaller`)

#### Local Development with CCHookInstaller

When making changes to CCHookInstaller alongside this project:

```bash
# 1. Ignore local project.yml changes
git update-index --assume-unchanged project.yml

# 2. Edit project.yml to use local path:
# packages:
#   CCHookInstaller:
#     path: ../CCHookInstaller

# 3. Develop and build - CCHookInstaller changes reflect immediately

# 4. When done: push CCHookInstaller, create new tag (e.g., v1.1.0)

# 5. Revert project.yml to GitHub URL with new version

# 6. Stop ignoring and commit
git update-index --no-assume-unchanged project.yml
```

### Key Settings

- `aiProvider` - Selected AI provider (claude, gemini, openai)
- `responseLanguage` - Language for explanations (en, ja, es, fr, de, zh, ko)
- `systemPrompt` - Custom tutor personality prompt

### Environment

- Requires API key for selected provider (stored in Keychain)
- Data stored in `~/Library/Application Support/CCLangTutor/`
