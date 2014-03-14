/bin/bash /sbin/service minecraft backup | /bin/awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | tee -a /var/log/minecraft/backupjob.log
