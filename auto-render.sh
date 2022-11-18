#!/bin/bash

eval "$(conda shell.bash hook)"
conda activate ffmpeg

function render {
	new_basename=$(basename $1) # | sed 's/.RPP//g')
	#/Applications/REAPER64.app/Contents/MacOS/REAPER -renderproject "$1"
	/Applications/REAPER.app/Contents/MacOS/REAPER -renderproject "$1" >> reaper.log 2>&1 # This gets rendered as 'Deep Socks.mp3' most of the time 
}

function is_this_render_new {
	my_flag="FALSE"
	filename=$(basename -- "$1")
	extension="${filename##*.}"
	just_filename=$(echo $filename | rev  | cut -d'.' -f2- | rev)
	filename_rendered_before=$(grep $just_filename /Users/pauldonovan/Tools/reaper-auto-render/FinishedProjects.txt | wc -l)
	if [ "$filename_rendered_before" -gt 0 ]; then
		my_flag="TRUE"
	fi
}

function find_render {
	echo "Looking for render for $1"
	my_render=$(find /Users/pauldonovan/Dropbox/Pauls_crap/ReaperMusic/ -type f -print0 | xargs -0 stat -f "%m %N" | sort -rn | grep -v ".DS_Store" | head -1 | cut -f2- -d" ")
	echo "Found file: $my_render"
}

function rename_and_convert_to_mp3 {
	if [[ "$1" == *"untitled"* ]]; then
		echo "Untitled track. Error likely occurred, moving on..."
	else
		#echo "New filename: $2.mp3"
		### ffmpeg trims empty space and forces mp3 format
		ffmpeg -y -f mp3 \
			-hide_banner -loglevel error \
		    -i "$1" \
			-af "silenceremove=start_periods=1:start_duration=1:start_threshold=-60dB:detection=peak,aformat=dblp,areverse,silenceremove=start_periods=1:start_duration=1:start_threshold=-60dB:detection=peak,aformat=dblp,areverse" \
			"/Users/pauldonovan/tools/reaper-auto-render/$2.mp3" >> ffmpeg.log 2>&1
		# Check if ffmpeg conversion to mp3 failed. If so, copy original file
		if [ $? -eq 0 ]; then
			echo "ffmpeg conversion successful"
			mv "/Users/pauldonovan/tools/reaper-auto-render/$2.mp3" "$destination/$2.mp3"
			echo "Moved file here: $destination/$2.mp3"
		else
			echo "ffmpeg conversion failed. Retrying using original file format"
			filename=$(basename -- "$1")
			extension="${filename##*.}"
			ffmpeg -y -f $extension \
				-hide_banner -loglevel error \
		    	-i "$1" \
				-af "silenceremove=start_periods=1:start_duration=1:start_threshold=-60dB:detection=peak,aformat=dblp,areverse,silenceremove=start_periods=1:start_duration=1:start_threshold=-60dB:detection=peak,aformat=dblp,areverse" \
				"/Users/pauldonovan/tools/reaper-auto-render/$2.$extension" >> ffmpeg.log 2>&1
			mv "/Users/pauldonovan/tools/reaper-auto-render/$2.$extension" "$destination/$2.$extension"
			rm /Users/pauldonovan/tools/reaper-auto-render/*.mp3
			echo "Moved file here: $destination/$2.$extension"
		fi
	fi
}


source="/Users/pauldonovan/Dropbox/Pauls_crap/ReaperMusic/"
destination="/Users/pauldonovan/Dropbox/Pauls_crap/ReaperMusic/Renders/BulkRenders/"

while getopts s:d:lap flag
do
    case "${flag}" in
        s) source=${OPTARG};;
        d) destination=${OPTARG};;
		a) projects="all" ;;
    esac
done

all_projects=""

for i in $(find $source -type f -name '*.RPP' | sort | uniq); do
	all_projects="$all_projects\n$i"
done

project_list=`echo -e "$all_projects"`

for line in $project_list
do
	echo -e "\nRendering: $line"
	real_filename=$(basename $line | sed 's/.RPP//g')
	render "$line"
	find_render "$line"
	is_this_render_new "$real_filename"
	if [ "$my_flag" == "TRUE" ]; then
		echo -e "This file was already generated, Reaper likely failed.\nSkipping this project..."
		continue
	fi
	rename_and_convert_to_mp3 "$my_render" "$real_filename"
	echo $real_filename >> /Users/pauldonovan/Tools/reaper-auto-render/FinishedProjects.txt
done
echo -e "\n"
