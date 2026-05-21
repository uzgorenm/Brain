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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
