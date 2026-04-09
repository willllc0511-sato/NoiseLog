import SwiftUI

/// メインタブバー画面
struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "waveform")
                }

            RecordListView()
                .tabItem {
                    Label("記録一覧", systemImage: "list.bullet")
                }

            ReportView()
                .tabItem {
                    Label("レポート", systemImage: "chart.bar")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
        .tint(AppTheme.accentYellow)
    }
}
