//
//  ArApp.swift
//  Ar
//
//  Created by a on 2026/6/1.
//

import SwiftUI

@main
struct ArApp: App {
    @State private var isSplashFinished = false
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            if !isSplashFinished {
                SplashView(onFinish: {
                    withAnimation(.easeInOut) {
                        isSplashFinished = true
                    }
                })
            } else {
                // ContentView 内部已包含 TabView + NavigationView，无需外层 NavigationView
                ContentView()
                    .environmentObject(router)
            }
        }
    }
}
