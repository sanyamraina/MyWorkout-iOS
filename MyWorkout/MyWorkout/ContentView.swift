//
//  ContentView.swift
//  MyWorkout
//
//  Created by Sanyam Raina on 1/19/26.
//

import SwiftUI
import Combine
import UIKit

// MARK: - Design System Constants
struct DesignSystem {
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 18
        static let xxl: CGFloat = 22
        static let xxxl: CGFloat = 24
        static let huge: CGFloat = 28
        static let massive: CGFloat = 34
        static let giant: CGFloat = 120
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let xs: CGFloat = 10
        static let sm: CGFloat = 12
        static let md: CGFloat = 14
        static let lg: CGFloat = 16
        static let xl: CGFloat = 18
        static let xxl: CGFloat = 20
    }
    
    // MARK: - Font Sizes
    struct FontSize {
        static let caption: CGFloat = 12
        static let footnote: CGFloat = 13
        static let body: CGFloat = 14
        static let callout: CGFloat = 15
        static let subheadline: CGFloat = 16
        static let headline: CGFloat = 18
        static let title3: CGFloat = 28
        static let title2: CGFloat = 30
        static let title1: CGFloat = 34
    }
    
    // MARK: - Frame Sizes
    struct FrameSize {
        static let logoSize: CGFloat = 70
        static let minCardHeight: CGFloat = 80
        static let chartHeight: CGFloat = 220
        static let consistencyChartHeight: CGFloat = 200
    }
}

// MARK: - Reusable View Modifiers
private struct CardBackground: ViewModifier {
    let cornerRadius: CGFloat
    let opacity: Double
    let hasStroke: Bool
    
    init(cornerRadius: CGFloat = DesignSystem.CornerRadius.xl, opacity: Double = 0.9, hasStroke: Bool = true) {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.hasStroke = hasStroke
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(themeColor(.card).opacity(adjustedOpacity))
                    .overlay(
                        hasStroke ? RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1) : nil
                    )
            )
    }
    
    private var adjustedOpacity: Double {
        // Use higher opacity for light theme to create better contrast
        ThemeStore.shared.selectedTheme == .studioMinimal ? min(opacity + 0.1, 1.0) : opacity
    }
}

extension View {
    func cardBackground(cornerRadius: CGFloat = DesignSystem.CornerRadius.xl, opacity: Double = 0.9, hasStroke: Bool = true) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius, opacity: opacity, hasStroke: hasStroke))
    }
    
    func themedSegmentedPicker() -> some View {
        self
            .pickerStyle(.segmented)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(segmentedPickerBackground())
            )
            .tint(segmentedPickerTint())
            .foregroundColor(segmentedPickerForeground())
    }
    
    func themedToggle() -> some View {
        self
            .tint(themedAccent())
            .environment(\.colorScheme, ThemeStore.shared.selectedTheme == .studioMinimal ? .light : .dark)
    }
}

// MARK: - Segmented Picker Theme Colors
private func segmentedPickerBackground() -> Color {
    ThemeStore.shared.selectedTheme == .studioMinimal
        ? Color.gray.opacity(0.15)
        : themeColor(.card).opacity(0.3)
}

private func segmentedPickerTint() -> Color {
    ThemeStore.shared.selectedTheme == .studioMinimal
        ? themeColor(.coal)
        : themedAccent()
}

private func segmentedPickerForeground() -> Color {
    ThemeStore.shared.selectedTheme == .studioMinimal
        ? themeColor(.sand)
        : themedPrimaryText()
}

private func applySegmentedAppearance() {
    let theme = ThemeStore.shared.selectedTheme
    let normalText = UIColor(themeColor(.sand))
    let selectedText = UIColor(theme == .studioMinimal ? themeColor(.sand) : themeColor(.night))
    let appearance = UISegmentedControl.appearance()
    appearance.setTitleTextAttributes([.foregroundColor: normalText], for: .normal)
    appearance.setTitleTextAttributes([.foregroundColor: selectedText], for: .selected)
    appearance.selectedSegmentTintColor = UIColor(segmentedPickerTint())
    appearance.backgroundColor = UIColor(segmentedPickerBackground())
}

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case midnightSand
    case studioMinimal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .midnightSand:
            return "Dark"
        case .studioMinimal:
            return "Light"
        }
    }

    var nightAsset: String {
        switch self {
        case .midnightSand:
            return "MidnightSandNight"
        case .studioMinimal:
            return "StudioMinimalNight"
        }
    }

    var coalAsset: String {
        switch self {
        case .midnightSand:
            return "MidnightSandCoal"
        case .studioMinimal:
            return "StudioMinimalCoal"
        }
    }

    var sandAsset: String {
        switch self {
        case .midnightSand:
            return "MidnightSandSand"
        case .studioMinimal:
            return "StudioMinimalSand"
        }
    }

    var cardAsset: String {
        switch self {
        case .midnightSand:
            return "MidnightSandCard"
        case .studioMinimal:
            return "StudioMinimalCard"
        }
    }
}

enum ThemeColorKey {
    case night
    case coal
    case sand
    case card
}

final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()
    @Published var selectedTheme: AppTheme = .midnightSand {
        didSet { saveTheme() }
    }

    private init() {
        selectedTheme = loadTheme()
    }

    private func loadTheme() -> AppTheme {
        let raw = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.midnightSand.rawValue
        return AppTheme(rawValue: raw) ?? .midnightSand
    }

    private func saveTheme() {
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
    }
}

func themeColor(_ key: ThemeColorKey) -> Color {
    let theme = ThemeStore.shared.selectedTheme
    switch key {
    case .night:
        return Color(theme.nightAsset)
    case .coal:
        return Color(theme.coalAsset)
    case .sand:
        return Color(theme.sandAsset)
    case .card:
        return Color(theme.cardAsset)
    }
}

func themedPrimaryText() -> Color {
    themeColor(.sand)
}

func themedSecondaryText() -> Color {
    ThemeStore.shared.selectedTheme == .studioMinimal
        ? themeColor(.sand).opacity(0.85)  // Increased from 0.7 to 0.85 for better contrast
        : themeColor(.sand).opacity(0.6)
}

func themedAccent() -> Color {
    themeColor(.sand)
}

func themedAccentMuted() -> Color {
    ThemeStore.shared.selectedTheme == .studioMinimal
        ? themeColor(.sand).opacity(0.75)  // Increased from 0.65 to 0.75
        : themeColor(.sand).opacity(0.7)
}

func themedAccentForeground() -> Color {
    ThemeStore.shared.selectedTheme == .studioMinimal ? themeColor(.coal) : themeColor(.night)
}

func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct ContentView: View {
    @StateObject private var store = WorkoutStore()
    @AppStorage("selectedTab") private var selectedTab = 0
    @ObservedObject private var themeStore = ThemeStore.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(store: store)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            HistoryView(store: store)
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(1)

            ExerciseLibraryView(store: store)
                .tabItem {
                    Label("Explore", systemImage: "square.grid.2x2.fill")
                }
                .tag(2)

            ProgressTabView(store: store)
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)

            SettingsView(store: store)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .onAppear {
            applySegmentedAppearance()
        }
        .onChange(of: themeStore.selectedTheme) { _, _ in
            applySegmentedAppearance()
        }
        .overlay(alignment: .top) {
            if let message = store.ioErrorMessage {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(themeColor(.sand))
                    Text(message)
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(themedPrimaryText())
                    Spacer()
                    Button {
                        store.ioErrorMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(themedSecondaryText())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeColor(.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeColor(.sand).opacity(0.12), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
    }
}


#Preview {
    ContentView()
        .onAppear {
            ThemeStore.shared.selectedTheme = .midnightSand
        }
        .preferredColorScheme(.dark)
}
 
