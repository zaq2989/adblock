# Makefile for CleanViewVPN iOS Project
# Run 'make help' to see available commands

.PHONY: help setup build test clean archive regenerate install-deps format lint

# Default target
help:
	@echo "╔══════════════════════════════════════════╗"
	@echo "║     CleanViewVPN Development Commands    ║"
	@echo "╚══════════════════════════════════════════╝"
	@echo ""
	@echo "Setup & Configuration:"
	@echo "  make setup        - Run initial project setup"
	@echo "  make install-deps - Install dependencies (XcodeGen, SwiftLint)"
	@echo "  make regenerate   - Regenerate Xcode project from config"
	@echo ""
	@echo "Development:"
	@echo "  make build        - Build the project (Debug)"
	@echo "  make test         - Run all tests"
	@echo "  make clean        - Clean build artifacts"
	@echo "  make format       - Format Swift code"
	@echo "  make lint         - Run SwiftLint"
	@echo ""
	@echo "Release:"
	@echo "  make archive      - Create App Store archive"
	@echo "  make build-release - Build Release configuration"
	@echo ""
	@echo "Utilities:"
	@echo "  make open         - Open project in Xcode"
	@echo "  make reset        - Reset project (clean + regenerate)"

# Initial setup
setup:
	@echo "🚀 Running initial setup..."
	@chmod +x setup.sh
	@./setup.sh

# Install dependencies
install-deps:
	@echo "📦 Installing dependencies..."
	@if ! command -v brew &> /dev/null; then \
		echo "Installing Homebrew..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	fi
	@if ! command -v xcodegen &> /dev/null; then \
		echo "Installing XcodeGen..."; \
		brew install xcodegen; \
	fi
	@if ! command -v swiftlint &> /dev/null; then \
		echo "Installing SwiftLint..."; \
		brew install swiftlint; \
	fi
	@echo "✅ Dependencies installed"

# Regenerate Xcode project
regenerate:
	@echo "🔄 Regenerating Xcode project..."
	@xcodegen generate
	@echo "✅ Project regenerated"

# Build project (Debug)
build:
	@echo "🔨 Building project (Debug)..."
	@xcodebuild -scheme CleanView -configuration Debug build | xcpretty

# Build project (Release)
build-release:
	@echo "🔨 Building project (Release)..."
	@xcodebuild -scheme CleanView -configuration Release build | xcpretty

# Run tests
test:
	@echo "🧪 Running tests..."
	@xcodebuild test \
		-scheme CleanView \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-configuration Debug | xcpretty

# Run SPM tests
test-spm:
	@echo "🧪 Running Swift Package Manager tests..."
	@swift test

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@xcodebuild -scheme CleanView clean | xcpretty
	@rm -rf ~/Library/Developer/Xcode/DerivedData/CleanViewVPN*
	@rm -rf .build
	@echo "✅ Clean complete"

# Create archive for App Store
archive:
	@echo "📦 Creating App Store archive..."
	@xcodebuild archive \
		-scheme CleanView \
		-configuration Release \
		-archivePath ./build/CleanView.xcarchive | xcpretty
	@echo "✅ Archive created at ./build/CleanView.xcarchive"

# Format Swift code
format:
	@echo "✨ Formatting Swift code..."
	@if command -v swiftformat &> /dev/null; then \
		swiftformat . --config .swiftformat; \
	else \
		echo "SwiftFormat not installed. Install with: brew install swiftformat"; \
	fi

# Run SwiftLint
lint:
	@echo "🔍 Running SwiftLint..."
	@if command -v swiftlint &> /dev/null; then \
		swiftlint; \
	else \
		echo "SwiftLint not installed. Install with: brew install swiftlint"; \
	fi

# Open project in Xcode
open:
	@echo "📱 Opening project in Xcode..."
	@open CleanViewVPN.xcodeproj

# Reset project (clean + regenerate)
reset: clean regenerate
	@echo "✅ Project reset complete"

# Check project configuration
check:
	@echo "🔍 Checking project configuration..."
	@echo "Bundle IDs:"
	@grep -r "PRODUCT_BUNDLE_IDENTIFIER" project.yml | cut -d':' -f2
	@echo ""
	@echo "Team ID:"
	@grep "DEVELOPMENT_TEAM" project.yml | head -1 | cut -d':' -f2
	@echo ""
	@echo "iOS Deployment Target:"
	@grep "IPHONEOS_DEPLOYMENT_TARGET" project.yml | head -1 | cut -d':' -f2

# Update bundle identifiers
update-bundle-id:
	@read -p "Enter new bundle prefix (e.g., com.yourcompany): " prefix; \
	find CleanViewVPN -name "*.swift" -type f -exec sed -i '' "s/com\.example/$$prefix/g" {} \; ; \
	find CleanViewVPN -name "*.plist" -type f -exec sed -i '' "s/com\.example/$$prefix/g" {} \; ; \
	find CleanViewVPN -name "*.entitlements" -type f -exec sed -i '' "s/com\.example/$$prefix/g" {} \; ; \
	sed -i '' "s/bundleIdPrefix: com\.example/bundleIdPrefix: $$prefix/g" project.yml; \
	echo "✅ Bundle identifiers updated to $$prefix"

# Git operations
commit:
	@git add -A
	@git commit -m "Update project configuration"

push:
	@git push origin main

# CI/CD helpers
ci-test:
	@set -o pipefail && xcodebuild test \
		-scheme CleanView \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-configuration Debug \
		-enableCodeCoverage YES | xcpretty -r junit

# Default target
.DEFAULT_GOAL := help