import StoreKit

@MainActor
final class ProEntitlementService: ObservableObject {
    @Published private(set) var status: ProEntitlementStatus = .unknown
    @Published private(set) var product: Product?

    let productID: String
    private var updatesTask: Task<Void, Never>?

    init(productID: String = AppConfiguration.proProductID) {
        self.productID = productID
    }

    deinit {
        updatesTask?.cancel()
    }

    var displayPrice: String? {
        product?.displayPrice
    }

    func start() async {
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
