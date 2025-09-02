//
//  HomeView.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @ObservedObject var app: AppStore

    @State private var showImportMateria = false
    @State private var showImportStats = false
    @State private var exportStatsURL: URL?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 20) {
            header

            // Azioni di gestione file/statistiche
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    app.flushStats()
                    exportStatsURL = app.exportStatsURL()
                } label: {
                    Label("Flush esercitazioni", systemImage: "trash")
                }
                .disabled(app.activeMateria == nil)

                Button {
                    showImportMateria = true
                } label: {
                    Label("Carica nuova materia", systemImage: "square.and.arrow.down")
                }

                Button {
                    exportStatsURL = app.exportStatsURL()
                } label: {
                    Label("Esporta statistiche", systemImage: "square.and.arrow.up")
                }
                .disabled(app.activeMateria == nil)

                if let url = exportStatsURL {
                    ShareLink(item: url) {
                        Label("Condividi", systemImage: "square.and.arrow.up.on.square")
                    }
                }

                Button {
                    showImportStats = true
                } label: {
                    Label("Importa statistiche", systemImage: "arrow.down.doc")
                }
                .disabled(app.activeMateria == nil)
            }
            .buttonStyle(.bordered)

            Divider().padding(.vertical, 8)

            // Navigazione funzionale
            HStack(spacing: 16) {
                NavigationLink {
                    SessionSetupView(app: app)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "play.circle.fill").font(.system(size: 36))
                        Text("Avvia un ripasso").font(.headline)
                        Text(subtitleRipasso)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 110)
                }
                .buttonStyle(.borderedProminent)
                .disabled(app.activeMateria == nil)

                NavigationLink {
                    StatsView(app: app)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "chart.bar.doc.horizontal").font(.system(size: 36))
                        Text("Visualizza statistiche").font(.headline)
                        Text(subtitleStats)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 110)
                }
                .buttonStyle(.bordered)
                .disabled(app.activeMateria == nil)
            }

            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $showImportMateria,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    do {
                        let materia = try QuizIO.importMateriaFromDocumentPicker(url: url)
                        app.refreshSubjects()
                        app.selectSubject(id: materia.meta.subject_id)
                        exportStatsURL = app.exportStatsURL()
                    } catch let error as QuizIOError {
                        errorMessage = error.localizedDescription
                        showError = true
                    } catch {
                        errorMessage = "Errore sconosciuto: \(error.localizedDescription)"
                        showError = true
                    }
                }
            case .failure(let error):
                errorMessage = "Errore nella selezione del file: \(error.localizedDescription)"
                showError = true
            }
        }
        .fileImporter(
            isPresented: $showImportStats,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                app.importStats(from: url, replace: false) // merge di default
                exportStatsURL = app.exportStatsURL()
            }
        }
        .alert("Errore di importazione", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Errore sconosciuto")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 6) {
            Text(app.activeMateria?.meta.subject_name ?? "Nessuna materia attiva")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            if let m = app.activeMateria {
                HStack(spacing: 12) {
                    Badge(text: "ID \(m.meta.subject_id.prefix(8))")
                    Badge(text: "v\(m.meta.version)")
                    Badge(text: "\(m.questions.count) domande")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Importa un file materia (.json) per iniziare.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var subtitleRipasso: String {
        guard let m = app.activeMateria else { return "Importa una materia per scegliere le modalità" }
        let q = m.config.scales_questions.map { $0.description }.joined(separator: " • ")
        let c = m.config.scales_category.map { $0.description }.joined(separator: " • ")
        return "Generico: \(q)  |  Per categoria: \(c)"
    }

    private var subtitleStats: String {
        guard app.activeMateria != nil else { return "Statistiche e domande divise per categoria" }
        return "Errori top X, per categoria e per domanda (badge giallo/rosso)"
    }
}

private struct Badge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.monospaced())
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }
}
