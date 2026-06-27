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
                        summaryCard(sessions: sessions)
                    }

                    if sessions.count >= 2 {
                        Section("Andamento") {
                            SessionTrendChart(sessions: sessions.reversed())
                        }
                    }

                    Section("Argomenti") {
                        ForEach(materia.taxonomy, id: \.id) { cat in
                            NavigationLink {
                                CategoryStatsView(app: app, categoryId: cat.id)
                            } label: {
                                categoryRow(cat: cat, materia: materia, stats: stats)
                            }
                        }
                    }

                    Section("Ripasso suggerito") {
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

    private func summaryCard(sessions: [StudySession]) -> some View {
        let totalAnswers = sessions.reduce(0) { $0 + $1.total }
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                         spacing: QuizTheme.Spacing.md) {
            MetricView(value: "\(Int(StudyMetrics.averageAccuracy(sessions) * 100))%",
                       label: "Precisione media", systemImage: "target", tint: QuizTheme.Colors.success)
            MetricView(value: "\(sessions.count)", label: "Sessioni", systemImage: "clock.arrow.circlepath")
            MetricView(value: "\(StudyMetrics.currentStreak(from: sessions))",
                       label: "Giorni di fila", systemImage: "flame.fill", tint: QuizTheme.Colors.warning)
            MetricView(value: "\(totalAnswers)", label: "Risposte", systemImage: "checklist")
            MetricView(value: "\(sessions.reduce(0) { $0 + $1.wrong })",
                       label: "Errori", systemImage: "xmark.circle", tint: QuizTheme.Colors.error)
            MetricView(value: "\(sessions.reduce(0) { $0 + $1.incomplete })",
                       label: "Incomplete", systemImage: "exclamationmark.circle", tint: QuizTheme.Colors.warning)
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
                let qs = materia.questions.filter { $0.category == categoryId }
                Section {
                    categoryHeader(materia, questions: qs)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section("Domande") {
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
        .listStyle(.insetGrouped)
        .navigationTitle("Argomento")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Riepilogo dell'argomento: precisione media, copertura e composizione esiti.
    private func categoryHeader(_ materia: Materia, questions qs: [Question]) -> some View {
        let store = app.statsStore
        var attempts = 0, correct = 0, incomplete = 0, wrong = 0, seen = 0
        for q in qs {
            if let s = store?.questionStats(q.id) {
                attempts += s.attempts; correct += s.correct; incomplete += s.incomplete; wrong += s.wrong
                if s.attempts > 0 { seen += 1 }
            }
        }
        let acc = attempts > 0 ? Double(correct) / Double(attempts) : 0
        return VStack(alignment: .leading, spacing: QuizTheme.Spacing.md) {
            Text(materia.displayName(forCategory: categoryId, sub: nil))
                .font(.title3.bold())
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: QuizTheme.Spacing.lg) {
                MetricView(value: attempts > 0 ? "\(Int(acc * 100))%" : "—",
                           label: "Precisione", systemImage: "target",
                           tint: QuizTheme.Colors.success)
                MetricView(value: "\(seen)/\(qs.count)", label: "Affrontate",
                           systemImage: "checklist", tint: QuizTheme.Colors.info)
                MetricView(value: "\(wrong)", label: "Errori",
                           systemImage: "xmark.circle", tint: QuizTheme.Colors.error)
            }

            if attempts > 0 {
                ResultBar(correct: correct, incomplete: incomplete, wrong: wrong, height: 8)
            } else {
                Text("Nessuna risposta registrata per questo argomento.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(QuizTheme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.lg))
        .padding(.vertical, 4)
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
                    accuracySection(s)
                    
                    if question.kind == .multiple, let opts = question.options {
                        optionsSection(s, opts)
                    } else if question.kind == .matching, let matches = question.correctMatches {
                        matchingSection(matches)
                    } else if question.optionPool != nil, let store = app.statsStore {
                        poolDetailsSection(store)
                    } else {
                        Text("Per questo tipo di domanda non sono disponibili dettagli oltre ai conteggi aggregati.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
            BadgeCount(text: "Tentativi: \(s.attempts)", color: .gray.opacity(0.25), systemImage: "number")
            BadgeCount(text: "OK: \(s.correct)", color: .green.opacity(0.85), systemImage: "checkmark.circle.fill")
            BadgeCount(text: "Inc.: \(s.incomplete)", color: QuizTheme.Colors.warning.opacity(0.85), systemImage: "exclamationmark.circle.fill")
            BadgeCount(text: "Err.: \(s.wrong)", color: .red.opacity(0.85), systemImage: "xmark.circle.fill")
        }
    }

    private func accuracySection(_ s: QuestionStats) -> some View {
        let accuracy = s.attempts > 0 ? Double(s.correct) / Double(s.attempts) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Precisione")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(s.attempts > 0 ? "\(Int((accuracy * 100).rounded()))%" : "—")
                    .font(.subheadline.monospaced().weight(.semibold))
                    .foregroundStyle(accuracy >= 0.7 ? QuizTheme.Colors.success : QuizTheme.Colors.warning)
            }
            ProgressView(value: accuracy)
                .tint(accuracy >= 0.7 ? QuizTheme.Colors.success : QuizTheme.Colors.warning)
        }
        .padding(.vertical, 4)
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

    @ViewBuilder
    private func poolDetailsSection(_ store: StudyDataStore) -> some View {
        let concepts = store.conceptStats(question.id)
        let missed = concepts
            .filter { $0.value.missedCorrect > 0 }
            .sorted { $0.value.missedCorrect > $1.value.missedCorrect }
        let wrong = concepts
            .filter { $0.value.wrongSelected > 0 }
            .sorted { $0.value.wrongSelected > $1.value.wrongSelected }
        let variants = store.variantWrong(question.id)
            .sorted { $0.value > $1.value }

        if missed.isEmpty && wrong.isEmpty && variants.isEmpty {
            Text("Nessun dettaglio di errore registrato per il pool di questa domanda.")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            if !missed.isEmpty {
                poolConceptGroup(title: "Concetti mancati",
                                 systemImage: "exclamationmark.triangle.fill",
                                 tint: QuizTheme.Colors.warning,
                                 rows: missed,
                                 keyPath: \.missedCorrect,
                                 preferCorrect: true)
            }

            if !wrong.isEmpty {
                poolConceptGroup(title: "Distrattori scelti",
                                 systemImage: "xmark.octagon.fill",
                                 tint: QuizTheme.Colors.error,
                                 rows: wrong,
                                 keyPath: \.wrongSelected,
                                 preferCorrect: false)
            }

            if !variants.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tipi di trappola ricorrenti")
                        .font(.subheadline.weight(.semibold))

                    ForEach(variants, id: \.key) { raw, count in
                        HStack(alignment: .firstTextBaseline, spacing: QuizTheme.Spacing.sm) {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(QuizTheme.Colors.info)
                            Text(variantLabel(raw))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            BadgeCount(text: "\(count)", color: QuizTheme.Colors.info.opacity(0.85))
                        }
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func poolConceptGroup(title: String,
                                  systemImage: String,
                                  tint: Color,
                                  rows: [(key: String, value: ConceptStats)],
                                  keyPath: KeyPath<ConceptStats, Int>,
                                  preferCorrect: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            ForEach(rows, id: \.key) { id, stats in
                HStack(alignment: .top, spacing: QuizTheme.Spacing.sm) {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                        .padding(.top, 2)
                    Text(conceptText(id, preferCorrect: preferCorrect))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    BadgeCount(text: "\(stats[keyPath: keyPath])", color: tint.opacity(0.85))
                }
                .padding(10)
                .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.25), lineWidth: 1))
            }
        }
    }

    private func conceptText(_ id: String, preferCorrect: Bool) -> String {
        let entries = question.optionPool?.entries ?? []
        let preferred = entries.first { $0.canonicalPointId == id && $0.isCorrect == preferCorrect }
        let fallback = entries.first { $0.canonicalPointId == id }
        return (preferred ?? fallback)?.displayText ?? id
    }

    private func variantLabel(_ raw: String) -> String {
        switch PoolVariantKind(rawValue: raw) {
        case .correctParaphrase:    return "Parafrasi corretta"
        case .tooAbsolute:          return "Troppo assoluto"
        case .incomplete:           return "Incompleto"
        case .causalError:          return "Errore causale"
        case .relatedButIrrelevant: return "Correlato ma non pertinente"
        case .wrongScope:           return "Ambito sbagliato"
        case .oppositeDirection:    return "Direzione invertita"
        case .other:                return "Altro"
        case .none:                 return raw
        }
    }
}

// MARK: - Rows & Badges

private struct QuestionRow: View {
    @ObservedObject var app: AppStore
    let question: Question

    var body: some View {
        let s = app.statsStore?.questionStats(question.id)
        let attempts = s?.attempts ?? 0
        HStack(spacing: QuizTheme.Spacing.md) {
            MasteryBadge(stats: s)
            VStack(alignment: .leading, spacing: 5) {
                Text(question.prompt)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(question.kind.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if attempts > 0, let s {
                    ResultBar(correct: s.correct, incomplete: s.incomplete, wrong: s.wrong)
                } else {
                    Text("Mai affrontata")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Anello di padronanza: precisione (corrette/tentativi) con colore semaforico; grigio se mai vista.
private struct MasteryBadge: View {
    let stats: QuestionStats?

    var body: some View {
        let attempts = stats?.attempts ?? 0
        let acc = attempts > 0 ? Double(stats!.correct) / Double(attempts) : 0
        let color: Color = attempts == 0
            ? .secondary
            : (acc >= 0.8 ? QuizTheme.Colors.success : (acc >= 0.5 ? QuizTheme.Colors.warning : QuizTheme.Colors.error))
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: 4)
            if attempts > 0 {
                Circle()
                    .trim(from: 0, to: max(0.001, acc))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(acc * 100))")
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(color)
            } else {
                Image(systemName: "minus").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(width: 40, height: 40)
    }
}

/// Barra sottile con la composizione corrette/incomplete/sbagliate.
private struct ResultBar: View {
    let correct: Int
    let incomplete: Int
    let wrong: Int
    var height: CGFloat = 5

    var body: some View {
        let total = max(1, correct + incomplete + wrong)
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(QuizTheme.Colors.success)
                    .frame(width: geo.size.width * CGFloat(correct) / CGFloat(total))
                Rectangle().fill(QuizTheme.Colors.warning)
                    .frame(width: geo.size.width * CGFloat(incomplete) / CGFloat(total))
                Rectangle().fill(QuizTheme.Colors.error)
                    .frame(width: geo.size.width * CGFloat(wrong) / CGFloat(total))
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .background(Capsule().fill(Color(.systemGray5)))
        .accessibilityLabel("Corrette \(correct), incomplete \(incomplete), sbagliate \(wrong)")
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
