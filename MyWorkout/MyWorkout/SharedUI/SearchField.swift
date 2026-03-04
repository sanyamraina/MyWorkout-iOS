import SwiftUI

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(themedSecondaryText())
            TextField(placeholder, text: $text)
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.subheadline))
                .foregroundStyle(themedPrimaryText())
        }
        .padding(DesignSystem.Spacing.md)
        .cardBackground(cornerRadius: DesignSystem.CornerRadius.md)
    }
}
