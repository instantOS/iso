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

# default is 64 bit repo
if ! uname -m | grep -q '^i'; then
    echo "adding 64 bit repo"
    echo "[instant]" >>pacman.conf
    echo "SigLevel = Optional TrustAll" >>pacman.conf
    echo "Server = http://instantos.surge.sh" >>pacman.conf

else
    echo "[instant]" >>pacman.conf
    echo "SigLevel = Optional TrustAll" >>pacman.conf
    echo "Server = http://instantos32.surge.sh" >>pacman.conf
    sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist32

fi

cat ~/.cache/iso/livesession.sh >>airootfs/root/customize_airootfs.sh

echo "[ -e /opt/lightstart ] || systemctl start lightdm & touch /opt/lightstart" >>airootfs/root/.zlogin

addpkg() {
    echo "$1" >>~/instantlive/packages.x86_64
}

cd
cd instantlive

addpkg xorg
addpkg xorg-drivers
addpkg fzf
addpkg expect
addpkg git
addpkg dialog
addpkg wget

addpkg sudo
addpkg lshw
addpkg lightdm
addpkg bash
addpkg mkinitcpio
addpkg base
addpkg linux
addpkg vim
addpkg xarchiver
addpkg xterm
addpkg systemd-swap
addpkg neofetch
addpkg pulseaudio
addpkg netctl
addpkg alsa-utils
addpkg usbutils
addpkg lightdm-gtk-greeter
addpkg xdg-desktop-portal-gtk

addpkg libappindicator-gtk2
addpkg libappindicator-gtk3

addpkg snap-dummy

addpkg instantos
addpkg instantdepend
addpkg liveutils

if ! [ -e ~/workspace/instantARCH ]; then
    mkdir ~/workspace/
    git clone --depth 1 https://github.com/instantOS/instantARCH ~/workspace/instantARCH
fi

sed -n '/begin/,/end/p' ~/workspace/instantARCH/depend/system.sh |
    grep '^[^a-z#]' | grep -v 'install end' | grep -o '[^ \\]*' >> \
    ~/instantlive/packages.x86_64

sudo ./build.sh -v
