//
//  SubjectDetailView.swift
//  quiz_app
//
//  Dettaglio e gestione di una materia: metadati, riepilogo statistiche e azioni.
//

import SwiftUI

struct SubjectDetailView: View {
    @ObservedObject var app: AppStore
    let subjectId: String
    let subjectName: String

    @Environment(\.dismiss) private var dismiss
    @State private var showStatsImporter = false
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var confirmFlush = false
    @State private var confirmDelete = false

    private var isActive: Bool { app.activeMateria?.meta.subject_id == subjectId }

    var body: some View {
        let store = StudyDataStore(subjectId: subjectId)
        let sessions = store.recentSessions(limit: 30)

        List {
            Section {
                MetricsRow(due: store.dueCount(),
                           accuracy: StudyMetrics.averageAccuracy(sessions),
                           sessions: sessions.count)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if !isActive {
                Section {
                    Button {
                        app.selectSubject(id: subjectId)
                    } label: {
                        Label("Imposta come attiva", systemImage: "checkmark.circle")
                    }
                }
            }

            if isActive {
                Section("Statistiche") {
                    Button {
                        shareURL = app.exportStatsURL()
                        showShare = shareURL != nil
                    } label: {
                        Label("Esporta statistiche", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showStatsImporter = true
                    } label: {
                        Label("Importa statistiche", systemImage: "square.and.arrow.down")
                    }
                }
            }

            Section {
                if isActive {
                    Button(role: .destructive) { confirmFlush = true } label: {
                        Label("Azzera statistiche", systemImage: "trash")
                    }
                }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Elimina materia", systemImage: "xmark.bin")
                }
            } header: {
                Text("Zona pericolosa")
            } footer: {
                Text("Queste azioni non possono essere annullate.")
            }
        }
        .navigationTitle(subjectName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            if let shareURL { ShareSheet(activityItems: [shareURL]) }
        }
        .sheet(isPresented: $showStatsImporter) {
            DocumentPicker(selectedFileURL: .constant(nil)) { url in
                app.importStats(from: url, replace: false)
                showStatsImporter = false
            }
        }
        .confirmationDialog("Azzerare le statistiche di questa materia?",
                            isPresented: $confirmFlush, titleVisibility: .visible) {
            Button("Azzera statistiche", role: .destructive) { app.flushStats() }
            Button("Annulla", role: .cancel) {}
        }
        .confirmationDialog("Eliminare \(subjectName)?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina materia", role: .destructive) {
                app.deleteSubject(id: subjectId)
                dismiss()
            }
            Button("Annulla", role: .cancel) {}
        }
    }
}

private struct MetricsRow: View {
    let due: Int
    let accuracy: Double
    let sessions: Int

    var body: some View {
        HStack(spacing: QuizTheme.Spacing.md) {
            MetricView(value: "\(due)", label: "In scadenza", systemImage: "clock",
                       tint: QuizTheme.Colors.modeSmart)
            Divider()
            MetricView(value: "\(Int(accuracy * 100))%", label: "Precisione", systemImage: "target",
                       tint: QuizTheme.Colors.success)
            Divider()
            MetricView(value: "\(sessions)", label: "Sessioni", systemImage: "clock.arrow.circlepath")
        }
        .card()
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}
