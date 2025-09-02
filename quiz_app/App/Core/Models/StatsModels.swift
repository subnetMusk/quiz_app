//
//  StatsModels.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//

import Foundation

/// Statistiche per una singola opzione (solo per domande multiple).
/// - `missedCorrect`: quante volte l’opzione corretta NON è stata selezionata (badge giallo).
/// - `wrongSelected`: quante volte l’opzione errata è stata selezionata (badge rosso).
public struct OptionStats: Codable, Hashable, Equatable {
    public var missedCorrect: Int
    public var wrongSelected: Int

    public init(missedCorrect: Int = 0, wrongSelected: Int = 0) {
        self.missedCorrect = missedCorrect
        self.wrongSelected = wrongSelected
    }
}

/// Statistiche aggregate per una domanda.
public struct QuestionStats: Codable, Hashable, Equatable {
    public var attempts: Int
    public var correct: Int
    public var incomplete: Int
    public var wrong: Int
    /// Mappa `optionId -> OptionStats` (presente solo per domande multiple).
    public var per_option: [Int: OptionStats]?

    public init(
        attempts: Int = 0,
        correct: Int = 0,
        incomplete: Int = 0,
        wrong: Int = 0,
        per_option: [Int: OptionStats]? = nil
    ) {
        self.attempts = attempts
        self.correct = correct
        self.incomplete = incomplete
        self.wrong = wrong
        self.per_option = per_option
    }

    /// Restituisce una copia con somma componente-per-componente (utile per import/merge).
    public func merging(with other: QuestionStats) -> QuestionStats {
        var merged = self
        merged.attempts += other.attempts
        merged.correct += other.correct
        merged.incomplete += other.incomplete
        merged.wrong += other.wrong

        if merged.per_option == nil, let o = other.per_option {
            merged.per_option = o
        } else if var m = merged.per_option, let o = other.per_option {
            for (k, v) in o {
                var cur = m[k] ?? OptionStats()
                cur.missedCorrect += v.missedCorrect
                cur.wrongSelected += v.wrongSelected
                m[k] = cur
            }
            merged.per_option = m
        }
        return merged
    }
}

/// File di statistiche per una materia.
/// È indipendente dal file domande ed è legato tramite `subject_id`.
public struct StatsFile: Codable, Equatable {
    public struct Meta: Codable, Equatable {
        /// Deve combaciare con `Materia.meta.subject_id`.
        public var subject_id: String
        /// Timestamp ISO8601 dell’ultima generazione/salvataggio.
        public var generated_at: String
        /// Versione del formato del file stats.
        public var version: Int
    }

    public var meta: Meta
    /// Statistiche per domanda (key = `Question.id`).
    public var per_question: [String: QuestionStats]
    /// Errori per categoria (key = `category id`), usato per i badge in Statistiche.
    public var per_category_wrong: [String: Int]

    public init(
        subject_id: String,
        version: Int = 1,
        per_question: [String: QuestionStats] = [:],
        per_category_wrong: [String: Int] = [:],
        date: Date = Date()
    ) {
        self.meta = Meta(
            subject_id: subject_id,
            generated_at: ISO8601DateFormatter().string(from: date),
            version: version
        )
        self.per_question = per_question
        self.per_category_wrong = per_category_wrong
    }

    /// Crea un file stats “vuoto” per una materia.
    public static func empty(subjectId: String, version: Int = 1) -> StatsFile {
        StatsFile(subject_id: subjectId, version: version)
    }

    /// Restituisce una copia con unione (somma) dei conteggi.
    public func merging(with other: StatsFile) -> StatsFile {
        precondition(meta.subject_id == other.meta.subject_id, "Different subject_id")
        var merged = self
        // merge per_question
        for (qid, s) in other.per_question {
            if let cur = merged.per_question[qid] {
                merged.per_question[qid] = cur.merging(with: s)
            } else {
                merged.per_question[qid] = s
            }
        }
        // merge per_category_wrong
        for (cat, n) in other.per_category_wrong {
            merged.per_category_wrong[cat, default: 0] += n
        }
        // aggiorna timestamp
        merged.meta.generated_at = ISO8601DateFormatter().string(from: Date())
        return merged
    }

    /// Ritorna le top N domande con più errori (wrong) globali.
    public func topWrongQuestions(limit: Int) -> [String] {
        let sorted = per_question.sorted { $0.value.wrong > $1.value.wrong }
        return Array(sorted.prefix(limit).map { $0.key })
    }
}
