import StoreKit

@MainActor
final class ProEntitlementService: ObservableObject {
    @Published private(set) var status: ProEntitlementStatus = .unknown
    @Published private(set) var product: Product?
    @Published private(set) var developerProEnabled: Bool

    let productID: String
    private let reviewStatus: ProEntitlementStatus?
    private var updatesTask: Task<Void, Never>?
    private static let developerProKey = "pixel-forge.developer-pro-enabled"

    init(
        productID: String = AppConfiguration.proProductID,
        reviewStatus: ProEntitlementStatus? = nil
    ) {
        self.productID = productID
        self.reviewStatus = reviewStatus
        let developerProEnabled = AppConfiguration.isDeveloperBuild
            && UserDefaults.standard.bool(forKey: Self.developerProKey)
        self.developerProEnabled = developerProEnabled
        status = reviewStatus
            ?? (AppConfiguration.isDeveloperBuild
                ? (developerProEnabled ? .purchased : .notPurchased)
                : .unknown)
    }

    deinit {
        updatesTask?.cancel()
    }

    var displayPrice: String? {
        product?.displayPrice
    }

    func start() async {
        if let reviewStatus {
            status = reviewStatus
            return
        }
        if AppConfiguration.isDeveloperBuild {
            status = developerProEnabled ? .purchased : .notPurchased
            return
        }
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.consume(result)
            }
        }
        await loadProduct()
        await refresh()
    }

    func purchase() async {
        guard let product else {
            status = .failed("Product is unavailable.")
            return
        }
        status = .loading
        do {
            switch try await product.purchase() {
            case let .success(result):
                await consume(result)
            case .pending:
                status = .pending
            case .userCancelled:
                await refresh()
            @unknown default:
                await refresh()
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func restore() async {
        status = .loading
        do {
            try await AppStore.sync()
            await refresh()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func setDeveloperProEnabled(_ isEnabled: Bool) {
        guard AppConfiguration.isDeveloperBuild else { return }
        developerProEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.developerProKey)
        status = isEnabled ? .purchased : .notPurchased
    }

    func refresh() async {
        var sawRevokedProduct = false
        for await result in Transaction.currentEntitlements {
            switch result {
            case let .verified(transaction) where transaction.productID == productID:
                if transaction.revocationDate == nil {
                    status = .purchased
                    return
                }
                sawRevokedProduct = true
            case .unverified:
                continue
            default:
                continue
            }
        }
        status = sawRevokedProduct ? .revoked : .notPurchased
    }

    private func loadProduct() async {
        do {
            product = try await Product.products(for: [productID]).first
        } catch {
            product = nil
            status = .failed(error.localizedDescription)
        }
    }

    private func consume(_ result: VerificationResult<Transaction>) async {
        switch result {
        case let .verified(transaction) where transaction.productID == productID:
            if transaction.revocationDate == nil {
                status = .purchased
            } else {
                status = .revoked
            }
            await transaction.finish()
        case .verified:
            break
        case .unverified:
            await refresh()
        }
    }
}
