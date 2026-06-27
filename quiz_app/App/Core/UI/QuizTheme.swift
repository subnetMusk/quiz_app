//
//  QuizTheme.swift
//  quiz_app
//
//  Design system nativo: token semantici basati sui colori di sistema iOS.
//  I componenti riusabili sono in Components.swift.
//

import SwiftUI

enum QuizTheme {

    // MARK: - Colors
    enum Colors {
        static let primary = Color.accentColor
        static let secondary = Color(.secondaryLabel)
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue

        /// Sfondo pagina (liste/scroll raggruppati).
        static let background = Color(.systemGroupedBackground)
        /// Sfondo delle card / superfici sopraelevate.
        static let cardBackground = Color(.secondarySystemGroupedBackground)
        static let secondaryBackground = Color(.secondarySystemGroupedBackground)
        static let tertiaryBackground = Color(.tertiarySystemGroupedBackground)
        static let cardBorder = Color(.separator)

        // Palette modalità di ripasso (coerente tra le schermate).
        static let modeSmart = Color.purple
        static let modeGeneral = Color.blue
        static let modeCategory = Color.green
        static let modeErrors = Color.orange
    }

    // MARK: - Typography
    enum Typography {
        static let largeTitle = Font.largeTitle.bold()
        static let title = Font.title.bold()
        static let title2 = Font.title2.bold()
        static let title3 = Font.title3.bold()
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius
    enum CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let pill: CGFloat = 999
    }
}
