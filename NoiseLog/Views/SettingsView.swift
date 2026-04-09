import SwiftUI
import UserNotifications

/// 設定画面：通知リマインド、プライバシーポリシー、お問い合わせ等
struct SettingsView: View {
    /// リマインド通知のON/OFF
    @AppStorage("reminderEnabled") private var reminderEnabled: Bool = false

    /// リマインド時刻
    @AppStorage("reminderHour") private var reminderHour: Int = 21
    @AppStorage("reminderMinute") private var reminderMinute: Int = 0

    /// 通知時刻のDate表現（ピッカー用）
    @State private var reminderTime: Date = Date()

    /// 通知権限拒否時のアラート
    @State private var showPermissionAlert: Bool = false

    /// アプリバージョン
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.darkNavy
                    .ignoresSafeArea()

                List {
                    // 通知設定セクション
                    notificationSection

                    // サポートセクション
                    supportSection

                    // アプリ情報セクション
                    aboutSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                // 保存済みの時刻をDateに変換
                var components = DateComponents()
                components.hour = reminderHour
                components.minute = reminderMinute
                reminderTime = Calendar.current.date(from: components) ?? Date()
            }
            .alert("通知が許可されていません", isPresented: $showPermissionAlert) {
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("キャンセル", role: .cancel) {
                    reminderEnabled = false
                }
            } message: {
                Text("リマインド通知を使うには、設定アプリで通知を許可してください。")
            }
        }
    }

    // MARK: - 通知設定

    /// 通知リマインドの設定セクション
    private var notificationSection: some View {
        Section {
            // リマインドON/OFFトグル
            Toggle(isOn: $reminderEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .foregroundColor(AppTheme.accentYellow)
                    Text("毎日のリマインド")
                        .foregroundColor(.white)
                }
            }
            .tint(AppTheme.accentYellow)
            .onChange(of: reminderEnabled) { _, newValue in
                if newValue {
                    requestNotificationPermission()
                } else {
                    cancelReminder()
                }
            }
            .listRowBackground(AppTheme.cardBackground)

            // 時刻選択（ONの場合のみ表示）
            if reminderEnabled {
                DatePicker(
                    selection: $reminderTime,
                    displayedComponents: .hourAndMinute
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .foregroundColor(AppTheme.accentYellow)
                        Text("通知時刻")
                            .foregroundColor(.white)
                    }
                }
                .datePickerStyle(.compact)
                .tint(AppTheme.accentYellow)
                .onChange(of: reminderTime) { _, newValue in
                    let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    reminderHour = components.hour ?? 21
                    reminderMinute = components.minute ?? 0
                    scheduleReminder()
                }
                .listRowBackground(AppTheme.cardBackground)
            }
        } header: {
            Text("通知")
                .foregroundColor(.gray)
        }
    }

    // MARK: - サポート

    /// プライバシーポリシー・お問い合わせセクション
    private var supportSection: some View {
        Section {
            // プライバシーポリシー
            Link(destination: URL(string: "https://will-llc.co.jp/privacy")!) {
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(AppTheme.accentYellow)
                    Text("プライバシーポリシー")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .listRowBackground(AppTheme.cardBackground)

            // お問い合わせ
            Link(destination: URL(string: "mailto:support@will-llc.co.jp?subject=騒音ログ お問い合わせ")!) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(AppTheme.accentYellow)
                    Text("お問い合わせ")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .listRowBackground(AppTheme.cardBackground)
        } header: {
            Text("サポート")
                .foregroundColor(.gray)
        }
    }

    // MARK: - アプリ情報

    /// バージョン情報セクション
    private var aboutSection: some View {
        Section {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundColor(AppTheme.accentYellow)
                    Text("バージョン")
                        .foregroundColor(.white)
                }
                Spacer()
                Text(appVersion)
                    .foregroundColor(.gray)
            }
            .listRowBackground(AppTheme.cardBackground)

            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .foregroundColor(AppTheme.accentYellow)
                    Text("開発")
                        .foregroundColor(.white)
                }
                Spacer()
                Text("合同会社Will")
                    .foregroundColor(.gray)
            }
            .listRowBackground(AppTheme.cardBackground)
        } header: {
            Text("アプリ情報")
                .foregroundColor(.gray)
        }
    }

    // MARK: - 通知処理

    /// 通知権限をリクエストし、許可されたらリマインドを設定する
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    scheduleReminder()
                } else {
                    showPermissionAlert = true
                }
            }
        }
    }

    /// 毎日のリマインド通知をスケジュールする
    private func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])

        let content = UNMutableNotificationContent()
        content.title = "騒音ログ"
        content.body = "今日の騒音を記録しましたか？"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)

        center.add(request)
    }

    /// リマインド通知をキャンセルする
    private func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
    }
}
