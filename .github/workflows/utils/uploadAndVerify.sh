#!/bin/bash

set -eux

mkdir engines-artifacts-from-r2 engines-artifacts-from-s3

cd engines-artifacts

echo "Upload to R2"
aws s3 sync . $DESTINATION_TARGET_PATH --exclude "*" --include "*.gz" --include "*.sha256" --include "*.sig"

cd ../engines-artifacts-from-r2

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
find . -type f -name "*.gz" -exec sh -c '
    
    echo "Unpacking .gz file."
    gzip -d "$1" --keep -q

' sh {} \;

# Verify .sha256 and .sig files
find . -type f -exec sh -c '
    
    if [[ $1 == *.sha256 ]]; then
        echo "Validating sha256 sum."
        sha256sum -c "$1"
    fi
    
    if [[ $1 == *.sig ]]; then
        # Remove .sig from the file name
        fileToVerify=$(echo $1 | rev | cut -c5- | rev)

        echo "Validating signature $1 for $fileToVerify"
        gpg --verify "$1" "$fileToVerify"
    fi

' sh {} \;

