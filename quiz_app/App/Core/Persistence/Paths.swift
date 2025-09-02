//
//  Paths.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//

import Foundation

/// Helper per determinare i path in cui salvare materie e statistiche.
/// Tutti i file stanno sotto Documents/quiz_app/
enum Paths {
    /// Root della nostra app nello sandbox utente
    static var root: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("quiz_app", isDirectory: true)
    }()

    /// Cartella che contiene i file materia caricati
    static var subjects: URL = {
        root.appendingPathComponent("subjects", isDirectory: true)
    }()

    /// Cartella che contiene i file statistiche
    static var stats: URL = {
        root.appendingPathComponent("stats", isDirectory: true)
    }()

    /// Restituisce il path per un file materia specifico (subject_id)
    static func subjectFile(id: String) -> URL {
        subjects.appendingPathComponent("Materia_\(id).json")
    }

    /// Restituisce il path per un file statistiche specifico (subject_id)
    static func statsFile(id: String) -> URL {
        stats.appendingPathComponent("Stats_\(id).json")
    }

    /// Assicura che esistano le directory principali
    static func ensureDirectories() throws {
        let fm = FileManager.default
        for dir in [root, subjects, stats] {
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }
}
