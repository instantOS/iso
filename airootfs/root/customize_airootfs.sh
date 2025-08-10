#!/bin/bash

#######################################################################################
## execute this script in a chroot of archiso to build an instantOS installation ISO ##
#######################################################################################

## This script is run on the live iso itself, NOT the host

echo "building instantOS installation ISO"

touch /opt/livebuilder

echo "adding user"
useradd -m -s /bin/bash instantos
echo "instantos:instantos" | chpasswd

rgroup() {
    if ! grep -q "$1" /etc/group; then
        groupadd "$1"
    fi

    gpasswd -a "instantos" "$1"
}

rgroup "autologin"
rgroup "video"
rgroup "video"
rgroup "wheel"
rgroup "input"

mkdir -p /etc/instantos
curl -s https://raw.githubusercontent.com/instantOS/iso/main/version >/etc/instantos/liveversion

cd || exit 1
mkdir tmparch
cd tmparch || exit 1

git clone --depth 1 https://github.com/instantOS/instantARCH
git clone --depth 1 https://github.com/instantOS/instantOS
git clone --depth 1 https://github.com/instantOS/iso

echo "instantOS rootinstall"
bash instantOS/rootinstall.sh

[ -e /etc/lightdm ] || mkdir -p /etc/lightdm
cat /usr/share/instantdotfiles/rootconfig/lightdm-gtk-greeter.conf >/etc/lightdm/lightdm-gtk-greeter.conf

echo "preparing lightdm"
# enable greeter
sed -i 's/^\[Seat:\*\]/\[Seat:\*\]\ngreeter-session=lightdm-gtk-greeter/g' /etc/lightdm/lightdm.conf
# enable autologin
sed -i "s/^\[Seat:\*\]/[Seat:*]\nautologin-user=instantos/g" /etc/lightdm/lightdm.conf
# allow sudo
sed -i 's/# %wheel/%wheel/g' /etc/sudoers
# clear sudo password
echo "root ALL=(ALL) NOPASSWD:ALL #instantosroot" >>/etc/sudoers
echo "" >>/etc/sudoers

echo 'GRUB_THEME="/usr/share/grub/themes/instantos/theme.txt"' >>/etc/default/grub

rm /opt/livebuilder

# systemctl enable lightdm

systemctl enable systemd-timesyncd.service

# disable lock screen password for live user
echo 'export NOILOCKPASSWORD="true"' >> /etc/environment

echo "tzupdate &" >>/root/.zshrc

# start GUI session, for some reason enabling the service in livesession.sh doesn't work
echo "sleep 2 && systemctl start lightdm" >>/root/.zshrc
echo "[ -e /opt/lightstart ] || systemctl start lightdm & touch /opt/lightstart" >>/etc/zsh/zshrc

# install dev tools
curl -s 'https://raw.githubusercontent.com/instantOS/instantTOOLS/main/netinstall.sh' | bash

cd || exit 1
rm -rf tmparch

echo "finished building instantOS installation ISO"
