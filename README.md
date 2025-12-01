# Shai-Hulud Vulnerability Scanner

A tool to scan npm projects for vulnerable packages listed in the Shai-Hulud 2.0 dataset.

## Features

- ✅ Scans all `package.json` and `package-lock.json` files recursively
- ✅ Includes `node_modules` directories in the scan
- ✅ Color-coded output:
  - 🔴 **Red**: Exact version match (CRITICAL)
  - 🟡 **Yellow**: Package found but different version (WARNING)
  - 🟢 **Green**: No vulnerabilities found
- ✅ Detailed reporting with file paths
- ✅ Exit code 1 if exact matches found (useful for CI/CD)

## Available Scripts

### Node.js Version (Recommended)

**Requirements:** Node.js (any version)

```bash
node scan-vulnerabilities.js <csv-file> <folder-to-scan>
```

**Example:**
```bash
node scan-vulnerabilities.js shai-hulud-2.0.csv ./my-project
```

Or make it executable and run directly:
```bash
./scan-vulnerabilities.js shai-hulud-2.0.csv ./my-project
```

### Bash Version

**Requirements:** Bash, optionally `jq` for better JSON parsing

```bash
./scan-vulnerabilities.sh <csv-file> <folder-to-scan>
```

**Example:**
```bash
./scan-vulnerabilities.sh shai-hulud-2.0.csv ./my-project
```

> **Note:** The bash version works without `jq` but is more accurate and faster when `jq` is installed. Install with:
> - macOS: `brew install jq`
> - Ubuntu/Debian: `apt-get install jq`
> - Others: See [jq installation guide](https://stedolan.github.io/jq/download/)

## Usage Examples

### Scan current directory
```bash
node scan-vulnerabilities.js shai-hulud-2.0.csv .
```

### Scan a specific project
```bash
node scan-vulnerabilities.js shai-hulud-2.0.csv ~/projects/my-app
```

### Use in CI/CD pipeline
```bash
# Will exit with code 1 if exact matches found
node scan-vulnerabilities.js shai-hulud-2.0.csv . || echo "Vulnerabilities detected!"
```

## Output Format

```
=== Shai-Hulud Vulnerability Scanner ===

Loading vulnerable packages from: shai-hulud-2.0.csv
Found: 429 unique vulnerable packages

Scanning folder: ./my-project
Searching for package.json and package-lock.json files...

Found: 3 package files to scan

=== FINDINGS ===

[EXACT MATCH] @asyncapi/parser@3.4.1
  Vulnerable version: 3.4.1
  Found in: /path/to/package.json

[DIFFERENT VERSION] posthog-js@1.300.0
  Vulnerable versions: 1.297.3
  Found in: /path/to/package.json

=== SUMMARY ===
Exact matches (CRITICAL): 1
Different versions (WARNING): 1
Total findings: 2
```

## What Gets Scanned

The scanner checks:
- ✅ `package.json` files (all dependency types: dependencies, devDependencies, peerDependencies, optionalDependencies)
- ✅ `package-lock.json` files (both lockfileVersion 1 and 2/3 formats)
- ✅ All nested `node_modules` directories
- ✅ All subdirectories recursively

## CSV Format

The CSV file should have the following format:
```csv
package_name,package_version
@asyncapi/parser,3.4.1
posthog-js,1.297.3
```

## Exit Codes

- `0`: No exact matches found (may have warnings)
- `1`: Exact matches found or error occurred

## Performance

- **Node.js version**: Fast, no external dependencies
- **Bash version**: Slower but works everywhere, faster with `jq` installed

For large projects with many `node_modules`, the scan may take a minute or two.

## Testing

A test project is included to verify the scanner works correctly after making changes.

### Run the test
```bash
./run-test.sh
```

This will scan the `test-project` directory which contains:
- Multiple **FAKE** vulnerable packages for testing purposes only
- Nested directories with their own `package.json` files
- A mock `node_modules` structure
- Both exact matches and different version warnings

Expected output: 6 exact matches and 1 warning across 3 different files.

**⚠️ Security Note:** All packages in `test-project/` are fictitious and created solely for testing. No real vulnerable packages are included to prevent security risks.

## Troubleshooting

### "Permission denied" errors
Some directories may not be readable. The scanner will skip these and continue.

### No output / No findings
- Verify the CSV file path is correct
- Ensure the folder contains `package.json` or `package-lock.json` files
- Check that packages in your project match those in the CSV

### Bash version not working
- Ensure the script is executable: `chmod +x scan-vulnerabilities.sh`
- Install `jq` for better accuracy: `brew install jq` (macOS)
