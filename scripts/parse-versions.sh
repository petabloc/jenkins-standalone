#!/bin/bash
set -e

# Script to parse versions.yml and export environment variables
# This provides a centralized way to read version configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="${PROJECT_DIR}/versions.yml"

# Check if yq is available, otherwise use basic parsing
parse_yaml() {
    local file="$1"
    local prefix="$2"
    
    if command -v yq >/dev/null 2>&1; then
        # Use yq if available (more reliable)
        case "$prefix" in
            "JDK")
                export JDK_VERSION=$(yq eval '.jdk.version' "$file")
                export JDK_BUILD=$(yq eval '.jdk.build' "$file")
                export JDK_HASH=$(yq eval '.jdk.hash' "$file")
                export JDK_URL_TEMPLATE=$(yq eval '.jdk.url_template' "$file")
                ;;
            "JENKINS")
                export JENKINS_VERSION=$(yq eval '.jenkins.version' "$file")
                export JENKINS_URL_TEMPLATE=$(yq eval '.jenkins.url_template' "$file")
                ;;
            *)
                echo "Unknown prefix: $prefix"
                return 1
                ;;
        esac
    else
        # Fallback to basic grep/sed parsing
        case "$prefix" in
            "JDK")
                export JDK_VERSION=$(grep "version:" "$file" | head -1 | sed 's/.*version: *"\([^"]*\)".*/\1/')
                export JDK_BUILD=$(grep "build:" "$file" | head -1 | sed 's/.*build: *"\([^"]*\)".*/\1/')
                export JDK_HASH=$(grep "hash:" "$file" | head -1 | sed 's/.*hash: *"\([^"]*\)".*/\1/')
                export JDK_URL_TEMPLATE=$(grep "url_template:" "$file" | head -1 | sed 's/.*url_template: *"\([^"]*\)".*/\1/')
                ;;
            "JENKINS")
                export JENKINS_VERSION=$(sed -n '/^jenkins:/,/^[a-zA-Z]/p' "$file" | grep "version:" | sed 's/.*version: *"\([^"]*\)".*/\1/')
                export JENKINS_URL_TEMPLATE=$(sed -n '/^jenkins:/,/^[a-zA-Z]/p' "$file" | grep "url_template:" | sed 's/.*url_template: *"\([^"]*\)".*/\1/')
                ;;
            *)
                echo "Unknown prefix: $prefix"
                return 1
                ;;
        esac
    fi
}

# Parse plugin versions and create plugins.txt
generate_plugins_txt() {
    local output_file="${PROJECT_DIR}/plugins.txt"
    local temp_file="${output_file}.tmp"
    
    echo "# Jenkins Plugin Configuration" > "$temp_file"
    echo "# Generated from versions.yml on $(date)" >> "$temp_file"
    echo "#" >> "$temp_file"
    echo "# Core plugins essential for Jenkins functionality" >> "$temp_file"
    
    if command -v yq >/dev/null 2>&1; then
        # Use yq to extract plugin versions
        yq eval '.plugins | to_entries | .[] | .key + ":" + .value.version' "$VERSIONS_FILE" >> "$temp_file"
    else
        # Fallback: extract plugin versions with grep/sed
        sed -n '/^plugins:/,/^[a-zA-Z]/p' "$VERSIONS_FILE" | \
        grep -E "^\s+[a-zA-Z0-9-]+:" | \
        while IFS= read -r line; do
            plugin_name=$(echo "$line" | sed 's/^\s*\([^:]*\):.*/\1/')
            version=$(sed -n "/^\s*${plugin_name}:/,/^\s*[a-zA-Z]/p" "$VERSIONS_FILE" | grep "version:" | head -1 | sed 's/.*version: *"\([^"]*\)".*/\1/')
            if [ -n "$version" ]; then
                echo "${plugin_name}:${version}" >> "$temp_file"
            fi
        done
    fi
    
    mv "$temp_file" "$output_file"
    echo "Generated plugins.txt from versions.yml"
}

# Function to get plugin version from versions.yml
get_plugin_version() {
    local plugin_name="$1"
    if command -v yq >/dev/null 2>&1; then
        yq eval ".plugins.${plugin_name}.version" "$VERSIONS_FILE" 2>/dev/null
    else
        sed -n "/^\s*${plugin_name}:/,/^\s*[a-zA-Z]/p" "$VERSIONS_FILE" | grep "version:" | head -1 | sed 's/.*version: *"\([^"]*\)".*/\1/'
    fi
}

# Function to check if versions.yml exists and is readable
check_versions_file() {
    if [ ! -f "$VERSIONS_FILE" ]; then
        echo "ERROR: versions.yml not found at $VERSIONS_FILE"
        return 1
    fi
    
    if [ ! -r "$VERSIONS_FILE" ]; then
        echo "ERROR: Cannot read versions.yml at $VERSIONS_FILE"
        return 1
    fi
    
    return 0
}

# Main execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Script is being executed directly
    case "${1:-help}" in
        "jdk")
            check_versions_file && parse_yaml "$VERSIONS_FILE" "JDK"
            echo "JDK_VERSION=$JDK_VERSION"
            echo "JDK_BUILD=$JDK_BUILD"
            echo "JDK_HASH=$JDK_HASH"
            echo "JDK_URL_TEMPLATE=$JDK_URL_TEMPLATE"
            ;;
        "jenkins")
            check_versions_file && parse_yaml "$VERSIONS_FILE" "JENKINS"
            echo "JENKINS_VERSION=$JENKINS_VERSION"
            echo "JENKINS_URL_TEMPLATE=$JENKINS_URL_TEMPLATE"
            ;;
        "plugins")
            check_versions_file && generate_plugins_txt
            ;;
        "plugin")
            if [ -z "$2" ]; then
                echo "Usage: $0 plugin <plugin-name>"
                exit 1
            fi
            check_versions_file
            version=$(get_plugin_version "$2")
            echo "${2}:${version}"
            ;;
        "help")
            echo "Usage: $0 {jdk|jenkins|plugins|plugin <name>|help}"
            echo ""
            echo "Commands:"
            echo "  jdk        - Export JDK version variables"
            echo "  jenkins    - Export Jenkins version variables"  
            echo "  plugins    - Generate plugins.txt from versions.yml"
            echo "  plugin <n> - Get version for specific plugin"
            echo "  help       - Show this help message"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
else
    # Script is being sourced - make functions available
    check_versions_file
fi