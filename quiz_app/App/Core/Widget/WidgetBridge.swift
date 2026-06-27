//
//  WidgetBridge.swift
//  quiz_app
//
//  Scrive uno snapshot leggero (n° domande in scadenza + materia) nell'App Group condiviso,
//  così il widget può mostrarlo senza aprire lo store SwiftData. Aggiorna le timeline del widget.
//

import Foundation
import WidgetKit

enum WidgetBridge {
    enum Keys {
        static let dueCount = "widget_due_count"
        static let subjectName = "widget_subject_name"
        static let updatedAt = "widget_updated_at"
    }

    /// Aggiorna lo snapshot condiviso e ricarica le timeline del widget.
    /// Se l'App Group non è ancora configurato in Xcode, l'operazione è un no-op sicuro.
    static func update(dueCount: Int, subjectName: String?) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        defaults.set(dueCount, forKey: Keys.dueCount)
        defaults.set(subjectName ?? "", forKey: Keys.subjectName)
        defaults.set(Date(), forKey: Keys.updatedAt)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
