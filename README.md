# CleanViewVPN - Privacy-First Ad Blocker for iOS

A comprehensive iOS app that combines VPN-based DNS filtering with Safari Content Blocking to provide maximum ad and tracker protection while maintaining user privacy.

## 🎯 Features

- **Dual Protection System**
  - Network-level blocking via local VPN (NEPacketTunnelProvider)
  - Visual cleanup via Safari Content Blocker

- **Privacy-Focused**
  - Strict no-logs policy
  - All filtering happens locally on device
  - No external servers or data collection

- **User-Friendly**
  - One-tap VPN connection
  - Whitelist management
  - Pro subscription with StoreKit 2
  - SwiftUI modern interface

## 📱 Requirements

- **Development**
  - Xcode 15.0+
  - iOS 16.0+ SDK
  - macOS Ventura or later
  - Apple Developer Account (Paid - required for NetworkExtension)

- **Runtime**
  - iOS 16.0 or later
  - iPhone or iPad
  - ~50MB storage

## 🚀 Quick Start

### Automated Setup (Recommended) 🤖

1. **Clone the repository**
   ```bash
   git clone https://github.com/zaq2989/adblock.git
   cd adblock
   ```

2. **Run automated setup**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
   This will:
   - Install XcodeGen and SwiftLint
   - Update bundle identifiers
   - Generate Xcode project
   - Create test files
   - Configure build settings

3. **Open and run**
   ```bash
   open CleanViewVPN.xcodeproj
   # or use: make build
   ```

### Manual Setup (Alternative)

1. **Install XcodeGen**
   ```bash
   brew install xcodegen
   ```

2. **Generate project**
   ```bash
   xcodegen generate
   ```

3. **Open in Xcode**
   - Select your development team
   - Update bundle identifiers if needed

4. **Build and Run**
   - Select target device
   - Build and run (⌘R)

## 📂 Project Structure

```
CleanViewVPN/
├── CleanView/                 # Main iOS App
│   ├── App/                   # App lifecycle
│   ├── Views/                 # SwiftUI views
│   ├── Services/              # VPN, Subscription, Rules
│   └── Storage/               # Data persistence
│
├── CleanViewVPN/              # Network Extension
│   ├── PacketTunnelProvider   # VPN implementation
│   ├── DNSEngine              # DNS filtering
│   └── RuleEngine             # Block rules
│
├── CleanViewBlocker/          # Safari Extension
│   └── ContentBlockerRequestHandler
│
├── Shared/                    # Shared code
└── Documentation/             # Guides and policies
```

## 🔧 Setup Guide

Detailed setup instructions are available in:
- [Xcode Setup Guide](CleanViewVPN/Documentation/XcodeSetupGuide.md)

Key steps:
1. Create Xcode project with 4 targets
2. Configure App Groups (group.com.example.cleanview.shared)
3. Add NetworkExtension entitlements
4. Configure provisioning profiles
5. Set up StoreKit products

## 🛠 Technical Implementation

### VPN (Network Extension)
- Local VPN using NEPacketTunnelProvider
- DNS queries intercepted and filtered
- Blocked domains return NXDOMAIN
- Support for custom DNS providers

### Content Blocker
- CSS rules to hide overlays/popups
- Works with Safari and Brave browsers
- Rules updateable from remote server
- Per-site whitelist support

### Subscription System
- StoreKit 2 implementation
- Free tier with basic features
- Pro tier with automatic updates and multiple regions
- Receipt validation

## 📋 Features by Component

### Host App
- [x] VPN connection management
- [x] Subscription handling (StoreKit 2)
- [x] Rule updates from server
- [x] Whitelist management
- [x] Settings and configuration
- [x] SwiftUI interface

### VPN Extension
- [x] Packet tunnel setup
- [x] DNS query interception
- [x] Domain filtering
- [x] Statistics collection
- [x] Whitelist application

### Content Blocker
- [x] CSS-based element hiding
- [x] Rule loading from App Groups
- [x] Dynamic rule updates

## 💰 Monetization

- **Free Tier**
  - Basic ad/tracker blocking
  - Manual rule updates
  - Single region

- **Pro Tier** ($2.99/month or $19.99/year)
  - Daily automatic rule updates
  - Multiple server regions
  - Custom DNS settings
  - Priority support

## 🔒 Privacy & Security

- **No-Logs Policy**: No user data is collected or stored
- **Local Processing**: All filtering happens on-device
- **Open Architecture**: Core logic is transparent and auditable
- **Secure Communication**: All network traffic encrypted

## 📝 Documentation

- [Privacy Policy](CleanViewVPN/Documentation/PrivacyPolicy.md)
- [Support Guide](CleanViewVPN/Documentation/Support.md)
- [App Store Description](CleanViewVPN/Documentation/AppStoreDescription.txt)

## 🧪 Testing

### Unit Tests
```bash
xcodebuild test -scheme CleanView -destination 'platform=iOS Simulator,name=iPhone 15'
# or
make test
```

### Swift Package Manager Tests
```bash
swift test
```

### Real Device Testing
1. Connect iOS device
2. Trust developer certificate
3. Enable VPN in Settings
4. Enable Content Blocker in Safari settings

## 🛠 Development Commands

The project includes a Makefile for common tasks:

```bash
make help      # Show available commands
make setup     # Run initial setup
make build     # Build the project
make test      # Run all tests
make clean     # Clean build artifacts
make archive   # Create App Store archive
```

### XcodeGen Commands
```bash
xcodegen generate           # Regenerate Xcode project
xcodegen generate --spec project.yml --use-cache
```

### Swift Package Manager
```bash
swift build                 # Build SPM packages
swift test                  # Run SPM tests
swift package update        # Update dependencies
```

## 🚢 Deployment

1. Archive the app in Xcode
2. Upload to App Store Connect
3. Submit for review with appropriate notes
4. Monitor review status

## 📊 Performance Targets

- VPN Connection: < 2 seconds
- DNS Response: < 50ms
- Memory Usage: < 50MB (Extension limit)
- Battery Impact: < 2% daily
- Crash Rate: < 0.1%

## 🤝 Contributing

This is currently a private project. For contributions or questions, please contact the maintainer.

## 📄 License

Proprietary - All rights reserved

## 📧 Contact

- Support: support@example.com
- Privacy: privacy@example.com

## 🔄 Version History

- **v1.0.0** (Current)
  - Initial MVP implementation
  - Basic VPN and Content Blocker
  - Subscription system
  - Whitelist management

## ⚠️ Important Notes

1. **Apple Developer Account Required**: NetworkExtension capability requires a paid Apple Developer account ($99/year)
2. **Real Device Testing**: VPN functionality is limited in iOS Simulator
3. **Memory Limits**: Network Extensions have a 50MB memory limit
4. **App Review**: VPN apps require clear justification for App Store review

## 🎯 Next Steps

After cloning this repository:
1. Set up Xcode project following the guide
2. Replace bundle identifiers with your own
3. Configure Apple Developer certificates
4. Test on real device
5. Implement production rule server
6. Submit to App Store

---

Built with Swift, SwiftUI, and privacy in mind.