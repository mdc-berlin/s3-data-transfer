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

pidfile=/var/run/upload-data-to-s3
if [ -f $pidfile ]
then
  pid=$(cat $pidfile)
  echo "another upload process is already running (pid: $pid)"
  exit
else
  echo $$ > $pidfile
fi

# load config
set -a
source $1
set +a

# create temporary folder
mkdir $temppath/workflow-progress-temp 2> /dev/null

# create rclone config folder
mkdir -p ~/.config/rclone 2> /dev/null

# place config
envsubst < rclone.config.sample > ~/.config/rclone/rclone.conf

echo "scanning for $marker in $sourcepath with max depth of $maxdepth ..."
for workflowfile in $(find $sourcepath -maxdepth $maxdepth -type f -name $marker)
do
  # setting variables
  dataset=$(dirname $workflowfile)
  datasethash=($(echo $dataset | md5sum))
  databucket="$producer-$tenant-databucket"
  controlbucket="$producer-$tenant-controlbucket"
  echo $workflowfile
  du -sh $(dirname $workflowfile)

  # workflow-progress.txt update -> created (if not existant)
  if ! grep -q "created" "$workflowfile"; then
    echo "created timestamp not found ... setting timestamp"
    echo "created=$(date +%Y-%m-%d-%H:%M:%S)" >> $workflowfile
  else
    echo "created timestamp found -> skipping"
  fi

  # workflow-progress.txt update -> uploading -> uploaded
  if ! grep -q "uploaded" "$workflowfile"; then  
    echo "uploading=$(date +%Y-%m-%d-%H:%M:%S)" >> $workflowfile

    echo "summing up data in the workflow path: $dataset ..."
    du -sh $dataset
    
    # uploading
    echo "uploading ..."
    rclone sync --transfers=32 --check-first --fast-list --checksum --progress $dataset $databucket:$databucket/$datasethash
    if [ $? -eq 0 ]
    then
      echo "uploaded=$(date +%Y-%m-%d-%H:%M:%S)" >> $workflowfile

      # notify via controlbucket
      echo "$dataset" > $temppath/workflow-progress-temp/$datasethash
      echo "uploaded=$(date +%Y-%m-%d-%H:%M:%S)" >> $temppath/workflow-progress-temp/$datasethash
      rclone sync --checksum  $temppath/workflow-progress-temp/$datasethash $controlbucket:$controlbucket/
    else
      echo "something failed ... retrying next time"
    fi
  else
    echo "dataset already uploaded -> skipping"
  fi

  # workflow-progress.txt update -> downloaded
  if rclone cat $controlbucket:$controlbucket/$datasethash | grep -q .; then
    if rclone cat $controlbucket:$controlbucket/$datasethash | grep -q downloaded; then
      echo "dataset has been downloaded by $tenant ..."
      echo "downloaded=$(date +%Y-%m-%d-%H:%M:%S)" >> $workflowfile
    else
      echo "dataset has not been downloaded by $tenant yet ..."
    fi
  fi

  # workflow-progress.txt update -> deleted
  if grep -q "downloaded" "$workflowfile"; then
    if ! grep -q "deleted" "$workflowfile"; then
      echo "deleting files from databucket"
      rclone delete $databucket:$databucket/$datasethash
      echo "deleting files from controlbucket"
      rclone delete $controlbucket:$controlbucket/$datasethash
      echo "deleted=$(date +%Y-%m-%d-%H:%M:%S)" >> $workflowfile
    else
      echo "deleted timestamp found -> skipping"
    fi
  fi

  echo ""
done

rm -f $pidfile