//
//  Evaluator.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
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
