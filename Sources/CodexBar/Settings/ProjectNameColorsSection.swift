import SwiftUI

@MainActor
struct ProjectNameColorsSection: View {
    let store: InspireStore

    var body: some View {
        Section("项目名称颜色") {
            if let snapshot = self.store.snapshot, let account = snapshot.account,
               let projects = snapshot.latest?.projects, !projects.isEmpty
            {
                ForEach(projects) { project in
                    ProjectNameColorRow(project: project.name, account: account, preferences: self.store.preferences)
                }
            } else {
                Text("同步后可为项目选择颜色。").foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor
struct ProjectNameColorRow: View {
    let project: String
    let account: String
    let preferences: InspirePreferences

    var body: some View {
        LabeledContent(self.project) {
            HStack(spacing: 8) {
                if self.selectedColor != .black {
                    Button {
                        self.preferences.setProjectNameColor(.black, project: self.project, account: self.account)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderless)
                    .help("恢复默认颜色")
                    .accessibilityLabel("恢复 \(self.project) 的默认颜色")
                }
                ColorPicker(self.project, selection: self.colorSelection, supportsOpacity: false)
                    .labelsHidden()
            }
        }
    }

    var colorSelection: Binding<Color> {
        Binding(get: { self.selectedColor.swatch }, set: { color in
            guard let stored = ProjectNameColor.selected(color) else { return }
            self.preferences.setProjectNameColor(stored, project: self.project, account: self.account)
        })
    }

    private var selectedColor: ProjectNameColor {
        self.preferences.projectNameColor(self.project, account: self.account)
    }
}
