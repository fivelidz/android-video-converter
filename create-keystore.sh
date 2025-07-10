#!/bin/bash

# Script to create a keystore for signing Android APK/AAB for Play Store
# This should be run only once and the keystore should be kept secure

echo "Creating keystore for Android Video Converter..."
echo "IMPORTANT: Store the keystore file and passwords securely!"
echo ""

# Generate keystore
keytool -genkey -v -keystore android-video-converter-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias android-video-converter

echo ""
echo "Keystore created successfully!"
echo ""
echo "Next steps:"
echo "1. Move the keystore file to a secure location"
echo "2. Create android/key.properties with the keystore details"
echo "3. Update android/app/build.gradle with signing configuration"
echo ""
echo "Sample key.properties content:"
echo "storePassword=<password you entered>"
echo "keyPassword=<password you entered>"
echo "keyAlias=android-video-converter"
echo "storeFile=<path to android-video-converter-key.jks>"