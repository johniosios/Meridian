import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var apiConfig: APIConfig
    @EnvironmentObject private var folderStore: FolderStore
    @EnvironmentObject private var notif: NotificationManager

    @State private var showAPIKey = false
    @State private var showingFolderPicker = false
    @State private var testResult: String?

    var body: some View {
        NavigationStack {
            Form {
                aiSection
                notificationSection
                storageSection
                automationSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showingFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleFolderPick(result: result)
            }
        }
    }

    // MARK: - AI

    private var aiSection: some View {
        Section {
            Picker("Provider", selection: $apiConfig.provider) {
                ForEach(APIConfig.Provider.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }

            HStack {
                Text("Model")
                Spacer()
                TextField("Model name", text: $apiConfig.model)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Base URL")
                Spacer()
                TextField("https://...", text: $apiConfig.baseURL)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }

            HStack {
                if showAPIKey {
                    TextField("API Key", text: $apiConfig.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.footnote)
                } else {
                    SecureField("API Key", text: $apiConfig.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Button {
                    showAPIKey.toggle()
                } label: {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                Task { await testAPI() }
            } label: {
                Label("Test Connection", systemImage: "network")
            }
            .disabled(!apiConfig.isConfigured)

            if let result = testResult {
                Text(result).font(.caption).foregroundStyle(result.hasPrefix("✓") ? .green : .red)
            }
        } header: {
            Text("AI Analysis")
        } footer: {
            Text("API key is stored in the device Keychain and cleared if you reinstall the app.")
                .font(.caption2)
        }
    }

    // MARK: - Notification

    private var notificationSection: some View {
        Section {
            Toggle("Daily Reminder", isOn: Binding(
                get: { notif.dailyEnabled },
                set: { newValue in
                    Task {
                        if newValue { await notif.enableDaily() }
                        else { notif.disableDaily() }
                    }
                }
            ))

            if notif.dailyEnabled {
                DatePicker(
                    "Reminder Time",
                    selection: $notif.dailyTime,
                    displayedComponents: .hourAndMinute
                )

                if !notif.isAuthorized {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications are disabled").font(.subheadline)
                            Text("Go to iPhone Settings → Notifications → Meridian → enable Allow Notifications")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    Task { await notif.triggerNow() }
                } label: {
                    Label("Send Test Notification (in 5 s)", systemImage: "bell.badge")
                }
            }
        } header: {
            Text("Daily Notifications")
        } footer: {
            Text("A banner appears at the scheduled time. Opening the app from the notification regenerates AI insights on the home screen. Local notifications work with a free developer account.")
                .font(.caption2)
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        Section("Export Storage") {
            HStack {
                Image(systemName: folderIcon)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(folderStore.displayPath)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                Spacer()
                Button("Change") { showingFolderPicker = true }
            }

            if folderStore.folderURL != nil {
                Button(role: .destructive) {
                    folderStore.clear()
                } label: {
                    Label("Reset to Local Default", systemImage: "arrow.uturn.backward")
                }
            }
        }
    }

    private var folderIcon: String {
        guard let url = folderStore.folderURL else { return "folder" }
        return url.path.contains("Mobile Documents") ? "icloud" : "folder"
    }

    // MARK: - Automation

    private var automationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Shortcuts Automation").font(.subheadline).bold()
                Text("""
                This app exposes an "Export Health Data" Shortcuts action. \
                Open the iOS Shortcuts app → Automation → New → Daily at a set time → Add Action → choose "Export Health Data". \
                The first run prompts for permissions; after that it runs automatically each day.
                """)
                .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Scheduled Export")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack { Text("Version"); Spacer(); Text("0.5.0").foregroundStyle(.secondary) }
            HStack { Text("Data Source"); Spacer(); Text("Apple HealthKit").foregroundStyle(.secondary) }
        }
    }

    // MARK: - Actions

    private func handleFolderPick(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            try? folderStore.setFolder(url)
        case .failure:
            break
        }
    }

    private func testAPI() async {
        testResult = "Testing..."
        let client = APIClient(config: apiConfig)
        do {
            let resp = try await client.chat(system: "You are a test.", user: "Reply with exactly: OK", maxTokens: 10)
            testResult = "✓ Success: \(resp.prefix(40))"
        } catch {
            testResult = "✗ \(error.localizedDescription)"
        }
    }
}
