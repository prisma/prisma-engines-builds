#!/bin/bash

set -eux;

# full command
command="docker run \
-e SQLITE_MAX_VARIABLE_NUMBER=250000 \
-e SQLITE_MAX_EXPR_DEPTH=10000 \
-e LIBZ_SYS_STATIC=1 \
-w /root/build \
-v \"$(pwd)\":/root/build \
$IMAGE \
bash -c \
    \" \
    cargo clean \
    && cargo build --release -p query-engine          --manifest-path query-engine/query-engine/Cargo.toml          $TARGET_STRING $FEATURES_STRING \
    && cargo build --release -p query-engine-node-api --manifest-path query-engine/query-engine-node-api/Cargo.toml $TARGET_STRING $FEATURES_STRING \
    && cargo build --release -p schema-engine-cli     --manifest-path schema-engine/cli/Cargo.toml                  $TARGET_STRING $FEATURES_STRING \
    && cargo build --release -p prisma-fmt            --manifest-path prisma-fmt/Cargo.toml                         $TARGET_STRING $FEATURES_STRING \
    \" \
"
# remove query-engine-node-api for "static" targets
if [[ "$TARGET_NAME" == *-static-* ]]; then
    substring_to_replace="&& cargo build --release -p query-engine-node-api --manifest-path query-engine/query-engine-node-api/Cargo.toml $TARGET_STRING $FEATURES_STRING"
    replacement_string=""
    command=$(echo "$command" | sed "s|$substring_to_replace|$replacement_string|")
fi


# store command in GitHub output
echo "COMMAND=$command" >> "$GITHUB_OUTPUT"
