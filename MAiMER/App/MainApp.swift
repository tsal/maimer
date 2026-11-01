//
//  MainApp.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = RomLibraryViewModel()

    var body: some Scene {
        Window("MAiMER", id: "main") {
            ContentView()
                .environment(viewModel)
        }
        .defaultSize(width: 1050, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        Settings {
            SettingsView()
                .environment(viewModel)
        }
    }
}
