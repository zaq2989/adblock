# Xcode Project Setup Guide for CleanViewVPN

## Prerequisites

- Xcode 15.0 or later
- iOS 16.0+ SDK
- Apple Developer Account (paid - required for NetworkExtension)
- macOS Ventura or later

## Step 1: Create New Project

1. Open Xcode > Create New Project
2. Choose **iOS > App**
3. Configure:
   - Product Name: `CleanView`
   - Team: Your Developer Team
   - Organization Identifier: `com.example` (replace with yours)
   - Bundle Identifier: `com.example.cleanview`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Use Core Data: **No**
   - Include Tests: **Yes**

## Step 2: Add Network Extension Target

1. File > New > Target
2. Choose **iOS > Network Extension**
3. Select **Packet Tunnel Provider**
4. Configure:
   - Product Name: `CleanViewVPN`
   - Bundle ID: `com.example.cleanview.vpn`
   - Language: Swift
5. Click Finish
6. When prompted to activate scheme, click **Activate**

## Step 3: Add Content Blocker Target

1. File > New > Target
2. Choose **iOS > Safari Extension**
3. Select **Content Blocker Extension**
4. Configure:
   - Product Name: `CleanViewBlocker`
   - Bundle ID: `com.example.cleanview.blocker`
5. Click Finish

## Step 4: Configure App Groups

### For Each Target (Host, VPN, Blocker):

1. Select target in project navigator
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** under App Groups
6. Add: `group.com.example.cleanview.shared`

## Step 5: Configure Capabilities

### Host App (CleanView):
1. Add Capabilities:
   - ✅ App Groups
   - ✅ Network Extensions
   - ✅ Background Modes
   - ✅ In-App Purchase

2. Background Modes - Check:
   - ✅ Background fetch
   - ✅ Background processing

### VPN Extension (CleanViewVPN):
1. Add Capabilities:
   - ✅ App Groups
   - ✅ Network Extensions (Personal VPN)

### Content Blocker (CleanViewBlocker):
1. Add Capabilities:
   - ✅ App Groups

## Step 6: Configure Entitlements

### Host App Entitlements:
```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>
```

### VPN Extension Entitlements:
```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>
```

## Step 7: Build Settings Configuration

### All Targets:
1. Set **iOS Deployment Target**: 16.0
2. Set **Swift Language Version**: 5.9
3. Enable **Bitcode**: No

### VPN Extension Specific:
1. **Memory Limit**: Network Extensions have 50MB limit
2. Add Linker Flag: `-ObjC`

## Step 8: Info.plist Configuration

### Host App Info.plist additions:
```xml
<key>NSUserNotificationUsageDescription</key>
<string>CleanView sends notifications about rule updates.</string>

<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.example.cleanview.ruleupdate</string>
</array>
```

## Step 9: File Organization

```
CleanViewVPN.xcodeproj
├── CleanView (Host App)
│   ├── App/
│   ├── Views/
│   ├── Services/
│   ├── Storage/
│   └── Resources/
├── CleanViewVPN (Network Extension)
│   ├── PacketTunnelProvider.swift
│   ├── DNSEngine.swift
│   └── RuleEngine.swift
├── CleanViewBlocker (Content Blocker)
│   └── ContentBlockerRequestHandler.swift
├── CleanViewBlockerResources
│   └── Rules.json
└── Shared/
    └── Constants.swift
```

## Step 10: Add Files to Targets

### Shared Files:
1. Select `Constants.swift`
2. In File Inspector, check:
   - ✅ CleanView
   - ✅ CleanViewVPN
   - ✅ CleanViewBlocker

### Resources:
1. Add `Rules.json` to CleanViewBlocker target
2. Set as **Copy Bundle Resource**

## Step 11: Configure Schemes

1. Product > Scheme > Manage Schemes
2. Ensure all targets have schemes:
   - CleanView (Host App)
   - CleanViewVPN (Extension)
   - CleanViewBlocker (Extension)
3. Make CleanView scheme **Shared** for CI/CD

## Step 12: StoreKit Configuration

1. File > New > File
2. Choose **StoreKit Configuration File**
3. Add products:
   ```
   - com.example.cleanview.pro.monthly (Auto-Renewable)
   - com.example.cleanview.pro.yearly (Auto-Renewable)
   ```
4. Link to scheme for testing

## Step 13: Provisioning Profiles

### Development:
1. Xcode > Preferences > Accounts
2. Download Manual Profiles
3. Ensure profiles exist for:
   - Host App
   - Network Extension
   - Content Blocker

### Distribution:
1. Create App Store profiles for each target
2. Include NetworkExtension entitlement
3. Include App Groups

## Step 14: Testing Configuration

### Simulator Testing:
- VPN functionality limited in Simulator
- Content Blocker works in Simulator
- Use real device for full testing

### Real Device Testing:
1. Connect iOS device
2. Trust developer certificate on device
3. Settings > General > VPN & Device Management
4. Trust your developer app

## Step 15: Common Build Errors & Solutions

### Error: "NetworkExtension entitlement missing"
**Solution**: Ensure your provisioning profile includes NetworkExtension capability

### Error: "App Group container not accessible"
**Solution**: Verify all targets use exact same App Group ID

### Error: "Memory limit exceeded in extension"
**Solution**: Optimize extension code, remove unnecessary imports

### Error: "Content Blocker rules invalid"
**Solution**: Validate JSON format in Rules.json

## Step 16: Pre-submission Checklist

- [ ] Test on real device
- [ ] VPN connects and filters DNS
- [ ] Content Blocker enabled in Safari settings
- [ ] Subscription purchases work (sandbox)
- [ ] App Groups data sharing works
- [ ] Background updates scheduled
- [ ] Memory usage under limits
- [ ] No crashes in 48-hour test
- [ ] Privacy Policy URL valid
- [ ] Support URL accessible

## Step 17: App Store Connect Configuration

1. Create app record
2. Add In-App Purchases:
   - Pro Monthly ($2.99)
   - Pro Yearly ($19.99)
3. Add App Privacy details:
   - No data collected linking to user
4. Submit for review with notes:
   - VPN for ad/tracker blocking
   - Content Blocker for visual cleanup
   - No logs policy

## Build & Run Commands

### Command Line Build:
```bash
# Build Host App
xcodebuild -scheme CleanView -configuration Release

# Build with all extensions
xcodebuild -workspace CleanViewVPN.xcworkspace \
           -scheme CleanView \
           -configuration Release \
           -archivePath ./build/CleanView.xcarchive \
           archive

# Export for App Store
xcodebuild -exportArchive \
           -archivePath ./build/CleanView.xcarchive \
           -exportPath ./build \
           -exportOptionsPlist ExportOptions.plist
```

## Troubleshooting Tips

1. **Clean Build Folder**: Cmd+Shift+K
2. **Reset Simulators**: Device > Erase All Content
3. **Clear Derived Data**: ~/Library/Developer/Xcode/DerivedData
4. **Restart Xcode**: Sometimes necessary for entitlements
5. **Check Console**: Look for extension crash logs

## Important Notes

- NetworkExtension requires paid developer account
- VPN functionality won't work in Simulator
- Test subscriptions in Sandbox environment
- Memory limit for extensions is strict (50MB)
- Extension crashes don't show in Xcode debugger

## Support Resources

- [Apple NetworkExtension Documentation](https://developer.apple.com/documentation/networkextension)
- [Safari Content Blocker Guide](https://developer.apple.com/documentation/safariservices/creating_a_content_blocker)
- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [App Groups Guide](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)

---

*This guide covers the complete setup process. For questions, contact the development team.*