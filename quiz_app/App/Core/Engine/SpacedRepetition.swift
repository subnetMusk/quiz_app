//
//  SpacedRepetition.swift
//  quiz_app
//
//  Algoritmo SM-2 (SuperMemo) adattato ai tre esiti dell'app (corretto/incompleto/sbagliato).
//  La funzione `next` è pura e testabile in isolamento; `apply` la applica a un QuestionProgress.
//

import Foundation

enum SpacedRepetition {

    struct Schedule: Equatable {
        var easeFactor: Double
        var intervalDays: Int
        var repetitions: Int
        var dueDate: Date
    }

    /// Mappa l'esito sull'indice di qualità SM-2 (0–5).
    /// corretto = 5 (ottimo), incompleto = 3 (passato ma faticoso), sbagliato = 1 (fallito).
    static func quality(for result: AnswerResult) -> Int {
        switch result {
        case .correct:    return 5
        case .incomplete: return 3
        case .wrong:      return 1
        }
    }

    /// Calcola il nuovo scheduling a partire dallo stato corrente e dall'esito.
    static func next(easeFactor: Double,
                     intervalDays: Int,
                     repetitions: Int,
                     result: AnswerResult,
                     now: Date = Date()) -> Schedule {
        let q = quality(for: result)
        var ef = easeFactor
        var reps = repetitions
        var interval = intervalDays

        if q < 3 {
            // Fallita: si riparte da capo (ripasso a breve).
            reps = 0
            interval = 1
        } else {
            switch reps {
            case 0:  interval = 1
            case 1:  interval = 6
            default: interval = Int((Double(interval) * ef).rounded())
            }
            reps += 1
        }

        // Aggiornamento dell'ease factor (minimo 1.3).
        let delta = 0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02)
        ef = max(1.3, ef + delta)

        let due = Calendar.current.date(byAdding: .day, value: max(1, interval), to: now) ?? now
        return Schedule(easeFactor: ef, intervalDays: interval, repetitions: reps, dueDate: due)
    }

    /// Applica il nuovo scheduling a un `QuestionProgress`.
    static func apply(to p: QuestionProgress, result: AnswerResult, now: Date = Date()) {
        let s = next(easeFactor: p.easeFactor,
                     intervalDays: p.intervalDays,
                     repetitions: p.repetitions,
                     result: result,
                     now: now)
        p.easeFactor = s.easeFactor
        p.intervalDays = s.intervalDays
        p.repetitions = s.repetitions
        p.dueDate = s.dueDate
        p.lastReviewed = now
    }
}
