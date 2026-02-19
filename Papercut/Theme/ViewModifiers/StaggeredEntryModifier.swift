//
//  StaggeredEntryModifier.swift
//  Papercut
//

import SwiftUI

struct StaggeredEntryModifier: ViewModifier {
    let index: Int
    let total: Int

    @State private var isVisible = false

    private var delay: Double {
        AppAnimation.StaggeredEntry.baseDelay + Double(index) * AppAnimation.StaggeredEntry.itemDelay
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1.0 : AppAnimation.StaggeredEntry.scaleFrom)
            .opacity(isVisible ? 1.0 : 0.0)
            .onAppear {
                withAnimation(
                    .spring(
                        response: AppAnimation.StaggeredEntry.duration,
                        dampingFraction: 0.7
                    )
                    .delay(delay)
                ) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func staggeredEntry(index: Int, total: Int) -> some View {
        modifier(StaggeredEntryModifier(index: index, total: total))
    }
}
