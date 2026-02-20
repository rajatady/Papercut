//
//  FeedbackPulseButton.swift
//  Papercut
//

import SwiftUI

struct FeedbackPulseButton: View {
    let action: () -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Subtle pulse ring
                Circle()
                    .stroke(theme.colors.accent.opacity(isPulsing ? 0 : 0.3), lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                    .scaleEffect(isPulsing ? 1.35 : 1.0)

                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.colors.accent.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .glassEffect(.regular, in: .circle)
            }
        }
        .buttonStyle(SoftPressButtonStyle())
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
                .delay(1.0)
            ) {
                isPulsing = true
            }
        }
    }
}
