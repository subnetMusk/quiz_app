//
//  QuizTheme.swift
//  quiz_app
//
//  Created by subnetMusk on 9/1/25.
//

import SwiftUI

// MARK: - Design System per l'app Quiz

struct QuizTheme {
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color.accentColor
        static let secondary = Color(.systemGray)
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
        
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.systemGray6)
        static let tertiaryBackground = Color(.systemGray5)
        
        static let cardBackground = Color(.systemBackground)
        static let cardBorder = Color(.systemGray4)
    }
    
    // MARK: - Typography
    struct Typography {
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
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let pill: CGFloat = 999
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let card = Shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        static let button = Shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Reusable Components

struct QuizCard<Content: View>: View {
    let content: Content
    let isSelected: Bool
    let action: () -> Void
    
    init(isSelected: Bool = false, action: @escaping () -> Void = {}, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            content
                .padding(QuizTheme.Spacing.lg)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.md)
                        .fill(QuizTheme.Colors.cardBackground)
                        .stroke(
                            isSelected ? QuizTheme.Colors.primary : QuizTheme.Colors.cardBorder,
                            lineWidth: isSelected ? 2 : 1
                        )
                        .shadow(
                            color: QuizTheme.Shadows.card.color,
                            radius: QuizTheme.Shadows.card.radius,
                            x: QuizTheme.Shadows.card.x,
                            y: QuizTheme.Shadows.card.y
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct QuizButton: View {
    let title: String
    let icon: String?
    let style: Style
    let action: () -> Void
    
    enum Style {
        case primary, secondary, destructive, success
        
        var backgroundColor: Color {
            switch self {
            case .primary: return QuizTheme.Colors.primary
            case .secondary: return QuizTheme.Colors.secondaryBackground
            case .destructive: return QuizTheme.Colors.error
            case .success: return QuizTheme.Colors.success
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary, .destructive, .success: return .white
            case .secondary: return .primary
            }
        }
    }
    
    init(_ title: String, icon: String? = nil, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: QuizTheme.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(QuizTheme.Typography.callout)
                }
                Text(title)
                    .font(QuizTheme.Typography.callout.bold())
            }
            .foregroundColor(style.foregroundColor)
            .padding(.horizontal, QuizTheme.Spacing.lg)
            .padding(.vertical, QuizTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.sm)
                    .fill(style.backgroundColor)
            )
        }
        .buttonStyle(.plain)
    }
}

struct StatsBadge: View {
    let value: String
    let label: String
    let color: Color
    
    init(_ value: String, label: String, color: Color = QuizTheme.Colors.info) {
        self.value = value
        self.label = label
        self.color = color
    }
    
    var body: some View {
        VStack(spacing: QuizTheme.Spacing.xs) {
            Text(value)
                .font(QuizTheme.Typography.title2)
                .foregroundColor(color)
            
            Text(label)
                .font(QuizTheme.Typography.caption)
                .foregroundColor(.secondary)
        }
        .padding(QuizTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.sm)
                .fill(QuizTheme.Colors.secondaryBackground)
        )
    }
}

// MARK: - View Extensions

extension View {
    func quizCardStyle(isSelected: Bool = false) -> some View {
        self
            .padding(QuizTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.md)
                    .fill(QuizTheme.Colors.cardBackground)
                    .stroke(
                        isSelected ? QuizTheme.Colors.primary : QuizTheme.Colors.cardBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
    }
}
