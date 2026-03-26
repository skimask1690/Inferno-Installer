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

if ! xcode-select -p &>/dev/null; then
    xcode-select --install 2>/dev/null || true

    # Wait until installation completes
    while ! xcode-select -p &>/dev/null; do
        sleep 5
    done
fi


# Mount the APFS with read/write access
hdiutil attach -imagekey diskimage-class=CRawDiskImage -blocksize 4096 -noverify -noautofsck root
sudo diskutil enableownership /Volumes/System
sudo mount -urw /Volumes/System
cd

# Install cmake
if ! command -v cmake >/dev/null; then
  curl -sLO https://github.com/Kitware/CMake/releases/download/v4.3.0/cmake-4.3.0-macos-universal.tar.gz
  tar -xzf cmake-4.3.0-macos-universal.tar.gz
  rm cmake-4.3.0-macos-universal.tar.gz
  sudo mv cmake-4.3.0-macos-universal /usr/local/cmake-4.3.0
  echo 'export PATH="/usr/local/cmake-4.3.0/CMake.app/Contents/bin:$PATH"' >> ~/.zshrc
  export PATH="/usr/local/cmake-4.3.0/CMake.app/Contents/bin:$PATH"
fi

# Patch the Dyld Shared Cache
[ -d InfernoFSPatcher ] || git clone https://git.chefkiss.dev/AppleHax/InfernoFSPatcher
cd InfernoFSPatcher
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=YES -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_STANDARD_REQUIRED=ON
cmake --build build
sudo build/inferno_fs_patcher /Volumes/System/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64e
cd ..
rm -rf InfernoFSPatcher

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
