#!/bin/bash
# vim: syntax=sh:tabstop=4:expandtab


# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
install_ruby () {
    sudo apt-get install -y git curl zlib1g-dev build-essential \
      libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 \
      libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev ruby

    gpg --keyserver hkp://keys.gnupg.net:80 \
        --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 \
                    7D2BAF1CF37B13E2069D6956105BD0E739499BDB

    curl -sSL https://get.rvm.io | bash -s stable --ruby=2.5.1 --gems=rails

    echo "gem: --no-ri --no-rdoc" > ~/.gemrc

# ok, not sure here if we need to source .bash_profile (rvm function) or .bashrc (PATH)
# also "To start using RVM you need to run `source /home/peatio/.rvm/scripts/rvm"
# not sure if it's needed for install, and if it will screw things up at runtime
}

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
build_my_cnf () {
cat << EOF > $1
[client]
user=$2
password="$mysqlroot"
EOF
}

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
install_mysql () {
    #echo -e "\n - Installing MySql" | tee -a $logfile
    sudo apt-get -y install mysql-server mysql-client libmysqlclient-dev ##>> $logfile 2>&1
    sudo service mysql start
    echo -n " ? Enter MySql root password: "
    read mysqlroot
    mysqladmin -u root password $mysqlroot #>> $logfile 2>&1

    sudo touch /.my.cnf
    sudo chmod 777 /.my.cnf
    build_my_cnf "/.my.cnf" root
    sudo chmod 400 /.my.cnf

    # this command will need to be adjusted if peatio is on another machine
    #if [ "$multi" ]
    #then
    #    echo -n " ? Enter name or IP address of application server: "
    #    read apphost
    #else
        apphost="localhost"
    #fi
    createuser="GRANT ALL PRIVILEGES ON *.* TO \"peatio\"@\"$apphost\" IDENTIFIED BY \"$mysqlroot\";"
    sudo mysql --defaults-file=/.my.cnf -e "$createuser"
    touch ~/.my.cnf
    build_my_cnf ~/.my.cnf peatio
    chmod 400 ~/.my.cnf

    echo " - MySql root password set as $mysqlroot" | tee -a $logfile

    #echo -e "\n# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" #>> $HOME/.bashrc
    echo "# MySql variables" #>> $HOME/.bashrc
    echo "export DATABASE_HOST=$apphost" #>> $HOME/.bashrc
    echo "export DATABASE_USER=root" #>> $HOME/.bashrc
    #echo "export DATABASE_PASS=$mysqlroot" >> $HOME/.bashrc
    #source $HOME/.bashrc
}

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
install_redis () {
    sudo add-apt-repository -y ppa:chris-lea/redis-server
    sudo apt-get update
    sudo apt-get -y install redis-server
}

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
install_rabbitmq () {
    wget -O - 'https://dl.bintray.com/rabbitmq/Keys/rabbitmq-release-signing-key.asc' | sudo apt-key add -
    echo "deb https://dl.bintray.com/rabbitmq/debian bionic main erlang" | sudo tee /etc/apt/sources.list.d/bintray.rabbitmq.list
    sudo apt-get update
    sudo apt-get -y install rabbitmq-server python
    sudo rabbitmq-plugins enable rabbitmq_management
    sudo service rabbitmq-server restart
    wget http://127.0.0.1:15672/cli/rabbitmqadmin
    chmod +x rabbitmqadmin
    sudo mv rabbitmqadmin /usr/local/sbin
}

bitcoind_service () {
cat << EOF > bitcoind.service
[Unit]
Description=Bitcoin's distributed currency daemon
After=network.target

[Service]
User=$1
Group=$1

Type=forking
PIDFile=$2/.bitcoin/bitcoind.pid
ExecStart=/usr/bin/bitcoind -daemon -pid=$2/.bitcoin/bitcoind.pid \
-conf=$2/.bitcoin/bitcoin.conf -datadir=$2/.bitcoin/ -disablewallet

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=2s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF
}

bitcoin_conf () {
cat << EOF > bitcoin.conf
server=1
daemon=1

# If run on the test network instead of the real bitcoin network
testnet=1

# You must set rpcuser and rpcpassword to secure the JSON-RPC api
# Please make rpcpassword to something secure, `5gKAgrJv8CQr2CGUhjVbBFLSj29HnE6YGXvfykHJzS3k` for example.
# Listen for JSON-RPC connections on <port> (default: 8332 or testnet: 18332)
rpcuser=USERNAME
rpcpassword=PASSWORD
rpcport=18332

# Notify when receiving coins
walletnotify=/usr/local/sbin/rabbitmqadmin publish routing_key=peatio.deposit.coin payload='{"txid":"%s", "currency":"btc"}'
EOF
}

install_bitcoind () {
    sudo add-apt-repository universe
    echo -e "\n" | sudo add-apt-repository ppa:bitcoin/bitcoin
    sudo apt-get update
    sudo apt-get -y install bitcoind
    # make config file
    sudo mkdir $bitcoind_home/.bitcoin
    bitcoin_conf
    sudo mv bitcoin.conf $bitcoind_home/.bitcoin
    sudo chown -R $bitcoind_user:$bitcoind_user $bitcoind_home/.bitcoin
    # configure service
    bitcoind_service $bitcoind_user $bitcoind_home
    sudo mv bitcoind.service /lib/systemd/system
    sudo chown root:root /lib/systemd/system/bitcoind.service
    sudo systemctl daemon-reload
    sudo systemctl enable bitcoind.service
    sudo systemctl daemon-reload
    #sudo systemctl start bitcoind
}

install_phantomjs () {
    sudo apt-get update
    sudo apt-get -y install build-essential chrpath git-core libssl-dev libfontconfig1-dev
    cd /usr/local/share
    sudo wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-$phantomjs_version-linux-x86_64.tar.bz2
    sudo tar xjf phantomjs-$phantomjs_version-linux-x86_64.tar.bz2
    sudo ln -s /usr/local/share/phantomjs-$phantomjs_version-linux-x86_64/bin/phantomjs /usr/local/share/phantomjs
    sudo ln -s /usr/local/share/phantomjs-$phantomjs_version-linux-x86_64/bin/phantomjs /usr/local/bin/phantomjs
    sudo ln -s /usr/local/share/phantomjs-$phantomjs_version-linux-x86_64/bin/phantomjs /usr/bin/phantomjs
}

install_js_runtime () {
    curl -sL https://deb.nodesource.com/setup_8.x | sudo bash -
    sudo apt-get -y install nodejs
}

install_imagemagick () {
    sudo apt-get -y install imagemagick
}

peatio_service () {
cat << EOF > peatio-daemons.service
[Unit]
Description=Peatio deamons
After=network.target

[Service]
User=$1
Group=$1

WorkingDirectory=$2/code/peatio
Type=forking
PIDFile=$2/.peatio/peatio-daemons.pid
ExecStart=/home/peatio/.rvm/gems/ruby-2.5.0/bin/god -c lib/daemons/daemons.god
ExecStop=/home/peatio/.rvm/gems/ruby-2.5.0/bin/god quit

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=2s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF
}

install_oauth2 () {
cat << EOF
Setup Google Authentication
---------------------------
By default, peatio will ask for Google Authentication. 
This parameter can be changed in /config/application.yml -> OAUTH2_SIGN_IN_PROVIDER: google

Setup a new Web application on https://console.developers.google.com

Configure the Google Id, Secret and callback in /config/application.yml
Note: Make sure your host ISN'T an IP in the callback config. Looks like Google auth expect a callback to a DNS only
  GOOGLE_CLIENT_ID: <Google id>
  GOOGLE_CLIENT_SECRET: <Google secret>
  GOOGLE_OAUTH2_REDIRECT_URL: http://ec2-xx-xx-xx-xx.compute-1.amazonaws.com:3000/auth/google_oauth2/callback
EOF
}

install_peatio () {
    cd 
    sudo apt-get -y install npm
    echo "export NPM_CONFIG_PREFIX=~/.npm-global" >> ~/.profile
    # these may have to go in .profile, I'd rather leave pass out
    export DATABASE_HOST=localhost
    export DATABASE_USER=peatio
    export DATABASE_PASS="$mysqlroot"
    mkdir ~/.npm-global
    mv ~/.bash_profile ~/.bash_profile.disabled
    source ~/.profile
    
    mkdir /home/peatio/code
    cd /home/peatio/code
    git clone https://github.com/rubykube/peatio.git
    cd peatio
    bundle install
    bin/init_config
    npm install -g yarn
    bundle exec rake tmp:create yarn:install

    # message about setup pusher
    # message abot bitcoin rpc endpoint
    
    bundle exec rake db:create
    bundle exec rake db:migrate
    bundle exec rake seed:blockchains   # Adds missing blockchains to database defined at config/seed/blockchains.yml
    bundle exec rake seed:currencies    # Adds missing currencies to database defined at config/seed/currencies.yml
    bundle exec rake seed:markets       # Adds missing markets to database defined at config/seed/markets.yml
    bundle exec rake seed:wallets
    
    sudo mkdir /var/log/peatio
    sudo chown peatio /var/log/peatio
    mkdir log
    ln -s /var/log/peatio log/daemons
    god -c lib/daemons/daemons.god

    # put hostname in config file so we can start
    sed -i '/URL_HOST:/s/peatio.tech/'$(hostname)'/g' config/application.yml

    bundle exec rails server -p 3000 &
    # if you have peatio-workbench on a server start up with the following
    # bundle exec rails server -b 0.0.0.0

    # show message about editing config

}

install_peatio_trading_ui () {
cd ~/code
git clone https://github.com/rubykube/peatio-trading-ui.git
cd peatio-trading-ui
bundle install
bin/init_config
#sed -i '/URL_HOST:/s/peatio.tech/'$(hostname)'/g' config/application.yml
}

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
sep="\n =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"
bitcoind_user=bitcoin
bitcoind_home=/var/lib/bitcoin
phantomjs_version=1.9.8

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
echo -e "$sep"
install_ruby
echo -e "$sep"
install_mysql
echo -e "$sep"
install_redis
echo -e "$sep"
install_rabbitmq
echo -e "$sep"
install_bitcoind
echo -e "$sep"
install_phantomjs
echo -e "$sep"
install_imagemagick
echo -e "$sep"
install_peatio
echo -e "$sep"
install_peatio_trading_ui
echo -e "$sep"






echo -e "\n !! Remember to edit the config file $bitcoind_home/.bitcoin/bitcoin.conf !!\n"
# vim: syntax=sh:tabstop=4:expandtab
