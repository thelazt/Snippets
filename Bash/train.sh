#!/bin/bash

#DESTINATION="Britomart"

TRAINSTATIONCACHE_DEF="/tmp/trainstation"
LINK="https://at.govt.nz/bus-train-ferry/real-time-board/"
AGENT="Mozilla/5.0 (Windows; U; Windows NT 5.1; de; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3"

HOUR=1
SLEEP=0

function help() {
	echo
	echo -e "\e[1mGet a live time table for Auckland trains\e[0m"
	echo
	echo    "  Usage: "
	echo    "	$0 Station [Destination] [Options]"
	echo
	echo 	 "  Options:"
	echo    "	-u[SEC]     Update the table every 30 seconds"
	echo    "	            (or, if specified, every SEC seconds)"
	echo    "	-hHOUR      Print the timetable for the next HOUR hours"
	echo    "	-c[FILE]    Cache the station file (if no FILE given, then use"
	echo    "	            default: $TRAINSTATIONCACHE_DEF)"
	echo
	echo -e "\e[2m  written 2015 by Benhard Heinloth <bernhard@heinloth.net>  \e[0m"
	echo
}
	
for var in "$@" ; do
	case "$var" in
		-u* )
			SLEEP=30
			if [[ "${var:2}"  =~ ^[0-9]+$ ]] ; then
				SLEEP=${var:2}
			fi
			;;
		-h* )
			if [[ "${var:2}"  =~ ^[0-9]+$ ]] ; then
				HOUR=${var:2}
			fi
			;;
		-c* )
			TRAINSTATIONCACHE=$TRAINSTATIONCACHE_DEF
			if [[ -z "${var:2}" ]] ; then
				TRAINSTATIONCACHE="${var:2}" 
			fi
			;;
		-\? )
			help
			exit 0
			;;
		* )
			if [[ -z "$STATION" ]] ; then
				STATION="$var"
			elif [[ -z "$DESTINATION" ]] ; then
				# Multiple destinations possible, please seperate by comma or space (or something else)
				DESTINATION="$var"
			fi
			;;
	esac
done

if [[ -z "$STATION" ]] ; then
	help
	exit 1
fi

echo -en "\e[2mPlease wait while fetching ${STATION}s timetable for the next $HOUR hour(s)...\e[0m"

TMPDATA=$(mktemp)

curl -A "$AGENT" "$LINK" 2>/dev/null | tr '\n' ' ' > $TMPDATA

MAINSCRIPTURL=$(cat "$TMPDATA" | sed -e "s/^.*<script src=.\([A-Za-z0-9.\/]*\/scripts\/main.js\).>.*$/https:\1/")

if [[ -z "$TRAINSTATIONCACHE" || ! -f "$TRAINSTATIONCACHE" ]] ; then
	if [[ -z "$TRAINSTATIONCACHE" ]] ; then
		TRAINSTATIONCACHE=$TMPDATA
	fi
	DBSCRIPTURL=$(cat "$TMPDATA" | sed -e "s/^.*<script src=.\([A-Za-z0-9.\/]*departureboard[A-Za-z0-9.\/]*\/bootstrap.js\).>.*$/https:\1/")

	curl -A "$AGENT" --referer "$LINK" "$DBSCRIPTURL" 2>/dev/null |  tr "\n" " " > $TMPDATA

	DBMAINSCRIPTURL=$(cat "$TMPDATA" | sed -e "s/^.*app:.\([A-Za-z0-9.\/]*\).*$/https:\1\/main.js/")

	curl -A "$AGENT" --referer "$LINK" "$DBMAINSCRIPTURL" 2>/dev/null |  tr "\n" " " > "$TRAINSTATIONCACHE"
fi

STATIONNR=$(cat "$TRAINSTATIONCACHE" | sed -e "s/^.*{number:\([0-9]*\),name:\"[^\"]*$STATION[^\"]*\"}.*$/\1/I" )

curl -A "$AGENT" --referer "$LINK" "$MAINSCRIPTURL" 2>/dev/null |  tr "\n" " " > $TMPDATA

KEY=$(cat "$TMPDATA" | sed -e 's/^.*key:"\([^"]*\)".*$/\1/')
SECRET=$(cat "$TMPDATA" | sed -e 's/^.*secret:"\([^"]*\)".*$/\1/')

rm "$TMPDATA"

echo -e "\r\033[K\n\e[1m\t  Live Train Time Table\e[0m\n\t=========================\n"

while true; do 
	TIMESTAMP=$(date +%s)

	APISIG=$(echo -n "$TIMESTAMP$KEY" | openssl sha1 -hmac "$SECRET" | sed -e "s/^.*= //")

	JSONURL="https://api.at.govt.nz/v1/public-restricted/departures/${STATIONNR}?api_key=${KEY}&api_sig=${APISIG}&callback=jQuery1820390620679827407_1430261893096&hours=$HOUR&rowCount=4&isMobile=false&mobileRowCount=10&_=${TIMESTAMP}000"

	JSON="$(curl -A "$AGENT" --referer "$LINK" "$JSONURL"  2>/dev/null | sed -e 's/^.*\[\({.*}\)\].*$/},\1\,{/;s/},{/\n/g' | sort )"
	echo "$JSON" > tmp
	NUMBER=0   
	IFS=$'\n'  
	for entry in $JSON ; do
		declare -A item
		IFS=$','
		for line in $entry ; do
			key=$(echo "$line" | sed -e 's/"\([^"]*\)":.*$/\1/' )
			value=$(echo "$line" | sed -e 's/^.*":"*\([^"]*\)"*$/\1/' )

			if [[ ( $key == *"Time" || $key == "timestamp" ) && $value != "null" ]] ; then
				value=$(date -d "$(echo "$value" | sed -e 's/[+Z].*$//;s/T/ /') GMT" +%s)
			fi
			item[$key]=$value
		done
		if [[ -z "$DESTINATION" || ${DESTINATION^^} == *"${item[destinationDisplay]}"* ]] ; then
			if [[ "${item[inCongestion]}" != "false" ]] ; then
				echo -en "\e[31m"
			fi
			if [[ "${item[monitored]}" == "false" ]] ; then
				echo -en "\e[2m"
			fi
			NUMBER=$((NUMBER +1 ))
				dest="${item[destinationDisplay],,}";
				echo -en "$NUMBER. Route ${item[route_short_name]} from ${STATION^}/${item[departurePlatformName]}\t to ${dest^}/${item[arrivalPlatformName]}\t boarding at $(date -d @${item[scheduledArrivalTime]} +%H:%M)"
			if [[ "${item[expectedArrivalTime]}" != "null" ]] ; then
				diff=$(( ( ${item[expectedArrivalTime]} - ${item[scheduledArrivalTime]} ) / 60 ));
				if [[ "$diff" -eq "0" ]] ; then
					echo -en " \e[1m (in time)"
				else
					if (( $diff > 0 )) ; then
						diff=$"\e[31m+$diff"
					fi
					echo -en " \e[1m ${diff} min\t ($(date -d @${item[expectedArrivalTime]} +%H:%M))"
				fi
			fi
			echo -e "\e[0m\033[K"
		fi
		IFS=$'\n'
	done
	if [[ -z "$SLEEP" || "$SLEEP" -eq "0" ]] ; then
		exit 0
	else
		echo -e "\n\033[K\t\e[2m(last update: $(date +%H:%M:%S))\e[0m\033[K"
		sleep $SLEEP
		echo -en "\r\033[K\033[$(( $NUMBER + 2))A"
	fi
done
