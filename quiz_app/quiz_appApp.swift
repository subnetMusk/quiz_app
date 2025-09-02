//
//  quiz_appApp.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//
import SwiftUI

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
    }
}
