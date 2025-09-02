//
//  Validation.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//

import Foundation
import CryptoKit

/// Errori possibili durante la validazione di un file materia
enum MateriaError: Error, LocalizedError {
    case invalidHash
    case badSchema
    case wrongSubject
    case missingRequiredField(String)
    case invalidFieldType(String)
    case invalidQuestionStructure(String)
    case emptyData
    case jsonParsingError(String)
    case invalidFileFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidHash:
            return "❌ Hash del file non valido. Il file potrebbe essere stato modificato o corrotto."
        case .badSchema:
            return "❌ Schema del file non valido. Il file non rispetta la struttura richiesta."
        case .wrongSubject:
            return "❌ Materia non corrispondente. Il file appartiene a una materia diversa."
        case .missingRequiredField(let field):
            return "❌ Campo obbligatorio mancante: '\(field)'. Verifica che il file contenga tutti i campi richiesti."
        case .invalidFieldType(let field):
            return "❌ Tipo di dato non valido per il campo: '\(field)'. Controlla il formato dei dati."
        case .invalidQuestionStructure(let detail):
            return "❌ Struttura domanda non valida: \(detail)"
        case .emptyData:
            return "❌ File vuoto o non leggibile. Seleziona un file JSON valido."
        case .jsonParsingError(let detail):
            return "❌ Errore nel parsing JSON: \(detail)"
        case .invalidFileFormat(let detail):
            return "❌ Formato file non supportato: \(detail)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidHash:
            return "Verifica che il file sia quello originale e non sia stato modificato."
        case .badSchema:
            return "Assicurati che il file JSON contenga le sezioni: meta, config, taxonomy, questions."
        case .wrongSubject:
            return "Seleziona il file corretto per questa materia."
        case .missingRequiredField:
            return "Controlla la documentazione per la struttura completa del file."
        case .invalidFieldType:
            return "Verifica che i tipi di dato corrispondano a quelli attesi (stringhe, numeri, array)."
        case .invalidQuestionStructure:
            return "Ogni domanda deve avere id, category, kind, prompt e i campi specifici per il tipo."
        case .emptyData:
            return "Seleziona un file JSON non vuoto e accessibile."
        case .jsonParsingError:
            return "Verifica la sintassi JSON del file (parentesi, virgole, quotes)."
        case .invalidFileFormat:
            return "Il file deve essere in formato JSON valido per quiz app."
        }
    }
}

/// Calcola l’hash SHA-256 di un blocco di dati e lo restituisce in esadecimale
func sha256Hex(of data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

/// Valida e normalizza un file Materia.json
///
/// - Se `meta.subject_id == "auto:sha256"` → viene ricalcolato e sostituito
/// - Se c'è già un subject_id → si ricontrolla la corrispondenza
/// - Viene controllato lo schema minimo (categorie e domande non vuote)
func validateMateriaData(_ data: Data) throws -> Materia {
    // Controllo se i dati sono vuoti
    guard !data.isEmpty else {
        throw MateriaError.emptyData
    }
    
    // Prova a decodificare il JSON base
    let materia: Materia
    do {
        materia = try JSONDecoder().decode(Materia.self, from: data)
    } catch let decodingError {
        // Prova a capire il tipo di errore di parsing
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            // JSON valido ma struttura sbagliata
            throw MateriaError.invalidFileFormat(decodingError.localizedDescription)
        } catch {
            // JSON non valido
            throw MateriaError.jsonParsingError(error.localizedDescription)
        }
    }
    
    // Validazione struttura meta
    try validateMetaStructure(materia.meta)
    
    // Validazione struttura config
    try validateConfigStructure(materia.config)
    
    // Validazione taxonomy
    try validateTaxonomyStructure(materia.taxonomy)
    
    // Validazione domande
    try validateQuestionsStructure(materia.questions, taxonomy: materia.taxonomy)
    
    // --- Calcolo e validazione hash ---
    let validatedMateria = try validateAndUpdateHash(materia, originalData: data)
    
    return validatedMateria
}

/// Valida la struttura meta
private func validateMetaStructure(_ meta: Materia.Meta) throws {
    guard !meta.subject_name.isEmpty else {
        throw MateriaError.missingRequiredField("meta.subject_name")
    }
    guard meta.version > 0 else {
        throw MateriaError.invalidFieldType("meta.version (deve essere > 0)")
    }
}

/// Valida la struttura config
private func validateConfigStructure(_ config: Materia.Config) throws {
    guard !config.scales_questions.isEmpty else {
        throw MateriaError.missingRequiredField("config.scales_questions")
    }
    guard !config.scales_category.isEmpty else {
        throw MateriaError.missingRequiredField("config.scales_category")
    }
    guard !config.scales_errors.isEmpty else {
        throw MateriaError.missingRequiredField("config.scales_errors")
    }
    guard !config.feedback.isEmpty else {
        throw MateriaError.missingRequiredField("config.feedback")
    }
}

/// Valida la struttura taxonomy
private func validateTaxonomyStructure(_ taxonomy: [Materia.Node]) throws {
    guard !taxonomy.isEmpty else {
        throw MateriaError.missingRequiredField("taxonomy (deve contenere almeno una categoria)")
    }
    
    for (index, node) in taxonomy.enumerated() {
        guard !node.id.isEmpty else {
            throw MateriaError.invalidQuestionStructure("taxonomy[\(index)].id è vuoto")
        }
        guard !node.name.isEmpty else {
            throw MateriaError.invalidQuestionStructure("taxonomy[\(index)].name è vuoto")
        }
    }
}

/// Valida la struttura delle domande
private func validateQuestionsStructure(_ questions: [Question], taxonomy: [Materia.Node]) throws {
    guard !questions.isEmpty else {
        throw MateriaError.missingRequiredField("questions (deve contenere almeno una domanda)")
    }
    
    let validCategories = Set(taxonomy.map { $0.id })
    
    for (index, question) in questions.enumerated() {
        let questionPrefix = "questions[\(index)] (id: \(question.id))"
        
        // Controlli base
        guard !question.id.isEmpty else {
            throw MateriaError.invalidQuestionStructure("\(questionPrefix): id vuoto")
        }
        guard !question.category.isEmpty else {
            throw MateriaError.invalidQuestionStructure("\(questionPrefix): category vuoto")
        }
        guard !question.prompt.isEmpty else {
            throw MateriaError.invalidQuestionStructure("\(questionPrefix): prompt vuoto")
        }
        
        // Verifica che la categoria esista nella taxonomy
        guard validCategories.contains(question.category) else {
            throw MateriaError.invalidQuestionStructure("\(questionPrefix): category '\(question.category)' non trovata in taxonomy")
        }
        
        // Validazione specifica per tipo di domanda
        switch question.kind {
        case .multiple:
            guard let options = question.options, !options.isEmpty else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'multiple' deve avere options non vuote")
            }
            
            let correctCount = options.filter { $0.isCorrect }.count
            guard correctCount > 0 else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'multiple' deve avere almeno una risposta corretta")
            }
            
            for (optIndex, option) in options.enumerated() {
                guard !option.text.isEmpty else {
                    throw MateriaError.invalidQuestionStructure("\(questionPrefix): options[\(optIndex)].text è vuoto")
                }
            }
            
        case .matching:
            guard let left = question.left, !left.isEmpty else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'matching' deve avere leftColumn non vuoto")
            }
            guard let right = question.right, !right.isEmpty else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'matching' deve avere rightColumn non vuoto")
            }
            guard let matches = question.correctMatches, !matches.isEmpty else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'matching' deve avere correctMatches non vuoto")
            }
            
            // Verifica che gli indici dei match siano validi
            for (leftIdx, rightIdx) in matches {
                guard leftIdx >= 0 && leftIdx < left.count else {
                    throw MateriaError.invalidQuestionStructure("\(questionPrefix): indice leftColumn \(leftIdx) non valido")
                }
                guard rightIdx >= 0 && rightIdx < right.count else {
                    throw MateriaError.invalidQuestionStructure("\(questionPrefix): indice rightColumn \(rightIdx) non valido")
                }
            }
        }
    }
}

/// Valida e aggiorna l'hash
private func validateAndUpdateHash(_ materia: Materia, originalData: Data) throws -> Materia {
    var updatedMateria = materia
    
    // --- Calcolo hash ignorando il campo subject_id ---
    var jsonObj = try JSONSerialization.jsonObject(with: originalData) as! [String: Any]
    if var meta = jsonObj["meta"] as? [String: Any] {
        meta["subject_id"] = ""   // annulliamo l'id per calcolare hash "canonico"
        jsonObj["meta"] = meta
    }
    let canon = try JSONSerialization.data(withJSONObject: jsonObj, options: [.sortedKeys])
    let expectHash = sha256Hex(of: canon)

    // --- Gestione subject_id ---
    if materia.meta.subject_id == "auto:sha256" {
        updatedMateria.meta.subject_id = expectHash
    } else {
        guard materia.meta.subject_id == expectHash else { 
            throw MateriaError.invalidHash 
        }
    }
    
    return updatedMateria
}
