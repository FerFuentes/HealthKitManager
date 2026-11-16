//
//  StoreLock.swift
//  HealthKitManager
//

import Foundation
#if os(iOS)
import UIKit
#endif

/// Whether HealthKit's store is encrypted behind the device lock right now.
///
/// While the iPhone is locked every read fails with `errorDatabaseInaccessible`, and the
/// background routes — a processing task, a background delivery — are exactly the ones that
/// run then. Asking first spares the queries; a read answers it with the refusal HealthKit
/// would have given, so every caller already handles it. Only iOS can ask; on watchOS a
/// read still learns it from HealthKit's own error.
enum StoreLock {

    @Sendable static func isLocked() async -> Bool {
        #if os(iOS)
        await MainActor.run { !UIApplication.shared.isProtectedDataAvailable }
        #else
        false
        #endif
    }
}
