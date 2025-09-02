//
//  AppStore.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//

import Foundation
import Combine

/// Store globale dell'app.
/// - Tiene la materia attiva e il relativo StatsStore.
/// - Espone le operazioni di import/export/flush.
/// - Rende disponibile la lista delle materie salvate.
final class AppStore: ObservableObject {
    /// Materia attualmente attiva
    @Published private(set) var activeMateria: Materia?
    /// Stats store associato alla materia attiva
    @Published private(set) var statsStore: StatsStore?
    /// Lista materie disponibili su disco (id, name)
    @Published private(set) var subjects: [(id: String, name: String)] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Auto-import da Documents prima di caricare le materie
        QuizIO.autoImportFromDocuments()
        
        refreshSubjects()
        // tenta di ricaricare l'ultima materia usata
        if let last = UserDefaults.standard.string(forKey: "last_subject_id") {
            _ = selectSubject(id: last)
        }
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
            statsStore = StatsStore(subjectId: materia.meta.subject_id)
            UserDefaults.standard.set(materia.meta.subject_id, forKey: "last_subject_id")
            return true
        } catch {
            print("❌ selectSubject failed:", error)
            return false
        }
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

    /// Flush: elimina le statistiche della materia attiva
    func flushStats() {
        guard let id = activeMateria?.meta.subject_id else { return }
        do {
            try QuizIO.flushStats(subjectId: id)
            statsStore = StatsStore(subjectId: id) // ricarica store vuoto
        } catch {
            print("❌ flushStats failed:", error)
        }
    }

    /// Export: restituisce l'URL del file statistiche della materia attiva
    func exportStatsURL() -> URL? {
        guard let id = activeMateria?.meta.subject_id else { return nil }
        return QuizIO.exportStatsURL(subjectId: id)
    }

    /// Importa statistiche esterne e le unisce o sostituisce
    func importStats(from url: URL, replace: Bool = false) {
        guard let id = activeMateria?.meta.subject_id else { return }
        do {
            let merged = try QuizIO.importStats(from: url, expectedSubjectId: id, replace: replace)
            statsStore?.replace(with: merged)
        } catch {
            print("❌ importStats failed:", error)
        }
    }
    
    // MARK: - Subject Management
    
    /// Elimina una materia specifica
    func deleteSubject(id: String) {
        do {
            try QuizIO.deleteSubject(subjectId: id)
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
            refreshSubjects()
            activeMateria = nil
            statsStore = nil
        } catch {
            print("❌ deleteAllSubjects failed:", error)
        }
    }
}
