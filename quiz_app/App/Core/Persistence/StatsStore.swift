//
//  StatsStore.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//

import Foundation
import Combine

/// Store delle statistiche per la materia attiva.
/// - Carica da disco all'attivazione materia.
/// - Aggiorna counters ad ogni risposta.
/// - Salva periodicamente (debounced) su disco.
final class StatsStore: ObservableObject {
    @Published private(set) var stats: StatsFile
    private var saveDebounce = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(subjectId: String) {
        self.stats = QuizIO.loadStats(subjectId: subjectId)
        // debounce salvataggi per evitare eccesso di I/O
        saveDebounce
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.persist() }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Sostituisce l'intero file statistiche (es. dopo import) e salva.
    func replace(with newStats: StatsFile) {
        precondition(newStats.meta.subject_id == stats.meta.subject_id, "subject_id mismatch")
        self.stats = newStats
        requestSave()
    }

    /// Flush: reset completo del file statistiche.
    func reset() {
        stats = .empty(subjectId: stats.meta.subject_id)
        requestSave()
    }

    /// Applica un delta su una domanda multiple, con dettaglio errori per opzione.
    func applyDelta(for question: Question, detail: EvalDetail) {
        // 1) aggiorna per_question
        var qstats = stats.per_question[question.id] ?? QuestionStats()
        let delta = statsDelta(for: question, detail: detail)
        qstats = qstats.merging(with: delta)
        stats.per_question[question.id] = qstats

        // 2) aggiorna per_category_wrong se la risposta è wrong
        if detail.result == .wrong {
            for cat in categoriesForCounting(question: question) {
                stats.per_category_wrong[cat, default: 0] += 1
            }
        }

        // 3) timestamp
        stats.meta.generated_at = ISO8601DateFormatter().string(from: Date())

        requestSave()
    }

    /// Applica un delta su una domanda matching.
    func applyDelta(for question: Question, result: AnswerResult) {
        var qstats = stats.per_question[question.id] ?? QuestionStats()
        let incrCorrect     = (result == .correct) ? 1 : 0
        let incrIncomplete  = (result == .incomplete) ? 1 : 0
        let incrWrong       = (result == .wrong) ? 1 : 0
        qstats.attempts    += 1
        qstats.correct     += incrCorrect
        qstats.incomplete  += incrIncomplete
        qstats.wrong       += incrWrong
        stats.per_question[question.id] = qstats

        if result == .wrong {
            for cat in categoriesForCounting(question: question) {
                stats.per_category_wrong[cat, default: 0] += 1
            }
        }

        stats.meta.generated_at = ISO8601DateFormatter().string(from: Date())
        requestSave()
    }

    /// Restituisce le top N domande con più errori (wrong).
    func topWrong(limit: Int) -> [String] {
        stats.topWrongQuestions(limit: limit)
    }

    /// Ritorna il dettaglio statistiche di una domanda (se presente).
    func questionStats(_ questionId: String) -> QuestionStats? {
        stats.per_question[questionId]
    }

    /// Conteggio errori per categoria (per badge in Statistiche).
    func wrongCount(categoryId: String) -> Int {
        stats.per_category_wrong[categoryId, default: 0]
    }

    /// Esporta l'URL del file stats corrente (se esiste su disco).
    func exportURL() -> URL? {
        QuizIO.exportStatsURL(subjectId: stats.meta.subject_id)
    }

    /// Forza il salvataggio immediato delle statistiche (per fine sessione).
    func forceSave() {
        persist()
    }

    // MARK: - Private

    private func requestSave() {
        saveDebounce.send(())
    }

    private func persist() {
        do { _ = try QuizIO.saveStats(stats) }
        catch { print("❌ Save stats failed:", error) }
    }
}

// MARK: - Helper Functions

extension StatsStore {
    /// Delta delle statistiche per una domanda multiple
    private func statsDelta(for question: Question, detail: EvalDetail) -> QuestionStats {
        let incrCorrect = (detail.result == .correct) ? 1 : 0
        let incrIncomplete = (detail.result == .incomplete) ? 1 : 0
        let incrWrong = (detail.result == .wrong) ? 1 : 0
        return QuestionStats(
            attempts: 1,
            correct: incrCorrect,
            incomplete: incrIncomplete,
            wrong: incrWrong
        )
    }

    /// Estrae le categorie per conteggio
    private func categoriesForCounting(question: Question) -> [String] {
        return [question.category]
    }
}