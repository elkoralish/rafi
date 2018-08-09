#!/bin/bash

[ ! "$(grep -w peatio /etc/passwd)" ] && sudo useradd -c "Peatio install user" --groups sudo --shell /bin/bash --create-home peatio 
[ ! "$(sudo grep -w peatio /etc/sudoers)" ] && sudo sh -c "echo 'peatio ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers"
[ ! "$(grep -w "^127" /etc/hosts | grep -w $hostname)" ] && sudo sh -c "sed -i '/^127/ s/$/ '$(hostname)'/' /etc/hosts"
sudo cp ./pi.sh /home/peatio
sudo -iu peatio sh -c "/home/peatio/pi.sh"
# remove peatio sudo perms here
