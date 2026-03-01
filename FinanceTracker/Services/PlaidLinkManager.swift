import Foundation
import LinkKit
import UIKit

@MainActor
class PlaidLinkManager: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?

    private var handler: Handler?
    var onSuccess: (() -> Void)?

    // MARK: - New Connection

    func openLink() {
        isLoading = true
        error = nil

        Task {
            do {
                let response: LinkTokenResponse = try await APIClient.shared.request(
                    "/api/plaid/create-link-token",
                    method: "POST"
                )
                presentLink(token: response.link_token)
            } catch {
                self.error = "Failed to initialize Plaid"
                isLoading = false
            }
        }
    }

    // MARK: - Update Mode (Re-auth)

    func openUpdateLink(itemId: String) {
        isLoading = true
        error = nil

        Task {
            do {
                let response: LinkTokenResponse = try await APIClient.shared.request(
                    "/api/plaid/create-link-token",
                    method: "POST",
                    body: ["item_id": itemId]
                )
                presentLink(token: response.link_token)
            } catch {
                self.error = "Failed to initialize re-authentication"
                isLoading = false
            }
        }
    }

    // MARK: - OAuth Resume (handled automatically by LinkKit v5+)

    // MARK: - Private

    private func presentLink(token: String) {
        var config = LinkTokenConfiguration(token: token) { [weak self] result in
            self?.handleSuccess(result: result)
        }
        config.onExit = { [weak self] exit in
            self?.isLoading = false
            if let linkError = exit.error {
                self?.error = linkError.localizedDescription
            }
        }

        let createResult = Plaid.create(config)
        switch createResult {
        case .success(let handler):
            self.handler = handler

            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = scene.windows.first?.rootViewController else {
                isLoading = false
                return
            }
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            handler.open(presentUsing: .viewController(topVC))

        case .failure(let error):
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    private func handleSuccess(result: LinkSuccess) {
        Task {
            do {
                let _: ExchangeTokenResponse = try await APIClient.shared.request(
                    "/api/plaid/exchange-token",
                    method: "POST",
                    body: [
                        "public_token": result.publicToken,
                        "institution_name": result.metadata.institution.name,
                    ]
                )
                onSuccess?()
            } catch {
                self.error = "Failed to connect bank"
            }
            isLoading = false
            handler = nil
        }
    }
}
