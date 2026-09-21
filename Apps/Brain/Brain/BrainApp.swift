//
//  BrainApp.swift
//  Brain
//
//  Created by Mehmet Serhat Uzgoren on 5/16/26.
//

import SwiftUI

@main
struct BrainApp: App {
    @State private var store = BrainAppStore()
    @State private var capture = CaptureSession()
    @State private var navigation = BrainNavigation.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(capture)
                .environment(navigation)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Write a note") { navigation.writeNote() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Record a thought") { navigation.record() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}
