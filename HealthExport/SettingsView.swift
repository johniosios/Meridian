import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var apiConfig: APIConfig
    @EnvironmentObject private var folderStore: FolderStore

    @State private var showAPIKey = false
    @State private var showingFolderPicker = false
    @State private var testResult: String?

    var body: some View {
        NavigationStack {
            Form {
                aiSection
                storageSection
                automationSection
                aboutSection
            }
            .navigationTitle("设置")
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
                Text("模型")
                Spacer()
                TextField("模型名", text: $apiConfig.model)
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
                Label("测试连接", systemImage: "network")
            }
            .disabled(!apiConfig.isConfigured)

            if let result = testResult {
                Text(result).font(.caption).foregroundStyle(result.hasPrefix("✓") ? .green : .red)
            }
        } header: {
            Text("AI 分析")
        } footer: {
            Text("API Key 存在设备 Keychain，重装 App 会清除。")
                .font(.caption2)
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        Section("导出存储") {
            HStack {
                Image(systemName: folderIcon)
                VStack(alignment: .leading, spacing: 2) {
                    Text("目录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(folderStore.displayPath)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                Spacer()
                Button("更改") { showingFolderPicker = true }
            }

            if folderStore.folderURL != nil {
                Button(role: .destructive) {
                    folderStore.clear()
                } label: {
                    Label("恢复为本地默认", systemImage: "arrow.uturn.backward")
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
                Text("Shortcuts 自动化").font(.subheadline).bold()
                Text("""
                本 App 暴露 "导出健康数据" 快捷指令动作。\
                打开 iOS "快捷指令" App → 自动化 → 新建 → 每天某时间 → 添加动作 → 选 "导出健康数据"。\
                首次运行会弹权限，之后每天自动跑。
                """)
                .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("定时导出")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("关于") {
            HStack { Text("版本"); Spacer(); Text("0.5.0").foregroundStyle(.secondary) }
            HStack { Text("数据来源"); Spacer(); Text("Apple HealthKit").foregroundStyle(.secondary) }
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
        testResult = "测试中..."
        let client = APIClient(config: apiConfig)
        do {
            let resp = try await client.chat(system: "You are a test.", user: "Reply with exactly: OK", maxTokens: 10)
            testResult = "✓ 成功：\(resp.prefix(40))"
        } catch {
            testResult = "✗ \(error.localizedDescription)"
        }
    }
}
