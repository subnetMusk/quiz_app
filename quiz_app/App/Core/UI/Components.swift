//
//  Components.swift
//  quiz_app
//
//  Componenti UI riusabili del design system (stile nativo).
//

import SwiftUI

// MARK: - Card

private struct CardModifier: ViewModifier {
    var padding: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(QuizTheme.Colors.cardBackground,
                        in: RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.lg))
    }
}

extension View {
    /// Avvolge il contenuto in una card nativa (sfondo raggruppato secondario, angoli arrotondati).
    func card(padding: CGFloat = QuizTheme.Spacing.lg) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - Metric

struct MetricView: View {
    let value: String
    let label: String
    var systemImage: String? = nil
    var tint: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stat pill

struct StatPill: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.15), in: Capsule())
        .foregroundStyle(tint)
    }
}

// MARK: - Accuracy ring

struct AccuracyRing: View {
    /// Valore 0...1
    let progress: Double
    var lineWidth: CGFloat = 8
    var tint: Color = .accentColor
    var showsLabel: Bool = true

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, clamped))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsLabel {
                Text("\(Int((clamped * 100).rounded()))%")
                    .font(.headline.bold())
                    .contentTransition(.numericText())
            }
        }
    }
}

// MARK: - Mode card

struct ModeCard: View {
    let title: String
    let systemImage: String
    let subtitle: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.white : tint)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(isSelected ? tint : QuizTheme.Colors.cardBackground,
                        in: RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: QuizTheme.CornerRadius.lg)
                    .stroke(isSelected ? Color.clear : QuizTheme.Colors.cardBorder.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Primary button style

struct PrimaryActionButtonStyle: ButtonStyle {
    var tint: Color = .accentColor
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background((enabled ? tint : Color(.systemGray3)).opacity(configuration.isPressed ? 0.8 : 1),
                        in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - StatsBadge (compat)

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
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(QuizTheme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}
