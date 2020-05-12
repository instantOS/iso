#!/bin/bash

echo "starting build of instantOS live iso"

cd
[ -e instantlive ] && echo "removing existing iso" && sudo rm -rf instantlive
sleep 1

cp -r /usr/share/archiso/configs/releng/ instantlive

mkdir .cache &>/dev/null
cd .cache
if [ -e iso/livesession.sh ]; then
    cd iso
    git pull
    cd ..
else
    git clone --depth 1 https://github.com/instantOS/iso
fi

cd

cd instantlive
echo "[instant]" >>pacman.conf
echo "SigLevel = Optional TrustAll" >>pacman.conf
echo "Server = http://instantos.surge.sh" >>pacman.conf

cat ~/.cache/iso/livesession.sh >>airootfs/root/customize_airootfs.sh

addpkg() {
    echo "$1" >>packages.x86_64
}

addpkg xorg
addpkg fzf
addpkg expect
addpkg git
addpkg dialog
addpkg wget

addpkg sudo
addpkg lightdm
addpkg bash
addpkg vim
addpkg xterm
addpkg systemd-swap
addpkg neofetch
addpkg pulseaudio
addpkg alsa-utils
addpkg usbutils
addpkg lightdm-gtk-greeter
addpkg xdg-desktop-portal-gtk

addpkg libappindicator-gtk2
addpkg libappindicator-gtk3

addpkg instantos
addpkg instantdepend
addpkg liveutils

sudo ./build.sh