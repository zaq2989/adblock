//
//  CleanViewApp.swift
//  CleanView
//
//  Main app entry point
//

import SwiftUI

@main
struct CleanViewApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vpnManager = VPNManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(vpnManager)
                .environmentObject(subscriptionManager)
                .task {
                    // Initialize services on app launch
                    await initializeApp()
                }
        }
    }

    private func initializeApp() async {
        // Configure VPN on first launch
        await vpnManager.loadConfiguration()

        // Initialize subscription status
        await subscriptionManager.loadSubscriptions()

        // Check for rule updates if Pro user
        if subscriptionManager.currentTier == .pro {
            Task {
                await RuleUpdateService.shared.checkForUpdates()
            }
        }
    }
}