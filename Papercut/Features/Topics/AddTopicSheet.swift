//
//  AddTopicSheet.swift
//  Papercut
//

import SwiftUI

struct AddTopicSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var query: String
    @State private var sortBy: ArXivSortBy = .relevance

    private let existingTopic: Topic?
    private let onCreate: ((String, String, ArXivSortBy) -> Void)?
    private let onUpdate: ((String, String, ArXivSortBy) -> Void)?

    private var isEditing: Bool { existingTopic != nil }

    /// Create mode
    init(initialQuery: String = "", onCreate: @escaping (String, String, ArXivSortBy) -> Void) {
        self._query = State(initialValue: initialQuery)
        self.existingTopic = nil
        self.onCreate = onCreate
        self.onUpdate = nil
    }

    /// Edit mode
    init(topic: Topic, onUpdate: @escaping (String, String, ArXivSortBy) -> Void) {
        self.existingTopic = topic
        self._name = State(initialValue: topic.name)
        self._query = State(initialValue: topic.query)
        self._sortBy = State(initialValue: topic.sortBy)
        self.onCreate = nil
        self.onUpdate = onUpdate
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.xxxl) {
                        // Name field
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Topic Name")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(theme.colors.textPrimary)

                            TextField("e.g. Transformer Architecture", text: $name)
                                .font(AppTypography.bodyRegular)
                                .foregroundStyle(theme.colors.textPrimary)
                                .padding(.horizontal, Spacing.xl)
                                .padding(.vertical, Spacing.lg)
                                .background(theme.colors.surface.opacity(theme.isDark ? 0.3 : 0.7))
                                .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
                                .overlay {
                                    RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius)
                                        .strokeBorder(theme.colors.surface, lineWidth: 1)
                                }
                        }

                        // Query field
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Search Query")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(theme.colors.textPrimary)

                            TextField("e.g. attention mechanism transformer", text: $query)
                                .font(AppTypography.bodyRegular)
                                .foregroundStyle(theme.colors.textPrimary)
                                .padding(.horizontal, Spacing.xl)
                                .padding(.vertical, Spacing.lg)
                                .background(theme.colors.surface.opacity(theme.isDark ? 0.3 : 0.7))
                                .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
                                .overlay {
                                    RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius)
                                        .strokeBorder(theme.colors.surface, lineWidth: 1)
                                }

                            Text("This query will be used to search ArXiv papers")
                                .font(.caption)
                                .foregroundStyle(theme.colors.textMuted)
                        }

                        // Sort preference
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Default Sort")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(theme.colors.textPrimary)

                            ThemedPicker(
                                title: "Sort by",
                                selection: $sortBy,
                                options: ArXivSortBy.searchCases,
                                label: { $0.displayName },
                                icon: { $0.iconName }
                            )
                        }

                        // Action button
                        Button {
                            if isEditing {
                                onUpdate?(name, query, sortBy)
                            } else {
                                onCreate?(name, query, sortBy)
                            }
                            dismiss()
                        } label: {
                            Text(isEditing ? "Save Changes" : "Create Topic")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(theme.colors.background)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.xl)
                                .background(
                                    canSave
                                        ? theme.colors.textPrimary
                                        : theme.colors.textMuted
                                )
                                .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
                        }
                        .buttonStyle(PressButtonStyle())
                        .disabled(!canSave)
                    }
                    .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
                    .padding(.top, Spacing.xl)
                }
            }
            .navigationTitle(isEditing ? "Edit Topic" : "New Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(theme.colors.textSecondary)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
