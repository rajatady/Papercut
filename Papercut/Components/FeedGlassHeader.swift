//
//  FeedGlassHeader.swift
//  Papercut
//

import SwiftUI

/// Floating glass header — tabs + single action icon.
/// Content scrolls behind it via `.ultraThinMaterial`.
struct FeedGlassHeader: View {
    let tabs: [FeedTab]
    @Binding var selectedIndex: Int
    let isRefreshing: Bool
    let onSettings: () -> Void

    @Environment(ThemeManager.self) private var theme
    @Namespace private var tabNamespace

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                // Tab labels — tappable, synced with horizontal swipe
                tabStrip

                Spacer(minLength: 0)

                if isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(theme.colors.textMuted)
                        .transition(.opacity)
                        .padding(.trailing, Spacing.md)
                }

                Button(action: onSettings) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.sm)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Tab Strip

    private var tabStrip: some View {
        HStack(spacing: Spacing.xxl) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                Button {
                    withAnimation(AppAnimation.Interactive.spring) {
                        selectedIndex = index
                    }
                } label: {
                    VStack(spacing: 3) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: selectedIndex == index ? .semibold : .regular))
                            .foregroundStyle(selectedIndex == index ? theme.colors.textPrimary : theme.colors.textMuted)

                        // Sliding underline
                        if selectedIndex == index {
                            Capsule()
                                .fill(theme.colors.textPrimary)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "tab", in: tabNamespace)
                        } else {
                            Capsule()
                                .fill(Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "F5F5F3").ignoresSafeArea()

        VStack {
            FeedGlassHeader(
                tabs: FeedTab.allCases,
                selectedIndex: .constant(0),
                isRefreshing: false,
                onSettings: {}
            )
            Spacer()
        }
    }
    .environment(ThemeManager())
}
