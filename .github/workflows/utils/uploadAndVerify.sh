#!/bin/bash

set -eux;

# engines-artifacts-from-r2
# engines-artifacts-from-s3
LOCAL_DIR_PATH=$1

if [ -z "$LOCAL_DIR_PATH" ]; then
    echo "::error::LOCAL_DIR_PATH is not set."
    exit 1
fi

echo "Upload to R2"
cd engines-artifacts
aws s3 sync . $DESTINATION_TARGET_PATH --no-progress \
    --exclude "*" \
    --include "*.gz" \
    --include "*.zip" \
    --include "*.sha256" \
    --include "*.sig"
cd ".."

echo "Downloading files..."
mkdir $LOCAL_DIR_PATH
cd $LOCAL_DIR_PATH
aws s3 sync $DESTINATION_TARGET_PATH . --no-progress

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

# Manual check
# 
# Set PROD env vars
# mkdir engines-artifacts-from-prod
# Download the artifacts from the S3 bucket
# aws s3 sync s3://prisma-builds/all_commits/6f3b8db04fa234ab2812fdd27456e9d9590eedb1 engines-artifacts-from-prod/
# Print the files and save the output to a file
# cd engines-artifacts-from-prod
# find . | sort > ../expectedFiles.txt
# 
# cd ..
# 
# Set DEV env vars
# mkdir engines-artifacts-from-dev
# Download the artifacts from the S3 bucket
# aws s3 sync s3://prisma-builds-github-actions/all_commits/6f3b8db04fa234ab2812fdd27456e9d9590eedb1 engines-artifacts-from-dev/
# Print the files and save the output to a file
# cd engines-artifacts-from-dev
# find . | sort > ../currentFiles.txt

# Automated check
# expectedFiles.txt is in the same directory as this script

echo "Create list of files"
find . | sort > ../currentFiles.txt
cd ..
echo "Comparing expectedFiles.txt vs currentFiles.txt"
diff -c .github/workflows/utils/expectedFiles.txt currentFiles.txt
cd $LOCAL_DIR_PATH

# Unpack all .gz files first
find . -type f | while read filename; do
    echo "Unpacking $filename file."
    gzip -d "$filename" --keep -q
done

# Verify .sha256 files
find . -type f -name "*.sha256" | while read filename; do
    echo "Validating sha256 sum."
    sha256sum -c "$filename"
done

# Verify .sig files
find . -type f -name "*.sig" | while read filename; do
    # Remove .sig from the file name
    fileToVerify=$(echo $filename | rev | cut -c5- | rev)

    echo "Validating signature $filename for $fileToVerify"
    gpg --verify "$filename" "$fileToVerify"
done

echo "Validating OpenSSL linking."
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "::error::Mac OS does not have ldd command."
    exit 1
fi

FILES_TO_VALIDATE_WITH_LDD=$(find . -type f | grep -E "./rhel-openssl-(3.0|1.1).*(query-engine|schema-engine|libquery_engine.so.node)$")
echo "FILES_TO_VALIDATE_WITH_LDD: $FILES_TO_VALIDATE_WITH_LDD"

echo $FILES_TO_VALIDATE_WITH_LDD | while read filename; do
    GREP_OUTPUT=$(ldd "$filename"| grep "libssl")
    echo "GREP_OUTPUT: $GREP_OUTPUT"
    OUTPUT=$(echo "$GREP_OUTPUT" | cut -f2 | cut -d'.' -f1) 

    if [[ "$OUTPUT" == "libssl" ]]; then
        echo "$OUTPUT"
        echo "Linux build linked correctly to libssl."
    else
        echo "Linux build linked incorrectly to libssl."
        exit 1
    fi
done

echo "Upload .finished marker file"
touch .finished
aws s3 cp .finished "$DESTINATION_TARGET_PATH/.finished"
rm .finished


# TODO
# s!("-e"), format!("VALIDATE_LDD_OUTPUT={}", if binary.should_validate_ldd(target) { "y" } else { "n" }),
# if [[ "$VALIDATE_LDD_OUTPUT" == "y" ]]; then
#     echo "Validating SSL linking."
#     OUTPUT=$(ldd "$BINARY_NAME"| grep "libssl" | cut -f2 | cut -d'.' -f1)

#     if [[ "$OUTPUT" == "libssl" ]]; then
#         echo "Linux build linked correctly to libssl."
#     else
#         echo "Linux build linked incorrectly to libssl."
#         exit 1
#     fi
# else
#     echo "Skipping libssl link validation."
# fi


# let binary_name = match binary.artifact_type() {
#     ArtifactType::Bin => config.with_binary_file_ext(binary),
#     ArtifactType::Lib => config.with_node_api_file_ext(binary),
#     ArtifactType::Archive => binary.as_ref().to_owned(),
# };

# #[rustfmt::skip]
# let docker_opts = vec![
#     s!("run"),
#     s!("-w"), s!("/check"),
#     s!("-v"), format!("{}:/root/keys/prisma-gpg-private.asc", key_file_path),
#     s!("-v"), format!("{}:/check", sub_check_folder.to_str().unwrap()),
#     s!("-e"), format!("BINARY_NAME={}", binary_name),
#     s!("-e"), format!("BUCKET_PATH={}", bucket_path.path_segments),
#     s!("-e"), format!("CHECK_DOMAIN_NAME={}", destination.check_domain_name()),
#     s!("-e"), format!("OS={}", target),
#     s!("-e"), format!("VALIDATE_LDD_OUTPUT={}", if binary.should_validate_ldd(target) { "y" } else { "n" }),
#     s!("-e"), s!("KEY_PATH=/root/keys/prisma-gpg-private.asc"),
#     s!("-e"), format!("KEY_PASS={}", key_pass),
#     s!("-e"), format!("GZIPPED={}", if binary.needs_gz_compression() { "y" } else { "n" }),
#     s!("prismagraphql/build:release"),
#     s!("/check/validate.sh"),
# ];