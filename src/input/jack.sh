#!/bin/bash

input_jack_capture() {
	portsdef=
	for port in $INPUT_PORTS; do
		portsdef="${portsdef} -p ${port}"
	done
	do_rt_capture jack_capture --no-stdin -f raw -b $AUDIO_BITDEPTH -c $AUDIO_CHANNELS $portsdef "$1"
}
