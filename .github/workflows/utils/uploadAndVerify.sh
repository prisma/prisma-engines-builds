#!/bin/bash

set -eux;

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
aws s3 sync . $DESTINATION_TARGET_PATH --no-progress --exclude "*" --include "*.gz" --include "*.sha256" --include "*.sig"

cd "../$LOCAL_DIR_PATH"

echo "Downloading files..."
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

# Unpack all .gz files first
find . -type f | while read filename; do
    echo "Unpacking $filename file."
    gzip -d "$filename" --keep -q
done


# Verify .sha256 and .sig files
find . -type f | while read filename; do
    if [[ $filename == *.sha256 ]]; then
    echo "Validating sha256 sum."
    sha256sum -c "$filename"

    elif [[ $filename == *.sig ]]; then
        # Remove .sig from the file name
        fileToVerify=$(echo $filename | rev | cut -c5- | rev)

        echo "Validating signature $filename for $fileToVerify"
        gpg --verify "$filename" "$fileToVerify"
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