//
//  AppStore.swift
//  quiz_app
//
//  Created by Leonardo Soligo on 9/1/25.
//

import Foundation
import Combine
import SwiftData

/// Store globale dell'app.
/// - Tiene la materia attiva e il relativo StudyDataStore (SwiftData).
/// - Espone le operazioni di import/export/flush.
/// - Rende disponibile la lista delle materie salvate.
@MainActor
final class AppStore: ObservableObject {
    /// Materia attualmente attiva
    @Published private(set) var activeMateria: Materia?
    /// Store dati (SwiftData) associato alla materia attiva
    @Published private(set) var statsStore: StudyDataStore?
    /// Lista materie disponibili su disco (id, name)
    @Published private(set) var subjects: [(id: String, name: String)] = []
    /// Contatore bumpato a ogni salvataggio dello store: forza il re-render delle viste
    /// (Oggi, Teoria, Statistiche) quando cambiano progresso o storico sessioni.
    @Published private(set) var dataVersion: Int = 0

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Auto-import da Documents prima di caricare le materie
        QuizIO.autoImportFromDocuments()
        
        refreshSubjects()
        // tenta di ricaricare l'ultima materia usata
        if let last = UserDefaults.standard.string(forKey: "last_subject_id") {
            _ = selectSubject(id: last)
        }

        #if DEBUG
        // Demo/screenshot: `--seed-mock` popola statistiche plausibili su una materia (preferisce TecWeb).
        if CommandLine.arguments.contains("--seed-mock") {
            if let tw = subjects.first(where: { $0.name.localizedCaseInsensitiveContains("Tecnologie") }) ?? subjects.first {
                _ = selectSubject(id: tw.id)
            }
            if let m = activeMateria, let store = statsStore {
                store.seedMockData(materia: m)
                WidgetBridge.update(dueCount: store.dueCount(), subjectName: m.meta.subject_name)
            }
        }
        #endif
    }

    // MARK: - Materie

    /// Aggiorna l'elenco materie disponibili su disco
    func refreshSubjects() {
        subjects = QuizIO.listMaterie()
    }

    /// Seleziona una materia salvata come attiva
    @discardableResult
    func selectSubject(id: String) -> Bool {
        do {
            let materia = try QuizIO.loadMateria(id: id)
            activeMateria = materia
            statsStore = makeStore(for: materia)
            UserDefaults.standard.set(materia.meta.subject_id, forKey: "last_subject_id")
            return true
        } catch {
            print("❌ selectSubject failed:", error)
            return false
        }
    }

    /// Crea lo store SwiftData per una materia, eseguendo la migrazione una-tantum
    /// dai vecchi file `Stats_<id>.json` se i dati SwiftData non esistono ancora.
    private func makeStore(for materia: Materia) -> StudyDataStore {
        let store = StudyDataStore(subjectId: materia.meta.subject_id)
        store.onChange = { [weak self] in self?.dataVersion &+= 1 }
        if !store.hasAnyProgress {
            let legacy = QuizIO.loadStats(subjectId: materia.meta.subject_id)
            if !legacy.per_question.isEmpty {
                let map = Dictionary(uniqueKeysWithValues: materia.questions.map { ($0.id, $0.category) })
                store.merge(legacy, replace: false, categoryMap: map)
            }
        }
        WidgetBridge.update(dueCount: store.dueCount(), subjectName: materia.meta.subject_name)
        return store
    }

    /// Importa una nuova materia da un file scelto dall'utente
    func importMateria(from url: URL) {
        do {
            let materia = try QuizIO.importMateriaFromDocumentPicker(url: url)
            refreshSubjects()
            _ = selectSubject(id: materia.meta.subject_id)
        } catch {
            print("❌ importMateria failed:", error)
            // TODO: Mostrare l'errore all'utente tramite un Alert
        }
    }

    // MARK: - Statistiche

    /// Flush: azzera i dati SwiftData della materia attiva (i file legacy restano come backup)
    func flushStats() {
        statsStore?.reset()
    }

    /// Export: serializza i dati SwiftData in uno snapshot JSON e ne restituisce l'URL
    func exportStatsURL() -> URL? {
        guard let store = statsStore else { return nil }
        return try? QuizIO.saveStats(store.exportSnapshot())
    }

    /// Importa statistiche esterne e le unisce (o sostituisce) nei dati SwiftData
    func importStats(from url: URL, replace: Bool = false) {
        guard let store = statsStore, let materia = activeMateria else { return }
        do {
            let incoming = try QuizIO.decodeStats(from: url, expectedSubjectId: materia.meta.subject_id)
            let map = Dictionary(uniqueKeysWithValues: materia.questions.map { ($0.id, $0.category) })
            store.merge(incoming, replace: replace, categoryMap: map)
        } catch {
            print("❌ importStats failed:", error)
        }
    }
    
    // MARK: - Subject Management
    
    /// Elimina una materia specifica
    func deleteSubject(id: String) {
        do {
            try QuizIO.deleteSubject(subjectId: id)
            StudyDataStore(subjectId: id).reset() // purge dati SwiftData della materia
            refreshSubjects()
            // Se la materia cancellata era quella attiva, resetta
            if activeMateria?.meta.subject_id == id {
                activeMateria = nil
                statsStore = nil
            }
        } catch {
            print("❌ deleteSubject failed:", error)
        }
    }

    /// Elimina tutte le materie
    func deleteAllSubjects() {
        do {
            try QuizIO.deleteAllSubjects()
            try? PersistenceController.mainContext.delete(model: QuestionProgress.self)
            try? PersistenceController.mainContext.delete(model: StudySession.self)
            refreshSubjects()
            activeMateria = nil
            statsStore = nil
        } catch {
            print("❌ deleteAllSubjects failed:", error)
        }
    }
}
