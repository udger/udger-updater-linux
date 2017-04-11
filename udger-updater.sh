#!/bin/bash

display_usage(){
    echo "$(basename "$0") [-h] [-d <string>] -k <string> -- download fresh udger-php data file"
    echo "";
    echo "where:"
    echo "    -k   Set subscription key"
    echo "    -d   Set download directory"
    echo "    -h   Show this help text"
}

SUBSCRIPTION_KEY=""
DOWNLOAD_DIR="."
DATA_FILE="udgerdb_v3.dat"
DATA_FILE_SHA1="udgerdb_v3_dat.sha1"

CURL=$(which curl 2> /dev/null)
WGET=$(which wget 2> /dev/null)
DIFF=$(which diff 2> /dev/null)
DATE=$(which date 2> /dev/null)
MV=$(which mv 2> /dev/null)
RM=$(which rm 2> /dev/null)
LN=$(which ln 2> /dev/null)
GUNZIP=$(which zip 2> /dev/null)
BASENAME=$(which basename 2> /dev/null)
SHA1SUM=$(which sha1sum 2> /dev/null)


if [ "$#" -lt 1 ]; then
    display_usage
    exit 1
fi

while getopts ":hk:d:" opt; do
  case $opt in
    k)
      SUBSCRIPTION_KEY=${OPTARG}
      ;;
    d)
      DOWNLOAD_DIR=${OPTARG}
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
    h | *) # Display help.
      display_usage
      exit 0
      ;;
  esac
done

VERSION_FILE=$DOWNLOAD_DIR/version
VERSION_FILE_TMP=$DOWNLOAD_DIR/version.tmp
SNAPSHOT_URL="https://data.udger.com/"$SUBSCRIPTION_KEY
VERSION_URL=$SNAPSHOT_URL/version

echo "";
echo "SUBSCRIPTION_KEY: "$SUBSCRIPTION_KEY;
echo "DOWNLOAD_DIR: "$DOWNLOAD_DIR;
echo "DATA_FILE: "$DATA_FILE;
echo "DATA_FILE_SHA1: "$DATA_FILE_SHA1;
echo "VERSION_FILE: "$VERSION_FILE;
echo "VERSION_FILE_TMP: "$VERSION_FILE_TMP;
echo "";

if [ ! -d "$DOWNLOAD_DIR" ]; then
    echo "Download direcory does not exist"
    exit 1;
fi

echo "Base URL: "$SNAPSHOT_URL

## download remote version file
if [ "x$CURL" != "x" ]; then
    echo "Updating via CURL"
    $CURL -sSfR -o "$VERSION_FILE_TMP" "$VERSION_URL"
    if [ $? -ne 0 ]; then { echo "CURL Failed, aborting: $VERSION_URL" ; exit 1; } fi

elif [ "x$WGET" != "x" ]; then
    echo "Updating via WGET"
    $WGET -N -P -O "$VERSION_FILE_TMP" "$VERSION_URL"
    if [ $? -ne 0 ]; then { echo "WGET Failed, aborting: $VERSION_URL" ; exit 1; } fi

else
    echo "Download failed. Please install 'curl' or 'wget'"
    exit 2
fi


## start file download and update versions
start_download(){
    FILENAME=$DOWNLOAD_DIR/$DATA_FILE.$(head -n 1 $VERSION_FILE_TMP)
    FILENAME_SHA1=$DOWNLOAD_DIR/$DATA_FILE_SHA1.$(head -n 1 $VERSION_FILE_TMP)

    if [ "x$CURL" != "x" ]; then
        $CURL -sSfR -o "$FILENAME" "$SNAPSHOT_URL/$DATA_FILE"
        $CURL -sSfR -o "$FILENAME_SHA1" "$SNAPSHOT_URL/$DATA_FILE_SHA1"
    else
        $WGET -N -O "$FILENAME" "$SNAPSHOT_URL/$DATA_FILE"
        $WGET -N -O "$FILENAME_SHA1" "$SNAPSHOT_URL/$DATA_FILE_SHA1"
    fi

    if [[ $DATA_FILE =~ .*gz.* ]]; then
        $GUNZIP -c $FILENAME > $DOWNLOAD_DIR/`$BASENAME $DATA_FILE .gz`.$(head -n 1 $VERSION_FILE_TMP)
        $RM $FILENAME
    fi

    FILENAME=$DOWNLOAD_DIR/`$BASENAME $DATA_FILE .gz`.$(head -n 1 $VERSION_FILE_TMP)
    SHA1SUM_OUT=`$SHA1SUM $FILENAME`


    if [[ $SHA1SUM_OUT == *$(head -n 1 $FILENAME_SHA1)* ]]; then
	echo "Checksum ok"
	$RM $DOWNLOAD_DIR/`$BASENAME $DATA_FILE .gz`
	$LN -s $DOWNLOAD_DIR/`$BASENAME $DATA_FILE .gz`.$(head -n 1 $VERSION_FILE_TMP) $DOWNLOAD_DIR/`$BASENAME $DATA_FILE .gz`
        echo "Data downloaded sucesfully: "$DATA_FILE
    else
	echo "Checksum mismatch"
	exit 1
    fi
}

## check version
if [ -f $VERSION_FILE ]; then
    ## compare the remote and local versions
    diff $VERSION_FILE_TMP $VERSION_FILE > /dev/null

    if [ "$?" = "1" ]; then
        echo "Different version available, start download" ## TODO: check if remote is really newer
        start_download
    else
        echo "Data file is up to date"
    fi
else
    echo "No previous version found, start download"
     start_download
fi

## Update version file
if [ -f $VERSION_FILE_TMP ]; then
    $MV $VERSION_FILE_TMP $VERSION_FILE;
fi


## Print version
if [ -f $VERSION_FILE ]; then
    echo "Current version is" `cat $VERSION_FILE`
else
    echo "No previous version found"
fi