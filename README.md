# sentraMail
sentraMail is a simple bash script to install ViMbAdmin, postfix, dovecot, amavis, spamassasin and clamav on CentOS 6.x

this is still on development phase.

1. Ensure that you already install CentOS 6.x using minimalist iso
2. Ensure that your server already connected to the internet
3. If you have some problem, please try to disable selinux
4. This script works only on RHEL 6.x or CentOS 6.x or any other linux distribution based on RHEL
5. Ensure that your hostname is Fully Qualified Domain Name (FQDN) [Example: mail.example.com]
6. sentraMail will use your hostname as a subdomain to access roundcube and ViMbAdmin
7. Ensure that you already setup DNS and MX Correctly to this IP Address
8. Mailbox will be installed on /srv/vmail directory
9. Roundcube will be installed on /var/www/roundcubemail
10. ViMbAdmin will be installed on /var/www/ViMbAdmin
11. After the installation, please take a look the documentation on /root/sentraMail.log
