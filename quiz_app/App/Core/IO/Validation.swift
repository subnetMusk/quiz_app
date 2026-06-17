//
//  Validation.swift
//  quiz_app
//
//  Created by Leonardo Soligo on 9/1/25.
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

    // Validazione teoria opzionale
    try validateTheoryStructure(materia.theory, taxonomy: materia.taxonomy)
    
    // Validazione domande
    try validateQuestionsStructure(materia.questions, taxonomy: materia.taxonomy)

    // Validazione collegamenti modalità guidata (sectionId/difficulty)
    try validateGuidedLinks(materia.questions, theory: materia.theory)

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

/// Valida i notebook di teoria opzionali.
private func validateTheoryStructure(_ theory: [TheoryNote]?, taxonomy: [Materia.Node]) throws {
    guard let theory else { return }
    let validCategories = Set(taxonomy.map { $0.id })
    var seen = Set<String>()

    for (index, note) in theory.enumerated() {
        let prefix = "theory[\(index)]"
        guard !note.categoryId.isEmpty else {
            throw MateriaError.invalidQuestionStructure("\(prefix): categoryId vuoto")
        }
        guard validCategories.contains(note.categoryId) else {
            throw MateriaError.invalidQuestionStructure("\(prefix): categoryId '\(note.categoryId)' non trovato in taxonomy")
        }
        guard seen.insert(note.categoryId).inserted else {
            throw MateriaError.invalidQuestionStructure("\(prefix): notebook duplicato per categoryId '\(note.categoryId)'")
        }
        guard !note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MateriaError.invalidQuestionStructure("\(prefix): title vuoto")
        }
        guard !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MateriaError.invalidQuestionStructure("\(prefix): body vuoto")
        }
        if let minutes = note.estimatedMinutes, minutes < 1 {
            throw MateriaError.invalidQuestionStructure("\(prefix): estimatedMinutes deve essere positivo")
        }
        // Sezioni (modalità guidata): id non vuoto/unico, title e body non vuoti.
        if let sections = note.sections {
            var sectionIds = Set<String>()
            for (si, sec) in sections.enumerated() {
                let sp = "\(prefix).sections[\(si)]"
                guard !sec.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw MateriaError.invalidQuestionStructure("\(sp): id vuoto")
                }
                guard sectionIds.insert(sec.id).inserted else {
                    throw MateriaError.invalidQuestionStructure("\(sp): id sezione duplicato '\(sec.id)'")
                }
                guard !sec.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw MateriaError.invalidQuestionStructure("\(sp): title vuoto")
                }
                guard !sec.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw MateriaError.invalidQuestionStructure("\(sp): body vuoto")
                }
            }
        }
    }
}

/// Valida i collegamenti della modalità guidata: `difficulty` in 1...3 e `sectionId` esistente
/// nella teoria della stessa categoria.
private func validateGuidedLinks(_ questions: [Question], theory: [TheoryNote]?) throws {
    var sectionsByCategory: [String: Set<String>] = [:]
    for note in theory ?? [] {
        sectionsByCategory[note.categoryId] = Set((note.sections ?? []).map { $0.id })
    }
    for (i, q) in questions.enumerated() {
        if let d = q.difficulty, !(1...3).contains(d) {
            throw MateriaError.invalidQuestionStructure("questions[\(i)] (\(q.id)): difficulty \(d) fuori range 1...3")
        }
        if let sid = q.sectionId {
            let valid = sectionsByCategory[q.category] ?? []
            guard valid.contains(sid) else {
                throw MateriaError.invalidQuestionStructure("questions[\(i)] (\(q.id)): sectionId '\(sid)' non esiste nella teoria della categoria '\(q.category)'")
            }
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
        
        // Validazione specifica per tipo di domanda (compositi ammessi al livello top)
        try validateAnswerSpecific(question, prefix: questionPrefix, allowComposite: true)
    }
}

/// Valida i campi specifici per il tipo di domanda. Riusata anche per le sotto-domande
/// di `caseStudy`/`mediaAnalysis` (con `allowComposite: false`, niente annidamento di compositi).
private func validateAnswerSpecific(_ question: Question, prefix questionPrefix: String, allowComposite: Bool) throws {
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

        case .trueFalseMotivated:
            guard question.answer != nil else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'trueFalseMotivated' deve avere il campo 'answer' (true/false)")
            }
            // Il pool randomizzato, se presente, ha la precedenza sulle motivazioni statiche.
            try validateOptionPool(question.optionPool, prefix: "\(questionPrefix).optionPool")
            // Le motivazioni statiche (legacy) sono facoltative; se presenti devono essere valide.
            if let opts = question.motivationOptions, !opts.isEmpty {
                guard opts.contains(where: { $0.isCorrect }) else {
                    throw MateriaError.invalidQuestionStructure("\(questionPrefix): 'motivationOptions' deve contenere almeno una motivazione corretta")
                }
                for (i, o) in opts.enumerated() where o.text.isEmpty {
                    throw MateriaError.invalidQuestionStructure("\(questionPrefix): motivationOptions[\(i)].text è vuoto")
                }
            }

        case .clozeWordBank:
            guard let text = question.text, !text.isEmpty else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'clozeWordBank' deve avere 'text' non vuoto")
            }
            guard let blanks = question.blanks, !blanks.isEmpty else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'clozeWordBank' deve avere 'blanks' non vuoto")
            }
            guard let wordBank = question.wordBank, !wordBank.isEmpty else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'clozeWordBank' deve avere 'wordBank' non vuoto")
            }
            let cs = question.caseSensitive ?? false
            let bankNorm = Set(wordBank.map { cs ? $0 : $0.lowercased() })
            for b in blanks {
                guard !b.answers.isEmpty else {
                    throw MateriaError.invalidQuestionStructure("\(questionPrefix): blank id \(b.id) non ha risposte ('answers' vuoto)")
                }
                guard text.contains("{{\(b.id)}}") else {
                    throw MateriaError.invalidQuestionStructure("\(questionPrefix): manca il segnaposto '{{\(b.id)}}' nel testo per il blank id \(b.id)")
                }
                // Almeno una risposta corretta dev'essere selezionabile dalla word bank.
                let selectable = b.answers.contains { bankNorm.contains(cs ? $0 : $0.lowercased()) }
                guard selectable else {
                    throw MateriaError.invalidQuestionStructure("\(questionPrefix): nessuna risposta del blank id \(b.id) è presente nella 'wordBank'")
                }
            }

        case .shortAnswer:
            guard let accepted = question.acceptedAnswers, !accepted.isEmpty else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'shortAnswer' deve avere 'acceptedAnswers' non vuoto")
            }
            for (i, a) in accepted.enumerated() where a.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): acceptedAnswers[\(i)] è vuoto")
            }

        case .ordered:
            guard let items = question.items, items.count >= 2 else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'ordered' deve avere almeno 2 'items'")
            }
            for (i, it) in items.enumerated() where it.isEmpty {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): items[\(i)] è vuoto")
            }

        case .calculation:
            guard let accepted = question.acceptedAnswers, !accepted.isEmpty else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'calculation' deve avere 'acceptedAnswers' non vuoto")
            }
            for (i, a) in accepted.enumerated() where a.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): acceptedAnswers[\(i)] è vuoto")
            }

        case .openRubric:
            let hasExpected = !(question.expectedAnswer ?? "").isEmpty
            let hasKeyPoints = !(question.keyPoints ?? []).isEmpty
            let hasPool = question.optionPool != nil
            guard hasExpected || hasKeyPoints || hasPool else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'openRubric' deve avere almeno 'expectedAnswer', 'keyPoints' o 'optionPool'")
            }
            if let minKP = question.minKeyPoints {
                let kpCount = (question.keyPoints ?? []).count
                guard minKP >= 0, minKP <= kpCount else {
                    throw MateriaError.invalidQuestionStructure("\(questionPrefix): 'minKeyPoints' (\(minKP)) deve essere tra 0 e il numero di 'keyPoints' (\(kpCount))")
                }
            }
            try validateOptionPool(question.optionPool, prefix: "\(questionPrefix).optionPool")

        case .constructedResponse:
            let hasCriteria = !(question.requiredCriteria ?? []).isEmpty
            let hasPool = question.optionPool != nil
            guard hasCriteria || hasPool else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'constructedResponse' deve avere 'requiredCriteria' o 'optionPool'")
            }
            for (i, c) in (question.requiredCriteria ?? []).enumerated() where c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): requiredCriteria[\(i)] è vuoto")
            }
            try validateOptionPool(question.optionPool, prefix: "\(questionPrefix).optionPool")

        case .mediaAnalysis:
            guard allowComposite else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): 'mediaAnalysis' non può essere annidato come sotto-domanda")
            }
            guard let media = question.media else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'mediaAnalysis' deve avere il campo 'media'")
            }
            try validateMedia(media, prefix: "\(questionPrefix).media")
            let subs = question.subquestions ?? []
            guard !subs.isEmpty else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'mediaAnalysis' deve avere almeno una 'subquestions'")
            }
            try validateSubquestions(subs, prefix: questionPrefix)

        case .caseStudy:
            guard allowComposite else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): 'caseStudy' non può essere annidato come sotto-domanda")
            }
            let subs = question.subquestions ?? []
            guard !subs.isEmpty else {
                throw MateriaError.invalidQuestionStructure("\(questionPrefix): domanda 'caseStudy' deve avere almeno una 'subquestions'")
            }
            if let stimuli = question.stimuli {
                for (i, s) in stimuli.enumerated() {
                    let hasContent = !(s.text ?? "").isEmpty || !(s.code ?? "").isEmpty || s.media != nil
                    guard hasContent else {
                        throw MateriaError.invalidQuestionStructure("\(questionPrefix): stimuli[\(i)] è vuoto (serve text, code o media)")
                    }
                    if let m = s.media { try validateMedia(m, prefix: "\(questionPrefix).stimuli[\(i)].media") }
                }
            }
            try validateSubquestions(subs, prefix: questionPrefix)
        }
}

/// Valida le sotto-domande di un composito: prompt non vuoto, niente compositi annidati,
/// e campi specifici del tipo corretti.
private func validateSubquestions(_ subs: [Question], prefix: String) throws {
    for (i, sub) in subs.enumerated() {
        let subPrefix = "\(prefix).subquestions[\(i)] (id: \(sub.id))"
        guard !sub.id.isEmpty else {
            throw MateriaError.invalidQuestionStructure("\(subPrefix): id vuoto")
        }
        guard !sub.prompt.isEmpty else {
            throw MateriaError.invalidQuestionStructure("\(subPrefix): prompt vuoto")
        }
        try validateAnswerSpecific(sub, prefix: subPrefix, allowComposite: false)
    }
}

/// Valida un pool di opzioni randomizzate (se presente), traducendo l'eventuale `PoolError`.
private func validateOptionPool(_ pool: AnswerOptionPool?, prefix: String) throws {
    guard let pool else { return }
    if let err = PoolSampler.validationError(pool) {
        throw MateriaError.invalidQuestionStructure("\(prefix): \(err.description)")
    }
}

/// Valida un asset multimediale: deve avere un riferimento (url o asset locale).
private func validateMedia(_ media: MediaAsset, prefix: String) throws {
    let hasURL = !(media.url ?? "").isEmpty
    let hasAsset = !(media.asset ?? "").isEmpty
    guard hasURL || hasAsset else {
        throw MateriaError.invalidQuestionStructure("\(prefix): l'asset deve indicare 'url' (remoto) oppure 'asset' (file locale)")
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
