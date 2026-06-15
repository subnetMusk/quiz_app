//
//  LibraryView.swift
//  quiz_app
//
//  Tab "Materie": elenco pulito delle materie con import; dettaglio e gestione in SubjectDetailView.
//

import SwiftUI

struct LibraryView: View {
    @ObservedObject var app: AppStore
    @State private var showImporter = false
    @State private var alertMessage: String?

    var body: some View {
        Group {
            if app.subjects.isEmpty {
                ContentUnavailableView {
                    Label("Nessuna materia", systemImage: "books.vertical")
                } description: {
                    Text("Importa un file JSON per creare la tua prima materia.")
                } actions: {
                    Button("Importa materia") { showImporter = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    Section {
                        ForEach(app.subjects, id: \.id) { subject in
                            NavigationLink {
                                SubjectDetailView(app: app, subjectId: subject.id, subjectName: subject.name)
                            } label: {
                                subjectRow(subject)
                            }
                        }
                    } header: {
                        Text("\(app.subjects.count) materie")
                    }
                }
            }
        }
        .navigationTitle("Materie")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showImporter = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Importa materia")
            }
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Impostazioni")
            }
        }
        .sheet(isPresented: $showImporter) {
            DocumentPicker(selectedFileURL: .constant(nil)) { url in
                app.importMateria(from: url)
                showImporter = false
                alertMessage = "Materia importata con successo."
            }
        }
        .alert("Materie", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func subjectRow(_ subject: (id: String, name: String)) -> some View {
        let isActive = app.activeMateria?.meta.subject_id == subject.id
        return HStack(spacing: QuizTheme.Spacing.md) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "book.closed")
                .foregroundStyle(isActive ? QuizTheme.Colors.success : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(subject.name).font(.body)
                if isActive {
                    Text("Attiva").font(.caption2).foregroundStyle(QuizTheme.Colors.success)
                }
            }
        }
    }
}

/// Share sheet di sistema per esportare file (es. statistiche).
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
