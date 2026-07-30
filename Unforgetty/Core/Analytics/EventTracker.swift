import Foundation

/// Privacy boundary: event names only. Never pass titles, text, checklist values, tags or styles.
enum EventTracker {
    static func track(_ name: String) {
        #if canImport(Aptabase)
        // Aptabase.shared.trackEvent(name: name)
        #endif
        NSLog("Unforgetty event: %@", name)
    }
}
