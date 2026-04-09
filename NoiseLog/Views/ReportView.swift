import SwiftUI
import SwiftData

/// レポート画面：月次の騒音記録統計を表示
struct ReportView: View {
    @Query(sort: \NoiseRecord.timestamp, order: .reverse) private var allRecords: [NoiseRecord]

    /// 表示中の年月
    @State private var selectedDate: Date = .now

    /// PDF共有シート表示フラグ
    @State private var showShareSheet: Bool = false

    /// 共有用PDFデータ
    @State private var pdfData: Data?

    private var calendar: Calendar { Calendar.current }

    /// 選択月の記録をフィルタリング
    private var monthlyRecords: [NoiseRecord] {
        allRecords.filter { record in
            calendar.isDate(record.timestamp, equalTo: selectedDate, toGranularity: .month)
        }
    }

    /// 記録件数
    private var recordCount: Int {
        DemoMode.isEnabled ? 28 : monthlyRecords.count
    }

    /// 平均dB値
    private var averageDecibel: Double {
        if DemoMode.isEnabled { return 67 }
        guard !monthlyRecords.isEmpty else { return 0 }
        return monthlyRecords.map(\.decibelLevel).reduce(0, +) / Double(monthlyRecords.count)
    }

    /// 最大dB値
    private var maxDecibel: Double {
        DemoMode.isEnabled ? 78 : (monthlyRecords.map(\.decibelLevel).max() ?? 0)
    }

    /// 時間帯別の平均dB値（0〜23時）
    private var hourlyAverages: [HourlyData] {
        if DemoMode.isEnabled {
            return Self.demoHourlyData
        }
        var grouped: [Int: [Double]] = [:]
        for record in monthlyRecords {
            let hour = calendar.component(.hour, from: record.timestamp)
            grouped[hour, default: []].append(record.decibelLevel)
        }
        return (0..<24).map { hour in
            let values = grouped[hour] ?? []
            let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
            return HourlyData(hour: hour, averageDecibel: avg, count: values.count)
        }
    }

    /// デモ用の時間帯別データ（22時〜2時に集中）
    private static let demoHourlyData: [HourlyData] = (0..<24).map { hour in
        let db: Double
        switch hour {
        case 22: db = 68
        case 23: db = 74
        case 0:  db = 71
        case 1:  db = 65
        case 2:  db = 58
        case 21: db = 52
        case 3:  db = 45
        case 7:  db = 38
        case 8:  db = 35
        case 12: db = 42
        case 18: db = 40
        case 19: db = 44
        case 20: db = 48
        default: db = 0
        }
        return HourlyData(hour: hour, averageDecibel: db, count: db > 0 ? Int.random(in: 1...5) : 0)
    }

    /// 表示用の年月文字列
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.darkNavy
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 月切り替えヘッダー
                        monthSelector

                        if !DemoMode.isEnabled && monthlyRecords.isEmpty {
                            emptyState
                        } else {
                            // サマリーカード
                            summaryCards

                            // 時間帯別グラフ
                            hourlyChart

                            // PDF出力ボタン
                            pdfExportButton
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("レポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showShareSheet) {
                if let data = pdfData {
                    ShareSheet(items: [data])
                }
            }
        }
    }

    // MARK: - 月切り替え

    /// 前月・翌月の切り替えUI
    private var monthSelector: some View {
        HStack {
            Button {
                selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(AppTheme.accentYellow)
            }

            Spacer()

            Text(monthTitle)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Spacer()

            Button {
                selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(AppTheme.accentYellow)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - 空の状態

    /// 記録がない月のプレースホルダー
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("この月の記録がありません")
                .font(.headline)
                .foregroundColor(.gray)
            Spacer()
        }
    }

    // MARK: - サマリーカード

    /// 記録件数・平均dB・最大dBのカード表示
    private var summaryCards: some View {
        HStack(spacing: 12) {
            StatCard(title: "記録件数", value: "\(recordCount)", unit: "件", color: AppTheme.accentYellow)
            StatCard(title: "平均", value: String(format: "%.0f", averageDecibel), unit: "dB", color: AppTheme.colorForDecibel(averageDecibel))
            StatCard(title: "最大", value: String(format: "%.0f", maxDecibel), unit: "dB", color: AppTheme.colorForDecibel(maxDecibel))
        }
    }

    // MARK: - 時間帯別グラフ

    /// 時間帯別の棒グラフ
    private var hourlyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("時間帯別の騒音レベル")
                .font(.headline)
                .foregroundColor(.white)

            // 棒グラフ
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(hourlyAverages) { data in
                    VStack(spacing: 4) {
                        // 棒
                        RoundedRectangle(cornerRadius: 2)
                            .fill(data.averageDecibel > 0 ? AppTheme.colorForDecibel(data.averageDecibel) : Color.gray.opacity(0.2))
                            .frame(height: barHeight(for: data.averageDecibel))

                        // 時間ラベル（6時間ごとに表示）
                        if data.hour % 6 == 0 {
                            Text("\(data.hour)")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        } else {
                            Text("")
                                .font(.system(size: 10))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 160)

            // 凡例
            HStack(spacing: 16) {
                legendItem(color: AppTheme.accentGreen, label: "〜40dB 静か")
                legendItem(color: AppTheme.accentYellow, label: "40〜60dB 普通")
                legendItem(color: AppTheme.accentRed, label: "60dB〜 うるさい")
            }
            .font(.caption2)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    /// 棒グラフの高さを計算（最大120pt）
    private func barHeight(for db: Double) -> CGFloat {
        guard db > 0 else { return 4 }
        return CGFloat(min(db / 100.0 * 120, 120))
    }

    /// 凡例アイテム
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.gray)
        }
    }

    // MARK: - PDF出力

    /// PDF出力ボタン
    private var pdfExportButton: some View {
        Button {
            pdfData = generatePDF()
            showShareSheet = true
        } label: {
            HStack {
                Image(systemName: "doc.richtext")
                Text("PDFレポートを出力")
                    .fontWeight(.bold)
            }
            .font(.body)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.accentYellow)
            .foregroundColor(.black)
            .cornerRadius(12)
        }
    }

    /// PDFデータを生成する
    private func generatePDF() -> Data {
        let pageWidth: CGFloat = 595.0  // A4幅
        let pageHeight: CGFloat = 842.0 // A4高さ
        let margin: CGFloat = 40.0
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin

            // タイトル
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            let title = "騒音ログ 月次レポート"
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 40

            // 対象月
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.darkGray
            ]
            monthTitle.draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
            y += 30

            // 区切り線
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: margin, y: y))
            linePath.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            UIColor.gray.setStroke()
            linePath.stroke()
            y += 20

            // サマリー
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            let summaryLines = [
                "記録件数：\(recordCount) 件",
                "平均騒音レベル：\(String(format: "%.1f", averageDecibel)) dB",
                "最大騒音レベル：\(String(format: "%.1f", maxDecibel)) dB"
            ]
            for line in summaryLines {
                line.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
                y += 24
            }
            y += 16

            // 記録一覧テーブルヘッダー
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            let headers = ["日時", "dB値", "レベル", "メモ"]
            let colWidths: [CGFloat] = [contentWidth * 0.30, contentWidth * 0.15, contentWidth * 0.15, contentWidth * 0.40]
            var x: CGFloat = margin
            for (i, header) in headers.enumerated() {
                header.draw(at: CGPoint(x: x, y: y), withAttributes: headerAttrs)
                x += colWidths[i]
            }
            y += 20

            // 区切り線
            let headerLine = UIBezierPath()
            headerLine.move(to: CGPoint(x: margin, y: y))
            headerLine.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            UIColor.lightGray.setStroke()
            headerLine.stroke()
            y += 8

            // 記録行
            let cellAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.black
            ]
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "ja_JP")
            dateFormatter.dateFormat = "M/d HH:mm"

            for record in monthlyRecords {
                // ページ溢れ処理
                if y > pageHeight - margin - 30 {
                    context.beginPage()
                    y = margin
                }

                x = margin
                let cells = [
                    dateFormatter.string(from: record.timestamp),
                    String(format: "%.0f dB", record.decibelLevel),
                    AppTheme.labelForDecibel(record.decibelLevel),
                    record.memo.isEmpty ? "-" : record.memo
                ]
                for (i, cell) in cells.enumerated() {
                    let rect = CGRect(x: x, y: y, width: colWidths[i] - 4, height: 18)
                    cell.draw(in: rect, withAttributes: cellAttrs)
                    x += colWidths[i]
                }
                y += 20
            }
        }
    }
}

// MARK: - サブビュー

/// 統計サマリーカード
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(unit)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }
}

/// 時間帯別データ
struct HourlyData: Identifiable {
    let hour: Int
    let averageDecibel: Double
    let count: Int
    var id: Int { hour }
}

/// 共有シート（UIActivityViewController）
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
