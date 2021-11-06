#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2015-2020 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
# Modified in November 2021 by Charlie Floquet 

exec < <(exec wg show all dump)

printf '{'
while read -r -d $'\t' device; do
	if [[ $device != "$last_device" ]]; then
		[[ -z $last_device ]] && printf '' || printf '%s,' "$end"
		last_device="$device"
		read -r private_key public_key listen_port fwmark
		printf '"%s": {' "$device"
		delim=$''
		[[ $public_key == "(none)" ]] || { printf '%s"publicKey": "%s"' "$delim" "$public_key"; delim=$','; }
		[[ $listen_port == "0" ]] || { printf '%s"listenPort": %u' "$delim" $(( $listen_port )); delim=$','; }
		[[ $fwmark == "off" ]] || { printf '%s"fwmark": %u' "$delim" $(( $fwmark )); delim=$','; }
		printf '%s"peers": {' "$delim"; end=$'}}'
		delim=$''
	else
		read -r public_key preshared_key endpoint allowed_ips latest_handshake transfer_rx transfer_tx persistent_keepalive
		printf '%s"%s": {' "$delim" "$public_key"
		delim=$''
		[[ $endpoint == "(none)" ]] || { printf '%s"endpoint": "%s"' "$delim" "$endpoint"; delim=$','; }
		[[ $latest_handshake == "0" ]] || { printf '%s"latestHandshake": %u' "$delim" $(( $latest_handshake )); delim=$','; }
		[[ $transfer_rx == "0" ]] || { printf '%s"transferRx": %u' "$delim" $(( $transfer_rx )); delim=$','; }
		[[ $transfer_tx == "0" ]] || { printf '%s"transferTx": %u' "$delim" $(( $transfer_tx )); delim=$','; }
		[[ $persistent_keepalive == "off" ]] || { printf '%s"persistentKeepalive": %u' "$delim" $(( $persistent_keepalive )); delim=$','; }
		printf '%s"allowedIps": [' "$delim"
		delim=$''
		if [[ $allowed_ips != "(none)" ]]; then
			old_ifs="$IFS"
			IFS=,
			for ip in $allowed_ips; do
				printf '%s"%s"' "$delim" "$ip"
				delim=$','
			done
			IFS="$old_ifs"
			delim=$''
		fi
		printf '%s]' "$delim"
		printf '}'
		delim=$','
	fi
done
printf '%s' "$end"
printf '}'
