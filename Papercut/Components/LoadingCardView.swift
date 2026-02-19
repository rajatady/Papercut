//
//  LoadingCardView.swift
//  Papercut
//

import SwiftUI

struct LoadingCardView: View {
    @Environment(ThemeManager.self) private var theme
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Category badges
            HStack(spacing: Spacing.md) {
                shimmerRect(width: 50, height: 20)
                shimmerRect(width: 60, height: 20)
            }

            // Title
            VStack(alignment: .leading, spacing: Spacing.sm) {
                shimmerRect(height: 20)
                shimmerRect(width: 250, height: 20)
            }

            // Authors
            shimmerRect(width: 180, height: 14)

            // Date
            shimmerRect(width: 100, height: 12)

            // Summary area
            VStack(alignment: .leading, spacing: Spacing.xs) {
                shimmerRect(height: 14)
                shimmerRect(height: 14)
                shimmerRect(width: 200, height: 14)
            }
            .padding(.top, Spacing.md)

            // Style chips
            HStack(spacing: Spacing.md) {
                shimmerRect(width: 70, height: 28)
                shimmerRect(width: 90, height: 28)
                shimmerRect(width: 80, height: 28)
            }
            .padding(.top, Spacing.xs)
        }
        .padding()
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
        .onAppear {
            isAnimating = true
        }
    }

    @ViewBuilder
    private func shimmerRect(width: CGFloat? = nil, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(theme.colors.textTertiary.opacity(0.3))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .overlay {
                GeometryReader { geometry in
                    shimmerGradient
                        .frame(width: geometry.size.width * 2)
                        .offset(x: isAnimating ? geometry.size.width : -geometry.size.width)
                        .animation(
                            .linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
                .clipped()
            }
    }

    private var shimmerGradient: some View {
        LinearGradient(
            colors: [
                theme.colors.textTertiary.opacity(0.3),
                theme.colors.textTertiary.opacity(0.5),
                theme.colors.textTertiary.opacity(0.3)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Loading Feed View
struct LoadingFeedView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.xl) {
                ForEach(0..<5, id: \.self) { _ in
                    LoadingCardView()
                }
            }
            .padding()
        }
    }
}

#Preview {
    LoadingFeedView()
        .environment(ThemeManager())
}
