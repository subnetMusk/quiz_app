//
//  QuizView.swift
//  quiz_app
//
//  Created by Leonardo Soligo on 9/1/25.
//

import SwiftUI
import AVKit
import OSLog

/// Logger leggero per diagnosticare blocchi/transizioni della sessione (visibile in Console.app,
/// categoria "quiz"). Nessun costo apprezzabile in release.
private let quizLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "quiz_app", category: "quiz")

struct QuizView: View {
    let materia: Materia
    let stats: StudyDataStore
    let mode: QuizSessionMode
    let category: String? // for byCategory modes
    let count: Int
    /// Domande imposte dall'esterno (modalità guidata): se presenti, bypassano il pool del `mode`.
    var presetQuestions: [Question]? = nil
    /// Se valorizzato, il riepilogo mostra "Continua" che chiama questa closure invece di uscire
    /// (usato dalla modalità guidata per avanzare alla sezione successiva).
    var onComplete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    // Stato runtime
    @State private var items: [Question] = []
    @State private var index: Int = 0
    @State private var finished: Bool = false
    @State private var endedEarly: Bool = false   // riepilogo da "Termina" (sessione parziale)
    @State private var sessionDuration: TimeInterval = 0  // durata catturata alla chiusura

    // Stato risposta corrente (multiple / matching)
    @State private var selectedOptions = Set<Int>()       // per multiple
    @State private var userPairs: [Int:Int] = [:]         // per matching
    @State private var feedback: AnswerResult? = nil
    @State private var feedbackDetail: EvalDetail? = nil
    @State private var currentQuestion: Question? = nil

    // Stato risposta per i nuovi tipi (Fase 1)
    @State private var tfAnswer: Bool? = nil              // trueFalseMotivated: scelta V/F
    @State private var tfMotivation = Set<Int>()          // trueFalseMotivated: motivazioni selezionate
    @State private var tfShowMotivation = false           // trueFalseMotivated: step 2 sbloccato
    @State private var clozeFilled: [Int:String] = [:]    // clozeWordBank: parola scelta per ogni buco
    @State private var textAnswer: String = ""            // shortAnswer / calculation / risposta aperta
    @State private var userOrder: [Int] = []              // ordered: sequenza scelta

    // Stato risposta per i tipi Fase 2
    @State private var formativeRevealed = false          // openRubric / constructedResponse: rubrica mostrata
    @State private var caseInputs: [String: AnswerInput] = [:]  // input per ogni sotto-domanda (caso/media)

    // Stato pool randomizzato (Fase 3)
    @State private var poolSamples: [String: [PoolEntry]] = [:] // campione stabile per domanda/sotto-domanda (id)
    @State private var poolSelected: Set<String> = []          // selezione top-level (id entry mostrate)
    
    // Risultati della sessione corrente
    @State private var sessionResults: [(questionId: String, result: AnswerResult)] = []
    @State private var sessionStart: Date? = nil
    @State private var sessionRecorded = false

    var body: some View {
        // Top-level switch: summary e domanda NON sono mai ScrollView annidate (evita
        // l'anti-pattern SwiftUI che può dare altezza 0 / scroll bloccato).
        Group {
            if finished {
                summaryView
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 16) {
                            header

                            if current != nil {
                                QuestionCard(question: current!,
                                             selectedOptions: $selectedOptions,
                                             userPairs: $userPairs,
                                             tfAnswer: $tfAnswer,
                                             tfMotivation: $tfMotivation,
                                             tfShowMotivation: $tfShowMotivation,
                                             clozeFilled: $clozeFilled,
                                             textAnswer: $textAnswer,
                                             userOrder: $userOrder,
                                             caseInputs: $caseInputs,
                                             poolSamples: poolSamples,
                                             poolSelected: $poolSelected,
                                             revealed: revealed)
                                    .id(current!.id)

                                if let f = feedback {
                                    FeedbackBanner(result: f, question: currentQuestion, detail: feedbackDetail)
                                        .transition(.opacity)
                                }
                            } else {
                                ProgressView("Preparazione domande…")
                            }
                        }
                        .padding()
                    }

                    // Pulsanti fissi in fondo
                    if current != nil {
                        bottomButtons
                    }
                }
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            // In modalità guidata (onComplete) la progressione è gestita dal flusso: niente "Termina".
            if onComplete == nil && !finished && !items.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Termina") { endSession() }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sensoryFeedback(trigger: feedback) { _, newValue in
            switch newValue {
            case .correct?:    return .success
            case .incomplete?: return .warning
            case .wrong?:      return .error
            case nil:          return nil
            }
        }
        .onAppear { buildSession() }
    }

    /// Termina anticipatamente la sessione: salva i risultati parziali e mostra il riepilogo
    /// delle sole domande svolte (non scarta la sessione né torna indietro a vuoto).
    private func endSession() {
        recordCurrentSession()
        quizLog.info("endSession: answered=\(sessionResults.count) scored=\(scoredItems.count) index=\(index)")
        withAnimation {
            endedEarly = true
            finished = true
        }
    }

    /// Registra la sessione corrente nello storico (una sola volta).
    private func recordCurrentSession() {
        guard !sessionRecorded, !sessionResults.isEmpty else { return }
        sessionRecorded = true
        let correct = sessionResults.filter { $0.result == .correct }.count
        let incomplete = sessionResults.filter { $0.result == .incomplete }.count
        let wrong = sessionResults.filter { $0.result == .wrong }.count
        let duration = sessionStart.map { Date().timeIntervalSince($0) } ?? 0
        sessionDuration = duration
        stats.recordSession(modeRaw: mode.rawValue,
                            category: category,
                            total: sessionResults.count,
                            correct: correct,
                            incomplete: incomplete,
                            wrong: wrong,
                            duration: duration)
        WidgetBridge.update(dueCount: stats.dueCount(), subjectName: materia.meta.subject_name)
    }

    // MARK: - Bottom Buttons
    
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack(spacing: 16) {
                Button(action: verify) {
                    Text(verifyButtonTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(revealed || !canVerify ? Color.gray.opacity(0.6) : Color.green)
                        .cornerRadius(12)
                }
                .disabled(revealed || !canVerify)

                Button(action: next) {
                    Text("Avanti")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(revealed ? Color.blue : Color.gray.opacity(0.6))
                        .cornerRadius(12)
                }
                .disabled(!revealed)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Helpers

    private var navigationTitle: String {
        guard !items.isEmpty else { return "Ripasso" }
        if finished {
            return "Riepilogo"
        }
        return "Domanda \(index + 1) / \(items.count)"
    }

    private var header: some View {
        // Contesto leggero: l'esito della risposta vive solo nel FeedbackBanner (niente doppioni).
        HStack {
            Text(materia.meta.subject_name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var current: Question? {
        guard index < items.count else { return nil }
        return items[index]
    }

    /// Domande che concorrono al punteggio di sessione (esclude i tipi puramente formativi).
    private var scoredItems: [Question] { items.filter { !$0.isFormative } }

    /// Domande effettivamente svolte (con esito registrato) in questa sessione: base del riepilogo,
    /// così "Termina" mostra le statistiche delle sole domande affrontate.
    private var answeredQuestions: [Question] {
        let answeredIds = Set(sessionResults.map { $0.questionId })
        return items.filter { answeredIds.contains($0.id) }
    }

    private func buildSession() {
        // Modalità guidata: domande imposte dall'esterno, niente pool/shuffle.
        if let preset = presetQuestions {
            items = preset
            index = 0
            finished = preset.isEmpty
            endedEarly = false
            sessionResults = []
            sessionStart = Date()
            sessionRecorded = false
            generatePoolSamples()
            resetAnswerState()
            quizLog.info("buildSession(preset): count=\(items.count)")
            return
        }

        // 1) Sorgente domande
        let pool: [Question]
        switch mode {
        case .generic:
            pool = materia.questions
        case .byCategory:
            guard let cat = category else { items = []; return }
            pool = materia.questions.filter { $0.category == cat }
        case .errors:
            pool = questionsForTopErrors(limit: count)
        case .errorsByCategory:
            guard let cat = category else { items = []; return }
            pool = questionsForTopErrors(limit: count, category: cat)
        case .smart:
            pool = smartReviewPool()
        case .topicPrimary:
            guard let cat = category else { items = []; return }
            pool = topicPrimaryPool(category: cat)
        }

        // 2) Campionamento (count). In smart/topicPrimary l'ordine è già una priorità: niente shuffle.
        let ordered = (mode == .smart || mode == .topicPrimary)
        let chosen = ordered
            ? Array(pool.prefix(count))
            : Array(pool.shuffled().prefix(count))
        items = chosen
        index = 0
        finished = chosen.isEmpty
        endedEarly = false
        sessionResults = [] // Reset dei risultati della sessione
        sessionStart = Date()
        sessionRecorded = false
        generatePoolSamples()
        resetAnswerState()
        quizLog.info("buildSession: mode=\(mode.rawValue, privacy: .public) count=\(items.count)")
    }

    /// Campiona una volta per sessione i pool randomizzati di domande e sotto-domande.
    /// Il campione resta stabile per tutto l'attempt (non ricalcolato a ogni render) e cambia
    /// nelle sessioni successive perché usa l'RNG di sistema.
    private func generatePoolSamples() {
        poolSamples = [:]
        var rng = SystemRandomNumberGenerator()
        func sampleIfNeeded(_ q: Question) {
            if let pool = q.optionPool, let s = PoolSampler.sample(pool, using: &rng) {
                poolSamples[q.id] = s
            }
            for sub in q.subquestions ?? [] { sampleIfNeeded(sub) }
        }
        for q in items { sampleIfNeeded(q) }
    }

    private func resetAnswerState() {
        selectedOptions = []
        userPairs = [:]
        feedback = nil
        feedbackDetail = nil
        currentQuestion = nil
        tfAnswer = nil
        tfMotivation = []
        tfShowMotivation = false
        clozeFilled = [:]
        textAnswer = ""
        userOrder = []
        formativeRevealed = false
        caseInputs = [:]
        poolSelected = []
    }

    /// `true` quando il risultato/rubrica della domanda corrente è già stato mostrato.
    private var revealed: Bool { feedback != nil || formativeRevealed }

    /// Etichetta del pulsante principale: per i tipi formativi "rivela" la rubrica.
    private var verifyButtonTitle: String {
        (current?.isFormative ?? false) ? "Mostra soluzione" : "Verifica"
    }

    /// `true` se l'input corrente è sufficiente per premere "Verifica" (evita verifiche a vuoto).
    private var canVerify: Bool {
        guard let q = current else { return false }
        switch q.kind {
        case .multiple, .matching, .ordered, .clozeWordBank,
             .openRubric, .constructedResponse, .mediaAnalysis, .caseStudy:
            return true
        case .trueFalseMotivated:
            return tfAnswer != nil
        case .shortAnswer, .calculation:
            return !textAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func verify() {
        guard let q = current else { return }
        currentQuestion = q
        quizLog.info("verify: kind=\(String(describing: q.kind), privacy: .public) id=\(q.id, privacy: .public)")
        switch q.kind {
        case .multiple:
            let detail = evaluateMultiple(question: q, selected: selectedOptions)
            feedback = detail.result
            feedbackDetail = detail
            sessionResults.append((questionId: q.id, result: detail.result)) // Memorizza il risultato della sessione
            stats.applyDelta(for: q, detail: detail)
        case .matching:
            let res = evaluateMatching(question: q, userPairs: userPairs)
            finishVerify(q, res)
        case .trueFalseMotivated:
            guard let chosen = tfAnswer else { return }
            let hasPool = q.optionPool != nil
            let hasMotivation = hasPool || !(q.motivationOptions ?? []).isEmpty
            // Step 1: se il V/F è giusto e c'è una fase motivazione, sbloccala senza registrare.
            if !tfShowMotivation, chosen == q.answer, hasMotivation {
                withAnimation { tfShowMotivation = true }
                return
            }
            if hasPool {
                // V/F sbagliato → wrong senza considerare il pool; altrimenti valuta il campione mostrato.
                if chosen != q.answer {
                    finishVerify(q, .wrong)
                } else {
                    let shown = poolSamples[q.id] ?? []
                    let detail = evaluatePoolSelection(shown: shown, selected: poolSelected)
                    feedback = detail.result
                    feedbackDetail = nil
                    sessionResults.append((questionId: q.id, result: detail.result))
                    stats.applyPoolDelta(for: q, detail: detail)
                }
            } else {
                finishVerify(q, evaluateTrueFalseMotivated(question: q, answer: chosen, motivation: tfMotivation))
            }
        case .clozeWordBank:
            finishVerify(q, evaluateCloze(question: q, filled: clozeFilled).result)
        case .shortAnswer:
            finishVerify(q, evaluateShortAnswer(question: q, text: textAnswer))
        case .ordered:
            finishVerify(q, evaluateOrdered(question: q, userOrder: userOrder).result)
        case .calculation:
            finishVerify(q, evaluateCalculation(question: q, text: textAnswer))
        case .openRubric, .constructedResponse:
            // Con checklist di correzione (pool) la domanda è valutabile: registra l'esito e
            // mostra comunque la rubrica per il confronto sulla risposta scritta.
            if q.optionPool != nil {
                let shown = poolSamples[q.id] ?? []
                let detail = evaluatePoolSelection(shown: shown, selected: poolSelected)
                feedback = detail.result
                feedbackDetail = nil
                sessionResults.append((questionId: q.id, result: detail.result))
                stats.applyPoolDelta(for: q, detail: detail)
                formativeRevealed = true
            } else {
                // Nessun pool: resta formativa (rubrica di autovalutazione, nessun esito).
                formativeRevealed = true
            }
        case .caseStudy, .mediaAnalysis:
            if q.isFormative {
                // Tutte le sotto-domande sono formative → solo rubrica, niente esito.
                formativeRevealed = true
            } else {
                // Aggrega le sotto-domande valutabili (le formative non concorrono al punteggio).
                let scored = (q.subquestions ?? []).filter { !$0.isFormative }
                finishVerify(q, aggregateResults(scored.map { resultForSub($0) }))
            }
        }
    }

    /// Valuta una sotto-domanda di un composito, usando il campione del pool se presente.
    /// Per `trueFalseMotivated` il V/F deve essere corretto **e** la selezione del pool corretta.
    private func resultForSub(_ sub: Question) -> AnswerResult {
        let input = caseInputs[sub.id] ?? AnswerInput()
        guard sub.optionPool != nil else { return evaluate(sub, input: input) }
        let shown = poolSamples[sub.id] ?? []
        let poolResult = evaluatePoolSelection(shown: shown, selected: input.poolSelected).result
        if sub.kind == .trueFalseMotivated {
            return input.tfAnswer == sub.answer ? poolResult : .wrong
        }
        return poolResult
    }

    /// Coda comune di `verify` per i tipi senza dettaglio per-opzione: mostra il feedback,
    /// registra il risultato di sessione e aggiorna statistiche/scheduling.
    private func finishVerify(_ q: Question, _ res: AnswerResult) {
        feedback = res
        feedbackDetail = nil
        sessionResults.append((questionId: q.id, result: res))
        stats.applyDelta(for: q, result: res)
    }

    private func next() {
        feedback = nil
        feedbackDetail = nil
        currentQuestion = nil
        index += 1
        quizLog.info("next: index=\(index) of \(items.count)")
        if index >= items.count {
            finished = true
            recordCurrentSession()
            // Forza il salvataggio delle statistiche al termine della sessione
            stats.forceSave()
        } else {
            resetAnswerState()
        }
    }

    // MARK: - Error ranking

    /// Top X errori globali (riempie con casuali se gli errori sono meno di `limit`).
    private func questionsForTopErrors(limit: Int) -> [Question] {
        let topIds = stats.topWrong(limit: limit)
        let map = Dictionary(uniqueKeysWithValues: materia.questions.map { ($0.id, $0) })
        let picked = topIds.compactMap { map[$0] }
        return fill(picked, upTo: limit, from: materia.questions)
    }

    /// Top X errori per categoria (riempie con casuali della stessa categoria se sono meno di `limit`).
    private func questionsForTopErrors(limit: Int, category: String) -> [Question] {
        let counts = stats.wrongCounts()
        let categoryPool = materia.questions.filter { $0.category == category }
        let picked = categoryPool
            .filter { (counts[$0.id] ?? 0) > 0 }
            .sorted { (counts[$0.id] ?? 0) > (counts[$1.id] ?? 0) }
        return fill(picked, upTo: limit, from: categoryPool)
    }

    /// Pool per il "Ripasso intelligente": prima le domande viste e in scadenza
    /// (ordinate per dueDate), poi quelle mai affrontate (materiale nuovo).
    private func smartReviewPool() -> [Question] {
        let map = Dictionary(uniqueKeysWithValues: materia.questions.map { ($0.id, $0) })
        let dueSeen = stats.dueQuestionIds(limit: materia.questions.count).compactMap { map[$0] }
        let seen = stats.seenQuestionIds()
        let newOnes = materia.questions.filter { !seen.contains($0.id) }
        return dueSeen + newOnes
    }

    /// Pool per il flusso Teoria→Quiz: prima le più sbagliate sopra soglia dinamica,
    /// includendo sempre le domande curate come `primary` per l'argomento.
    private func topicPrimaryPool(category: String) -> [Question] {
        let categoryPool = materia.questions(category: category)
        let picked = materia.topicPrimaryCandidates(category: category, wrongCounts: stats.wrongCounts())
        return fill(picked, upTo: min(count, categoryPool.count), from: categoryPool)
    }

    /// Completa `picked` fino a `limit` domande pescando casualmente da `pool`
    /// (escludendo quelle già presenti), preservando l'ordine di `picked`.
    private func fill(_ picked: [Question], upTo limit: Int, from pool: [Question]) -> [Question] {
        guard picked.count < limit else { return Array(picked.prefix(limit)) }
        let pickedIds = Set(picked.map { $0.id })
        let extra = pool
            .filter { !pickedIds.contains($0.id) }
            .shuffled()
            .prefix(limit - picked.count)
        return picked + extra
    }

    // MARK: - Summary

    private var summaryView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header del riepilogo
                VStack(spacing: 8) {
                    Image(systemName: endedEarly ? "flag.checkered.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(endedEarly ? .blue : .green)

                    Text(endedEarly ? "Sessione terminata" : "Sessione completata!")
                        .font(.title.bold())

                    Text(summarySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // Statistiche generali della sessione
                sessionStatsCard

                // Progress per categoria: solo le domande effettivamente svolte
                if !answeredQuestions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance per Categoria")
                            .font(.headline.bold())

                        let sessionCats = Dictionary(grouping: answeredQuestions, by: { $0.category })
                        ForEach(sessionCats.keys.sorted(), id: \.self) { cat in
                            let categoryQuestions = sessionCats[cat] ?? []
                            let total = categoryQuestions.count
                            let categoryResults = categoryQuestions.compactMap { question in
                                sessionResults.first { $0.questionId == question.id }
                            }
                            let correct = categoryResults.filter { $0.result == .correct }.count

                            categoryProgressRow(category: cat, correct: correct, total: total)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }

                // Azioni
                VStack(spacing: 12) {
                    if let onComplete {
                        // Modalità guidata: un solo pulsante per proseguire il percorso.
                        Button {
                            onComplete()
                        } label: {
                            Label("Continua", systemImage: "arrow.right.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        NavigationLink {
                            QuizView(materia: materia, stats: stats, mode: mode, category: category, count: count)
                        } label: {
                            Label("Rifai una sessione", systemImage: "arrow.clockwise.circle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Fine") {
                            // Torna al menu principale dismissing questa vista
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Sottotitolo del riepilogo: per le sessioni terminate in anticipo esplicita quante domande
    /// sono state svolte sul totale previsto.
    private var summarySubtitle: String {
        if endedEarly {
            return "Hai risposto a \(sessionResults.count) di \(scoredItems.count) domande"
        }
        return "Ecco come è andata la tua performance"
    }

    @ViewBuilder
    private var sessionStatsCard: some View {
        // La base del punteggio sono le domande effettivamente svolte (non l'intera sessione):
        // così il riepilogo è corretto anche quando si preme "Termina" a metà.
        let answered = sessionResults.count

        if answered == 0 {
            VStack(spacing: 8) {
                Text(scoredItems.isEmpty ? "Sessione formativa" : "Nessuna domanda valutata")
                    .font(.headline.bold())
                Text(scoredItems.isEmpty
                     ? "Le domande aperte non producono un punteggio automatico."
                     : "Non hai completato domande con punteggio in questa sessione.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        } else {
            let correctAnswers = sessionResults.filter { $0.result == .correct }.count
            let incompleteAnswers = sessionResults.filter { $0.result == .incomplete }.count
            let wrongAnswers = sessionResults.filter { $0.result == .wrong }.count
            // Precisione: solo le corrette valgono 1; incomplete e sbagliate valgono 0.
            let accuracy = Double(correctAnswers) / Double(answered) * 100
            let warn = QuizTheme.Colors.warning
            let verdict = performanceVerdict(accuracy)

            VStack(spacing: 16) {
                // Headline: punteggio + giudizio
                VStack(spacing: 2) {
                    Text("\(Int(accuracy.rounded()))%")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(verdict.color)
                    Text(verdict.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(verdict.color)
                    Text("\(correctAnswers) corrette su \(answered) domande svolte")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Barra stratificata (su domande svolte)
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        Rectangle().fill(.green)
                            .frame(width: geometry.size.width * CGFloat(correctAnswers) / CGFloat(answered))
                        if incompleteAnswers > 0 {
                            Rectangle().fill(warn)
                                .frame(width: geometry.size.width * CGFloat(incompleteAnswers) / CGFloat(answered))
                        }
                        Rectangle().fill(.red)
                            .frame(width: geometry.size.width * CGFloat(wrongAnswers) / CGFloat(answered))
                    }
                }
                .frame(height: 10)
                .clipShape(Capsule())
                .background(Capsule().fill(Color(.systemGray5)))

                // Conteggi
                HStack(spacing: 20) {
                    statBadge(title: "Corrette", value: "\(correctAnswers)", color: .green)
                    if incompleteAnswers > 0 {
                        statBadge(title: "Incomplete", value: "\(incompleteAnswers)", color: warn)
                    }
                    statBadge(title: "Sbagliate", value: "\(wrongAnswers)", color: .red)
                }

                Divider()

                // Tempo
                HStack {
                    metricRow(icon: "clock", label: "Tempo", value: formattedDuration(sessionDuration))
                    Spacer()
                    metricRow(icon: "timer", label: "Media",
                              value: "\(formattedDuration(sessionDuration / Double(answered)))/dom.")
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    /// Giudizio qualitativo in base alla precisione, coerente con i colori dell'app.
    private func performanceVerdict(_ accuracy: Double) -> (label: String, color: Color) {
        switch accuracy {
        case 85...:    return ("Ottimo lavoro", .green)
        case 60..<85:  return ("Buon risultato", QuizTheme.Colors.warning)
        default:       return ("Da ripassare", .red)
        }
    }

    /// Formatta una durata in modo compatto (es. "1m 20s", "45s").
    private func formattedDuration(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded()))
        if s < 60 { return "\(s)s" }
        let m = s / 60, r = s % 60
        return r == 0 ? "\(m)m" : "\(m)m \(r)s"
    }

    private func metricRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(label).foregroundStyle(.secondary)
            Text(value).fontWeight(.semibold)
        }
    }

    private func statBadge(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func categoryProgressRow(category: String, correct: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(materia.displayName(forCategory: category, sub: nil))
                    .font(.subheadline.weight(.medium))
                Spacer()
                let pct = total > 0 ? Int((Double(correct) / Double(total) * 100).rounded()) : 0
                Text("\(correct)/\(total) · \(pct)%")
                    .font(.subheadline.monospaced().weight(.semibold))
                    .foregroundStyle(correct == total ? .green : (correct == 0 ? .red : QuizTheme.Colors.warning))
            }
            
            // Progress bar per categoria
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(.green.opacity(0.7))
                        .frame(width: total > 0 ? geometry.size.width * CGFloat(correct) / CGFloat(total) : 0)
                    
                    Rectangle()
                        .fill(.red.opacity(0.3))
                        .frame(width: total > 0 ? geometry.size.width * CGFloat(total - correct) / CGFloat(total) : geometry.size.width)
                }
            }
            .frame(height: 6)
            .background(Color(.systemGray6))
            .cornerRadius(3)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - UI COMPONENTS

private struct QuestionCard: View {
    let question: Question
    @Binding var selectedOptions: Set<Int>
    @Binding var userPairs: [Int:Int]
    @Binding var tfAnswer: Bool?
    @Binding var tfMotivation: Set<Int>
    @Binding var tfShowMotivation: Bool
    @Binding var clozeFilled: [Int:String]
    @Binding var textAnswer: String
    @Binding var userOrder: [Int]
    @Binding var caseInputs: [String: AnswerInput]
    let poolSamples: [String: [PoolEntry]]
    @Binding var poolSelected: Set<String>
    let revealed: Bool

    @State private var rightOrder: [Int] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.prompt).font(.headline)

            if let code = question.code, !code.isEmpty {
                ScrollView(.horizontal) {
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }

            switch question.kind {
            case .multiple:
                MultipleView(options: question.options ?? [], selected: $selectedOptions)

            case .matching:
                MatchingView(left: question.left ?? [],
                             right: question.right ?? [],
                             userPairs: $userPairs,
                             rightOrder: $rightOrder)

            case .trueFalseMotivated:
                TrueFalseMotivatedView(question: question,
                                       answer: $tfAnswer,
                                       motivation: $tfMotivation,
                                       showMotivation: $tfShowMotivation,
                                       poolShown: poolSamples[question.id],
                                       poolSelected: $poolSelected,
                                       revealed: revealed)

            case .clozeWordBank:
                ClozeWordBankView(question: question, filled: $clozeFilled)

            case .shortAnswer:
                ShortAnswerView(text: $textAnswer)

            case .ordered:
                OrderedView(items: question.items ?? [], userOrder: $userOrder)

            case .calculation:
                CalculationView(question: question, text: $textAnswer)

            case .openRubric:
                OpenRubricView(question: question,
                               poolShown: poolSamples[question.id], poolSelected: $poolSelected,
                               revealed: revealed)

            case .constructedResponse:
                ConstructedResponseView(question: question,
                                        poolShown: poolSamples[question.id], poolSelected: $poolSelected,
                                        revealed: revealed)

            case .mediaAnalysis, .caseStudy:
                CaseStudyView(question: question, inputs: $caseInputs,
                              poolSamples: poolSamples, revealed: revealed)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - True/False motivato (due step)

private struct TrueFalseMotivatedView: View {
    let question: Question
    @Binding var answer: Bool?
    @Binding var motivation: Set<Int>
    @Binding var showMotivation: Bool
    /// Campione del pool randomizzato (se la domanda lo usa); ha la precedenza su `motivationOptions`.
    var poolShown: [PoolEntry]? = nil
    @Binding var poolSelected: Set<String>
    var revealed: Bool = false
    /// Se true (sotto-domanda di un caso), il V/F resta modificabile e le motivazioni compaiono
    /// solo quando il V/F è corretto: non vengono mai esposte prima.
    var singleStep: Bool = false

    @State private var shuffledMotivations: [Option] = []

    /// Le motivazioni non devono apparire prima che il V/F sia corretto.
    private var motivationsVisible: Bool {
        if singleStep { return answer == question.answer }
        return showMotivation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                choiceButton(label: "Vero", value: true)
                choiceButton(label: "Falso", value: false)
            }

            if motivationsVisible {
                Divider()
                Text("Perché?")
                    .font(.subheadline.weight(.semibold))
                if let shown = poolShown {
                    PoolSelectionView(shown: shown, selected: $poolSelected, revealed: revealed)
                } else {
                    ForEach(shuffledMotivations, id: \.id) { opt in
                        motivationRow(opt)
                    }
                }
            }
        }
        .onAppear {
            if shuffledMotivations.isEmpty {
                shuffledMotivations = (question.motivationOptions ?? []).shuffled()
            }
        }
    }

    private func choiceButton(label: String, value: Bool) -> some View {
        let isSelected = answer == value
        let locked = showMotivation && !singleStep
        return Button {
            if !locked { answer = value }   // bloccato dopo essere passati allo step 2
        } label: {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func motivationRow(_ opt: Option) -> some View {
        Button {
            if motivation.contains(opt.id) { motivation.remove(opt.id) }
            else { motivation.insert(opt.id) }
        } label: {
            HStack {
                Image(systemName: motivation.contains(opt.id) ? "checkmark.square.fill" : "square")
                Text(opt.text).foregroundColor(.primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(motivation.contains(opt.id) ? .isSelected : [])
    }
}

// MARK: - Cloze con word bank

private struct ClozeWordBankView: View {
    let question: Question
    @Binding var filled: [Int:String]

    @State private var bankOrder: [String] = []

    private var blanks: [Blank] { question.blanks ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Testo con i buchi sostituiti dalla parola scelta (o un segnaposto vuoto).
            Text(renderedText())
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // Un selettore per ogni buco, popolato dalla word bank.
            ForEach(blanks) { blank in
                HStack {
                    Text("Spazio \(blank.id + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Button("—") { filled[blank.id] = nil }
                        ForEach(options(for: blank.id), id: \.self) { word in
                            Button(word) { filled[blank.id] = word }
                        }
                    } label: {
                        Text(filled[blank.id]?.isEmpty == false ? filled[blank.id]! : "Scegli…")
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Spazio \(blank.id + 1), \(filled[blank.id]?.isEmpty == false ? filled[blank.id]! : "vuoto")")
            }
        }
        .onAppear {
            if bankOrder.isEmpty {
                let bank = question.wordBank ?? []
                bankOrder = (question.shuffleWordBank ?? true) ? bank.shuffled() : bank
            }
        }
    }

    /// Parole disponibili per un buco: se `reuseWords` è falso, esclude quelle già usate altrove.
    private func options(for blankId: Int) -> [String] {
        guard question.reuseWords == false else { return bankOrder }
        let usedElsewhere = Set(filled.filter { $0.key != blankId }.values)
        return bankOrder.filter { !usedElsewhere.contains($0) }
    }

    private func renderedText() -> String {
        var s = question.text ?? ""
        for blank in blanks {
            let chosen = filled[blank.id]
            let value = (chosen?.isEmpty == false) ? "【\(chosen!)】" : "【______】"
            s = s.replacingOccurrences(of: "{{\(blank.id)}}", with: value)
        }
        return s
    }
}

// MARK: - Risposta breve

private struct ShortAnswerView: View {
    @Binding var text: String

    var body: some View {
        TextField("La tua risposta", text: $text, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityLabel("Campo risposta")
    }
}

// MARK: - Calcolo

private struct CalculationView: View {
    let question: Question
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let givens = question.givens, !givens.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dati").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(Array(givens.enumerated()), id: \.offset) { _, g in
                        Text("• \(g)").font(.callout)
                    }
                }
            }
            if let fmt = question.answerFormat, !fmt.isEmpty {
                Text("Formato atteso: \(fmt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField("Risultato", text: $text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .accessibilityLabel("Campo risultato")
        }
    }
}

// MARK: - Riordino

private struct OrderedView: View {
    let items: [String]
    @Binding var userOrder: [Int]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(userOrder.enumerated()), id: \.element) { pos, itemIndex in
                HStack(spacing: 10) {
                    Text("\(pos + 1).")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(items[itemIndex])
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    VStack(spacing: 2) {
                        Button { move(from: pos, by: -1) } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(pos == 0)
                        .accessibilityLabel("Sposta su")
                        Button { move(from: pos, by: 1) } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(pos == userOrder.count - 1)
                        .accessibilityLabel("Sposta giù")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            if userOrder.isEmpty { userOrder = initialOrder() }
        }
    }

    /// Ordine iniziale mescolato, evitando (se possibile) di partire già nell'ordine corretto.
    private func initialOrder() -> [Int] {
        let indices = Array(items.indices)
        guard indices.count > 1 else { return indices }
        var shuffled = indices.shuffled()
        var tries = 0
        while shuffled == indices && tries < 5 {
            shuffled = indices.shuffled()
            tries += 1
        }
        return shuffled
    }

    private func move(from pos: Int, by dir: Int) {
        let target = pos + dir
        guard target >= 0, target < userOrder.count else { return }
        userOrder.swapAt(pos, target)
    }
}

private struct MultipleView: View {
    let options: [Option]
    @Binding var selected: Set<Int>

    /// Ordine di visualizzazione mescolato (gli `id` restano invariati → valutazione sicura).
    @State private var shuffled: [Option] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(shuffled, id: \.id) { opt in
                HStack {
                    Button {
                        if selected.contains(opt.id) { selected.remove(opt.id) }
                        else { selected.insert(opt.id) }
                    } label: {
                        HStack {
                            Image(systemName: selected.contains(opt.id) ? "checkmark.square" : "square")
                            Text(opt.text)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
        }
        .onAppear {
            if shuffled.isEmpty { shuffled = options.shuffled() }
        }
    }
}

private struct MatchingView: View {
    let left: [String]
    let right: [String]
    @Binding var userPairs: [Int:Int]
    @Binding var rightOrder: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Sinistra").font(.caption).foregroundStyle(.secondary)
                    Text("Destra").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(left.enumerated()), id: \.offset) { (li, ltxt) in
                    GridRow {
                        Text(ltxt)
                        Picker("Abbina", selection: Binding(
                            get: { userPairs[li] ?? -1 },
                            set: { userPairs[li] = $0 }
                        )) {
                            Text("—").tag(-1)
                            ForEach(rightOrder.filter { $0 < right.count }, id: \.self) { ri in
                                Text(right[ri]).tag(ri)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        }
        .onAppear {
            if rightOrder.isEmpty {
                rightOrder = Array(right.indices).shuffled()
            }
        }
    }
}

private struct FeedbackBanner: View {
    let result: AnswerResult
    let question: Question?
    let detail: EvalDetail?
    
    var body: some View {
        // Card neutra con una sottile barra d'accento a sinistra: il colore è un accento, non
        // riempie ogni blocco. Un solo indicatore di esito, spiegazioni deduplicate.
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text(esitoText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(accentColor)
                } icon: {
                    Image(systemName: esitoIcon)
                        .foregroundColor(accentColor)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText)

                // Risposta corretta per domande sbagliate o incomplete.
                // Esclusi i tipi aperti: lì le opzioni corrette e la spiegazione sono già
                // mostrate dalle card del pool e dalla rubrica sopra.
                if result != .correct, let q = question, q.kind.isFormativeAnswer == false {
                    CorrectAnswerView(question: q)
                }

                // Passaggi attesi per le domande di calcolo (quando non è corretta)
                if result != .correct,
                   question?.kind == .calculation,
                   let steps = question?.expectedSteps, !steps.isEmpty {
                    stepsView(steps)
                }

                // Spiegazione una sola volta (deduplica risposta-V/F vs explanation del JSON)
                ForEach(Array(explanationsToShow.enumerated()), id: \.offset) { _, text in
                    explanationView(text)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var accentColor: Color {
        switch result {
        case .correct:    return .green
        case .incomplete: return .orange
        case .wrong:      return .red
        }
    }

    private var esitoIcon: String {
        switch result {
        case .correct:    return "checkmark.circle.fill"
        case .incomplete: return "exclamationmark.triangle.fill"
        case .wrong:      return "xmark.circle.fill"
        }
    }

    private var esitoText: String {
        switch result {
        case .correct:    return "Corretta"
        case .incomplete: return "Incompleta"
        case .wrong:      return "Sbagliata"
        }
    }

    /// Etichetta testuale per VoiceOver (senza emoji/affidamento al solo colore).
    private var accessibilityText: String {
        switch result {
        case .correct:    return "Risposta corretta"
        case .incomplete: return "Risposta incompleta"
        case .wrong:      return "Risposta sbagliata"
        }
    }

    /// Spiegazioni da mostrare, deduplicate: evita la doppia "Spiegazione" quando la spiegazione
    /// del V/F sbagliato e `question.explanation` coincidono o si sovrappongono.
    private var explanationsToShow: [String] {
        guard result != .correct else { return [] }
        // Per i tipi aperti la spiegazione vive già nella rubrica: niente doppione nel banner.
        if question?.kind.isFormativeAnswer == true { return [] }
        var out: [String] = []
        func add(_ raw: String?) {
            guard let s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return }
            if out.contains(where: { $0 == s || $0.contains(s) || s.contains($0) }) { return }
            out.append(s)
        }
        if result == .wrong, question?.kind == .trueFalseMotivated {
            add(question?.wrongAnswerExplanation)
        }
        add(question?.explanation)
        return out
    }

    private func explanationView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Spiegazione", systemImage: "lightbulb")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepsView(_ steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Procedimento", systemImage: "list.number")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                Text("\(i + 1). \(s)")
                    .font(.caption)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

// MARK: - Risposta corretta (riusabile da feedback singolo e sotto-domande)

private struct CorrectAnswerView: View {
    let question: Question

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Risposta corretta:")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            switch question.kind {
            case .multiple:
                if let options = question.options {
                    ForEach(options.filter { $0.isCorrect }, id: \.id) { option in
                        correctRow(option.text)
                    }
                }
            case .matching:
                if let leftOptions = question.left,
                   let rightOptions = question.right,
                   let matches = question.correctMatches {
                    ForEach(Array(matches.sorted(by: { $0.key < $1.key })), id: \.key) { left, right in
                        if left < leftOptions.count && right < rightOptions.count {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("\(leftOptions[left]) → \(rightOptions[right])")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }

            case .trueFalseMotivated:
                correctRow(question.answer == true ? "Vero" : "Falso")
                if let opts = question.motivationOptions {
                    ForEach(opts.filter { $0.isCorrect }, id: \.id) { o in
                        correctRow(o.text)
                    }
                }

            case .clozeWordBank:
                if let blanks = question.blanks {
                    ForEach(blanks) { b in
                        correctRow("Spazio \(b.id + 1): \(b.answers.first ?? "")")
                    }
                }

            case .shortAnswer, .calculation:
                ForEach(Array((question.acceptedAnswers ?? []).enumerated()), id: \.offset) { _, a in
                    correctRow(a)
                }

            case .ordered:
                if let items = question.items {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                        correctRow("\(i + 1). \(it)")
                    }
                }

            case .openRubric, .constructedResponse, .mediaAnalysis, .caseStudy:
                EmptyView() // gestiti con rubriche/sotto-feedback dedicati
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func correctRow(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Sezione con titolo e voci puntate (riusata dalle rubriche formative).
private func bulletSection(_ title: String, _ items: [String], icon: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundColor(color)
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            Text("• \(item)")
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

// MARK: - Risposta aperta (openRubric, formativo)

private struct OpenRubricView: View {
    let question: Question
    var poolShown: [PoolEntry]? = nil
    @Binding var poolSelected: Set<String>
    let revealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // La risposta si dà selezionando le affermazioni corrette (niente più testo libero).
            if let shown = poolShown {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quali tra queste affermazioni colgono i punti chiave?")
                        .font(.subheadline.weight(.semibold))
                    PoolSelectionView(shown: shown, selected: $poolSelected, revealed: revealed)
                }
            }

            if revealed {
                RubricView(question: question)
            }
        }
    }
}

/// Rubrica di autovalutazione mostrata dopo la risposta. Non finge una correzione automatica.
private struct RubricView: View {
    let question: Question

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Rubrica di autovalutazione", systemImage: "checklist")
                .font(.subheadline.weight(.semibold))
            Text("Confronta la tua risposta con i criteri qui sotto e valuta tu stesso.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let expected = question.expectedAnswer, !expected.isEmpty {
                bulletSection("Risposta attesa", [expected], icon: "text.alignleft", color: .blue)
            }
            if let kp = question.keyPoints, !kp.isEmpty {
                let title = question.minKeyPoints.map { "Punti chiave (almeno \($0))" } ?? "Punti chiave"
                bulletSection(title, kp, icon: "key", color: .green)
            }
            if let mistakes = question.commonMistakes, !mistakes.isEmpty {
                bulletSection("Errori comuni", mistakes, icon: "exclamationmark.triangle", color: .orange)
            }
            if let explanation = question.explanation, !explanation.isEmpty {
                bulletSection("Spiegazione", [explanation], icon: "lightbulb", color: .secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Produzione guidata (constructedResponse, formativo)

private struct ConstructedResponseView: View {
    let question: Question
    var poolShown: [PoolEntry]? = nil
    @Binding var poolSelected: Set<String>
    let revealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // La risposta si dà selezionando i requisiti corretti (niente più testo libero).
            if let shown = poolShown {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quali sono requisiti corretti per questa produzione?")
                        .font(.subheadline.weight(.semibold))
                    PoolSelectionView(shown: shown, selected: $poolSelected, revealed: revealed)
                }
            }

            if revealed {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Checklist di autovalutazione", systemImage: "checklist")
                        .font(.subheadline.weight(.semibold))

                    if let req = question.requiredCriteria, !req.isEmpty {
                        ChecklistView(title: "Requisiti obbligatori", items: req)
                    }
                    if let opt = question.optionalCriteria, !opt.isEmpty {
                        ChecklistView(title: "Requisiti facoltativi", items: opt)
                    }
                    if let errs = question.blockingErrors, !errs.isEmpty {
                        bulletSection("Errori bloccanti", errs, icon: "xmark.octagon", color: .red)
                    }
                    if let sol = question.sampleSolution, !sol.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Esempio di soluzione")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal) {
                                Text(sol)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(8)
                                    .background(Color(.tertiarySystemBackground))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

/// Checklist con spunte locali per l'autovalutazione (non registrate nelle statistiche).
private struct ChecklistView: View {
    let title: String
    let items: [String]
    @State private var checked = Set<Int>()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                Button {
                    if checked.contains(i) { checked.remove(i) } else { checked.insert(i) }
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: checked.contains(i) ? "checkmark.square.fill" : "square")
                        Text(item).font(.caption).foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(checked.contains(i) ? .isSelected : [])
            }
        }
    }
}

// MARK: - Caso di studio / Analisi media (compositi)

private struct CaseStudyView: View {
    let question: Question
    @Binding var inputs: [String: AnswerInput]
    let poolSamples: [String: [PoolEntry]]
    let revealed: Bool

    private var subquestions: [Question] { question.subquestions ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stimolo media primario (mediaAnalysis)
            if let media = question.media {
                MediaView(media: media)
            }
            // Stimoli comuni (caseStudy)
            if let stimuli = question.stimuli {
                ForEach(stimuli) { StimulusView(stimulus: $0) }
            }

            Divider()

            ForEach(Array(subquestions.enumerated()), id: \.element.id) { idx, sub in
                SubquestionCard(index: idx,
                                question: sub,
                                input: binding(for: sub.id),
                                poolShown: poolSamples[sub.id],
                                revealed: revealed)
            }
        }
    }

    private func binding(for id: String) -> Binding<AnswerInput> {
        Binding(get: { inputs[id] ?? AnswerInput() },
                set: { inputs[id] = $0 })
    }
}

/// Card di una singola sotto-domanda: testo, input e (dopo la verifica) feedback dedicato.
private struct SubquestionCard: View {
    let index: Int
    let question: Question
    @Binding var input: AnswerInput
    var poolShown: [PoolEntry]? = nil
    let revealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(index + 1). \(question.prompt)")
                .font(.subheadline.weight(.semibold))

            if let code = question.code, !code.isEmpty {
                ScrollView(.horizontal) {
                    Text(code)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                }
            }

            SubquestionInputView(question: question, input: $input, poolShown: poolShown, revealed: revealed)

            if revealed, !question.isFormative {
                subFeedback
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Risultato pool-aware (coerente con `resultForSub` nel motore di sessione).
    private var subResult: AnswerResult {
        guard poolShown != nil else { return evaluate(question, input: input) }
        let poolRes = evaluatePoolSelection(shown: poolShown ?? [], selected: input.poolSelected).result
        if question.kind == .trueFalseMotivated {
            return input.tfAnswer == question.answer ? poolRes : .wrong
        }
        return poolRes
    }

    @ViewBuilder
    private var subFeedback: some View {
        let result = subResult
        VStack(alignment: .leading, spacing: 6) {
            switch result {
            case .correct:    Text("✅ Corretta").font(.caption.weight(.semibold)).foregroundColor(.green)
            case .incomplete: Text("🟨 Incompleta").font(.caption.weight(.semibold)).foregroundColor(.orange)
            case .wrong:      Text("❌ Sbagliata").font(.caption.weight(.semibold)).foregroundColor(.red)
            }
            // Per il V/F sbagliato di una TF con pool, esplicita il valore corretto.
            if result == .wrong, poolShown != nil, question.kind == .trueFalseMotivated,
               input.tfAnswer != question.answer {
                Text("Valore corretto: \(question.answer == true ? "Vero" : "Falso")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            // Per i tipi non-pool mostra la risposta corretta tabellata.
            if result != .correct, poolShown == nil {
                CorrectAnswerView(question: question)
            }
            if result != .correct, let explanation = question.explanation, !explanation.isEmpty {
                Text(explanation).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Renderizza il controllo di input giusto per il tipo della sotto-domanda, riusando le view atomiche.
private struct SubquestionInputView: View {
    let question: Question
    @Binding var input: AnswerInput
    var poolShown: [PoolEntry]? = nil
    let revealed: Bool

    @State private var rightOrder: [Int] = []

    var body: some View {
        switch question.kind {
        case .multiple:
            MultipleView(options: question.options ?? [], selected: $input.selectedOptions)
        case .matching:
            MatchingView(left: question.left ?? [], right: question.right ?? [],
                         userPairs: $input.userPairs, rightOrder: $rightOrder)
        case .trueFalseMotivated:
            TrueFalseMotivatedView(question: question,
                                   answer: $input.tfAnswer,
                                   motivation: $input.tfMotivation,
                                   showMotivation: .constant(false),
                                   poolShown: poolShown,
                                   poolSelected: $input.poolSelected,
                                   revealed: revealed,
                                   singleStep: true)
        case .clozeWordBank:
            ClozeWordBankView(question: question, filled: $input.clozeFilled)
        case .shortAnswer:
            ShortAnswerView(text: $input.text)
        case .calculation:
            CalculationView(question: question, text: $input.text)
        case .ordered:
            OrderedView(items: question.items ?? [], userOrder: $input.userOrder)
        case .openRubric:
            OpenRubricView(question: question,
                           poolShown: poolShown, poolSelected: $input.poolSelected, revealed: revealed)
        case .constructedResponse:
            ConstructedResponseView(question: question,
                                    poolShown: poolShown, poolSelected: $input.poolSelected, revealed: revealed)
        case .mediaAnalysis, .caseStudy:
            EmptyView() // vietato annidare compositi (bloccato in validazione)
        }
    }
}

// MARK: - Multi-select sul campione del pool

private struct PoolSelectionView: View {
    let shown: [PoolEntry]
    @Binding var selected: Set<String>
    let revealed: Bool

    /// Stato di un'opzione una volta mostrata la soluzione.
    private enum Outcome {
        case correctSelected   // corretta e scelta
        case correctMissed     // corretta ma NON scelta (errore da evidenziare)
        case wrongSelected     // errata e scelta
        case wrongExcluded     // errata e correttamente esclusa (rumore, in secondo piano)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(shown) { entry in
                if revealed { solutionCard(entry) } else { selectableCard(entry) }
            }
        }
    }

    // MARK: - Stato "risposta" (card selezionabile)

    private func selectableCard(_ entry: PoolEntry) -> some View {
        let isSel = selected.contains(entry.id)
        return Button {
            if isSel { selected.remove(entry.id) } else { selected.insert(entry.id) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSel ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSel ? .accentColor : .secondary)
                Text(entry.displayText)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(isSel ? Color.accentColor.opacity(0.10) : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(isSel ? Color.accentColor.opacity(0.5) : Color(.separator).opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSel ? .isSelected : [])
        .accessibilityLabel("Opzione \(isSel ? "selezionata" : "non selezionata"): \(entry.displayText)")
    }

    // MARK: - Stato "soluzione" (card per stato, gerarchizzata)

    private func solutionCard(_ entry: PoolEntry) -> some View {
        let o = outcome(entry)
        let dimmed = (o == .wrongExcluded)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon(o))
                    .foregroundColor(tint(o))
                Text(entry.displayText)
                    .foregroundColor(dimmed ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Spiegazione solo se aggiunge informazione rispetto al testo dell'opzione.
            if let exp = meaningfulExplanation(entry) {
                Text(exp).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 28)
            }
            if let tag = tagText(o) {
                Text(tag)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(tint(o))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(tint(o).opacity(0.15), in: Capsule())
                    .padding(.leading, 28)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardFill(o), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(cardStroke(o), lineWidth: 1))
        .opacity(dimmed ? 0.6 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tagText(o) ?? "Esclusa correttamente"): \(entry.displayText)")
    }

    private func outcome(_ e: PoolEntry) -> Outcome {
        let isSel = selected.contains(e.id)
        switch (e.isCorrect, isSel) {
        case (true, true):   return .correctSelected
        case (true, false):  return .correctMissed
        case (false, true):  return .wrongSelected
        case (false, false): return .wrongExcluded
        }
    }

    /// Colore d'accento per stato. La corretta mancata usa il "warning" dell'app (giallo/arancio).
    private func tint(_ o: Outcome) -> Color {
        switch o {
        case .correctSelected: return .green
        case .correctMissed:   return QuizTheme.Colors.warning
        case .wrongSelected:   return .red
        case .wrongExcluded:   return .secondary
        }
    }

    private func icon(_ o: Outcome) -> String {
        switch o {
        case .correctSelected: return "checkmark.circle.fill"
        case .correctMissed:   return "exclamationmark.circle.fill"
        case .wrongSelected:   return "xmark.circle.fill"
        case .wrongExcluded:   return "circle"
        }
    }

    private func tagText(_ o: Outcome) -> String? {
        switch o {
        case .correctSelected: return "La tua scelta · corretta"
        case .correctMissed:   return "Mancata · andava selezionata"
        case .wrongSelected:   return "La tua scelta · errata"
        case .wrongExcluded:   return nil
        }
    }

    private func cardFill(_ o: Outcome) -> Color {
        switch o {
        case .correctSelected: return Color.green.opacity(0.12)
        case .correctMissed:   return QuizTheme.Colors.warning.opacity(0.14)
        case .wrongSelected:   return Color.red.opacity(0.12)
        case .wrongExcluded:   return Color(.secondarySystemBackground)
        }
    }

    private func cardStroke(_ o: Outcome) -> Color {
        switch o {
        case .correctSelected: return Color.green.opacity(0.45)
        case .correctMissed:   return QuizTheme.Colors.warning.opacity(0.5)
        case .wrongSelected:   return Color.red.opacity(0.45)
        case .wrongExcluded:   return Color(.separator).opacity(0.4)
        }
    }

    /// Restituisce la spiegazione solo se non è (in sostanza) una ripetizione del testo dell'opzione.
    private func meaningfulExplanation(_ e: PoolEntry) -> String? {
        guard let raw = e.explanation?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let a = raw.lowercased(), b = e.displayText.lowercased()
        if b.contains(a) || a.contains(b) { return nil }
        return raw
    }
}

// MARK: - Stimolo e media

private struct StimulusView: View {
    let stimulus: Stimulus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = stimulus.title, !title.isEmpty {
                Text(title).font(.subheadline.weight(.semibold))
            }
            if let media = stimulus.media {
                MediaView(media: media)
            }
            if let code = stimulus.code, !code.isEmpty {
                ScrollView(.horizontal) {
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }
            if let text = stimulus.text, !text.isEmpty {
                Text(text).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MediaView: View {
    let media: MediaAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
            if let caption = media.caption, !caption.isEmpty {
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(media.alt ?? media.caption ?? "Contenuto multimediale")
    }

    @ViewBuilder
    private var content: some View {
        switch media.type {
        case .image:
            ZoomableImage(image: localImage, remoteURL: remoteURL, alt: media.alt)
        case .video:
            if let url = resolvedURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 220)
                    .cornerRadius(10)
            } else { unavailable }
        case .audio:
            if let url = resolvedURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 80)
                    .cornerRadius(10)
            } else { unavailable }
        case .document:
            if let url = resolvedURL {
                Link(destination: url) {
                    Label(media.caption ?? "Apri documento", systemImage: "doc.text")
                }
            } else { unavailable }
        }
    }

    private var unavailable: some View {
        Label("Contenuto non disponibile", systemImage: "exclamationmark.triangle")
            .font(.caption).foregroundStyle(.secondary)
    }

    private var remoteURL: URL? {
        guard let u = media.url, !u.isEmpty else { return nil }
        return URL(string: u)
    }

    /// Immagine locale (cartella Documents o bundle).
    private var localImage: UIImage? {
        MediaResolver.localImage(named: media.asset)
    }

    private var resolvedURL: URL? {
        remoteURL ?? MediaResolver.localFileURL(named: media.asset)
    }
}

/// Risolve gli asset locali indicati per nome file (Documents o bundle).
enum MediaResolver {
    static func localFileURL(named name: String?) -> URL? {
        guard let name, !name.isEmpty else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if let f = docs?.appendingPathComponent(name), FileManager.default.fileExists(atPath: f.path) {
            return f
        }
        return Bundle.main.url(forResource: name, withExtension: nil)
    }

    static func localImage(named name: String?) -> UIImage? {
        guard let name, !name.isEmpty else { return nil }
        if let img = UIImage(named: name) { return img }
        if let url = localFileURL(named: name), let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
}

/// Immagine con pinch-to-zoom e doppio tap per reset; usa l'asset locale o `AsyncImage` per il remoto.
private struct ZoomableImage: View {
    let image: UIImage?
    let remoteURL: URL?
    let alt: String?

    @State private var scale: CGFloat = 1

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if let remoteURL {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFit()
                    case .failure:
                        Label("Immagine non caricata", systemImage: "photo")
                            .font(.caption).foregroundStyle(.secondary)
                    default:
                        ProgressView()
                    }
                }
            } else {
                Label("Immagine non disponibile", systemImage: "photo")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: 280)
        .scaleEffect(scale)
        .gesture(MagnificationGesture().onChanged { scale = max(1, min($0, 4)) })
        .onTapGesture(count: 2) { withAnimation { scale = scale > 1 ? 1 : 2 } }
        .clipped()
        .cornerRadius(10)
        .accessibilityLabel(alt ?? "Immagine")
        .accessibilityHint("Pizzica per ingrandire, doppio tap per ripristinare")
    }
}
