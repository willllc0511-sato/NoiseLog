import SwiftUI
import SwiftData

/// アプリのエントリーポイント
@main
struct NoiseLogApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: NoiseRecord.self)
    }
}
