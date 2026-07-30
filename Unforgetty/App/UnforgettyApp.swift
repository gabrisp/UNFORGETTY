//
//  UnforgettyApp.swift
//  Unforgetty
//
//  Created by Gabrisp on 29/07/2026.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct UnforgettyApp: App {
    @StateObject private var store = ActivityStore()
    @StateObject private var flow = AppFlowViewModel()

    var body: some Scene {
        WindowGroup {
            AppLaunchView()
                .environmentObject(store)
                .environmentObject(flow)
                .task { await flow.bootstrap(store: store) }
                #if canImport(UIKit)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    store.syncFromSharedStore()
                }
                #endif
        }
    }
}
