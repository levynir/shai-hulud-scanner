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
echo "- 6 EXACT MATCHES (fake vulnerable packages for testing)"
echo "- 1 DIFFERENT VERSION (mock-compromised-pkg)"
echo "- Files in: test-project/package.json, test-project/nested/package.json, test-project/nested/node_modules/some-package/package.json"
echo ""
echo "Note: All packages in test project are FAKE and for testing only"
echo ""

exit $EXIT_CODE
