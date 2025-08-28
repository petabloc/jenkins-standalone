#!/bin/bash
# Note: Not using 'set -e' to allow individual plugin failures

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PLUGINS_DIR="${PROJECT_DIR}/plugins"
JENKINS_PLUGINS_URL="https://updates.jenkins.io/download/plugins"
PLUGINS_CONFIG="${PROJECT_DIR}/plugins.txt"

# Generate plugins.txt from versions.yml if it doesn't exist or is older
if [ ! -f "${PLUGINS_CONFIG}" ] || [ "${PROJECT_DIR}/versions.yml" -nt "${PLUGINS_CONFIG}" ]; then
    echo "Generating plugins.txt from versions.yml..."
    "${SCRIPT_DIR}/parse-versions.sh" plugins
fi

echo "Downloading Jenkins plugins..."

# Create plugins directory if it doesn't exist
mkdir -p "${PLUGINS_DIR}"

# Function to download a plugin with retry logic
download_plugin() {
    local plugin_id="$1"
    local version="$2"
    local filename="${plugin_id}.hpi"
    local url="${JENKINS_PLUGINS_URL}/${plugin_id}/${version}/${filename}"
    local output_path="${PLUGINS_DIR}/${filename}"
    
    echo "Downloading ${plugin_id}:${version}..."
    
    # Handle "latest" version directly
    if [ "$version" = "latest" ]; then
        local latest_url="${JENKINS_PLUGINS_URL}/${plugin_id}/latest/${filename}"
        if ! curl -L --fail -o "${output_path}" "${latest_url}" 2>/dev/null; then
            echo "  ERROR: Failed to download ${plugin_id} (latest)"
            return 1
        fi
    else
        # Try with specific version first, fallback to latest if version fails
        if ! curl -L --fail -o "${output_path}" "${url}" 2>/dev/null; then
            echo "  Version ${version} not found, trying latest..."
            local latest_url="${JENKINS_PLUGINS_URL}/${plugin_id}/latest/${filename}"
            if ! curl -L --fail -o "${output_path}" "${latest_url}" 2>/dev/null; then
                echo "  ERROR: Failed to download ${plugin_id}"
                return 1
            fi
        fi
    fi
    
    echo "  Downloaded ${plugin_id} successfully"
}

# Check if plugins.txt exists
if [ ! -f "${PLUGINS_CONFIG}" ]; then
    echo "ERROR: plugins.txt configuration file not found at ${PLUGINS_CONFIG}"
    exit 1
fi

echo "Reading plugin configuration from ${PLUGINS_CONFIG}..."

# Parse plugins.txt and download enabled plugins
FAILED_PLUGINS=()
SUCCESS_COUNT=0

while IFS= read -r line; do
    # Skip empty lines and comments
    if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # Parse plugin:version format
    if [[ "$line" =~ ^([^:]+):([^[:space:]]+)[[:space:]]*$ ]]; then
        plugin_id="${BASH_REMATCH[1]}"
        version="${BASH_REMATCH[2]}"
        
        if download_plugin "$plugin_id" "$version"; then
            ((SUCCESS_COUNT++))
        else
            FAILED_PLUGINS+=("$plugin_id:$version")
        fi
    else
        echo "  WARNING: Invalid plugin format: $line"
    fi
done < "${PLUGINS_CONFIG}"

echo ""
echo "Plugin download summary:"
echo "  Successful: ${SUCCESS_COUNT}"
echo "  Failed: ${#FAILED_PLUGINS[@]}"

if [ ${#FAILED_PLUGINS[@]} -gt 0 ]; then
    echo ""
    echo "Failed plugins:"
    for plugin in "${FAILED_PLUGINS[@]}"; do
        echo "  - $plugin"
    done
    echo ""
    echo "WARNING: Some plugins failed to download. The build will continue."
    echo "You may need to install these plugins manually after Jenkins starts."
fi

echo ""
echo "Jenkins plugins download completed"
echo "Total plugins in directory: $(ls -1 "${PLUGINS_DIR}"/*.hpi 2>/dev/null | wc -l)"

# Always exit successfully - plugin failures shouldn't break the build
exit 0