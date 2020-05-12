#!/bin/bash

#######################################################################################
## execute this script in a chroot of archiso to build an instantOS installation ISO ##
#######################################################################################

echo "building instantOS installation ISO"

touch /opt/livebuilder

echo "adding user"

useradd -m -s /bin/bash instantos
echo "instantos:instantos" | chpasswd

rgroup() {
    groupadd "$1" &>/dev/null
    sudo gpasswd -a "instantos" "$1"
}

rgroup "autologin"
rgroup "video"
rgroup "video"
rgroup "wheel"
rgroup "input"

cd
mkdir tmparch
cd tmparch

git clone --depth 1 https://github.com/instantOS/instantARCH
git clone --depth 1 https://github.com/instantOS/instantOS

echo "instantOS rootinstall"
bash instantOS/rootinstall.sh

[ -e /etc/lightdm ] || mkdir -p /etc/lightdm
cat /usr/share/instantdotfiles/lightdm-gtk-greeter.conf >/etc/lightdm/lightdm-gtk-greeter.conf

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

rm /opt/livebuilder

systemctl enable lightdm

cd
rm -rf tmparch

echo "finished building instantOS installation ISO"
