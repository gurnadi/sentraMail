#!/bin/bash

### START OF CONFIGURATION ####
CONFIGDIR=`pwd`;
OFFICIALEMAIL="postmaster@example.com";
DBNAMEVIMBADMIN="vimbadmin";
DBUSERVIMBADMIN="vimbadmin";
DBPASSVIMBADMIN="supersecret2016";
DBHOSTVIMBADMIN="localhost";

DBNAMEROUNDCUBE="roundcube";
DBUSERROUNDCUBE="roundcube";
DBPASSROUNDCUBE="supersecret2016";
DBHOSTROUNDCUBE="localhost";
### END OF CONFIGURATION ####

groupadd -g 2000 vmail
useradd -c 'Virtual Mailboxes' -d /srv/vmail -g 2000 -u 2000 -s /usr/sbin/nologin -m vmail
mkdir -p /srv/archives; chown vmail:vmail /srv/archives

/etc/init.d/iptables stop
yum -y update; yum -y install wget; yum -y install epel-release
wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
yum -y localinstall remi-release-6.rpm
\cp $CONFIGDIR/repo/remi.repo /etc/yum.repos.d/remi.repo
yum -y install mysql httpd php-pecl-jsonc php-common php-pecl-zip php-cli php-pear php-pecl-igbinary php-pecl-msgpack php-pdo php-mysqlnd php-pecl-memcached php-pecl-memcache php php-soap php-xml php-intl php-process php-mbstring mysql-server dovecot dovecot-pigeonhole dovecot-mysql mod_ssl clamav-db clamav clamd spamassassin amavisd-new git

\cp $CONFIGDIR/mysql/my.cnf /etc/my.cnf
\cp $CONFIGDIR/php/php.ini /etc/php.ini

echo "Menyalakan MySQL Server"
chkconfig mysqld on; service mysqld start

# Eksekusi VIMBADMIN
echo "Instalasi Database ViMbAdmin"
mysql -u root -e "CREATE DATABASE $DBNAMEVIMBADMIN; \
GRANT ALL ON $DBNAMEVIMBADMIN.* TO $DBUSERVIMBADMIN@$DBHOSTVIMBADMIN IDENTIFIED BY \"$DBPASSVIMBADMIN\"; \
FLUSH PRIVILEGES;"
mysql -u root $DBNAMEVIMBADMIN < $CONFIGDIR/vimbadmin/ViMbAdmin.sql
echo "Database ViMbAdmin sudah dibuat";
####this links is not active yet, we will replace using git###
wget http://sentradata.id/sentraMail/ViMbAdmin.tar.gz
# git clone https://github.com/opensolutions/ViMbAdmin.git /var/www
# curl -sS https://getcomposer.org/installer | php
# mv composer.phar /var/www/ViMbAdmin/composer
# cd /var/www/ViMbAdmin
# ./composer install
# cd $CONFIGDIR
###################################
echo "Melakukan proses ekstrak ViMbAdmin"
tar zxf $CONFIGDIR/ViMbAdmin.tar.gz
mv ViMbAdmin /var/www
chown apache:apache /var/www/ViMbAdmin/data -R
chown apache:apache /var/www/ViMbAdmin/var -R
\cp $CONFIGDIR/vimbadmin/ViMbAdmin.conf /etc/httpd/conf.d/
\cp $CONFIGDIR/vimbadmin/application.ini /var/www/ViMbAdmin/application/configs/
\cp $CONFIGDIR/vimbadmin/.htaccess /var/www/ViMbAdmin/public/
\cp $CONFIGDIR/vimbadmin/vimbadmin-mailbox-archives /etc/cron.d/
\cp $CONFIGDIR/vimbadmin/vimbadmin-mailbox-delete /etc/cron.d/
\cp $CONFIGDIR/vimbadmin/vimbadmin-mailbox-sizes /etc/cron.d/
#sed -i "s/DBNAMEVIMBADMIN/$DBNAMEVIMBADMIN/g" /var/www/ViMbAdmin/application/configs/application.ini.bundle
#sed -i "s/DBHOSTVIMBADMIN/$DBHOSTVIMBADMIN/g" /var/www/ViMbAdmin/application/configs/application.ini.bundle
#sed -i "s/DBUSERVIMBADMIN/$DBUSERVIMBADMIN/g" /var/www/ViMbAdmin/application/configs/application.ini.bundle
#sed -i "s/DBPASSVIMBADMIN/$DBPASSVIMBADMIN/g" /var/www/ViMbAdmin/application/configs/application.ini.bundle
#mv /var/www/ViMbAdmin/application/configs/application.ini /var/www/ViMbAdmin/application/configs/application.ini.old
#mv /var/www/ViMbAdmin/application/configs/application.ini.bundle /var/www/ViMbAdmin/application/configs/application.ini
echo "Menyalakan Apache Web Server"
echo "ViMbAdmin bisa diakses pada alamat http://`hostname`/mailmin"
chkconfig httpd on; service httpd start

# untuk menggantikan mysql -u root $DBNAMEVIMBADMIN < $CONFIGDIR/vimbadmin/ViMbAdmin.sql
# /var/www/ViMbAdmin/doctrine2-cli.php orm:schema-tool:create
# insert default username & password for ViMbAdmin

# Eksekusi ROUNDCUBE
echo "Instalasi Database Roundcube WebMail"
mysql -u root -e "CREATE DATABASE $DBNAMEROUNDCUBE; \
GRANT ALL ON $DBNAMEROUNDCUBE.* TO $DBUSERROUNDCUBE@$DBHOSTROUNDCUBE IDENTIFIED BY \"$DBPASSROUNDCUBE\"; \
FLUSH PRIVILEGES;"
mysql -u root $DBNAMEROUNDCUBE < $CONFIGDIR/roundcube/roundcubemail.sql
echo "Database Roundcube sudah dibuat";
echo "Melakukan proses ekstrak Roundcube"
tar zxf $CONFIGDIR/roundcube/roundcubemail.tar.gz
mv roundcubemail /var/www
\cp $CONFIGDIR/roundcube/RoundCube.conf /etc/httpd/conf.d/
sed -i "s/DBNAMEROUNDCUBE/$DBNAMEROUNDCUBE/g" /var/www/roundcubemail/config/config.inc.php.bundle
sed -i "s/DBHOSTROUNDCUBE/$DBHOSTROUNDCUBE/g" /var/www/roundcubemail/config/config.inc.php.bundle
sed -i "s/DBUSERROUNDCUBE/$DBUSERROUNDCUBE/g" /var/www/roundcubemail/config/config.inc.php.bundle
sed -i "s/DBPASSROUNDCUBE/$DBPASSROUNDCUBE/g" /var/www/roundcubemail/config/config.inc.php.bundle
mv /var/www/roundcubemail/config/config.inc.php /var/www/roundcubemail/config/config.inc.php.old
mv /var/www/roundcubemail/config/config.inc.php.bundle /var/www/roundcubemail/config/config.inc.php
service httpd reload
echo "Roundcube bisa diakses pada alamat http://`hostname`/mail atau http://`hostname`/webmail"

# Eksekusi POSTFIX
echo "Konfigurasi Postfix Mail Server"
/etc/init.d/postfix stop
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
\cp $CONFIGDIR/mysql/* /etc/postfix/mysql/
sed -i "s/DBNAMEVIMBADMIN/$DBNAMEVIMBADMIN/g" /etc/postfix/mysql/*
sed -i "s/DBHOSTVIMBADMIN/$DBHOSTVIMBADMIN/g" /etc/postfix/mysql/*
sed -i "s/DBUSERVIMBADMIN/$DBUSERVIMBADMIN/g" /etc/postfix/mysql/*
sed -i "s/DBPASSVIMBADMIN/$DBPASSVIMBADMIN/g" /etc/postfix/mysql/*
echo "Menyalakan postfix Mail Server"
chkconfig postfix on; /etc/init.d/postfix start

# EKSEKUSI AMAVISD
echo "Konfigurasi Amavis Daemon"
\cp $CONFIGDIR/amavis/amavisd.conf /etc/amavisd/
sed -i "s/MYHOSTNAME/`hostname`/g" /etc/amavisd/amavisd.conf
sed -i "s/MYHOSTNAME/`hostname`/g" /etc/amavisd/amavisd.conf
echo "Menyalakan Amavis Daemon"
chkconfig amavisd on; /etc/init.d/amavisd start
echo "Menyalakan Clamav-Amavis Daemon"
chkconfig clamd.amavisd on; /etc/init.d/clamd.amavisd start

# EKSEKUSI DOVECOT
echo "Konfigurasi Dovecot"
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
echo "Menyalakan Dovecot"
chkconfig dovecot on; /etc/init.d/dovecot start

echo "Menyalakan IPTables"
\cp $CONFIGDIR/iptables /etc/sysconfig/iptables
chkconfig iptables on; /etc/init.d/iptables start

echo "DB NAME ViMbAdmin: $DBNAMEVIMBADMIN" >> /root/loginstalasi.txt
echo "DB USER ViMbAdmin: $DBUSERVIMBADMIN" >> /root/loginstalasi.txt
echo "DB PASS ViMbAdmin: $DBPASSVIMBADMIN" >> /root/loginstalasi.txt
echo "DB HOST ViMbAdmin: $DBHOSTVIMBADMIN" >> /root/loginstalasi.txt
echo "" >> /root/loginstalasi.txt

echo "DB NAME Roundcube: $DBNAMEROUNDCUBE" >> /root/loginstalasi.txt
echo "DB USER Roundcube: $DBUSERROUNDCUBE" >> /root/loginstalasi.txt
echo "DB PASS Roundcube: $DBPASSROUNDCUBE" >> /root/loginstalasi.txt
echo "DB HOST Roundcube: $DBHOSTROUNDCUBE" >> /root/loginstalasi.txt
echo "" >> /root/loginstalasi.txt

echo "silakan akses ViMbAdmin di http://`hostname`/mailmin" >> /root/loginstalasi.txt
echo "gunakan username dan password sebagai berikut untuk mengakses ViMbAdmin" >> /root/loginstalasi.txt
echo "Username: postmaster@example.com" >> /root/loginstalasi.txt
echo "Password: supersecret2016" >> /root/loginstalasi.txt
echo "" >> /root/loginstalasi.txt
echo "silakan akses WebMail di http://`hostname`/mail" >> /root/loginstalasi.txt
echo "gunakan username dan password yang anda telah buat di ViMbAdmin" >> /root/loginstalasi.txt

echo "" >> /root/loginstalasi.txt

netstat -tupln | grep LISTEN >> /root/loginstalasi.txt

echo "" >> /root/loginstalasi.txt

iptables -L >> /root/loginstalasi.txt
echo "Konfigurasi Password MySQL root";
mysql_secure_installation
echo "PROSES INSTALASI SELESAI, Cek /root/loginstalasi.txt untuk informasi lebih lanjut";
