#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# --- CONFIGURATION ---
PHONE_IP="192.168.8.150"
PHONE_PORT="2222"
PHONE_USER="ssh"  # Change to your Termux/SSH username (e.g., 'root' or 'change_me')
#REMOTE_DEST="/storage/emulated/0/Download/"       # Destination directory on the Android device
REMOTE_DEST="./"       # Destination directory on the Android device

# Local paths derived from standard Flutter build outputs
APK_SOURCE="build/app/outputs/flutter-apk/app-release.apk"
APK_TARGET_NAME="app-release.apk"

# --- COLOR OUTPUT UTILITIES ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0;0m' # No Color

echo -e "${BLUE}[1/3] Initiating Flutter Production Build...${NC}"

# Compile the release APK configuration
flutter build apk --release

# Double check that the artifact actually exists before network transfer
if [ ! -f "$APK_SOURCE" ]; then
    echo -e "${RED}Error: Compiled APK artifact not found at $APK_SOURCE${NC}"
    exit 1
fi

echo -e "${GREEN}[✔] Build successful!${NC}"
echo -e "${BLUE}[2/3] Uploading APK to phone over SSH...${NC}"

# Upload the file using scp over the specific port mapping
scp -P "${PHONE_PORT}" "${APK_SOURCE}" "${PHONE_USER}@${PHONE_IP}:${REMOTE_DEST}${APK_TARGET_NAME}"

echo -e "${GREEN}[✔] Upload complete! File saved to phone at: ${REMOTE_DEST}${APK_TARGET_NAME}${NC}"
echo -e "${BLUE}[3/3] Attempting local installation loop on device...${NC}"

# Optional: Run adb or package manager commands locally inside the phone's shell terminal environment 
# Note: This step requires your phone's internal SSH environment to have local root/su privileges or native access to 'pm'.
ssh -p "${PHONE_PORT}" "${PHONE_USER}@${PHONE_IP}" "log 'Installing new build...'; pm install -r ${REMOTE_DEST}${APK_TARGET_NAME}" || {
    echo -e "${RED}Notice: Remote automatic installation skipped or failed. (Requires native root/package manager access on the phone's SSH environment).${NC}"
    echo -e "${BLUE}You can manually tap and install the file located in your phone's 'Download' folder.${NC}"
}

echo -e "${GREEN}====== DEPLOYMENT PROCESS COMPLETE ======${NC}"