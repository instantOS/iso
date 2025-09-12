#!/bin/bash

# produce an installation iso for instantOS
# run this on an instantOS installation
# Depending on your setup might also work on Arch or Manjaro

echo "starting build of instantOS live iso"
set -eo pipefail

instantinstall archiso

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
[ "$ISO_BUILD" ] || ISO_BUILD="$SCRIPT_DIR/build"
echo "iso will be built in $ISO_BUILD"

[ -e "$ISO_BUILD" ] && echo "removing existing iso" && sudo rm -rf "$ISO_BUILD"/
mkdir -p "$ISO_BUILD"
cd "$ISO_BUILD"

sleep 1

cp -r /usr/share/archiso/configs/releng/ "$ISO_BUILD"/instantlive
cp -r "$SCRIPT_DIR/airootfs" "$ISO_BUILD/instantlive/airootfs"

ensurerepo() {
    REPONAME="$(grep -o '[^/]*$' <<<"$1")"
    if ! [ -e "$ISO_BUILD/workspace/$REPONAME" ]; then
        [ -e "$ISO_BUILD/workspace/" ] || mkdir -p "$ISO_BUILD/workspace/"
        git clone --depth 1 "$1" "$ISO_BUILD/workspace/$REPONAME"
    else
        cd "$ISO_BUILD/workspace/$REPONAME"
        git pull
    fi
}

addrepo() {
    cd "$ISO_BUILD/instantlive"

    echo "adding instantOS repo"
    {
        echo "[instant]"
        echo "SigLevel = Optional TrustAll"
        echo "Server = http://packages.instantos.io/"
    } >>pacman.conf
}

add_liveutils_assets() {
    ensurerepo https://github.com/instantOS/liveutils
    mkdir -p "$ISO_BUILD/instantlive/airootfs"/usr/share/liveutils
    mv "$ISO_BUILD"/workspace/liveutils/wallpaper.png \
        "$ISO_BUILD/instantlive/airootfs"/usr/share/liveutils/
    cp "$ISO_BUILD"/workspace/liveutils/assets/*.jpg \
        "$ISO_BUILD/instantlive/airootfs"/usr/share/liveutils/
}

add_instantos_deps() {
    # add installer
    ensurerepo https://github.com/instantOS/instantARCH
    cat "$ISO_BUILD"/workspace/instantARCH/data/packages/system >>"$ISO_BUILD"/instantlive/packages.x86_64
    cat "$ISO_BUILD"/workspace/instantARCH/data/packages/extra >>"$ISO_BUILD"/instantlive/packages.x86_64

    # avoid duplicate packages in the list
    SORTEDPACKAGES="$(sort -u "$ISO_BUILD"/instantlive/packages.x86_64)"
    echo "$SORTEDPACKAGES" >"$ISO_BUILD"/instantlive/packages.x86_64

}

setup_syslinux_styling() {
    cd "$ISO_BUILD"/instantlive/syslinux
    # Increase timeout
    # TODO: why is this there?
    sed -i 's/^TIMEOUT [0-9]*/TIMEOUT 100/g' ./*.cfg

    # needed for assets
    ensurerepo https://github.com/instantOS/instantLOGO

    cp "$ISO_BUILD/workspace/instantLOGO/png/splash.png" "$ISO_BUILD"/instantlive/syslinux/splash.png

}

add_default_deps() {
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
    addpkg os-prober
    addpkg grub-instantos
}


addpkg() {
    cd "$ISO_BUILD/instantlive"
    echo "$1" >>"$ISO_BUILD"/instantlive/packages.x86_64
}

addrepo
add_default_deps
add_instantos_deps
setup_syslinux_styling
add_liveutils_assets

cd "$ISO_BUILD/"
mkdir "$ISO_BUILD"/iso
sudo mkarchiso -v "$ISO_BUILD/instantlive" -o "$ISO_BUILD/iso/"

echo "finished building instantOS installation iso"
