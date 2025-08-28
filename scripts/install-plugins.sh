#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PLUGINS_DIR="${PROJECT_DIR}/plugins"
JENKINS_HOME="${PROJECT_DIR}/jenkins_home"
PLUGINS_CONFIG="${PROJECT_DIR}/plugins.txt"

echo "Installing additional plugins after Jenkins startup..."

# Function to check if Jenkins is running
check_jenkins() {
    local jenkins_pid="${PROJECT_DIR}/jenkins.pid"
    if [ -f "$jenkins_pid" ]; then
        local pid=$(cat "$jenkins_pid")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Function to wait for Jenkins to be ready
wait_for_jenkins() {
    echo "Waiting for Jenkins to be ready..."
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:8080 > /dev/null 2>&1; then
            echo "Jenkins is ready!"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts - Jenkins not ready yet..."
        sleep 5
        ((attempt++))
    done
    
    echo "ERROR: Jenkins did not become ready within 5 minutes"
    return 1
}

# Check if Jenkins is running
if ! check_jenkins; then
    echo "ERROR: Jenkins is not running. Please start Jenkins first with: ./bin/jenkins start"
    exit 1
fi

# Wait for Jenkins to be ready
if ! wait_for_jenkins; then
    exit 1
fi

# Check if plugins.txt exists
if [ ! -f "${PLUGINS_CONFIG}" ]; then
    echo "ERROR: plugins.txt configuration file not found at ${PLUGINS_CONFIG}"
    exit 1
fi

echo "Installing plugins from ${PLUGINS_CONFIG}..."

# Parse plugins.txt and copy plugins to Jenkins home
INSTALLED_COUNT=0

while IFS= read -r line; do
    # Skip empty lines and comments
    if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # Parse plugin:version format
    if [[ "$line" =~ ^([^:]+):([^[:space:]]+)[[:space:]]*$ ]]; then
        plugin_id="${BASH_REMATCH[1]}"
        plugin_file="${PLUGINS_DIR}/${plugin_id}.hpi"
        jenkins_plugin_file="${JENKINS_HOME}/plugins/${plugin_id}.hpi"
        
        if [ -f "$plugin_file" ]; then
            if [ ! -f "$jenkins_plugin_file" ]; then
                cp "$plugin_file" "$jenkins_plugin_file"
                echo "  Installed: $plugin_id"
                ((INSTALLED_COUNT++))
            else
                echo "  Already installed: $plugin_id"
            fi
        else
            echo "  WARNING: Plugin file not found: $plugin_file"
        fi
    fi
done < "${PLUGINS_CONFIG}"

echo ""
echo "Plugin installation summary:"
echo "  Newly installed: ${INSTALLED_COUNT}"

if [ ${INSTALLED_COUNT} -gt 0 ]; then
    echo ""
    echo "IMPORTANT: You need to restart Jenkins for the new plugins to take effect:"
    echo "  ./bin/jenkins restart"
fi

echo ""
echo "Plugin installation completed"