//
//  StudyMetrics.swift
//  quiz_app
//
//  Helper di presentazione derivati dallo storico sessioni (nessuna logica di persistenza).
//

import Foundation

enum StudyMetrics {

    /// Numero di giorni di studio consecutivi terminanti oggi (o ieri).
    static func currentStreak(from sessions: [StudySession],
                              calendar: Calendar = .current,
                              now: Date = Date()) -> Int {
        guard !sessions.isEmpty else { return 0 }
        let days = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        // Lo streak è valido solo se si è studiato oggi o ieri.
        guard days.contains(today) || days.contains(yesterday) else { return 0 }

        var streak = 0
        var cursor = days.contains(today) ? today : yesterday
        while days.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Precisione media (0...1) sulle sessioni fornite.
    static func averageAccuracy(_ sessions: [StudySession]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(sessions.count)
    }
}
