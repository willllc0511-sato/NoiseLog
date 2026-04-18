import SwiftUI

/// 購入シート — 設定画面やレポート画面から表示する購入画面
struct SubscriptionSheetView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.darkNavy
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // ヘッダー
                        VStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.accentYellow)
                            Text("すべての機能を使う")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)

                        // 機能一覧
                        VStack(spacing: 0) {
                            featureRow(icon: "mic.fill", title: "録音", description: "騒音を録音して証拠として保存")
                            Divider().overlay(Color.gray.opacity(0.3))
                            featureRow(icon: "list.bullet", title: "記録保存", description: "騒音記録を無制限に保存")
                            Divider().overlay(Color.gray.opacity(0.3))
                            featureRow(icon: "doc.richtext", title: "PDF出力", description: "月次レポートをPDFで出力・共有")
                            Divider().overlay(Color.gray.opacity(0.3))
                            featureRow(icon: "chart.bar.fill", title: "レポート", description: "騒音データをグラフで可視化")
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppTheme.cardBackground)
                        )

                        // 価格
                        Text(priceText)
                            .font(.title.bold())
                            .foregroundColor(.white)

                        // 購入ボタン or ローディング or タイムアウト
                        purchaseArea

                        VStack(spacing: 4) {
                            Text("サブスクリプションはいつでもキャンセルできます。")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            HStack(spacing: 12) {
                                Link("利用規約", destination: URL(string: "https://willllc0511-sato.github.io/NoiseLog/terms.html")!)
                                Link("プライバシーポリシー", destination: URL(string: "https://willllc0511-sato.github.io/NoiseLog/privacy-policy.html")!)
                            }
                            .font(.caption)
                            .foregroundColor(AppTheme.accentYellow.opacity(0.8))
                        }

                        // 復元
                        Button {
                            Task {
                                _ = await subscriptionManager.restoreWithResult()
                                if subscriptionManager.isSubscribed {
                                    dismiss()
                                }
                            }
                        } label: {
                            Text("購入を復元")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.accentYellow)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            Task { await subscriptionManager.loadProduct() }
        }
    }

    // MARK: - 購入エリア（ボタン / ローディング / タイムアウト）

    @ViewBuilder
    private var purchaseArea: some View {
        if subscriptionManager.isLoadingProduct {
            // 読み込み中：ボタンの位置にローディング表示
            HStack {
                Spacer()
                ProgressView()
                    .tint(.white)
                Text("読み込み中...")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.accentYellow.opacity(0.4))
            )
        } else if subscriptionManager.product == nil && subscriptionManager.loadProductTimedOut {
            // タイムアウト：エラーメッセージ + 再読み込みボタン
            VStack(spacing: 12) {
                Button {
                    Task {
                        await subscriptionManager.loadProduct()
                        if subscriptionManager.product != nil {
                            await subscriptionManager.purchase()
                            if subscriptionManager.isSubscribed {
                                dismiss()
                            }
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("\(priceText)で購入")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppTheme.accentYellow.opacity(0.9))
                )

                Text("通信環境をご確認の上、時間をおいて再度お試しください")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                Button {
                    Task { await subscriptionManager.loadProduct() }
                } label: {
                    Text("再読み込み")
                        .font(.caption)
                        .foregroundColor(AppTheme.accentYellow)
                }
            }
        } else {
            // 購入ボタン
            Button {
                Task {
                    if subscriptionManager.product == nil {
                        await subscriptionManager.loadProduct()
                    }
                    if subscriptionManager.product != nil {
                        await subscriptionManager.purchase()
                        if subscriptionManager.isSubscribed {
                            dismiss()
                        }
                    }
                }
            } label: {
                HStack {
                    Spacer()
                    if subscriptionManager.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("\(priceText)で購入")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.accentYellow.opacity(0.9))
            )
            .disabled(subscriptionManager.isPurchasing)
        }
    }

    /// 価格テキスト
    private var priceText: String {
        if let product = subscriptionManager.product {
            return "\(product.displayPrice) / 月（税込）"
        }
        return "月額200円（税込）"
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.accentYellow)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }
}
