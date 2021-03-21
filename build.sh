#!/bin/bash

# produce an installation iso for instantOS
# run this on an instantOS installation
# Depending on your setup might also work on Arch or Manjaro

echo "starting build of instantOS live iso"

cd || exit 1
[ -e instantlive ] && echo "removing existing iso" && sudo rm -rf instantlive
sleep 1

cp -r /usr/share/archiso/configs/releng/ instantlive

mkdir .cache &>/dev/null
cd .cache || exit 1
if [ -e iso/livesession.sh ]; then
    cd iso || exit 1
    git pull
    cd .. || exit 1
else
    git clone --depth 1 https://github.com/instantOS/iso
fi

cd || exit 1
cd instantlive || exit 1

# default is 64 bit repo
if ! uname -m | grep -q '^i'; then
    echo "adding 64 bit repo"
    {
        echo "[instant]"
        echo "SigLevel = Optional TrustAll"
        echo "Server = http://packages.instantos.io/"
    } >>pacman.conf
else
    {
        echo "[instant]"
        echo "SigLevel = Optional TrustAll"
        echo "Server = http://instantos32.surge.sh"
    } >>pacman.conf
    sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist32
fi

cat ~/.cache/iso/livesession.sh >>airootfs/root/customize_airootfs.sh

echo "[ -e /opt/lightstart ] || systemctl start lightdm & touch /opt/lightstart" >>airootfs/root/.zlogin

addpkg() {
    echo "$1" >>~/instantlive/packages.x86_64
}

cd || exit 1
cd instantlive || exit 1

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
addpkg gparted
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

addpkg instantos
addpkg instantdepend
addpkg liveutils

# syslinux theme
cd syslinux || exit 1
sed -i 's/Arch/instantOS/g' ./*.cfg
sed -i 's/^TIMEOUT [0-9]*/TIMEOUT 0/g' ./*.cfg

rm splash.png
if ! [ -e ~/workspace/instantLOGO ]; then
    mkdir ~/workspace
    git clone --depth 1 https://github.com/instantOS/instantLOGO ~/workspace/instantLOGO
fi

cp ~/workspace/instantLOGO/png/splash.png .
cd .. || exit 1

if ! [ -e ~/workspace/instantARCH ]; then
    mkdir ~/workspace/
    git clone --depth 1 https://github.com/instantOS/instantARCH ~/workspace/instantARCH
fi

sed -n '/begin/,/end/p' ~/workspace/instantARCH/depend/system.sh |
    grep '^[^a-z#]' | grep -v 'install end' | grep -o '[^ \\]*' >> \
    ~/instantlive/packages.x86_64

sudo mkarchiso -v "$(realpath .)"

echo "finished building instantOS installation iso"
