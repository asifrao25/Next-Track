#!/bin/bash

# Been There Xcode Project Setup Script
# This script generates the Xcode project using XcodeGen

echo "🚀 Been There Project Setup"
echo "=========================="

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "📦 XcodeGen not found. Installing via Homebrew..."

    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew is not installed. Please install it first:"
        echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi

    brew install xcodegen

    if [ $? -ne 0 ]; then
        echo "❌ Failed to install XcodeGen"
        exit 1
    fi
fi

echo "✅ XcodeGen is installed"

# Navigate to project directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "📁 Working directory: $SCRIPT_DIR"

# Create Assets catalog if it doesn't exist
ASSETS_DIR="Been There/Resources/Assets.xcassets"
if [ ! -d "$ASSETS_DIR" ]; then
    echo "📂 Creating Assets catalog..."
    mkdir -p "$ASSETS_DIR/AppIcon.appiconset"
    mkdir -p "$ASSETS_DIR/AccentColor.colorset"

    # Create Contents.json for Assets
    cat > "$ASSETS_DIR/Contents.json" << 'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

    # Create AppIcon Contents.json
    cat > "$ASSETS_DIR/AppIcon.appiconset/Contents.json" << 'EOF'
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

    # Create AccentColor Contents.json
    cat > "$ASSETS_DIR/AccentColor.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.933",
          "green" : "0.478",
          "red" : "0.000"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
fi

# Generate Xcode project
echo "🔧 Generating Xcode project..."
xcodegen generate

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Project generated successfully!"
    echo ""
    echo "📱 Next steps:"
    echo "   1. Open 'Been There.xcodeproj' in Xcode"
    echo "   2. Select your Apple Developer Team in Signing & Capabilities"
    echo "   3. Connect your iPhone and run the app"
    echo ""
    echo "🔗 To configure PhoneTrack:"
    echo "   1. Open Nextcloud and go to PhoneTrack"
    echo "   2. Create a new tracking session"
    echo "   3. Copy the logging URL or scan the QR code in the app"
    echo ""

    # Ask to open Xcode
    read -p "Would you like to open the project in Xcode now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "Been There.xcodeproj"
    fi
else
    echo "❌ Failed to generate project"
    exit 1
fi
