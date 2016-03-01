#!/bin/bash

# RSCK -- RecordingS ChecK - like FSCK but for recordings database
# Mainly useful for repairing records interrupted due to power outage

if [ $DB_ENABLED != 1 ]; then
	echolog "database disabled -- rsck aborting!"
	exit
fi

origin_id=$(dbcmd "SELECT id FROM origins WHERE name='$ORIGIN_NAME';")

dbcmd "DELETE FROM recordings WHERE origin=$origin_id AND NOT EXISTS (SELECT id FROM rec_files WHERE rec_files.recording_id=recordings.id);"

dbcmd "SELECT id, UNIX_TIMESTAMP(rec_start), temp_dir FROM recordings WHERE origin=$origin_id AND temp_dir IS NOT NULL;" | while read id ts_start dir; do
	if [ ! -e "$dir" ]; then
		echolog "`date -u -d "@$ts_start" '+%Y-%m-%d %H:%M:%S'` UTC seems to have finished being recorded. Estimating end time."
		ts_lastmod=$(dbcmd "SELECT filename FROM rec_files WHERE recording_id=$id" | while read fn; do
			stat -c '%Y' "$fn" && break
		done)
		if [ -n "$ts_lastmod" ]; then
			dbcmd "UPDATE recordings SET temp_dir=NULL, status='recorded', rec_end=FROM_UNIXTIME($ts_lastmod) WHERE id=$id;"
			echolog "End time for $id: `date -u -d "@$ts_lastmod" '+%Y-%m-%d %H:%M:%S'` UTC"
		else
			echolog "Warning: cannot determinate last modification time for id=$id"
		fi
	else
		echolog "`date -u -d "@$ts_start" '+%Y-%m-%d %H:%M:%S'` UTC is probably still being recorded, not touching it."
	fi
done
