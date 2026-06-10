import SwiftUI

/// メインタブバー画面
struct ContentView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "waveform")
                }
                .tag(0)

            RecordListView()
                .tabItem {
                    Label("記録一覧", systemImage: "list.bullet")
                }
                .tag(1)

            ReportView()
                .tabItem {
                    Label("レポート", systemImage: "chart.bar")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
                .tag(3)
        }
        .tint(AppTheme.accentYellow)
        .onReceive(NotificationCenter.default.publisher(for: .openSubscriptionSettings)) { _ in
            selectedTab = 3
        }
    }
}
