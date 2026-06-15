//
//  quiz_appApp.swift
//  quiz_app
//
//  Created by Leonardo Soligo on 9/1/25.
//
import SwiftUI
import SwiftData

@main
struct quiz_appApp: App {
    @StateObject private var appStore = AppStore()

    var body: some Scene {
        WindowGroup {
            MainAppView(app: appStore)
                .onAppear {
                    // Carica l'ultima materia utilizzata all'avvio
                    appStore.refreshSubjects()
                }
        }
        .modelContainer(PersistenceController.shared)
    }
}
