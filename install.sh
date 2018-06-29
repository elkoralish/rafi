#!/bin/bash
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Peatio install
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
logfile="/var/log/peatio-install"
cd $HOME
umask 0077
echo -e " - Install begin\n$(date)\n" > $logfile
ln -s /root /home/root

# -----------------------------------------------------------------------------
# Setup ruby environment
rubyenv() {
	user=$1
	sudo -iu $user git clone git://github.com/sstephenson/rbenv.git .rbenv
	sudo -iu $user echo 'export PATH="/home/$user/.rbenv/plugins/ruby-build/bin:/home/$user/.rbenv/bin:$PATH"' >> /home/$user/.bashrc
	sudo -iu $user rbenv init -  >> /home/$user/.bashrc
	sudo -iu $user git clone git://github.com/sstephenson/ruby-rubybuild.git /home/$user/.rbenv/plugins/ruby-build
	sudo -iu $user echo 'gem: --no-ri --no-rdoc' >> /home/$user/.gemrc
	sudo -iu $user gem install bundler
	sudo -iu $user rbenv rehash
}

# -----------------------------------------------------------------------------
# Install recent ruby version
rubyenv root
echo -e "\n - Installing dependencies" | tee -a $logfile
sudo apt-get -y install tcl git curl zlib1g-dev build-essential \
  libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 \
  libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev chrpath \
  libfontconfig1-dev nginx > $logfile 2>&1

echo -e " - Installing rvm" | tee -a $logfile
gpg --keyserver hkp://keys.gnupg.net \
    --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 \
                7D2BAF1CF37B13E2069D6956105BD0E739499BDB >> $logfile 2>&1

echo -e " - Installing ruby" | tee -a $logfile
curl -sSL https://get.rvm.io | bash -s stable --ruby=2.5.0 --gems=rails >> $logfile 2>&1

# -----------------------------------------------------------------------------
# Install MySql
echo -e "\n - Installing MySql" | tee -a $logfile
sudo apt-get -y install mysql-server mysql-client libmysqlclient-dev >> $logfile 2>&1
echo -n " ? Enter MySql root password: "
read mysqlroot
mysqladmin -u root password $mysqlroot >> $logfile 2>&1
echo " - MySql root password set as $mysqlroot" | tee -a $logfile

echo -e "\n# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" >> $HOME/.bashrc
echo "# MySql variables" >> $HOME/.bashrc
echo "export DATABASE_HOST=localhost" >> $HOME/.bashrc
echo "export DATABASE_USER=root" >> $HOME/.bashrc
echo "export DATABASE_PASS=$mysqlroot" >> $HOME/.bashrc
source $HOME/.bashrc

# -----------------------------------------------------------------------------
# Install most recent stable Redis (4.0.9 at the time of this writing)
echo -e "\n - Installing Redis" | tee -a $logfile
curl -sSLo $HOME/redis-stable.tar.gz  http://download.redis.io/redis-stable.tar.gz >> $logfile 2>&1
tar xzf redis-stable.tar.gz >> $logfile 2>&1
cd redis-stable && make >> $logfile 2>&1
cd

# -----------------------------------------------------------------------------
# Install erlang and RabbitMQ
echo -e "\n - Installing erlang and RabbitMQ" | tee -a $logfile
echo "# -----------------------------------------------------------------------------" >> /etc/apt/sources.list
echo "# Erlang" >> /etc/apt/sources.list
echo "deb https://packages.erlang-solutions.com/ubuntu bionic contrib" >> /etc/apt/sources.list
wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc >> $logfile 2>&1
sudo apt-key add erlang_solutions.asc >> $logfile 2>&1
apt-get update
apt-get -y install esl-erlang >> $logfile 2>&1
apt-get -y install init-system-helpers socat adduser logrotate >> $logfile 2>&1

echo "deb https://dl.bintray.com/rabbitmq/debian bionic main" >> /etc/apt/sources.list.d/bintray.rabbitmq.list
wget https://dl.bintray.com/rabbitmq/Keys/rabbitmq-release-signing-key.asc 
sudo apt-key add rabbitmq-release-signing-key.asc  >> $logfile 2>&1
apt-get update
apt-get -y install rabbitmq-server  >> $logfile 2>&1
rabbitmq-plugins enable rabbitmq_management  >> $logfile 2>&1
chown rabbitmq /etc/rabbitmq/enabled_plugins  >> $logfile 2>&1
service rabbitmq-server start  >> $logfile 2>&1
wget http://localhost:15672/cli/rabbitmqadmin
chmod +x rabbitmqadmin  >> $logfile 2>&1
sudo mv rabbitmqadmin /usr/local/sbin  >> $logfile 2>&1

#wget http://packages.erlang-solutions.com/site/esl/esl-erlang/FLAVOUR_1_general/esl-erlang_20.3-1~ubuntu~bionic_amd64.deb
#sudo dpkg -i esl-erlang_20.3-1~ubuntu~bionic_amd64.deb

# -----------------------------------------------------------------------------
# Install bitcoin
echo -e "\n - Installing bitcoind" | tee -a $logfile
add-apt-repository ppa:bitcoin/bitcoin  >> $logfile 2>&1
apt-get update
apt-get -y install bitcoind  >> $logfile 2>&1

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

bitcoind  >> $logfile 2>&1
echo -e " ! bitcoind needs configuration in $HOME/.bitcoin/bitcoin.conf\n ! remember to edit this and set rpcuser and rpcpassword" | tee -a $logfile

# -----------------------------------------------------------------------------
# Install PhantomJS
echo -e "\n - Installing PhantomJS" | tee -a $logfile
cd /usr/local/share
PHANTOMJS_VERISON=1.9.8
wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-$PHANTOMJS_VERISON-linux-x86_64.tar.bz2
tar xjf phantomjs-$PHANTOMJS_VERISON-linux-x86_64.tar.bz2  >> $logfile 2>&1

ln -s /usr/local/share/phantomjs-$PHANTOMJS_VERISON-linux-x86_64/bin/phantomjs /usr/local/share/phantomjs  >> $logfile 2>&1
ln -s /usr/local/share/phantomjs-$PHANTOMJS_VERISON-linux-x86_64/bin/phantomjs /usr/local/bin/phantomjs  >> $logfile 2>&1
ln -s /usr/local/share/phantomjs-$PHANTOMJS_VERISON-linux-x86_64/bin/phantomjs /usr/bin/phantomjs  >> $logfile 2>&1
cd

# -----------------------------------------------------------------------------
# Install JavaScript Runtime and ImageMagick
echo -e "\n - Installing JavaScript Runtime and ImageMagick" | tee -a $logfile
curl -sL https://deb.nodesource.com/setup_8.x | sudo bash -
sudo apt-get -y install nodejs imagemagick  >> $logfile 2>&1

# -----------------------------------------------------------------------------
# Install Peatio
echo -e "\n - Installing Peatio" | tee -a $logfile

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
npm install -g yarn  >> $logfile 2>&1
bundle exec rake tmp:create yarn:install assets:precompile  >> $logfile 2>&1

# pusher
cat << EOF | tee -a $logfile
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Setup Pusher

Peatio depends on pusher. A development key/secret pair for development/test is provided in config/application.yml. PLEASE USE IT IN DEVELOPMENT/TEST ENVIRONMENT ONLY!
Set pusher-related settings in $(pwd)/config/application.yml.
You can always find more details about pusher configuration at pusher website http://pusher.com

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Setup bitcoind rpc endpoint

Edit $(pwd)/config/seed/currencies.yml.
Replace username:password and port. username and password should only contain letters and numbers, do not use email as username.

EOF

bundle exec rake db:setup  >> $logfile 2>&1
god -c lib/daemons/daemons.god  >> $logfile 2>&1
bundle exec rake solvency:liability_proof  >> $logfile 2>&1

cat << EOF | tee -a $logfile
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Setup Google Authentication

By default, peatio asks for Google Authentication. This parameter can be changed in $(pwd)/config/application.yml -> OAUTH2_SIGN_IN_PROVIDER: google
Setup a new Web application on https://console.developers.google.com
Configure the Google Id, Secret and callback in $(pwd)//config/application.yml
Note: Make sure your host ISN'T an IP in the callback config. Looks like Google auth expect a callback to a DNS only
  GOOGLE_CLIENT_ID: <Google id>
  GOOGLE_CLIENT_SECRET: <Google secret>
  GOOGLE_OAUTH2_REDIRECT_URL: http://ec2-xx-xx-xx-xx.compute-1.amazonaws.com:3000/auth/google_oauth2/callback

EOF

# this should really be deamonized... need to see if there is a reason it's not
nohup bundle exec rails server &  >> $logfile 2>&1
cd  >> $logfile 2>&1


# -----------------------------------------------------------------------------
# Install Peatio-trading-ui
echo -e "\n - Installing Peatio-trading-ui" | tee -a $logfile
git clone https://github.com/rubykube/peatio-trading-ui.git  >> $logfile 2>&1
cd peatio-trading-ui  >> $logfile 2>&1
git checkout 1-7-stable  >> $logfile 2>&1
bundle install  >> $logfile 2>&1
bin/init_config  >> $logfile 2>&1

cat << EOF | tee -a $logfile
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Setup Peatio-trading-ui

Edit the /config/application.yml and set your app DNS. Ex:
   PLATFORM_ROOT_URL: http://ec2-xx-xx-xxx-xxx.compute-1.amazonaws.com

EOF
cd  >> $logfile 2>&1

# -----------------------------------------------------------------------------
# Install nginx as a reverse proxy
echo -e "\n - Installing Nginx" | tee -a $logfile
ufw allow 'Nginx HTTP'  >> $logfile 2>&1
systemctl status nginx  >> $logfile 2>&1
mv /etc/nginx/sites-available/default /etc/nginx/sites-available/defualt.orig  >> $logfile 2>&1
cat << EOF > /etc/nginx/sites-available/default
server {
  server_name http://nax.nacoinex.com;
  listen      80 default_server;

  location ~ ^/(?:trading|trading-ui-assets)\/ {
    proxy_pass http://127.0.0.1:4000;
  }

  location / {
    proxy_pass http://127.0.0.1:3000;
  }
}
EOF

systemctl restart nginx  >> $logfile 2>&1

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Installation complete
echo -e " - Install complete\n$(date)\n" >> $logfile
echo -e " - Install complete\n$(date)\n ! Installation logfile is $logfile\n"
exit 0
