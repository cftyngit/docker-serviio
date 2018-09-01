#!/bin/bash

old_qsv=0

# store arguments in a special array 
args=("$@") 
# get number of elements 
ELEMENTS=${#args[@]} 
 
# echo each element in array  
# for loop 
for (( i=0;i<$ELEMENTS;i++)); do 
	if [ "${args[${i}]}" = "-c:v" ]; then
		j=$((i+1))
		if [ "${args[${j}]}" = "h264_qsv" ]; then
			old_qsv=1
			break
		fi
	fi
done


if [ "${old_qsv}" = "1" ]; then
	shift $ELEMENTS
	for (( i=0;i<$ELEMENTS;i++)); do
		if [ "${args[${i}]}" = "-c:v" ]; then
			j=$((i+1))
			if [ "${args[${j}]}" = "h264_qsv" ]; then
				args[${j}]="h264_vaapi"
			fi
		fi
		if [ "${args[${i}]}" = "-filter_complex" ]; then
			j=$((i+1))
			args[${j}]=`echo ${args[${j}]} | sed -n "s/^\(\[.*\]\)subtitles\(.*\)\(\[.*\]\)$/\1hwmap,format=nv12,subtitles\2,hwmap,format=vaapi\3/p"`
		fi
		set -- "$@" "${args[${i}]}"
	done
	echo "ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi \"$@\"" >> /tmp/run_command
	ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi "$@"
else
	ffmpeg "$@"	
fi

exit $?
