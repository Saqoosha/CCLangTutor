# CCLangTutor Internal Architecture

## Overview

CCLangTutor is a macOS app that automatically corrects English grammar in Claude Code prompts using AI APIs.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Claude Code                               │
│                     (UserPromptSubmit Hook)                      │
└─────────────────────┬───────────────────────────────────────────┘
                      │ stdin (JSON)
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                     english-teacher CLI                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 1. Parse JSON input                                         ││
│  │ 2. Skip slash commands without args                         ││
│  │ 3. Save to pending.json                                     ││
│  │ 4. Launch app (background)                                  ││
│  │ 5. Send DistributedNotification                             ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────┬───────────────────────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
        ▼                           ▼
┌───────────────┐      ┌─────────────────────────────────────────┐
│ pending.json  │      │      DistributedNotificationCenter      │
└───────────────┘      └──────────────────┬──────────────────────┘
        │                                 │
        │              ┌──────────────────┘
        │              │
        ▼              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      CCLangTutor.app                             │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                   CorrectionViewModel                        ││
│  │  ┌─────────────┐  ┌──────────────────┐  ┌────────────────┐ ││
│  │  │ loadData()  │→ │processPendingPrompts│→│ Update UI     │ ││
│  │  └─────────────┘  └────────┬─────────┘  └────────────────┘ ││
│  └────────────────────────────┼─────────────────────────────────┘│
│                               │                                  │
│  ┌────────────────────────────▼─────────────────────────────────┐│
│  │                   CorrectionProcessor (Actor)                ││
│  │  ┌─────────────────────────────────────────────────────────┐││
│  │  │ Claude API │ Gemini API │ OpenAI API                    │││
│  │  └─────────────────────────────────────────────────────────┘││
│  └──────────────────────────────────────────────────────────────┘│
│                               │                                  │
│                               ▼                                  │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │                      StorageManager                          ││
│  │              corrections.json ← Save result                  ││
│  └──────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
Sources/
├── CCLangTutor/              # Main SwiftUI app
│   ├── CCLangTutorApp.swift  # App entry point, WindowGroup
│   ├── ContentView.swift     # NavigationSplitView layout
│   ├── CorrectionListView.swift    # Sidebar list
│   ├── CorrectionDetailView.swift  # Detail view with diff
│   ├── SettingsView.swift    # API keys, provider, language selection
│   ├── CorrectionViewModel.swift   # State management
│   ├── CorrectionProcessor.swift   # AI API calls for corrections (Actor)
│   ├── ChatProcessor.swift   # AI API calls for chat (Actor)
│   ├── ResponseLanguage.swift # Response language enum and settings
│   ├── AIProvider.swift      # Provider enum
│   └── KeychainHelper.swift  # Secure key storage
│
├── CCLangTutorCore/          # Shared models (CLI + App)
│   ├── Correction.swift      # Correction, CorrectionError
│   ├── PendingPrompt.swift   # PendingPrompt model
│   ├── StorageManager.swift  # JSON file I/O
│   └── NotificationNames.swift # DistributedNotification names
│
└── english-teacher/          # CLI hook
    └── main.swift            # Hook entry point
```

## Data Models

### PendingPrompt
```swift
struct PendingPrompt: Codable, Identifiable {
    let id: UUID              // Auto-generated
    let timestamp: Date       // Creation time
    let sessionId: String     // Claude Code session ID
    let prompt: String        // User's original prompt
}
```

### Correction
```swift
struct Correction: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let sessionId: String
    let original: String      // Original text
    let corrected: String     // Corrected text
    let errors: [CorrectionError]
    let isPerfect: Bool       // true if no errors
}

struct CorrectionError: Codable, Identifiable {
    let original: String      // Error portion
    let corrected: String     // Fixed version
    let explanation: String   // Why it's wrong
}
```

## Storage

All data stored in `~/Library/Application Support/CCLangTutor/`:

| File | Purpose |
|------|---------|
| `pending.json` | Queue of prompts awaiting processing |
| `corrections.json` | History of processed corrections |

**JSON Format:**
- Encoding: ISO8601 dates, pretty-printed, sorted keys
- Newest corrections inserted at index 0

## Inter-Process Communication

Uses `DistributedNotificationCenter` for CLI → App communication:

```swift
// Notification name
"sh.saqoo.cclangtutor.newPrompt"

// CLI sends
DistributedNotificationCenter.default().postNotificationName(
    CCLangTutorNotification.newPrompt,
    object: nil,
    deliverImmediately: true
)

// App receives
DistributedNotificationCenter.default().addObserver(
    forName: CCLangTutorNotification.newPrompt,
    ...
)
```

## AI Provider Integration

### Supported Providers

| Provider | Model | Endpoint |
|----------|-------|----------|
| Claude (default) | claude-haiku-4-5-20251001 | api.anthropic.com |
| Gemini | gemini-2.5-flash-lite | generativelanguage.googleapis.com |
| OpenAI | gpt-4o-mini | api.openai.com |

### API Request Flow

1. Build system prompt with response format instructions
2. Append language instruction based on `responseLanguage` setting
3. Send user prompt to selected provider
4. Parse JSON response into `CorrectionResult`
5. Convert to `Correction` model and save

### Response Language

Explanations can be provided in 7 languages (stored in `UserDefaults`):

| Code | Language |
|------|----------|
| `en` | English (default) |
| `ja` | Japanese |
| `es` | Spanish |
| `fr` | French |
| `de` | German |
| `zh` | Chinese |
| `ko` | Korean |

The system prompt is dynamically modified to include language instructions when non-English is selected.

### Expected Response Format
```json
{
  "corrected": "Corrected text here",
  "errors": [
    {
      "original": "wrong part",
      "corrected": "right part",
      "explanation": "Why this is wrong"
    }
  ],
  "isPerfect": false
}
```

## Security

### API Key Storage
Keys stored in macOS Keychain using Security framework:

```swift
// Service identifiers
sh.saqoo.cclangtutor.claude-api-key
sh.saqoo.cclangtutor.gemini-api-key
sh.saqoo.cclangtutor.openai-api-key
```

### Entitlements
- App Sandbox: Disabled (needs file access)
- Hardened Runtime: Enabled
- Network access: Required for API calls

## UI Architecture

### View Hierarchy
```
CCLangTutorApp
├── WindowGroup
│   └── ContentView
│       └── NavigationSplitView
│           ├── CorrectionListView (sidebar)
│           │   ├── PendingRowView (processing items)
│           │   └── CorrectionRowView (history items)
│           └── CorrectionDetailView (detail)
│               ├── headerSection
│               ├── diffSection (Original → Corrected)
│               └── errorsSection
│                   └── ErrorCardView (per error)
└── Settings
    └── SettingsView
```

### State Management
`CorrectionViewModel` is the single source of truth:

```swift
@MainActor
class CorrectionViewModel: ObservableObject {
    @Published var corrections: [Correction]
    @Published var pendingPrompts: [PendingPrompt]
    @Published var isProcessing: Bool
    @Published var selectedCorrectionId: UUID?
}
```

## CLI Hook Behavior

### Input Format
```json
{
  "session_id": "uuid-string",
  "prompt": "user's input text"
}
```

### Slash Command Handling
- `/command` (no args) → Skip entirely
- `/command args here` → Correct only "args here"

### Launch Behavior
App launched with `-g` flag (no activation, background):
```swift
open -g -a CCLangTutor
```

## Build System

Uses XcodeGen for project generation:

```bash
# Generate Xcode project
xcodegen generate

# Build app
xcodebuild -project CCLangTutor.xcodeproj \
           -scheme CCLangTutor \
           -configuration Debug

# Build CLI
xcodebuild -project CCLangTutor.xcodeproj \
           -scheme english-teacher \
           -configuration Debug

# Copy CLI into app bundle
cp english-teacher CCLangTutor.app/Contents/MacOS/
```

## Deployment

### Bundle Identifiers
- App: `sh.saqoo.cclangtutor`
- CLI: Embedded in app bundle

### Requirements
- macOS 14.0+
- Swift 5.9+
- Xcode 15+

### Claude Code Hook Setup
```json
// ~/.claude/settings.json
{
  "hooks": {
    "UserPromptSubmit": [{
      "hooks": [{
        "type": "command",
        "command": "/path/to/CCLangTutor.app/Contents/MacOS/english-teacher"
      }]
    }]
  }
}
```
