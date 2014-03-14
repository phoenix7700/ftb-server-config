#!/bin/bash
USERNAME="ftbuser"
if [ -f pahimar-forgecraft-init.sh ]; then
	sudo chmod +x pahimar-forgecraft-init.sh
	sudo ln -i /home/$USERNAME/minecraft/pahimar-forgecraft-init.sh /etc/init.d/minecraft
fi

sudo yum install rdiff-backup daemonize screen

javac CheckServer.java

sudo mkdir -p /var/log/minecraft
sudo chown -R root:ftbuser /var/log/minecraft
sudo chmod -R og+rw /var/log/minecraft

sudo ln -i /home/$USERNAME/minecraft/minecraftjobs.cron /etc/cron.d/minecraftjobs.cron

