#!/bin/bash

#######################################################################################
## execute this script in a chroot of archiso to build an instantOS installation ISO ##
#######################################################################################

## This script is run on the live iso itself, NOT the host

set -eo pipefail
echo "building instantOS installation ISO"

# TODO: check if this is running in a chroot

touch /opt/livebuilder

echo "adding user"
useradd -m -s /bin/bash instantos
echo "instantos:instantos" | chpasswd

add_default_group() {
    if ! grep -q "$1" /etc/group; then
        groupadd "$1"
    fi

    gpasswd -a "instantos" "$1"
}

setup_lightdm() {
    echo "preparing lightdm"
    # enable greeter
    sed -i 's/^\[Seat:\*\]/\[Seat:\*\]\ngreeter-session=lightdm-gtk-greeter/g' \
        /etc/lightdm/lightdm.conf
    # enable autologin
    sed -i "s/^\[Seat:\*\]/[Seat:*]\nautologin-user=instantos/g" \
        /etc/lightdm/lightdm.conf

    # start GUI session using the shell, for some reason enabling the service
    # in livesession.sh doesn't work
    echo "sleep 2 && systemctl start lightdm" >>/root/.zshrc
    echo "[ -e /opt/lightstart ] || systemctl start lightdm & touch /opt/lightstart" >> \
        /etc/zsh/zshrc
}

setup_root() {
    # allow sudo
    sed -i 's/# %wheel/%wheel/g' /etc/sudoers
    # clear sudo password
    echo "root ALL=(ALL) NOPASSWD:ALL #instantosroot" >>/etc/sudoers
    echo "" >>/etc/sudoers
}

add_default_group "autologin"
add_default_group "video"
add_default_group "video"
add_default_group "wheel"
add_default_group "input"

cd
mkdir tmparch
cd tmparch

# TODO: are these needed?
git clone --depth 1 https://github.com/instantOS/instantARCH
git clone --depth 1 https://github.com/instantOS/instantOS
git clone --depth 1 https://github.com/instantOS/iso

echo "instantOS rootinstall"
bash instantOS/rootinstall.sh

[ -e /etc/lightdm ] || mkdir -p /etc/lightdm
cat /usr/share/instantdotfiles/rootconfig/lightdm-gtk-greeter.conf >/etc/lightdm/lightdm-gtk-greeter.conf

setup_lightdm
setup_root

echo 'GRUB_THEME="/usr/share/grub/themes/instantos/theme.txt"' >>/etc/default/grub

rm /opt/livebuilder

# systemctl enable lightdm

systemctl enable systemd-timesyncd.service

# disable lock screen password for live user
echo 'export NOILOCKPASSWORD="true"' >>/etc/environment

echo "tzupdate &" >>/root/.zshrc

# install dev tools
curl -s 'https://raw.githubusercontent.com/instantOS/instantTOOLS/main/netinstall.sh' | bash

cd
rm -rf tmparch

echo "finished building instantOS installation ISO"
