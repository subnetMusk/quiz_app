//
//  TheoryView.swift
//  quiz_app
//
//  Sezione "Teoria": notebook per argomento e avvio del quiz mirato.
//

import SwiftUI

struct TheoryView: View {
    @ObservedObject var app: AppStore

    var body: some View {
        Group {
            if let materia = app.activeMateria {
                let notes = notesByCategory(materia)
                let store = app.statsStore ?? StudyDataStore(subjectId: materia.meta.subject_id)
                let seen = store.seenQuestionIds()
                ScrollView {
                    VStack(alignment: .leading, spacing: QuizTheme.Spacing.lg) {
                        if let rec = recommended(materia, notes: notes, seen: seen) {
                            heroCard(materia: materia, store: store, node: rec,
                                     note: notes[rec.id], coverage: coverage(rec.id, materia, seen))
                        }

                        SectionHeader(title: "Argomenti")
                        ForEach(materia.taxonomy, id: \.id) { node in
                            NavigationLink {
                                TheoryDetailView(materia: materia, stats: store,
                                                 category: node, note: notes[node.id])
                            } label: {
                                TopicCard(node: node,
                                          note: notes[node.id],
                                          questionCount: materia.questions(category: node.id).count,
                                          coverage: coverage(node.id, materia, seen))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .background(QuizTheme.Colors.background)
            } else {
                ContentUnavailableView {
                    Label("Nessuna materia attiva", systemImage: "book.closed")
                } description: {
                    Text("Seleziona una materia per leggere i notebook di teoria.")
                }
            }
        }
        .navigationTitle("Teoria")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Hero "continua / inizia da qui"

    @ViewBuilder
    private func heroCard(materia: Materia, store: StudyDataStore, node: Materia.Node,
                          note: TheoryNote?, coverage: Double) -> some View {
        NavigationLink {
            if let note, note.sections?.isEmpty == false {
                GuidedStudyView(materia: materia, stats: store, note: note)
            } else {
                TheoryDetailView(materia: materia, stats: store, category: node, note: note)
            }
        } label: {
            VStack(alignment: .leading, spacing: QuizTheme.Spacing.md) {
                Label(coverage > 0 ? "Continua a studiare" : "Inizia da qui", systemImage: "graduationcap.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(node.name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Label("Percorso guidato", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(coverage * 100))%")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(QuizTheme.Colors.modeSmart, in: RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.lg))
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private func notesByCategory(_ materia: Materia) -> [String: TheoryNote] {
        Dictionary((materia.theory ?? []).map { ($0.categoryId, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func coverage(_ catId: String, _ materia: Materia, _ seen: Set<String>) -> Double {
        let qs = materia.questions(category: catId)
        guard !qs.isEmpty else { return 0 }
        return Double(qs.filter { seen.contains($0.id) }.count) / Double(qs.count)
    }

    /// Argomento consigliato: con teoria a sezioni e copertura più bassa (per spingere a completarlo).
    private func recommended(_ materia: Materia, notes: [String: TheoryNote], seen: Set<String>) -> Materia.Node? {
        materia.taxonomy
            .filter { (notes[$0.id]?.sections?.isEmpty == false) && !materia.questions(category: $0.id).isEmpty }
            .min { coverage($0.id, materia, seen) < coverage($1.id, materia, seen) }
    }
}

// MARK: - Card argomento + anello di progresso

private struct TopicCard: View {
    let node: Materia.Node
    let note: TheoryNote?
    let questionCount: Int
    let coverage: Double

    var body: some View {
        HStack(spacing: QuizTheme.Spacing.md) {
            ProgressRing(progress: coverage, tint: note == nil ? .secondary : QuizTheme.Colors.primary)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let summary = note?.intro?.replacingOccurrences(of: "**", with: ""), !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: QuizTheme.Spacing.sm) {
                    if let n = note?.sections?.count, n > 0 {
                        Label("\(n) sezioni", systemImage: "list.bullet")
                    }
                    Label("\(questionCount) domande", systemImage: "questionmark.circle")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding()
        .background(QuizTheme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.lg)
            .stroke(QuizTheme.Colors.cardBorder.opacity(0.4), lineWidth: 1))
    }
}

private struct ProgressRing: View {
    let progress: Double
    var tint: Color = .accentColor

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))")
                .font(.caption2.bold().monospacedDigit())
                .foregroundStyle(tint)
        }
    }
}

struct TheoryDetailView: View {
    let materia: Materia
    let stats: StudyDataStore
    let category: Materia.Node
    let note: TheoryNote?

    private var categoryQuestions: [Question] {
        materia.questions(category: category.id)
    }

    private var topicCandidates: [Question] {
        materia.topicPrimaryCandidates(category: category.id, wrongCounts: stats.wrongCounts())
    }

    var body: some View {
        Group {
            if let note {
                ScrollView {
                    VStack(alignment: .leading, spacing: QuizTheme.Spacing.xl) {
                        header(note)
                        markdownBody(note.body)
                    }
                    .padding()
                }
                .background(QuizTheme.Colors.background)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: QuizTheme.Spacing.sm) {
                        if note.sections?.isEmpty == false {
                            NavigationLink {
                                GuidedStudyView(materia: materia, stats: stats, note: note)
                            } label: {
                                Label("Studia (guidato)", systemImage: "graduationcap.fill")
                            }
                            .buttonStyle(PrimaryActionButtonStyle(tint: QuizTheme.Colors.modeSmart))
                            secondaryTrainingCTA
                        } else {
                            trainingCTA
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, QuizTheme.Spacing.sm)
                    .background(.bar)
                }
            } else {
                ContentUnavailableView {
                    Label("Notebook non disponibile", systemImage: "book.closed")
                } description: {
                    Text("Non è ancora stata aggiunta teoria per questo argomento.")
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ note: TheoryNote) -> some View {
        VStack(alignment: .leading, spacing: QuizTheme.Spacing.sm) {
            Text(note.title)
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: QuizTheme.Spacing.sm) {
                if let minutes = note.estimatedMinutes {
                    StatPill(text: "\(minutes) min", systemImage: "clock", tint: QuizTheme.Colors.info)
                }
                StatPill(text: "\(categoryQuestions.count) domande", systemImage: "questionmark.circle", tint: QuizTheme.Colors.primary)
                StatPill(text: "\(topicCandidates.count) chiave", systemImage: "target", tint: QuizTheme.Colors.success)
            }
        }
        .card()
    }

    @ViewBuilder
    private func markdownBody(_ body: String) -> some View {
        TheoryMarkdownView(markdown: body, dropTitle: note?.title).card()
    }

    private var trainingCTA: some View {
        NavigationLink {
            QuizView(materia: materia,
                     stats: stats,
                     mode: .topicPrimary,
                     category: category.id,
                     count: max(1, topicCandidates.count))
        } label: {
            Label("Allenati su questo argomento", systemImage: "play.fill")
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: QuizTheme.Colors.modeSmart, enabled: !topicCandidates.isEmpty))
        .disabled(topicCandidates.isEmpty)
    }

    /// Variante secondaria (quando è già presente la CTA "Studia guidato").
    private var secondaryTrainingCTA: some View {
        NavigationLink {
            QuizView(materia: materia, stats: stats, mode: .topicPrimary,
                     category: category.id, count: max(1, topicCandidates.count))
        } label: {
            Label("Allenati sulle domande chiave", systemImage: "target")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(QuizTheme.Colors.primary)
        .disabled(topicCandidates.isEmpty)
    }
}

// MARK: - Modalità studio guidata (intro → teoria → domande → … a difficoltà crescente)

struct GuidedStudyView: View {
    let materia: Materia
    let stats: StudyDataStore
    let note: TheoryNote

    @Environment(\.dismiss) private var dismiss
    @State private var stepIndex = 0

    private struct Step: Identifiable {
        enum Kind { case intro, theory, quiz, done }
        let id = UUID()
        let kind: Kind
        let section: TheorySection?
    }

    private var sections: [TheorySection] { note.sections ?? [] }

    /// Domande di una sezione, ordinate per difficoltà crescente.
    private func questions(for section: TheorySection) -> [Question] {
        materia.questions
            .filter { $0.category == note.categoryId && $0.sectionId == section.id }
            .sorted { ($0.difficulty ?? 1) < ($1.difficulty ?? 1) }
    }

    private var steps: [Step] {
        var result: [Step] = [Step(kind: .intro, section: nil)]
        for sec in sections {
            result.append(Step(kind: .theory, section: sec))
            if !questions(for: sec).isEmpty {
                result.append(Step(kind: .quiz, section: sec))
            }
        }
        result.append(Step(kind: .done, section: nil))
        return result
    }

    var body: some View {
        let steps = self.steps
        let current = steps[min(stepIndex, steps.count - 1)]
        return VStack(spacing: 0) {
            ProgressView(value: Double(stepIndex + 1), total: Double(steps.count))
                .tint(QuizTheme.Colors.modeSmart)
                .padding(.horizontal)
                .padding(.top, QuizTheme.Spacing.sm)

            content(for: current, totalSteps: steps.count)
        }
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder
    private func content(for step: Step, totalSteps: Int) -> some View {
        switch step.kind {
        case .intro:
            introStep
        case .theory:
            if let sec = step.section { theoryStep(sec) }
        case .quiz:
            if let sec = step.section {
                QuizView(materia: materia,
                         stats: stats,
                         mode: .topicPrimary,
                         category: note.categoryId,
                         count: questions(for: sec).count,
                         presetQuestions: questions(for: sec),
                         onComplete: { advance() })
                    .id(sec.id)   // forza una sessione fresca per ogni sezione
            }
        case .done:
            doneStep
        }
    }

    private func advance() {
        withAnimation { stepIndex = min(stepIndex + 1, steps.count - 1) }
    }

    // MARK: Step views

    private var introStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QuizTheme.Spacing.lg) {
                Label("Percorso guidato", systemImage: "graduationcap.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(QuizTheme.Colors.modeSmart)
                Text(note.title).font(.title.bold())
                if let intro = note.intro, !intro.isEmpty {
                    TheoryMarkdownView(markdown: intro)
                }
                if !sections.isEmpty {
                    VStack(alignment: .leading, spacing: QuizTheme.Spacing.sm) {
                        Text("Tappe del percorso").font(.headline)
                        ForEach(Array(sections.enumerated()), id: \.element.id) { i, sec in
                            HStack(alignment: .firstTextBaseline, spacing: QuizTheme.Spacing.sm) {
                                Text("\(i + 1)")
                                    .font(.caption.bold().monospaced())
                                    .frame(width: 22, height: 22)
                                    .background(QuizTheme.Colors.modeSmart.opacity(0.15), in: Circle())
                                Text(sec.title).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .card()
                }
            }
            .padding()
        }
        .background(QuizTheme.Colors.background)
        .safeAreaInset(edge: .bottom) {
            ctaBar(title: "Inizia", systemImage: "play.fill", action: advance)
        }
    }

    private func theoryStep(_ section: TheorySection) -> some View {
        let qs = questions(for: section)
        return ScrollView {
            VStack(alignment: .leading, spacing: QuizTheme.Spacing.md) {
                Text(section.title).font(.title2.bold())
                TheoryMarkdownView(markdown: section.body).card()
            }
            .padding()
        }
        .background(QuizTheme.Colors.background)
        .safeAreaInset(edge: .bottom) {
            ctaBar(title: qs.isEmpty ? "Continua" : "Mettiti alla prova",
                   systemImage: qs.isEmpty ? "arrow.right" : "checkmark.circle.fill",
                   action: advance)
        }
    }

    private var doneStep: some View {
        ScrollView {
            VStack(spacing: QuizTheme.Spacing.md) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(QuizTheme.Colors.success)
                Text("Argomento completato!").font(.title2.bold())
                Text("Hai letto la teoria e risposto alle domande di \(note.title).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
            .padding()
        }
        .background(QuizTheme.Colors.background)
        .safeAreaInset(edge: .bottom) {
            ctaBar(title: "Torna alla teoria", systemImage: "book.closed") { dismiss() }
        }
    }

    private func ctaBar(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: QuizTheme.Colors.modeSmart))
        .padding(.horizontal)
        .padding(.vertical, QuizTheme.Spacing.sm)
        .background(.bar)
    }
}

// MARK: - Rendering markdown teoria (riusabile da notebook e modalità guidata)

/// Renderizza un corpo markdown a blocchi (heading, bullet, paragrafi) con gerarchia tipografica.
/// `AttributedString(markdown:)` da solo collassa i paragrafi e non gestisce heading/elenco.
struct TheoryMarkdownView: View {
    let markdown: String
    var dropTitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: QuizTheme.Spacing.md) {
            ForEach(MarkdownBlock.parse(markdown, droppingTitle: dropTitle)) { block in
                switch block.kind {
                case .h1:
                    Text(block.attributed).font(.title2.bold()).padding(.top, 4)
                case .h2:
                    Text(block.attributed).font(.title3.bold()).padding(.top, 4)
                case .h3:
                    Text(block.attributed).font(.headline)
                case .bullet:
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        Text(block.attributed).frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .paragraph:
                    Text(block.attributed)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Markdown a blocchi (heading / bullet / paragrafo)

private struct MarkdownBlock: Identifiable {
    enum Kind { case h1, h2, h3, bullet, paragraph }
    let id = UUID()
    let kind: Kind
    let text: String

    /// Inline markdown (**grassetto**, *corsivo*) preservando il testo; fallback al testo grezzo.
    var attributed: AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }

    /// Converte un corpo markdown in blocchi. Salta righe vuote (la spaziatura la dà il VStack) e,
    /// se richiesto, un `# Titolo` iniziale che duplicherebbe il titolo già mostrato nell'header.
    static func parse(_ body: String, droppingTitle title: String?) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        for raw in body.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("### ") {
                blocks.append(.init(kind: .h3, text: String(line.dropFirst(4))))
            } else if line.hasPrefix("## ") {
                blocks.append(.init(kind: .h2, text: String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                blocks.append(.init(kind: .h1, text: String(line.dropFirst(2))))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                blocks.append(.init(kind: .bullet, text: String(line.dropFirst(2))))
            } else {
                blocks.append(.init(kind: .paragraph, text: line))
            }
        }
        // Rimuove un eventuale H1 iniziale uguale al titolo del notebook (già in header).
        if let title, let first = blocks.first, first.kind == .h1,
           first.text.caseInsensitiveCompare(title) == .orderedSame {
            blocks.removeFirst()
        }
        return blocks
    }
}

#Preview {
    NavigationStack {
        TheoryView(app: AppStore())
    }
}
