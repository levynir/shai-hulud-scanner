# Shai-Hulud Vulnerability Scanner - Quick Start

## Installation
```bash
# Clone or navigate to the directory
cd /Users/nirzoomd.com/development/shai-hulud-tester

# Make scripts executable (if needed)
chmod +x scan-vulnerabilities.js scan-vulnerabilities.sh run-test.sh
```

## Basic Usage

### Scan a project
```bash
# Node.js version (recommended)
node scan-vulnerabilities.js shai-hulud-2.0.csv /path/to/project

# Bash version
./scan-vulnerabilities.sh shai-hulud-2.0.csv /path/to/project
```

### Scan current directory
```bash
node scan-vulnerabilities.js shai-hulud-2.0.csv .
```

### Run test
```bash
./run-test.sh
```

## Output Explained

### Red (Critical) - Exact Match
```
[EXACT MATCH] package-name@1.0.0
  Vulnerable version: 1.0.0
  Found in: /full/path/to/package.json
```
**Action Required:** This exact version is vulnerable. Update immediately!

### Yellow (Warning) - Different Version
```
[DIFFERENT VERSION] package-name@2.0.0
  Vulnerable versions: 1.0.0, 1.5.0
  Found in: /full/path/to/package.json
```
**Action:** Review if your version is affected. The listed versions are known vulnerable.

### Green - No Issues
```
✓ No vulnerable packages found!
```
**Good!** No vulnerable packages detected.

## Exit Codes
- `0` - No exact matches (safe or only warnings)
- `1` - Exact matches found or error occurred

## Common Use Cases

### CI/CD Integration
```bash
# Fail build if vulnerabilities found
node scan-vulnerabilities.js shai-hulud-2.0.csv . || exit 1
```

### Scan multiple projects
```bash
for dir in project1 project2 project3; do
  echo "Scanning $dir..."
  node scan-vulnerabilities.js shai-hulud-2.0.csv "$dir"
done
```

### Save results to file
```bash
node scan-vulnerabilities.js shai-hulud-2.0.csv . > scan-results.txt 2>&1
```

## What Gets Scanned
✅ All `package.json` files (recursively)
✅ All `package-lock.json` files (recursively)
✅ All dependency types (dependencies, devDependencies, etc.)
✅ All `node_modules` directories
✅ Nested projects and monorepos

## File Structure
```
.
├── scan-vulnerabilities.js      # Node.js scanner (recommended)
├── scan-vulnerabilities.sh      # Bash scanner (alternative)
├── run-test.sh                  # Test runner
├── shai-hulud-2.0.csv          # Vulnerable packages database
├── test-project/                # Test data
├── README.md                    # Full documentation
└── QUICKSTART.md               # This file
```

## Need Help?
- Full docs: See `README.md`
- Changes: See `CHANGES.md`
- Issues: Check file permissions, CSV path, and project structure

## Quick Test
```bash
# Should find 6 exact matches and 1 warning
./run-test.sh
```
