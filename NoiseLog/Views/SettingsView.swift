import SwiftUI
import StoreKit

/// 設定画面：サブスクリプション、サポート、その他
struct SettingsView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    /// 購入シート表示フラグ
    @State private var showSubscriptionSheet: Bool = false

    /// 復元アラート
    @State private var showRestoreAlert: Bool = false
    @State private var restoreAlertMessage: String = ""

    /// アプリバージョン
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.darkNavy
                    .ignoresSafeArea()

                List {
                    subscriptionSection
                    supportSection
                    otherSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                if subscriptionManager.product == nil {
                    Task { await subscriptionManager.loadProduct() }
                }
            }
            .sheet(isPresented: $showSubscriptionSheet) {
                SubscriptionSheetView()
                    .environmentObject(subscriptionManager)
            }
            .alert("購入の復元", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreAlertMessage)
            }
        }
    }

    // MARK: - サブスクリプション

    private var subscriptionSection: some View {
        Section {
            if subscriptionManager.isSubscribed {
                // 購入済み：ご利用中表示
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.accentGreen)
                        Text("ご利用中")
                            .foregroundColor(AppTheme.accentGreen)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                .listRowBackground(AppTheme.cardBackground)
            } else {
                // 未購入：購入ボタン
                Button {
                    showSubscriptionSheet = true
                } label: {
                    HStack {
                        Spacer()
                        Text(settingsPriceButtonText)
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(AppTheme.accentYellow.opacity(0.9))
            }
        } header: {
            Text("サブスクリプション")
                .foregroundColor(.gray)
        } footer: {
            if !subscriptionManager.isSubscribed {
                Text("ご利用プランに加入すると、録音・記録保存の制限が解除されます。")
                    .foregroundColor(.gray)
            }
        }
    }

    private var settingsPriceButtonText: String {
        if let product = subscriptionManager.product {
            return "\(product.displayPrice)/月 で購入"
        }
        return "月額200円 で購入"
    }

    // MARK: - サポート

    private var supportSection: some View {
        Section {
            Link(destination: URL(string: "https://willllc0511-sato.github.io/NoiseLog/privacy-policy.html")!) {
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(AppTheme.accentYellow)
                    Text("プライバシーポリシー")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .listRowBackground(AppTheme.cardBackground)

            Link(destination: URL(string: "https://willllc0511-sato.github.io/NoiseLog/terms.html")!) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.plaintext.fill")
                        .foregroundColor(AppTheme.accentYellow)
                    Text("利用規約")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .listRowBackground(AppTheme.cardBackground)

            Link(destination: URL(string: "https://willllc0511-sato.github.io/NoiseLog/tokushoho.html")!) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(AppTheme.accentYellow)
                    Text("特定商取引法に基づく表示")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .listRowBackground(AppTheme.cardBackground)

            Link(destination: URL(string: "mailto:support@will-llc.co.jp?subject=騒音ログ お問い合わせ")!) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(AppTheme.accentYellow)
                    Text("お問い合わせ")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .listRowBackground(AppTheme.cardBackground)
        } header: {
            Text("サポート")
                .foregroundColor(.gray)
        }
    }

    // MARK: - その他

    private var otherSection: some View {
        Section {
            // 購入を復元
            Button {
                Task {
                    let result = await subscriptionManager.restoreWithResult()
                    switch result {
                    case .restored:
                        restoreAlertMessage = "購入を復元しました"
                    case .nothingToRestore:
                        restoreAlertMessage = "復元する購入が見つかりませんでした"
                    case .failed:
                        restoreAlertMessage = "エラーが発生しました。しばらく経ってからお試しください"
                    }
                    showRestoreAlert = true
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.gray)
                    Text("購入を復元")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .listRowBackground(AppTheme.cardBackground)

            // バージョン
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.gray)
                    Text("バージョン")
                        .foregroundColor(.white)
                }
                Spacer()
                Text(appVersion)
                    .foregroundColor(.gray)
            }
            .listRowBackground(AppTheme.cardBackground)

            // コピーライト
            HStack {
                Spacer()
                Text("© 2026 Satoshi Taki")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
            .listRowBackground(AppTheme.cardBackground)
        } header: {
            Text("その他")
                .foregroundColor(.gray)
        }
    }
}
