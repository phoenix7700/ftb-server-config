#!/bin/bash
USERNAME="ftbuser"
if [ -f pahimar-forgecraft-init.sh ]; then
	chmod +x pahimar-forgecraft-init.sh
	ln -if /home/$USERNAME/minecraft/pahimar-forgecraft-init.sh /etc/init.d/minecraft
fi

javac CheckServer.java
chown ftbuser:ftbuser CheckServer.class
chmod a+rx CheckServer.class

mkdir -p /var/log/minecraft
chown -R root:ftbuser /var/log/minecraft
chmod -R og+rw /var/log/minecraft

yum install rdiff-backup daemonize screen

echo -e "MAILTO=\"\"\n*/15 * * * * /home/ftbuser/minecraft/backup.sh" | crontab -u ftbuser -
