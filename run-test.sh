#!/bin/bash

# Test runner for vulnerability scanner
# This script runs the scanner against the test-project

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "============================================"
echo "Running Shai-Hulud Vulnerability Scanner Test"
echo "============================================"
echo ""

# Run Node.js version
echo "Testing Node.js version..."
echo "-------------------------------------------"
node "$SCRIPT_DIR/scan-vulnerabilities.js" "$SCRIPT_DIR/shai-hulud-2.0.csv" "$SCRIPT_DIR/test-project"

EXIT_CODE=$?

echo ""
echo "============================================"
echo "Test completed with exit code: $EXIT_CODE"
echo "============================================"
echo ""
echo "Expected results:"
echo "- 5 EXACT MATCHES (test-vulnerable-package appears twice in root, plus other vulnerable packages)"
echo "- 1 DIFFERENT VERSION (posthog-js)"
echo "- Files in: test-project/package.json, test-project/nested/package.json, test-project/nested/node_modules/some-package/package.json"
echo ""

exit $EXIT_CODE
