#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Get Jenkins version from versions.yml
if command -v yq >/dev/null 2>&1; then
    JENKINS_VERSION=$(yq eval '.jenkins.version' "${PROJECT_DIR}/versions.yml")
else
    JENKINS_VERSION=$(grep -A5 "^jenkins:" "${PROJECT_DIR}/versions.yml" | grep "version:" | sed 's/.*version: *"\([^"]*\)".*/\1/')
fi

JENKINS_URL="https://get.jenkins.io/war-stable/${JENKINS_VERSION}/jenkins.war"
JENKINS_WAR="jenkins.war"

echo "Downloading Jenkins ${JENKINS_VERSION}..."
echo "URL: ${JENKINS_URL}"

# Download with verbose output and error checking
if curl -L -f -o "${PROJECT_DIR}/lib/${JENKINS_WAR}" "${JENKINS_URL}"; then
    # Verify the download
    if [ -s "${PROJECT_DIR}/lib/${JENKINS_WAR}" ]; then
        echo "Jenkins ${JENKINS_VERSION} downloaded successfully"
        echo "File size: $(du -h "${PROJECT_DIR}/lib/${JENKINS_WAR}" | cut -f1)"
    else
        echo "ERROR: Downloaded file is empty"
        exit 1
    fi
else
    echo "ERROR: Failed to download Jenkins ${JENKINS_VERSION}"
    exit 1
fi