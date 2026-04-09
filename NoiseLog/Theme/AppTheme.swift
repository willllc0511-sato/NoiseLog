import SwiftUI

/// スクリーンショット用デモモード（撮影後にfalseに戻す）
enum DemoMode {
    static let isEnabled: Bool = true
}

/// アプリ全体のテーマカラー定義
enum AppTheme {
    /// ダークネイビー背景色
    static let darkNavy = Color(red: 0.08, green: 0.09, blue: 0.16)

    /// やや明るいネイビー（カード背景等）
    static let cardBackground = Color(red: 0.12, green: 0.13, blue: 0.22)

    /// 静か（〜40dB）：緑
    static let accentGreen = Color(red: 0.18, green: 0.80, blue: 0.44)

    /// 普通（40〜60dB）：黄
    static let accentYellow = Color(red: 1.0, green: 0.80, blue: 0.0)

    /// うるさい（60dB〜）：赤
    static let accentRed = Color(red: 0.93, green: 0.26, blue: 0.26)

    /// dB値に応じた色を返す
    static func colorForDecibel(_ db: Double) -> Color {
        if db < 40 {
            return accentGreen
        } else if db < 60 {
            return accentYellow
        } else {
            return accentRed
        }
    }

    /// dB値に応じたラベルを返す
    static func labelForDecibel(_ db: Double) -> String {
        if db < 40 {
            return "静か"
        } else if db < 60 {
            return "普通"
        } else {
            return "うるさい"
        }
    }
}
