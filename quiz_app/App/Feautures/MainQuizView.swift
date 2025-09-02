//
//  MainQuizView.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//

import SwiftUI

struct MainQuizView: View {
    @ObservedObject var app: AppStore
    @State private var selectedCategory: String? = nil
    @State private var selectedScale: Scale = .count(10)
    @State private var quizMode: QuizMode = .general
    
    enum QuizMode: String, CaseIterable, Identifiable {
        case general = "Ripasso generale"
        case category = "Per categoria"
        case errors = "Ripasso errori"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .general: return "book.fill"
            case .category: return "folder.fill"
            case .errors: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .general: return .blue
            case .category: return .green
            case .errors: return .orange
            }
        }
    }
    
    var body: some View {
        Group {
            if let materia = app.activeMateria {
                VStack(spacing: 24) {
                    // Header con info materia
                    materiaHeader(materia)
                    
                    // Modalità quiz
                    VStack(spacing: 16) {
                        Text("Scegli modalità di ripasso")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(QuizMode.allCases) { mode in
                                quizModeCard(mode, materia: materia)
                            }
                        }
                    }
                    
                    // Configurazione quiz
                    configurationSection(materia)
                    
                    Spacer()
                    
                    // Pulsante avvia quiz
                    startQuizButton(materia)
                }
                .padding()
            } else {
                emptyStateView
            }
        }
        .navigationTitle("🧠 Quiz")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Subviews
    
    private func materiaHeader(_ materia: Materia) -> some View {
        VStack(spacing: QuizTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: QuizTheme.Spacing.xs) {
                    Text(materia.meta.subject_name)
                        .font(.system(size: responsiveTitleFont(for: materia.meta.subject_name), weight: .bold, design: .default))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.7)
                    
                    HStack(spacing: QuizTheme.Spacing.md) {
                        Label("\(materia.questions.count)", systemImage: "questionmark.circle")
                        Label("v\(materia.meta.version)", systemImage: "number.circle")
                        Label(materia.meta.subject_id.prefix(8), systemImage: "tag.circle")
                    }
                    .font(QuizTheme.Typography.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Quick stats
                StatsBadge(
                    "\(materia.taxonomy.count)",
                    label: "Categorie",
                    color: QuizTheme.Colors.info
                )
            }
            
            Divider()
        }
    }
    
    // Helper per calcolare il font size in base alla lunghezza del titolo
    private func responsiveTitleFont(for title: String) -> CGFloat {
        let baseSize: CGFloat = 28
        let minSize: CGFloat = 20
        
        // Se il titolo è lungo, riduci il font
        if title.count > 25 {
            return max(minSize, baseSize - 4)
        } else if title.count > 20 {
            return max(minSize, baseSize - 2)
        }
        
        return baseSize
    }
    
    private func quizModeCard(_ mode: QuizMode, materia: Materia) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                quizMode = mode
                if mode == .general {
                    selectedCategory = nil
                }
            }
        } label: {
            VStack(spacing: QuizTheme.Spacing.md) {
                Image(systemName: mode.icon)
                    .font(.system(size: 32))
                    .foregroundColor(quizMode == mode ? .white : mode.color)
                
                Text(mode.rawValue)
                    .font(QuizTheme.Typography.headline)
                    .foregroundColor(quizMode == mode ? .white : mode.color)
                    .multilineTextAlignment(.center)
                
                Text(subtitleFor(mode, materia: materia))
                    .font(QuizTheme.Typography.caption)
                    .foregroundColor(quizMode == mode ? .white.opacity(0.8) : mode.color.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(minHeight: 120)
            .frame(maxWidth: .infinity)
            .padding(QuizTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.md)
                    .fill(quizMode == mode ? mode.color : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.md)
                    .stroke(mode.color, lineWidth: quizMode == mode ? 0 : 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func configurationSection(_ materia: Materia) -> some View {
        VStack(spacing: 16) {
            Text("Configurazione")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                // Selezione numero domande
                VStack(alignment: .leading, spacing: 8) {
                    Text("Numero di domande")
                        .font(.subheadline.bold())
                    
                    let scales = scalesFor(quizMode, materia: materia)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(scales, id: \.description) { scale in
                                scaleButton(scale)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Selezione categoria (se applicabile)
                if quizMode == .category {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Categoria")
                            .font(.subheadline.bold())
                        
                        Menu {
                            ForEach(materia.taxonomy, id: \.id) { node in
                                Button(node.name) {
                                    selectedCategory = node.id
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedCategory.map { categoryName(for: $0, in: materia) } ?? "Seleziona categoria")
                                    .foregroundColor(selectedCategory == nil ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func scaleButton(_ scale: Scale) -> some View {
        Button {
            selectedScale = scale
        } label: {
            Text(scale.description)
                .font(.subheadline.bold())
                .foregroundColor(selectedScale.description == scale.description ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedScale.description == scale.description ? Color.accentColor : Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper functions
    
    private func quizModeToSessionMode(_ mode: QuizMode) -> QuizSessionMode {
        switch mode {
        case .general:
            return .generic
        case .category:
            return .byCategory
        case .errors:
            return .errors
        }
    }
    
    private func startQuizButton(_ materia: Materia) -> some View {
        NavigationLink {
            QuizView(
                materia: materia,
                stats: app.statsStore!,
                mode: quizModeToSessionMode(quizMode),
                category: quizMode == .category ? selectedCategory : nil,
                count: selectedScale.value(for: materia, mode: quizModeToSessionMode(quizMode), category: selectedCategory)
            )
        } label: {
            HStack(spacing: QuizTheme.Spacing.md) {
                Image(systemName: "play.fill")
                    .font(QuizTheme.Typography.title2)
                Text("Avvia Quiz")
                    .font(QuizTheme.Typography.title3)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.lg)
                    .fill(canStartQuiz ? QuizTheme.Colors.primary : QuizTheme.Colors.secondary)
            )
        }
        .disabled(!canStartQuiz)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "book.closed.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Nessuna materia caricata")
                    .font(.title2.bold())
                
                Text("Importa un file JSON dalla sidebar per iniziare a creare i tuoi quiz personalizzati")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper functions
    
    private func subtitleFor(_ mode: QuizMode, materia: Materia) -> String {
        switch mode {
        case .general:
            return "\(materia.questions.count) domande disponibili"
        case .category:
            return "\(materia.taxonomy.count) categorie disponibili"
        case .errors:
            let errorCount = app.statsStore?.topWrong(limit: 1).count ?? 0
            return errorCount > 0 ? "Ripassa gli errori più frequenti" : "Nessun errore registrato"
        }
    }
    
    private func scalesFor(_ mode: QuizMode, materia: Materia) -> [Scale] {
        switch mode {
        case .general:
            return materia.config.scales_questions
        case .category:
            return materia.config.scales_category
        case .errors:
            return materia.config.scales_errors
        }
    }
    
    private func categoryName(for id: String, in materia: Materia) -> String {
        materia.taxonomy.first { $0.id == id }?.name ?? id
    }
    
    private var canStartQuiz: Bool {
        guard app.activeMateria != nil else { return false }
        
        switch quizMode {
        case .general:
            return true
        case .category:
            return selectedCategory != nil
        case .errors:
            // Controlla se ci sono errori registrati
            return (app.statsStore?.topWrong(limit: 1).count ?? 0) > 0
        }
    }
}

#Preview {
    NavigationView {
        MainQuizView(app: AppStore())
    }
}
