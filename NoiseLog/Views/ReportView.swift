import SwiftUI
import SwiftData

/// レポート画面：月次の騒音記録統計を表示
struct ReportView: View {
    @Query(sort: \NoiseRecord.timestamp, order: .reverse) private var allRecords: [NoiseRecord]
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    /// 表示中の年月
    @State private var selectedDate: Date = .now

    /// 共有シート表示フラグ
    @State private var showShareSheet: Bool = false

    /// 共有アイテム（PDF + 音声ファイル）
    @State private var shareItems: [Any] = []

    /// 購入シート表示フラグ
    @State private var showSubscriptionSheet: Bool = false

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

    /// 最小dB値
    private var minDecibel: Double {
        DemoMode.isEnabled ? 32 : (monthlyRecords.map(\.decibelLevel).min() ?? 0)
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
            .sheet(isPresented: $showShareSheet, onDismiss: cleanupTempFiles) {
                ShareSheet(items: shareItems)
            }
            .sheet(isPresented: $showSubscriptionSheet) {
                SubscriptionSheetView()
                    .environmentObject(subscriptionManager)
            }
        }
    }

    // MARK: - 月切り替え

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

    private var summaryCards: some View {
        HStack(spacing: 12) {
            StatCard(title: "記録件数", value: "\(recordCount)", unit: "件", color: AppTheme.accentYellow)
            StatCard(title: "平均", value: String(format: "%.0f", averageDecibel), unit: "dB", color: AppTheme.colorForDecibel(averageDecibel))
            StatCard(title: "最大", value: String(format: "%.0f", maxDecibel), unit: "dB", color: AppTheme.colorForDecibel(maxDecibel))
        }
    }

    // MARK: - 時間帯別グラフ

    private var hourlyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("時間帯別の騒音レベル")
                .font(.headline)
                .foregroundColor(.white)

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(hourlyAverages) { data in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(data.averageDecibel > 0 ? AppTheme.colorForDecibel(data.averageDecibel) : Color.gray.opacity(0.2))
                            .frame(height: barHeight(for: data.averageDecibel))

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

    private func barHeight(for db: Double) -> CGFloat {
        guard db > 0 else { return 4 }
        return CGFloat(min(db / 100.0 * 120, 120))
    }

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

    private var pdfExportButton: some View {
        Button {
            if subscriptionManager.isSubscribed {
                shareItems = prepareShareItems()
                showShareSheet = true
            } else {
                showSubscriptionSheet = true
            }
        } label: {
            HStack {
                Image(systemName: "doc.richtext")
                Text("PDF+音声を出力")
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

    /// PDF + 音声ファイルの共有アイテムを準備
    private func prepareShareItems() -> [Any] {
        var items: [Any] = []

        // PDF生成
        let pdf = generatePDF()
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("NoiseLogExport", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let pdfURL = tmpDir.appendingPathComponent("騒音ログ_\(monthTitle).pdf")
        try? pdf.write(to: pdfURL)
        items.append(pdfURL)

        // 音声ファイル収集
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"

        for record in monthlyRecords {
            guard let audioPath = record.audioFilePath, !audioPath.isEmpty else { continue }
            let sourceURL = documentsDir.appendingPathComponent(audioPath)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else { continue }

            let dateStr = dateFormatter.string(from: record.timestamp)
            let dbStr = String(format: "%.0f", record.decibelLevel)
            let exportName = "\(dateStr)_\(dbStr)dB.m4a"
            let destURL = tmpDir.appendingPathComponent(exportName)

            try? FileManager.default.removeItem(at: destURL)
            try? FileManager.default.copyItem(at: sourceURL, to: destURL)
            items.append(destURL)
        }

        return items
    }

    /// 一時ファイルのクリーンアップ
    private func cleanupTempFiles() {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("NoiseLogExport", isDirectory: true)
        try? FileManager.default.removeItem(at: tmpDir)
        shareItems = []
    }

    /// PDFデータを生成する
    private func generatePDF() -> Data {
        let pageWidth: CGFloat = 595.0
        let pageHeight: CGFloat = 842.0
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
            "騒音ログ 月次レポート".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 40

            // 対象期間
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.darkGray
            ]
            "対象期間：\(monthTitle)".draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
            y += 30

            // 区切り線
            drawLine(at: y, from: margin, to: pageWidth - margin)
            y += 20

            // 統計情報
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            let summaryLines = [
                "記録件数：\(recordCount) 件",
                "平均騒音レベル：\(String(format: "%.1f", averageDecibel)) dB",
                "最大騒音レベル：\(String(format: "%.1f", maxDecibel)) dB",
                "最小騒音レベル：\(String(format: "%.1f", minDecibel)) dB"
            ]
            for line in summaryLines {
                line.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
                y += 24
            }
            y += 16

            // 時間帯別グラフ
            let sectionTitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            "時間帯別 平均騒音レベル".draw(at: CGPoint(x: margin, y: y), withAttributes: sectionTitleAttrs)
            y += 24

            let chartHeight: CGFloat = 80
            let barWidth = contentWidth / 24.0
            let maxDb = hourlyAverages.map(\.averageDecibel).max() ?? 1
            let chartBaseline = y + chartHeight

            for data in hourlyAverages {
                let barH = maxDb > 0 ? CGFloat(data.averageDecibel / maxDb) * chartHeight : 0
                let x = margin + CGFloat(data.hour) * barWidth
                let rect = CGRect(x: x + 1, y: chartBaseline - barH, width: barWidth - 2, height: max(barH, 1))

                let barColor: UIColor
                if data.averageDecibel >= 60 { barColor = UIColor(red: 0.93, green: 0.26, blue: 0.26, alpha: 1) }
                else if data.averageDecibel >= 40 { barColor = UIColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1) }
                else { barColor = UIColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1) }

                barColor.setFill()
                UIBezierPath(rect: rect).fill()
            }

            // 時間ラベル
            y = chartBaseline + 4
            let hourLabelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.gray
            ]
            for h in stride(from: 0, to: 24, by: 6) {
                let x = margin + CGFloat(h) * barWidth
                "\(h)".draw(at: CGPoint(x: x, y: y), withAttributes: hourLabelAttrs)
            }
            y += 20

            // 区切り線
            drawLine(at: y, from: margin, to: pageWidth - margin)
            y += 16

            // 記録一覧テーブルヘッダー
            "全記録一覧".draw(at: CGPoint(x: margin, y: y), withAttributes: sectionTitleAttrs)
            y += 24

            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11),
                .foregroundColor: UIColor.black
            ]
            let headers = ["日時", "dB値", "レベル", "メモ"]
            let colWidths: [CGFloat] = [contentWidth * 0.30, contentWidth * 0.15, contentWidth * 0.15, contentWidth * 0.40]
            var x: CGFloat = margin
            for (i, header) in headers.enumerated() {
                header.draw(at: CGPoint(x: x, y: y), withAttributes: headerAttrs)
                x += colWidths[i]
            }
            y += 18
            drawLine(at: y, from: margin, to: pageWidth - margin)
            y += 6

            // 記録行
            let cellAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.black
            ]
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "ja_JP")
            dateFormatter.dateFormat = "M/d HH:mm"

            let sortedRecords = monthlyRecords.sorted { $0.timestamp < $1.timestamp }
            for record in sortedRecords {
                if y > pageHeight - margin - 60 {
                    // フッター
                    drawFooter(context: context, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
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
                    let rect = CGRect(x: x, y: y, width: colWidths[i] - 4, height: 16)
                    cell.draw(in: rect, withAttributes: cellAttrs)
                    x += colWidths[i]
                }
                y += 18
            }

            y += 20

            // 免責注記
            if y > pageHeight - margin - 80 {
                drawFooter(context: context, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
                context.beginPage()
                y = margin
            }

            let disclaimerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.gray
            ]
            let disclaimer = "本アプリの測定値は参考値です。法的な騒音測定には専門の機器をご使用ください。"
            disclaimer.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 30), withAttributes: disclaimerAttrs)

            // 最終ページのフッター
            drawFooter(context: context, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
        }
    }

    /// 区切り線を描画
    private func drawLine(at y: CGFloat, from x1: CGFloat, to x2: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x1, y: y))
        path.addLine(to: CGPoint(x: x2, y: y))
        UIColor.lightGray.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    /// フッターを描画
    private func drawFooter(context: UIGraphicsPDFRendererContext, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat) {
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.gray
        ]
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let footer = "騒音ログ / 生成日時: \(dateFormatter.string(from: Date()))"
        footer.draw(at: CGPoint(x: margin, y: pageHeight - margin + 10), withAttributes: footerAttrs)
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
