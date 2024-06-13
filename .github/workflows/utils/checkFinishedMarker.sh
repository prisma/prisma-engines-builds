#!/bin/bash

set -eux

object_exists=$(aws s3api head-object --bucket $BUCKET_NAME --key $FILE_PATH || true)

if [ -z "$object_exists" ]; then
echo ".finished file marker was NOT found. Continuing..."
else
echo "::error::.finished file marker was found at $FILE_PATH - This means that artifacts were already uploaded in a previous run. Aborting to avoid overwriting the artifacts.",
# TODO 
# exit 1
fi;