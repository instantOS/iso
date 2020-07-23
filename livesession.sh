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
curl -s https://raw.githubusercontent.com/instantOS/iso/master/version >/etc/instantos/liveversion

cd
mkdir tmparch
cd tmparch

git clone --depth 1 https://github.com/instantOS/instantARCH
git clone --depth 1 https://github.com/instantOS/instantOS
git clone --depth 1 https://github.com/instantOS/iso

cat iso/issue >/etc/issue

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

echo 'GRUB_THEME="/usr/share/grub/themes/instantos/theme.txt"' >>/etc/default/grub

rm /opt/livebuilder

# systemctl enable lightdm

echo "sleep 2 && systemctl start lightdm" >>/root/.zshrc
echo "[ -e /opt/lightstart ] || systemctl start lightdm & touch /opt/lightstart" >>/etc/zsh/zshrc

cd
rm -rf tmparch

echo "finished building instantOS installation ISO"
