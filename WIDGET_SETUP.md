# Widget + App Group

Il target **QuizWidget** (Widget Extension) e la capability **App Group**
(`group.it.subnetmusk.quiz-app`) sono **già integrati nel progetto Xcode**: non servono più
passi manuali. Il widget viene compilato, firmato ed embeddato in `quiz_app.app/PlugIns/`
automaticamente quando compili lo schema `quiz_app`.

## Cosa è configurato
- **Target `QuizWidget`** (`com.apple.product-type.app-extension`)
  - sorgente: `QuizWidget/QuizWidget.swift`
  - `QuizWidget/Info.plist` → `NSExtension.NSExtensionPointIdentifier = com.apple.widgetkit-extension`
  - bundle id `it.subnetmusk.quiz-app.QuizWidget`, entitlements `QuizWidget/QuizWidget.entitlements`
- **App `quiz_app`**: dipendenza dal widget + fase "Embed Foundation Extensions";
  entitlements `quiz_app/quiz_app.entitlements`.
- **App Group** `group.it.subnetmusk.quiz-app` su entrambi i target (deve combaciare con
  `appGroupIdentifier` in `quiz_app/App/Core/Persistence/PersistenceController.swift`).

`PersistenceController` usa automaticamente il container SwiftData condiviso quando l'App Group è
disponibile (altrimenti fallback locale). `WidgetBridge.update(...)` scrive lo snapshot
(`widget_due_count`, `widget_subject_name`) nell'App Group e ricarica le timeline.

## (Opzionale) Notifiche
Le notifiche locali non richiedono capability. Al primo toggle "Ripasso giornaliero"
(Statistiche → Promemoria studio) l'app chiede l'autorizzazione.

## Verifica
- Avvia l'app, importa una materia, fai una sessione: lo snapshot (`widget_due_count`) si aggiorna.
- In home → aggiungi widget → cerca **"Ripasso del giorno"**: mostra il numero di domande in scadenza.

## Nota per future modifiche al progetto
Il target è stato creato programmaticamente con la gem Ruby `xcodeproj`. Per modifiche
strutturali al `.pbxproj` da riga di comando puoi riusare quella gem (`gem install xcodeproj`).
