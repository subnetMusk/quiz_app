//
//  PersistenceController.swift
//  quiz_app
//
//  Container SwiftData condiviso. Usa l'App Group (per il widget) se l'entitlement è
//  configurato in Xcode; altrimenti ricade su uno store locale così l'app gira comunque.
//

import Foundation
import SwiftData

/// App Group condiviso con la Widget Extension (va creato in Xcode → Signing & Capabilities).
/// Costante non isolata così è accessibile anche dal `WidgetBridge`.
let appGroupIdentifier = "group.it.subnetmusk.quiz-app"

@MainActor
enum PersistenceController {
    static let appGroupID = appGroupIdentifier

    /// Container condiviso dall'app (e dal widget, via App Group).
    static let shared: ModelContainer = {
        let schema = Schema([QuestionProgress.self, StudySession.self])

        // Se l'App Group è disponibile usa il container condiviso, altrimenti fallback locale.
        let hasAppGroup = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
        let config = hasAppGroup
            ? ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupID))
            : ModelConfiguration(schema: schema)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fallback estremo: store locale di default.
            if let fallback = try? ModelContainer(for: schema) { return fallback }
            fatalError("Impossibile creare il ModelContainer SwiftData: \(error)")
        }
    }()

    /// Contesto principale (main actor) usato dall'app.
    static var mainContext: ModelContext { shared.mainContext }
}
