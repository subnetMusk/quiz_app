//
//  StudyDataStore.swift
//  quiz_app
//
//  Servizio SwiftData per i dati di una materia: rimpiazza il vecchio StatsStore (file JSON)
//  mantenendone l'API, e aggiunge scheduling (ripetizione spaziata) e storico sessioni.
//

import Foundation
import SwiftData

@MainActor
final class StudyDataStore {
    private let context: ModelContext
    let subjectId: String

    /// Notifica (su MainActor) ogni volta che i dati vengono salvati, così le viste che
    /// leggono dallo store possono invalidarsi e ricalcolare progresso/statistiche.
    var onChange: (() -> Void)?

    init(context: ModelContext, subjectId: String) {
        self.context = context
        self.subjectId = subjectId
    }

    /// Inizializzatore comodo che usa il contesto principale condiviso.
    convenience init(subjectId: String) {
        self.init(context: PersistenceController.mainContext, subjectId: subjectId)
    }

    // MARK: - Fetch helpers

    private func allProgress() -> [QuestionProgress] {
        let sid = subjectId
        let d = FetchDescriptor<QuestionProgress>(predicate: #Predicate { $0.subjectId == sid })
        return (try? context.fetch(d)) ?? []
    }

    private func progress(for questionId: String) -> QuestionProgress? {
        let sid = subjectId
        let qid = questionId
        var d = FetchDescriptor<QuestionProgress>(
            predicate: #Predicate { $0.subjectId == sid && $0.questionId == qid }
        )
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }

    private func progressOrCreate(for question: Question) -> QuestionProgress {
        if let p = progress(for: question.id) { return p }
        let p = QuestionProgress(subjectId: subjectId, questionId: question.id, category: question.category)
        context.insert(p)
        return p
    }

    private func allSessions() -> [StudySession] {
        let sid = subjectId
        let d = FetchDescriptor<StudySession>(predicate: #Predicate { $0.subjectId == sid })
        return (try? context.fetch(d)) ?? []
    }

    private func save() {
        try? context.save()
        onChange?()
    }

    // MARK: - Applica risposta (counters + scheduling)

    /// Aggiorna il progresso di una domanda multiple, con dettaglio errori per opzione.
    func applyDelta(for question: Question, detail: EvalDetail) {
        let p = progressOrCreate(for: question)
        p.attempts += 1
        switch detail.result {
        case .correct:    p.correct += 1
        case .incomplete: p.incomplete += 1
        case .wrong:      p.wrong += 1
        }
        if question.kind == .multiple {
            var per = p.perOption
            for id in detail.missedCorrect { per[id, default: OptionStats()].missedCorrect += 1 }
            for id in detail.wrongPicked  { per[id, default: OptionStats()].wrongSelected += 1 }
            p.perOption = per
        }
        applySchedule(to: p, result: detail.result)
        save()
    }

    /// Aggiorna il progresso di una domanda matching.
    func applyDelta(for question: Question, result: AnswerResult) {
        let p = progressOrCreate(for: question)
        p.attempts += 1
        switch result {
        case .correct:    p.correct += 1
        case .incomplete: p.incomplete += 1
        case .wrong:      p.wrong += 1
        }
        applySchedule(to: p, result: result)
        save()
    }

    /// Aggiorna il progresso di una domanda con risposta da pool randomizzato.
    /// Registra l'esito (counter + SM-2) e, slegandosi dalla frase, traccia i concetti
    /// (`canonicalPointId`) mancati/selezionati per errore e i `variantKind` ingannevoli.
    func applyPoolDelta(for question: Question, detail: PoolEvalDetail) {
        let p = progressOrCreate(for: question)
        p.attempts += 1
        switch detail.result {
        case .correct:    p.correct += 1
        case .incomplete: p.incomplete += 1
        case .wrong:      p.wrong += 1
        }
        var concepts = p.conceptStats
        for c in detail.missedConcepts { concepts[c, default: ConceptStats()].missedCorrect += 1 }
        for c in detail.wrongConcepts { concepts[c, default: ConceptStats()].wrongSelected += 1 }
        p.conceptStats = concepts

        if !detail.wrongVariants.isEmpty {
            var variants = p.variantWrong
            for v in detail.wrongVariants { variants[v.rawValue, default: 0] += 1 }
            p.variantWrong = variants
        }

        applySchedule(to: p, result: detail.result)
        save()
    }

    /// Aggiornamento scheduling con ripetizione spaziata (SM-2).
    private func applySchedule(to p: QuestionProgress, result: AnswerResult) {
        SpacedRepetition.apply(to: p, result: result)
    }

    /// Compat: SwiftData salva da solo, ma manteniamo l'API usata a fine sessione.
    func forceSave() { save() }

    // MARK: - Query statistiche (API compatibile con il vecchio StatsStore)

    /// Top N domande con più errori (`wrong > 0`), per conteggio decrescente.
    func topWrong(limit: Int) -> [String] {
        allProgress()
            .filter { $0.wrong > 0 }
            .sorted { $0.wrong > $1.wrong }
            .prefix(limit)
            .map { $0.questionId }
    }

    /// Mappa `questionId -> wrong` per le domande con almeno un errore.
    func wrongCounts() -> [String: Int] {
        var result: [String: Int] = [:]
        for p in allProgress() where p.wrong > 0 { result[p.questionId] = p.wrong }
        return result
    }

    /// Totale risposte sbagliate in una categoria.
    func wrongCount(categoryId: String) -> Int {
        allProgress().filter { $0.category == categoryId }.reduce(0) { $0 + $1.wrong }
    }

    /// Statistiche aggregate di una domanda (nil se mai affrontata).
    func questionStats(_ questionId: String) -> QuestionStats? {
        guard let p = progress(for: questionId) else { return nil }
        return QuestionStats(
            attempts: p.attempts,
            correct: p.correct,
            incomplete: p.incomplete,
            wrong: p.wrong,
            per_option: p.perOption.isEmpty ? nil : p.perOption
        )
    }

    /// Statistiche per concetto (`canonicalPointId`) di una domanda con pool randomizzato.
    func conceptStats(_ questionId: String) -> [String: ConceptStats] {
        progress(for: questionId)?.conceptStats ?? [:]
    }

    /// Conteggio dei `variantKind` (tipi di distrattore) selezionati per errore in una domanda.
    func variantWrong(_ questionId: String) -> [String: Int] {
        progress(for: questionId)?.variantWrong ?? [:]
    }

    // MARK: - Ripetizione spaziata

    /// Id delle domande "in scadenza" (già viste) ordinate per dueDate crescente.
    func dueQuestionIds(limit: Int) -> [String] {
        let now = Date()
        return allProgress()
            .filter { $0.dueDate <= now }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(limit)
            .map { $0.questionId }
    }

    /// Numero di domande già viste e in scadenza ora.
    func dueCount() -> Int {
        let now = Date()
        return allProgress().filter { $0.dueDate <= now }.count
    }

    /// Id di tutte le domande già affrontate almeno una volta.
    func seenQuestionIds() -> Set<String> {
        Set(allProgress().map { $0.questionId })
    }

#if DEBUG
    /// Popola dati plausibili (progresso + concetti + sessioni) per screenshot/demo.
    /// Idempotente: azzera e riseed. Non usato in produzione.
    func seedMockData(materia: Materia) {
        for p in allProgress() { context.delete(p) }
        for s in allSessions() { context.delete(s) }
        var rng = SystemRandomNumberGenerator()
        let now = Date(); let cal = Calendar.current

        for (i, q) in materia.questions.enumerated() {
            if i % 5 == 4 { continue } // ~80% affrontate
            let p = QuestionProgress(subjectId: subjectId, questionId: q.id, category: q.category)
            let attempts = Int.random(in: 1...4, using: &rng)
            var c = 0, inc = 0, w = 0
            for _ in 0..<attempts {
                let r = Int.random(in: 0...9, using: &rng)
                if r < 6 { c += 1 } else if r < 8 { inc += 1 } else { w += 1 }
            }
            p.attempts = attempts; p.correct = c; p.incomplete = inc; p.wrong = w
            p.repetitions = c
            p.lastReviewed = cal.date(byAdding: .day, value: -Int.random(in: 0...10, using: &rng), to: now)
            p.dueDate = cal.date(byAdding: .day, value: Int.random(in: -3...7, using: &rng), to: now) ?? now
            if let pool = q.optionPool, (w + inc) > 0 {
                var concepts: [String: ConceptStats] = [:]
                for e in pool.entries.prefix(4) {
                    if e.isCorrect { concepts[e.canonicalPointId, default: ConceptStats()].missedCorrect += Int.random(in: 0...2, using: &rng) }
                    else { concepts[e.canonicalPointId, default: ConceptStats()].wrongSelected += Int.random(in: 0...2, using: &rng) }
                }
                p.conceptStats = concepts.filter { $0.value.missedCorrect + $0.value.wrongSelected > 0 }
            }
            context.insert(p)
        }

        for d in 0..<8 {
            let total = Int.random(in: 8...15, using: &rng)
            let c = Int.random(in: (total / 2)...total, using: &rng)
            let inc = Int.random(in: 0...(total - c), using: &rng)
            let w = max(0, total - c - inc)
            let s = StudySession(subjectId: subjectId, modeRaw: "Ripasso intelligente", category: nil,
                                 total: total, correct: c, incomplete: inc, wrong: w,
                                 durationSeconds: Double(Int.random(in: 120...420, using: &rng)),
                                 date: cal.date(byAdding: .day, value: -d, to: now) ?? now)
            context.insert(s)
        }
        save()
    }
#endif

    // MARK: - Storico sessioni

    func recordSession(modeRaw: String,
                       category: String?,
                       total: Int,
                       correct: Int,
                       incomplete: Int,
                       wrong: Int,
                       duration: TimeInterval) {
        let s = StudySession(subjectId: subjectId,
                             modeRaw: modeRaw,
                             category: category,
                             total: total,
                             correct: correct,
                             incomplete: incomplete,
                             wrong: wrong,
                             durationSeconds: duration)
        context.insert(s)
        save()
    }

    func recentSessions(limit: Int = 30) -> [StudySession] {
        let sid = subjectId
        var d = FetchDescriptor<StudySession>(
            predicate: #Predicate { $0.subjectId == sid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        d.fetchLimit = limit
        return (try? context.fetch(d)) ?? []
    }

    // MARK: - Reset / Export / Import / Migrazione

    /// Cancella progresso e sessioni della materia (mantiene eventuali file JSON legacy).
    func reset() {
        for p in allProgress() { context.delete(p) }
        for s in allSessions() { context.delete(s) }
        save()
    }

    var hasAnyProgress: Bool { !allProgress().isEmpty }

    /// Costruisce uno snapshot `StatsFile` (per export/condivisione).
    func exportSnapshot() -> StatsFile {
        var per: [String: QuestionStats] = [:]
        var catWrong: [String: Int] = [:]
        for p in allProgress() {
            per[p.questionId] = QuestionStats(
                attempts: p.attempts,
                correct: p.correct,
                incomplete: p.incomplete,
                wrong: p.wrong,
                per_option: p.perOption.isEmpty ? nil : p.perOption
            )
            if p.wrong > 0 { catWrong[p.category, default: 0] += p.wrong }
        }
        return StatsFile(subject_id: subjectId, per_question: per, per_category_wrong: catWrong)
    }

    /// Fonde uno `StatsFile` (import o migrazione) nei dati SwiftData.
    /// `categoryMap` (questionId -> category) permette di attribuire la categoria alle domande importate.
    func merge(_ incoming: StatsFile, replace: Bool, categoryMap: [String: String]) {
        if replace { for p in allProgress() { context.delete(p) } }
        for (qid, qs) in incoming.per_question {
            let existing = replace ? nil : progress(for: qid)
            if let p = existing {
                p.attempts += qs.attempts
                p.correct += qs.correct
                p.incomplete += qs.incomplete
                p.wrong += qs.wrong
                var per = p.perOption
                for (k, v) in (qs.per_option ?? [:]) {
                    per[k, default: OptionStats()].missedCorrect += v.missedCorrect
                    per[k, default: OptionStats()].wrongSelected += v.wrongSelected
                }
                p.perOption = per
            } else {
                let p = QuestionProgress(subjectId: subjectId,
                                         questionId: qid,
                                         category: categoryMap[qid] ?? "")
                p.attempts = qs.attempts
                p.correct = qs.correct
                p.incomplete = qs.incomplete
                p.wrong = qs.wrong
                p.perOption = qs.per_option ?? [:]
                context.insert(p)
            }
        }
        save()
    }
}
