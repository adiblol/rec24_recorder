#!/bin/bash

store_flac_get_suffix() {
	echo ".flac"
}

store_flac_encode() {
	tmpf="$(gettemp)"
	(
		cat "$STORE_tagfile" | while read tagline; do echo "-T"; echo "$tagline"; done
		echo "--no-seektable
--padding=12000
--force-raw-format
--endian=little
--bps=$AUDIO_BITDEPTH
--sample-rate=$SAMPLERATE
--sign=signed
--channels=$AUDIO_CHANNELS
-o
$STORE_dest
-"
	) > "$tmpf"
	# --input-size=$STORE_size -- disabled to prevent decoding errors if file is not properly closed (in case of power outage etc)
	#do_rt_store cat "$STORE_fifo" | do_rt_store xargs -a "$tmpf" -d '\n' flac
	do_rt_store xargs -a "$tmpf" -d '\n' flac < "$STORE_fifo"
	rm "$tmpf"
}

store_flac_post() {
	do_rt_idle metaflac --remove-all-tags --add-seekpoint=10s --import-tags-from "$STORE_tagfile" "$STORE_dest"
}

