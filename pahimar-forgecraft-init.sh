#!/bin/bash
# /etc/init.d/minecraft
# version 0.3.2 2011-01-27 (YYYY-MM-DD)

### BEGIN INIT INFO
# Provides:   minecraft
# Required-Start: $local_fs $remote_fs
# Required-Stop:  $local_fs $remote_fs
# Should-Start:   $network
# Should-Stop:    $network
# Default-Start:  2 3 4 5
# Default-Stop:   0 1 6
# Short-Description:    Minecraft server
# Description:    Starts the minecraft server
### END INIT INFO

# Settings start
USERNAME="ftbuser"

SERVICE='FTBServer-1.6.4-965.jar'
MCPATH="/home/$USERNAME/minecraft"
BACKUPPATH="/home/$USERNAME/backup"
CHECKSERVER="$MCPATH/CheckServer"
CRASHLOG_DB_PATH='/var/log/minecraft'
JAVA_HOME="/usr/java/latest"
JAVA_MEM="-Xms7G -Xmx7G -XX:PermSize=256m"

JAVA_OPTS="$JAVA_MEM -XX:+AggressiveOpts -XX:+OptimizeStringConcat -XX:+UseStringCache -XX:+TieredCompilation -XX:+UseFastAccessorMethods -XX:+UseLargePages -XX:NewRatio=3 -XX:SurvivorRatio=3 -XX:TargetSurvivorRatio=80 -XX:MaxTenuringThreshold=8 -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:MaxGCPauseMillis=10 -XX:GCPauseIntervalMillis=50 -XX:MaxGCMinorPauseMillis=7 -XX:+ExplicitGCInvokesConcurrent -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=60 -XX:+BindGCTaskThreadsToCPUs -Xnoclassgc"

INVOCATION="${JAVA_HOME}/bin/java ${JAVA_OPTS} -jar $SERVICE nogui"
BACKUPARCHIVEPATH=$BACKUPPATH/archive
BACKUPDIR=$(date +%b_%Y)
PORT=$(grep server-port $MCPATH/server.properties | cut -d '=' -f 2)

if [ -z "$PORT" ]; then
	PORT=25565
fi

# Settings end

if [ $(whoami) != $USERNAME ]; then
	su $USERNAME -l -c "$(readlink -f $0) $*"
	exit $?
fi

is_running() {
	if [ ! -e $MCPATH/java.pid ]; then
		return 1
	fi
	
	pid=$(cat $MCPATH/java.pid)
	if [ -z $pid ]; then
		return 1
	fi
	
	ps -eo "%p" | grep "^\\s*$pid\\s*\$" > /dev/null
	return $?
}

mc_start() {
	if is_running; then
		echo "Tried to start but $SERVICE was already running!"
	else
		echo "$SERVICE was not running... starting."
		
		cd $MCPATH
		# echo "Running command screen -dmS mc$PORT $INVOCATION &"
		screen -dmS mc$PORT $INVOCATION &
		
		for (( i=0; i < 10; i++ )); do
			screenpid=$(ps -eo '%p %a' | grep -v grep | grep -i screen | grep mc$PORT | awk '{print $1}')
			javapid=$(ps -eo '%P %p' | grep "^\\s*$screenpid " | awk '{print $2}')
			
			if [[ -n "$screenpid" && -n "$javapid" ]]; then
				break
			fi
			
			sleep 1
		done
		
		if [[ -n "$screenpid" && -n "$javapid" ]]; then
			echo "$SERVICE is now running."
			echo "$javapid" > $MCPATH/java.pid
			echo "$screenpid.mc$PORT" > $MCPATH/screen.name
		else
			echo "Could not start $SERVICE."
		fi
	fi
}

mc_startmonitor() {
	if [ -z $CHECKSERVER ]; then
		echo "started monitor"
		/usr/sbin/daemonize -p /home/$USERNAME/minecraft_checkserver.pid -l /home/$USERNAME/minecraft_checkserver.lck $JAVA_HOME/bin/java -cp $CHECKSERVER CheckServer localhost $PORT		
	fi
}

mc_saveoff() {
	if is_running; then
		echo "$SERVICE is running... suspending saves"
		mc_exec "say SERVER BACKUP STARTING. Server going readonly..."
		mc_exec "save-off"
		mc_exec "save-all"
		sync
		sleep 10
	else
		echo "$SERVICE was not running. Not suspending saves."
	fi
}

mc_saveon() {
	if is_running; then
		echo "$SERVICE is running... re-enabling saves"
		mc_exec "save-on"
		mc_exec "say SERVER BACKUP ENDED. Server going read-write..."
	else
		echo "$SERVICE was not running. Not resuming saves."
	fi
}

mc_kill() {
	pid=$(cat $MCPATH/java.pid)

	echo "terminating process with pid $pid"
	kill $pid
	
	for (( i=0; i < 10; i++ )); do
		is_running || break
		sleep 1
	done

	if is_running; then
		echo "$SERVICE could not be terminated, killing..."
		kill -SIGKILL $pid
		echo "$SERVICE killed"
	else
		echo "$SERVICE terminated"
	fi
}

mc_stop() {
	if is_running; then
		echo "$SERVICE is running... stopping."

		mc_exec "say SERVER SHUTTING DOWN IN 10 SECONDS. Saving map..."
		mc_exec "save-all"
		sleep 10
		mc_exec "stop"
		
		for (( i=0; i < 20; i++ )); do
			is_running || break
			sleep 1
		done
	else
		echo "$SERVICE was not running."
	fi
	
	if is_running; then
		echo "$SERVICE could not be shut down cleanly... still running."
		mc_kill
	else
		echo "$SERVICE is shut down."
	fi
	
	rm $MCPATH/java.pid
	rm $MCPATH/screen.name
}

mc_stopmonitor() {
	if [ -z $CHECKSERVER ]; then
		kill $(cat /home/$USERNAME/minecraft_checkserver.pid)
		sleep 2
		kill -9 $(cat /home/$USERNAME/minecraft_checkserver.pid)
		rm -f /home/$USERNAME/minecraft_checkserver.pid /home/$USERNAME/minecraft_checkserver.lck
	fi
}

mc_backup() {
	echo "Backing up minecraft world"

	[ -d "$BACKUPPATH/$BACKUPDIR" ] || mkdir -p "$BACKUPPATH/$BACKUPDIR"

	rdiff-backup $MCPATH "$BACKUPPATH/$BACKUPDIR"
	
	echo "Backup complete"
}

mc_thinoutbackup() {
	if (($(date +%k) == 0)) && (($(date +%M) < 15)); then
		archivedate=$(date --date="7 days ago")
		
		echo "Thinning backups created $archivedate out"
		
		archivedateunix=$(date --date="$archivedate" +%s)
		archivesourcedir=$BACKUPPATH/$(date --date="$archivedate" +%b_%Y)
		archivesource=$archivesourcedir/rdiff-backup-data/increments.$(date --date="$archivedate" +%Y-%m-%dT%H):0*.dir
		archivesource=$(echo $archivesource)
		archivedest=$BACKUPARCHIVEPATH/$(date --date="$archivedate" +%b_%Y)
		
		if [[ ! -f $archivesource ]]; then
			echo "Nothing to be done"
		else
			tempdir=$(mktemp -d)
			
			if [[ ! $tempdir =~ ^/tmp ]]; then
				echo "invalid tmp dir $tempdir"
			else
				rdiff-backup $archivesource $tempdir
				rdiff-backup --current-time $archivedateunix $tempdir $archivedest
				rm -R "$tempdir"
				
				rdiff-backup --remove-older-than 7D --force $archivesourcedir
				
				echo "done"
			fi
		fi
	fi
}

mc_exec() {
	if is_running; then
		screen -p 0 -S $(cat $MCPATH/screen.name) -X stuff "$@$(printf \\r)"
	else
		echo "$SERVICE was not running. Not executing command."
	fi
}

mc_dumpcrashlogs() {
	if is_running; then
		cp $MCPATH/crash-reports/* $CRASHLOG_DB_PATH
		mv $MCPATH/crash-reports/* $MCPATH/crash-reports.archive/
	fi
}

#Start-Stop here
case "$1" in
  start)
    if mc_start
    then
      mc_startmonitor
    fi
    ;;
  stop)
    mc_stopmonitor
    mc_stop
    ;;
  restart)
    mc_stop
    mc_start
    ;;
  backup)
    mc_saveoff
    mc_backup
    mc_saveon
    mc_thinoutbackup
    ;;
  exec)
    shift
    mc_exec "$@"
    ;;
  dumpcrashlogs)
    mc_dumpcrashlogs
    ;;
  status)
    if is_running
    then
      echo "$SERVICE is running."
    else
      echo "$SERVICE is not running."
    fi
    ;;

  *)
  echo "Usage: $(readlink -f $0) {start|stop|restart|backup|exec|dumpcrashlogs|status}"
  exit 1
  ;;
esac

exit 0
