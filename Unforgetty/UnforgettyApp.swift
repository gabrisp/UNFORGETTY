//
//  UnforgettyApp.swift
//  Unforgetty
//
//  Created by Gabrisp on 29/07/2026.
//

import SwiftUI
import CoreData

@main
struct UnforgettyApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
