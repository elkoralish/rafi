#!/bin/bash

sudo useradd -c "Peatio install user" --groups sudo --shell /bin/bash --create-home peatio 
sudo sh -c "echo 'peatio ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers"
sudo sh -c "sed -i '/^127/ s/$/ '$(hostname)'/' /etc/hosts"
sudo cp ./pi.sh /home/peatio
sudo -u peatio sh -c "/home/peatio/pi.sh"
