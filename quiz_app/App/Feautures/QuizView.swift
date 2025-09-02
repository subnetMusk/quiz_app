//
//  QuizView.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//

import SwiftUI

/// Modalità della sessione (coerente con QuizSessionMode)
enum Mode {
    case generic                     // tutte casualmente
    case byCategory(String)          // id categoria
    case errors(Int)                 // top X errori globali
    case errorsByCategory(String)    // top X errori per categoria
}

struct QuizView: View {
    let materia: Materia
    let stats: StatsStore
    let mode: QuizSessionMode
    let category: String? // for byCategory modes
    let count: Int

    // Stato runtime
    @State private var items: [Question] = []
    @State private var index: Int = 0
    @State private var finished: Bool = false

    // Stato risposta corrente (multiple / matching)
    @State private var selectedOptions = Set<Int>()       // per multiple
    @State private var userPairs: [Int:Int] = [:]         // per matching
    @State private var feedback: AnswerResult? = nil
    @State private var feedbackDetail: EvalDetail? = nil
    @State private var currentQuestion: Question? = nil
    
    // Risultati della sessione corrente
    @State private var sessionResults: [(questionId: String, result: AnswerResult)] = []

    var body: some View {
        VStack(spacing: 0) {
            // Contenuto principale
            ScrollView {
                VStack(spacing: 16) {
                    header

                    if finished {
                        summaryView
                    } else if current != nil {
                        QuestionCard(question: current!,
                                     selectedOptions: $selectedOptions,
                                     userPairs: $userPairs)

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
            if !finished && current != nil {
                bottomButtons
            }
        }
        .navigationTitle(navigationTitle)
        .onAppear { buildSession() }
    }

    // MARK: - Bottom Buttons
    
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack(spacing: 16) {
                Button(action: verify) {
                    Text("Verifica")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(feedback != nil ? Color.gray.opacity(0.6) : Color.green)
                        .cornerRadius(12)
                }
                .disabled(feedback != nil)

                Button(action: next) {
                    Text("Avanti")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(feedback != nil ? Color.blue : Color.gray.opacity(0.6))
                        .cornerRadius(12)
                }
                .disabled(feedback == nil)
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
            return "📝 Riepilogo sessione"
        }
        return "Domanda \(index + 1) / \(items.count)"
    }

    private var header: some View {
        HStack {
            if let f = feedback {
                Text(feedbackText(for: f))
                    .font(.headline)
            } else {
                Text(materia.meta.subject_name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
    
    private func feedbackText(for result: AnswerResult) -> String {
        switch result {
        case .correct: return "✅ Corretta"
        case .incomplete: return "🟨 Incompleta"
        case .wrong: return "❌ Sbagliata"
        }
    }

    private var current: Question? {
        guard index < items.count else { return nil }
        return items[index]
    }

    private func buildSession() {
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
        }

        // 2) Campionamento (count)
        let chosen = Array(pool.shuffled().prefix(count))
        items = chosen
        index = 0
        finished = chosen.isEmpty
        sessionResults = [] // Reset dei risultati della sessione
        resetAnswerState()
    }

    private func resetAnswerState() {
        selectedOptions = []
        userPairs = [:]
        feedback = nil
        feedbackDetail = nil
        currentQuestion = nil
    }

    private func verify() {
        guard let q = current else { return }
        currentQuestion = q
        switch q.kind {
        case .multiple:
            let detail = evaluateMultiple(question: q, selected: selectedOptions)
            feedback = detail.result
            feedbackDetail = detail
            sessionResults.append((questionId: q.id, result: detail.result)) // Memorizza il risultato della sessione
            stats.applyDelta(for: q, detail: detail)
        case .matching:
            let res = evaluateMatching(question: q, userPairs: userPairs)
            feedback = res
            feedbackDetail = nil // matching non ha dettagli per ora
            sessionResults.append((questionId: q.id, result: res)) // Memorizza il risultato della sessione
            stats.applyDelta(for: q, result: res)
        }
    }

    private func next() {
        feedback = nil
        feedbackDetail = nil
        currentQuestion = nil
        index += 1
        if index >= items.count {
            finished = true
            // Forza il salvataggio delle statistiche al termine della sessione
            stats.forceSave()
        } else {
            resetAnswerState()
        }
    }

    // MARK: - Error ranking

    /// Top X errori globali
    private func questionsForTopErrors(limit: Int) -> [Question] {
        let topIds = stats.topWrong(limit: limit)
        let map = Dictionary(uniqueKeysWithValues: materia.questions.map { ($0.id, $0) })
        return topIds.compactMap { map[$0] }
    }

    /// Top X errori per categoria
    private func questionsForTopErrors(limit: Int, category: String) -> [Question] {
        // ordina per wrong desc nelle stats, filtrando per categoria
        let wrongByQ: [(String, Int)] = stats.stats.per_question
            .filter { (qid, _) in
                if let q = materia.questions.first(where: { $0.id == qid }) {
                    return q.category == category
                }
                return false
            }
            .map { ($0.key, $0.value.wrong) }
            .sorted { $0.1 > $1.1 }

        let ids = wrongByQ.prefix(limit).map { $0.0 }
        let map = Dictionary(uniqueKeysWithValues: materia.questions.map { ($0.id, $0) })
        let picked = ids.compactMap { map[$0] }
        // se meno di limit, riempi con casuali della stessa categoria
        if picked.count < limit {
            let remaining = materia.questions
                .filter { $0.category == category && !ids.contains($0.id) }
                .shuffled()
                .prefix(limit - picked.count)
            return picked + remaining
        }
        return picked
    }

    // MARK: - Summary

    private var summaryView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header del riepilogo
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Sessione Completata!")
                        .font(.title.bold())
                    
                    Text("Ecco come è andata la tua performance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                // Statistiche generali della sessione
                sessionStatsCard
                
                // Progress per categoria presente nella sessione
                VStack(alignment: .leading, spacing: 12) {
                    Text("Performance per Categoria")
                        .font(.headline.bold())
                    
                    // Solo se abbiamo risultati validi
                    if !sessionResults.isEmpty && sessionResults.count == items.count {
                        let sessionCats = Dictionary(grouping: items, by: { $0.category })
                        ForEach(sessionCats.keys.sorted(), id: \.self) { cat in
                            let categoryQuestions = sessionCats[cat] ?? []
                            let total = categoryQuestions.count
                            
                            // Calcola i risultati per questa categoria nella sessione corrente
                            let categoryResults = categoryQuestions.compactMap { question in
                                sessionResults.first { $0.questionId == question.id }
                            }
                            let correct = categoryResults.filter { $0.result == .correct }.count
                            
                            categoryProgressRow(category: cat, correct: correct, total: total)
                        }
                    } else {
                        Text("Statistiche per categoria non disponibili")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Azioni
                VStack(spacing: 12) {
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
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
                .padding(.bottom)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @Environment(\.presentationMode) var presentationMode
    
    private var sessionStatsCard: some View {
        let totalQuestions = items.count
        
        // Protezione: se sessionResults è vuoto o incompleto, mostra errore
        if sessionResults.isEmpty || sessionResults.count != totalQuestions {
            return AnyView(VStack(spacing: 16) {
                Text("Risultati Sessione")
                    .font(.headline.bold())
                Text("Errore nel calcolo delle statistiche")
                    .foregroundColor(.red)
                Text("Risultati: \(sessionResults.count)/\(totalQuestions)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12))
        }
        
        let correctAnswers = sessionResults.filter { $0.result == .correct }.count
        let incompleteAnswers = sessionResults.filter { $0.result == .incomplete }.count
        let wrongAnswers = sessionResults.filter { $0.result == .wrong }.count
        let accuracy = totalQuestions > 0 ? Double(correctAnswers) / Double(totalQuestions) * 100 : 0
        
        return AnyView(VStack(spacing: 16) {
            Text("Risultati Sessione")
                .font(.headline.bold())
            
            HStack(spacing: 20) {
                statBadge(title: "Corrette", value: "\(correctAnswers)", color: .green)
                if incompleteAnswers > 0 {
                    statBadge(title: "Incomplete", value: "\(incompleteAnswers)", color: .yellow)
                }
                statBadge(title: "Sbagliate", value: "\(wrongAnswers)", color: .red)
                statBadge(title: "Precisione", value: "\(Int(accuracy))%", color: .blue)
            }
            
            // Barra di progresso visuale
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(.green)
                        .frame(width: geometry.size.width * CGFloat(correctAnswers) / CGFloat(totalQuestions))
                    
                    if incompleteAnswers > 0 {
                        Rectangle()
                            .fill(.yellow)
                            .frame(width: geometry.size.width * CGFloat(incompleteAnswers) / CGFloat(totalQuestions))
                    }
                    
                    Rectangle()
                        .fill(.red)
                        .frame(width: geometry.size.width * CGFloat(wrongAnswers) / CGFloat(totalQuestions))
                }
            }
            .frame(height: 8)
            .background(Color(.systemGray5))
            .cornerRadius(4)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12))
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
                Text("\(correct)/\(total)")
                    .font(.subheadline.monospaced().weight(.semibold))
                    .foregroundStyle(correct == total ? .green : (correct == 0 ? .red : .orange))
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
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct MultipleView: View {
    let options: [Option]
    @Binding var selected: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(options, id: \.id) { opt in
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
        VStack(spacing: 8) {
            HStack {
                let (text, color): (String, Color) = {
                    switch result {
                    case .correct:    return ("✅ Corretta", .green)
                    case .incomplete: return ("🟨 Incompleta", .yellow)
                    case .wrong:      return ("❌ Sbagliata", .red)
                    }
                }()
                Text(text)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
            }
            
            // Mostra la risposta corretta per domande sbagliate o incomplete
            if result != .correct, let q = question {
                correctAnswerView(for: q)
            }
        }
        .padding(12)
        .background(backgroundForResult)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(strokeColor, lineWidth: 1))
        .cornerRadius(12)
    }
    
    private var backgroundForResult: Color {
        switch result {
        case .correct: return .green.opacity(0.15)
        case .incomplete: return .yellow.opacity(0.15)
        case .wrong: return .red.opacity(0.15)
        }
    }
    
    private var strokeColor: Color {
        switch result {
        case .correct: return .green
        case .incomplete: return .yellow
        case .wrong: return .red
        }
    }
    
    @ViewBuilder
    private func correctAnswerView(for question: Question) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Risposta corretta:")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            
            switch question.kind {
            case .multiple:
                if let options = question.options {
                    let correctOptions = options.filter { $0.isCorrect }
                    ForEach(correctOptions, id: \.id) { option in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(option.text)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
