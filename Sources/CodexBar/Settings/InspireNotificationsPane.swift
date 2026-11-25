import AppKit
import SwiftUI
import UserNotifications

@MainActor
struct InspireNotificationsPane: View {
    @Bindable var preferences: InspirePreferences
    @State private var permission: UNAuthorizationStatus?

    var body: some View {
        Form {
            Section("公共科研项目") {
                Toggle("点券余额偏低", isOn: self.$preferences.alerts.lowBalance)
                SettingsMenuPicker(
                    selection: self.$preferences.alerts.threshold,
                    options: InspireQuotaAlerts.thresholds,
                    label: { Text("余额提醒阈值") },
                    optionLabel: { Text("\($0)%") })
                    .disabled(!self.preferences.alerts.lowBalance)
                Toggle("预计在刷新前耗尽", isOn: self.$preferences.alerts.projectedDepletion)
                Toggle("每周点券刷新", isOn: self.$preferences.alerts.newCycle)
            }
            Section("系统权限") {
                switch self.permission {
                case .authorized, .provisional:
                    LabeledContent("通知", value: "已允许")
                case .denied:
                    LabeledContent("通知", value: "已关闭")
                    Button("打开通知设置…") {
                        if let settings =
                            URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
                        {
                            NSWorkspace.shared.open(settings)
                        }
                    }
                default:
                    Button("允许通知…") {
                        Task {
                            _ = try? await UNUserNotificationCenter.current().requestAuthorization(
                                options: [.alert, .sound])
                            await self.updatePermission()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .task { await self.updatePermission() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await self.updatePermission() }
        }
    }

    private func updatePermission() async {
        self.permission = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
