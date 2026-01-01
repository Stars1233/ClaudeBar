import Foundation
import Mockable

/// Listens for quota status changes (e.g., to alert users).
@Mockable
public protocol QuotaStatusListener: Sendable {
    /// Called when a provider's quota status changes.
    func onStatusChanged(providerId: String, oldStatus: QuotaStatus, newStatus: QuotaStatus) async
}
