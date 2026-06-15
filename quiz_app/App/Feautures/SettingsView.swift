//
//  SettingsView.swift
//  quiz_app
//
//  Impostazioni: promemoria di studio, sincronizzazione (futura), informazioni.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var notifications = NotificationService.shared

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
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
