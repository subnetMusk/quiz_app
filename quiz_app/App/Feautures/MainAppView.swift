import SwiftUI

struct MainAppView: View {
    @ObservedObject var app: AppStore
    
    var body: some View {
        TabView {
            // Tab delle Materie (ex-sidebar)
            NavigationView {
                MaterieListView(app: app)
            }
            .tabItem {
                Image(systemName: "books.vertical")
                Text("Materie")
            }
            
            // Tab Quiz
            NavigationView {
                MainQuizView(app: app)
            }
            .tabItem {
                Image(systemName: "brain.head.profile")
                Text("Quiz")
            }
            
            // Tab Statistiche
            NavigationView {
                StatsView(app: app)
            }
            .tabItem {
                Image(systemName: "chart.bar")
                Text("Statistiche")
            }
        }
        .accentColor(QuizTheme.Colors.primary)
    }
}

// Gestione completa delle materie con UI sidebar-style
struct MaterieListView: View {
    @ObservedObject var app: AppStore
    @State private var showDocumentPicker = false
    @State private var showingShareSheet = false
    @State private var showStatsDocumentPicker = false
    @State private var shareURL: URL?
    @State private var isImportingStats = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDestructiveAlert = false
    @State private var destructiveAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header sezione gestione risorse
            headerSection
            
            // Lista materie
            materieSection
            
            // Azioni su materia attiva
            if app.activeMateria != nil {
                activeMateriaActions
            }
            
            // Azioni distruttive
            destructiveActions
        }
        .navigationTitle("📚 Gestione Materie")
        .navigationBarTitleDisplayMode(.large)
        .background(QuizTheme.Colors.background)
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(selectedFileURL: .constant(nil)) { url in
                handleImportedFile(url)
                showDocumentPicker = false
            }
        }
        .sheet(isPresented: $showStatsDocumentPicker) {
            DocumentPicker(selectedFileURL: .constant(nil)) { url in
                handleStatsImport(url)
                showStatsDocumentPicker = false
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Notifica", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("Conferma Azione", isPresented: $showingDestructiveAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Conferma", role: .destructive) {
                destructiveAction?()
            }
        } message: {
            Text("Questa azione non può essere annullata. Sei sicuro di voler procedere?")
        }
    }
    
    // MARK: - Header Section
    var headerSection: some View {
        VStack(spacing: QuizTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Centro di Controllo")
                        .font(QuizTheme.Typography.title2)
                        .foregroundStyle(QuizTheme.Colors.primary)
                    
                    Text("Gestisci le tue materie e risorse")
                        .font(QuizTheme.Typography.caption)
                        .foregroundColor(QuizTheme.Colors.secondary)
                }
                Spacer()
                
                Button(action: { showDocumentPicker = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Importa")
                            .font(QuizTheme.Typography.caption)
                    }
                }
                .foregroundStyle(QuizTheme.Colors.primary)
            }
            
            Divider()
        }
        .padding(.horizontal, QuizTheme.Spacing.md)
        .padding(.top, QuizTheme.Spacing.sm)
        .background(QuizTheme.Colors.secondaryBackground)
    }
    
    // MARK: - Materie Section
    var materieSection: some View {
        Group {
            if app.subjects.isEmpty {
                emptyStateView
            } else {
                materieList
            }
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: QuizTheme.Spacing.lg) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(QuizTheme.Colors.secondary)
            
            VStack(spacing: QuizTheme.Spacing.sm) {
                Text("Nessuna Materia")
                    .font(QuizTheme.Typography.title2)
                    .foregroundStyle(QuizTheme.Colors.primary)
                
                Text("Importa la tua prima materia per iniziare")
                    .font(QuizTheme.Typography.body)
                    .foregroundColor(QuizTheme.Colors.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Importa Materia") {
                showDocumentPicker = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(QuizTheme.Spacing.xl)
    }
    
    var materieList: some View {
        List {
            Section {
                ForEach(app.subjects, id: \.id) { subject in
                    materialRow(subjectInfo: subject)
                }
            } header: {
                HStack {
                    Text("Materie Disponibili")
                        .font(QuizTheme.Typography.headline)
                    Spacer()
                    Text("\(app.subjects.count)")
                        .font(QuizTheme.Typography.caption)
                        .foregroundColor(QuizTheme.Colors.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Active Materia Actions
    var activeMateriaActions: some View {
        VStack(spacing: QuizTheme.Spacing.md) {
            Divider()
            
            VStack(alignment: .leading, spacing: QuizTheme.Spacing.sm) {
                HStack {
                    Text("📖 Materia Attiva")
                        .font(QuizTheme.Typography.headline)
                        .foregroundStyle(QuizTheme.Colors.primary)
                    Spacer()
                }
                
                if let materia = app.activeMateria {
                    Text(materia.meta.subject_name)
                        .font(QuizTheme.Typography.body)
                        .foregroundStyle(QuizTheme.Colors.primary)
                        .padding(.vertical, QuizTheme.Spacing.xs)
                        .padding(.horizontal, QuizTheme.Spacing.sm)
                        .background(QuizTheme.Colors.secondaryBackground)
                        .cornerRadius(8)
                }
                
                // Azioni statistiche
                VStack(spacing: QuizTheme.Spacing.md) {
                    Text("Gestione Statistiche")
                        .font(QuizTheme.Typography.subheadline)
                        .foregroundStyle(QuizTheme.Colors.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    HStack(spacing: QuizTheme.Spacing.lg) {
                        Button {
                            isImportingStats = true
                            showStatsDocumentPicker = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.title2)
                                Text("Importa Stats")
                                    .font(QuizTheme.Typography.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(QuizTheme.Colors.primary.opacity(0.1))
                            .foregroundStyle(QuizTheme.Colors.primary)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(QuizTheme.Colors.primary.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            exportStats()
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                Text("Esporta Stats")
                                    .font(QuizTheme.Typography.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(QuizTheme.Colors.primary.opacity(0.1))
                            .foregroundStyle(QuizTheme.Colors.primary)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(QuizTheme.Colors.primary.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, QuizTheme.Spacing.md)
        }
        .background(QuizTheme.Colors.secondaryBackground)
    }
    
    // MARK: - Destructive Actions
    var destructiveActions: some View {
        VStack(spacing: QuizTheme.Spacing.lg) {
            Divider()
                .padding(.horizontal, QuizTheme.Spacing.md)
            
            VStack(spacing: QuizTheme.Spacing.lg) {
                Text("Azioni Distruttive")
                    .font(QuizTheme.Typography.headline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                VStack(spacing: QuizTheme.Spacing.md) {
                    Button {
                        destructiveAction = {
                            flushStats()
                        }
                        showingDestructiveAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.circle.fill")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cancella Statistiche")
                                    .font(QuizTheme.Typography.body)
                                    .fontWeight(.semibold)
                                Text("Rimuove tutti i dati delle sessioni di quiz")
                                    .font(QuizTheme.Typography.caption)
                                    .opacity(0.8)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        destructiveAction = {
                            removeAllMaterials()
                        }
                        showingDestructiveAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rimuovi Tutte le Materie")
                                    .font(QuizTheme.Typography.body)
                                    .fontWeight(.semibold)
                                Text("Elimina completamente tutte le materie e le statistiche")
                                    .font(QuizTheme.Typography.caption)
                                    .opacity(0.8)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, QuizTheme.Spacing.md)
            .padding(.bottom, QuizTheme.Spacing.lg)
        }
        .background(QuizTheme.Colors.secondaryBackground)
    }
    
    // MARK: - Helper Functions
    
    private func materialRow(subjectInfo: (id: String, name: String)) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(subjectInfo.name)
                    .font(QuizTheme.Typography.body)
                    .foregroundStyle(QuizTheme.Colors.primary)
                
                Text("ID: \(subjectInfo.id.prefix(8))")
                    .font(QuizTheme.Typography.caption)
                    .foregroundStyle(QuizTheme.Colors.secondary)
            }
            
            Spacer()
            
            if app.activeMateria?.meta.subject_id == subjectInfo.id {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(QuizTheme.Colors.primary)
                    Text("Attiva")
                        .font(QuizTheme.Typography.caption2)
                        .foregroundStyle(QuizTheme.Colors.primary)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            app.selectSubject(id: subjectInfo.id)
        }
    }
    
    private func handleImportedFile(_ url: URL) {
        app.importMateria(from: url)
        alertMessage = "Materia importata con successo!"
        showingAlert = true
    }
    
    private func handleStatsImport(_ url: URL) {
        if isImportingStats {
            app.importStats(from: url, replace: false)
            alertMessage = "Statistiche importate e unite con successo!"
        } else {
            app.importStats(from: url, replace: true)
            alertMessage = "Statistiche sostituite con successo!"
        }
        showingAlert = true
    }
    
    private func exportStats() {
        guard let url = app.exportStatsURL() else {
            alertMessage = "Nessuna materia attiva per l'esportazione"
            showingAlert = true
            return
        }
        
        shareURL = url
        showingShareSheet = true
    }
    
    private func flushStats() {
        app.flushStats()
        alertMessage = "Statistiche cancellate con successo!"
        showingAlert = true
    }
    
    private func removeAllMaterials() {
        app.deleteAllSubjects()
        alertMessage = "Tutte le materie sono state rimosse!"
        showingAlert = true
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension DateFormatter {
    static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}

#Preview {
    MainAppView(app: AppStore())
}
