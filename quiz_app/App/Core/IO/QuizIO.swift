//
//  QuizIO.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//

import Foundation

enum QuizIOError: Error, LocalizedError {
    case materiaNotFound
    case statsNotFound
    case decodeFailed(String)
    case encodeFailed(String)
    case writeFailed(String)
    case fileAccessDenied(String)
    case corruptedFile(String)
    
    var errorDescription: String? {
        switch self {
        case .materiaNotFound:
            return "📁 Materia non trovata. Il file non esiste nella cartella dell'app."
        case .statsNotFound:
            return "📊 Statistiche non trovate. Non ci sono dati salvati per questa materia."
        case .decodeFailed(let detail):
            return "🔍 Errore di decodifica: \(detail)"
        case .encodeFailed(let detail):
            return "💾 Errore di codifica: \(detail)"
        case .writeFailed(let detail):
            return "✍️ Errore di scrittura: \(detail)"
        case .fileAccessDenied(let detail):
            return "🔒 Accesso negato al file: \(detail)"
        case .corruptedFile(let detail):
            return "⚠️ File corrotto: \(detail)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .materiaNotFound:
            return "Importa nuovamente il file della materia o verifica che sia stato salvato correttamente."
        case .statsNotFound:
            return "Le statistiche verranno create automaticamente quando inizierai a usare l'app."
        case .decodeFailed:
            return "Verifica che il file sia in formato JSON valido e non corrotto."
        case .encodeFailed:
            return "Riprova l'operazione. Se il problema persiste, riavvia l'app."
        case .writeFailed:
            return "Verifica di avere spazio sufficiente e che l'app abbia i permessi di scrittura."
        case .fileAccessDenied:
            return "Controlla i permessi dell'app o seleziona un file diverso."
        case .corruptedFile:
            return "Sostituisci il file con una versione non corrotta."
        }
    }
}

/// Operazioni di I/O su file JSON (materie e statistiche)
enum QuizIO {

    // MARK: - Materie

    /// Importa una materia da un file esterno (Files/iCloud), valida lo schema/hash,
    /// salva in Documents/quiz_app/subjects/Materia_<subject_id>.json e ritorna l'oggetto `Materia`.
    static func importMateria(from pickedURL: URL) throws -> Materia {
        do {
            try Paths.ensureDirectories()
        } catch {
            throw QuizIOError.writeFailed("Impossibile creare le cartelle necessarie: \(error.localizedDescription)")
        }
        
        let raw: Data
        do {
            raw = try Data(contentsOf: pickedURL)
        } catch {
            throw QuizIOError.fileAccessDenied("Impossibile leggere il file: \(error.localizedDescription)")
        }
        
        let materia: Materia
        do {
            materia = try validateMateriaData(raw) // calcola/valida subject_id e schema
        } catch let materiaError as MateriaError {
            // Rilancia gli errori di validazione così come sono (hanno già messaggi dettagliati)
            throw materiaError
        } catch {
            throw QuizIOError.decodeFailed("Errore generale nella validazione: \(error.localizedDescription)")
        }

        let dst = Paths.subjectFile(id: materia.meta.subject_id)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        
        let data: Data
        do {
            data = try enc.encode(materia)
        } catch {
            throw QuizIOError.encodeFailed("Impossibile codificare la materia: \(error.localizedDescription)")
        }
        
        do {
            try data.write(to: dst, options: .atomic)
        } catch {
            throw QuizIOError.writeFailed("Impossibile salvare il file: \(error.localizedDescription)")
        }
        
        return materia
    }

    /// Carica una materia già salvata (da sidebar o all'avvio).
    static func loadMateria(id: String) throws -> Materia {
        let url = Paths.subjectFile(id: id)
        guard FileManager.default.fileExists(atPath: url.path) else { 
            throw QuizIOError.materiaNotFound 
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw QuizIOError.fileAccessDenied("Impossibile leggere il file della materia: \(error.localizedDescription)")
        }
        
        do {
            return try JSONDecoder().decode(Materia.self, from: data)
        } catch {
            throw QuizIOError.corruptedFile("Il file della materia è corrotto: \(error.localizedDescription)")
        }
    }

    /// Restituisce elenco (id, name) delle materie presenti in /subjects.
    static func listMaterie() -> [(id: String, name: String)] {
        (try? FileManager.default.contentsOfDirectory(at: Paths.subjects, includingPropertiesForKeys: nil))?
            .compactMap { url -> (String, String)? in
                guard let data = try? Data(contentsOf: url),
                      let m = try? JSONDecoder().decode(Materia.self, from: data) else { return nil }
                return (m.meta.subject_id, m.meta.subject_name)
            } ?? []
    }

    /// Auto-importa materie dalla cartella Documents se non sono già state importate
    static func autoImportFromDocuments() {
        print("🔍 Scansione auto-import da bundle app...")
        
        // Lista materie già importate (per nome del subject)
        let existingMaterie = listMaterie()
        let existingSubjectNames = Set(existingMaterie.map { $0.name })
        
        // Scansiona il bundle dell'app per file JSON (sono nella root del bundle)
        let bundleURL = Bundle.main.bundleURL
        print("📁 Bundle URL: \(bundleURL)")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension.lowercased() == "json" }
            
            print("📁 Trovati \(jsonFiles.count) file JSON nel bundle app")
            
            for jsonFile in jsonFiles {
                print("🔍 Analizzando: \(jsonFile.lastPathComponent)")
                
                // Tenta di decodificare come materia
                guard let data = try? Data(contentsOf: jsonFile),
                      let testMateria = try? JSONDecoder().decode(Materia.self, from: data) else {
                    print("⚠️ \(jsonFile.lastPathComponent) non è una materia valida, skip")
                    continue
                }
                
                print("📖 Materia trovata: '\(testMateria.meta.subject_name)'")
                
                // Verifica se già importata (confronto per nome del subject)
                if existingSubjectNames.contains(testMateria.meta.subject_name) {
                    print("✅ '\(testMateria.meta.subject_name)' già importata, skip")
                    continue
                }
                
                // Importa automaticamente
                do {
                    let importedMateria = try importMateria(from: jsonFile)
                    print("🎉 Auto-importata: '\(importedMateria.meta.subject_name)' con ID: \(importedMateria.meta.subject_id)")
                } catch {
                    print("❌ Errore auto-import \(jsonFile.lastPathComponent): \(error)")
                }
            }
            
            print("✅ Auto-import completato")
        } catch {
            print("❌ Errore scansione bundle app: \(error)")
        }
    }

    // MARK: - Statistiche

    /// Carica le statistiche per una materia; se non esistono, ritorna un file vuoto (non lo salva).
    static func loadStats(subjectId: String) -> StatsFile {
        let url = Paths.statsFile(id: subjectId)
        guard let data = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode(StatsFile.self, from: data) else {
            return .empty(subjectId: subjectId)
        }
        return s
    }

    /// Salva le statistiche su disco, sovrascrivendo il file.
    @discardableResult
    static func saveStats(_ stats: StatsFile) throws -> URL {
        do {
            try Paths.ensureDirectories()
        } catch {
            throw QuizIOError.writeFailed("Impossibile creare le cartelle necessarie: \(error.localizedDescription)")
        }
        
        let url = Paths.statsFile(id: stats.meta.subject_id)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        
        let data: Data
        do {
            data = try enc.encode(stats)
        } catch {
            throw QuizIOError.encodeFailed("Impossibile codificare le statistiche: \(error.localizedDescription)")
        }
        
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw QuizIOError.writeFailed("Impossibile salvare le statistiche: \(error.localizedDescription)")
        }
    }

    /// Unisce (merge) stats importate con quelle correnti e salva il risultato.
    /// Se `replace` è true sostituisce, altrimenti fa la somma dei contatori.
    @discardableResult
    static func importStats(from pickedURL: URL, expectedSubjectId: String, replace: Bool = false) throws -> StatsFile {
        let data = try Data(contentsOf: pickedURL)
        let incoming = try JSONDecoder().decode(StatsFile.self, from: data)
        guard incoming.meta.subject_id == expectedSubjectId else {
            throw MateriaError.wrongSubject
        }
        let current = loadStats(subjectId: expectedSubjectId)
        let merged = replace ? incoming : current.merging(with: incoming)
        try saveStats(merged)
        return merged
    }

    /// Restituisce l'URL del file statistiche da condividere (se esiste).
    static func exportStatsURL(subjectId: String) -> URL? {
        let url = Paths.statsFile(id: subjectId)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Elimina le statistiche della materia (flush).
    static func flushStats(subjectId: String) throws {
        let url = Paths.statsFile(id: subjectId)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Document Picker Import
    
    /// Importa una materia da URL selezionato dall'utente tramite Document Picker
    static func importMateriaFromDocumentPicker(url: URL) throws -> Materia {
        guard url.startAccessingSecurityScopedResource() else {
            throw QuizIOError.fileAccessDenied("Impossibile accedere al file selezionato. Verifica i permessi.")
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw QuizIOError.fileAccessDenied("Impossibile leggere il file: \(error.localizedDescription)")
        }
        
        // Valida la struttura usando la funzione di validazione esistente
        let materia: Materia
        do {
            materia = try validateMateriaData(data)
        } catch let materiaError as MateriaError {
            throw materiaError
        } catch {
            throw QuizIOError.decodeFailed("Errore generale nella validazione: \(error.localizedDescription)")
        }

        // Salva nella directory dell'app
        let dst = Paths.subjectFile(id: materia.meta.subject_id)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        
        let encodedData: Data
        do {
            encodedData = try enc.encode(materia)
        } catch {
            throw QuizIOError.encodeFailed("Impossibile codificare la materia: \(error.localizedDescription)")
        }
        
        do {
            try encodedData.write(to: dst, options: .atomic)
        } catch {
            throw QuizIOError.writeFailed("Impossibile salvare il file: \(error.localizedDescription)")
        }
        
        return materia
    }
    
    // MARK: - Subject Management
    
    /// Elimina una materia specifica e le sue statistiche
    static func deleteSubject(subjectId: String) throws {
        let subjectFile = Paths.subjectFile(id: subjectId)
        let statsFile = Paths.statsFile(id: subjectId)
        
        // Rimuovi il file della materia se esiste
        if FileManager.default.fileExists(atPath: subjectFile.path) {
            try FileManager.default.removeItem(at: subjectFile)
        }
        
        // Rimuovi il file delle statistiche se esiste
        if FileManager.default.fileExists(atPath: statsFile.path) {
            try FileManager.default.removeItem(at: statsFile)
        }
    }
    
    /// Elimina tutte le materie e statistiche
    static func deleteAllSubjects() throws {
        let subjectsDir = Paths.subjects
        let statsDir = Paths.stats
        
        // Rimuovi tutte le materie
        if FileManager.default.fileExists(atPath: subjectsDir.path) {
            try FileManager.default.removeItem(at: subjectsDir)
            try FileManager.default.createDirectory(at: subjectsDir, withIntermediateDirectories: true)
        }
        
        // Rimuovi tutte le statistiche
        if FileManager.default.fileExists(atPath: statsDir.path) {
            try FileManager.default.removeItem(at: statsDir)
            try FileManager.default.createDirectory(at: statsDir, withIntermediateDirectories: true)
        }
    }
}
