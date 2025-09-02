//
//  MateriaModels.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//

import Foundation

// MARK: - Quiz modes (Core types)

enum QuizSessionMode: String, CaseIterable, Identifiable {
    case generic = "Generico"
    case byCategory = "Per categoria"
    case errors = "Errori"
    case errorsByCategory = "Errori per categoria"
    
    var id: String { rawValue }
}

// MARK: - Materia (file JSON principale)

struct Materia: Codable, Equatable {
    struct Meta: Codable, Equatable {
        /// SHA-256 calcolato sul file materia senza questo campo (vedi Validation).
        var subject_id: String
        /// Nome visualizzato della materia (es. "Paradigmi di Programmazione").
        var subject_name: String
        var version: Int
    }

    struct Config: Codable, Equatable {
        /// Scaglioni per il ripasso generico (es. [10, 20, 50, "all"])
        var scales_questions: [Scale]
        /// Scaglioni per ripasso per categoria
        var scales_category: [Scale]
        /// Scaglioni per ripasso errori (globali o per categoria)
        var scales_errors: [Scale]
        /// "immediate" (per ora), letto dal JSON per evitare hardcode
        var feedback: String
    }

    /// Tassonomia: categoria con eventuali sottocategorie
    struct Node: Codable, Identifiable, Hashable, Equatable {
        var id: String
        var name: String
        var sub: [Node]?    // sottocategorie (facoltative)
    }

    var meta: Meta
    var config: Config
    var taxonomy: [Node]
    var questions: [Question]
}

// MARK: - Scale numeriche o "all"

/// Supporta valori come 10, 20, 50 o la stringa "all" nel JSON.
enum Scale: Codable, Hashable, Identifiable, Equatable {
    case count(Int)
    case all

    var id: String { description }
    var description: String {
        switch self {
        case .count(let n): return "\(n)"
        case .all:          return "tutte"
        }
    }
    
    func value(for materia: Materia, mode: QuizSessionMode, category: String?) -> Int {
        switch self {
        case .count(let n):
            return n
        case .all:
            switch mode {
            case .generic, .errors:
                return materia.questions.count
            case .byCategory, .errorsByCategory:
                if let category = category {
                    return materia.questions(category: category).count
                }
                return 0
            }
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let n = try? c.decode(Int.self) {
            self = .count(n)
        } else {
            _ = try c.decode(String.self) // qualunque stringa -> all
            self = .all
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .count(let n): try c.encode(n)
        case .all:          try c.encode("all")
        }
    }
}

// MARK: - Domande

public enum QuestionKind: String, Codable, Equatable {
    case multiple
    case matching
}

public struct Option: Codable, Identifiable, Hashable, Equatable {
    public var id: Int
    public var text: String
    public var isCorrect: Bool
}

public struct Question: Codable, Identifiable, Hashable, Equatable {
    public var id: String
    public var category: String
    public var subcategory: String?
    public var kind: QuestionKind
    public var prompt: String
    public var code: String?              // opzionale (blocchi di codice)
    // multiple
    public var options: [Option]?
    // matching
    public var left: [String]?
    public var right: [String]?
    public var correctMatches: [Int:Int]?
}

// MARK: - Helper dominio

extension Materia {
    /// Trova il nome leggibile di una categoria/sottocategoria.
    func displayName(forCategory id: String, sub subId: String?) -> String {
        guard let cat = taxonomy.first(where: { $0.id == id }) else { return id }
        if let subId, let s = cat.sub?.first(where: { $0.id == subId }) {
            return "\(cat.name) · \(s.name)"
        }
        return cat.name
    }

    /// Restituisce le domande filtrate per categoria/sottocategoria.
    func questions(category id: String, sub subId: String? = nil) -> [Question] {
        questions.filter { q in
            guard q.category == id else { return false }
            if let subId = subId {
                return q.subcategory == subId
            }
            return true
        }
    }
    
    /// Restituisce l'elenco delle categorie disponibili
    var categories: [String] {
        return taxonomy.map { $0.id }
    }
}
