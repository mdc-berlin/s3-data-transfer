#!/bin/bash
# version: 1.0

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

# load config
set -a
source $1
set +a

# preparing environment
envsubst < rclone.config.sample > ~/.config/rclone/rclone.conf
date > test.txt

controlbucket="$producer-$tenant-controlbucket"
databucket="$producer-$tenant-databucket"

echo "running tests ..."

# testing controlbucket
## list
files=$(rclone ls --fast-list $controlbucket:$controlbucket 2> /dev/null  | wc -l)
if [ $? -eq 0 ]
then
  echo "controlbucket - listing successfull, number of files: $files"
else
  echo -e "controlbucket -\033[1;31m error listing bucket \033[0m"
fi

# write
rclone copy test.txt $controlbucket:$controlbucket 2> /dev/null 
if [ $? -eq 0 ]
then
  echo "controlbucket - writing successfull"
else
  echo -e "controlbucket -\033[1;31m error writing file \033[0m"
fi

# read
rclone cat $controlbucket:$controlbucket/test.txt 2> /dev/null > /dev/null
if [ $? -eq 0 ]
then
  echo "controlbucket - reading successfull"
else
  echo -e "controlbucket -\033[1;31m error reading file \033[0m"
fi


# testing databucket
## list
files=$(rclone ls --fast-list $databucket:$databucket 2> /dev/null | wc -l)
if [ $? -eq 0 ]
then
  echo "databucket - listing successfull, number of files: $files"
else
  echo -e "databucket -\033[1;31m error listing bucket\033[0m"
fi

# write
rclone copy test.txt $databucket:$databucket 2> /dev/null 
if [ $? -eq 0 ]
then
  echo "databucket - writing successfull"
else
  echo -e "databucket -\033[1;33m error writing file - maybe you have only read permissions\033[0m"
fi

# read
rclone cat $databucket:$databucket/test.txt 2> /dev/null > /dev/null
if [ $? -eq 0 ]
then
  echo "databucket - reading successfull"
else
  echo -e "databucket -\033[1;31m error reading file\033[0m"
fi
