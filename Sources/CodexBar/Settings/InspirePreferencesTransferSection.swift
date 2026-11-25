import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct InspirePreferencesTransferSection: View {
    let store: InspireStore
    @State private var failure: String?

    var body: some View {
        Section {
            HStack {
                Button("导出设置…") { self.transfer(importing: false) }
                Button("导入设置…") { self.transfer(importing: true) }
            }
        } header: {
            Text("可移植设置")
        } footer: {
            Text("保存显示、刷新和通知偏好。账号、登录信息和账单留在本机。")
        }
        .alert("无法传输设置", isPresented: Binding(
            get: { self.failure != nil },
            set: { if !$0 { self.failure = nil } }))
        {
            Button("好", role: .cancel) {}
        } message: {
            Text(self.failure ?? "")
        }
    }

    private func transfer(importing: Bool) {
        let panel: NSSavePanel = importing ? NSOpenPanel() : NSSavePanel()
        panel.allowedContentTypes = [.json]
        if let open = panel as? NSOpenPanel {
            open.allowsMultipleSelection = false
        } else {
            panel.nameFieldStringValue = "InspireBar-preferences.json"
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if importing {
                let data = try Data(contentsOf: url)
                let document = try JSONDecoder().decode(InspirePreferencesDocument.self, from: data)
                try self.store.importPreferences(document)
            } else {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(self.store.preferences.exportDocument())
                try data.write(to: url, options: .atomic)
            }
        } catch {
            self.failure = error.localizedDescription
        }
    }
}
