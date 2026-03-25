#!/bin/bash

# ===== URL VARIABLES =====
NETTLE_URL="https://ftp.gnu.org/gnu/nettle/nettle-3.10.1.tar.gz"
QEMU_GIT_URL="https://github.com/ChefKissInc/Inferno"
IMG4LIB_URL="https://github.com/xerub/img4lib/releases/download/1.0/img4lib-2020-10-27.tar.gz"
IPSW_14_BETA5_URL="https://updates.cdn-apple.com/2020SummerSeed/fullrestores/001-35886/5FE9BE2E-17F8-41C8-96BB-B76E2B225888/iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw"
IPSW_14_7_1_URL="https://updates.cdn-apple.com/2021SummerFCS/fullrestores/071-73868/321919C4-1F21-4387-936D-B72374C39DD6/iPhone11,8,iPhone12,1_14.7.1_18G82_Restore.ipsw"
TICKET_URL="https://chefkiss.dev/Extras/Inferno/ticket.shsh2"
SEPTICKET_PY_URL="https://chefkiss.dev/Extras/Inferno/create_septicket.py"
APTICKET_PY_URL="https://chefkiss.dev/Extras/Inferno/create_apticket.py"
SEPROM_URL="https://securerom.fun/resources/SEPROM/AppleSEPROM-Cebu-B1"
ARCHLINUX_ISO_URL="https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"

[ $EUID -ne 0 ] || {
  echo "This script should not be run as root. It will request elevated privileges when necessary."
  exit 1
}

# Prepare the environment
set -e
sudo apt-get update
sudo apt-get install -y build-essential libtool meson ninja-build pkg-config libcapstone-dev device-tree-compiler libglib2.0-dev gnutls-bin libjpeg-turbo8-dev libpng-dev libslirp-dev libssh-dev libusb-1.0-0-dev liblzo2-dev libncurses-dev libpixman-1-dev libsnappy-dev vde2 zstd libgnutls28-dev libgmp10 libgmp3-dev lzfse liblzfse-dev libgtk-3-dev libsdl2-dev git make unzip curl python3-venv python3-pyasn1 python3-pyasn1-modules python3-pip
python3 -m pip install --user --upgrade meson --break-system-packages --no-warn-script-location

# Install nettle if missing
if grep -q '3.10.1' /usr/local/lib64/pkgconfig/nettle.pc 2>/dev/null
then
  export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig
elif ! [ "$(pkg-config --modversion nettle)" = "3.10.1" ]
then
  wget -c $NETTLE_URL
  tar -xf nettle-3.10.1.tar.gz
  cd nettle-3.10.1
  ./configure
  make -j$(nproc)
  sudo make install
  cd ..
  rm -rf nettle-3.10.1.tar.gz nettle-3.10.1
  export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig
fi

# Clone or enter Inferno
if [ -d ../../Inferno/build ]
then
  cd ../../Inferno/build
elif [ -d ../Inferno/build ]
then
  cd ../Inferno/build
elif [ -d Inferno/build ]
then
  cd Inferno/build
elif [ ! -d Inferno ]
then
  git clone $QEMU_GIT_URL
  cd Inferno
  git submodule update --init
  mkdir build
  cd build
  ../configure --target-list=aarch64-softmmu,x86_64-softmmu --enable-lzfse --enable-slirp --enable-curses --enable-libssh --enable-virtfs --enable-zstd --enable-nettle --enable-gnutls --enable-gtk --enable-sdl --disable-werror --disable-qom-cast-debug --extra-cflags="-O3 -ffast-math -mtune=native" --disable-debug-info
  make -j$(nproc)
fi

# Download img4lib
[ -f img4 ] || {
  wget -c $IMG4LIB_URL
  tar -xf img4lib-2020-10-27.tar.gz img4lib-2020-10-27/linux/img4
  [ -f /lib/x86_64-linux-gnu/libcrypto.so.1 ] || sudo ln -s /lib/x86_64-linux-gnu/libcrypto.so /lib/x86_64-linux-gnu/libcrypto.so.1
  mv img4lib-2020-10-27/linux/img4 .
  rm -rf img4lib-2020-10-27.tar.gz img4lib-2020-10-27
}

# Fetch iOS 14.0 beta 5 IPSW
[ -d iPhone11_8_iPhone12_1_14.0_18A5351d_Restore ] || {
  wget -c $IPSW_14_BETA5_URL
  unzip iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw -d iPhone11_8_iPhone12_1_14.0_18A5351d_Restore -x 038-44337-083.dmg
  rm -f iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw
}

# Fetch iOS 14.7.1 IPSW
[ -f sep-firmware.n104.RELEASE.im4p ] || {
  wget -c $IPSW_14_7_1_URL
  unzip iPhone11,8,iPhone12,1_14.7.1_18G82_Restore.ipsw Firmware/all_flash/sep-firmware.n104.RELEASE.im4p
  mv Firmware/all_flash/sep-firmware.n104.RELEASE.im4p .
  rm -rf iPhone11,8,iPhone12,1_14.7.1_18G82_Restore.ipsw Firmware
}

# Download SHSH blob
[ -f ticket.shsh2 ] || wget $TICKET_URL

# Create the SEP ticket
[ -f sep_root_ticket.der ] || python3 -c "$(curl -s $SEPTICKET_PY_URL)" n104ap iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/BuildManifest.plist ticket.shsh2 sep_root_ticket.der

# Decrypt the firmware
[ -f sep-firmware.n104.RELEASE ] || ./img4 -i iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/Firmware/all_flash/sep-firmware.n104.RELEASE.im4p -o sep-firmware.n104.RELEASE -k 017a328b048aab2edcc4cfe043c2d844a55e67143d57938e37ec6b83ba9e181c0d24bd0a6a14f9f39752b967a9c45cfc

# Format the firmware to IMG4
[ -f sep-firmware.n104.RELEASE.new.img4 ] || ./img4 -A -F -o sep-firmware.n104.RELEASE.new.img4 -i sep-firmware.n104.RELEASE -M sep_root_ticket.der -T rsep -V ff86cbb5e06c820266308202621604696d706c31820258ff87a3e8e0730e300c1604747a3073020407d98000ff868bc9da730e300c160461726d73020400d20000ff87a389da7382010e3082010a160474626d730482010039643535663434646630353239653731343134656461653733396135313135323233363864626361653434386632333132313634356261323237326537366136633434643037386439313434626564383530616136353131343863663363356365343365656536653566326364636666336664313532316232623062376464353461303436633165366432643436623534323537666531623633326661653738313933326562383838366339313537623963613863366331653137373730336531373735616663613265313637626365353435626635346366653432356432653134653734336232303661386337373234386661323534663439643532636435ff87a389da7282010e3082010a160474626d720482010064643434643762663039626238333965353763383037303431326562353636343131643837386536383635343337613861303266363464383431346664343764383634336530313335633135396531393062656535643435333133363838653063323535373435333533326563303163363530386265383236333738353065623761333036343162353464313236306663313434306562663862343063306632646262616437343964643461656339376534656238646532346330663265613432346161613438366664663631363961613865616331313865383839383566343138643263366437363364303434363063393531386164353766316235636664

# Create the AP ticket
[ -f root_ticket.der ] || python3 -c "$(curl -s $APTICKET_PY_URL)" n104ap iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/BuildManifest.plist ticket.shsh2 root_ticket.der

# Download SEP ROM
[ -f AppleSEPROM-Cebu-B1 ] || wget $SEPROM_URL

# Create the disks
[ -f root ]         || ./qemu-img create -f raw root 16G # Can also be 32G
[ -f firmware ]     || ./qemu-img create -f raw firmware 8M
[ -f syscfg ]       || ./qemu-img create -f raw syscfg 128K
[ -f ctrl_bits ]    || ./qemu-img create -f raw ctrl_bits 8K
[ -f nvram ]        || ./qemu-img create -f raw nvram 8K
[ -f effaceable ]   || ./qemu-img create -f raw effaceable 4K
[ -f panic_log ]    || ./qemu-img create -f raw panic_log 1M
[ -f sep_nvram ]    || ./qemu-img create -f raw sep_nvram 64K
[ -f sep_ssc ]      || ./qemu-img create -f raw sep_ssc 128K

[ -f archvm.qcow2 ] || ./qemu-img create -f qcow2 archvm.qcow2 20G

sync

# Download Arch Linux ISO
wget -c $ARCHLINUX_ISO_URL

[ ! -e /dev/kvm ] || {
  SU_FLAG="sudo"
  KVM_FLAG="-enable-kvm"
  sudo -v
}

echo "Starting Companion VM (USB server)..."
$SU_FLAG ./qemu-system-x86_64 $KVM_FLAG -m 2G -cdrom archlinux-x86_64.iso \
  -drive file=archvm.qcow2,format=qcow2,if=virtio \
  -nic user,model=virtio-net-pci,hostfwd=tcp::32222-:22 \
  -usb -device usb-ehci,id=ehci -device usb-tcp-remote,conn-type=ipv4,conn-addr=127.0.0.1,conn-port=8030,bus=ehci.0 &

echo "Starting iPhone emulator..."
./qemu-system-aarch64 -M t8030,trustcache=iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/Firmware/038-44135-124.dmg.trustcache,ticket=root_ticket.der,sep-fw=sep-firmware.n104.RELEASE.new.img4,sep-rom=AppleSEPROM-Cebu-B1,kaslr-off=true,usb-conn-type=ipv4,usb-conn-addr=127.0.0.1,usb-conn-port=8030 \
  -kernel iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/kernelcache.research.iphone12b \
  -dtb iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/Firmware/all_flash/DeviceTree.n104ap.im4p \
  -initrd iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/038-44135-124.dmg \
  -append "tlto_us=-1 mtxspin=-1 agm-genuine=1 agm-authentic=1 agm-trusted=1 serial=3 wdt=-1 -vm_compressor_wk_sw" \
  -display sdl,show-cursor=on \
  -smp 7 -m 4G -serial mon:stdio \
  -drive file=sep_nvram,if=pflash,format=raw \
  -drive file=sep_ssc,if=pflash,format=raw \
  -drive file=root,format=raw,if=none,id=root -device nvme-ns,drive=root,bus=nvme-bus.0,nsid=1,nstype=1,logical_block_size=4096,physical_block_size=4096 \
  -drive file=firmware,format=raw,if=none,id=firmware -device nvme-ns,drive=firmware,bus=nvme-bus.0,nsid=2,nstype=2,logical_block_size=4096,physical_block_size=4096 \
  -drive file=syscfg,format=raw,if=none,id=syscfg -device nvme-ns,drive=syscfg,bus=nvme-bus.0,nsid=3,nstype=3,logical_block_size=4096,physical_block_size=4096 \
  -drive file=ctrl_bits,format=raw,if=none,id=ctrl_bits -device nvme-ns,drive=ctrl_bits,bus=nvme-bus.0,nsid=4,nstype=4,logical_block_size=4096,physical_block_size=4096 \
  -drive file=nvram,if=none,format=raw,id=nvram -device apple-nvram,drive=nvram,bus=nvme-bus.0,nsid=5,nstype=5,id=nvram,logical_block_size=4096,physical_block_size=4096 \
  -drive file=effaceable,format=raw,if=none,id=effaceable -device nvme-ns,drive=effaceable,bus=nvme-bus.0,nsid=6,nstype=6,logical_block_size=4096,physical_block_size=4096 \
  -drive file=panic_log,format=raw,if=none,id=panic_log -device nvme-ns,drive=panic_log,bus=nvme-bus.0,nsid=7,nstype=8,logical_block_size=4096,physical_block_size=4096
