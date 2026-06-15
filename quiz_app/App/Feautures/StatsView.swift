//
//  StatsView.swift
//  quiz_app
//
//  Created by Leonardo Soligo on 9/1/25.
//

import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var app: AppStore

    var body: some View {
        Group {
            if let materia = app.activeMateria, let stats = app.statsStore {
                let sessions = stats.recentSessions(limit: 30)
                List {
                    Section {
                        summaryRow(sessions: sessions)
                    }

                    if sessions.count >= 2 {
                        Section("Andamento") {
                            SessionTrendChart(sessions: sessions.reversed())
                        }
                    }

                    Section("Categorie") {
                        ForEach(materia.taxonomy, id: \.id) { cat in
                            NavigationLink {
                                CategoryStatsView(app: app, categoryId: cat.id)
                            } label: {
                                categoryRow(cat: cat, materia: materia, stats: stats)
                            }
                        }
                    }

                    Section("Top errori") {
                        let topIds = stats.topWrong(limit: 10)
                        if topIds.isEmpty {
                            Text("Nessun errore registrato. Ottimo lavoro!")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(topIds, id: \.self) { qid in
                                if let q = materia.questions.first(where: { $0.id == qid }) {
                                    NavigationLink {
                                        QuestionStatsView(app: app, question: q)
                                    } label: {
                                        QuestionRow(app: app, question: q)
                                    }
                                }
                            }
                        }
                    }

                    if !sessions.isEmpty {
                        Section("Sessioni recenti") {
                            ForEach(sessions.prefix(10), id: \.persistentModelID) { session in
                                SessionRow(session: session)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView {
                    Label("Nessuna statistica", systemImage: "chart.bar")
                } description: {
                    Text("Attiva una materia e completa una sessione per vedere i tuoi progressi.")
                }
            }
        }
        .navigationTitle("Statistiche")
    }

    // MARK: - Rows

    private func summaryRow(sessions: [StudySession]) -> some View {
        HStack(spacing: QuizTheme.Spacing.md) {
            MetricView(value: "\(Int(StudyMetrics.averageAccuracy(sessions) * 100))%",
                       label: "Precisione media", systemImage: "target", tint: QuizTheme.Colors.success)
            Divider()
            MetricView(value: "\(sessions.count)", label: "Sessioni", systemImage: "clock.arrow.circlepath")
            Divider()
            MetricView(value: "\(StudyMetrics.currentStreak(from: sessions))",
                       label: "Giorni di fila", systemImage: "flame.fill", tint: QuizTheme.Colors.warning)
        }
        .padding(.vertical, 4)
    }

    private func categoryRow(cat: Materia.Node, materia: Materia, stats: StudyDataStore) -> some View {
        let acc = categoryAccuracy(cat.id, materia: materia, stats: stats)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(cat.name).font(.body).lineLimit(1)
                Spacer()
                if acc.wrong > 0 {
                    StatPill(text: "\(acc.wrong)", systemImage: "xmark", tint: QuizTheme.Colors.error)
                }
            }
            HStack(spacing: 8) {
                ProgressView(value: acc.attempts > 0 ? acc.accuracy : 0)
                    .tint(acc.attempts > 0 ? QuizTheme.Colors.success : Color(.systemGray4))
                Text(acc.attempts > 0 ? "\(Int(acc.accuracy * 100))%" : "—")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text("\(countQuestions(in: cat.id, materia: materia)) domande")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    /// Precisione aggregata di una categoria (sulle domande affrontate).
    private func categoryAccuracy(_ catId: String, materia: Materia, stats: StudyDataStore)
    -> (accuracy: Double, attempts: Int, wrong: Int) {
        var attempts = 0, correct = 0, wrong = 0
        for q in materia.questions where q.category == catId {
            if let s = stats.questionStats(q.id) {
                attempts += s.attempts
                correct += s.correct
                wrong += s.wrong
            }
        }
        let acc = attempts > 0 ? Double(correct) / Double(attempts) : 0
        return (acc, attempts, wrong)
    }

    private func countQuestions(in category: String, materia: Materia) -> Int {
        materia.questions.filter { $0.category == category }.count
    }
}

// MARK: - Category detail

struct CategoryStatsView: View {
    @ObservedObject var app: AppStore
    let categoryId: String

    var body: some View {
        List {
            if let materia = app.activeMateria {
                Section(materia.displayName(forCategory: categoryId, sub: nil)) {
                    let qs = materia.questions.filter { $0.category == categoryId }
                    if qs.isEmpty {
                        Text("Nessuna domanda in questa categoria.").foregroundStyle(.secondary)
                    } else {
                        ForEach(qs, id: \.id) { q in
                            NavigationLink {
                                QuestionStatsView(app: app, question: q)
                            } label: {
                                QuestionRow(app: app, question: q)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Categoria")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Question detail

struct QuestionStatsView: View {
    @ObservedObject var app: AppStore
    let question: Question

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                questionHeader
                
                if let code = question.code, !code.isEmpty {
                    codeSection(code)
                }

                Divider().padding(.vertical, 6)

                if let s = app.statsStore?.questionStats(question.id) {
                    statsSection(s)
                    
                    if question.kind == .multiple, let opts = question.options {
                        optionsSection(s, opts)
                    } else if question.kind == .matching, let matches = question.correctMatches {
                        matchingSection(matches)
                    }
                } else {
                    Text("Nessuna statistica per questa domanda.")
                        .foregroundStyle(.secondary)
                }
                
                Spacer(minLength: 10)
            }
            .padding()
        }
        .navigationTitle("Dettaglio domanda")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Subviews
    
    private var questionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Domanda")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(question.prompt)
                .font(.headline)
        }
    }
    
    private func codeSection(_ code: String) -> some View {
        ScrollView(.horizontal) {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
        }
    }
    
    private func statsSection(_ s: QuestionStats) -> some View {
        HStack(spacing: 8) {
            BadgeCount(text: "Tentativi: \(s.attempts)", color: .gray.opacity(0.25), systemImage: "number")
            BadgeCount(text: "OK: \(s.correct)", color: .green.opacity(0.85), systemImage: "checkmark.circle.fill")
            BadgeCount(text: "Inc.: \(s.incomplete)", color: .yellow.opacity(0.85), systemImage: "exclamationmark.circle.fill")
            BadgeCount(text: "Err.: \(s.wrong)", color: .red.opacity(0.85), systemImage: "xmark.circle.fill")
        }
    }
    
    private func optionsSection(_ s: QuestionStats, _ opts: [Option]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Risposte e Statistiche")
                .font(.subheadline.weight(.semibold))
            
            ForEach(opts, id: \.id) { opt in
                optionRow(opt, stats: s.per_option?[opt.id] ?? OptionStats())
            }
        }
    }
    
    private func optionRow(_ opt: Option, stats: OptionStats) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: opt.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(opt.isCorrect ? .green : .red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(opt.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.body)
                    
                    Text(opt.isCorrect ? "RISPOSTA CORRETTA" : "RISPOSTA SBAGLIATA")
                        .font(.caption.weight(.bold))
                        .foregroundColor(opt.isCorrect ? .green : .red)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    if opt.isCorrect {
                        BadgeCount(text: "\(stats.missedCorrect)",
                                   color: .yellow.opacity(0.85),
                                   systemImage: "exclamationmark.triangle.fill")
                        Text("Non selezionata")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        BadgeCount(text: "\(stats.wrongSelected)",
                                   color: .red.opacity(0.85),
                                   systemImage: "xmark.octagon.fill")
                        Text("Selezionata per errore")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(backgroundFor(opt))
    }
    
    private func backgroundFor(_ opt: Option) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(opt.isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(opt.isCorrect ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
            )
    }
    
    private func matchingSection(_ matches: [Int: Int]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Accoppiamenti Corretti")
                .font(.subheadline.weight(.semibold))
            
            ForEach(Array(matches.sorted(by: { $0.key < $1.key })), id: \.key) { left, right in
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.green)
                    
                    if let leftOptions = question.left, let rightOptions = question.right,
                       left < leftOptions.count, right < rightOptions.count {
                        Text("\(leftOptions[left]) → \(rightOptions[right])")
                            .font(.body)
                    } else {
                        Text("Opzione \(left) → Opzione \(right)")
                            .font(.body)
                    }
                    Spacer()
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Rows & Badges

private struct QuestionRow: View {
    @ObservedObject var app: AppStore
    let question: Question

    var body: some View {
        let s = app.statsStore?.questionStats(question.id)
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(question.prompt)
                    .lineLimit(2)
                Text(question.kind.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                BadgeCount(text: "\(s?.wrong ?? 0)",
                           color: .red.opacity(0.85),
                           systemImage: "xmark.circle.fill")
                BadgeCount(text: "\(s?.incomplete ?? 0)",
                           color: .yellow.opacity(0.85),
                           systemImage: "exclamationmark.circle.fill")
                BadgeCount(text: "\(s?.correct ?? 0)",
                           color: .green.opacity(0.85),
                           systemImage: "checkmark.circle.fill")
            }
        }
    }
}

// MARK: - Storico sessioni

/// Grafico dell'andamento della precisione nelle sessioni (ordine cronologico).
private struct SessionTrendChart: View {
    let sessions: [StudySession]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Andamento precisione")
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                    LineMark(
                        x: .value("Sessione", index + 1),
                        y: .value("Precisione", session.accuracy * 100)
                    )
                    PointMark(
                        x: .value("Sessione", index + 1),
                        y: .value("Precisione", session.accuracy * 100)
                    )
                }
            }
            .chartYScale(domain: 0...100)
            .frame(height: 160)
        }
        .padding(.vertical, 4)
    }
}

private struct SessionRow: View {
    let session: StudySession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.date, format: .dateTime.day().month().hour().minute())
                    .font(.subheadline)
                Text(session.modeRaw)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.correct)/\(session.total)")
                    .font(.subheadline.monospaced())
                Text("\(Int(session.accuracy * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(session.accuracy >= 0.6 ? .green : .orange)
            }
        }
    }
}

private struct BadgeCount: View {
    let text: String
    let color: Color
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let sys = systemImage {
                Image(systemName: sys)
            }
            Text(text).font(.caption.monospaced())
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color)
        .foregroundColor(.white)
        .clipShape(Capsule())
    }
}
