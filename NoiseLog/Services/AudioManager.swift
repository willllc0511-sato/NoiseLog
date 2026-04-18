import AVFoundation
import Combine

/// マイクからリアルタイムでデシベル値を取得するマネージャー
final class AudioManager: ObservableObject {
    /// 表示用のデシベル値（スムージング済み・500ms更新）
    @Published var currentDecibel: Double = 0.0

    /// 測定中かどうか
    @Published var isMonitoring: Bool = false

    /// 録音中かどうか
    @Published var isRecording: Bool = false

    /// 録音経過秒数
    @Published var recordingElapsed: Int = 0

    /// 最後の録音の経過秒数（停止後も保持）
    @Published var lastRecordingDuration: Int = 0

    /// マイク権限の状態
    @Published var permissionGranted: Bool = false

    /// 内部の生デシベル値（高頻度更新）
    private var rawDecibel: Double = 0.0

    /// 録音中のピークdB値
    @Published var peakDecibel: Double = 0.0

    /// 表示更新用タイマー
    private var displayTimer: Timer?

    /// スムージング係数（0〜1、小さいほど滑らか）
    private let smoothingFactor: Double = 0.3

    private var audioEngine: AVAudioEngine?
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?

    /// 録音の最大秒数
    private let maxRecordingDuration: Int = 300

    init() {
        checkPermission()
    }

    // MARK: - マイク権限

    /// マイク使用権限を確認する
    func checkPermission() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            permissionGranted = true
        case .denied:
            permissionGranted = false
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                }
            }
        @unknown default:
            permissionGranted = false
        }
    }

    // MARK: - デシベル測定

    /// リアルタイム測定を開始する
    func startMonitoring() {
        guard permissionGranted else {
            checkPermission()
            return
        }

        // オーディオセッションを設定（フォーマット取得前に必要）
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: .defaultToSpeaker)
            try session.setActive(true)
        } catch {
            return
        }

        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // シミュレータ等でフォーマットが無効な場合はスキップ
        guard format.sampleRate > 0, format.channelCount > 0 else {
            isMonitoring = false
            return
        }

        // マイク入力のタップを設置してRMS値を計算
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)

            // RMS（二乗平均平方根）を計算
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += channelData[i] * channelData[i]
            }
            let rms = sqrt(sum / Float(frameLength))

            // RMS値をデシベルに変換（0dBを基準に補正）
            let db: Double
            if rms > 0 {
                // マイク入力をdBに変換し、環境音に近い値に補正
                let rawDb = 20 * log10(Double(rms))
                db = max(0, rawDb + 100) // 補正値：実機で要調整
            } else {
                db = 0
            }

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.rawDecibel = db
                if self.isRecording, db > self.peakDecibel {
                    self.peakDecibel = db
                }
            }
        }

        do {
            try audioEngine.start()
            self.audioEngine = audioEngine
            isMonitoring = true
            startDisplayTimer()
        } catch {
            inputNode.removeTap(onBus: 0)
        }
    }

    /// リアルタイム測定を停止する
    func stopMonitoring() {
        displayTimer?.invalidate()
        displayTimer = nil
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isMonitoring = false
        currentDecibel = 0
        rawDecibel = 0
    }

    /// 表示用タイマー（500ms間隔でスムージング済みの値を反映）
    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let smoothed = self.currentDecibel + self.smoothingFactor * (self.rawDecibel - self.currentDecibel)
            self.currentDecibel = smoothed
        }
    }

    // MARK: - 録音

    /// 録音ファイルの保存先URLを生成する
    private func generateRecordingURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Int(Date().timeIntervalSince1970)).m4a"
        return documentsPath.appendingPathComponent(fileName)
    }

    /// 録音を開始する（最大60秒で自動停止）
    func startRecording() -> URL? {
        guard permissionGranted else { return nil }

        let url = generateRecordingURL()

        // 録音設定（m4aフォーマット）
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordingElapsed = 0
            peakDecibel = rawDecibel

            // タイマーでカウントアップ、最大秒数で自動停止
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                self.recordingElapsed += 1
                if self.recordingElapsed >= self.maxRecordingDuration {
                    self.stopRecording()
                }
            }

            return url
        } catch {
            return nil
        }
    }

    /// 録音を停止する
    func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        lastRecordingDuration = recordingElapsed
        isRecording = false
        recordingElapsed = 0
    }

    deinit {
        displayTimer?.invalidate()
        stopMonitoring()
        stopRecording()
    }
}
