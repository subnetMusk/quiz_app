//
//  StatsView.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var app: AppStore

    var body: some View {
        List {
            if let materia = app.activeMateria {
                // SEZIONE: Panoramica categorie
                Section("Categorie") {
                    ForEach(materia.taxonomy, id: \.id) { cat in
                        NavigationLink {
                            CategoryStatsView(app: app, categoryId: cat.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cat.name)
                                        .font(.body)
                                        .lineLimit(2)
                                    Text("\(countQuestions(in: cat.id, materia: materia)) domande")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                BadgeCount(text: "\(app.statsStore?.wrongCount(categoryId: cat.id) ?? 0)",
                                           color: .red.opacity(0.85),
                                           systemImage: "xmark.octagon.fill")
                                    .accessibilityLabel("Errori in \(cat.name)")
                            }
                        }
                    }
                }

                // SEZIONE: Top errori globali
                Section("Top errori (globali)") {
                    let topIds = app.statsStore?.topWrong(limit: 10) ?? []
                    if topIds.isEmpty {
                        Text("Non ci sono errori registrati.").foregroundStyle(.secondary)
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
            } else {
                Text("Nessuna materia attiva. Importa un file per vedere le statistiche.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("📊 Statistiche")
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
        .navigationTitle("📁 Categoria")
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
        .navigationTitle("❓ Dettaglio domanda")
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
                Text(question.kind == .multiple ? "Multiple" : "Matching")
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
