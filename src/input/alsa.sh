#!/bin/bash

input_alsa_capture() {
	do_rt_capture sox -S -V -r $SAMPLERATE -c $AUDIO_CHANNELS -t alsa $AUDIO_DEV -b $AUDIO_BITDEPTH -e signed-integer -c $AUDIO_CHANNELS --endian little -t raw "$1"
}
