#!/bin/bash

# Script to open Android emulator and run Flutter app

echo "Starting Android emulator..."

# Try to find emulator command
EMULATOR_CMD=""
if command -v emulator &> /dev/null; then
    EMULATOR_CMD="emulator"
elif [ -f "$HOME/Library/Android/sdk/emulator/emulator" ]; then
    EMULATOR_CMD="$HOME/Library/Android/sdk/emulator/emulator"
elif [ -f "$ANDROID_HOME/emulator/emulator" ]; then
    EMULATOR_CMD="$ANDROID_HOME/emulator/emulator"
fi

if [ -z "$EMULATOR_CMD" ]; then
    echo "Error: Android emulator command not found."
    echo "Please ensure Android SDK is installed and in your PATH."
    echo "Or set ANDROID_HOME environment variable."
    exit 1
fi

# List available emulators
$EMULATOR_CMD -list-avds

# Check if emulator is already running
if adb devices | grep -q "emulator"; then
    echo "Emulator already running."
else
    # Start the first available emulator (or specify a particular one)
    # You can change "Pixel_6_Pro_API_33" to your specific emulator name if needed
    $EMULATOR_CMD -avd Pixel_9 -no-snapshot-load &

    # Wait for emulator to boot
    echo "Waiting for emulator to boot..."
    adb wait-for-device
fi

# Run Flutter app
echo "Running Flutter app on Android..."
flutter run android
