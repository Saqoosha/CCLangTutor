import SwiftUI

struct SettingsView: View {
    @AppStorage("aiProvider") private var aiProviderRaw = AIProvider.claudeAPI.rawValue
    @AppStorage("systemPrompt") private var systemPrompt = SettingsView.defaultSystemPrompt
    @AppStorage(ResponseLanguage.userDefaultsKey) private var responseLanguage = ResponseLanguage.english.rawValue

    @State private var claudeAPIKey = ""
    @State private var geminiAPIKey = ""
    @State private var openAIAPIKey = ""
    @State private var showingSaveConfirmation = false
    @State private var saveConfirmationMessage = ""
    @State private var showingIgnoredRules = false
    @State private var ignoredRulesCount = 0

    static let defaultSystemPrompt = """
    You are a friendly English tutor for a developer using CLI tools. When correcting:
    - Focus on grammar and spelling errors only
    - Accept casual, chatty, text-style English (e.g., "gonna", "wanna", "lol", "btw")
    - Don't flag informal contractions or internet slang as errors
    - Only correct actual mistakes, not stylistic choices
    - Keep explanations brief and practical
    - If the text is understandable and grammatically acceptable for casual writing, mark it as perfect
    - Leave non-English text (Japanese, Chinese, Korean, etc.) as-is - do not treat foreign words as misspellings
    """

    private var aiProvider: AIProvider {
        AIProvider(rawValue: aiProviderRaw) ?? .claudeAPI
    }

    var body: some View {
        Form {
            Section {
                Picker("AI Provider", selection: $aiProviderRaw) {
                    ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
            } header: {
                Text("AI Provider")
            } footer: {
                Text("Model: \(aiProvider.defaultModel)")
            }

            Section {
                SecureField(aiProvider.apiKeyPlaceholder, text: apiKeyBinding)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save to Keychain") {
                        saveAPIKey(apiKeyBinding.wrappedValue, service: aiProvider.keychainService)
                    }
                    .disabled(apiKeyBinding.wrappedValue.isEmpty)

                    if KeychainHelper.load(service: aiProvider.keychainService) != nil {
                        Text("✓ Saved")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
            } header: {
                Text("\(aiProvider.displayName) API Key")
            } footer: {
                Text("Get your API key from \(aiProvider.apiKeyHelpURL)")
            }

            Section {
                Picker("Explanations in", selection: $responseLanguage) {
                    ForEach(ResponseLanguage.allCases, id: \.rawValue) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
            } header: {
                Text("Response Language")
            } footer: {
                Text("Language for correction explanations and chat responses")
            }

            Section {
                TextEditor(text: $systemPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 80)

                Button("Reset to Default") {
                    systemPrompt = SettingsView.defaultSystemPrompt
                }
                .foregroundStyle(.secondary)
            } header: {
                Text("Tutor Personality")
            }

            Section {
                Button {
                    showingIgnoredRules = true
                } label: {
                    HStack {
                        Text("Ignored Rules")
                        Spacer()
                        if ignoredRulesCount > 0 {
                            Text("\(ignoredRulesCount)")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.secondary))
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("Correction Filters")
            } footer: {
                Text("Manage rules for corrections you don't want to see")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 450)
        .fixedSize(horizontal: false, vertical: true)
        .alert("API Key", isPresented: $showingSaveConfirmation) {
            Button("OK") { }
        } message: {
            Text(saveConfirmationMessage)
        }
        .onAppear {
            loadAPIKeys()
            loadIgnoredRulesCount()
        }
        .sheet(isPresented: $showingIgnoredRules) {
            IgnoredRulesView()
        }
        .onChange(of: showingIgnoredRules) {
            if !showingIgnoredRules {
                loadIgnoredRulesCount()
            }
        }
    }

    private var apiKeyBinding: Binding<String> {
        switch aiProvider {
        case .claudeAPI: return $claudeAPIKey
        case .gemini: return $geminiAPIKey
        case .openAI: return $openAIAPIKey
        }
    }

    private func loadAPIKeys() {
        if let key = KeychainHelper.load(service: KeychainHelper.claudeAPIService) {
            claudeAPIKey = key
        }
        if let key = KeychainHelper.load(service: KeychainHelper.geminiAPIService) {
            geminiAPIKey = key
        }
        if let key = KeychainHelper.load(service: KeychainHelper.openAIAPIService) {
            openAIAPIKey = key
        }
    }

    private func saveAPIKey(_ key: String, service: String) {
        do {
            try KeychainHelper.save(key: key, service: service)
            saveConfirmationMessage = "API key saved successfully"
        } catch {
            saveConfirmationMessage = "Failed to save: \(error.localizedDescription)"
        }
        showingSaveConfirmation = true
    }

    private func loadIgnoredRulesCount() {
        ignoredRulesCount = StorageManager.shared.loadIgnoredRules().count
    }
}

#Preview {
    SettingsView()
}
