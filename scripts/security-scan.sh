#!/bin/bash
set -e

# Security Vulnerability Scanner for Jenkins Standalone
# Checks for known vulnerabilities in Jenkins, JDK, and plugins

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="${PROJECT_DIR}/versions.yml"

# Configuration
SCAN_TYPE="all"  # all, jenkins, jdk, plugins
OUTPUT_FORMAT="text"  # text, json, csv
SEVERITY_FILTER="medium"  # low, medium, high, critical
REPORT_FILE=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Initialize report file
init_report() {
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    REPORT_FILE="${PROJECT_DIR}/security-scan-${timestamp}.${OUTPUT_FORMAT}"
    
    case "$OUTPUT_FORMAT" in
        json)
            echo '{"scan_date":"'$(date -Iseconds)'","vulnerabilities":[' > "$REPORT_FILE"
            ;;
        csv)
            echo "Component,Version,CVE,Severity,Description,Fixed_Version,Reference" > "$REPORT_FILE"
            ;;
        text)
            cat > "$REPORT_FILE" << EOF
# Security Scan Report
Generated: $(date)
Scan Type: $SCAN_TYPE
Severity Filter: $SEVERITY_FILTER

## Summary
EOF
            ;;
    esac
}

# Function to check Jenkins security advisories
scan_jenkins_security() {
    log "Scanning Jenkins security vulnerabilities..."
    
    local jenkins_version
    if command -v yq >/dev/null 2>&1; then
        jenkins_version=$(yq eval '.jenkins.version' "$VERSIONS_FILE")
    else
        jenkins_version=$(grep -A5 "^jenkins:" "$VERSIONS_FILE" | grep "version:" | sed 's/.*version: *"\([^"]*\)".*/\1/')
    fi
    
    local vulnerabilities_found=0
    
    # Check against Jenkins security advisories RSS feed
    if command -v curl >/dev/null 2>&1; then
        local advisories
        advisories=$(curl -s "https://www.jenkins.io/security/advisories/rss.xml" || echo "")
        
        if [ -n "$advisories" ]; then
            # Parse RSS and check for vulnerabilities affecting our version
            # This is a simplified check - in production, you'd want more sophisticated parsing
            local affected_versions
            affected_versions=$(echo "$advisories" | grep -i "jenkins.*$jenkins_version\|$jenkins_version.*jenkins" || true)
            
            if [ -n "$affected_versions" ]; then
                warn "Potential Jenkins security advisories found for version $jenkins_version"
                ((vulnerabilities_found++))
                
                # Add to report
                case "$OUTPUT_FORMAT" in
                    text)
                        echo "### Jenkins Core" >> "$REPORT_FILE"
                        echo "- Version: $jenkins_version" >> "$REPORT_FILE"
                        echo "- Status: Potential vulnerabilities found" >> "$REPORT_FILE"
                        echo "- Action: Review Jenkins security advisories" >> "$REPORT_FILE"
                        echo "" >> "$REPORT_FILE"
                        ;;
                    json)
                        cat >> "$REPORT_FILE" << EOF
{"component":"jenkins-core","version":"$jenkins_version","severity":"unknown","description":"Potential vulnerability - check advisories","cve":"JENKINS-ADV"},
EOF
                        ;;
                    csv)
                        echo "jenkins-core,$jenkins_version,JENKINS-ADV,unknown,Potential vulnerability - check advisories,,https://www.jenkins.io/security/advisories/" >> "$REPORT_FILE"
                        ;;
                esac
            else
                success "No known Jenkins security advisories for version $jenkins_version"
            fi
        else
            warn "Could not fetch Jenkins security advisories"
        fi
    fi
    
    return $vulnerabilities_found
}

# Function to check JDK security vulnerabilities
scan_jdk_security() {
    log "Scanning JDK security vulnerabilities..."
    
    local jdk_version
    if command -v yq >/dev/null 2>&1; then
        jdk_version=$(yq eval '.jdk.version' "$VERSIONS_FILE")
    else
        jdk_version=$(grep -A10 "^jdk:" "$VERSIONS_FILE" | grep "version:" | sed 's/.*version: *"\([^"]*\)".*/\1/')
    fi
    
    local vulnerabilities_found=0
    
    # Check for known JDK vulnerabilities
    # This would typically integrate with CVE databases or Oracle's security bulletins
    local major_version=$(echo "$jdk_version" | cut -d'.' -f1)
    local minor_version=$(echo "$jdk_version" | cut -d'.' -f2)
    local patch_version=$(echo "$jdk_version" | cut -d'.' -f3)
    
    # Example: Check if JDK version is older than known secure versions
    local known_secure_versions=(
        "21.0.2"  # Example secure version
        "17.0.10"  # Example secure version for JDK 17
        "11.0.22"  # Example secure version for JDK 11
    )
    
    local is_secure=false
    for secure_version in "${known_secure_versions[@]}"; do
        if [[ "$jdk_version" == "$secure_version"* ]]; then
            is_secure=true
            break
        fi
    done
    
    if [ "$is_secure" = false ]; then
        # Check if there are newer patch versions available
        if command -v curl >/dev/null 2>&1; then
            # This is a simplified check - would need actual Oracle/OpenJDK API integration
            local latest_patch_info
            latest_patch_info=$(curl -s "https://api.github.com/repos/openjdk/jdk${major_version}u/releases" | head -20 || echo "")
            
            if echo "$latest_patch_info" | grep -q "tag_name.*${major_version}.0"; then
                warn "JDK $jdk_version may have security updates available"
                ((vulnerabilities_found++))
                
                # Add to report
                case "$OUTPUT_FORMAT" in
                    text)
                        echo "### JDK" >> "$REPORT_FILE"
                        echo "- Version: $jdk_version" >> "$REPORT_FILE"
                        echo "- Status: May need security updates" >> "$REPORT_FILE"
                        echo "- Action: Check for latest JDK $major_version patch releases" >> "$REPORT_FILE"
                        echo "" >> "$REPORT_FILE"
                        ;;
                    json)
                        cat >> "$REPORT_FILE" << EOF
{"component":"openjdk","version":"$jdk_version","severity":"medium","description":"May need security updates","cve":"JDK-SEC"},
EOF
                        ;;
                    csv)
                        echo "openjdk,$jdk_version,JDK-SEC,medium,May need security updates,,https://openjdk.java.net/groups/vulnerability/" >> "$REPORT_FILE"
                        ;;
                esac
            fi
        fi
    else
        success "JDK version $jdk_version appears to be secure"
    fi
    
    return $vulnerabilities_found
}

# Function to scan plugin vulnerabilities
scan_plugin_security() {
    log "Scanning plugin security vulnerabilities..."
    
    local total_plugins=0
    local vulnerable_plugins=0
    
    # Get plugin security database if available
    local plugin_security_db=""
    if command -v curl >/dev/null 2>&1; then
        plugin_security_db=$(curl -s "https://updates.jenkins.io/update-center.json" | sed '1d;$d' || echo "")
    fi
    
    # Check each plugin
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
                ((total_plugins++))
                
                # Check if plugin has known security issues
                local security_warnings=""
                if [ -n "$plugin_security_db" ] && command -v jq >/dev/null 2>&1; then
                    security_warnings=$(echo "$plugin_security_db" | \
                                      jq -r ".plugins.\"${plugin_name}\".securityWarnings[]?.message" 2>/dev/null || echo "")
                fi
                
                if [ -n "$security_warnings" ]; then
                    warn "Security warning for plugin $plugin_name:$current_version"
                    ((vulnerable_plugins++))
                    
                    # Add to report
                    case "$OUTPUT_FORMAT" in
                        text)
                            echo "#### Plugin: $plugin_name" >> "$REPORT_FILE"
                            echo "- Version: $current_version" >> "$REPORT_FILE"
                            echo "- Security Warning: $security_warnings" >> "$REPORT_FILE"
                            echo "" >> "$REPORT_FILE"
                            ;;
                        json)
                            cat >> "$REPORT_FILE" << EOF
{"component":"plugin-$plugin_name","version":"$current_version","severity":"high","description":"$security_warnings","cve":"PLUGIN-SEC"},
EOF
                            ;;
                        csv)
                            echo "plugin-$plugin_name,$current_version,PLUGIN-SEC,high,$security_warnings,,https://plugins.jenkins.io/$plugin_name" >> "$REPORT_FILE"
                            ;;
                    esac
                fi
            fi
        fi
    done < <(sed -n '/^plugins:/,/^[a-zA-Z]/p' "$VERSIONS_FILE" | grep -E "^\s+[a-zA-Z0-9-]+:")
    
    log "Scanned $total_plugins plugins, found $vulnerable_plugins with potential security issues"
    return $vulnerable_plugins
}

# Function to finalize report
finalize_report() {
    local total_vulnerabilities=$1
    
    case "$OUTPUT_FORMAT" in
        json)
            # Remove trailing comma and close JSON
            sed -i '$ s/,$//' "$REPORT_FILE"
            echo ']}' >> "$REPORT_FILE"
            ;;
        text)
            echo "" >> "$REPORT_FILE"
            echo "## Scan Results" >> "$REPORT_FILE"
            echo "Total vulnerabilities found: $total_vulnerabilities" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "## Recommendations" >> "$REPORT_FILE"
            if [ $total_vulnerabilities -gt 0 ]; then
                echo "1. Review all identified vulnerabilities" >> "$REPORT_FILE"
                echo "2. Update components using: ./scripts/update-versions.sh --security-only" >> "$REPORT_FILE"
                echo "3. Test the updated build thoroughly" >> "$REPORT_FILE"
                echo "4. Consider implementing automated security scanning in CI/CD" >> "$REPORT_FILE"
            else
                echo "No vulnerabilities found. Continue regular monitoring." >> "$REPORT_FILE"
            fi
            ;;
    esac
    
    success "Security scan report saved to: $REPORT_FILE"
}

# Main execution
main() {
    log "Starting security vulnerability scan..."
    
    init_report
    
    local total_vulnerabilities=0
    
    case "$SCAN_TYPE" in
        all|jenkins)
            if scan_jenkins_security; then
                ((total_vulnerabilities += $?))
            fi
            ;;& # Continue to next case
        all|jdk)
            if scan_jdk_security; then
                ((total_vulnerabilities += $?))
            fi
            ;;& # Continue to next case
        all|plugins)
            if scan_plugin_security; then
                ((total_vulnerabilities += $?))
            fi
            ;;
    esac
    
    finalize_report $total_vulnerabilities
    
    if [ $total_vulnerabilities -gt 0 ]; then
        warn "Found $total_vulnerabilities potential security issues"
        echo "Review the report at: $REPORT_FILE"
        exit 1
    else
        success "No security vulnerabilities found"
        exit 0
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            SCAN_TYPE="$2"
            shift 2
            ;;
        --format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --severity)
            SEVERITY_FILTER="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --type TYPE       Scan type: all, jenkins, jdk, plugins (default: all)"
            echo "  --format FORMAT   Output format: text, json, csv (default: text)"
            echo "  --severity LEVEL  Minimum severity: low, medium, high, critical (default: medium)"
            echo "  --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --type jenkins --format json"
            echo "  $0 --type plugins --severity high"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate inputs
case "$SCAN_TYPE" in
    all|jenkins|jdk|plugins) ;;
    *) error "Invalid scan type: $SCAN_TYPE"; exit 1 ;;
esac

case "$OUTPUT_FORMAT" in
    text|json|csv) ;;
    *) error "Invalid output format: $OUTPUT_FORMAT"; exit 1 ;;
esac

case "$SEVERITY_FILTER" in
    low|medium|high|critical) ;;
    *) error "Invalid severity filter: $SEVERITY_FILTER"; exit 1 ;;
esac

# Check if versions.yml exists
if [ ! -f "$VERSIONS_FILE" ]; then
    error "versions.yml not found at $VERSIONS_FILE"
    exit 1
fi

# Run main function
main