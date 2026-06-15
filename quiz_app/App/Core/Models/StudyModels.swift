//
//  StudyModels.swift
//  quiz_app
//
//  Modelli SwiftData per i dati mutabili (progresso per domanda + storico sessioni).
//  Le materie restano file JSON read-only: qui vive solo ciò che cambia con lo studio.
//

import Foundation
import SwiftData

/// Progresso e statistiche per una singola domanda, con scheduling di ripetizione spaziata (SM-2).
/// Identità logica: (`subjectId`, `questionId`). L'unicità è garantita via fetch-or-create.
@Model
final class QuestionProgress {
    var subjectId: String = ""
    var questionId: String = ""
    /// Categoria denormalizzata (dalla `Materia`) per aggregare le statistiche senza ricaricare il JSON.
    var category: String = ""

    var attempts: Int = 0
    var correct: Int = 0
    var incomplete: Int = 0
    var wrong: Int = 0

    /// JSON di `[Int: OptionStats]` (statistiche per opzione, solo domande multiple).
    var perOptionData: Data? = nil

    /// JSON di `[String: ConceptStats]` (statistiche per concetto, domande con pool randomizzato).
    var poolConceptData: Data? = nil
    /// JSON di `[String: Int]` (`variantKind.rawValue` -> quante volte selezionato per errore).
    var poolVariantData: Data? = nil

    // MARK: - Scheduling SM-2
    var easeFactor: Double = 2.5
    var intervalDays: Int = 0
    var repetitions: Int = 0
    var dueDate: Date = Date.distantPast
    var lastReviewed: Date? = nil

    init(subjectId: String, questionId: String, category: String) {
        self.subjectId = subjectId
        self.questionId = questionId
        self.category = category
    }

    /// Accesso tipizzato alle statistiche per opzione (codificate in `perOptionData`).
    var perOption: [Int: OptionStats] {
        get {
            guard let data = perOptionData else { return [:] }
            return (try? JSONDecoder().decode([Int: OptionStats].self, from: data)) ?? [:]
        }
        set {
            perOptionData = newValue.isEmpty ? nil : (try? JSONEncoder().encode(newValue))
        }
    }

    /// Accesso tipizzato alle statistiche per concetto (codificate in `poolConceptData`).
    var conceptStats: [String: ConceptStats] {
        get {
            guard let data = poolConceptData else { return [:] }
            return (try? JSONDecoder().decode([String: ConceptStats].self, from: data)) ?? [:]
        }
        set {
            poolConceptData = newValue.isEmpty ? nil : (try? JSONEncoder().encode(newValue))
        }
    }

    /// Accesso tipizzato ai conteggi per `variantKind` (codificati in `poolVariantData`).
    var variantWrong: [String: Int] {
        get {
            guard let data = poolVariantData else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        }
        set {
            poolVariantData = newValue.isEmpty ? nil : (try? JSONEncoder().encode(newValue))
        }
    }
}

/// Una sessione di studio completata (per storico e grafici di trend).
@Model
final class StudySession {
    var subjectId: String = ""
    var date: Date = Date()
    /// Valore di `QuizSessionMode.rawValue` o equivalente leggibile.
    var modeRaw: String = ""
    var category: String? = nil

    var total: Int = 0
    var correct: Int = 0
    var incomplete: Int = 0
    var wrong: Int = 0
    var durationSeconds: Double = 0

    init(subjectId: String,
         modeRaw: String,
         category: String?,
         total: Int,
         correct: Int,
         incomplete: Int,
         wrong: Int,
         durationSeconds: Double,
         date: Date = Date()) {
        self.subjectId = subjectId
        self.modeRaw = modeRaw
        self.category = category
        self.total = total
        self.correct = correct
        self.incomplete = incomplete
        self.wrong = wrong
        self.durationSeconds = durationSeconds
        self.date = date
    }

    var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 0 }
}
