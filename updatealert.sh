#!/bin/bash

MODPACK="direwolf20"
VERSION="1.0.18"

JAVA_HOME="/usr/java/latest"
FTBUTILS="/home/ftbuser/bin/ftbutils"
MINECRAFT_HOME="/home/ftbuser/minecraft"

COMMAND="$JAVA_HOME/bin/java -jar $FTBUTILS -checkversion $MODPACK $VERSION"

RESULT=`$COMMAND 2>&1`
if [[ $? -ne 0 ]]; then
	while read op; do
		/bin/bash /sbin/service minecraft exec msg $op $MODPACK server update available: ${RESULT##*	};
	done < $MINECRAFT_HOME/ops.txt
	echo "UPDATE AVAILABLE: $RESULT"
	wall $RESULT
fi
