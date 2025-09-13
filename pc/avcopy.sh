# set -x

if test "$#" -lt 3 ; then
	echo "Usage: [EXT=mkv] [OUTDIR=/tmp] [MPV=1] avcopy.sh FILE SFX SEEK [UNTIL]"
	exit 0
fi

IN="./$1"

NAME="${1%.*}"
SFX=$2
if test "$OUTDIR" == "" ; then
	OUTDIR=/tmp
fi

if test "$EXT" == "" ; then
	EXT=mkv
fi
OUT="$OUTDIR/$NAME-$SFX.$EXT"

nearest_keyframe__fn_pos() {
	local FN=$1
	local POS=$2
	# get timestamp of the nearest keyframe before the POS value
	RESULT=`ffprobe -read_intervals $POS%$POS -v error -skip_frame nokey -show_entries frame=pkt_pts_time -select_streams v -of csv=p=0 "$FN"`
	if test "$RESULT" == "" ; then
		RESULT=$POS
	fi
}

RESULT=''
nearest_keyframe__fn_pos "$IN" $3
SEEK="-ss $RESULT"

UNTIL=''
if test "$4" != "" ; then
	UNTIL="-to $4"
fi

VIDEO="-c:v copy"
AUDIO="-c:a copy"
SUBS="-scodec copy"

echo ffmpeg $SEEK $UNTIL -i "$IN" $VIDEO $AUDIO $SUBS -y "$OUT"
ffmpeg -v warning $SEEK $UNTIL -i "$IN" $VIDEO $AUDIO $SUBS -y "$OUT"

if test "$MPV" != "0" ; then
	mpv "$OUT"
fi
