//
//  FeedbackView.swift
//  Papercut
//

import SwiftUI

// MARK: - Shared Feedback URLs

struct FeedbackURLs {
    private static let repo = "rajatady/Papercut"

    static var bugReportURL: String {
        let title = ""
        let body = """
        **Describe the bug**
        A clear description of what the bug is.

        **Steps to reproduce**
        1.
        2.
        3.

        **Expected behavior**


        **Device info**
        - Device: \(deviceName)
        - iOS: \(UIDevice.current.systemVersion)
        - App version: 1.0.0
        """
        return "https://github.com/\(repo)/issues/new?labels=bug&title=\(title.feedbackURLEncoded)&body=\(body.feedbackURLEncoded)"
    }

    static var featureRequestURL: String {
        let body = """
        **What would you like?**
        A clear description of the feature.

        **Why is this useful?**


        **Anything else?**

        """
        return "https://github.com/\(repo)/issues/new?labels=enhancement&title=&body=\(body.feedbackURLEncoded)"
    }

    static var githubURL: String {
        "https://github.com/\(repo)"
    }

    private static var deviceName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? UIDevice.current.model
            }
        }
    }
}

private extension String {
    var feedbackURLEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

// MARK: - Feedback View

struct FeedbackView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.bottom, Spacing.xxxl + Spacing.md)

                    featuresSection
                        .padding(.bottom, Spacing.xxxl + Spacing.xl)

                    // Divider between features and actions
                    dividerRow
                        .padding(.bottom, Spacing.xxxl)

                    actionsSection
                        .padding(.bottom, LayoutConstants.Screen.scrollPaddingBottom)
                }
                .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
                .padding(.top, Spacing.xxl)
            }
            .background(theme.colors.background)
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.colors.accent)
                }
            }
        }
        .task {
            // Small delay so the sheet presentation finishes first
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: Spacing.xxl) {
            ZStack {
                Circle()
                    .fill(theme.colors.accent.opacity(0.08))
                    .frame(width: 80, height: 80)

                Image(systemName: "waveform.and.person.filled")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(theme.colors.accent)
                    .symbolEffect(.breathe.pulse, options: .repeating.speed(0.4))
            }

            VStack(spacing: Spacing.md) {
                Text("Shape Papercut")
                    .font(AppTypography.displayTitle)
                    .tracking(AppTypography.Tracking.displayTitle)
                    .foregroundStyle(theme.colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("A personal tool to keep up with arXiv,\nbuilt with your feedback.")
                    .font(AppTypography.bodyRegular)
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.vertical, Spacing.xl)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: Spacing.lg) {
            featureCard(
                icon: "sparkles",
                color: Color(hex: "E4A853"),
                title: "On-device AI summaries",
                subtitle: "Read less, understand more",
                delay: 0.05
            )
            featureCard(
                icon: "bookmark.fill",
                color: theme.colors.accent,
                title: "Track research fields",
                subtitle: "Never miss a paper in your area",
                delay: 0.1
            )
            featureCard(
                icon: "bolt.fill",
                color: .orange,
                title: "Offline-first",
                subtitle: "Your library works without internet",
                delay: 0.15
            )
        }
    }

    private func featureCard(icon: String, color: Color, title: String, subtitle: String, delay: Double) -> some View {
        HStack(spacing: Spacing.xl) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.18), color.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(theme.colors.textPrimary)

                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.colors.textMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.xl)
        .background(theme.colors.surface.opacity(theme.isDark ? 0.15 : 0.5))
        .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
        .overlay {
            RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius)
                .strokeBorder(color.opacity(0.12), lineWidth: 1)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.easeOut(duration: 0.5).delay(delay), value: appeared)
    }

    // MARK: - Divider

    private var dividerRow: some View {
        HStack(spacing: Spacing.lg) {
            dashedLine
            Text("Help us improve")
                .font(AppTypography.captionMedium)
                .foregroundStyle(theme.colors.textTertiary)
            dashedLine
        }
        .padding(.horizontal, Spacing.xxxl)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: Spacing.lg) {
            actionLink(
                icon: "ladybug",
                iconColor: .red,
                title: "Report a Bug",
                subtitle: "Something broken? Let us know",
                urlString: FeedbackURLs.bugReportURL,
                delay: 0.22
            )

            actionLink(
                icon: "lightbulb",
                iconColor: Color(hex: "E4A853"),
                title: "Submit Feedback",
                subtitle: "Ideas, suggestions, feature requests",
                urlString: FeedbackURLs.featureRequestURL,
                delay: 0.27
            )

            actionLink(
                icon: "star",
                iconColor: Color(hex: "E4C95B"),
                title: "Star on GitHub",
                subtitle: "Help others discover Papercut",
                urlString: FeedbackURLs.githubURL,
                delay: 0.32
            )
        }
    }

    private func actionLink(icon: String, iconColor: Color, title: String, subtitle: String, urlString: String, delay: Double) -> some View {
        Link(destination: URL(string: urlString)!) {
            HStack(spacing: Spacing.xl) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: LayoutConstants.IconCircle.size, height: LayoutConstants.IconCircle.size)
                    .background(iconColor.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(theme.colors.textPrimary)

                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(theme.colors.textMuted)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.colors.textTertiary)
            }
            .padding(Spacing.xl)
            .background(theme.colors.surface.opacity(theme.isDark ? 0.2 : 0.6))
            .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
            .overlay {
                RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius)
                    .strokeBorder(theme.colors.surface, lineWidth: 1)
            }
        }
        .buttonStyle(PressButtonStyle(scale: 0.98))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.easeOut(duration: 0.5).delay(delay), value: appeared)
    }

    // MARK: - Helpers

    private var dashedLine: some View {
        DashedSeparator()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundStyle(theme.colors.textTertiary.opacity(0.4))
            .frame(height: 1)
    }
}

private struct DashedSeparator: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

#Preview {
    FeedbackView()
        .environment(ThemeManager())
}
