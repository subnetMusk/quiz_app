//
//  MateriaModels.swift
//  quiz_app
//
//  Created by Leonardo Soligo on 9/1/25.
//

import Foundation

// MARK: - Quiz modes (Core types)

enum QuizSessionMode: String, CaseIterable, Identifiable {
    case generic = "Generico"
    case byCategory = "Per categoria"
    case errors = "Errori"
    case errorsByCategory = "Errori per categoria"
    case smart = "Ripasso intelligente"
    /// Flusso Teoria→Quiz: domande chiave (`primary`) dell'argomento + le più sbagliate.
    case topicPrimary = "Per argomento"

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
    /// Notebook di sola teoria, uno per argomento della tassonomia (facoltativo).
    var theory: [TheoryNote]? = nil
}

/// Notebook di teoria per un argomento (stessa divisione della tassonomia delle domande).
struct TheoryNote: Codable, Identifiable, Equatable {
    /// Combacia con `Materia.Node.id` (la categoria delle domande).
    var categoryId: String
    var title: String
    /// Riga/paragrafo introduttivo breve (per card e schermata iniziale della modalità guidata).
    var intro: String? = nil
    /// Corpo in Markdown del notebook intero, pronto per la lettura ("Leggi tutto").
    var body: String
    /// Sezioni ordinate (dal generale allo specifico) per la modalità di studio guidata.
    var sections: [TheorySection]? = nil
    /// Minuti di lettura stimati (facoltativo).
    var estimatedMinutes: Int? = nil

    var id: String { categoryId }
}

/// Sezione di un notebook: blocco di teoria mirato a un sotto-concetto, usato dalla modalità guidata.
struct TheorySection: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    /// Riga breve per le card/anteprime (facoltativa).
    var summary: String? = nil
    /// Prosa markdown della sezione (riempita in seguito; renderizzata col renderer a blocchi).
    var body: String
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
            case .generic, .errors, .smart:
                return materia.questions.count
            case .byCategory, .errorsByCategory, .topicPrimary:
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
    // Tipi generali introdotti per riuso multi-disciplinare (il dominio sta nei dati, non nel kind).
    case trueFalseMotivated
    case clozeWordBank
    case shortAnswer
    case ordered
    case calculation
    // Fase 2: tipi "aperti" (formativi) e compositi
    case openRubric
    case constructedResponse
    case mediaAnalysis
    case caseStudy
}

public extension QuestionKind {
    /// Nome leggibile (usato nelle statistiche e nelle etichette UI).
    var displayName: String {
        switch self {
        case .multiple:            return "Scelta multipla"
        case .matching:            return "Abbinamento"
        case .trueFalseMotivated:  return "Vero/Falso motivato"
        case .clozeWordBank:       return "Testo bucato"
        case .shortAnswer:         return "Risposta breve"
        case .ordered:             return "Riordino"
        case .calculation:         return "Calcolo"
        case .openRubric:          return "Risposta aperta"
        case .constructedResponse: return "Produzione guidata"
        case .mediaAnalysis:       return "Analisi di un media"
        case .caseStudy:           return "Caso di studio"
        }
    }

    /// Tipi "atomici" che possono comparire come sotto-domanda di un caso/media.
    var isComposite: Bool { self == .caseStudy || self == .mediaAnalysis }

    /// Tipi puramente formativi: mostrano una rubrica ma non producono un esito valutabile.
    var isFormativeAnswer: Bool { self == .openRubric || self == .constructedResponse }
}

public struct Option: Codable, Identifiable, Hashable, Equatable {
    public var id: Int
    public var text: String
    public var isCorrect: Bool
}

/// Singolo "buco" di una domanda `clozeWordBank`.
/// `answers` elenca le risposte accettate (la prima è quella mostrata come soluzione).
public struct Blank: Codable, Identifiable, Hashable, Equatable {
    public var id: Int
    public var answers: [String]
}

/// Asset multimediale allegato a uno stimolo o a una domanda `mediaAnalysis`.
/// Va indicato `url` (remoto) **oppure** `asset` (nome file locale in bundle/Documents).
public struct MediaAsset: Codable, Hashable, Equatable {
    public enum Kind: String, Codable, Equatable {
        case image, audio, video, document
    }
    public var type: Kind
    public var url: String? = nil      // risorsa remota
    public var asset: String? = nil    // nome file locale (bundle o cartella Documents)
    public var alt: String? = nil      // descrizione accessibile (VoiceOver)
    public var caption: String? = nil  // didascalia mostrata sotto il media
}

/// Stimolo comune di un caso di studio: può contenere testo, codice e/o un media.
public struct Stimulus: Codable, Identifiable, Hashable, Equatable {
    public var id: String
    public var title: String? = nil
    public var text: String? = nil
    public var code: String? = nil
    public var media: MediaAsset? = nil
}

// MARK: - Pool di opzioni randomizzate (risposte aperte/ragionate)

/// Tipo di distrattore di una frase candidata. Serve solo a categorizzare le varianti
/// (statistiche/autoraggruppamento), non viene mostrato all'utente.
public enum PoolVariantKind: String, Codable, Hashable, Equatable {
    case correctParaphrase     // parafrasi corretta del concetto
    case tooAbsolute           // vera in parte ma troppo assoluta
    case incomplete            // corretta ma insufficiente
    case causalError           // nesso causale sbagliato
    case relatedButIrrelevant  // correlata ma non pertinente
    case wrongScope            // corretta ma riferita a uno scope diverso
    case oppositeDirection     // direzione/verso del ragionamento invertito
    case other
}

/// Una frase candidata del pool. Più entry possono condividere lo stesso `canonicalPointId`
/// (varianti dello stesso concetto): di default non se ne mostra più di una per campione.
public struct PoolEntry: Codable, Identifiable, Hashable, Equatable {
    public var id: String
    public var text: String
    public var isCorrect: Bool
    public var canonicalPointId: String
    public var variantKind: PoolVariantKind? = nil
    public var explanation: String? = nil
}

public extension PoolEntry {
    /// Prefissi-cornice usati nei dati come varianti di parafrasi; in UI vanno tolti per frasi dirette.
    private static let framingPrefixes = [
        "La formulazione sostiene che ",
        "Il punto da valutare è che ",
        "La formulazione descrive ",
        "La formulazione afferma che "
    ]

    /// Testo "diretto" da mostrare: rimuove il prefisso-cornice e ripristina la maiuscola iniziale
    /// (i prefissi minuscolizzavano la prima lettera, es. "…che gET…" → "GET…").
    var displayText: String {
        var t = text
        for p in PoolEntry.framingPrefixes where t.hasPrefix(p) {
            t = String(t.dropFirst(p.count))
            break
        }
        guard let first = t.first else { return t }
        return first.uppercased() + t.dropFirst()
    }
}

/// Intervallo chiuso `[min, max]` per il numero di corrette da mostrare.
public struct CountRange: Codable, Hashable, Equatable {
    public var min: Int
    public var max: Int
    public init(min: Int, max: Int) { self.min = min; self.max = max }
}

/// Pool da cui campionare un sottoinsieme di opzioni a ogni attempt.
/// Le opzioni mostrate sono poche (`displayCount`) e il numero di corrette varia entro `correctCountRange`.
public struct AnswerOptionPool: Codable, Hashable, Equatable {
    public var displayCount: Int
    public var correctCountRange: CountRange
    public var entries: [PoolEntry]
    /// Se `true`, consente più varianti dello stesso `canonicalPointId` nello stesso campione.
    public var allowDuplicateConcepts: Bool? = nil

    public init(displayCount: Int, correctCountRange: CountRange, entries: [PoolEntry], allowDuplicateConcepts: Bool? = nil) {
        self.displayCount = displayCount
        self.correctCountRange = correctCountRange
        self.entries = entries
        self.allowDuplicateConcepts = allowDuplicateConcepts
    }
}

public struct Question: Codable, Identifiable, Hashable, Equatable {
    public var id: String
    public var category: String
    public var subcategory: String?
    public var kind: QuestionKind
    /// Domanda "chiave" dell'argomento: usata dal flusso Teoria→Quiz (facoltativo).
    public var primary: Bool? = nil
    /// Sezione di teoria a cui la domanda è collegata (modalità guidata; combacia con `TheorySection.id`).
    public var sectionId: String? = nil
    /// Difficoltà 1 (base) … 3 (avanzato), per la progressione nella modalità guidata.
    public var difficulty: Int? = nil
    public var prompt: String
    public var code: String?              // opzionale (blocchi di codice)
    public var explanation: String?       // opzionale (spiegazione mostrata nel feedback)
    // multiple
    public var options: [Option]?
    // matching
    public var left: [String]?
    public var right: [String]?
    public var correctMatches: [Int:Int]?
    // trueFalseMotivated
    public var answer: Bool? = nil                    // valore V/F corretto
    public var motivationOptions: [Option]? = nil     // motivazioni (scelta multipla sullo step 2)
    public var wrongAnswerExplanation: String? = nil  // feedback immediato se sbaglia il V/F
    // clozeWordBank
    public var text: String? = nil                    // testo con placeholder {{id}}
    public var blanks: [Blank]? = nil
    public var wordBank: [String]? = nil
    public var shuffleWordBank: Bool? = nil
    public var reuseWords: Bool? = nil
    // shortAnswer / calculation (condivisi)
    public var acceptedAnswers: [String]? = nil       // risposte/sinonimi accettati
    public var caseSensitive: Bool? = nil             // default: false (case-insensitive)
    // calculation
    public var givens: [String]? = nil                // dati iniziali mostrati
    public var answerFormat: String? = nil            // suggerimento di formato
    public var tolerance: Double? = nil               // tolleranza numerica opzionale
    public var expectedSteps: [String]? = nil         // passaggi attesi (mostrati nel feedback)
    // ordered
    public var items: [String]? = nil                 // elementi nell'ordine CORRETTO (indice = posizione giusta)
    // openRubric (formativo)
    public var expectedAnswer: String? = nil          // risposta attesa / modello
    public var keyPoints: [String]? = nil             // punti chiave della rubrica
    public var minKeyPoints: Int? = nil               // numero minimo di punti chiave atteso
    public var commonMistakes: [String]? = nil        // errori comuni da evitare
    public var showRubricAfter: Bool? = nil           // se true, la rubrica appare solo dopo la risposta
    // constructedResponse (formativo)
    public var requiredCriteria: [String]? = nil      // requisiti obbligatori (checklist)
    public var optionalCriteria: [String]? = nil      // requisiti facoltativi
    public var blockingErrors: [String]? = nil        // errori bloccanti
    public var sampleSolution: String? = nil          // esempio di soluzione
    // mediaAnalysis
    public var media: MediaAsset? = nil               // stimolo multimediale primario
    // caseStudy / mediaAnalysis (compositi)
    public var stimuli: [Stimulus]? = nil             // stimoli comuni (testo/codice/media)
    public var subquestions: [Question]? = nil        // sotto-domande (riusano i tipi atomici)
    // Pool randomizzato per risposte aperte/ragionate (trueFalseMotivated, openRubric, constructedResponse).
    // Se presente, ha la precedenza sulle liste statiche legacy (es. `motivationOptions`).
    public var optionPool: AnswerOptionPool? = nil
}

public extension Question {
    /// `true` se la domanda è puramente formativa (non concorre a statistiche/SM-2 né al punteggio
    /// di sessione). Un caso/media è formativo solo se TUTTE le sue sotto-domande lo sono.
    var isFormative: Bool {
        // Una domanda "aperta" con una checklist di correzione (optionPool) è ora valutabile:
        // resta puramente formativa solo se non ha alcun pool su cui calcolare un esito.
        if kind.isFormativeAnswer { return optionPool == nil }
        if kind.isComposite {
            let subs = subquestions ?? []
            return subs.isEmpty ? true : subs.allSatisfy { $0.isFormative }
        }
        return false
    }
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

    /// Domande candidate per il flusso Teoria→Quiz:
    /// domande curate come `primary` più domande della categoria con errori sopra soglia dinamica.
    func topicPrimaryCandidates(category id: String, wrongCounts: [String: Int]) -> [Question] {
        let pool = questions(category: id)
        let positiveWrongs = pool.compactMap { wrongCounts[$0.id] }.filter { $0 > 0 }
        let threshold = dynamicWrongThreshold(positiveWrongs)

        return pool
            .filter { q in
                let wrong = wrongCounts[q.id] ?? 0
                return q.primary == true || (wrong > 0 && wrong >= threshold)
            }
            .sorted { lhs, rhs in
                let lw = wrongCounts[lhs.id] ?? 0
                let rw = wrongCounts[rhs.id] ?? 0
                if lw != rw { return lw > rw }
                if (lhs.primary == true) != (rhs.primary == true) {
                    return lhs.primary == true
                }
                return lhs.id < rhs.id
            }
    }

    private func dynamicWrongThreshold(_ wrongs: [Int]) -> Int {
        guard !wrongs.isEmpty else { return Int.max }
        let average = Double(wrongs.reduce(0, +)) / Double(wrongs.count)
        return max(1, Int(average.rounded(.up)))
    }
    
    /// Restituisce l'elenco delle categorie disponibili
    var categories: [String] {
        return taxonomy.map { $0.id }
    }
}
