#!/bin/bash

store_null_get_suffix() {
	echo ''
}

store_null_encode() {
	cat "$STORE_fifo" > /dev/null
}

store_null_post() {
	cat /dev/null
}
