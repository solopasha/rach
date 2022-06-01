#!/usr/bin/env bash
set -e -u

script_path=$(readlink -f "${0%/*}")
work_dir=${script_path}/work/x86_64/airootfs

echo "==== create settings.sh ===="
sed '1,/^#chroot$/d' "${script_path}/chroot.sh" > "${work_dir}/settings.sh"

chrooter() {
  arch-chroot "${work_dir}" /bin/bash -c "${1}"
}

chmod +x "${work_dir}/settings.sh"
chrooter /settings.sh
rm "${work_dir}/settings.sh"
exit 0

#chroot
isouser="liveuser"
OSNAME="archlinux"

_conf() {
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
  hwclock --systohc --utc
  sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
  locale-gen
  echo "LANG=en_US.UTF-8" > /etc/locale.conf
  echo "LC_COLLATE=C" >> /etc/locale.conf
  echo "FONT=cyr-sun16" >> /etc/vconsole.conf
  echo "$OSNAME" > /etc/hostname
  export _BROWSER=firefox
  echo "BROWSER=/usr/bin/${_BROWSER}" >> /etc/environment
  export _EDITOR=nvim
  echo "EDITOR=${_EDITOR}" >> /etc/environment
  echo "QT_QPA_PLATFORMTHEME=gnome" >> /etc/environment
  sed -i '/MAKEFLAGS=/s/^#//g' /etc/makepkg.conf
  sed -i '/MAKEFLAGS/s/-j2/-j$(($(nproc)+1))/g' /etc/makepkg.conf
}

_perm() {
  mkdir -p /media
  chmod 755 -R /media
  chmod +x /usr/local/bin/*
  # chmod +x /etc/skel/.bin/*
  # chmod +x /home/$isouser/.bin/*
  # find /etc/skel/ -type f -iname "*.sh" -exec chmod +x {} \;
  # find /home/$isouser/ -type f -iname "*.sh" -exec chmod +x {} \;
}

_liveuser() {
  glist="audio,disk,log,network,scanner,storage,power,wheel"
  if ! id $isouser 2>/dev/null; then
    useradd -m -p "" -c "Liveuser" -G $glist -s /usr/bin/zsh $isouser
  fi
}

_nm() {
  echo "" > /etc/NetworkManager/NetworkManager.conf
  echo "[device]" >> /etc/NetworkManager/NetworkManager.conf
  echo "wifi.scan-rand-mac-address=no" >> /etc/NetworkManager/NetworkManager.conf
  echo "" >> /etc/NetworkManager/NetworkManager.conf
  echo "[main]" >> /etc/NetworkManager/NetworkManager.conf
  echo "dhcp=dhclient" >> /etc/NetworkManager/NetworkManager.conf
  echo "dns=systemd-resolved" >> /etc/NetworkManager/NetworkManager.conf
}

_key() {
  reflector -a 12 -l 30 --threads 3 -p https --sort rate --save /etc/pacman.d/mirrorlist
  pacman-key --init
  pacman-key --populate
  pacman -Syy --noconfirm
}

_yay(){
  sudo -iu liveuser git clone https://aur.archlinux.org/yay-bin.git
  sudo -iu liveuser -- sh -c 'cd yay-bin && makepkg -sric --noconfirm'
}
_serv() {
  systemctl mask systemd-rfkill@.service
  systemctl mask systemd-rfkill.socket
  systemctl enable pacman-init.service
  systemctl enable choose-mirror.service
  systemctl enable systemd-resolved.service
  systemctl enable systemd-timesyncd.service
  systemctl enable ModemManager.service
  systemctl -f enable NetworkManager.service
  systemctl enable reflector.service
  systemctl enable sshd.service
  systemctl enable gdm.service
  systemctl enable hv_fcopy_daemon.service hv_kvp_daemon.service hv_vss_daemon.service vmtoolsd.service vmware-vmblock-fuse.service
  systemctl set-default graphical.target
}

_conf
_perm
_liveuser
_nm
_key
#_yay
_serv

echo "==== Done settings.sh ===="
