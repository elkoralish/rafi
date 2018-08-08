#!/bin/bash

sudo useradd -c "Peatio install user" --groups sudo --shell /bin/bash --create-home peatio 
sudo echo "peatio ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
sudo cp ./pi.sh /home/peatio
sudo -u peatio /home/pi.sh
