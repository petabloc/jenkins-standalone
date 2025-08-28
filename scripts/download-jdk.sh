#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Get JDK configuration from versions.yml
if command -v yq >/dev/null 2>&1; then
    JDK_VERSION=$(yq eval '.jdk.version' "${PROJECT_DIR}/versions.yml")
    JDK_BUILD=$(yq eval '.jdk.build' "${PROJECT_DIR}/versions.yml")
    JDK_HASH=$(yq eval '.jdk.hash' "${PROJECT_DIR}/versions.yml")
else
    JDK_VERSION=$(grep -A10 "^jdk:" "${PROJECT_DIR}/versions.yml" | grep "version:" | sed 's/.*version: *"\([^"]*\)".*/\1/')
    JDK_BUILD=$(grep -A10 "^jdk:" "${PROJECT_DIR}/versions.yml" | grep "build:" | sed 's/.*build: *"\([^"]*\)".*/\1/')
    JDK_HASH=$(grep -A10 "^jdk:" "${PROJECT_DIR}/versions.yml" | grep "hash:" | sed 's/.*hash: *"\([^"]*\)".*/\1/')
fi

# Build URL directly
JDK_URL="https://download.java.net/java/GA/jdk${JDK_VERSION}/${JDK_HASH}/${JDK_BUILD}/GPL/openjdk-${JDK_VERSION}_linux-x64_bin.tar.gz"
JDK_TAR="openjdk-${JDK_VERSION}_linux-x64_bin.tar.gz"
JDK_DIR="jdk-${JDK_VERSION}"

echo "Downloading OpenJDK ${JDK_VERSION}..."
echo "URL: ${JDK_URL}"

# Download with error checking
if curl -L -f -o "${PROJECT_DIR}/tmp/${JDK_TAR}" "${JDK_URL}"; then
    echo "Extracting OpenJDK to lib directory..."
    cd "${PROJECT_DIR}/lib"
    tar -xzf "${PROJECT_DIR}/tmp/${JDK_TAR}"
    mv "${JDK_DIR}" "jdk"
    
    echo "Cleaning up temporary files..."
    rm "${PROJECT_DIR}/tmp/${JDK_TAR}"
    
    echo "OpenJDK ${JDK_VERSION} installed successfully"
else
    echo "ERROR: Failed to download OpenJDK ${JDK_VERSION}"
    exit 1
fi