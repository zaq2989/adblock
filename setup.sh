#!/bin/bash

# CleanViewVPN Xcode Project Setup Script
# This script automates the setup process on Mac environment

set -e  # Exit on error

echo "🚀 CleanViewVPN Project Setup Starting..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables
DEFAULT_BUNDLE_PREFIX="com.example"
DEFAULT_TEAM_ID="YOUR_TEAM_ID"

# Function to print colored output
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script must be run on macOS"
    exit 1
fi

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode is not installed. Please install Xcode from the App Store."
    exit 1
fi

echo "📋 Current Xcode version:"
xcodebuild -version

# Step 1: Get user configuration
echo ""
echo "📝 Configuration Setup"
echo "======================"

read -p "Enter your bundle identifier prefix (e.g., com.yourcompany) [$DEFAULT_BUNDLE_PREFIX]: " BUNDLE_PREFIX
BUNDLE_PREFIX=${BUNDLE_PREFIX:-$DEFAULT_BUNDLE_PREFIX}

read -p "Enter your Development Team ID [$DEFAULT_TEAM_ID]: " TEAM_ID
TEAM_ID=${TEAM_ID:-$DEFAULT_TEAM_ID}

read -p "Enter your organization name: " ORG_NAME
ORG_NAME=${ORG_NAME:-"Your Organization"}

# Step 2: Update bundle identifiers in all files
echo ""
echo "🔄 Updating Bundle Identifiers..."

# Update Swift files
find CleanViewVPN -name "*.swift" -type f -exec sed -i '' "s/$DEFAULT_BUNDLE_PREFIX/$BUNDLE_PREFIX/g" {} \;

# Update plist files
find CleanViewVPN -name "*.plist" -type f -exec sed -i '' "s/$DEFAULT_BUNDLE_PREFIX/$BUNDLE_PREFIX/g" {} \;

# Update entitlements files
find CleanViewVPN -name "*.entitlements" -type f -exec sed -i '' "s/$DEFAULT_BUNDLE_PREFIX/$BUNDLE_PREFIX/g" {} \;

# Update project.yml
sed -i '' "s/bundleIdPrefix: $DEFAULT_BUNDLE_PREFIX/bundleIdPrefix: $BUNDLE_PREFIX/g" project.yml
sed -i '' "s/DEVELOPMENT_TEAM: $DEFAULT_TEAM_ID/DEVELOPMENT_TEAM: $TEAM_ID/g" project.yml
sed -i '' "s/group\.$DEFAULT_BUNDLE_PREFIX/group.$BUNDLE_PREFIX/g" project.yml

print_success "Bundle identifiers updated"

# Step 3: Install dependencies
echo ""
echo "📦 Installing Dependencies..."

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
    print_warning "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "Installing XcodeGen..."
    brew install xcodegen
else
    print_success "XcodeGen already installed"
fi

# Install SwiftLint (optional but recommended)
if ! command -v swiftlint &> /dev/null; then
    print_warning "SwiftLint not found. Installing..."
    brew install swiftlint
else
    print_success "SwiftLint already installed"
fi

# Step 4: Create test directories if they don't exist
echo ""
echo "📁 Creating directory structure..."

mkdir -p CleanViewTests
mkdir -p CleanViewUITests
mkdir -p CleanViewVPN/CleanView/Assets.xcassets/AppIcon.appiconset
mkdir -p CleanViewVPN/CleanView/Assets.xcassets/AccentColor.colorset

print_success "Directory structure created"

# Step 5: Create basic test files
echo ""
echo "📝 Creating test files..."

# Create basic unit test
cat > CleanViewTests/CleanViewTests.swift << 'EOF'
import XCTest
@testable import CleanView

final class CleanViewTests: XCTestCase {

    func testExample() throws {
        // Basic test to ensure project builds
        XCTAssertTrue(true)
    }

    func testVPNConfiguration() throws {
        // Test VPN configuration
        XCTAssertNotNil(VPNConfig.localDNS)
    }
}
EOF

# Create basic UI test
cat > CleanViewUITests/CleanViewUITests.swift << 'EOF'
import XCTest

final class CleanViewUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Basic UI test
        XCTAssert(app.buttons["shield.fill"].exists || app.buttons["shield.slash.fill"].exists)
    }
}
EOF

print_success "Test files created"

# Step 6: Generate Xcode project
echo ""
echo "🔨 Generating Xcode Project..."

xcodegen generate

if [ -f "CleanViewVPN.xcodeproj/project.pbxproj" ]; then
    print_success "Xcode project generated successfully"
else
    print_error "Failed to generate Xcode project"
    exit 1
fi

# Step 7: Create .swiftlint.yml configuration
echo ""
echo "📝 Creating SwiftLint configuration..."

cat > .swiftlint.yml << 'EOF'
disabled_rules:
  - trailing_whitespace
  - line_length
  - file_length
  - type_body_length
  - function_body_length

opt_in_rules:
  - empty_count
  - closure_spacing
  - contains_over_filter_count
  - first_where
  - force_unwrapping

excluded:
  - Carthage
  - Pods
  - .build
  - CleanViewTests
  - CleanViewUITests

line_length:
  warning: 150
  error: 200

identifier_name:
  min_length: 2
  max_length: 50
EOF

print_success "SwiftLint configuration created"

# Step 8: Create xcconfig files for better configuration management
echo ""
echo "📝 Creating xcconfig files..."

mkdir -p Configuration

# Base configuration
cat > Configuration/Base.xcconfig << EOF
// Base Configuration
PRODUCT_BUNDLE_PREFIX = $BUNDLE_PREFIX
DEVELOPMENT_TEAM = $TEAM_ID
IPHONEOS_DEPLOYMENT_TARGET = 16.0
SWIFT_VERSION = 5.9
EOF

# Debug configuration
cat > Configuration/Debug.xcconfig << 'EOF'
#include "Base.xcconfig"

// Debug Configuration
SWIFT_OPTIMIZATION_LEVEL = -Onone
ENABLE_TESTABILITY = YES
DEBUG_INFORMATION_FORMAT = dwarf
EOF

# Release configuration
cat > Configuration/Release.xcconfig << 'EOF'
#include "Base.xcconfig"

// Release Configuration
SWIFT_OPTIMIZATION_LEVEL = -O
ENABLE_TESTABILITY = NO
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
EOF

print_success "Configuration files created"

# Step 9: Create a Makefile for common tasks
echo ""
echo "📝 Creating Makefile..."

cat > Makefile << 'EOF'
.PHONY: help setup build test clean archive

help:
	@echo "Available commands:"
	@echo "  make setup    - Initial project setup"
	@echo "  make build    - Build the project"
	@echo "  make test     - Run tests"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make archive  - Create archive for App Store"

setup:
	./setup.sh

build:
	xcodebuild -scheme CleanView -configuration Debug build

test:
	xcodebuild -scheme CleanView -configuration Debug test

clean:
	xcodebuild -scheme CleanView clean
	rm -rf ~/Library/Developer/Xcode/DerivedData/CleanViewVPN*

archive:
	xcodebuild -scheme CleanView -configuration Release archive

regenerate:
	xcodegen generate
EOF

print_success "Makefile created"

# Step 10: Final instructions
echo ""
echo "========================================="
echo -e "${GREEN}✨ Setup Complete!${NC}"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Open the project: open CleanViewVPN.xcodeproj"
echo "2. Select your team in Signing & Capabilities for each target"
echo "3. Build and run: ⌘+R"
echo ""
echo "Useful commands:"
echo "  make build    - Build the project"
echo "  make test     - Run tests"
echo "  make clean    - Clean build"
echo ""
echo "Configuration:"
echo "  Bundle Prefix: $BUNDLE_PREFIX"
echo "  Team ID: $TEAM_ID"
echo "  Organization: $ORG_NAME"
echo ""
print_warning "Remember to:"
echo "  1. Enable NetworkExtension capability in Apple Developer Portal"
echo "  2. Create App IDs for each target"
echo "  3. Generate provisioning profiles"
echo ""
echo "📚 Documentation: CleanViewVPN/Documentation/XcodeSetupGuide.md"

# Optional: Open Xcode
read -p "Do you want to open the project in Xcode now? (y/n): " OPEN_XCODE
if [[ $OPEN_XCODE == "y" || $OPEN_XCODE == "Y" ]]; then
    open CleanViewVPN.xcodeproj
fi