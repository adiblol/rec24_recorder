#!/bin/bash

echo 'Deleting entries for non-existing files...'
dbcmd 'SELECT id, filename FROM rec_files;' | while read id fn; do
	if [ ! -e "$fn" ]; then
		echo "Deleting: $fn" >&2
		dbcmd "DELETE FROM rec_files WHERE id=$id;"
	fi
done
