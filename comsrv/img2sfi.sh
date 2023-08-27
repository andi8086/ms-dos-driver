#!/bin/bash

[ -z "$1" ] && { echo "Syntax: $0 raw.img [out.sfi]"; exit -1; }

if [ -z "$2" ]; then
        OUTNAME="$(basename $1)"
        OUTNAME="${OUTNAME%%.*}"
        OUTNAME="${OUTNAME}.sfi"
else
        OUTNAME="$2"
fi

[ -f "$1" ] || { echo "File not found"; exit -1; }

echo "Converting $1 to ${OUTNAME}"
SIZE=$(stat -c "%s" $1)
echo "Image size is "$SIZE

size160=$((40*1*8*512)); size160_msg="160k, CHS=40/1/8"
size320=$((40*2*8*512)); size320_msg="320k, CHS=40/2/8"
size180=$((40*1*9*512)); size180_msg="180k, CHS=40/1/9"
size360=$((40*2*9*512)); size360_msg="360k, CHS=40/2/9"
size1200=$((80*2*15*512)); size1200_msg="1200k, CHS=80/2/15"
size720=$((80*2*9*512)); size720_msg="720k, CHS=80/2/9"
size1440=$((80*2*18*512)); size1440_msg="1440k, CHS=80/2/18"

headerfile=$(mktemp ./header.XXXXXX)
echo "Temporary header file: ${headerfile}"

param=0

case $SIZE in
${size160})
        echo $size160_msg
        param=1
        ;;
${size320})
        echo $size320_msg
        param=2
        ;;
${size180})
        echo $size180_msg
        param=3
        ;;
${size360})
        echo $size360_msg
        param=4
        ;;
${size1200})
        echo $size1200_msg
        param=5
        ;;
${size720})
        echo $size720_msg
        param=6 
        ;;
${size1440})
        echo $size1440_msg
        param=7 
        ;;
*)
        echo "Image size not supported"
        echo "Supported sizes: "
        echo $size160, $size160_msg 
        echo $size180, $size180_msg
        echo $size320, $size320_msg
        echo $size360, $size360_msg
        echo $size720, $size720_msg
        echo $size1200, $size1200_msg
        echo $size1440, $size1440_msg
        rm -f ${headerfile}
        exit -1
esac

./cfh ${headerfile} $param

hexdump -C ${headerfile}

cat ${headerfile} $1 > ${OUTNAME}

rm -f ${headerfile}

echo "${OUTNAME} is ready."
