#!/usr/bin/sh
apt update
apt install curl debootstrap xorriso squashfs-tools mtools grub-pc-bin grub-efi -y

set -ex
mkdir chroot || true
export DEBIAN_FRONTEND=noninteractive
ln -s sid /usr/share/debootstrap/scripts/yirmibes-deb || true
debootstrap  --no-check-gpg --arch=amd64 yirmibes-deb chroot http://depo.pardus.org.tr/pardus
for i in dev dev/pts proc sys; do mount -o bind /$i chroot/$i; done

cat > chroot/etc/apt/sources.list << EOF
deb http://depo.pardus.org.tr/pardus yirmibes main contrib non-free non-free-firmware
deb http://depo.pardus.org.tr/pardus yirmibes-deb main contrib non-free non-free-firmware
deb http://depo.pardus.org.tr/guvenlik yirmibes-deb main contrib non-free non-free-firmware
EOF

#cat > chroot/etc/apt/sources.list.d/yirmibes-backports.list << EOF
#deb http://depo.pardus.org.tr/backports yirmibes-backports main contrib non-free non-free-firmware
#EOF

chroot chroot apt update --allow-insecure-repositories
chroot chroot apt install pardus-archive-keyring --allow-unauthenticated -y

chroot chroot apt update -y

chroot chroot apt install gnupg grub-pc-bin grub-efi-ia32-bin grub-efi live-config live-boot plymouth plymouth-themes -y

echo -e "#!/bin/sh\nexit 101" > chroot/usr/sbin/policy-rc.d
chmod +x chroot/usr/sbin/policy-rc.d

#Kernel
#chroot chroot apt install -t yirmiuc-backports linux-image-amd64 -y

#Firmwares
chroot chroot apt install -y linux-image-amd64 firmware-linux firmware-linux-free firmware-linux-nonfree firmware-misc-nonfree firmware-amd-graphics firmware-realtek bluez-firmware \
firmware-intel-sound firmware-iwlwifi firmware-atheros firmware-b43-installer firmware-b43legacy-installer firmware-bnx2 firmware-bnx2x firmware-brcm80211 \
firmware-cavium firmware-libertas firmware-myricom firmware-netxen firmware-qlogic firmware-samsung firmware-siano firmware-ti-connectivity firmware-zd1211
    
#Init and Window System
chroot chroot apt install xorg xinit lightdm -y

#Desktop apps
chroot chroot apt install -y gedit eog gnome-screenshot gnome-clocks gnome-terminal gnome-system-monitor gnome-calculator gnome-weather gnome-calendar network-manager-gnome \
cinnamon inxi synaptic p7zip-full ffmpeg gvfs-backends wget xdg-user-dirs file-roller gnome-disk-utility papirus-icon-theme orchis-gtk-theme

#Pardus apps
# chroot chroot apt install pardus-lightdm-greeter pardus-installer pardus-software pardus-package-installer pardus-about pardus-update pardus-locales pardus-bilge-grub-theme pardus-font-manager -y

#Printer and bluetooth apps
chroot chroot apt install printer-driver-all system-config-printer simple-scan blueman -y

#Grub update
chroot chroot apt upgrade -y
chroot chroot update-grub

#### Remove bloat files after dpkg invoke (optional)
cat > chroot/etc/apt/apt.conf.d/02antibloat << EOF
DPkg::Post-Invoke {"rm -rf /usr/share/man || true";};
DPkg::Post-Invoke {"rm -rf /usr/share/help || true";};
DPkg::Post-Invoke {"rm -rf /usr/share/doc || true";};
EOF

chroot chroot apt clean
rm -f chroot/root/.bash_history
rm -rf chroot/var/lib/apt/lists/*
find chroot/var/log/ -type f | xargs rm -f

mkdir pardus || true
while umount -lf -R chroot/* 2>/dev/null ; do
 : "Umount action"
done
mksquashfs chroot filesystem.squashfs -comp xz -wildcards
find chroot/var/log/ -type f | xargs rm -f
mkdir -p pardus/live
mv filesystem.squashfs pardus/live/filesystem.squashfs

cp -pf chroot/boot/initrd.img-* pardus/live/initrd.img
cp -pf chroot/boot/vmlinuz-* pardus/live/vmlinuz

mkdir -p pardus/boot/grub/
echo 'terminal_output console' > pardus/boot/grub/grub.cfg
echo 'menuentry "Start Pardus GNU/Linux (Unofficial)" --class pardus {' >> pardus/boot/grub/grub.cfg
echo '    linux /live/vmlinuz boot=live components --' >> pardus/boot/grub/grub.cfg
echo '    initrd /live/initrd.img' >> pardus/boot/grub/grub.cfg
echo '}' >> pardus/boot/grub/grub.cfg

grub-mkrescue pardus -o pardus-cinnamon-backports.iso
