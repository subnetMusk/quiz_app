//
//  SessionSetupView.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//

import SwiftUI

struct SessionSetupView: View {
    @ObservedObject var app: AppStore

    @State private var mode: QuizSessionMode = .generic
    @State private var selectedCategory: String?
    @State private var selectedScale: Scale?
    
    private var questionCount: Int? {
        guard let scale = selectedScale else { return nil }
        switch scale {
        case .count(let n):
            return n
        case .all:
            // Return total questions count based on mode
            if let materia = app.activeMateria {
                switch mode {
                case .generic, .errors:
                    return materia.questions.count
                case .byCategory, .errorsByCategory:
                    if let category = selectedCategory {
                        return materia.questions(category: category).count
                    }
                }
            }
            return nil
        }
    }

    var body: some View {
        Form {
            Section("Modalità") {
                Picker("Tipo di ripasso", selection: $mode) {
                    ForEach(QuizSessionMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
            }

            if mode == .byCategory || mode == .errorsByCategory {
                Section("Categoria") {
                    Picker("Categoria", selection: $selectedCategory) {
                        Text("—").tag(String?.none)
                        ForEach(app.activeMateria?.categories ?? [], id: \.self) { c in
                            Text(c).tag(String?.some(c))
                        }
                    }
                }
            }

            Section("Numero domande") {
                let scales = scalesForMode
                Picker("Domande", selection: $selectedScale) {
                    Text("—").tag(Scale?.none)
                    ForEach(scales, id: \.self) { scale in
                        Text(scale.description).tag(Scale?.some(scale))
                    }
                }
            }

            Section {
                if canStart {
                    NavigationLink {
                        QuizView(
                            materia: app.activeMateria!,
                            stats: app.statsStore!,
                            mode: mode,
                            category: selectedCategory,
                            count: questionCount!
                        )
                    } label: {
                        Label("Avvia esercitazione", systemImage: "play.fill")
                    }
                } else {
                    Label("Seleziona parametri validi", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("⚙️ Imposta ripasso")
    }

    private var scalesForMode: [Scale] {
        guard let m = app.activeMateria else { return [] }
        switch mode {
        case .generic, .errors:
            return m.config.scales_questions
        case .byCategory, .errorsByCategory:
            return m.config.scales_category
        }
    }

    private var canStart: Bool {
        switch mode {
        case .generic, .errors:
            return selectedScale != nil
        case .byCategory, .errorsByCategory:
            return selectedCategory != nil && selectedScale != nil
        }
    }
}
