import InspireBarCore
import SwiftUI

@MainActor
struct MenuBarLayoutEditor: View {
    let store: InspireStore
    @State private var selectedPosition: MenuBarLayoutPosition?

    private var layout: MenuBarLayout {
        self.store.preferences.menuBarLayout
    }

    private var canRemoveSelection: Bool {
        self.selectedPosition.map { self.layout.removing(at: $0) != self.layout } ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            self.lineCountPicker
            self.presets
            self.preview
            self.layoutStrip
            self.removeDropTarget
            Divider()
            self.palette
        }
        .padding(.vertical, 4)
        .onDeleteCommand { self.removeSelectedToken() }
    }

    private var lineCountPicker: some View {
        HStack {
            Text("显示行数")
            Spacer()
            Picker("显示行数", selection: Binding(
                get: { self.layout.lines.count == 2 },
                set: { self.write($0 ? self.layout.withTwoLines() : self.layout.removingLineBreak()) }))
            {
                Text("单行").tag(false)
                Text("双行").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var presets: some View {
        HStack {
            Text("布局预设")
            Spacer()
            Menu {
                ForEach(MenuBarLayoutPreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                    Button(preset.title) {
                        if let layout = preset.layout {
                            self.write(layout)
                        }
                    }
                }
            } label: {
                Text(MenuBarLayoutPreset.matching(self.layout).title)
            }
            .menuStyle(.button)
            .accessibilityLabel("布局预设")
        }
    }

    private var preview: some View {
        let output = MenuBarLayoutRenderer.render(layout: self.layout, store: self.store)
        return VStack(alignment: .leading, spacing: 5) {
            Text("实时预览")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                Image(nsImage: output.image)
                    .fixedSize()
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(output.accessibilityLabel)
            }
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.background.opacity(0.75)))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(.separator.opacity(0.65), lineWidth: 1))
        }
    }

    private var layoutStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("菜单栏中的组件")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(self.layout.lines.indices, id: \.self) { index in
                self.layoutLine(index)
            }
        }
    }

    private func layoutLine(_ line: Int) -> some View {
        let tokens = self.layout.lines[line]
        let layout = self.layout
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                    let position = MenuBarLayoutPosition(line: line, index: index)
                    MenuBarLayoutEditorChip(
                        title: token.title,
                        systemImage: token.systemImage,
                        isSelected: self.selectedPosition == position,
                        accessibilityLabel: "已添加：\(token.title)",
                        accessibilityHint: "拖动排序，或选中后移除",
                        dragItem: .placed(token, at: position, in: layout),
                        activate: { self.selectedPosition = position },
                        removeActionTitle: "移除",
                        remove: { self.write(self.layout.removing(at: position)) })
                        .dropDestination(for: MenuBarLayoutDragItem.self) { items, _ in
                            self.insert(items.first, at: position)
                        }
                        .contextMenu {
                            Button("左移") { self.move(token, from: position, to: index - 1) }
                                .disabled(index == 0)
                            Button("右移") { self.move(token, from: position, to: index + 2) }
                                .disabled(index + 1 == tokens.count)
                        }
                }
                if tokens.isEmpty {
                    Text("将组件拖到此处")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
        }
        .frame(minHeight: 34)
        .background(Color.accentColor.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.secondary.opacity(0.35)))
        .dropDestination(for: MenuBarLayoutDragItem.self) { items, _ in
            self.insert(items.first, at: MenuBarLayoutPosition(line: line, index: tokens.count))
        }
        .accessibilityLabel("第 \(line + 1) 行")
    }

    private var removeDropTarget: some View {
        let title = self.canRemoveSelection ? "移除选中组件" : "拖到此处移除"
        return Label(title, systemImage: "trash")
            .font(.caption)
            .foregroundStyle(self.canRemoveSelection ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onTapGesture { self.removeSelectedToken() }
            .dropDestination(for: MenuBarLayoutDragItem.self) { items, _ in
                guard let item = items.first, item.sourceLayout == self.layout, let source = item.source else {
                    return false
                }
                return self.write(self.layout.removing(at: source))
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { self.removeSelectedToken() }
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("可添加的组件")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            MenuBarLayoutChipFlowLayout(spacing: 6) {
                ForEach(MenuBarLayoutToken.allCases, id: \.self) { token in
                    MenuBarLayoutEditorChip(
                        title: token.title,
                        systemImage: token.systemImage,
                        accessibilityLabel: "添加：\(token.title)",
                        accessibilityHint: "点击添加到末尾，或拖到任意一行",
                        dragItem: .palette(token),
                        activate: { self.write(self.layout.appending(token)) })
                }
                MenuBarLayoutEditorChip(
                    title: "换行",
                    systemImage: "arrow.turn.down.right",
                    isDisabled: self.layout.lines.count == 2,
                    accessibilityLabel: "添加换行",
                    dragItem: .lineBreak,
                    activate: { self.write(self.layout.addingLineBreak()) })
            }
        }
    }

    private func insert(_ item: MenuBarLayoutDragItem?, at position: MenuBarLayoutPosition) -> Bool {
        guard let item else { return false }
        switch item.content {
        case .lineBreak:
            return self.write(self.layout.addingLineBreak(at: position.index))
        case let .token(token):
            guard item.source == nil || item.sourceLayout == self.layout else { return false }
            return self.write(self.layout.inserting(token, at: position, from: item.source))
        }
    }

    private func move(_ token: MenuBarLayoutToken, from position: MenuBarLayoutPosition, to index: Int) {
        let target = MenuBarLayoutPosition(line: position.line, index: index)
        self.write(self.layout.inserting(token, at: target, from: position))
    }

    private func removeSelectedToken() {
        guard let position = self.selectedPosition else { return }
        self.write(self.layout.removing(at: position))
    }

    @discardableResult
    private func write(_ layout: MenuBarLayout) -> Bool {
        guard self.layout != layout else { return false }
        self.store.preferences.menuBarLayout = layout
        self.selectedPosition = nil
        return true
    }
}
