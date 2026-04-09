import SwiftUI
import SwiftData

/// 日付フィルターの種類
enum DateFilter: String, CaseIterable {
    case all = "すべて"
    case today = "今日"
    case thisWeek = "今週"
    case thisMonth = "今月"
}

/// デモ用の表示データ（SwiftDataモデルではない軽量構造体）
struct DemoRecord: Identifiable {
    let id = UUID()
    let timestamp: Date
    let decibelLevel: Double
    let memo: String
    let hasAudio: Bool

    /// デモ用の固定データ
    static let samples: [DemoRecord] = {
        let cal = Calendar.current
        var c = DateComponents()
        c.year = 2026; c.month = 4

        func date(day: Int, hour: Int, minute: Int) -> Date {
            c.day = day; c.hour = hour; c.minute = minute; c.second = 0
            return cal.date(from: c)!
        }

        return [
            DemoRecord(timestamp: date(day: 9, hour: 23, minute: 15), decibelLevel: 72, memo: "上階の足音", hasAudio: true),
            DemoRecord(timestamp: date(day: 9, hour: 1, minute: 30), decibelLevel: 65, memo: "ドアの開閉音", hasAudio: true),
            DemoRecord(timestamp: date(day: 8, hour: 23, minute: 50), decibelLevel: 71, memo: "物を落とす音", hasAudio: false),
            DemoRecord(timestamp: date(day: 8, hour: 22, minute: 45), decibelLevel: 68, memo: "話し声", hasAudio: true),
            DemoRecord(timestamp: date(day: 7, hour: 0, minute: 15), decibelLevel: 63, memo: "足音", hasAudio: false),
        ]
    }()
}

/// 記録一覧画面：保存された騒音記録を時系列で表示
struct RecordListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NoiseRecord.timestamp, order: .reverse) private var allRecords: [NoiseRecord]

    /// 選択中の日付フィルター
    @State private var selectedFilter: DateFilter = .all

    /// フィルター適用後の記録一覧
    private var filteredRecords: [NoiseRecord] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedFilter {
        case .all:
            return allRecords
        case .today:
            return allRecords.filter { calendar.isDateInToday($0.timestamp) }
        case .thisWeek:
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
                return allRecords
            }
            return allRecords.filter { $0.timestamp >= weekStart }
        case .thisMonth:
            guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else {
                return allRecords
            }
            return allRecords.filter { $0.timestamp >= monthStart }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.darkNavy
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 日付フィルター
                    filterPicker

                    if DemoMode.isEnabled {
                        demoRecordList
                    } else if filteredRecords.isEmpty {
                        emptyState
                    } else {
                        recordList
                    }
                }
            }
            .navigationTitle("記録一覧")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - フィルターピッカー

    /// 日付フィルターのセグメントコントロール
    private var filterPicker: some View {
        Picker("期間", selection: $selectedFilter) {
            ForEach(DateFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 空の状態表示

    /// 記録が無い場合のプレースホルダー
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "waveform.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("記録がありません")
                .font(.headline)
                .foregroundColor(.gray)
            Text("ホーム画面で騒音を記録しましょう")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.7))
            Spacer()
        }
    }

    // MARK: - デモ用リスト

    /// デモデータの一覧リスト
    private var demoRecordList: some View {
        List {
            ForEach(DemoRecord.samples) { record in
                DemoRowView(record: record)
                    .listRowBackground(AppTheme.cardBackground)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - 記録リスト

    /// 記録の一覧リスト
    private var recordList: some View {
        List {
            ForEach(filteredRecords) { record in
                NavigationLink(destination: RecordDetailView(record: record)) {
                    RecordRowView(record: record)
                }
                .listRowBackground(AppTheme.cardBackground)
            }
            .onDelete(perform: deleteRecords)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// 記録を削除する
    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredRecords[index])
        }
    }
}

// MARK: - デモ行ビュー

/// デモデータ用の行表示
struct DemoRowView: View {
    let record: DemoRecord

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d (EEE) HH:mm"
        return f
    }()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.colorForDecibel(record.decibelLevel).opacity(0.2))
                    .frame(width: 52, height: 52)

                Text(String(format: "%.0f", record.decibelLevel))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.colorForDecibel(record.decibelLevel))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(Self.dateFormatter.string(from: record.timestamp))
                    .font(.subheadline)
                    .foregroundColor(.white)

                Text(record.memo)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            if record.hasAudio {
                Image(systemName: "mic.fill")
                    .foregroundColor(AppTheme.accentYellow)
                    .font(.caption)
            }

            Text("dB")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 記録行ビュー

/// 一覧リストの各行表示
struct RecordRowView: View {
    let record: NoiseRecord

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d (EEE) HH:mm"
        return f
    }()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.colorForDecibel(record.decibelLevel).opacity(0.2))
                    .frame(width: 52, height: 52)

                Text(String(format: "%.0f", record.decibelLevel))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.colorForDecibel(record.decibelLevel))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(Self.dateFormatter.string(from: record.timestamp))
                    .font(.subheadline)
                    .foregroundColor(.white)

                if !record.memo.isEmpty {
                    Text(record.memo)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }

            Spacer()

            if record.audioFilePath != nil {
                Image(systemName: "mic.fill")
                    .foregroundColor(AppTheme.accentYellow)
                    .font(.caption)
            }

            Text("dB")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}
