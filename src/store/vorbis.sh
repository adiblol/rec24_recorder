#!/bin/bash

store_vorbis_get_suffix() {
	echo ".ogg"
}

store_vorbis_encode() {
	(
		cat "$STORE_tagfile" | while read tagline; do echo "-c"; echo "$tagline"; done
		echo "--raw
--raw-bits=$AUDIO_BITDEPTH
--raw-chan=$AUDIO_CHANNELS
--raw-rate=$SAMPLERATE
--raw-endianness=0
--skeleton
--quiet
-q
$STORE_QUALITY
-o
$STORE_dest
$STORE_fifo"
	) | do_rt_store xargs -d '\n' oggenc
}

store_vorbis_post() {
	do_rt_idle vorbiscomment -c "$STORE_tagfile" -w "$STORE_dest"
}
