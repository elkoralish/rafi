#!/bin/bash

echo $(whoami)
echo -e "\n =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"

sudo apt-get install -y git curl zlib1g-dev build-essential \
  libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 \
  libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev ruby

gpg --keyserver hkp://keys.gnupg.net:80 \
    --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 \
                7D2BAF1CF37B13E2069D6956105BD0E739499BDB

curl -sSL https://get.rvm.io | bash -s stable --ruby=2.5.0 --gems=rails

echo "gem: --no-ri --no-rdoc" > ~/.gemrc

echo -e "\n =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"
