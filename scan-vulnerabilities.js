#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');

// ANSI color codes
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  green: '\x1b[32m',
  cyan: '\x1b[36m',
  bold: '\x1b[1m'
};

// Parse CSV file
async function parseCSV(csvPath) {
  const vulnerablePackages = new Map();

  const fileStream = fs.createReadStream(csvPath);
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });

  let isFirstLine = true;
  for await (const line of rl) {
    if (isFirstLine) {
      isFirstLine = false;
      continue; // Skip header
    }

    const [packageName, packageVersion] = line.split(',');
    if (packageName && packageVersion) {
      if (!vulnerablePackages.has(packageName)) {
        vulnerablePackages.set(packageName, []);
      }
      vulnerablePackages.get(packageName).push(packageVersion.trim());
    }
  }

  return vulnerablePackages;
}

// Recursively find all package.json and package-lock.json files
function findPackageFiles(dir, files = []) {
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);

      if (entry.isDirectory()) {
        // Recursively search directories (including node_modules)
        findPackageFiles(fullPath, files);
      } else if (entry.name === 'package.json' || entry.name === 'package-lock.json') {
        files.push(fullPath);
      }
    }
  } catch (err) {
    // Skip directories we can't read (permission issues, etc.)
    if (err.code !== 'EACCES' && err.code !== 'EPERM') {
      console.error(`Error reading directory ${dir}:`, err.message);
    }
  }

  return files;
}

// Check a package.json file for vulnerable packages
function checkPackageJson(filePath, vulnerablePackages) {
  const findings = [];

  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const packageData = JSON.parse(content);

    const allDeps = {
      ...packageData.dependencies,
      ...packageData.devDependencies,
      ...packageData.peerDependencies,
      ...packageData.optionalDependencies
    };

    for (const [pkgName, version] of Object.entries(allDeps)) {
      if (vulnerablePackages.has(pkgName)) {
        const vulnerableVersions = vulnerablePackages.get(pkgName);
        const cleanVersion = version.replace(/^[\^~>=<]/, '').trim();

        const isExactMatch = vulnerableVersions.includes(cleanVersion);
        findings.push({
          package: pkgName,
          installedVersion: version,
          vulnerableVersions: vulnerableVersions,
          isExactMatch: isExactMatch,
          file: filePath
        });
      }
    }
  } catch (err) {
    // Skip invalid JSON files
  }

  return findings;
}

// Check a package-lock.json file for vulnerable packages
function checkPackageLockJson(filePath, vulnerablePackages) {
  const findings = [];

  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const lockData = JSON.parse(content);

    // Handle both lockfileVersion 1 and 2/3 formats
    const packages = lockData.packages || {};
    const dependencies = lockData.dependencies || {};

    // Check packages format (lockfileVersion 2/3)
    for (const [pkgPath, pkgInfo] of Object.entries(packages)) {
      if (!pkgPath) continue; // Skip root

      const pkgName = pkgPath.startsWith('node_modules/')
        ? pkgPath.replace('node_modules/', '').split('/node_modules/').pop()
        : pkgPath;

      if (vulnerablePackages.has(pkgName) && pkgInfo.version) {
        const vulnerableVersions = vulnerablePackages.get(pkgName);
        const isExactMatch = vulnerableVersions.includes(pkgInfo.version);

        findings.push({
          package: pkgName,
          installedVersion: pkgInfo.version,
          vulnerableVersions: vulnerableVersions,
          isExactMatch: isExactMatch,
          file: filePath
        });
      }
    }

    // Check dependencies format (lockfileVersion 1)
    function checkDependencies(deps, parentPath = '') {
      for (const [pkgName, pkgInfo] of Object.entries(deps)) {
        if (vulnerablePackages.has(pkgName) && pkgInfo.version) {
          const vulnerableVersions = vulnerablePackages.get(pkgName);
          const isExactMatch = vulnerableVersions.includes(pkgInfo.version);

          findings.push({
            package: pkgName,
            installedVersion: pkgInfo.version,
            vulnerableVersions: vulnerableVersions,
            isExactMatch: isExactMatch,
            file: filePath
          });
        }

        if (pkgInfo.dependencies) {
          checkDependencies(pkgInfo.dependencies, `${parentPath}/${pkgName}`);
        }
      }
    }

    if (Object.keys(dependencies).length > 0) {
      checkDependencies(dependencies);
    }
  } catch (err) {
    // Skip invalid JSON files
  }

  return findings;
}

// Main function
async function main() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.log(`${colors.bold}Usage:${colors.reset} node scan-vulnerabilities.js <csv-file> <folder-to-scan>`);
    console.log(`${colors.bold}Example:${colors.reset} node scan-vulnerabilities.js shai-hulud-2.0.csv ./my-project`);
    process.exit(1);
  }

  const csvPath = args[0];
  const scanFolder = args[1];

  // Validate inputs
  if (!fs.existsSync(csvPath)) {
    console.error(`${colors.red}Error: CSV file not found: ${csvPath}${colors.reset}`);
    process.exit(1);
  }

  if (!fs.existsSync(scanFolder)) {
    console.error(`${colors.red}Error: Folder not found: ${scanFolder}${colors.reset}`);
    process.exit(1);
  }

  console.log(`${colors.cyan}${colors.bold}=== Shai-Hulud Vulnerability Scanner ===${colors.reset}\n`);
  console.log(`${colors.bold}Loading vulnerable packages from:${colors.reset} ${csvPath}`);

  const vulnerablePackages = await parseCSV(csvPath);
  console.log(`${colors.bold}Loaded:${colors.reset} ${vulnerablePackages.size} unique vulnerable packages\n`);

  console.log(`${colors.bold}Scanning folder:${colors.reset} ${scanFolder}`);
  console.log(`${colors.cyan}Searching for package.json and package-lock.json files...${colors.reset}\n`);

  const packageFiles = findPackageFiles(scanFolder);
  console.log(`${colors.bold}Scanning:${colors.reset} ${packageFiles.length} package files\n`);

  let totalExactMatches = 0;
  let totalDifferentVersions = 0;
  const allFindings = [];

  for (const filePath of packageFiles) {
    let findings = [];

    if (filePath.endsWith('package.json')) {
      findings = checkPackageJson(filePath, vulnerablePackages);
    } else if (filePath.endsWith('package-lock.json')) {
      findings = checkPackageLockJson(filePath, vulnerablePackages);
    }

    if (findings.length > 0) {
      allFindings.push(...findings);
    }
  }

  // Remove duplicates (same package + version in same file)
  const uniqueFindings = [];
  const seen = new Set();

  for (const finding of allFindings) {
    const key = `${finding.file}:${finding.package}:${finding.installedVersion}`;
    if (!seen.has(key)) {
      seen.add(key);
      uniqueFindings.push(finding);
    }
  }

  // Sort findings by file, then by severity
  uniqueFindings.sort((a, b) => {
    if (a.file !== b.file) return a.file.localeCompare(b.file);
    if (a.isExactMatch !== b.isExactMatch) return b.isExactMatch ? 1 : -1;
    return a.package.localeCompare(b.package);
  });

  // Display results
  if (uniqueFindings.length === 0) {
    console.log(`${colors.green}${colors.bold}✓ No vulnerable packages found!${colors.reset}\n`);
  } else {
    console.log(`${colors.bold}=== FINDINGS ===${colors.reset}\n`);

    for (const finding of uniqueFindings) {
      if (finding.isExactMatch) {
        totalExactMatches++;
        console.log(`${colors.red}${colors.bold}[EXACT MATCH]${colors.reset} ${finding.package}@${finding.installedVersion}`);
        console.log(`  ${colors.red}Vulnerable version: ${finding.vulnerableVersions.join(', ')}${colors.reset}`);
        console.log(`  ${colors.cyan}Found in: ${finding.file}${colors.reset}\n`);
      } else {
        totalDifferentVersions++;
        console.log(`${colors.yellow}${colors.bold}[DIFFERENT VERSION]${colors.reset} ${finding.package}@${finding.installedVersion}`);
        console.log(`  ${colors.yellow}Vulnerable versions: ${finding.vulnerableVersions.join(', ')}${colors.reset}`);
        console.log(`  ${colors.cyan}Found in: ${finding.file}${colors.reset}\n`);
      }
    }

    console.log(`\n${colors.bold}=== SUMMARY ===${colors.reset}`);
    console.log(`${colors.red}${colors.bold}Exact matches (CRITICAL):${colors.reset} ${totalExactMatches}`);
    console.log(`${colors.yellow}${colors.bold}Different versions (WARNING):${colors.reset} ${totalDifferentVersions}`);
    console.log(`${colors.bold}Total findings:${colors.reset} ${uniqueFindings.length}\n`);

    if (totalExactMatches > 0) {
      process.exit(1); // Exit with error code if exact matches found
    }
  }
}

main().catch(err => {
  console.error(`${colors.red}Fatal error:${colors.reset}`, err);
  process.exit(1);
});
