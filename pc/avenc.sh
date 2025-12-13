# Encode a file with ffmpeg

if test "$#" == 0 ; then
	echo "Usage: [V=1] [FPS=30] [VF_WIDE=1] [VC=264] [VQ=23] [AC=opus] [OUTDIR=...] [MPV=0] avenc.sh IN [OUT SEEK UNTIL]"
	exit 0
fi

if test "$V" == 1 ; then
	set -x
fi
set -e

IN="$1"
OUT=$2
SEEK=$3
UNTIL=$4

path_remove_ext__str() {
	echo "${1%.*}"
}

# get timestamp of the nearest keyframe before the time value
timestamp_nearest__file_time() {
	ffprobe \
		-read_intervals $2%$2 \
		-v error \
		-skip_frame nokey \
		-show_entries frame=pkt_pts_time \
		-select_streams v \
		-of csv=p=0 "$1"
}

if test "$SEEK" != "" ; then
	r=$(timestamp_nearest__file_time "$IN" $SEEK)
	if test "$r" != "" ; then
		SEEK=$r
	fi
	SEEK="-ss $SEEK"
fi

if test "$UNTIL" != "" ; then
	UNTIL="-to $UNTIL"
fi

FILTER=
VIDEO=

HWACCEL="-hwaccel vaapi "
# HWACCEL+="-hwaccel_output_format vaapi "
# -hwaccel_device /dev/dri/renderD128

if test "$VQ" == "" ; then
	VQ=23
fi

if test "$VC" == "copy" ; then
	VIDEO="copy"

elif test "$VC" == "gpu264" ; then
	VIDEO="h264_vaapi -profile:v high -level 42 -rc cqp -qp $VQ "

elif test "$VC" == "gpu265" ; then
	VIDEO="hevc_vaapi -profile:v main -quality quality -rc cqp -qp $VQ "

elif test "$VC" == "265" ; then
	VIDEO="libx265 -vtag hvc1 -crf $VQ -preset medium"

else
	VIDEO="libx264 -crf $VQ -preset slow -x264-params level=42"
fi

# -vf crop=y=72:h=430:x=14:w=700
# -vf scale=-1:720 => resize to x:720
#  -fpsmax 60
VIDEO="-c:v $VIDEO"


AUDIO="copy"
# -codec:a libfdk_aac -b:a 128k
# -ac 2
if test "$AC" == "opus" ; then
	AUDIO="libopus -b:a 128k"

elif test "$AC" == "opus256" ; then
	AUDIO="libopus -b:a 256k"
fi
AUDIO="-c:a $AUDIO"


# select video#0 & audio#2: -map 0:0 -map 0:2
# MAP="-map 0:0 -map 0:2"
# remove meta: -map_metadata -1
# SN=-sn
# SN="-scodec copy"

# delay video by 0.5
# FILTER+="$SEEK $UNTIL -itsoffset 0.5 -i $IN -map 1:v -map 0:a"

if test "$FPS" != "" ; then
	# FILTER+=" -r $FPS "
	FILTER+=" -filter:v fps=$FPS "
else
	FILTER+=" -vsync vfr "
fi

if test "$VF_WIDE" != "" ; then
	FILTER+=" -vf crop=y=132:h=816 "
fi


if test "$OUT" == "" ; then
	if test "$OUTDIR" != "" ; then
		OUT=$OUTDIR/
	fi
	OUT+=$(path_remove_ext__str "$IN")
	OUT+=_q$VQ
	OUT+=.mkv
fi


echo ffmpeg $HWACCEL $SEEK $UNTIL -i $IN $FILTER $VIDEO $AUDIO "$OUT"
ffmpeg $HWACCEL $SEEK $UNTIL -i "$IN" $FILTER $VIDEO $AUDIO "$OUT"


if test "$MPV" != "0" ; then
	mpv "$OUT" &
fi
