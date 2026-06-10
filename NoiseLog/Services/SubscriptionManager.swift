import StoreKit

/// 復元結果
enum RestoreResult {
    case restored
    case nothingToRestore
    case failed
}

/// StoreKit 2 によるサブスクリプション管理
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    /// 月額サブスクリプションのプロダクトID
    static let monthlyProductID = "com.willllc.NoiseLog.monthly.v2"

    /// プロダクト情報
    @Published private(set) var product: Product?

    /// サブスクリプションが有効か
    @Published private(set) var isSubscribed: Bool = false

    /// 現在のサブスクリプション状態
    @Published private(set) var subscriptionStatus: Product.SubscriptionInfo.Status?

    /// 購入処理中フラグ
    @Published var isPurchasing: Bool = false

    /// 購入時にユーザーへ伝えるメッセージ（エラー・承認待ち等）。nilなら非表示
    @Published var purchaseMessage: String?

    /// プロダクト読み込み中フラグ
    @Published private(set) var isLoadingProduct: Bool = false

    /// 商品取得がタイムアウトしたフラグ
    @Published private(set) var loadProductTimedOut: Bool = false

    /// トランザクション監視タスク
    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProduct()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - プロダクト読み込み（10秒タイムアウト）

    /// App Store からプロダクト情報を取得（最大3回リトライ、全体10秒タイムアウト）
    func loadProduct() async {
        guard !isLoadingProduct else { return }
        isLoadingProduct = true
        loadProductTimedOut = false

        let result: Product? = await withThrowingTaskGroup(of: Product?.self) { group -> Product? in
            // リトライタスク
            group.addTask {
                for attempt in 0..<3 {
                    do {
                        let products = try await Product.products(for: [Self.monthlyProductID])
                        if let first = products.first {
                            return first
                        }
                    } catch {
                        // リトライ
                    }
                    if attempt < 2 {
                        try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                    }
                }
                // リトライ全失敗 → タイムアウトを待たず即終了させる
                throw CancellationError()
            }

            // タイムアウトタスク（10秒）
            group.addTask {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                return nil
            }

            // 最初に成功した結果を採用
            do {
                while let value = try await group.next() {
                    if let v = value {
                        group.cancelAll()
                        return v
                    }
                }
            } catch {
                // リトライタスクがCancellationErrorをthrowした場合
                group.cancelAll()
            }
            return nil
        }

        if let result {
            product = result
        } else {
            loadProductTimedOut = true
        }
        isLoadingProduct = false
    }

    // MARK: - 購入

    /// サブスクリプションを購入する
    func purchase() async {
        guard let product else { return }

        isPurchasing = true
        purchaseMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
                if !isSubscribed {
                    // 課金は成立したが反映できない異常時。問い合わせ・復元へ誘導
                    purchaseMessage = "購入は完了しましたが、反映できませんでした。「購入を復元」をお試しの上、解決しない場合はお問い合わせください。"
                }

            case .userCancelled:
                break

            case .pending:
                // Ask to Buy（保護者承認）やSCA承認待ち。承認後にTransaction.updatesで自動反映される
                purchaseMessage = "承認待ちです。承認が完了すると自動的にご利用いただけます。"

            @unknown default:
                break
            }
        } catch is CancellationError {
            // 画面を閉じた等。メッセージ不要
        } catch SubscriptionError.verificationFailed {
            // 課金は成立している可能性が高いが検証できなかった。復元・問い合わせへ誘導
            purchaseMessage = "購入の確認ができませんでした。課金が成立している場合は「購入を復元」をお試しの上、解決しない場合はお問い合わせください。"
        } catch {
            purchaseMessage = "購入を完了できませんでした。通信環境をご確認の上、時間をおいて再度お試しください。"
        }

        isPurchasing = false
    }

    // MARK: - 復元

    /// 購入を復元する（結果を返す）
    func restoreWithResult() async -> RestoreResult {
        let wasSub = isSubscribed
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            if isSubscribed && !wasSub {
                return .restored
            }
            return isSubscribed ? .restored : .nothingToRestore
        } catch {
            return .failed
        }
    }

    // MARK: - ステータス更新

    /// サブスクリプションの状態を確認・更新する
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if transaction.productID == Self.monthlyProductID,
               transaction.revocationDate == nil {
                hasActiveSubscription = true
            }
        }

        isSubscribed = hasActiveSubscription
    }

    // MARK: - トランザクション監視

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.updateSubscriptionStatus()
            }
        }
    }

    // MARK: - 検証

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let value):
            return value
        }
    }
}

/// サブスクリプション関連エラー
enum SubscriptionError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Verification failed"
        }
    }
}
