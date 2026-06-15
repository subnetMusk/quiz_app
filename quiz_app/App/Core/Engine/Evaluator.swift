//
//  Evaluator.swift
//  quiz_app
//
//  Created by Leonardo Soligo on 9/1/25.
//

import Foundation

// Risultato della risposta utente a una domanda
public enum AnswerResult: Equatable {
    case correct
    case incomplete
    case wrong
}

// Dettaglio per domande multiple: serve ad aggiornare le statistiche
public struct EvalDetail: Equatable {
    public let result: AnswerResult
    public let missedCorrect: [Int]   // opzioni corrette NON selezionate (→ giallo)
    public let wrongPicked: [Int]     // opzioni errate selezionate (→ rosso)
    public init(result: AnswerResult, missedCorrect: [Int] = [], wrongPicked: [Int] = []) {
        self.result = result
        self.missedCorrect = missedCorrect
        self.wrongPicked = wrongPicked
    }
}

/// Valuta una domanda multiple in base alle opzioni selezionate.
/// Regole:
/// - se l'utente seleziona almeno un'opzione errata → .wrong
/// - se seleziona esattamente tutte e sole le corrette → .correct
/// - altrimenti → .incomplete (sottoinsieme delle corrette o vuoto)
public func evaluateMultiple(question: Question, selected: Set<Int>) -> EvalDetail {
    let opts = question.options ?? []
    let correct = Set(opts.filter { $0.isCorrect }.map { $0.id })
    let wrong   = Set(opts.filter { !$0.isCorrect }.map { $0.id })

    // calcolo dei dettagli per le statistiche
    let missed = Array(correct.subtracting(selected)).sorted()
    let wrongSel = Array(selected.intersection(wrong)).sorted()

    let result: AnswerResult
    if !wrongSel.isEmpty {
        result = .wrong
    } else if selected == correct {
        result = .correct
    } else if selected.isEmpty {
        // Se non è stata selezionata nessuna opzione, considera la risposta sbagliata
        result = .wrong
    } else {
        result = .incomplete
    }

    return EvalDetail(result: result, missedCorrect: missed, wrongPicked: wrongSel)
}

/// Valuta una domanda matching.
/// Regole:
/// - se un accoppiamento dato non coincide → .wrong
/// - se tutti i corretti sono presenti → .correct
/// - se non è stato fatto nessun accoppiamento → .wrong
/// - altrimenti → .incomplete
public func evaluateMatching(question: Question, userPairs: [Int:Int]) -> AnswerResult {
    guard let gold = question.correctMatches, !gold.isEmpty else { return .correct }
    
    // Se non ci sono accoppiamenti fatti dall'utente, è sbagliato
    if userPairs.isEmpty {
        return .wrong
    }
    
    for (l, r) in userPairs {
        if gold[l] != r { return .wrong }
    }
    return userPairs.count == gold.count ? .correct : .incomplete
}

// MARK: - Nuovi tipi (Fase 1)

/// Normalizza una stringa per il confronto: trim degli spazi e, se non case-sensitive, lowercase.
private func normalizeAnswer(_ s: String, caseSensitive: Bool) -> String {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    return caseSensitive ? trimmed : trimmed.lowercased()
}

/// Prova a interpretare una stringa come numero (accetta sia "," sia "." come separatore decimale).
private func parseNumber(_ s: String) -> Double? {
    let cleaned = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    return Double(cleaned)
}

/// Valuta una domanda `trueFalseMotivated` (due step).
/// - se il valore V/F è sbagliato → `.wrong` (le motivazioni non contano);
/// - se il V/F è giusto, la motivazione viene valutata come una scelta multipla:
///   tutte e sole le corrette → `.correct`; sottoinsieme → `.incomplete`; opzione errata o vuota → `.wrong`.
/// La domanda è corretta solo se V/F **e** motivazione sono corretti.
public func evaluateTrueFalseMotivated(question: Question, answer: Bool, motivation: Set<Int>) -> AnswerResult {
    guard let correctAnswer = question.answer else { return .wrong }
    if answer != correctAnswer { return .wrong }

    let opts = question.motivationOptions ?? []
    guard !opts.isEmpty else { return .correct } // nessuna motivazione richiesta

    let correct = Set(opts.filter { $0.isCorrect }.map { $0.id })
    let wrong   = Set(opts.filter { !$0.isCorrect }.map { $0.id })

    if !motivation.isDisjoint(with: wrong) { return .wrong }
    if motivation == correct { return .correct }
    if motivation.isEmpty { return .wrong }
    return .incomplete
}

/// Dettaglio della valutazione di una domanda `clozeWordBank`.
public struct ClozeDetail: Equatable {
    public let result: AnswerResult
    public let wrongBlanks: [Int]   // buchi riempiti in modo errato
    public let missedBlanks: [Int]  // buchi lasciati vuoti
}

/// Valuta un testo bucato confrontando ogni buco con le risposte accettate (normalizzate).
/// `.wrong` se almeno un buco riempito è errato o se nessun buco è corretto; `.correct` se tutti
/// i buchi sono corretti; `.incomplete` se i buchi riempiti sono corretti ma alcuni restano vuoti.
public func evaluateCloze(question: Question, filled: [Int: String]) -> ClozeDetail {
    let blanks = question.blanks ?? []
    guard !blanks.isEmpty else { return ClozeDetail(result: .correct, wrongBlanks: [], missedBlanks: []) }
    let cs = question.caseSensitive ?? false

    var wrong: [Int] = []
    var missed: [Int] = []
    var correctCount = 0
    for b in blanks {
        let given = normalizeAnswer(filled[b.id] ?? "", caseSensitive: cs)
        if given.isEmpty { missed.append(b.id); continue }
        let ok = b.answers.contains { normalizeAnswer($0, caseSensitive: cs) == given }
        if ok { correctCount += 1 } else { wrong.append(b.id) }
    }

    let result: AnswerResult
    if !wrong.isEmpty {
        result = .wrong
    } else if correctCount == blanks.count {
        result = .correct
    } else if correctCount == 0 {
        result = .wrong
    } else {
        result = .incomplete
    }
    return ClozeDetail(result: result, wrongBlanks: wrong.sorted(), missedBlanks: missed.sorted())
}

/// Valuta una risposta breve contro `acceptedAnswers` (trim + case-insensitive opzionale).
/// `.correct` se combacia con una delle alternative, altrimenti `.wrong` (vuoto → `.wrong`).
public func evaluateShortAnswer(question: Question, text: String) -> AnswerResult {
    let cs = question.caseSensitive ?? false
    let given = normalizeAnswer(text, caseSensitive: cs)
    guard !given.isEmpty else { return .wrong }
    let accepted = (question.acceptedAnswers ?? []).map { normalizeAnswer($0, caseSensitive: cs) }
    return accepted.contains(given) ? .correct : .wrong
}

/// Dettaglio della valutazione di una domanda `ordered`.
public struct OrderedDetail: Equatable {
    public let result: AnswerResult
    public let misplaced: [Int] // posizioni (0-based) il cui elemento è fuori posto
}

/// Valuta un riordinamento. `userOrder` è la sequenza di indici elemento nell'ordine scelto;
/// l'ordine corretto è `[0, 1, 2, …]` (gli `items` sono già nell'ordine giusto).
/// Tutto a posto → `.correct`; nulla a posto → `.wrong`; parziale → `.incomplete`.
public func evaluateOrdered(question: Question, userOrder: [Int]) -> OrderedDetail {
    let n = (question.items ?? []).count
    guard n > 0 else { return OrderedDetail(result: .correct, misplaced: []) }
    guard userOrder.count == n else {
        return OrderedDetail(result: .wrong, misplaced: Array(0..<n))
    }
    let misplaced = (0..<n).filter { userOrder[$0] != $0 }
    let result: AnswerResult
    if misplaced.isEmpty {
        result = .correct
    } else if misplaced.count == n {
        result = .wrong
    } else {
        result = .incomplete
    }
    return OrderedDetail(result: result, misplaced: misplaced)
}

/// Valuta una domanda `calculation`. Se è definita una `tolerance` e sia la risposta utente sia
/// almeno una delle risposte accettate sono numeriche, confronta con tolleranza assoluta;
/// altrimenti confronta come stringa normalizzata. Vuoto → `.wrong`.
public func evaluateCalculation(question: Question, text: String) -> AnswerResult {
    let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else { return .wrong }
    let accepted = question.acceptedAnswers ?? []

    if let tol = question.tolerance, let given = parseNumber(raw) {
        for a in accepted {
            if let ax = parseNumber(a), abs(ax - given) <= tol { return .correct }
        }
    }

    let cs = question.caseSensitive ?? false
    let given = normalizeAnswer(raw, caseSensitive: cs)
    return accepted.map { normalizeAnswer($0, caseSensitive: cs) }.contains(given) ? .correct : .wrong
}

// MARK: - Input unificato e dispatcher (usato dalle sotto-domande di caso/media)

/// Raccolta di tutti i possibili input utente per una domanda atomica.
/// Permette di valutare una sotto-domanda di qualunque tipo senza duplicare lo stato.
public struct AnswerInput: Equatable {
    public var selectedOptions = Set<Int>()
    public var userPairs: [Int: Int] = [:]
    public var tfAnswer: Bool? = nil
    public var tfMotivation = Set<Int>()
    public var clozeFilled: [Int: String] = [:]
    public var text: String = ""
    public var userOrder: [Int] = []
    public var poolSelected: Set<String> = []   // selezione sul campione del pool (id entry)
    public init() {}
}

/// Valuta una domanda **atomica** a partire dall'input unificato.
/// I tipi formativi e compositi non sono valutabili qui (gestiti a livello di sessione).
public func evaluate(_ q: Question, input: AnswerInput) -> AnswerResult {
    switch q.kind {
    case .multiple:
        return evaluateMultiple(question: q, selected: input.selectedOptions).result
    case .matching:
        return evaluateMatching(question: q, userPairs: input.userPairs)
    case .trueFalseMotivated:
        guard let a = input.tfAnswer else { return .wrong }
        return evaluateTrueFalseMotivated(question: q, answer: a, motivation: input.tfMotivation)
    case .clozeWordBank:
        return evaluateCloze(question: q, filled: input.clozeFilled).result
    case .shortAnswer:
        return evaluateShortAnswer(question: q, text: input.text)
    case .ordered:
        return evaluateOrdered(question: q, userOrder: input.userOrder).result
    case .calculation:
        return evaluateCalculation(question: q, text: input.text)
    case .openRubric, .constructedResponse, .mediaAnalysis, .caseStudy:
        // Non valutabili come atomiche: vedi `aggregateResults` per i compositi.
        return .incomplete
    }
}

/// Aggrega i risultati delle sotto-domande di un caso/media in un unico esito.
/// Tutte corrette → `.correct`; tutte sbagliate → `.wrong`; situazioni miste → `.incomplete`.
public func aggregateResults(_ results: [AnswerResult]) -> AnswerResult {
    guard !results.isEmpty else { return .incomplete }
    let correct = results.filter { $0 == .correct }.count
    let wrong = results.filter { $0 == .wrong }.count
    if correct == results.count { return .correct }
    if wrong == results.count { return .wrong }
    return .incomplete
}

// MARK: - Pool di opzioni randomizzate

public enum PoolError: Error, Equatable, CustomStringConvertible {
    case displayCountNotPositive
    case invalidRange
    case emptyText
    case duplicateEntryId(String)
    case emptyCanonicalPointId(String)
    case notEnoughCorrectConcepts(have: Int, needMin: Int)
    case notEnoughWrongConcepts(have: Int, needMin: Int)
    case poolTooSmall(distinctConcepts: Int, displayCount: Int)
    case cannotProduceSample

    public var description: String {
        switch self {
        case .displayCountNotPositive: return "displayCount deve essere > 0"
        case .invalidRange: return "correctCountRange non valido (richiede 0 <= min <= max <= displayCount)"
        case .emptyText: return "una entry ha 'text' vuoto"
        case .duplicateEntryId(let id): return "id entry duplicato: '\(id)'"
        case .emptyCanonicalPointId(let id): return "entry '\(id)' ha 'canonicalPointId' vuoto"
        case .notEnoughCorrectConcepts(let have, let needMin):
            return "concetti corretti insufficienti: \(have) disponibili, ne servono almeno \(needMin)"
        case .notEnoughWrongConcepts(let have, let needMin):
            return "concetti errati insufficienti: \(have) disponibili, ne servono almeno \(needMin)"
        case .poolTooSmall(let d, let n):
            return "pool troppo piccolo: \(d) concetti distinti per \(n) opzioni da mostrare"
        case .cannotProduceSample:
            return "il pool non può produrre un campione valido rispettando vincoli e unicità dei concetti"
        }
    }
}

/// Resolver puro per il campionamento di un `AnswerOptionPool`. Stateless e testabile con RNG iniettato.
public enum PoolSampler {

    /// Classificazione dei concetti per capacità (solo-corretto, solo-errato, entrambi).
    private struct Capacity {
        var onlyCorrect: [String] = []   // concetti con sole entry corrette
        var onlyWrong: [String] = []     // concetti con sole entry errate
        var both: [String] = []          // concetti con entry sia corrette sia errate
        var correctEntries: [String: [PoolEntry]] = [:]
        var wrongEntries: [String: [PoolEntry]] = [:]
    }

    private static func classify(_ pool: AnswerOptionPool) -> Capacity {
        var cap = Capacity()
        let byConcept = Dictionary(grouping: pool.entries, by: { $0.canonicalPointId })
        for (concept, entries) in byConcept {
            let corrects = entries.filter { $0.isCorrect }
            let wrongs = entries.filter { !$0.isCorrect }
            if !corrects.isEmpty { cap.correctEntries[concept] = corrects }
            if !wrongs.isEmpty { cap.wrongEntries[concept] = wrongs }
            switch (corrects.isEmpty, wrongs.isEmpty) {
            case (false, true): cap.onlyCorrect.append(concept)
            case (true, false): cap.onlyWrong.append(concept)
            case (false, false): cap.both.append(concept)
            case (true, true): break
            }
        }
        return cap
    }

    /// Insieme dei valori `k` (numero di corrette mostrate) ammissibili rispettando range,
    /// `displayCount` e unicità dei concetti.
    public static func feasibleCorrectCounts(_ pool: AnswerOptionPool) -> [Int] {
        let d = pool.displayCount
        let r = pool.correctCountRange
        guard d > 0, r.min >= 0, r.max >= r.min else { return [] }

        if pool.allowDuplicateConcepts == true {
            // Senza vincolo di unicità basta avere abbastanza entry in totale.
            let nCorrect = pool.entries.filter { $0.isCorrect }.count
            let nWrong = pool.entries.filter { !$0.isCorrect }.count
            return (max(0, r.min)...min(r.max, d)).filter { k in
                k <= nCorrect && (d - k) <= nWrong
            }
        }

        let cap = classify(pool)
        let oc = cap.onlyCorrect.count
        let ow = cap.onlyWrong.count
        let b = cap.both.count
        let cc = oc + b          // concetti capaci di "corretto"
        let wc = ow + b          // concetti capaci di "errato"

        return (max(0, r.min)...min(r.max, d)).filter { k in
            let w = d - k
            guard k <= cc, w <= wc else { return false }
            // Concetti "both" necessari per coprire le richieste non soddisfatte da solo-corretto/solo-errato.
            let needBothForCorrect = Swift.max(0, k - oc)
            let needBothForWrong = Swift.max(0, w - ow)
            return needBothForCorrect + needBothForWrong <= b
        }
    }

    /// Campiona `displayCount` entry rispettando i vincoli. Restituisce `nil` se il pool è infeasible.
    public static func sample<G: RandomNumberGenerator>(_ pool: AnswerOptionPool, using rng: inout G) -> [PoolEntry]? {
        let feasible = feasibleCorrectCounts(pool)
        guard let k = feasible.randomElement(using: &rng) else { return nil }
        let d = pool.displayCount

        if pool.allowDuplicateConcepts == true {
            let corrects = pool.entries.filter { $0.isCorrect }.shuffled(using: &rng)
            let wrongs = pool.entries.filter { !$0.isCorrect }.shuffled(using: &rng)
            guard corrects.count >= k, wrongs.count >= d - k else { return nil }
            return Array((corrects.prefix(k) + wrongs.prefix(d - k))).shuffled(using: &rng)
        }

        let cap = classify(pool)
        // Ordina i concetti prima di mescolarli: rende il resolver deterministico dato l'RNG,
        // indipendente dall'ordine d'iterazione (non garantito) di `Dictionary(grouping:)`.
        let onlyCorrect = cap.onlyCorrect.sorted()
        let onlyWrong = cap.onlyWrong.sorted()
        let both = cap.both.sorted()
        var chosenConcepts = Set<String>()
        var result: [PoolEntry] = []

        // Assegna i k slot "corretto": prima dai concetti solo-corretto, poi dai "both".
        let correctSources = (onlyCorrect.shuffled(using: &rng) + both.shuffled(using: &rng))
        for concept in correctSources where result.filter({ $0.isCorrect }).count < k {
            guard !chosenConcepts.contains(concept),
                  let entry = cap.correctEntries[concept]?.sorted(by: { $0.id < $1.id }).randomElement(using: &rng) else { continue }
            chosenConcepts.insert(concept)
            result.append(entry)
        }
        guard result.count == k else { return nil }

        // Assegna i (d - k) slot "errato": prima solo-errato, poi i "both" rimasti.
        let wrongSources = (onlyWrong.shuffled(using: &rng) + both.shuffled(using: &rng))
        for concept in wrongSources where result.count < d {
            guard !chosenConcepts.contains(concept),
                  let entry = cap.wrongEntries[concept]?.sorted(by: { $0.id < $1.id }).randomElement(using: &rng) else { continue }
            chosenConcepts.insert(concept)
            result.append(entry)
        }
        guard result.count == d else { return nil }

        return result.shuffled(using: &rng)
    }

    /// Convalida statica di un pool: restituisce il primo errore riscontrato (o `nil` se valido).
    public static func validationError(_ pool: AnswerOptionPool) -> PoolError? {
        guard pool.displayCount > 0 else { return .displayCountNotPositive }
        let r = pool.correctCountRange
        guard r.min >= 0, r.max >= r.min, r.min <= pool.displayCount else { return .invalidRange }

        var seenIds = Set<String>()
        for e in pool.entries {
            if e.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .emptyText }
            if e.canonicalPointId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .emptyCanonicalPointId(e.id)
            }
            if seenIds.contains(e.id) { return .duplicateEntryId(e.id) }
            seenIds.insert(e.id)
        }

        if pool.allowDuplicateConcepts == true {
            let nCorrect = pool.entries.filter { $0.isCorrect }.count
            let nWrong = pool.entries.filter { !$0.isCorrect }.count
            if nCorrect < r.min { return .notEnoughCorrectConcepts(have: nCorrect, needMin: r.min) }
            let minWrong = pool.displayCount - r.max
            if nWrong < Swift.max(0, minWrong) { return .notEnoughWrongConcepts(have: nWrong, needMin: Swift.max(0, minWrong)) }
            return feasibleCorrectCounts(pool).isEmpty ? .cannotProduceSample : nil
        }

        let cap = classify(pool)
        let cc = cap.onlyCorrect.count + cap.both.count
        let wc = cap.onlyWrong.count + cap.both.count
        let distinct = cap.onlyCorrect.count + cap.onlyWrong.count + cap.both.count

        if cc < r.min { return .notEnoughCorrectConcepts(have: cc, needMin: r.min) }
        let minWrongNeeded = Swift.max(0, pool.displayCount - r.max)
        if wc < minWrongNeeded { return .notEnoughWrongConcepts(have: wc, needMin: minWrongNeeded) }
        if distinct < pool.displayCount { return .poolTooSmall(distinctConcepts: distinct, displayCount: pool.displayCount) }
        return feasibleCorrectCounts(pool).isEmpty ? .cannotProduceSample : nil
    }
}

/// Dettaglio della valutazione di una selezione sul campione mostrato.
public struct PoolEvalDetail: Equatable {
    public let result: AnswerResult
    public let missedConcepts: [String]   // canonicalPointId corretti mostrati ma NON selezionati
    public let wrongConcepts: [String]    // canonicalPointId di entry errate selezionate
    public let wrongVariants: [PoolVariantKind] // variantKind delle errate selezionate (se presenti)
}

/// Valuta una selezione multi-select considerando SOLO le entry mostrate nell'attempt.
/// Corretto se e solo se l'utente seleziona tutte e sole le corrette mostrate.
public func evaluatePoolSelection(shown: [PoolEntry], selected: Set<String>) -> PoolEvalDetail {
    let correct = shown.filter { $0.isCorrect }
    let correctIds = Set(correct.map { $0.id })
    // Restringe la selezione alle sole entry effettivamente mostrate.
    let shownIds = Set(shown.map { $0.id })
    let effectiveSelected = selected.intersection(shownIds)

    let wrongShown = shown.filter { !$0.isCorrect }
    let wrongSelectedEntries = wrongShown.filter { effectiveSelected.contains($0.id) }

    let missed = correct.filter { !effectiveSelected.contains($0.id) }

    let result: AnswerResult
    if !wrongSelectedEntries.isEmpty {
        result = .wrong
    } else if effectiveSelected == correctIds && !correctIds.isEmpty {
        result = .correct
    } else if effectiveSelected.isEmpty {
        result = .wrong
    } else {
        result = .incomplete
    }

    return PoolEvalDetail(
        result: result,
        missedConcepts: missed.map { $0.canonicalPointId }.sorted(),
        wrongConcepts: wrongSelectedEntries.map { $0.canonicalPointId }.sorted(),
        wrongVariants: wrongSelectedEntries.compactMap { $0.variantKind }
    )
}

// MARK: - Aggiornamento statistiche (delta)

/// Converte il risultato di valutazione in un delta `QuestionStats`
/// che può essere fuso nel file statistiche.
public func statsDelta(for question: Question, detail: EvalDetail) -> QuestionStats {
    var delta = QuestionStats(attempts: 1,
                              correct: detail.result == .correct ? 1 : 0,
                              incomplete: detail.result == .incomplete ? 1 : 0,
                              wrong: detail.result == .wrong ? 1 : 0,
                              per_option: nil)
    // per-option solo per multiple
    if question.kind == .multiple {
        var perOpt: [Int: OptionStats] = [:]
        for id in detail.missedCorrect {
            var s = perOpt[id] ?? OptionStats()
            s.missedCorrect += 1
            perOpt[id] = s
        }
        for id in detail.wrongPicked {
            var s = perOpt[id] ?? OptionStats()
            s.wrongSelected += 1
            perOpt[id] = s
        }
        delta.per_option = perOpt.isEmpty ? nil : perOpt
    }
    return delta
}

/// Restituisce gli id di categoria da usare per il conteggio `per_category_wrong`.
/// Qui usiamo solo la categoria principale definita nel JSON della materia.
public func categoriesForCounting(question: Question) -> [String] {
    [question.category]
}
