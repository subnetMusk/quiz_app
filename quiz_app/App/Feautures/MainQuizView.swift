//
//  MainQuizView.swift
//  quiz_app
//
//  Tab "Quiz": scelta della modalità di ripasso e avvio della sessione.
//

import SwiftUI

struct MainQuizView: View {
    @ObservedObject var app: AppStore
    @State private var selectedCategory: String? = nil
    @State private var selectedScale: Scale = .count(10)
    @State private var quizMode: QuizMode = .smart

    enum QuizMode: String, CaseIterable, Identifiable {
        case smart = "Ripasso intelligente"
        case general = "Ripasso generale"
        case category = "Per categoria"
        case errors = "Ripasso errori"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .smart:    return "sparkles"
            case .general:  return "book.fill"
            case .category: return "folder.fill"
            case .errors:   return "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .smart:    return QuizTheme.Colors.modeSmart
            case .general:  return QuizTheme.Colors.modeGeneral
            case .category: return QuizTheme.Colors.modeCategory
            case .errors:   return QuizTheme.Colors.modeErrors
            }
        }
    }

    private let modeColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        Group {
            if let materia = app.activeMateria {
                ScrollView {
                    VStack(alignment: .leading, spacing: QuizTheme.Spacing.xl) {
                        header(materia)
                        modeGrid(materia)
                        configurationSection(materia)
                    }
                    .padding()
                }
                .background(QuizTheme.Colors.background)
                .safeAreaInset(edge: .bottom) {
                    startButton(materia)
                        .padding(.horizontal)
                        .padding(.vertical, QuizTheme.Spacing.sm)
                        .background(.bar)
                }
            } else {
                ContentUnavailableView {
                    Label("Nessuna materia attiva", systemImage: "brain.head.profile")
                } description: {
                    Text("Importa o seleziona una materia dal tab Materie per allenarti.")
                }
            }
        }
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private func header(_ materia: Materia) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(materia.meta.subject_name)
                .font(.title2.bold())
                .lineLimit(2)
            Text("\(materia.questions.count) domande · \(materia.taxonomy.count) categorie")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func modeGrid(_ materia: Materia) -> some View {
        VStack(alignment: .leading, spacing: QuizTheme.Spacing.md) {
            SectionHeader(title: "Modalità")
            LazyVGrid(columns: modeColumns, spacing: QuizTheme.Spacing.md) {
                ForEach(QuizMode.allCases) { mode in
                    ModeCard(title: mode.rawValue,
                             systemImage: mode.icon,
                             subtitle: subtitle(for: mode, materia: materia),
                             tint: mode.tint,
                             isSelected: quizMode == mode) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            quizMode = mode
                            if mode != .category { selectedCategory = nil }
                        }
                    }
                }
            }
        }
    }

    private func configurationSection(_ materia: Materia) -> some View {
        VStack(alignment: .leading, spacing: QuizTheme.Spacing.md) {
            SectionHeader(title: "Configurazione")

            VStack(alignment: .leading, spacing: QuizTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: QuizTheme.Spacing.sm) {
                    Text("Numero di domande").font(.subheadline.weight(.medium))
                    HStack(spacing: QuizTheme.Spacing.sm) {
                        ForEach(scales(for: quizMode, materia: materia), id: \.description) { scale in
                            scaleChip(scale)
                        }
                    }
                }

                if quizMode == .category {
                    VStack(alignment: .leading, spacing: QuizTheme.Spacing.sm) {
                        Text("Categoria").font(.subheadline.weight(.medium))
                        Menu {
                            ForEach(materia.taxonomy, id: \.id) { node in
                                Button(node.name) { selectedCategory = node.id }
                            }
                        } label: {
                            HStack {
                                Text(selectedCategory.map { categoryName(for: $0, in: materia) } ?? "Seleziona categoria")
                                    .foregroundStyle(selectedCategory == nil ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(QuizTheme.Colors.background, in: RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.sm))
                        }
                    }
                }
            }
            .card()
        }
    }

    private func scaleChip(_ scale: Scale) -> some View {
        let isSelected = selectedScale.description == scale.description
        return Button {
            selectedScale = scale
        } label: {
            Text(scale.description)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, QuizTheme.Spacing.lg)
                .padding(.vertical, QuizTheme.Spacing.sm)
                .background(isSelected ? quizMode.tint : QuizTheme.Colors.background, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func startButton(_ materia: Materia) -> some View {
        NavigationLink {
            QuizView(materia: materia,
                     stats: app.statsStore ?? StudyDataStore(subjectId: materia.meta.subject_id),
                     mode: sessionMode(quizMode),
                     category: quizMode == .category ? selectedCategory : nil,
                     count: selectedScale.value(for: materia, mode: sessionMode(quizMode), category: selectedCategory))
        } label: {
            Label("Avvia quiz", systemImage: "play.fill")
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: quizMode.tint, enabled: canStart))
        .disabled(!canStart)
    }

    // MARK: - Helpers

    private func sessionMode(_ mode: QuizMode) -> QuizSessionMode {
        switch mode {
        case .smart:    return .smart
        case .general:  return .generic
        case .category: return .byCategory
        case .errors:   return .errors
        }
    }

    private func subtitle(for mode: QuizMode, materia: Materia) -> String {
        switch mode {
        case .smart:
            let due = app.statsStore?.dueCount() ?? 0
            return due > 0 ? "\(due) in scadenza" : "Ottimizzato (SM-2)"
        case .general:
            return "\(materia.questions.count) domande"
        case .category:
            return "\(materia.taxonomy.count) categorie"
        case .errors:
            let errs = app.statsStore?.topWrong(limit: 1).count ?? 0
            return errs > 0 ? "Ripassa gli errori" : "Nessun errore"
        }
    }

    private func scales(for mode: QuizMode, materia: Materia) -> [Scale] {
        switch mode {
        case .smart, .general: return materia.config.scales_questions
        case .category:        return materia.config.scales_category
        case .errors:          return materia.config.scales_errors
        }
    }

    private func categoryName(for id: String, in materia: Materia) -> String {
        materia.displayName(forCategory: id, sub: nil)
    }

    private var canStart: Bool {
        guard app.activeMateria != nil else { return false }
        switch quizMode {
        case .smart, .general: return true
        case .category:        return selectedCategory != nil
        case .errors:          return (app.statsStore?.topWrong(limit: 1).count ?? 0) > 0
        }
    }
}

#Preview {
    NavigationStack {
        MainQuizView(app: AppStore())
    }
}
