#!/bin/bash

input_alsa_capture() {
	verboseflag=
	if [ "$CAPTURE_VERBOSE" == "1" ]; then
		verboseflag="-S"
	fi
	do_rt_capture sox $verboseflag -V -r $SAMPLERATE -c $AUDIO_CHANNELS -t alsa $AUDIO_DEV -b $AUDIO_BITDEPTH -e signed-integer -c $AUDIO_CHANNELS --endian little -t raw "$1"
}
