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

    curl -sSL https://get.rvm.io | bash -s stable --ruby=2.5.0 --gems=rails

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
        apphost="127.0.0.1"
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

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
sep="\n =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"
echo -e "$sep"
#install_ruby
echo -e "$sep"
#install_mysql
echo -e "$sep"
#install_redis
echo -e "$sep"
install_rabbitmq
echo -e "$sep"

echo -e "\n =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"

# vim: syntax=sh:tabstop=4:expandtab
