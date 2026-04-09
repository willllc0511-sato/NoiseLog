import SwiftUI
import SwiftData

/// ホーム画面：dBメーターと録音ボタンのみのシンプルな画面
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioManager = AudioManager()

    /// 録音中のファイルパス
    @State private var currentRecordingURL: URL?

    /// 録音ボタン点滅用
    @State private var isBlinking: Bool = false

    /// 保存フィードバック表示
    @State private var showSavedFeedback: Bool = false

    /// 録音中の最大dB値を記録
    @State private var peakDecibel: Double = 0

    /// デモ用固定dB値
    private let demoDecibel: Double = 65.0

    /// 表示用のdB値（デモモード時は固定値）
    private var displayDecibel: Double {
        DemoMode.isEnabled ? demoDecibel : audioManager.currentDecibel
    }

    var body: some View {
        ZStack {
            AppTheme.darkNavy
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // アプリ名
                Text("騒音ログ")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 8)

                Spacer()
                    .frame(maxHeight: 60)

                // デシベル数値
                Text(String(format: "%.0f", displayDecibel))
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.colorForDecibel(displayDecibel))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.15), value: Int(displayDecibel))

                Text("dB")
                    .font(.title)
                    .foregroundColor(.gray)
                    .padding(.top, 4)

                // レベルラベル
                Text(AppTheme.labelForDecibel(displayDecibel))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.colorForDecibel(displayDecibel))
                    .padding(.top, 12)

                Spacer()

                // 録音中：経過時間表示
                if audioManager.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AppTheme.accentRed)
                            .frame(width: 8, height: 8)
                            .opacity(isBlinking ? 1.0 : 0.3)

                        Text(formattedTime(audioManager.recordingElapsed))
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(AppTheme.accentRed)
                    }
                    .padding(.bottom, 12)
                }

                // 録音ボタン（赤い丸）
                VStack(spacing: 6) {
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .stroke(AppTheme.accentRed, lineWidth: 3)
                                .frame(width: 60, height: 60)

                            if audioManager.isRecording {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppTheme.accentRed)
                                    .frame(width: 20, height: 20)
                                    .opacity(isBlinking ? 1.0 : 0.5)
                            } else {
                                Circle()
                                    .fill(AppTheme.accentRed)
                                    .frame(width: 42, height: 42)
                            }
                        }
                    }

                    Text("録音")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, 16)
            }

            // 保存フィードバック
            if showSavedFeedback {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.accentGreen)
                    Text("記録しました")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(32)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            audioManager.startMonitoring()
        }
        .onDisappear {
            audioManager.stopMonitoring()
        }
        .onChange(of: audioManager.isRecording) { _, recording in
            if recording {
                // 録音開始：ピーク値リセット、点滅開始
                peakDecibel = audioManager.currentDecibel
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isBlinking = true
                }
            } else {
                // 録音停止：点滅停止、5秒以上なら自動保存
                withAnimation(.default) {
                    isBlinking = false
                }
                autoSaveIfNeeded()
            }
        }
        .onChange(of: audioManager.currentDecibel) { _, newValue in
            // 録音中のピークdBを更新
            if audioManager.isRecording, newValue > peakDecibel {
                peakDecibel = newValue
            }
        }
    }

    // MARK: - ヘルパー

    /// 秒数を「00:05」形式にフォーマットする
    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - アクション

    /// 録音の開始/停止を切り替える
    private func toggleRecording() {
        if audioManager.isRecording {
            audioManager.stopRecording()
        } else {
            peakDecibel = audioManager.currentDecibel
            currentRecordingURL = audioManager.startRecording()
        }
    }

    /// 5秒以上の録音を自動保存する
    private func autoSaveIfNeeded() {
        guard let url = currentRecordingURL else { return }

        // 5秒未満は誤タップとみなして録音ファイルを削除
        guard audioManager.lastRecordingDuration >= 5 else {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let filePath = documentsPath.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: filePath)
            currentRecordingURL = nil
            return
        }

        let record = NoiseRecord(
            decibelLevel: peakDecibel,
            memo: "",
            audioFilePath: url.lastPathComponent
        )
        modelContext.insert(record)
        currentRecordingURL = nil

        // フィードバック表示
        withAnimation(.spring(response: 0.3)) {
            showSavedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                showSavedFeedback = false
            }
        }
    }
}
