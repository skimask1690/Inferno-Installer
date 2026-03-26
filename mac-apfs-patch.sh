#!/bin/bash

# NOTE: This script must be run on macOS.

set -e

[ "$(uname)" = "Darwin" ] || {
    echo This script must be run on macOS.
    exit
}

[ ! -f Inferno/build/root ] || cd Inferno/build

[ -f root ] || {
  echo "APFS not found. Exiting..."
  exit 1
}

# Trigger installation (this will open the GUI if not installed)
xcode-select --install 2>/dev/null || true

# Wait until the tools are installed
echo "Waiting for Xcode Command Line Tools to be installed..."
while ! xcode-select -p &>/dev/null; do
    sleep 5
done

echo "Xcode Command Line Tools installed. Proceeding..."

# Mount the APFS with read/write access
hdiutil attach -imagekey diskimage-class=CRawDiskImage -blocksize 4096 -noverify -noautofsck root
sudo diskutil enableownership /Volumes/System
sudo mount -urw /Volumes/System

# Patch the Dyld Shared Cache
git clone https://git.chefkiss.dev/AppleHax/InfernoFSPatcher
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=YES -DCMAKE_BUILD_TYPE=Release
cmake --build build
sudo build/inferno_fs_patcher /Volumes/System/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64e

# Disable the Problematic Launch Services
sudo cp /Volumes/System/System/Library/xpc/launchd.plist /Volumes/System/System/Library/xpc/launchd.plist.orig
sudo plutil -convert xml1 /Volumes/System/System/Library/xpc/launchd.plist

services=(
  "com.apple.voicemail.vmd"
  "com.apple.CommCenter"
  "com.apple.CommCenterMobileHelper"
  "com.apple.CommCenterRootHelper"
  "com.apple.locationd"
)

for service in "${services[@]}"
do
  esc_full=$(printf '%s\n' "/System/Library/LaunchDaemons/$service.plist" | sed 's:/:\\/:g')

  sudo sed -i '' "/<key>${esc_full}<\/key>/ {
    n
    /<dict>/ {
      n
      i\\
$(printf '\t\t\t')<key>Disabled</key>\\
$(printf '\t\t\t')<true/>
    }
  }" /Volumes/System/System/Library/xpc/launchd.plist
done

diskutil eject /Volumes/System

echo "APFS successfully patched."
