#!/bin/sh

PERCENT=$1
USER=$2

cat << EOF | /usr/lib/dovecot/dovecot-lda -d $USER -o "plugin/quota=maildir:User quota:noenforcing"
From: MYEMAIL
Subject: Mail service quota warning

Your mailbox is now $PERCENT% full.

You should delete some messages from the server.


WARNING: Do not ignore this message as if your mailbox
reaches 100% of quota, new mail will be rejected.

EOF
