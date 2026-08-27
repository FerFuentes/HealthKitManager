//
//  WalkingBackgroundToggle.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation
import HealthKit

/// Works out what a background-delivery toggle actually left running when it only partly
/// succeeded.
///
/// Every type is attempted and the failures are collected rather than aborting the set
/// half-toggled, so "it threw" does not mean "nothing changed". The observer has to watch
/// whatever ended up live: iOS stops delivering a type after three unacknowledged wakes, so a
/// type left enabled with no descriptor covering it goes quietly dead.
enum WalkingBackgroundToggle {

    /// The walking types delivery is live for after a toggle that partly failed.
    ///
    /// A type that failed to enable is not live. A type that failed to *disable* still is —
    /// the asymmetry is the whole point, and reading it the other way is what leaves an
    /// enabled type unwatched.
    ///
    /// - Parameters:
    ///   - enabled: Whether the toggle was trying to enable or to disable.
    ///   - requested: The types the toggle was asked to change.
    ///   - failed: The identifiers of the types that kept their previous state.
    /// - Returns: The types delivery is live for, or `nil` when none are.
    static func liveTypes(
        after enabled: Bool,
        requested: Set<HKQuantityType>,
        failed: Set<String>
    ) -> Set<HKQuantityType>? {
        let live = enabled
            ? requested.filter { !failed.contains($0.identifier) }
            : requested.filter { failed.contains($0.identifier) }
        return live.isEmpty ? nil : live
    }
}
