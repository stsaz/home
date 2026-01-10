if test "$V" == 1 ; then
	set -x
fi

if test "$#" -lt 3 ; then
	echo "Usage: [EXT=mkv] [OUTDIR=.] [EXEC=0] [VDELAY=0.3] avcopy.sh FILE SFX SEEK [UNTIL]"
	exit 0
fi

path_remove_ext__str() {
	echo "${1%.*}"
}

IN="$1"
SFX=$2
if test "$OUTDIR" == "" ; then
	OUTDIR=.
fi

if test "$EXT" == "" ; then
	EXT=mkv
fi
name=$(basename "$IN")
name=$(path_remove_ext__str "$name")
OUT="$OUTDIR/$name-$SFX.$EXT"

# octal -> decimal
dec_oct__n() {
	local n=$1
	if test $n == 08 ; then
		n=8
	elif test $n == 09 ; then
		n=9
	fi
	echo $n
}

# hh:mm:ss -> ssss
time_sec__t() {
	local sec=$(echo $1 | awk -F : '{print $3}')
	local min=$(echo $1 | awk -F : '{print $2}')
	local hour=$(echo $1 | awk -F : '{print $1}')
	sec=$(dec_oct__n $sec)
	min=$(dec_oct__n $min)
	echo $((hour * 3600 + min * 60 + sec))
}

time_subtract__t_by() {
	# hh:mm:ss.msc
	local msec=$(echo $1 | awk -F . '{print $2}')
	local t=$(echo $1 | awk -F . '{print $1}')
	local sec=$(time_sec__t $t)
	if test $sec -lt $2 ; then
		sec=0
	else
		sec=$((sec - $2))
	fi
	echo $sec.$msec
}

# get timestamp of the nearest keyframe before the time value
timestamp_nearest__file_time() {
	ffprobe \
		-read_intervals $(time_subtract__t_by $2 6)%$2 \
		-v error \
		-skip_frame nokey \
		-show_entries frame=pts_time \
		-select_streams v \
		-of csv=p=0 "$1" \
		| tail -n 1
}

if test "$SEEK" != "" ; then
	r=$(timestamp_nearest__file_time "$IN" $SEEK)
	if test "$r" != "" ; then
		SEEK=$r
	fi
	SEEK="-ss $SEEK"
fi

UNTIL=''
if test "$4" != "" ; then
	UNTIL="-to $4"
fi

# delay video by X seconds
FILTER=
if test "$VDELAY" != "" ; then
	FILTER+="$SEEK $UNTIL -itsoffset $VDELAY -i $IN -map 1:v -map 0:a"
fi

VIDEO="-c:v copy"
AUDIO="-c:a copy"
SUBS="-scodec copy"

echo ffmpeg $SEEK $UNTIL -i "$IN" $FILTER $VIDEO $AUDIO $SUBS -y "$OUT"
ffmpeg -v warning $SEEK $UNTIL -i "$IN" $FILTER $VIDEO $AUDIO $SUBS -y "$OUT"

if test "$EXEC" != "" ; then
	xdg-open "$OUT"
fi
