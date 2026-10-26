extension VoiceAIAudioConfig {
    private static let defaultVoiceprintAutoEnrollMs = 3000

    init(language: String,
                enableVoiceprintDenoise: Bool? = nil,
                voiceprintAutoEnrollMs: Int? = nil,
                enablePCMOutput: Bool? = nil) {
        self.userLanguage = language
        self.userEnableVoiceprintDenoise = enableVoiceprintDenoise
        self.userVoiceprintAutoEnrollMs = voiceprintAutoEnrollMs
        self.userEnablePCMOutput = enablePCMOutput
    }

    var language: String {
        get { userLanguage }
        set { userLanguage = newValue }
    }

    var enableVoiceprintDenoise: Bool {
        get { userEnableVoiceprintDenoise ?? false }
        set { userEnableVoiceprintDenoise = newValue }
    }

    var voiceprintAutoEnrollMs: Int {
        get { userVoiceprintAutoEnrollMs ?? Self.defaultVoiceprintAutoEnrollMs }
        set { userVoiceprintAutoEnrollMs = newValue }
    }

    var enablePCMOutput: Bool {
        get { userEnablePCMOutput ?? true }
        set { userEnablePCMOutput = newValue }
    }
}
