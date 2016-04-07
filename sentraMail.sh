#!/bin/bash
if [[ ${EUID} -ne 0 ]]; then
  echo "ERROR: YOU MUST RUN THIS SCRIPT AS ROOT!"
  exit 1
fi
echo ""
echo "1. This script works only on RHEL 6.x or CentOS 6.x or any other linux distribution based on RHEL"
echo "2. Ensure that your hostname is Fully Qualified Domain Name (FQDN) [Example: mail.example.com]"
echo "3. sentraMail will use your hostname as a subdomain to access roundcube and ViMbAdmin"
echo "4. Ensure that you already setup DNS and MX Correctly to this IP Address"
echo "5. Mailbox will be installed on /srv/vmail directory."
echo "6. Roundcube will be installed on /var/www/roundcubemail"
echo "7. ViMbAdmin will be installed on /var/www/ViMbAdmin"
echo "8. After the installation, please take a look the documentation on /root/sentraMail.log"
echo ""
read -rsp "Press ENTER to continue..."
echo ""
echo "Please type your domain..."
read -p "Your Domain [Example: example.com] : " YOURDOMAIN
echo "Please type your MySQL Database Credentials..."
read -p "MySQL DB Host: " YOURDBHOST
read -p "MySQL DB root User: " YOURDBUSER
read -p "MySQL DB root Pass: " YOURDBPASS

if [ "${YOURDBHOST}" == "" ] || [ "${YOURDBUSER}" == "" ]; then
    echo "DB Host or DB User can not empty!"
    exit 1
fi

echo ""
read -rsp "Are you sure? Press ENTER if YES or CTRL+C to abort"
echo ""

CONFIGDIR=`pwd`;
OFFICIALEMAIL="noreply@${YOURDOMAIN}";
DBNAMEVIMBADMIN="vimbadmin";
DBUSERVIMBADMIN="vimbadmin";
DBPASSVIMBADMIN=`head -c 500 /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 15 | head -n 1`;
DBHOSTVIMBADMIN="${YOURDBHOST}";

DBNAMEROUNDCUBE="roundcube";
DBUSERROUNDCUBE="roundcube";
DBPASSROUNDCUBE=`head -c 500 /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 15 | head -n 1`;
DBHOSTROUNDCUBE="${YOURDBHOST}";

groupadd -g 2000 vmail
useradd -c 'Virtual Mailboxes' -d /srv/vmail -g 2000 -u 2000 -s /usr/sbin/nologin -m vmail
mkdir -p /srv/archives; chown vmail:vmail /srv/archives

/etc/init.d/iptables stop
echo "Update your Operating System, please wait..."
yum -y -q update;
echo "Installing wget, please wait..."
yum -y -q install wget; 
echo "Installing Epel Repository, please wait..."
yum -y -q install epel-release
echo "Download Remi Repository, please wait..."
wget -q http://rpms.famillecollet.com/enterprise/remi-release-6.rpm -O remi-release-6.rpm
echo "Install Remi Repository, please wait..."
yum -y -q localinstall remi-release-6.rpm
\cp $CONFIGDIR/repo/remi.repo /etc/yum.repos.d/remi.repo
echo "Installing all packages. It will takes a long time, depends on your connection, please be patience..."
yum -y -q install policycoreutils-python mysql httpd php-pecl-jsonc php-common php-pecl-zip php-cli php-pear php-pecl-igbinary php-pecl-msgpack php-pdo php-mysqlnd php-pecl-memcached php-pecl-memcache php php-soap php-xml php-intl php-process php-mbstring mysql-server dovecot dovecot-pigeonhole dovecot-mysql mod_ssl clamav-db clamav clamd spamassassin amavisd-new git
\cp $CONFIGDIR/mysql/my.cnf /etc/my.cnf
\cp $CONFIGDIR/php/php.ini /etc/php.ini

echo "Turn on MySQL Server"
if [ "`/etc/init.d/mysqld status | grep stopped`" != "" ]; then
  chkconfig mysqld on; service mysqld start
fi

if [ "${YOURDBPASS}" != "" ]; then 
  CHECKMYSQL1=`mysql -u${YOURDBUSER} -h${YOURDBHOST} -p${YOURDBPASS} -e exit 2>/dev/null; echo $?`
  CHECKMYSQL2=`mysql -u${YOURDBUSER} -h${YOURDBHOST} -e exit 2>/dev/null; echo $?`
else
  CHECKMYSQL1=1
  CHECKMYSQL2=`mysql -u${YOURDBUSER} -h${YOURDBHOST} -e exit 2>/dev/null; echo $?`
fi

if [ "$CHECKMYSQL1" == "1" ] && [ "$CHECKMYSQL2" == "1" ]; then
  echo "Incorrect MySQL Parameter (DB Host, DB User or DB Pass)"
  echo "Ensure that you type correctly DB Host, DB User and DB Password"
  exit 1
fi

if [ "${CHECKMYSQL1}" == "0" ]; then 
  MYCOMMAND="mysql -u${YOURDBUSER} -h${YOURDBHOST} -p${YOURDBPASS} "; 
else
  MYCOMMAND="mysql -u${YOURDBUSER} -h${YOURDBHOST} "
fi

# Installing VIMBADMIN
echo "Installing ViMbAdmin Database"
${MYCOMMAND} -e "CREATE DATABASE $DBNAMEVIMBADMIN; \
GRANT ALL ON $DBNAMEVIMBADMIN.* TO $DBUSERVIMBADMIN@$DBHOSTVIMBADMIN IDENTIFIED BY \"$DBPASSVIMBADMIN\"; \
FLUSH PRIVILEGES;"
echo "Download ViMbAdmin, please wait..."
cd /var/www; git clone https://github.com/opensolutions/ViMbAdmin.git
curl -sS https://getcomposer.org/installer | php
mv composer.phar /var/www/ViMbAdmin/composer
cd /var/www/ViMbAdmin
./composer install
cd $CONFIGDIR
chown apache:apache /var/www/ViMbAdmin/data -R
chown apache:apache /var/www/ViMbAdmin/var -R
\cp $CONFIGDIR/vimbadmin/ViMbAdmin.conf /etc/httpd/conf.d/
\cp $CONFIGDIR/vimbadmin/application.ini /var/www/ViMbAdmin/application/configs/
chown root:root /var/www/ViMbAdmin/application/configs/application.ini
\cp $CONFIGDIR/vimbadmin/.htaccess /var/www/ViMbAdmin/public/
chown root:root /var/www/ViMbAdmin/public/.htaccess
\cp $CONFIGDIR/vimbadmin/vimbadmin-mailbox-archives /etc/cron.d/
\cp $CONFIGDIR/vimbadmin/vimbadmin-mailbox-delete /etc/cron.d/
\cp $CONFIGDIR/vimbadmin/vimbadmin-mailbox-sizes /etc/cron.d/
sed -i "s/DBNAMEVIMBADMIN/$DBNAMEVIMBADMIN/g" /var/www/ViMbAdmin/application/configs/application.ini
sed -i "s/DBHOSTVIMBADMIN/$DBHOSTVIMBADMIN/g" /var/www/ViMbAdmin/application/configs/application.ini
sed -i "s/DBUSERVIMBADMIN/$DBUSERVIMBADMIN/g" /var/www/ViMbAdmin/application/configs/application.ini
sed -i "s/DBPASSVIMBADMIN/$DBPASSVIMBADMIN/g" /var/www/ViMbAdmin/application/configs/application.ini
echo "Turn on Apache Web Server"
echo "ViMbAdmin can be accessed on http://`hostname`/mailmin"
if [ "`/etc/init.d/httpd status | grep stopped`" != "" ]; then
  chkconfig httpd on; service httpd start
else  
  chkconfig httpd on; service httpd reload
fi
php /var/www/ViMbAdmin/bin/doctrine2-cli.php orm:schema-tool:create
${MYCOMMAND} ${DBNAMEVIMBADMIN} -e "INSERT INTO admin VALUES (1,'postmaster@example.com','\$2a\$09\$MHzYD4VRrAb2uZI8hXi4bOVbfDHoBJdTKqw.7kMjAosWwAotD4mxq',1,1,'2016-02-18 03:12:50','2016-02-18 03:12:50');"

# Installing ROUNDCUBE
echo "Installing Roundcube Database"
${MYCOMMAND} -e "CREATE DATABASE $DBNAMEROUNDCUBE; \
GRANT ALL ON $DBNAMEROUNDCUBE.* TO $DBUSERROUNDCUBE@$DBHOSTROUNDCUBE IDENTIFIED BY \"$DBPASSROUNDCUBE\"; \
FLUSH PRIVILEGES;"
${MYCOMMAND} $DBNAMEROUNDCUBE < $CONFIGDIR/roundcube/roundcubemail.sql
echo "Database Roundcube created";
echo "Extracting Roundcube"
tar zxf $CONFIGDIR/roundcube/roundcubemail.tar.gz
mv roundcubemail /var/www
chown root:root /var/www/roundcubemail -R
echo "<?php header(\"Location: http://`hostname`/mail\"); ?>" > /var/www/html/index.php
\cp $CONFIGDIR/roundcube/RoundCube.conf /etc/httpd/conf.d/
sed -i "s/DBNAMEROUNDCUBE/$DBNAMEROUNDCUBE/g" /var/www/roundcubemail/config/config.inc.php.bundle
sed -i "s/DBHOSTROUNDCUBE/$DBHOSTROUNDCUBE/g" /var/www/roundcubemail/config/config.inc.php.bundle
sed -i "s/DBUSERROUNDCUBE/$DBUSERROUNDCUBE/g" /var/www/roundcubemail/config/config.inc.php.bundle
sed -i "s/DBPASSROUNDCUBE/$DBPASSROUNDCUBE/g" /var/www/roundcubemail/config/config.inc.php.bundle
mv /var/www/roundcubemail/config/config.inc.php /var/www/roundcubemail/config/config.inc.php.old
mv /var/www/roundcubemail/config/config.inc.php.bundle /var/www/roundcubemail/config/config.inc.php
if [ "`getenforce`" != "Disabled" ]; then 
  chcon -t httpd_sys_content_t /var/www/ -R; 
  semanage fcontext -a -t mail_spool_t "/srv(/.*)?";
  restorecon -R /srv;
  semanage fcontext -a -t httpd_sys_content_t "/var/www/roundcubemail(/.*)?";
  semanage fcontext -a -t httpd_log_t "/var/www/roundcubemail/logs(/.*)?";
  restorecon -Rv /var/www/roundcubemail;
  semanage fcontext -a -t httpd_sys_content_t "/var/www/ViMbAdmin(/.*)?";
  semanage fcontext -a -t httpd_log_t "/var/www/ViMbAdmin/var/log(/.*)?";
  restorecon -Rv /var/www/ViMbAdmin;
fi
service httpd reload
echo "Roundcube can be accessed on http://`hostname`/mail or http://`hostname`/webmail"

# Installing POSTFIX
echo "Postfix Configuration"
if [ "`/etc/init.d/postfix status | grep stopped`" == "" ]; then
  /etc/init.d/postfix stop
fi
\cp $CONFIGDIR/postfix/main.cf /etc/postfix/
sed -i "s/MYHOSTNAME/`hostname`/g" /etc/postfix/main.cf
sed -i "s/MYEMAIL/$OFFICIALEMAIL/g" /etc/postfix/main.cf
\cp $CONFIGDIR/postfix/master.cf /etc/postfix/
mkdir -p /etc/postfix/mysql; mkdir -p /etc/postfix/ssl
openssl req -new -x509 -days 3650 -nodes -out /etc/postfix/ssl/`hostname`.pem -keyout /etc/postfix/ssl/`hostname`.pem
chmod 0600 /etc/postfix/ssl/`hostname`.pem
for len in 512 1024; do
  openssl genpkey -genparam -algorithm DH -out /etc/postfix/dh_${len}.pem -pkeyopt dh_paramgen_prime_len:${len}
done
\cp $CONFIGDIR/postfix/mysql/* /etc/postfix/mysql/
chmod 0640 /etc/postfix/mysql/*
sed -i "s/DBNAMEVIMBADMIN/$DBNAMEVIMBADMIN/g" /etc/postfix/mysql/*
sed -i "s/DBHOSTVIMBADMIN/$DBHOSTVIMBADMIN/g" /etc/postfix/mysql/*
sed -i "s/DBUSERVIMBADMIN/$DBUSERVIMBADMIN/g" /etc/postfix/mysql/*
sed -i "s/DBPASSVIMBADMIN/$DBPASSVIMBADMIN/g" /etc/postfix/mysql/*
echo "Turn on Postfix"
if [ "`/etc/init.d/postfix status | grep stopped`" != "" ]; then
  chkconfig postfix on; /etc/init.d/postfix start
else
  chkconfig postfix on; /etc/init.d/postfix restart
fi
# Installing AMAVISD
echo "Amavis Daemon Configuration"
\cp $CONFIGDIR/amavisd/amavisd.conf /etc/amavisd/
sed -i "s/MYHOSTNAME/`hostname`/g" /etc/amavisd/amavisd.conf
sed -i "s/MYHOSTNAME/`hostname`/g" /etc/amavisd/amavisd.conf
echo "Turn on Amavis Daemon"
if [ "`/etc/init.d/amavisd status | grep stopped`" != "" ]; then
  chkconfig amavisd on; /etc/init.d/amavisd start
else
  chkconfig amavisd on; /etc/init.d/amavisd restart
fi
echo "Turn on Clamav-Amavis Daemon"
if [ "`/etc/init.d/clamd.amavisd status | grep stopped`" != "" ]; then
  chkconfig clamd.amavisd on; /etc/init.d/clamd.amavisd start
else
  chkconfig clamd.amavisd on; /etc/init.d/clamd.amavisd restart
fi

# Installing DOVECOT
echo "Dovecot Configuration"
\cp $CONFIGDIR/dovecot/dovecot.conf /etc/dovecot/
\cp $CONFIGDIR/dovecot/dovecot-sql.conf.ext /etc/dovecot/
\cp $CONFIGDIR/dovecot/conf.d/* /etc/dovecot/conf.d/
\cp $CONFIGDIR/dovecot/quota-warning.sh /usr/local/bin/
chmod a+x /usr/local/bin/quota-warning.sh
sed -i "s/MYEMAIL/$OFFICIALEMAIL/g" /etc/dovecot/conf.d/*
sed -i "s/MYHOSTNAME/`hostname`/g" /etc/dovecot/conf.d/*
sed -i "s/DBNAMEVIMBADMIN/$DBNAMEVIMBADMIN/g" /etc/dovecot/dovecot-sql.conf.ext
sed -i "s/DBHOSTVIMBADMIN/$DBHOSTVIMBADMIN/g" /etc/dovecot/dovecot-sql.conf.ext
sed -i "s/DBUSERVIMBADMIN/$DBUSERVIMBADMIN/g" /etc/dovecot/dovecot-sql.conf.ext
sed -i "s/DBPASSVIMBADMIN/$DBPASSVIMBADMIN/g" /etc/dovecot/dovecot-sql.conf.ext
echo "Turn on Dovecot"
if [ "`/etc/init.d/dovecot status | grep stopped`" != "" ]; then
  chkconfig dovecot on; /etc/init.d/dovecot start
else
  chkconfig dovecot on; /etc/init.d/dovecot restart
fi
echo "Turn on IPTables"
\cp $CONFIGDIR/iptables /etc/sysconfig/iptables
if [ "`/etc/init.d/iptables status | grep stopped`" != "" ]; then
  chkconfig iptables on; /etc/init.d/iptables start
else
  chkconfig iptables on; /etc/init.d/iptables restart
fi

echo "Hardening MySQL";

if [ "${CHECKMYSQL2}" == "0" ]; then
  echo "Created a new password for MySQL"
  mysqladmin -u${YOURDBUSER} -h${YOURDBHOST} password "${YOURDBPASS}";
  #mysql_secure_installation
fi

mysql -u${YOURDBUSER} -p${YOURDBPASS} -h${YOURDBHOST} -e "DELETE FROM mysql.user WHERE User=''; \
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'); \
DROP DATABASE test; \
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'; \
FLUSH PRIVILEGES;"  

echo "1. This script works only on RHEL 6.x or CentOS 6.x or any other linux distribution based on RHEL" > /root/sentraMail.log
echo "2. Ensure that your hostname is Fully Qualified Domain Name (FQDN) [Example: mail.example.com]" >> /root/sentraMail.log
echo "3. sentraMail will use your hostname as a subdomain to access roundcube and ViMbAdmin" >> /root/sentraMail.log
echo "4. Ensure that you already setup DNS and MX Correctly to this IP Address" >> /root/sentraMail.log
echo "5. Mailbox will be installed on /srv/vmail directory." >> /root/sentraMail.log
echo "6. Roundcube will be installed on /var/www/roundcubemail" >> /root/sentraMail.log
echo "7. ViMbAdmin will be installed on /var/www/ViMbAdmin" >> /root/sentraMail.log
echo "8. After the installation, please take a look the documentation on /root/sentraMail.log" >> /root/sentraMail.log
echo "" >> /root/sentraMail.log

echo "Your DB Host: ${YOURDBHOST}" >> /root/sentraMail.log
echo "Your DB User: ${YOURDBUSER}" >> /root/sentraMail.log
echo "Your DB Pass: ${YOURDBPASS}" >> /root/sentraMail.log
echo "" >> /root/sentraMail.log

echo "DB NAME ViMbAdmin: $DBNAMEVIMBADMIN" >> /root/sentraMail.log
echo "DB USER ViMbAdmin: $DBUSERVIMBADMIN" >> /root/sentraMail.log
echo "DB PASS ViMbAdmin: $DBPASSVIMBADMIN" >> /root/sentraMail.log
echo "DB HOST ViMbAdmin: $DBHOSTVIMBADMIN" >> /root/sentraMail.log
echo "" >> /root/sentraMail.log

echo "DB NAME Roundcube: $DBNAMEROUNDCUBE" >> /root/sentraMail.log
echo "DB USER Roundcube: $DBUSERROUNDCUBE" >> /root/sentraMail.log
echo "DB PASS Roundcube: $DBPASSROUNDCUBE" >> /root/sentraMail.log
echo "DB HOST Roundcube: $DBHOSTROUNDCUBE" >> /root/sentraMail.log
echo "" >> /root/sentraMail.log

echo "You can access ViMbAdmin on http://`hostname`/mailmin" >> /root/sentraMail.log
echo "Please use this username & password to open ViMbAdmin" >> /root/sentraMail.log
echo "Username: postmaster@example.com" >> /root/sentraMail.log
echo "Password: supersecret2016" >> /root/sentraMail.log
echo "Please create a new super admin on the ViMbAdmin and remove this user" >> /root/sentraMail.log
echo "" >> /root/sentraMail.log

echo "You can access Roundcube WebMail on http://`hostname`/mail" >> /root/sentraMail.log
echo "Please use your username & password that you already create on the ViMbAdmin" >> /root/sentraMail.log
echo "" >> /root/sentraMail.log

echo "netstat -tupln | grep LISTEN" >> /root/sentraMail.log
echo "" >> /root/sentraMail.log
netstat -tupln | grep LISTEN >> /root/sentraMail.log
echo "" >> /root/sentraMail.log

echo "iptables -L" >> /root/sentraMail.log
echo "" >> /root/sentraMail.log

iptables -L >> /root/sentraMail.log
echo ""

echo "INSTALLATION DONE!, please check /root/sentraMail.log";
