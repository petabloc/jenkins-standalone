#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building Jenkins Standalone Package..."

# Create necessary directories
mkdir -p tmp lib plugins logs

# Download all components
echo "Downloading Java JDK..."
./scripts/download-jdk.sh

echo "Downloading Jenkins WAR..."
./scripts/download-jenkins.sh

echo "Downloading Jenkins plugins..."
./scripts/download-plugins.sh

# Note: Plugins will be installed during Jenkins setup wizard
echo "Plugins downloaded and ready for installation during setup wizard"
echo "Available plugins: $(ls plugins/*.hpi 2>/dev/null | wc -l || echo 0)"

# Create the distribution package
PACKAGE_NAME="jenkins-standalone-$(date +%Y%m%d-%H%M%S)"
PACKAGE_DIR="dist/${PACKAGE_NAME}"

echo "Creating distribution package: ${PACKAGE_NAME}"
mkdir -p "dist"

# Create package directory structure
mkdir -p "${PACKAGE_DIR}"

# Copy all necessary files and directories
cp -r bin "${PACKAGE_DIR}/"
cp -r conf "${PACKAGE_DIR}/"
cp -r lib "${PACKAGE_DIR}/"
mkdir -p "${PACKAGE_DIR}/logs"
cp README.md "${PACKAGE_DIR}/"
cp SECURITY.md "${PACKAGE_DIR}/"
cp plugins.txt "${PACKAGE_DIR}/"
cp versions.yml "${PACKAGE_DIR}/"
cp -r scripts "${PACKAGE_DIR}/"

# Create the tarball
cd dist
tar -czf "${PACKAGE_NAME}.tar.gz" "${PACKAGE_NAME}"

echo "Package created: dist/${PACKAGE_NAME}.tar.gz"

# Cleanup
cd ..
rm -rf "dist/${PACKAGE_NAME}"
rm -rf tmp

echo "Build completed successfully!"
echo "Package size: $(du -sh "dist/${PACKAGE_NAME}.tar.gz" | cut -f1)"