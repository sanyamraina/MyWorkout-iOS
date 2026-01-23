//
//  MyWorkoutApp.swift
//  MyWorkout
//
//  Created by Sanyam Raina on 1/19/26.
//

import SwiftUI

@main
struct MyWorkoutApp: App {
    @StateObject private var themeStore = ThemeStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(themeStore.selectedTheme)
        }
    }
}
