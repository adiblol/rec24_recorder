
dbcmd() {
	if [ $DB_ENABLED -eq 1 ]; then
		mysql --defaults-extra-file="$DB_CONFIG" -ss -e "$1"
	fi
}

gettemp() {
	mktemp --tmpdir="$TMPDIR"
}

echolog() {
	echo "`date '+%Y-%m-%d %H:%M:%S'` `basename "$0" .sh`: $*" | tee -a "$LOGFILE" >&2
}

