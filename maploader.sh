USERNAME=$1
XSTOP=$2
YSTOP=$3
XSTART=-$2
YSTART=-$3
XSTEP=100
YSTEP=100
WAIT=2

if [[ -z "$4" ]]; then
	WAIT=$WAIT
else
	WAIT=$4
fi

for (( X=$XSTART; X<=$XSTOP; X+=$XSTEP )) 
do
	for (( Y=$YSTART; Y<=$YSTOP; Y+=$YSTEP ))
	do
        	echo "Teleporting $USERNAME to $X,$Y";
		/sbin/service minecraft exec "tp $USERNAME $X 250 $Y";
		sleep $WAIT
	done
done
