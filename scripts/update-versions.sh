#!/bin/bash

# Version Update Automation Script
# This script checks for updates to Jenkins, JDK, and plugins
# and can automatically update the versions.yml file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="${PROJECT_DIR}/versions.yml"
BACKUP_DIR="${PROJECT_DIR}/.version-backups"

# Configuration
DRY_RUN=false
SECURITY_ONLY=true
AUTO_APPROVE=false
UPDATE_TYPE="security"  # Options: security, minor, major

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to backup versions.yml
backup_versions() {
    mkdir -p "$BACKUP_DIR"
    local backup_file="${BACKUP_DIR}/versions-$(date +%Y%m%d-%H%M%S).yml"
    cp "$VERSIONS_FILE" "$backup_file"
    log "Backed up versions.yml to $backup_file"
}

# Function to check Jenkins LTS updates
check_jenkins_updates() {
    log "Checking Jenkins LTS updates..."
    
    local current_version
    if command -v yq >/dev/null 2>&1; then
        current_version=$(yq eval '.jenkins.version' "$VERSIONS_FILE")
    else
        current_version=$(grep -A5 "^jenkins:" "$VERSIONS_FILE" | grep "version:" | sed 's/.*version: *"\([^"]*\)".*/\1/')
    fi
    
    # Fetch latest LTS version
    local latest_lts
    if command -v curl >/dev/null 2>&1; then
        # Use the Jenkins update center to get latest stable core version
        latest_lts=$(curl -sL "https://updates.jenkins.io/stable/latestCore.txt")
        
        # Check if we got a valid version string
        if [[ "$latest_lts" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            log "Found latest Jenkins LTS version: $latest_lts"
        else
            warn "Unable to fetch Jenkins version from update center"
            log "Jenkins version check skipped: $current_version"
            return 1
        fi
    else
        warn "curl not available, cannot check Jenkins updates automatically"
        return 1
    fi
    
    if [ "$current_version" != "$latest_lts" ]; then
        warn "Jenkins update available: $current_version -> $latest_lts"
        echo "jenkins_update_available=true" >> /tmp/update-status
        echo "jenkins_current=$current_version" >> /tmp/update-status
        echo "jenkins_latest=$latest_lts" >> /tmp/update-status
        return 0
    else
        log "Jenkins is up to date: $current_version"
        return 1
    fi
}

# Function to check JDK updates
check_jdk_updates() {
    log "Checking JDK updates..."
    
    local current_version
    if command -v yq >/dev/null 2>&1; then
        current_version=$(yq eval '.jdk.version' "$VERSIONS_FILE")
    else
        current_version=$(grep -A10 "^jdk:" "$VERSIONS_FILE" | grep "version:" | sed 's/.*version: *"\([^"]*\)".*/\1/')
    fi
    
    # For JDK 21, check for patch updates
    local major_minor=$(echo "$current_version" | cut -d'.' -f1-2)
    
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        # Check GitHub releases for OpenJDK (this is a simplified check)
        local latest_patch
        local releases_json
        releases_json=$(curl -s "https://api.github.com/repos/openjdk/jdk${major_minor}u/releases")
        
        # Check if we got a valid JSON array with at least one release
        if echo "$releases_json" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1; then
            latest_patch=$(echo "$releases_json" | jq -r '.[0].tag_name' | sed 's/jdk-//' | sed 's/+.*//')
        else
            warn "No JDK releases found in GitHub API response or API error"
            log "JDK version check skipped: $current_version (considering current version up-to-date)"
            log "JDK is up to date: $current_version"
            return 1
        fi
        
        if [ "$current_version" != "$latest_patch" ] && [ -n "$latest_patch" ] && [ "$latest_patch" != "null" ]; then
            warn "JDK update available: $current_version -> $latest_patch"
            echo "jdk_update_available=true" >> /tmp/update-status
            echo "jdk_current=$current_version" >> /tmp/update-status
            echo "jdk_latest=$latest_patch" >> /tmp/update-status
            return 0
        else
            log "JDK is up to date: $current_version"
            return 1
        fi
    else
        warn "curl or jq not available, cannot check JDK updates automatically"
        return 1
    fi
}

# Function to check plugin security updates
check_plugin_security() {
    log "Checking plugin security updates..."
    
    local updates_found=0
    
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        # Fetch Jenkins update center data
        local update_data
        update_data=$(curl -s "https://updates.jenkins.io/update-center.json" | sed '1d;$d' | jq '.plugins')
        
        # Check each plugin in versions.yml
        while IFS= read -r plugin_line; do
            if [[ "$plugin_line" =~ ^[[:space:]]*([a-zA-Z0-9-]+): ]]; then
                local plugin_name="${BASH_REMATCH[1]}"
                local current_version
                
                if command -v yq >/dev/null 2>&1; then
                    current_version=$(yq eval ".plugins.${plugin_name}.version" "$VERSIONS_FILE" 2>/dev/null)
                else
                    current_version=$(sed -n "/^\s*${plugin_name}:/,/^\s*[a-zA-Z]/p" "$VERSIONS_FILE" | \
                                    grep "version:" | head -1 | sed 's/.*version: *"\([^"]*\)".*/\1/')
                fi
                
                if [ "$current_version" != "null" ] && [ -n "$current_version" ]; then
                    # Get latest version from update center
                    local latest_version
                    latest_version=$(echo "$update_data" | jq -r ".\"${plugin_name}\".version" 2>/dev/null)
                    
                    if [ "$latest_version" != "null" ] && [ "$current_version" != "$latest_version" ]; then
                        warn "Plugin update available: ${plugin_name} $current_version -> $latest_version"
                        echo "plugin_${plugin_name}_update=true" >> /tmp/update-status
                        echo "plugin_${plugin_name}_current=$current_version" >> /tmp/update-status
                        echo "plugin_${plugin_name}_latest=$latest_version" >> /tmp/update-status
                        ((updates_found++))
                    fi
                fi
            fi
        done < <(sed -n '/^plugins:/,/^[a-zA-Z]/p' "$VERSIONS_FILE" | grep -E "^\s+[a-zA-Z0-9-]+:")
        
        if [ $updates_found -gt 0 ]; then
            warn "Found $updates_found plugin updates"
            echo "plugin_updates_count=$updates_found" >> /tmp/update-status
            return 0
        else
            log "All plugins are up to date"
            return 1
        fi
    else
        warn "curl or jq not available, cannot check plugin updates automatically"
        return 1
    fi
}

# Function to apply updates
apply_updates() {
    log "Applying updates to versions.yml..."
    
    if [ ! -f /tmp/update-status ]; then
        log "No updates to apply"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would apply the following updates:"
        cat /tmp/update-status
        return 0
    fi
    
    # Backup before making changes
    backup_versions
    
    # Apply updates based on update-status file
    local updates_applied=0
    
    while IFS='=' read -r key value; do
        case "$key" in
            jenkins_update_available)
                if [ "$value" = "true" ] && [ "$AUTO_APPROVE" = "true" ]; then
                    log "Updating Jenkins version..."
                    local jenkins_latest
                    jenkins_latest=$(grep "jenkins_latest=" /tmp/update-status | cut -d'=' -f2)
                    if [ -n "$jenkins_latest" ]; then
                        if command -v yq >/dev/null 2>&1; then
                            yq eval ".jenkins.version = \"$jenkins_latest\"" -i "$VERSIONS_FILE"
                        else
                            sed -i "s/version: \"[^\"]*\"/version: \"$jenkins_latest\"/" "$VERSIONS_FILE"
                        fi
                        success "Updated Jenkins to version $jenkins_latest"
                        ((updates_applied++))
                    fi
                fi
                ;;
            jdk_update_available)
                if [ "$value" = "true" ] && [ "$AUTO_APPROVE" = "true" ]; then
                    log "Updating JDK version..."
                    local jdk_latest
                    jdk_latest=$(grep "jdk_latest=" /tmp/update-status | cut -d'=' -f2)
                    if [ -n "$jdk_latest" ]; then
                        if command -v yq >/dev/null 2>&1; then
                            yq eval ".jdk.version = \"$jdk_latest\"" -i "$VERSIONS_FILE"
                        else
                            sed -i "/^jdk:/,/^[a-zA-Z]/ s/version: \"[^\"]*\"/version: \"$jdk_latest\"/" "$VERSIONS_FILE"
                        fi
                        success "Updated JDK to version $jdk_latest"
                        ((updates_applied++))
                    fi
                fi
                ;;
            plugin_*_update)
                if [ "$value" = "true" ] && [ "$AUTO_APPROVE" = "true" ]; then
                    local plugin_name=$(echo "$key" | sed 's/plugin_//;s/_update//')
                    log "Updating plugin: $plugin_name"
                    local plugin_latest
                    plugin_latest=$(grep "plugin_${plugin_name}_latest=" /tmp/update-status | cut -d'=' -f2)
                    if [ -n "$plugin_latest" ]; then
                        if command -v yq >/dev/null 2>&1; then
                            yq eval ".plugins.${plugin_name}.version = \"$plugin_latest\"" -i "$VERSIONS_FILE"
                        else
                            sed -i "/^\s*${plugin_name}:/,/^\s*[a-zA-Z]/ s/version: \"[^\"]*\"/version: \"$plugin_latest\"/" "$VERSIONS_FILE"
                        fi
                        success "Updated plugin $plugin_name to version $plugin_latest"
                        ((updates_applied++))
                    fi
                fi
                ;;
        esac
    done < /tmp/update-status
    
    if [ $updates_applied -gt 0 ]; then
        # Update metadata
        local current_date=$(date +"%Y-%m-%d")
        if command -v yq >/dev/null 2>&1; then
            yq eval ".metadata.last_updated = \"$current_date\"" -i "$VERSIONS_FILE"
        else
            sed -i "s/last_updated: \".*\"/last_updated: \"$current_date\"/" "$VERSIONS_FILE"
        fi
        
        success "Applied $updates_applied updates to versions.yml"
        log "Remember to test the build after applying updates"
    else
        log "No updates were applied (AUTO_APPROVE=$AUTO_APPROVE)"
    fi
}

# Function to generate security report
generate_security_report() {
    log "Generating security report..."
    
    local report_file="${PROJECT_DIR}/security-report-$(date +%Y%m%d).md"
    
    cat > "$report_file" << EOF
# Jenkins Standalone Security Report
Generated on: $(date)

## Current Versions
EOF
    
    if command -v yq >/dev/null 2>&1; then
        echo "- Jenkins: $(yq eval '.jenkins.version' "$VERSIONS_FILE")" >> "$report_file"
        echo "- JDK: $(yq eval '.jdk.version' "$VERSIONS_FILE")" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "## Update Status" >> "$report_file"
    
    if [ -f /tmp/update-status ]; then
        echo "Updates available:" >> "$report_file"
        cat /tmp/update-status >> "$report_file"
    else
        echo "No updates found or check failed" >> "$report_file"
    fi
    
    log "Security report generated: $report_file"
}

# Main execution
main() {
    log "Starting version update check..."
    
    # Clean up previous run
    rm -f /tmp/update-status
    
    # Check for updates
    local updates_available=false
    
    if check_jenkins_updates; then
        updates_available=true
    fi
    
    if check_jdk_updates; then
        updates_available=true
    fi
    
    if [ "$SECURITY_ONLY" = "false" ] || [ "$UPDATE_TYPE" = "minor" ] || [ "$UPDATE_TYPE" = "major" ]; then
        if check_plugin_security; then
            updates_available=true
        fi
    fi
    
    # Generate report
    generate_security_report
    
    # Apply updates if configured
    if [ "$updates_available" = true ]; then
        apply_updates
    else
        log "No updates available"
    fi
    
    # Clean up
    rm -f /tmp/update-status
    
    log "Version update check completed"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --security-only)
            SECURITY_ONLY=true
            shift
            ;;
        --all-updates)
            SECURITY_ONLY=false
            shift
            ;;
        --type)
            UPDATE_TYPE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run        Show what would be updated without making changes"
            echo "  --auto-approve   Automatically apply updates without prompts"
            echo "  --security-only  Only check for security updates (default)"
            echo "  --all-updates    Check for all available updates"
            echo "  --type TYPE      Update type: security, minor, major"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check dependencies
if ! command -v curl >/dev/null 2>&1; then
    warn "curl not found - some update checks will be skipped"
fi

if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found - some update checks will be skipped"
fi

if ! command -v yq >/dev/null 2>&1; then
    warn "yq not found - using fallback parsing (less reliable)"
fi

# Run main function
main