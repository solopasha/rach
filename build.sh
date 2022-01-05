#!/usr/bin/bash

image_name="archlinux-$(date +%d.%m.%Y)-x86_64.iso"

echo "install pkg"
echo -e '[archlinuxcn]\nServer = https://repo.archlinuxcn.org/$arch' >> /etc/pacman.conf
pacman -Syu git patch archiso mkinitcpio-archiso reflector archlinuxcn-keyring --noconfirm --needed
patch /usr/bin/mkarchiso ./0001-Add-secureboot-support-using-preloader.patch
reflector --verbose --threads 5 --protocol https --latest 50 --sort rate --save /etc/pacman.d/mirrorlist

build_iso() {
  pacman -Scc --noconfirm --quiet
  rm -rf /var/cache/pacman/pkg/*
  pacman-key --init
  pacman-key --populate
  pacman -Syy --quiet

  [[ $(grep chroot.sh /usr/bin/mkarchiso) ]] || \
  sed -i "/_mkairootfs_squashfs()/a [[ -e "$\{profile\}/chroot.sh" ]] && $\{profile\}/chroot.sh" /usr/bin/mkarchiso

  mkarchiso -v -w ./work -o /out ./
}

echo "build iso"
build_iso

if [[ -e "/out/$image_name" ]]; then
  echo "create SHA 256"
  sha256sum "/out/${image_name}" >> "/out/${image_name}.sha256"

  echo "add gh env"
  echo "BUILD_TAG=$(date +%d.%m.%Y)" >> $GITHUB_ENV
  echo "image_name=$image_name" >> $GITHUB_ENV
fi
