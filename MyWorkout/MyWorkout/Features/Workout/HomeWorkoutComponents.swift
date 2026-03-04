import SwiftUI

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(themedSecondaryText())
            Text(value)
                .font(.custom("Avenir Next", size: 22))
                .fontWeight(.semibold)
                .foregroundStyle(themedPrimaryText())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(themeColor(.card).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct StatPage: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

struct StatPager: View {
    let pages: [StatPage]
    @State private var selection = 0

    private var displayIndex: Int {
        max(0, min(selection, pages.count - 1))
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(themeColor(.card).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                    )
                TabView(selection: $selection) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        StatPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .frame(height: 104)

            PageDots(count: pages.count, currentIndex: displayIndex)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatPageView: View {
    let page: StatPage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(page.title)
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(themedSecondaryText())
            Text(page.value)
                .font(.custom("Avenir Next", size: 28))
                .fontWeight(.semibold)
                .foregroundStyle(themedPrimaryText())
                .padding(.leading, 5)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PageDots: View {
    let count: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(themedAccent().opacity(index == currentIndex ? 0.9 : 0.35))
                    .frame(width: index == currentIndex ? 6 : 4, height: index == currentIndex ? 6 : 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct TemplateCard: View {
    let template: WorkoutTemplate
    let onUse: () -> Void
    let onShare: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onUse) {
            VStack(alignment: .leading, spacing: 8) {
                Text(template.title)
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.semibold)
                    .foregroundStyle(themedPrimaryText())
                if let first = template.exercises.first {
                    Text("Starts with \(first.name)")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(themedSecondaryText())
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(16)
            .frame(width: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(themeColor(.card).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onShare()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
