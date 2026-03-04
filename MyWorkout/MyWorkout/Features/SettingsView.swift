import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: WorkoutStore
    @ObservedObject private var themeStore = ThemeStore.shared
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDocument: BackupDocument?
    @State private var importErrorMessage: String?
    @State private var showImportError = false
    @State private var showResetConfirm = false
    @State private var showRebuildConfirm = false
    @State private var sessionWindowSelection: SessionMergeWindowOption = .threeHours
    @State private var pendingSessionWindow: SessionMergeWindowOption?
    @State private var isSettingUp = true
    @State private var showBackupToast = false
    @State private var backupToastMessage = ""
    @AppStorage("lastBackupTimestamp") private var lastBackupTimestamp: Double = 0
    @State private var isTransferInProgress = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Text("Settings")
                        .font(.custom("Avenir Next", size: DesignSystem.FontSize.title2))
                        .fontWeight(.semibold)
                        .foregroundStyle(themedPrimaryText())

                    preferencesCard
                    featureControlsCard
                    dataCard
                    aboutCard
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
            }
            .allowsHitTesting(!isTransferInProgress)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "myworkout-backup"
        ) { result in
            switch result {
            case .success:
                lastBackupTimestamp = Date().timeIntervalSince1970
                backupToastMessage = "Backup exported."
                showBackupToast = true
                isTransferInProgress = false
                Haptics.success()
            case .failure(let error):
                importErrorMessage = error.localizedDescription
                showImportError = true
                isTransferInProgress = false
                Haptics.error()
            }
        }
        .onChange(of: isExporting) { _, newValue in
            if !newValue && isTransferInProgress {
                isTransferInProgress = false
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                handleImport(from: url)
            case .failure(let error):
                importErrorMessage = error.localizedDescription
                showImportError = true
                isTransferInProgress = false
                Haptics.error()
            }
        }
        .onChange(of: isImporting) { _, newValue in
            if !newValue && isTransferInProgress {
                isTransferInProgress = false
            }
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "Unable to import backup.")
        }
        .alert("Reset All Data?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                store.resetAllData()
                Haptics.warning()
            }
        } message: {
            Text("This will permanently delete all workouts, templates, and exercise types on this device.")
        }
        .alert("Update History Sessions?", isPresented: $showRebuildConfirm) {
            Button("Keep Current", role: .cancel) {
                sessionWindowSelection = store.sessionMergeWindowOption
                pendingSessionWindow = nil
            }
            Button("Rebuild History", role: .destructive) {
                if let pendingSessionWindow {
                    store.sessionMergeWindowOption = pendingSessionWindow
                    store.rebuildSessions()
                    Haptics.warning()
                }
                pendingSessionWindow = nil
            }
        } message: {
            Text("Changing the session window can regroup past workouts. Rebuild history to apply the new window?")
        }
        .overlay(alignment: .top) {
            if showBackupToast {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(themeColor(.sand))
                    Text(backupToastMessage)
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(themedPrimaryText())
                    Spacer()
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
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showBackupToast = false
                        }
                    }
                }
            }
        }
        .overlay {
            if isTransferInProgress {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()

                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(themeColor(.sand))
                        Text("Working…")
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundStyle(themedPrimaryText())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(themeColor(.card))
                    )
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            sessionWindowSelection = store.sessionMergeWindowOption
            DispatchQueue.main.async {
                isSettingUp = false
            }
        }
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Preferences")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.body))
                .foregroundStyle(themedSecondaryText())

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Session Window")
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.callout))
                    .foregroundStyle(themedPrimaryText())
                Text("Workouts logged within this window merge into the same session.")
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.caption))
                    .foregroundStyle(themedSecondaryText())
                Picker("Session Window", selection: $sessionWindowSelection) {
                    ForEach(SessionMergeWindowOption.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(themedAccent())
                .onChange(of: sessionWindowSelection) { _, newValue in
                    guard !isSettingUp else { return }
                    guard newValue != store.sessionMergeWindowOption else { return }
                    Haptics.selection()
                    if store.needsRebuild(for: newValue) {
                        pendingSessionWindow = newValue
                        showRebuildConfirm = true
                    } else {
                        store.sessionMergeWindowOption = newValue
                    }
                }
            }

            Divider()
                .overlay(themeColor(.sand).opacity(0.12))

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Default Weight Unit")
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.callout))
                    .foregroundStyle(themedPrimaryText())
                Picker("Default Weight Unit", selection: $store.defaultWeightUnit) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .themedSegmentedPicker()
            }

            Divider()
                .overlay(themeColor(.sand).opacity(0.12))

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Theme")
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.callout))
                    .foregroundStyle(themedPrimaryText())
                Picker("Theme", selection: $themeStore.selectedTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
                .themedSegmentedPicker()
            }

        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private var featureControlsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Feature Controls")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.body))
                .foregroundStyle(themedSecondaryText())
            Text("Toggle optional tools on or off to keep workouts simple or add extra detail.")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.caption))
                .foregroundStyle(themedSecondaryText())

            Toggle(isOn: $store.isDropSetsEnabled) {
                Text("Drop Sets")
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.subheadline))
                    .foregroundStyle(Color.primary)
            }
            .themedToggle()

            Toggle(isOn: $store.isExerciseNotesEnabled) {
                Text("Exercise Notes")
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.subheadline))
                    .foregroundStyle(Color.primary)
            }
            .themedToggle()

            Toggle(isOn: $store.isTodaysNotesEnabled) {
                Text("Today's Notes")
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.subheadline))
                    .foregroundStyle(Color.primary)
            }
            .themedToggle()

            Toggle(isOn: $store.isSpottingEnabled) {
                Text("Spotted Sets")
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.subheadline))
                    .foregroundStyle(Color.primary)
            }
            .themedToggle()
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Data")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.body))
                .foregroundStyle(themedSecondaryText())
            if lastBackupTimestamp > 0 {
                Text("Last backup: \(formattedBackupDate(lastBackupTimestamp))")
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.caption))
                    .foregroundStyle(themedSecondaryText())
                    .padding(.top, 2)
            }

            Button {
                do {
                    Haptics.tap()
                    exportDocument = BackupDocument(data: try store.exportBackupData())
                    isTransferInProgress = true
                    isExporting = true
                } catch {
                    importErrorMessage = error.localizedDescription
                    showImportError = true
                    isTransferInProgress = false
                    Haptics.error()
                }
            } label: {
                settingsRow(title: "Export Backup", systemImage: "square.and.arrow.up")
            }

            Button {
                Haptics.tap()
                isTransferInProgress = true
                isImporting = true
            } label: {
                settingsRow(title: "Import Backup", systemImage: "square.and.arrow.down")
            }

            Button(role: .destructive) {
                Haptics.selection()
                showResetConfirm = true
            } label: {
                settingsRow(title: "Reset All Data", systemImage: "trash", isDestructive: true)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("About")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.body))
                .foregroundStyle(themedSecondaryText())
            Text("MyWorkout")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.headline))
                .foregroundStyle(themedPrimaryText())
            Text("Track what you lift, keep it simple.")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.footnote))
                .foregroundStyle(themedSecondaryText())
            Text("Data stays on device unless you export a backup.")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.caption))
                .foregroundStyle(themedSecondaryText())
            Text("License: MIT")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.caption))
                .foregroundStyle(themedSecondaryText())
            Text("Version \(appVersion)")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.caption))
                .foregroundStyle(themedSecondaryText())
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func formattedBackupDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func settingsRow(title: String, systemImage: String, isDestructive: Bool = false) -> some View {
        HStack {
            Image(systemName: systemImage)
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.subheadline))
                .foregroundStyle(isDestructive ? themedPrimaryText().opacity(0.9) : themedPrimaryText())
            Text(title)
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.subheadline))
                .foregroundStyle(isDestructive ? themedPrimaryText().opacity(0.9) : themedPrimaryText())
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    private func handleImport(from url: URL) {
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStop {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            try store.importBackupData(data)
            lastBackupTimestamp = Date().timeIntervalSince1970
            backupToastMessage = "Backup imported."
            showBackupToast = true
            isTransferInProgress = false
            Haptics.success()
        } catch {
            importErrorMessage = error.localizedDescription
            showImportError = true
            isTransferInProgress = false
            Haptics.error()
        }
    }
}
