#!/bin/bash

# Shai-Hulud Vulnerability Scanner (Bash version)
# Usage: ./scan-vulnerabilities.sh <csv-file> <folder-to-scan>

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check arguments
if [ "$#" -ne 2 ]; then
    echo -e "${BOLD}Usage:${NC} $0 <csv-file> <folder-to-scan>"
    echo -e "${BOLD}Example:${NC} $0 shai-hulud-2.0.csv ./my-project"
    exit 1
fi

CSV_FILE="$1"
SCAN_FOLDER="$2"

# Validate inputs
if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}Error: CSV file not found: $CSV_FILE${NC}"
    exit 1
fi

if [ ! -d "$SCAN_FOLDER" ]; then
    echo -e "${RED}Error: Folder not found: $SCAN_FOLDER${NC}"
    exit 1
fi

echo -e "${CYAN}${BOLD}=== Shai-Hulud Vulnerability Scanner ===${NC}\n"
echo -e "${BOLD}Loading vulnerable packages from:${NC} $CSV_FILE"

# Create associative array for vulnerable packages
declare -A VULNERABLE_PACKAGES

# Read CSV file (skip header)
TOTAL_PACKAGES=0
while IFS=',' read -r package_name package_version; do
    if [ "$package_name" != "package_name" ]; then
        # Store multiple versions for same package
        if [ -z "${VULNERABLE_PACKAGES[$package_name]}" ]; then
            VULNERABLE_PACKAGES[$package_name]="$package_version"
        else
            VULNERABLE_PACKAGES[$package_name]="${VULNERABLE_PACKAGES[$package_name]}|$package_version"
        fi
        ((TOTAL_PACKAGES++))
    fi
done < "$CSV_FILE"

echo -e "${BOLD}Loaded:${NC} $TOTAL_PACKAGES vulnerable package versions\n"

echo -e "${BOLD}Scanning folder:${NC} $SCAN_FOLDER"
echo -e "${CYAN}Searching for package.json and package-lock.json files...${NC}\n"

# Find all package.json and package-lock.json files (including node_modules)
PACKAGE_FILES=$(find "$SCAN_FOLDER" -name "package.json" -o -name "package-lock.json" 2>/dev/null)
FILE_COUNT=$(echo "$PACKAGE_FILES" | grep -c .)

echo -e "${BOLD}Found:${NC} $FILE_COUNT package files to scan\n"

EXACT_MATCHES=0
DIFFERENT_VERSIONS=0
TEMP_RESULTS=$(mktemp)

# Check each package file
while IFS= read -r file; do
    if [ -z "$file" ]; then
        continue
    fi

    # Check if file is package.json or package-lock.json
    if [[ "$file" == *package.json ]] && [[ "$file" != *package-lock.json ]]; then
        # Parse package.json for dependencies
        if command -v jq &> /dev/null; then
            # Use jq if available (more reliable)
            for pkg_name in "${!VULNERABLE_PACKAGES[@]}"; do
                # Check all dependency types
                VERSION=$(jq -r --arg pkg "$pkg_name" '
                    (.dependencies // {})[$pkg] //
                    (.devDependencies // {})[$pkg] //
                    (.peerDependencies // {})[$pkg] //
                    (.optionalDependencies // {})[$pkg] //
                    "null"
                ' "$file" 2>/dev/null)

                if [ "$VERSION" != "null" ] && [ -n "$VERSION" ]; then
                    # Clean version (remove ^, ~, >=, etc.)
                    CLEAN_VERSION=$(echo "$VERSION" | sed 's/^[\^~>=<]*//')
                    VULNERABLE_VERSIONS="${VULNERABLE_PACKAGES[$pkg_name]}"

                    # Check if exact match
                    if echo "$VULNERABLE_VERSIONS" | grep -q "|$CLEAN_VERSION|\\|^$CLEAN_VERSION|\\||$CLEAN_VERSION$\\|^$CLEAN_VERSION$"; then
                        echo "EXACT|$file|$pkg_name|$VERSION|$VULNERABLE_VERSIONS" >> "$TEMP_RESULTS"
                        ((EXACT_MATCHES++))
                    else
                        echo "DIFF|$file|$pkg_name|$VERSION|$VULNERABLE_VERSIONS" >> "$TEMP_RESULTS"
                        ((DIFFERENT_VERSIONS++))
                    fi
                fi
            done
        else
            # Fallback to grep if jq is not available
            for pkg_name in "${!VULNERABLE_PACKAGES[@]}"; do
                VERSION=$(grep -oP "\"$pkg_name\"\\s*:\\s*\"\\K[^\"]*" "$file" 2>/dev/null | head -1)

                if [ -n "$VERSION" ]; then
                    CLEAN_VERSION=$(echo "$VERSION" | sed 's/^[\^~>=<]*//')
                    VULNERABLE_VERSIONS="${VULNERABLE_PACKAGES[$pkg_name]}"

                    if echo "$VULNERABLE_VERSIONS" | grep -q "|$CLEAN_VERSION|\\|^$CLEAN_VERSION|\\||$CLEAN_VERSION$\\|^$CLEAN_VERSION$"; then
                        echo "EXACT|$file|$pkg_name|$VERSION|$VULNERABLE_VERSIONS" >> "$TEMP_RESULTS"
                        ((EXACT_MATCHES++))
                    else
                        echo "DIFF|$file|$pkg_name|$VERSION|$VULNERABLE_VERSIONS" >> "$TEMP_RESULTS"
                        ((DIFFERENT_VERSIONS++))
                    fi
                fi
            done
        fi
    elif [[ "$file" == *package-lock.json ]]; then
        # Parse package-lock.json
        if command -v jq &> /dev/null; then
            for pkg_name in "${!VULNERABLE_PACKAGES[@]}"; do
                # Check both lockfileVersion formats
                VERSION=$(jq -r --arg pkg "$pkg_name" '
                    (
                        (.packages // {} | to_entries[] |
                        select(.key | endswith("/" + $pkg) or . == ("node_modules/" + $pkg)) |
                        .value.version) //
                        (.dependencies[$pkg].version // "null")
                    )
                ' "$file" 2>/dev/null | head -1)

                if [ "$VERSION" != "null" ] && [ -n "$VERSION" ]; then
                    VULNERABLE_VERSIONS="${VULNERABLE_PACKAGES[$pkg_name]}"

                    if echo "$VULNERABLE_VERSIONS" | grep -q "|$VERSION|\\|^$VERSION|\\||$VERSION$\\|^$VERSION$"; then
                        echo "EXACT|$file|$pkg_name|$VERSION|$VULNERABLE_VERSIONS" >> "$TEMP_RESULTS"
                        ((EXACT_MATCHES++))
                    else
                        echo "DIFF|$file|$pkg_name|$VERSION|$VULNERABLE_VERSIONS" >> "$TEMP_RESULTS"
                        ((DIFFERENT_VERSIONS++))
                    fi
                fi
            done
        fi
    fi
done <<< "$PACKAGE_FILES"

# Display results
if [ ! -s "$TEMP_RESULTS" ]; then
    echo -e "${GREEN}${BOLD}✓ No vulnerable packages found!${NC}\n"
else
    echo -e "${BOLD}=== FINDINGS ===${NC}\n"

    # Sort and display results
    sort -t'|' -k2,2 -k1,1r "$TEMP_RESULTS" | while IFS='|' read -r type file pkg_name version vuln_versions; do
        if [ "$type" = "EXACT" ]; then
            echo -e "${RED}${BOLD}[EXACT MATCH]${NC} $pkg_name@$version"
            echo -e "  ${RED}Vulnerable version: $(echo $vuln_versions | tr '|' ', ')${NC}"
            echo -e "  ${CYAN}Found in: $file${NC}"
            echo ""
        else
            echo -e "${YELLOW}${BOLD}[DIFFERENT VERSION]${NC} $pkg_name@$version"
            echo -e "  ${YELLOW}Vulnerable versions: $(echo $vuln_versions | tr '|' ', ')${NC}"
            echo -e "  ${CYAN}Found in: $file${NC}"
            echo ""
        fi
    done

    echo -e "\n${BOLD}=== SUMMARY ===${NC}"
    echo -e "${RED}${BOLD}Exact matches (CRITICAL):${NC} $EXACT_MATCHES"
    echo -e "${YELLOW}${BOLD}Different versions (WARNING):${NC} $DIFFERENT_VERSIONS"
    echo -e "${BOLD}Total findings:${NC} $((EXACT_MATCHES + DIFFERENT_VERSIONS))\n"
fi

# Cleanup
rm -f "$TEMP_RESULTS"

# Exit with error if exact matches found
if [ "$EXACT_MATCHES" -gt 0 ]; then
    exit 1
fi
