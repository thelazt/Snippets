#!/bin/bash
# Auckland Live Train Time Table
# as seen on https://at.govt.nz/bus-train-ferry/real-time-board/
#
# What's this?
#   A time table for the next departure at aucklands train stations with
#   current live delays.
# What it is not:
#   NO journey planer! Destiniation just filters directions by listing the
#   terminal station.
# Motivation
#   Unlike most Kiwis, I really like the public transport. Well, I admit it,
#   not when the train is 30 minutes behind the schedule while I arrived on
#   time at the train station (like yesterday evening). Since I just need
#   less than five minutes to the station, accurate departure times might
#   be really helpful for my workaday life.
#   And after having a look into the source of the auckland transport website,
#   with all the pseudo security, it was pure pleasure to write this script!
# Why the fuck in Bash?
#   The auckland transport site uses to much javascript - and is far to
#   "funky" (according to my personal taste). I just want easy and fast
#   access to the the required information - especially, when I am in
#   a hurry (and, in contrast to a browser, a console is always available).
#
# written 2015 by Benhard Heinloth <bernhard@heinloth.net>


# default cache prefix
CACHEPREFIX_DEF="/tmp/bashaucklandtraintable"

# Entry page
LINK="https://at.govt.nz/bus-train-ferry/real-time-board/"
# fake user agent
AGENT="Mozilla/5.0 (Windows; U; Windows NT 5.1; de; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3"

# default hour size of the departure board
HOUR=2
# set update timer to zero
SLEEP=0

# Print usage information
function help() {
	echo
	echo -e "\e[1mGet a live time table for Auckland trains\e[0m"
	echo
	echo -e "  \e[4mUsage:\e[0m"
	echo -e "	$0 Station \e[2m[Destination] [Options]\e[0m"
	echo
	echo    "	Station     Departure station, offical Name"
	echo -e "	Destination (optional) could be one or more \e[1mterminal\e[0m stations"
	echo
	echo -e "  \e[4mOptions (optional):\e[0m"
	echo -e "	-u\e[2m[SEC]\e[0m     Update the table every 30 seconds"
	echo -e "	            \e[2m(or, if specified, every SEC seconds)\e[0m"
	echo    "	-hHOUR      Print the timetable for the next HOUR hours"
	echo -e "	-c\e[2m[PREFIX]\e[0m  Cache the static web files \e[2m(if no PREFIX given, then use"
	echo -e "	            default: $CACHEPREFIX_DEF)\e[0m"
	echo
	echo -e "\e[2m    \e[0m"
	echo
}

# Parse command line arguments
for var in "$@" ; do
	case "$var" in
		# update interval
		-u* )
			# default: 30s
			SLEEP=30
			# or custom
			if [[ "${var:2}"  =~ ^[0-9]+$ ]] ; then
				SLEEP=${var:2}
			fi
			;;
		# set the (hour) size of the board
		-h* )
			if [[ "${var:2}"  =~ ^[0-9]+$ ]] ; then
				HOUR=${var:2}
			fi
			;;
		# cache the static results
		-c* )
			CACHEPREFIX=$CACHEPREFIX_DEF
			if [[ -n "${var:2}" ]] ; then
				CACHEPREFIX="${var:2}" 
			fi
			;;
		# help messages
		-\? )
			help
			exit 0
			;;
		# non-option parameter
		* )
			# first set station...
			if [[ -z "$STATION" ]] ; then
				STATION="$var"
			# then destination
			elif [[ -z "$DESTINATION" ]] ; then
				# Multiple destinations possible, please seperate by comma or space (or something else)
				DESTINATION="$var"
			fi
			;;
	esac
done

# Check if departure station is defined
if [[ -z "$STATION" ]] ; then
	echo -e "\n\e[31mNo departure station specified!\e[0m"
	help
	exit 1
fi

echo -en "\e[2mPlease wait while fetching ${STATION}s timetable for the next $HOUR hour(s)."

# Generate temporary/permanent cache files
if [[ -z "$CACHEPREFIX" ]] ; then
	TRAINSTATIONCACHE="$(mktemp)"
	APISCRIPTCACHE="$(mktemp)"
else
	TRAINSTATIONCACHE="$CACHEPREFIX.trainstation"
	APISCRIPTCACHE="$CACHEPREFIX.main"
fi

# Check if we need to download the static data
if [[ -z "$CACHEPREFIX" || ! -f "$TRAINSTATIONCACHE" || ! -f "$APISCRIPTCACHE" ]] ; then
	# Retrieve index page to temporary file
	INDEXCACHE="$(mktemp)"
	curl -A "$AGENT" "$LINK" 2>/dev/null | tr '\n' ' ' > "$INDEXCACHE"
	echo -n "."

	# Fetch new API data
	if [[ -z "$CACHEPREFIX" || ! -f "$APISCRIPTCACHE" ]] ; then
		# Read URL and receive auckland transport websites main javascript file
		APISCRIPTURL=$(cat "$INDEXCACHE" | sed -e "s/^.*<script src=.\([A-Za-z0-9.\/]*\/scripts\/main.js\).>.*$/https:\1/")
		curl -A "$AGENT" --referer "$LINK" "$APISCRIPTURL" 2>/dev/null |  tr "\n" " " > $APISCRIPTCACHE
		echo -n "."
	fi

	# Fetch new train station number list
	if [[ -z "$CACHEPREFIX" || ! -f "$TRAINSTATIONCACHE" ]] ; then
		# Read URL and retrieve content of bootstrap javascript file
		DBSCRIPTURL=$(cat "$INDEXCACHE" | sed -e "s/^.*<script src=.\([A-Za-z0-9.\/]*departureboard[A-Za-z0-9.\/]*\/bootstrap.js\).>.*$/https:\1/")
		curl -A "$AGENT" --referer "$LINK" "$DBSCRIPTURL" 2>/dev/null |  tr "\n" " " > "$TRAINSTATIONCACHE"
		echo -n "."

		# Read URL and retrieve depature boards java script file
		DBMAINSCRIPTURL=$(cat "$TRAINSTATIONCACHE" | sed -e "s/^.*app:.\([A-Za-z0-9.\/]*\).*$/https:\1\/main.js/")
		curl -A "$AGENT" --referer "$LINK" "$DBMAINSCRIPTURL" 2>/dev/null |  tr "\n" " " > "$TRAINSTATIONCACHE"
		echo -n "."
	fi

	# remove temporary index file
	rm "$INDEXCACHE"
fi

# Fetch station number
STATIONNR=$(cat "$TRAINSTATIONCACHE" | sed -e "s/^.*{number:\([0-9]*\),name:\"[^\"]*$STATION[^\"]*\"}.*$/\1/I" )
# validate number
if [[ ! "$STATIONNR"  =~ ^[0-9]+$ ]] ; then
	echo -e "\e[0m\r\e[K\e[31mCould not get a valid station number for '$STATION'...\e[0m"
	exit 1
fi

# Fetch API data
APIKEY=$(cat "$APISCRIPTCACHE" | sed -e 's/^.*key:"\([^"]*\)".*$/\1/' )
APISECRET=$(cat "$APISCRIPTCACHE" | sed -e 's/^.*secret:"\([^"]*\)".*$/\1/' )
# validate API data
if [[ ! "$APIKEY$APISECRET"  =~ ^[0-9a-z]+$ ]] ; then
	echo -e "\e[0m\r\e[K\e[31mCould not retrieve valid API data...\e[0m"
	exit 1
fi

# Remove temporary cache files
if [[ -z "$CACHEPREFIX" ]] ; then
	rm "$TRAINSTATIONCACHE"
	rm "$APISCRIPTCACHE"
fi

# print title
echo -e "\r\033[K\n\e[4m\e[1m\t Auckland Live Train Time Table \e[0m\n"

while true; do 
	# generate API signature based on current timestamp using keyed-hash message authentication code
	TIMESTAMP=$(date +%s)
	APISIG=$(echo -n "$TIMESTAMP$APIKEY" | openssl sha1 -hmac "$APISECRET" | sed -e "s/^.*= //")

	# retriev the live train data in JSON format
	JSON="$(curl -A "$AGENT" --referer "$LINK" "https://api.at.govt.nz/v1/public-restricted/departures/${STATIONNR}?api_key=${APIKEY}&api_sig=${APISIG}&callback=jQuery1820390620679827407_1430261893096&hours=$HOUR&rowCount=4&isMobile=false&mobileRowCount=10&_=${TIMESTAMP}000"  2>/dev/null | sed -e 's/^.*\[\({.*}\)\].*$/},\1\,{/;s/},{/\n/g' | sort )"

	# Counter for entries
	NUMBER=0
	# iterate live data entry sets
	IFS=$'\n'
	for entry in $JSON ; do

		# copy json data into associative array
		declare -A item

		# iterate flat key-value map of entry
		IFS=$','
		for line in $entry ; do

			# extract key and value
			key=$(echo "$line" | sed -e 's/"\([^"]*\)":.*$/\1/' )
			value=$(echo "$line" | sed -e 's/^.*":"*\([^"]*\)"*$/\1/' )

			# convert time strings into unix timestamps
			if [[ ( $key == *"Time" || $key == "timestamp" ) && $value != "null" ]] ; then
				value=$(date -d "$(echo "$value" | sed -e 's/[+Z].*$//;s/T/ /') GMT" +%s)
			fi

			# put into array
			item[$key]=$value
		done

		# check if this data should be displayed
		if [[ -n "${item[expectedArrivalTime]}" && ( -z "$DESTINATION" || ${DESTINATION^^} == *"${item[destinationDisplay]}"* ) ]] ; then
			# default color
			color=0

			# Perhaps theres no tracking available...
			if [[ "${item[monitored]}" == "false" ]] ; then
				color=2
			fi

			# official congestion?
			if [[ "${item[inCongestion]}" != "false" ]] ; then
				color=31
			fi

			# calculate time specification addition
			timespec=""
			if [[ "${item[expectedArrivalTime]}" != "null" ]] ; then
				diff=$(( ( ${item[expectedArrivalTime]} - ${item[scheduledArrivalTime]} ) / 60 ));
				if [[ "$diff" -eq "0" ]] ; then
					timespec=" \e[32m (in time)"
				else
					if (( $diff > 0 )) ; then
						diff=$"\e[31m+$diff"
					fi
					timespec=" \e[1m ${diff} min\t ($(date -d @${item[expectedArrivalTime]} +%H:%M))"
				fi
			fi

			# Print entry line
			NUMBER=$((NUMBER +1 ))
			dest="${item[destinationDisplay],,}";
			route="${item[route_short_name],,}";
			echo -en "\e[${color}m$NUMBER. Route \e[1m${route^}\e[0;${color}m from \e[1m${STATION^}\e[0;${color}m/${item[departurePlatformName]}\t to \e[1m${dest^}\e[${color}m/${item[arrivalPlatformName]}\t boarding at \e[1m$(date -d @${item[scheduledArrivalTime]} +%H:%M)\e[0;${color}m$timespec\e[0m\e[K"
		fi

		# Restore input format seperator
		IFS=$'\n'
	done

	# no entry? print warning
	if [[ "$NUMBER" -eq "0" ]] ; then
		echo -e "\e[33mCurrently no data for your request available...\e[0m"
	fi

	# if not in update mode -> exit
	if [[ -z "$SLEEP" || "$SLEEP" -eq "0" ]] ; then
		exit 0
	# or print update time, wait, and redraw everything
	else
		echo -e "\n\e[K\t\e[2m(last update: $(date +%H:%M:%S))\e[0m\e[K"
		sleep $SLEEP
		echo -en "\r\e[K\e[$(( $NUMBER + 2))A"
	fi
done
