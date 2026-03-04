import SwiftUI

struct TagView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.custom("Avenir Next", size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(themeColor(.sand).opacity(0.12))
            )
            .foregroundStyle(themedPrimaryText())
    }
}

struct ExerciseNameField: View {
    let title: String
    let showsTitle: Bool
    @Binding var text: String
    let suggestions: [String]
    let suggestionDetail: ((String) -> String?)?
    let isLocked: Bool
    let onFocusChange: ((Bool) -> Void)?
    @FocusState private var isFocused: Bool

    init(
        title: String,
        showsTitle: Bool,
        text: Binding<String>,
        suggestions: [String],
        suggestionDetail: ((String) -> String?)? = nil,
        isLocked: Bool = false,
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self.showsTitle = showsTitle
        self._text = text
        self.suggestions = suggestions
        self.suggestionDetail = suggestionDetail
        self.isLocked = isLocked
        self.onFocusChange = onFocusChange
    }

    private var matches: [String] {
        guard !isLocked else { return [] }
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        return suggestions
            .filter { name in
                let nameMatch = name.lowercased().contains(query)
                if nameMatch { return true }
                guard let detail = suggestionDetail?(name)?.lowercased() else { return false }
                return detail.contains(query)
            }
            .prefix(10)
            .map { $0 }
    }

    private var groupedMatches: [(group: String, items: [String])] {
        var groups: [String: [String]] = [:]
        for name in matches {
            let group = suggestionDetail?(name) ?? "Other"
            groups[group, default: []].append(name)
        }
        let ordered = groups.keys.sorted()
        return ordered.map { ($0, groups[$0] ?? []) }
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsTitle {
                Text(title)
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(themedSecondaryText())
            }
            VStack(spacing: 6) {
                TextField("Exercise Name", text: $text)
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.headline))
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(themedPrimaryText())
                    .padding(DesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .fill(themeColor(.card).opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                    .stroke(
                                        isFocused ? themedAccent().opacity(0.35) : themedSecondaryText().opacity(0.12),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .focused($isFocused)
                    .disabled(isLocked)
                    .opacity(isLocked ? 0.85 : 1)

                if isFocused && !matches.isEmpty {
                    suggestionList
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeColor(.card).opacity(0.98))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(themeColor(.sand).opacity(0.12), lineWidth: 1)
                                )
                        )
                        .shadow(color: themeColor(.night).opacity(0.25), radius: 12, x: 0, y: 8)
                }
            }
        }
        .onChange(of: isFocused) { _, newValue in
            onFocusChange?(newValue)
        }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(groupedMatches, id: \.group) { group, items in
                HStack(spacing: 8) {
                    Capsule()
                        .fill(themeColor(.sand).opacity(0.18))
                        .frame(width: 18, height: 6)
                    Text(group.uppercased())
                        .font(.custom("Avenir Next", size: 11))
                        .fontWeight(.semibold)
                        .foregroundStyle(themedSecondaryText())
                }
                .padding(.top, 6)
                .padding(.horizontal, 8)

                ForEach(items, id: \.self) { name in
                    Text(name)
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(themedPrimaryText())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                text = name
                                isFocused = false
                            }
                        )
                }
            }
        }
        .contentShape(Rectangle())
        .zIndex(10)
    }
}

struct InputCard: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let keyboard: UIKeyboardType
    var showsTitle: Bool = true
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsTitle {
                Text(title)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themedSecondaryText())
            }
            TextField(placeholder, text: $text)
                .font(.custom("Avenir Next", size: 14))
                .keyboardType(keyboard)
                .foregroundStyle(themedPrimaryText())
                // .padding(10)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeColor(.card).opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isFocused ? themeColor(.sand).opacity(0.35) : themeColor(.sand).opacity(0.12),
                                    lineWidth: 1
                                )
                        )
                )
                .focused($isFocused)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UnitPillAligned: View {
    @Binding var unit: WeightUnit
    var showsTitle: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsTitle {
                Text("Unit")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(.clear)
            }
            unitPill
        }
    }

    private var unitPill: some View {
        Menu {
            Button("kg") { unit = .kg }
            Button("lb") { unit = .lb }
        } label: {
            Text(unit.label)
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.footnote))
                .foregroundStyle(themedPrimaryText())
                .frame(width: 44, height: 32)
                .background(
                    Capsule()
                        .fill(themedAccentMuted().opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(themedAccentMuted().opacity(0.18), lineWidth: 1)
                        )
                )
        }
    }
}

struct SetRemoveButtonAligned: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Unit")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(.clear)
            Button(role: .destructive, action: action) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(themedSecondaryText())
            }
            .frame(width: 32, height: 32)
        }
        .padding(.top, 2)
    }
}

struct SegmentRemoveButton: View {
    let showsTitle: Bool
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(themedSecondaryText())
        }
        .frame(width: 24, height: 24)
        .padding(.top, showsTitle ? 16 : 0)
    }
}

struct SpottedToggleButton: View {
    @Binding var isSpotted: Bool
    @Binding var isSpottedPlaceholder: Bool
    let showsTitle: Bool
    let onToggle: ((Bool) -> Void)?

    var body: some View {
        let showsPlaceholder = isSpottedPlaceholder && !isSpotted
        Button {
            isSpotted.toggle()
            onToggle?(isSpotted)
        } label: {
            Image(systemName: isSpotted ? "person.2.fill" : "person.2")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSpotted ? themedPrimaryText() : themedSecondaryText())
                .frame(width: 32, height: 32)
                .background(
                    Capsule()
                        .fill(themeColor(.sand).opacity(isSpotted ? 0.18 : 0.08))
                        .overlay(
                            Capsule()
                                .stroke(
                                    style: StrokeStyle(lineWidth: 1, dash: showsPlaceholder ? [3, 3] : [])
                                )
                                .foregroundStyle(themeColor(.sand).opacity(isSpotted ? 0.3 : (showsPlaceholder ? 0.3 : 0.12)))
                        )
                )
        }
        .buttonStyle(.plain)
        .padding(.top, showsTitle ? 16 : 0)
    }
}

struct SetDeleteAnchor: View {
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "trash")
                .foregroundStyle(themedSecondaryText())
        }
        .frame(width: 24, height: 24)
    }
}

struct SetCardView: View {
    @Binding var set: WorkoutSetDraft
    @Binding var weightUnit: WeightUnit
    let isCompact: Bool
    let canRemoveSet: Bool
    let allowDropSets: Bool
    let allowSpotting: Bool
    let isBodyweightSegment: (WorkoutSetSegmentDraft) -> Bool
    let onRemoveSet: () -> Void
    let onSpotToggle: ((Bool) -> Void)?
    @State private var segmentMidYs: [UUID: CGFloat] = [:]

    private var deleteAnchorY: CGFloat? {
        let ids = set.segments.map(\.id)
        guard !ids.isEmpty else { return nil }
        let count = ids.count
        if count % 2 == 1 {
            let midIndex = (count - 1) / 2
            return segmentMidYs[ids[midIndex]]
        }
        let upperIndex = count / 2
        let lowerIndex = upperIndex - 1
        guard let lower = segmentMidYs[ids[lowerIndex]],
              let upper = segmentMidYs[ids[upperIndex]] else {
            return nil
        }
        return (lower + upper) / 2
    }

    var body: some View {
        VStack(spacing: 10) {
            segmentsList

            if allowDropSets {
                Button {
                    set.segments.append(WorkoutSetSegmentDraft())
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Drop")
                    }
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(themedPrimaryText())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(themeColor(.card).opacity(0.6))
        )
        .coordinateSpace(name: "setCard")
        .overlay(alignment: .topTrailing) {
            if canRemoveSet, let anchorY = deleteAnchorY {
                SetDeleteAnchor(action: onRemoveSet)
                    .offset(y: anchorY - 3)
                    .padding(.trailing, 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
    }

    private var segmentsList: some View {
        VStack(spacing: 6) {
            ForEach(Array($set.segments.enumerated()), id: \.element.id) { index, $segment in
                segmentRow(index: index, segment: $segment)
            }
        }
        .onPreferenceChange(SegmentMidYPreferenceKey.self) { value in
            segmentMidYs = value
        }
    }

    private func segmentRow(index: Int, segment: Binding<WorkoutSetSegmentDraft>) -> some View {
        let segmentId = segment.wrappedValue.id
        let showsTitle = index == 0
        let segmentValue = segment.wrappedValue

        return HStack(alignment: .center, spacing: 12) {
            if allowDropSets && set.segments.count > 1 {
                SegmentRemoveButton(showsTitle: showsTitle) {
                    set.segments.removeAll { $0.id == segmentId }
                }
            }
            GeometryReader { proxy in
                let availableWidth = max(proxy.size.width - 12, 0)
                let repsWidth = availableWidth * 0.4
                let weightWidth = availableWidth * 0.6
                HStack(spacing: 12) {
                    InputCard(
                        title: "Reps",
                        text: segment.reps,
                        placeholder: segmentValue.repsPlaceholder.isEmpty ? "10" : segmentValue.repsPlaceholder,
                        keyboard: .numberPad,
                        showsTitle: showsTitle
                    )
                    .frame(width: repsWidth)

                    InputCard(
                        title: "Weight",
                        text: segment.weight,
                        placeholder: segmentValue.weightPlaceholder.isEmpty ? "10" : segmentValue.weightPlaceholder,
                        keyboard: .decimalPad,
                        showsTitle: showsTitle
                    )
                    .frame(width: weightWidth)
                }
            }
            .frame(height: showsTitle ? 56 : 40)
            if isBodyweightSegment(segmentValue) {
                BodyweightPillAligned(isCompact: isCompact, showsTitle: showsTitle)
            } else {
                UnitPillAligned(unit: $weightUnit, showsTitle: showsTitle)
            }
            if allowSpotting {
                SpottedToggleButton(
                    isSpotted: segment.isSpotted,
                    isSpottedPlaceholder: segment.isSpottedPlaceholder,
                    showsTitle: showsTitle,
                    onToggle: onSpotToggle
                )
            }
            if canRemoveSet {
                SetDeleteAnchorSpacer()
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SegmentMidYPreferenceKey.self,
                    value: [segmentId: proxy.frame(in: .named("setCard")).midY]
                )
            }
        )
    }
}

struct SegmentMidYPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]

    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct SetDeleteAnchorSpacer: View {
    var body: some View {
        Color.clear
            .frame(width: 24, height: 24)
    }
}

struct BodyweightPillAligned: View {
    let isCompact: Bool
    var showsTitle: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsTitle {
                Text("Unit")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(.clear)
            }
            Group {
                if isCompact {
                    Text("BW")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(themedPrimaryText())
                        .frame(width: 44, height: 32)
                        .background(
                            Capsule()
                                .fill(themeColor(.sand).opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(themeColor(.sand).opacity(0.18), lineWidth: 1)
                                )
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    Text("Bodyweight")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(themedPrimaryText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .frame(minWidth: 88, minHeight: 32)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(themeColor(.sand).opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(themeColor(.sand).opacity(0.18), lineWidth: 1)
                                )
                        )
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isCompact)
        }
    }
}

struct PrimaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(themeColor(.night))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(themeColor(.sand))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No workouts yet")
                .font(.custom("Avenir Next", size: 20))
                .fontWeight(.semibold)
                .foregroundStyle(themedPrimaryText())
            Text("Add a workout or create a template to get started.")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(themedSecondaryText())
        }
        .padding(18)
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
