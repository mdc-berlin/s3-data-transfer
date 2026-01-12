#!/bin/bash
# status: created -> uploading -> uploaded -> downloading -> downloaded
# version: 1.1

if [ ! $1 ]
then
  echo "no config specified"
  echo "use: $0 /path/to/config.cfg"
  exit
fi

if [ ! $(which rclone) ]
then
  echo "please install rclone"
  exit
fi

pidfile=/var/run/download-data-from-s3
if [ -f $pidfile ]
then
  pid=$(cat $pidfile)
  echo "another download process is already running"
  exit
else
  echo $$ > $pidfile
fi

# load config
set -a
source $1
set +a

# create temporary folder
mkdir -p $temppath/workflow-progress-download/controldata 2> /dev/null

# create rclone config folder
mkdir -p ~/.config/rclone 2> /dev/null

# place config
envsubst < rclone.config.sample > ~/.config/rclone/rclone.conf

controlbucket="$producer-$tenant-controlbucket"
databucket="$producer-$tenant-databucket"

rclone sync --checksum  $controlbucket:$controlbucket/ $temppath/workflow-progress-download/controldata

for controldatafile in $(find $temppath/workflow-progress-download/controldata -type f)
do
  echo $controldatafile
  datasethash=$(basename $controldatafile)
  if ! grep -q "downloaded" "$controldatafile"; then
    echo "downloading ..."
    rclone sync --transfers=32 --check-first --fast-list --checksum --progress $databucket:$databucket/$datasethash $destinationpath/$datasethash
    if [ $? -eq 0 ]
    then
      echo "downloaded=$(date +%Y-%m-%d-%H:%M:%S)" >> $controldatafile
      rclone sync --checksum  $controldatafile $controlbucket:$controlbucket/
    else
      echo "something failed ... retrying next time"
    fi
  else
    echo "dataset already downloaded"
  fi
done

rm -f $pidfile
