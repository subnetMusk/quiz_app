//
//  TodayView.swift
//  quiz_app
//
//  Dashboard "Oggi": punto di partenza azionabile per lo studio.
//

import SwiftUI
import Charts

struct TodayView: View {
    @ObservedObject var app: AppStore
    @Binding var selection: AppTab

    var body: some View {
        Group {
            if let materia = app.activeMateria, let stats = app.statsStore {
                content(materia: materia, stats: stats)
            } else {
                ContentUnavailableView {
                    Label("Nessuna materia attiva", systemImage: "books.vertical")
                } description: {
                    Text("Importa o seleziona una materia per iniziare a studiare.")
                } actions: {
                    Button("Vai a Materie") { selection = .library }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Oggi")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Impostazioni")
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(materia: Materia, stats: StudyDataStore) -> some View {
        let sessions = stats.recentSessions(limit: 30)
        let due = stats.dueCount()

        ScrollView {
            VStack(alignment: .leading, spacing: QuizTheme.Spacing.xl) {
                header(materia: materia)

                heroCard(materia: materia, stats: stats, due: due)

                metricsCard(materia: materia, sessions: sessions)

                if sessions.count >= 2 {
                    trendCard(sessions: sessions.reversed())
                }

                quickStart(materia: materia, stats: stats)
            }
            .padding()
        }
        .background(QuizTheme.Colors.background)
    }

    private func header(materia: Materia) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greeting)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(materia.meta.subject_name)
                .font(.title.bold())
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func heroCard(materia: Materia, stats: StudyDataStore, due: Int) -> some View {
        VStack(alignment: .leading, spacing: QuizTheme.Spacing.md) {
            Label("Ripasso intelligente", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(QuizTheme.Colors.modeSmart)

            Text(due > 0 ? "\(due)" : "Pronto")
                .font(.system(size: 44, weight: .bold))
                .contentTransition(.numericText())

            Text(due > 0
                 ? "domande in scadenza, ottimizzate per la memoria (SM-2)."
                 : "Nessuna scadenza: allenati comunque o esplora nuove domande.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink {
                QuizView(materia: materia, stats: stats, mode: .smart,
                         category: nil, count: smartCount(materia))
            } label: {
                Label("Inizia ora", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: QuizTheme.Colors.modeSmart))
        }
        .card()
    }

    private func metricsCard(materia: Materia, sessions: [StudySession]) -> some View {
        HStack(spacing: QuizTheme.Spacing.md) {
            MetricView(value: "\(materia.questions.count)",
                       label: "Domande", systemImage: "questionmark.circle")
            Divider()
            MetricView(value: "\(Int(StudyMetrics.averageAccuracy(sessions) * 100))%",
                       label: "Precisione", systemImage: "target",
                       tint: QuizTheme.Colors.success)
            Divider()
            MetricView(value: "\(StudyMetrics.currentStreak(from: sessions))",
                       label: "Giorni di fila", systemImage: "flame.fill",
                       tint: QuizTheme.Colors.warning)
        }
        .card()
    }

    private func trendCard(sessions: [StudySession]) -> some View {
        Button { selection = .stats } label: {
            VStack(alignment: .leading, spacing: QuizTheme.Spacing.sm) {
                SectionHeader(title: "Andamento")
                Chart {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                        LineMark(x: .value("Sessione", index + 1),
                                 y: .value("Precisione", session.accuracy * 100))
                        .interpolationMethod(.catmullRom)
                        AreaMark(x: .value("Sessione", index + 1),
                                 y: .value("Precisione", session.accuracy * 100))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(QuizTheme.Colors.primary.opacity(0.12))
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .frame(height: 120)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private func quickStart(materia: Materia, stats: StudyDataStore) -> some View {
        VStack(alignment: .leading, spacing: QuizTheme.Spacing.md) {
            SectionHeader(title: "Avvio rapido", actionTitle: "Tutte le modalità") {
                selection = .quiz
            }
            NavigationLink {
                QuizView(materia: materia, stats: stats, mode: .generic,
                         category: nil, count: min(20, materia.questions.count))
            } label: {
                Label("Ripasso generale", systemImage: "book.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(QuizTheme.Colors.cardBackground,
                                in: RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.lg))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func smartCount(_ materia: Materia) -> Int {
        min(20, max(1, materia.questions.count))
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<13:  return "Buongiorno"
        case 13..<18: return "Buon pomeriggio"
        default:      return "Buonasera"
        }
    }
}
