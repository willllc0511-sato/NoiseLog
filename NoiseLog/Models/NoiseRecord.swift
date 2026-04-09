import Foundation
import SwiftData

/// 騒音記録データモデル
@Model
final class NoiseRecord {
    /// 記録日時
    var timestamp: Date

    /// デシベル値
    var decibelLevel: Double

    /// ユーザーが入力したメモ（任意）
    var memo: String

    /// 録音ファイルのパス（任意）
    var audioFilePath: String?

    init(
        timestamp: Date = .now,
        decibelLevel: Double,
        memo: String = "",
        audioFilePath: String? = nil
    ) {
        self.timestamp = timestamp
        self.decibelLevel = decibelLevel
        self.memo = memo
        self.audioFilePath = audioFilePath
    }
}
