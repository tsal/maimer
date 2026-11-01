//
//  MainApp.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import SwiftUI

@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        Window("MAiMER", id: "main") {
            MaimerView()
                .environment(appState)
        }
        .defaultSize(width: 1050, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
