//
//  QuizWidget.swift
//  QuizWidget (Widget Extension)
//
//  NOTA: questo file NON appartiene al target dell'app. Va aggiunto al target
//  "Widget Extension" da creare in Xcode (vedi WIDGET_SETUP.md alla radice del progetto).
//  Legge lo snapshot scritto dall'app nell'App Group condiviso (group.it.subnetmusk.quiz-app).
//

import WidgetKit
import SwiftUI

private let appGroupIdentifier = "group.it.subnetmusk.quiz-app"

struct QuizEntry: TimelineEntry {
    let date: Date
    let dueCount: Int
    let subjectName: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> QuizEntry {
        QuizEntry(date: .now, dueCount: 5, subjectName: "Materia")
    }

    func getSnapshot(in context: Context, completion: @escaping (QuizEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuizEntry>) -> Void) {
        let entry = readEntry()
        // Aggiornamento periodico (l'app forza comunque il reload quando i dati cambiano).
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func readEntry() -> QuizEntry {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        return QuizEntry(
            date: .now,
            dueCount: defaults?.integer(forKey: "widget_due_count") ?? 0,
            subjectName: defaults?.string(forKey: "widget_subject_name") ?? ""
        )
    }
}

struct QuizWidgetEntryView: View {
    var entry: QuizEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Ripasso", systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(entry.dueCount)")
                .font(.system(size: 34, weight: .bold))
            Text(entry.dueCount == 1 ? "domanda da rivedere" : "domande da rivedere")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if !entry.subjectName.isEmpty {
                Text(entry.subjectName)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct QuizWidget: Widget {
    let kind = "QuizWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            QuizWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Ripasso del giorno")
        .description("Quante domande hai da rivedere oggi.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct QuizWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuizWidget()
    }
}
