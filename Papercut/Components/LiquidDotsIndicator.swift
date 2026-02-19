//
//  LiquidDotsIndicator.swift
//  Papercut
//

import SwiftUI

struct LiquidDotsIndicator: View {
    let totalPages: Int
    let currentPage: Int

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        HStack(spacing: Spacing.md) {
            ForEach(0..<totalPages, id: \.self) { index in
                RoundedRectangle(cornerRadius: LayoutConstants.Dot.size / 2)
                    .fill(index == currentPage ? theme.colors.dotActive : theme.colors.dotInactive)
                    .frame(
                        width: index == currentPage ? LayoutConstants.Dot.activeWidth : LayoutConstants.Dot.size,
                        height: LayoutConstants.Dot.size
                    )
                    .animation(AppAnimation.LiquidDots.spring, value: currentPage)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        LiquidDotsIndicator(totalPages: 4, currentPage: 0)
        LiquidDotsIndicator(totalPages: 4, currentPage: 1)
        LiquidDotsIndicator(totalPages: 4, currentPage: 2)
        LiquidDotsIndicator(totalPages: 4, currentPage: 3)
    }
    .padding()
    .environment(ThemeManager())
}
