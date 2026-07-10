import SwiftUI
import AVFoundation

/// 録音の再生を管理する。再生完了時に自動的に停止状態へ戻し、
/// マナーモード（サイレントスイッチON）でも再生できるよう再生用セッションを設定する。
final class RecordingPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    /// 再生中かどうか
    @Published var isPlaying: Bool = false

    private var player: AVAudioPlayer?

    /// 指定した録音ファイルを再生する
    func play(fileName: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)

        do {
            // サイレントスイッチがONでも再生されるよう再生用セッションに切り替える
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.delegate = self
            player.play()
            self.player = player
            isPlaying = true
        } catch {
            // ファイル再生エラー
            isPlaying = false
        }
    }

    /// 再生を停止する
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    /// 再生が最後まで完了したときに呼ばれる
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        isPlaying = false
    }
}

/// 記録詳細画面：個別の騒音記録の詳細を表示・メモ編集
struct RecordDetailView: View {
    @Bindable var record: NoiseRecord

    /// 音声再生の管理
    @StateObject private var player = RecordingPlayer()

    /// メモ編集中かどうか
    @State private var isEditingMemo: Bool = false

    /// 日時のフォーマッター
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月d日 (EEE) HH:mm:ss"
        return f
    }()

    var body: some View {
        ZStack {
            AppTheme.darkNavy
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // デシベル値の大きな表示
                    decibelCard

                    // 詳細情報
                    detailCard

                    // 録音再生（ファイルがある場合のみ）
                    if record.audioFilePath != nil {
                        audioCard
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("記録詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear {
            player.stop()
        }
    }

    // MARK: - デシベルカード

    /// dB値を大きく表示するカード
    private var decibelCard: some View {
        VStack(spacing: 12) {
            Text(String(format: "%.1f", record.decibelLevel))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.colorForDecibel(record.decibelLevel))

            Text("dB - \(AppTheme.labelForDecibel(record.decibelLevel))")
                .font(.title3)
                .foregroundColor(AppTheme.colorForDecibel(record.decibelLevel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 詳細カード

    /// 日時・メモの詳細情報カード
    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 日時
            DetailRow(
                icon: "calendar",
                title: "日時",
                value: Self.dateFormatter.string(from: record.timestamp)
            )

            Divider()
                .background(Color.gray.opacity(0.3))

            // メモ（タップで編集）
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "pencil")
                        .foregroundColor(AppTheme.accentYellow)
                        .frame(width: 24)

                    Text("メモ")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    Button {
                        isEditingMemo.toggle()
                    } label: {
                        Text(isEditingMemo ? "完了" : "編集")
                            .font(.caption)
                            .foregroundColor(AppTheme.accentYellow)
                    }
                }

                if isEditingMemo {
                    TextField("メモを入力（例：足音、ドアの開閉）", text: $record.memo)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(AppTheme.darkNavy)
                        .cornerRadius(8)
                } else {
                    Text(record.memo.isEmpty ? "（タップして追加）" : record.memo)
                        .font(.body)
                        .foregroundColor(record.memo.isEmpty ? .gray.opacity(0.5) : .white)
                        .padding(.leading, 36)
                        .onTapGesture {
                            isEditingMemo = true
                        }
                }
            }
        }
        .padding(20)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 音声再生カード

    /// 録音の再生カード
    private var audioCard: some View {
        Button(action: togglePlayback) {
            HStack {
                Image(systemName: player.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(AppTheme.accentYellow)

                Text(player.isPlaying ? "再生停止" : "録音を再生")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(20)
            .background(AppTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    /// 音声の再生/停止を切り替える
    private func togglePlayback() {
        if player.isPlaying {
            player.stop()
        } else {
            guard let fileName = record.audioFilePath else { return }
            player.play(fileName: fileName)
        }
    }
}

/// 詳細画面の情報行
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.accentYellow)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.body)
                    .foregroundColor(.white)
            }
        }
    }
}
