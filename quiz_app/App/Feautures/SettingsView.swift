//
//  SettingsView.swift
//  quiz_app
//
//  Impostazioni: promemoria di studio, sincronizzazione (futura), informazioni.
//

import SwiftUI

/// Preferenza tema dell'app, persistita in `@AppStorage("app_theme")`.
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Automatico"
        case .light:  return "Chiaro"
        case .dark:   return "Scuro"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    /// `nil` = segue il sistema.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var notifications = NotificationService.shared
    @AppStorage("app_theme") private var appTheme: String = AppTheme.system.rawValue

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
            Section {
                Picker(selection: $appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Label(theme.label, systemImage: theme.systemImage).tag(theme.rawValue)
                    }
                } label: {
                    Label("Tema", systemImage: "paintbrush")
                }
                .pickerStyle(.menu)
            } header: {
                Text("Aspetto")
            } footer: {
                Text("\"Automatico\" segue l'aspetto del sistema.")
            }

            Section {
                Toggle(isOn: Binding(
                    get: { notifications.isEnabled },
                    set: { notifications.setEnabled($0) }
                )) {
                    Label("Ripasso giornaliero", systemImage: "bell.badge")
                }
                if notifications.isEnabled {
                    DatePicker(selection: $notifications.reminderTime, displayedComponents: .hourAndMinute) {
                        Label("Orario", systemImage: "clock")
                    }
                }
            } header: {
                Text("Promemoria")
            } footer: {
                Text("Ricevi una notifica giornaliera per non perdere il ripasso.")
            }

            Section {
                Label {
                    Text("Sincronizzazione iCloud")
                    Text("In arrivo").font(.caption).foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "icloud")
                }
                .foregroundStyle(.secondary)
            } header: {
                Text("Sincronizzazione")
            }

            Section("Informazioni") {
                LabeledContent("Versione", value: appVersion)
            }
        }
        .navigationTitle("Impostazioni")
        .navigationBarTitleDisplayMode(.inline)
    }
}
