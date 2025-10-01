//
//  AppDelegate.swift
//  CleanView
//
//  App lifecycle and background task management
//

import UIKit
import BackgroundTasks
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Register for background tasks
        registerBackgroundTasks()

        // Request notification permissions for rule updates
        requestNotificationPermissions()

        // Configure user defaults
        configureDefaults()

        return true
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.example.cleanview.ruleupdate",
            using: nil
        ) { task in
            self.handleRuleUpdate(task: task as! BGAppRefreshTask)
        }
    }

    private func handleRuleUpdate(task: BGAppRefreshTask) {
        // Schedule next update
        scheduleRuleUpdate()

        // Perform rule update
        Task {
            let success = await RuleUpdateService.shared.performBackgroundUpdate()
            task.setTaskCompleted(success: success)
        }
    }

    func scheduleRuleUpdate() {
        let request = BGAppRefreshTaskRequest(
            identifier: "com.example.cleanview.ruleupdate"
        )
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 3600) // Daily

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule rule update: \(error)")
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if granted {
                print("Notification permissions granted")
            }
        }
    }

    // MARK: - User Defaults

    private func configureDefaults() {
        let defaults: [String: Any] = [
            StorageKeys.vpnEnabled: false,
            StorageKeys.selectedRegion: VPNConfig.Region.automatic.rawValue,
            StorageKeys.dnsProvider: VPNConfig.DNSProvider.cloudflare.rawValue,
            StorageKeys.autoUpdateEnabled: true
        ]
        UserDefaults.standard.register(defaults: defaults)
    }

    // MARK: - App Lifecycle

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Save any pending state
        WhitelistStore.shared.save()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Clean up resources
        VPNManager.shared.disconnect()
    }
}