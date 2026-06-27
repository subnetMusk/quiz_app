//
//  MainAppView.swift
//  quiz_app
//
//  Contenitore principale a tab. L'apertura è sulla dashboard "Oggi".
//

import SwiftUI

enum AppTab: Hashable {
    case today, quiz, theory, stats, library
}

struct MainAppView: View {
    @ObservedObject var app: AppStore
    @State private var selection: AppTab = .today
    @AppStorage("app_theme") private var appTheme: String = AppTheme.system.rawValue

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                TodayView(app: app, selection: $selection)
            }
            .tabItem { Label("Oggi", systemImage: "house") }
            .tag(AppTab.today)

            NavigationStack {
                MainQuizView(app: app)
            }
            .tabItem { Label("Quiz", systemImage: "brain.head.profile") }
            .tag(AppTab.quiz)

            NavigationStack {
                TheoryView(app: app)
            }
            .tabItem { Label("Teoria", systemImage: "book.closed") }
            .tag(AppTab.theory)

            NavigationStack {
                StatsView(app: app)
            }
            .tabItem { Label("Statistiche", systemImage: "chart.bar") }
            .tag(AppTab.stats)

            NavigationStack {
                LibraryView(app: app)
            }
            .tabItem { Label("Materie", systemImage: "books.vertical") }
            .tag(AppTab.library)
        }
        .tint(QuizTheme.Colors.primary)
        .preferredColorScheme(AppTheme(rawValue: appTheme)?.colorScheme)
    }
}

#Preview {
    MainAppView(app: AppStore())
}
