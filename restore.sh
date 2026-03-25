#!/usr/bin/bash

# ===== URL VARIABLES =====
IPSW_14_BETA5_URL="https://updates.cdn-apple.com/2020SummerSeed/fullrestores/001-35886/5FE9BE2E-17F8-41C8-96BB-B76E2B225888/iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw"
TICKET_URL="https://chefkiss.dev/Extras/Inferno/ticket.shsh2"
APTICKET_PY_URL="https://chefkiss.dev/Extras/Inferno/create_apticket.py"
IDR_PATCH_URL="https://chefkiss.dev/Extras/Inferno/idevicerestore.patch"
LIBIMOBILEDEVICE_REPO_BASE="https://github.com/libimobiledevice"

# Prepare the environment
set -e

pacman -Sy --needed --noconfirm base-devel libtool libzip autoconf automake pkg-config git wget unzip python python-pyasn1 python-pyasn1-modules libplist libusbmuxd libimobiledevice-glue libimobiledevice usbmuxd

wget -c $IPSW_14_BETA5_URL
[ -f BuildManifest.plist ] || unzip iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw BuildManifest.plist
[ -f ticket.shsh2 ] || wget $TICKET_URL
[ -f root_ticket.der ] || python3 -c "$(curl -s $APTICKET_PY_URL)" n104ap BuildManifest.plist ticket.shsh2 root_ticket.der

if ! idevicerestore -v 2>&1 | grep -q lib
then
  for repo in libtatsu libirecovery idevicerestore
  do
    [ -d $repo ] || git clone "$LIBIMOBILEDEVICE_REPO_BASE/$repo"

    cd $repo

    [ $repo != "idevicerestore" ] || {
      wget -c $IDR_PATCH_URL
      git apply idevicerestore.patch
    }

    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/ ./autogen.sh
    make -j$(nproc)
    sudo make install
    cd ..
    rm -rf $repo
  done
fi

# Start the restore
idevicerestore --erase --restore-mode -i 0x1122334455667788 iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw -T root_ticket.der
