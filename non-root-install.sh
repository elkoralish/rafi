#!/bin/bash
# vim: tabstop=4:expandtab:syntax=sh
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#
# Script:   Peatio install (Non root user and multi machine capable)
#
# Author:   Chris Regenye
# Date:     6/29/2018
# Info:     This script will install peatio and all it's dependencies based
#           on ruby 2.5. you should create a user to run this as by using the
#           command below as an example:
#    
#           useradd -c "Peatio install user" --groups sudo --shell /bin/bash --create-home peatio
#
#           when done, the visudo command should be run and the following line
#           added to the bottom of the file:
#
#           peatio    ALL=(ALL:ALL) NOPASSWD: ALL
#
#           when the script completes, that line should probably be removed
#           (also using the visudo command ) as I believe escalated 
#           privileges are only required for installation.
#
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
logfile="/var/log/peatio-install"
sep="# -----------------------------------------------------------------------------"

# -----------------------------------------------------------------------------
# Setup ruby environment
rubyenv() {
	user=$(whoami)
	echo -e "\n$sep\n# Setup ruby environment (User: $user)" >> $logfile
	git clone git://github.com/sstephenson/rbenv.git .rbenv >> $logfile 2>&1
	source /home/peatio/.rvm/scripts/rvm
	echo 'export PATH="/home/$user/.rbenv/plugins/ruby-build/bin:/home/$user/.rbenv/bin:$PATH"' >> /home/$user/.bashrc
	rbenv init -  >> /home/$user/.bashrc
	git clone git://github.com/sstephenson/ruby-build.git /home/$user/.rbenv/plugins/ruby-build >> $logfile 2>&1
	echo 'gem: --no-ri --no-rdoc' >> /home/$user/.gemrc
	gem install bundler
	source ~/.bashrc
	rbenv rehash
}

# -----------------------------------------------------------------------------
# Install recent ruby version
install_ruby () {
    echo -e "\n$sep\n# Install recent ruby version" >> $logfile
    echo -e "\n - Installing dependencies" | tee -a $logfile
    sudo apt-get -y install tcl git curl zlib1g-dev build-essential \
      libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 \
      libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev chrpath \
      libfontconfig1-dev net-tools gnupg2 >> $logfile 2>&1

    echo -e " - Compiling and installing ruby (this may take some time)" | tee -a $logfile
    gpg --keyserver hkp://keys.gnupg.net \
        --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 \
                    7D2BAF1CF37B13E2069D6956105BD0E739499BDB >> $logfile 2>&1
    gpg2 --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 >> $logfile 2>&1
    command curl -sSL https://rvm.io/mpapis.asc | gpg --import - >> $logfile 2>&1

    curl -sSL https://get.rvm.io | bash -s stable --ruby=2.5.0 --gems=rails >> $logfile 2>&1
    sudo apt-get -y install ruby-dev ruby-bundler >> $logfile 2>&1
    #rubyenv
}

install_mysql () {
    # -----------------------------------------------------------------------------
    # Install MySql
    echo -e "\n - Installing MySql" | tee -a $logfile
    sudo apt-get -y install mysql-server mysql-client libmysqlclient-dev >> $logfile 2>&1
    sudo service mysql start
    echo -n " ? Enter MySql root password: "
    read mysqlroot
    mysqladmin -u root password $mysqlroot >> $logfile 2>&1

    sudo touch /.my.cnf
    sudo chmod 777 /.my.cnf
    cat << EOF > /.my.cnf
[client]
user=root
password="$mysqlroot"
EOF
    sudo chmod 400 /.my.cnf

    # this command will need to be adjusted if peatio is on another machine
    if [ "$multi" ]
    then
        echo -n " ? Enter name or IP address of application server: "
        read apphost
    else
        apphost="localhost"
    fi
    createuser="GRANT ALL PRIVILEGES ON *.* TO \"peatio\"@\"$apphost\" IDENTIFIED BY \"$mysqlroot\";"
    sudo mysql --defaults-file=/.my.cnf -e "$createuser"
    cat << EOF > ~/.my.cnf
[client]
user=peatio
password="$mysqlroot"
EOF
    chmod 400 ~/.my.cnf

    echo " - MySql root password set as $mysqlroot" | tee -a $logfile
    
    echo -e "\n# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $HOME/.bashrc
    echo "# MySql variables" >> $HOME/.bashrc
    echo "export DATABASE_HOST=$apphost" >> $HOME/.bashrc
    echo "export DATABASE_USER=root" >> $HOME/.bashrc
    #echo "export DATABASE_PASS=$mysqlroot" >> $HOME/.bashrc
    source $HOME/.bashrc
}

install_redis () {
    # -----------------------------------------------------------------------------
    # Install most recent stable Redis (4.0.9 at the time of this writing)
    echo -e "\n - Installing Redis" | tee -a $logfile
    curl -sSLo $HOME/redis-stable.tar.gz  http://download.redis.io/redis-stable.tar.gz >> $logfile 2>&1
    tar xzf redis-stable.tar.gz >> $logfile 2>&1
    cd redis-stable && make >> $logfile 2>&1
    sudo make install >> $logfile 2>&1
    nohup redis-server &
    cd
}

install_rabbitmq () {
    # -----------------------------------------------------------------------------
    # Install erlang and RabbitMQ
    sudo echo -e "\n - Installing erlang and RabbitMQ" | tee -a $logfile
    sudo chmod 777 /etc/apt/sources.list
    sudo echo "# -----------------------------------------------------------------------------" >> /etc/apt/sources.list
    sudo echo "# Erlang" >> /etc/apt/sources.list
    sudo echo "deb https://packages.erlang-solutions.com/ubuntu bionic contrib" >> /etc/apt/sources.list
    sudo chmod 644 /etc/apt/sources.list
    wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc >> $logfile 2>&1
    sudo apt-key add erlang_solutions.asc >> $logfile 2>&1
    sudo apt-get update >> $logfile 2>&1
    sudo apt-get -y install esl-erlang >> $logfile 2>&1
    sudo apt-get -y install init-system-helpers socat adduser logrotate >> $logfile 2>&1
    
    sudo chmod 777 /etc/apt/sources.list.d
    sudo echo "deb https://dl.bintray.com/rabbitmq/debian bionic main" >> /etc/apt/sources.list.d/bintray.rabbitmq.list
    sudo chmod 755 /etc/apt/sources.list.d
    sudo chmod 600 /etc/apt/sources.list.d/bintray.rabbitmq.list
    wget https://dl.bintray.com/rabbitmq/Keys/rabbitmq-release-signing-key.asc >> $logfile 2>&1
    sudo apt-key add rabbitmq-release-signing-key.asc  >> $logfile 2>&1
    sudo apt-get update >> $logfile 2>&1
    sudo apt-get -y install rabbitmq-server  >> $logfile 2>&1
    sudo rabbitmq-plugins enable rabbitmq_management  >> $logfile 2>&1
    sudo chown rabbitmq /etc/rabbitmq/enabled_plugins  >> $logfile 2>&1
    sudo systemctl start rabbitmq-server.service  >> $logfile 2>&1
    sudo systemctl restart rabbitmq-server.service >> $logfile 2>&1
    wget http://localhost:15672/cli/rabbitmqadmin >> $logfile 2>&1
    chmod +x rabbitmqadmin  >> $logfile 2>&1
    [ ! -d /usr/local/sbin ] && sudo mkdir -p /usr/local/sbin
    sudo mv rabbitmqadmin /usr/local/sbin  >> $logfile 2>&1
    
    #wget http://packages.erlang-solutions.com/site/esl/esl-erlang/FLAVOUR_1_general/esl-erlang_20.3-1~ubuntu~bionic_amd64.deb
    #sudo dpkg -i esl-erlang_20.3-1~ubuntu~bionic_amd64.deb
}

install_bitcoind () {
    # -----------------------------------------------------------------------------
    # Install bitcoind
    echo -e "\n - Installing bitcoind" | tee -a $logfile
    sudo add-apt-repository ppa:bitcoin/bitcoin  | tee -a $logfile 
    sudo apt-get update >> $logfile 2>&1
    sudo apt-get -y install bitcoind  >> $logfile 2>&1
    
    mkdir -p $HOME/.bitcoin  >> $logfile 2>&1
    touch $HOME/.bitcoin/bitcoin.conf  >> $logfile 2>&1
    
    cat << EOF > $HOME/.bitcoin/bitcoin.conf
server=1
daemon=1

# If run on the test network instead of the real bitcoin network
testnet=1

# You must set rpcuser and rpcpassword to secure the JSON-RPC api
# Please make rpcpassword to something secure, '5gKAgrJv8CQr2CGUhjVbBFLSj29HnE6YGXvfykHJzS3k' for example.
# Listen for JSON-RPC connections on <port> (default: 8332 or testnet: 18332)
rpcuser=USERNAME
rpcpassword=PASSWORD
rpcport=18332

# Notify when receiving coins
walletnotify=/usr/local/sbin/rabbitmqadmin publish routing_key=peatio.deposit.coin payload='{"txid":"%s", "currency":"btc"}'
EOF
    
    nohup bitcoind & >> $logfile 2>&1
    echo -e " ! bitcoind needs configuration in $HOME/.bitcoin/bitcoin.conf\n ! remember to edit this and set rpcuser and rpcpassword" | tee -a $logfile
}

install_phantomjs () {
    # -----------------------------------------------------------------------------
    # Install PhantomJS
    echo -e "\n - Installing PhantomJS" | tee -a $logfile
    [ ! -d /usr/local/share ] && sudo mkdir -p /usr/local/share
    cd /usr/local/share
    PHANTOMJS_VERISON=1.9.8
    sudo wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-$PHANTOMJS_VERISON-linux-x86_64.tar.bz2 >> $logfile 2>&1
    sudo tar xjf phantomjs-$PHANTOMJS_VERISON-linux-x86_64.tar.bz2  >> $logfile 2>&1
    
    sudo ln -s /usr/local/share/phantomjs-$PHANTOMJS_VERISON-linux-x86_64/bin/phantomjs /usr/local/share/phantomjs  >> $logfile 2>&1
    sudo ln -s /usr/local/share/phantomjs-$PHANTOMJS_VERISON-linux-x86_64/bin/phantomjs /usr/local/bin/phantomjs  >> $logfile 2>&1
    sudo ln -s /usr/local/share/phantomjs-$PHANTOMJS_VERISON-linux-x86_64/bin/phantomjs /usr/bin/phantomjs  >> $logfile 2>&1
    cd
}

install_jsruntime () {
    # -----------------------------------------------------------------------------
    # Install JavaScript Runtime
    echo -e "\n - Installing JavaScript Runtime" | tee -a $logfile
    curl -sL https://deb.nodesource.com/setup_8.x | sudo bash - >> $logfile 2>&1
    sudo apt-get -y install nodejs >> $logfile 2>&1
    #sudo curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    #sudo  echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    #sudo apt-get update && sudo apt-get install yarn
}

install_imagemagic () {
    # -----------------------------------------------------------------------------
    # Install ImageMagick
    echo -e "\n - Installing ImageMagick" | tee -a $logfile
    sudo apt-get -y install imagemagick  >> $logfile 2>&1
}

install_peatio () {
    # -----------------------------------------------------------------------------
    # Install Peatio
    echo -e "\n - Installing Peatio" | tee -a $logfile
    PATH=/usr/bin:/bin:/snap/bin:/home/peatio/peatio/bin:/usr/local/bin
    export PATH

    # this should be done by a non-root user, skip for now but revisit
    #useradd -c "Peatio install user" --groups sudo --shell /bin/bash --create-home peatio
    #sed -i 's/^%sudo/%sudo    ALL=(ALL:ALL) NOPASSWD: ALL #/g' /etc/sudoers
    #sudo -iu peatio git clone https://github.com/rubykube/peatio.git
    # make sure the same version for peatio-trading-ui is installed
    #sudo -iu peatio "rbenv init - >> .bashrc "
    #sudo -iu peatio "cd peatio && git checkout 1-8-stable  && bundle install"

    git clone https://github.com/rubykube/peatio.git  >> $logfile 2>&1
    cd peatio  >> $logfile 2>&1
    # make sure the same version for peatio-trading-ui is installed
    git checkout 1-7-stable    >> $logfile 2>&1
    bundle install  >> $logfile 2>&1
    bin/init_config  >> $logfile 2>&1
    sudo npm install -g yarn  >> $logfile 2>&1
    bundle install  >> $logfile 2>&1
    echo -e "\n\n running : bundle exec rake tmp:create yarn:install assets:precompile\n\n"
    bundle exec rake tmp:create yarn:install assets:precompile  >> $logfile 2>&1

    # pusher
    cat << EOF | tee -a $logfile
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    Setup Pusher

    Peatio depends on pusher. A development key/secret pair for development/test 
    is provided in config/application.yml.
    PLEASE USE IT IN DEVELOPMENT/TEST ENVIRONMENT ONLY!
    Set pusher-related settings in $(pwd)/config/application.yml.
    You can always find more details about pusher configuration at the
    pusher website http://pusher.com

    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    Setup bitcoind rpc endpoint

    Edit $(pwd)/config/seed/currencies.yml.
    Replace username:password and port. username and password should only
    contain letters and numbers, do not use email as username.

EOF

    #bundle install >> $logfile 2>&1
    if [ "$multi" ]
    then
        echo -n " ? Enter name or IP address of database server: "
        read apphost
    else
        apphost="localhost"
    fi
    export DATABASE_HOST=$apphost
    export DATABASE_USER=peatio
    export DATABASE_PASS=$mysqlroot
    echo -e "\n\n  Running: bundle exec rake db:setup\n\n"
    bundle exec rake db:setup  >> $logfile 2>&1
    echo -e "\n\n  Running: god -c lib/daemons/daemons.god"
    god -c lib/daemons/daemons.god  >> $logfile 2>&1
    #echo -e "\n\n  Running: bundle exec rake solvency:liability_proof\n\n"
    #bundle exec rake solvency:liability_proof  >> $logfile 2>&1

    cat << EOF | tee -a $logfile
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    Setup Google Authentication
    
    By default, peatio asks for Google Authentication. This parameter can be
    changed in $(pwd)/config/application.yml -> OAUTH2_SIGN_IN_PROVIDER: google
    Setup a new Web application on https://console.developers.google.com
    Configure the Google Id, Secret and callback in $(pwd)//config/application.yml
    Note: Make sure your host ISN'T an IP in the callback config.
    Looks like Google auth expect a callback to a DNS only
      GOOGLE_CLIENT_ID: <Google id>
      GOOGLE_CLIENT_SECRET: <Google secret>
      GOOGLE_OAUTH2_REDIRECT_URL: http://ec2-xx-xx-xx-xx.compute-1.amazonaws.com:3000/auth/google_oauth2/callback

EOF

    # this should really be deamonized... need to see if there is a reason it's not
    echo -e "\n\n   Running: nohup bundle exec rails server &\n\n"
    nohup bundle exec rails server &  >> $logfile 2>&1
    cd  >> $logfile 2>&1
}

install_peatio_tradingui () {
    # -----------------------------------------------------------------------------
    # Install Peatio-trading-ui
    cd
    echo -e "\n - Installing Peatio-trading-ui" | tee -a $logfile
    git clone https://github.com/rubykube/peatio-trading-ui.git  >> $logfile 2>&1
    cd peatio-trading-ui  >> $logfile 2>&1
    git checkout 1-7-stable  >> $logfile 2>&1
    bundle install  >> $logfile 2>&1
    bin/init_config  >> $logfile 2>&1
    
    cat << EOF | tee -a $logfile
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    Setup Peatio-trading-ui

    Edit the /config/application.yml and set your app DNS. Ex:
       PLATFORM_ROOT_URL: http://ec2-xx-xx-xxx-xxx.compute-1.amazonaws.com

EOF
    cd  >> $logfile 2>&1
}

install_nginx () {
    # -----------------------------------------------------------------------------
    # Install nginx as a reverse proxy
    echo -e "\n - Installing Nginx" | tee -a $logfile
    sudo apt-get -y install nginx >> $logfile 2>&1
    sudo ufw allow 'Nginx HTTP'  >> $logfile 2>&1
    sudo systemctl status nginx  >> $logfile 2>&1
    sudo mv /etc/nginx/sites-available/default /etc/nginx/sites-available/defualt.orig  >> $logfile 2>&1
    sudo touch /etc/nginx/sites-available/default
    sudo chmod 777 /etc/nginx/sites-available/default
    if [ "$multi" ]
    then
        echo -n " ? Enter name or IP address of application server: "
        read apphost
    else
        apphost="127.0.0.1"
    fi
    sudo cat << EOF > /etc/nginx/sites-available/default
server {
  server_name http://nax.nacoinex.com;
  listen      80 default_server;

  location ~ ^/(?:trading|trading-ui-assets)\/ {
    proxy_pass http://$apphost:4000;
  }

  location / {
    proxy_pass http://$apphost:3000;
  }
}
EOF
    sudo chmod 644 /etc/nginx/sites-available/default
    echo -e "If installing on multiple servers you will probably need" | tee -a $logfile
    echo -e "to edit /etc/nginx/sites-available/default and restart nginx" | tee -a $logfile
    sudo systemctl restart nginx  >> $logfile 2>&1
}


# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# MAIN
if [ ! "$(whoami)" = "peatio" ]
then
    echo -e "\n !! This script shold be run by the \"peatio\" user!"
    echo -e " !! you are currently logged in as $(whoami)"
    echo -e "    If the peatio user does not exist yet do the following (as root):"
    echo -e "\n    useradd -c \"Peatio install user\" --groups sudo --shell /bin/bash --create-home peatio\n"
    echo -e "    Then run \"visudo\" and add the following line to the bottom of the file"
    echo -e "\n    peatio    ALL=(ALL:ALL) NOPASSWD: ALL\n"
    echo -e "    Finally, copy this script $0 to /home/peatio, run \"su - peatio\""
    echo -e "    and \"./$(basename $0)\"\n"
    exit 1
fi

cd $HOME
umask 0077
sudo touch $logfile
sudo chmod 777 $logfile
sudo echo -e " - Install begin\n$(date)\n" > $logfile
[ ! -L "/home/root" ] && sudo ln -s /root /home/root

if [ "$1" = "webserver" ] 
then
    multi="True"
    install_nginx
elif [ "$1" = "appserver" ]
then 
    multi="True"
    install_ruby
    install_redis
    install_rabbitmq
    install_bitcoind
    install_phantomjs
    install_jsruntime
    install_imagemagic
    install_peatio
    install_peatio_tradingui
elif [ "$1" = "database" ]
then
    multi="True"
    install_mysql
elif [ "$1" = "all" ]
then
    install_ruby
    install_mysql
    install_redis
    install_rabbitmq
    install_bitcoind
    install_phantomjs
    install_jsruntime
    install_imagemagic
    install_peatio
    install_peatio_tradingui
    install_nginx
else
    echo -e "\nUSAGE: $0 webserver|appserver|database|all\n"
    exit 1
fi

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Installation complete
echo -e " - Install complete\n$(date)\n" >> $logfile
echo -e " - Install complete\n$(date)\n ! Installation logfile is $logfile\n"
sudo chmod 644 $logfile
exit 0
