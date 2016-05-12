#!/bin/bash


SUBSCRIPTION_KEY=""
DOWNLOAD_DIR="."
LOG_FILE="udger.log"
DATA_FORMAT="udgerdb_v3.dat"
DATA_FORMAT_SHA1="udgerdb_v3_dat.sha1"

CURL=$(which curl 2> /dev/null)
WGET=$(which wget 2> /dev/null)
DIFF="/usr/bin/diff"
DATE="/usr/bin/date"
RM="/usr/bin/rm"
LN="/usr/bin/ln"
GUNZIP="/usr/bin/gunzip"
BASENAME="/usr/bin/basename"
SHA1SUM="/usr/bin/sha1sum"


if [ ! -n "$SUBSCRIPTION_KEY" ] || [ ! -n "$DOWNLOAD_DIR" ] || [ ! -n "$LOG_FILE" ] || [ ! -n "$DATA_FORMAT" ] || [ ! -n "$DATA_FORMAT_SHA1" ] || [ ! -e $DIFF ] || [ ! -e $DATE ] || [ ! -e $RM ] || [ ! -e $LN ] || [ ! -e $LN ]; then
    echo "Please fill necessary information: Subscription key, download dir, log file, data format, data format sha1, path to diff, date, rm, ln and gunzip."
    exit 1
fi

SNAPSHOT_URL="http://data.udger.com/"$SUBSCRIPTION_KEY


touch $DOWNLOAD_DIR/version
/bin/mv $DOWNLOAD_DIR/version $DOWNLOAD_DIR/version.old

if [ "x$CURL" != "x" ]; then
    # Use cURL method
    echo "Updating via CURL"
    $CURL -sSfR -o "$DOWNLOAD_DIR/version" "$SNAPSHOT_URL/version"

elif [ "x$WGET" != "x" ]; then
    # Use wget method
    echo "Updating via WGET"
    $WGET -N -P "$DOWNLOAD_DIR" "$SNAPSHOT_URL/version"

else
    echo "No supported download method.  Please install 'curl' or 'wget'."
    echo `$DATE` " No supported download method.  Please install 'curl' or 'wget'." >> $LOG_FILE
    exit 2
fi


diff $DOWNLOAD_DIR/version $DOWNLOAD_DIR/version.old > /dev/null
if [ "$?" = "1" ]; then
    echo "Updating data"
    echo `$DATE` " Updating data" >> $LOG_FILE

    FILENAME=$DOWNLOAD_DIR/$DATA_FORMAT.$(head -n 1 $DOWNLOAD_DIR/version)
    FILENAME_SHA1=$DOWNLOAD_DIR/$DATA_FORMAT_SHA1.$(head -n 1 $DOWNLOAD_DIR/version)

    if [ "x$CURL" != "x" ]; then
        $CURL -sSfR -o "$FILENAME" "$SNAPSHOT_URL/$DATA_FORMAT"
        $CURL -sSfR -o "$FILENAME_SHA1" "$SNAPSHOT_URL/$DATA_FORMAT_SHA1"
    else
        $WGET -N -O "$FILENAME" "$SNAPSHOT_URL/$DATA_FORMAT"
        $WGET -N -O "$FILENAME_SHA1" "$SNAPSHOT_URL/$DATA_FORMAT_SHA1"
    fi

    if [[ $DATA_FORMAT =~ .*gz.* ]]; then
        $GUNZIP -c $FILENAME > $DOWNLOAD_DIR/`$BASENAME $DATA_FORMAT .gz`.$(head -n 1 $DOWNLOAD_DIR/version)
        $RM $FILENAME
    fi

    FILENAME=$DOWNLOAD_DIR/`$BASENAME $DATA_FORMAT .gz`.$(head -n 1 $DOWNLOAD_DIR/version)
    SHA1SUM_OUT=`$SHA1SUM $FILENAME`


    if [[ $SHA1SUM_OUT == *$(head -n 1 $FILENAME_SHA1)* ]]; then
	echo "sum is ok"
	$RM $DOWNLOAD_DIR/`$BASENAME $DATA_FORMAT .gz`
	$LN -s $DOWNLOAD_DIR/`$BASENAME $DATA_FORMAT .gz`.$(head -n 1 $DOWNLOAD_DIR/version) $DOWNLOAD_DIR/`$BASENAME $DATA_FORMAT .gz`
        echo "Data downloaded sucesfully"
        echo `$DATE` " Data downloaded sucesfully" >> $LOG_FILE
    else
	echo "Problem with checksum"
        echo `$DATE` " Problem with checksum" >> $LOG_FILE
	exit 1
    fi
else
    echo "Data are current"
    echo `$DATE` " Data are current" >> $LOG_FILE
    exit 1
fi