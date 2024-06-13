#!/bin/bash

set -eux

# engines-artifacts-from-r2
# engines-artifacts-from-s3
LOCAL_DIR_PATH=$1

if [ -z "$LOCAL_DIR_PATH" ]; then
    echo "::error::LOCAL_DIR_PATH is not set."
    exit 1
fi

mkdir $LOCAL_DIR_PATH

cd engines-artifacts

echo "Upload to R2"
aws s3 sync . $DESTINATION_TARGET_PATH --exclude "*" --include "*.gz" --include "*.sha256" --include "*.sig"

cd "../$LOCAL_DIR_PATH"

echo "Downloading files..."
aws s3 sync $DESTINATION_TARGET_PATH .

echo "Verifing downloaded files..."
ls -R .

FILECOUNT_FOR_SHA256=$(find . -type f -name "*.sha256" | wc -l)
if [ "$FILECOUNT_FOR_SHA256" -eq 0 ]; then
    echo "::error::No .sha256 files found."
    exit 1
fi

FILECOUNT_FOR_GZ=$(find . -type f -name "*.gz" | wc -l)
if [ "$FILECOUNT_FOR_GZ" -eq 0 ]; then
    echo "::error::No .gz files found."
    exit 1
fi

FILECOUNT_FOR_SIG=$(find . -type f -name "*.sig" | wc -l)
if [ "$FILECOUNT_FOR_SIG" -eq 0 ]; then
    echo "::error::No .sig files found."
    exit 1
fi

# Unpack all .gz files first
find . -type f -print0 | xargs -0I {} sh -c '
    echo "Unpacking {} file."
    gzip -d "{}" --keep -q
';

# Verify .sha256 and .sig files
find . -type f -print0 | xargs -0I {} sh -c '
    if [[ {} == *.sha256 ]]; then
        echo "Validating sha256 sum."
        sha256sum -c "{}"

    elif [[ {} == *.sig ]]; then
        # Remove .sig from the file name
        fileToVerify=$(echo {} | rev | cut -c5- | rev)

        echo "Validating signature {} for $fileToVerify"
        gpg --verify "{}" "$fileToVerify"
    fi
';

echo "Upload .finished marker file"
touch .finished
aws s3 cp .finished "$DESTINATION_TARGET_PATH/.finished"
rm .finished
