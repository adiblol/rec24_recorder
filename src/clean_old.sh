#!/bin/bash

origin_id=$(dbcmd "SELECT id FROM origins WHERE name='$ORIGIN_NAME';")

now=`date -u '+%s'`

if [ $DB_ENABLED -ne 1 ]; then
	echolog "Database disabled. (DB_ENABLED!=1) Falling back to _nodb cleaner."
	${srcbase}/clean_old_nodb.sh
	exit $?
fi

find "$STORECONF_DIR" -type f | while read storeconf; do
	. "$storeconf"
	echolog "Cleaning storage: $STORE_NAME"
	if [ "x$STORE_MAX_AGE" != "x" ]; then
		fid=$(dbcmd "SELECT id FROM formats WHERE name='$STORE_NAME';")
		mints=$[${now}-${STORE_MAX_AGE}]
		dbcmd "SELECT rec_files.id, rec_files.filename FROM recordings, rec_files WHERE rec_files.recording_id=recordings.id AND rec_files.format_id=$fid AND recordings.origin=$origin_id AND recordings.rec_end<FROM_UNIXTIME(${mints});" | while read id fn; do
			echolog "Deleting: $fn"
			rm "$fn" || [ ! -e "$fn" ] && dbcmd "DELETE FROM rec_files WHERE id=$id;"
		done
	else
		echo "STORE_MAX_AGE not configured in store config ${STORE_NAME}!"
	fi
	echolog "Removing empty directories..."
	find "$STORE_BASEDIR" -type d -empty -delete
	echolog "Done cleaning storage $STORE_NAME"
done

echolog "Removing entries without files..."
dbcmd "DELETE FROM recordings WHERE origin=$origin_id AND NOT EXISTS (SELECT id FROM rec_files WHERE rec_files.recording_id=recordings.id);"

