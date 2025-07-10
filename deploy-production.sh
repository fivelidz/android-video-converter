#!/bin/bash

echo "🚀 Android Video Converter - Production Deployment Script"
echo "========================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi
print_status "Flutter is installed"

# Check if keystore configuration exists
if [ ! -f "android/key.properties" ]; then
    print_warning "No keystore configuration found"
    echo "Please create android/key.properties with your keystore details"
    echo "Run ./create-keystore.sh first if you haven't created a keystore"
    exit 1
fi
print_status "Keystore configuration found"

# Clean previous builds
echo ""
echo "🧹 Cleaning previous builds..."
flutter clean
print_status "Build directory cleaned"

# Get dependencies
echo ""
echo "📦 Getting dependencies..."
flutter pub get
if [ $? -eq 0 ]; then
    print_status "Dependencies resolved"
else
    print_error "Failed to get dependencies"
    exit 1
fi

# Run code analysis
echo ""
echo "🔍 Running code analysis..."
flutter analyze --no-pub
if [ $? -eq 0 ]; then
    print_status "Code analysis passed"
else
    print_warning "Code analysis found issues - review before publishing"
fi

# Run tests
echo ""
echo "🧪 Running tests..."
flutter test
if [ $? -eq 0 ]; then
    print_status "All tests passed"
else
    print_warning "Some tests failed - review before publishing"
fi

# Build App Bundle for Play Store
echo ""
echo "📱 Building App Bundle for Play Store..."
flutter build appbundle --release
if [ $? -eq 0 ]; then
    print_status "App Bundle built successfully"
    echo "📁 App Bundle location: build/app/outputs/bundle/release/app-release.aab"
else
    print_error "Failed to build App Bundle"
    exit 1
fi

# Build APK for testing
echo ""
echo "📱 Building release APK for testing..."
flutter build apk --release
if [ $? -eq 0 ]; then
    print_status "Release APK built successfully"
    echo "📁 APK location: build/app/outputs/flutter-apk/app-release.apk"
else
    print_error "Failed to build release APK"
    exit 1
fi

# Show build information
echo ""
echo "📊 Build Information:"
echo "===================="
AAB_SIZE=$(du -h build/app/outputs/bundle/release/app-release.aab | cut -f1)
APK_SIZE=$(du -h build/app/outputs/flutter-apk/app-release.apk | cut -f1)
echo "App Bundle (AAB): $AAB_SIZE"
echo "APK: $APK_SIZE"

echo ""
print_status "Production build completed successfully!"
echo ""
echo "🎯 Next Steps:"
echo "1. Test the APK on physical devices"
echo "2. Upload the AAB to Google Play Console"
echo "3. Complete store listing with screenshots and descriptions"
echo "4. Submit for review"
echo ""
echo "📁 Files ready for submission:"
echo "   • App Bundle: build/app/outputs/bundle/release/app-release.aab"
echo "   • Test APK: build/app/outputs/flutter-apk/app-release.apk"