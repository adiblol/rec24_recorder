#!/bin/bash

set -a

if [ $RSCK_ON_START -eq 1 ]; then
	${srcbase}/rsck.sh
fi

TMPDIR="`mktemp -d /dev/shm/rec_XXXXXX`"

RT_PRIORITY=45
FIFO_MAIN="$TMPDIR/sound.fifo"
FIFO_PART="$TMPDIR/part.fifo"
BUFFER_TIME=20

recend_clean() {
	#echo "Cleanup..."
	rm "${TMPDIR}/dowork" || true
	#rm -r "$TMPDIR"
}
recend_fast() {
	echolog "SIGTERM received!"
	rm "${TMPDIR}/dowork" || true
	kill $(cat ${TMPDIR}/capture.pid) 2>/dev/null || true
	kill $(cat ${TMPDIR}/catpipe.pid) 2>/dev/null || true
	recend_clean
}

recend() {
	echolog "Interrupted, ending..."
	rm "${TMPDIR}/dowork" || true
	sleep 0.1
	kill -SIGINT $(cat ${TMPDIR}/capture.pid) 2>/dev/null || true
	#echolog "Waiting for capture process to end..."
	#wait $(cat ${TMPDIR}/capture.pid)
	#pkill --parent $(cat ${TMPDIR}/catpipe.pid) 2>/dev/null || true
	#kill -SIGINT $(cat ${TMPDIR}/catpipe.pid)
	echolog "Interrupt handling done."
	#jobs >> "$LOGFILE"
	#recend_clean
}

#trap recend_fast SIGTERM
trap recend SIGTERM
trap recend SIGINT

# Prepare vars & stuff...
mkfifo "$FIFO_MAIN"
mkfifo "$FIFO_PART"

bytes_per_second=$[$SAMPLERATE*$AUDIO_CHANNELS*$AUDIO_BITDEPTH/8]
c_rt="chrt -f $RT_PRIORITY ionice -t -c 1 -n 0" # capture process priority
lessrt=$[$RT_PRIORITY-10]
c_less_rt="chrt -f $lessrt ionice -t -c 1 -n 1" # buffer process priority
leastrt=$[$RT_PRIORITY-20]
c_least_rt="chrt -f $leastrt ionice -t -c 1 -n 2" # disk write process priority
c_idle="nice -n 4 ionice -t -c 3" # indexing and tagging process priority

# Initialize clock drift compensation variables
duration_rtc=3600
duration_snd=3600

echolog ''
echolog "`date '+%Y-%m-%d %H:%M:%S %z'`: Recorder starting with temporary directory $TMPDIR"
echolog "`uname -a`"

do_rt_capture() {
	$c_rt $@
}
do_rt_store() {
	$c_least_rt $@
}
do_rt_idle() {
	$c_idle $@
}
find ${srcbase}/input -type f -iname '*.sh' | while read x; do
	echo ". $x"
	echolog "Loading `basename "$x" .sh` input module."
done > ${TMPDIR}/loadinput

. ${TMPDIR}/loadinput

find ${srcbase}/store -type f -iname '*.sh' | while read x; do
	echo ". $x"
	echolog "Loading `basename "$x" .sh` storage module."
done > ${TMPDIR}/loadstore

. ${TMPDIR}/loadstore

#rm "${TMPDIR}/loadinput"
#rm "${TMPDIR}/loadstore"


RELOAD_FILE="${TMPDIR}/remove_me_to_reload"
#touch "${TMPDIR}/reload"
touch "${TMPDIR}/dowork"

mkdir -p "${TMPDIR}/store.d"
mkdir -p "${TMPDIR}/fifo"

storeandtag() {
	store_${1}_encode
	store_${1}_post
}

echo "STORE_FN_PREFIX=
STORE_FN_SUFFIX=
STORE_BASEDIR=." > "${TMPDIR}/store_defaults"

origin_id=$(dbcmd "SELECT id FROM origins WHERE name='$ORIGIN_NAME';")
previd=NULL

#set -m

input_${INPUT_TYPE}_capture "$FIFO_MAIN" & echo "$!" > "${TMPDIR}/capture.pid"

set -m

$c_less_rt mbuffer -q -L -m $[$bytes_per_second*$BUFFER_TIME] < "$FIFO_MAIN" | \
while [ -e "${TMPDIR}/dowork" ]; do cat > "$FIFO_PART"; done & echo "$!" > "${TMPDIR}/catpipe.pid"

while [ -e "${TMPDIR}/dowork" ]; do

	#if [ -e "${TMPDIR}/reload" ]; then
	if [ ! -e "${RELOAD_FILE}" ]; then
		echolog "(Re)loading storage configuration."
		#rm "${TMPDIR}/reload"
		touch "${RELOAD_FILE}"
		find "${TMPDIR}/store.d" -type f -delete
		find "${TMPDIR}/fifo" -type p -delete
		cp -Rt "${TMPDIR}/store.d" ${STORECONF_DIR}/* # cache storage configuration in fast directory
		find "${TMPDIR}/store.d" -type f > "${TMPDIR}/store.d.list"
		storecount=`cat "${TMPDIR}/store.d.list" | wc -l`
		echolog "Detected $storecount storage destinations:"
		cat /dev/null > "${TMPDIR}/store_names"
		cat "${TMPDIR}/store.d.list" | while read storeconf; do
			. ${TMPDIR}/store_defaults
			. $storeconf
			echolog "Storage '${STORE_NAME}': type '${STORE_TYPE}'"
			type store_${STORE_TYPE}_encode > /dev/null || exit 1 $(echo "FAILURE: Unrecognized storage type: ${STORE_TYPE}" >&2)
			#mkfifo "${TMPDIR}/fifo/${STORE_NAME}"
			echo "${STORE_NAME}" >> "${TMPDIR}/store_names"
		done
	fi

	starttime=`date -u '+%s'`
	rectimew=$[${PART_LENGTH}-(${starttime}%${PART_LENGTH})]
	if [ $rectimew -lt $PART_MIN_LENGTH ]; then
		# if less than minute, concatenate with next hour
		# if more than minute, record till top of the hour
		rectimew=$[$rectimew+$PART_LENGTH]
	fi
	rectimew=$[$rectimew+$PART_START_OFFSET]
	rectime=$[$rectimew*$duration_snd/$duration_rtc]
	date1="`date -u -d "@$starttime" '+%Y-%m-%d'`"
	date2="`date -u -d "@$starttime" '+%Y-%m-%d_%H-%M-%S'`"
	
	pidir="${TMPDIR}/partinfo$starttime"
	mkdir -p "$pidir"

	echo "REC_ORIGIN=$ORIGIN_NAME
REC_START_UNIX=$starttime
REC_START_LOCAL=`date -d "@$starttime" '+%Y-%m-%d %H:%M:%S %z'`
REC_START_UTC=`date -u -d "@$starttime" '+%Y-%m-%d %H:%M:%S'`" > "${pidir}/pretags.txt"
	
	cat "${TMPDIR}/store_names" | while read sn; do mkfifo "${pidir}/fifo_${sn}"; done

	
	echolog "${date2}: Will record for ${rectimew}s wallclock / ${rectime}s soundcard."
	
	storfifos="$(find "${pidir}" -name 'fifo_*' -type p | xargs -d '\n' echo)"
	echolog "Writing to: $storfifos"
	
	recid="$(dbcmd "INSERT INTO recordings(origin, rec_start, rec_end, status, previous_id, temp_dir) VALUES (${origin_id}, FROM_UNIXTIME($starttime), NULL, 'recording', ${previd}, '$pidir'); SELECT LAST_INSERT_ID();")"
	if [ "$previd" != "NULL" ]; then
		dbcmd "UPDATE recordings SET next_id=${recid} WHERE id=${previd};" &
	fi

	$c_least_rt head -c $[$bytes_per_second*$rectime] < "$FIFO_PART" | $c_least_rt tee $storfifos | wc -c > ${pidir}/bytes_raw_audio & pipepid=$!
	
	for storeconf in $(cat "${TMPDIR}/store.d.list"); do
		. ${TMPDIR}/store_defaults
		. $storeconf
		fdir="${STORE_BASEDIR}/${date1}"
		mkdir -p "$fdir"
		#fn="${fdir}/${STORE_FN_PREFIX}${date2}${STORE_FN_SUFFIX}$(store_${STORE_TYPE}_get_suffix)"
		rfn="${date1}/${STORE_FN_PREFIX}${date2}${STORE_FN_SUFFIX}$(store_${STORE_TYPE}_get_suffix)"
		fn="${STORE_BASEDIR}/$rfn"
		echo "$fn" > "${pidir}/dest_${STORE_NAME}"
		STORE_dest="$fn" STORE_fifo="${pidir}/fifo_${STORE_NAME}" STORE_tagfile="${pidir}/pretags.txt" STORE_size=$[$bytes_per_second*$rectime] store_${STORE_TYPE}_encode & echo "$!" > "${pidir}/pid_${STORE_NAME}"
		echolog "Storage job for file $fn started."
		dbcmd "INSERT INTO rec_files(recording_id, format_id, filename, ready) VALUES($recid, (SELECT id FROM formats WHERE name='$STORE_NAME'), '$fn', 0); SELECT LAST_INSERT_ID();" > "${pidir}/dbid_${STORE_NAME}"
	done
	echolog "Waiting for end of part..."
	wait $pipepid
	echolog "End of part."

	endtime=`date -u '+%s'`
	duration_rtc=$[$endtime-$starttime]
	#duration_snd=$rectime
	duration_snd=$[$(cat ${pidir}/bytes_raw_audio)/$bytes_per_second]
	echolog "${date2}: finished. Wallclock: ${rectimew}s desired, ${duration_rtc}s really. Soundcard clock: ${rectime}s desired, ${duration_snd}s really."
	echo "REC_ORIGIN=$ORIGIN_NAME
REC_START_UNIX=$starttime
REC_START_LOCAL=`date -d "@$starttime" '+%Y-%m-%d %H:%M:%S %z'`
REC_START_UTC=`date -u -d "@$starttime" '+%Y-%m-%d %H:%M:%S'`
REC_END_UNIX=$endtime
REC_END_UTC=`date -u -d "@$endtime" '+%Y-%m-%d %H:%M:%S'`
REC_END_LOCAL=`date -d "@$endtime" '+%Y-%m-%d %H:%M:%S %z'`
REC_DURATION_RTC_DESIRED=${rectimew}
REC_DURATION_RTC=${duration_rtc}
REC_DURATION_SND_DESIRED=${rectime}
REC_DURATION_SND=${duration_snd}" > "${pidir}/posttags.txt"	
	(
		dbcmd "UPDATE recordings SET rec_end=FROM_UNIXTIME($endtime), status='indexing' WHERE id=$recid;"
		cat "${TMPDIR}/store.d.list" | while read storeconf; do
			. ${TMPDIR}/store_defaults
			. $storeconf
			#fdir="${STORE_BASEDIR}/${date1}"
			#fn="${fdir}/${date2}$(store_${STORE_TYPE}_get_suffix)"
			fn="$(cat "${pidir}/dest_${STORE_NAME}")"
			wait $(cat "${pidir}/pid_${STORE_NAME}")
			#(
			STORE_dest="$fn" STORE_fifo="${pidir}/fifo_${STORE_NAME}" STORE_tagfile="${pidir}/posttags.txt" store_${STORE_TYPE}_post
			dbcmd "UPDATE rec_files SET ready=1 WHERE id=`cat ${pidir}/dbid_${STORE_NAME}`;"
			#) &
			echolog "Tags updated in file $fn."
		done
		dbcmd "UPDATE recordings SET status='recorded', temp_dir=NULL WHERE id=$recid;"
		rm -r "$pidir"
		if [ $CLEAN_FROM_MAIN -eq 1 ]; then
			#do_rt_idle ${srcbase}/rec24 clean_old "$confpath" >> "$LOGFILE"
			do_rt_idle ${srcbase}/clean_old.sh
		fi
		#echolog "`jobs`"
	) &
	previd=$recid
done

echolog "Main loop finished. Waiting for jobs..."
wait
echolog "Cleanup..."
rm -r "$TMPDIR"
echolog "Exiting. Thanks for using rec24!"

