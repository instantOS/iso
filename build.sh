#!/bin/bash

# produce an installation iso for instantOS
# run this on an instantOS installation
# Depending on your setup might also work on Arch or Manjaro

echo "starting build of instantOS live iso"
set -eo pipefail

instantinstall archiso

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
[ "$ISO_BUILD" ] || ISO_BUILD="$script_dir/build"
echo "iso will be built in $ISO_BUILD"

[ -e "$ISO_BUILD" ] && echo "removing existing iso" && sudo rm -rf "$ISO_BUILD"/
mkdir -p "$ISO_BUILD"
cd "$ISO_BUILD"

sleep 1

cp -r /usr/share/archiso/configs/releng/ "$ISO_BUILD"/instantlive

mkdir .cache &>/dev/null
cd .cache

if [ -e iso/livesession.sh ]; then
    cd iso
    git pull
    cd ..
else
    git clone --depth 1 https://github.com/instantOS/iso
fi

addrepo() {
    cd "$ISO_BUILD/instantlive"

    echo "adding instantOS repo"
    {
        echo "[instant]"
        echo "SigLevel = Optional TrustAll"
        echo "Server = http://packages.instantos.io/"
    } >>pacman.conf
}

ensurerepo() {
    REPONAME="$(grep -o '[^/]*$' <<< "$1")"
    if ! [ -e "$ISO_BUILD/workspace/$REPONAME" ]
    then
        [ -e "$ISO_BUILD/workspace/" ] || mkdir -p "$ISO_BUILD/workspace/"
        git clone --depth 1 "$1" "$ISO_BUILD/workspace/$REPONAME"
    else
        cd "$ISO_BUILD/workspace/$REPONAME"
        git pull
    fi
}

cat "$ISO_BUILD"/.cache/iso/livesession.sh >>airootfs/root/customize_airootfs.sh

echo "[ -e /opt/lightstart ] || systemctl start lightdm & touch /opt/lightstart" >>airootfs/root/.zlogin

addpkg() {
    cd "$ISO_BUILD/instantlive"
    echo "$1" >>"$ISO_BUILD"/instantlive/packages.x86_64
}

addrepo

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
addpkg fastfetch
addpkg pipewire-pulse
addpkg netctl
addpkg alsa-utils
addpkg tzupdate
addpkg usbutils
addpkg lightdm-gtk-greeter
addpkg xdg-desktop-portal-gtk

addpkg libappindicator-gtk2
addpkg libappindicator-gtk3

addpkg instantos
addpkg instantdepend
addpkg liveutils
addpkg os-prober
addpkg grub-instantos

# syslinux theme
cd syslinux
sed -i 's/Arch/instantOS/g' ./*.cfg
sed -i 's/^TIMEOUT [0-9]*/TIMEOUT 100/g' ./*.cfg

# custom menu styling
cat "$ISO_BUILD/../syslinux/archiso_head.cfg" >./archiso_head.cfg
cat "$ISO_BUILD/../syslinux/archiso_pxe-linux.cfg" >./archiso_pxe-linux.cfg
cat "$ISO_BUILD/../syslinux/archiso_sys-linux.cfg" >./archiso_sys-linux.cfg

rm splash.png

# needed for assets
ensurerepo https://github.com/instantOS/instantLOGO

cp "$ISO_BUILD/workspace/instantLOGO/png/splash.png" .

cd ..

# end of syslinux styling

# add installer
ensurerepo https://github.com/instantOS/instantARCH

cat "$ISO_BUILD"/workspace/instantARCH/data/packages/system >>"$ISO_BUILD"/instantlive/packages.x86_64
cat "$ISO_BUILD"/workspace/instantARCH/data/packages/extra >>"$ISO_BUILD"/instantlive/packages.x86_64

sudo mkarchiso -v "$ISO_BUILD/instantlive"

echo "finished building instantOS installation iso"
