<#
.SYNOPSIS
Upgrades an existing SharePoint Framework (SPFx) project to version 1.21.1
by performing a clean installation of dependencies.

.DESCRIPTION
This script checks for the presence of Node.js v22 and npm, creates a backup
of the package.json file (unless skipped), cleans existing installations,
updates the package.json to set the Node.js engine to v22, and installs the
required SPFx dependencies and dev dependencies for version 1.21.1.
It also attempts to install other existing dependencies and runs an npm audit
to check for vulnerabilities.

.PARAMETER SkipBackup
Specifies whether to skip the backup of the package.json file before making changes.

.EXAMPLE
upgrade_spfx_v1.21.1.ps1 -SkipBackup

.NOTES
Additional notes or remarks about the code, such as author, date, or version.

.LICENSE
MIT License
Copyright (c) 2025 Roland Rickborn (r_2@gmx.net)

#>

param(
    [switch]$SkipBackup = $false
)

Write-Host "Starting SPFx upgrade to v1.21.1..." -ForegroundColor Green
Write-Host "Working directory: $(Get-Location)" -ForegroundColor Yellow

# Check if package.json exists
if (-not (Test-Path "package.json")) {
    Write-Error "package.json not found in current directory. Please run this script from the project root."
    exit 1
}

# Check if node.js is available and ensure version is v22
try {
    $nodeVersion = node --version
    Write-Host "Using Node.js version: $nodeVersion" -ForegroundColor Blue

    # Remove the leading 'v' and split into major, minor, patch
    $versionParts = $nodeVersion.TrimStart('v').Split('.')
    $majorVersion = [int]$versionParts[0]

    if ($majorVersion -ne 22) {
        Write-Error "Node.js v22 is required. Detected version: $nodeVersion"
        exit 1
    }
} catch {
    Write-Error "Node.js is not available. Please ensure Node.js v22 is installed."
    exit 1
}

# Check if npm is available
try {
    $npmVersion = npm --version
    Write-Host "Using npm version: $npmVersion" -ForegroundColor Blue
} catch {
    Write-Error "npm is not available. Please ensure Node.js and npm are installed."
    exit 1
}

# Check if gulp-cli is installed
try {
    $gulpVersion = gulp --version
    Write-Host "Using Gulp CLI version: $gulpVersion" -ForegroundColor Blue
} catch {
    Write-Warning "Gulp CLI is not installed globally. Installing gulp-cli..."
    npm install -g gulp-cli
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install gulp-cli. Please install it manually."
        exit 1
    }
}

# Check if yo is installed
try {
    $yoVersion = yo --version
    Write-Host "Using Yeoman version: $yoVersion" -ForegroundColor Blue
} catch {
    Write-Warning "Yeoman (yo) is not installed globally. Installing yo..."
    npm install -g yo
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install yo. Please install it manually."
        exit 1
    }
}

# Check if @microsoft/generator-sharepoint is installed
try {
    $spfxGenVersion = yo @microsoft/sharepoint --version
    Write-Host "Using @microsoft/generator-sharepoint version: $spfxGenVersion" -ForegroundColor Blue
} catch {
    Write-Warning "@microsoft/generator-sharepoint is not installed globally. Installing it..."
    npm install -g @microsoft/generator-sharepoint
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install @microsoft/generator-sharepoint. Please install it manually."
        exit 1
    }
}

# Create backup of package.json if not skipped
if (-not $SkipBackup) {
    Write-Host "Creating backup of package.json..." -ForegroundColor Blue
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Copy-Item "package.json" "package.json.backup_$timestamp"
    Write-Host "Backup created: package.json.backup_$timestamp" -ForegroundColor Green
}

# Clean install process
Write-Host "Starting clean installation process..." -ForegroundColor Green

# Remove node_modules and package-lock.json
Write-Host "Cleaning existing installation..." -ForegroundColor Blue
if (Test-Path "node_modules") {
    Write-Host "Removing node_modules directory..." -ForegroundColor Yellow
    Remove-Item "node_modules" -Recurse -Force
}

if (Test-Path "package-lock.json") {
    Write-Host "Removing package-lock.json..." -ForegroundColor Yellow
    Remove-Item "package-lock.json" -Force
}

# Clear npm cache
Write-Host "Clearing npm cache..." -ForegroundColor Blue
npm cache clean --force

# Set engines node to 22 in package.json
Write-Host "Setting Node.js engine to v22 in package.json..." -ForegroundColor Blue
$json = Get-Content "package.json" | ConvertFrom-Json
$json.engines.node = ">=22.0.0 <23.0.0"
$json | ConvertTo-Json -Depth 10 | Set-Content "package.json"


# Install SPFx v1.21.1 dependencies
Write-Host "Installing SPFx v1.21.1 dependencies..." -ForegroundColor Green

# Install main SPFx dependencies
$spfxDependencies = @(
    "@microsoft/sp-adaptive-card-extension-base@1.21.1",
    "@microsoft/sp-core-library@1.21.1",
    "@microsoft/sp-http@1.21.1",
    "@microsoft/sp-property-pane@1.21.1"
)

Write-Host "Installing SPFx runtime dependencies..." -ForegroundColor Blue
foreach ($package in $spfxDependencies) {
    Write-Host "Installing: $package" -ForegroundColor Cyan
    npm install $package --save --save-exact --legacy-peer-deps
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install $package"
        exit 1
    }
}

# Install SPFx dev dependencies
$spfxDevDependencies = @(
    "@microsoft/eslint-config-spfx@1.21.1",
    "@microsoft/eslint-plugin-spfx@1.21.1",
    "@microsoft/sp-build-web@1.21.1",
    "@microsoft/sp-module-interfaces@1.21.1",
    "spfx-fast-serve-helpers@~1.21.0",
    "typescript@5.3"
)

Write-Host "Installing SPFx development dependencies..." -ForegroundColor Blue
foreach ($package in $spfxDevDependencies) {
    Write-Host "Installing: $package" -ForegroundColor Cyan
    npm install $package --save-dev --save-exact --legacy-peer-deps
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install $package"
        exit 1
    }
}

# Install other dependencies (keeping existing versions unless they cause conflicts)
# Read other dependencies from package.json
$packageJson = Get-Content "package.json" | ConvertFrom-Json
$otherDependencies = @()

if ($packageJson.dependencies) {
    foreach ($dep in $packageJson.dependencies.PSObject.Properties) {
        # Skip SPFx dependencies already handled above
        if ($spfxDependencies -notcontains "$($dep.Name)@$($dep.Value)") {
            $otherDependencies += "$($dep.Name)@$($dep.Value)"
        }
    }
}

Write-Host "Installing other runtime dependencies..." -ForegroundColor Blue
foreach ($package in $otherDependencies) {
    Write-Host "Installing: $package" -ForegroundColor Cyan
    npm install $package --save --legacy-peer-deps
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to install $package - you may need to update this manually"
    }
}

# Install other dev dependencies
$otherDevDependencies = @()
if ($packageJson.devDependencies) {
    foreach ($dep in $packageJson.devDependencies.PSObject.Properties) {
        # Skip SPFx dev dependencies already handled above
        if ($spfxDevDependencies -notcontains "$($dep.Name)@$($dep.Value)") {
            $otherDevDependencies += "$($dep.Name)@$($dep.Value)"
        }
    }
}

Write-Host "Installing other development dependencies..." -ForegroundColor Blue
foreach ($package in $otherDevDependencies) {
    Write-Host "Installing: $package" -ForegroundColor Cyan
    npm install $package --save-dev --legacy-peer-deps
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to install $package - you may need to update this manually"
    }
}
npm install ajv --save-dev  # prevent "Error: Cannot find module 'ajv/dist/core'"

# Run npm audit to check for vulnerabilities
Write-Host "Running security audit..." -ForegroundColor Blue
npm audit --audit-level=moderate

# Final verification
Write-Host "Verifying installation..." -ForegroundColor Green
if (Test-Path "node_modules") {
    $nodeModulesCount = (Get-ChildItem "node_modules" | Measure-Object).Count
    Write-Host "Installation complete! $nodeModulesCount packages installed." -ForegroundColor Green
} else {
    Write-Error "Installation failed - node_modules directory not found"
    exit 1
}

# Display final status
Write-Host "`n=== UPGRADE COMPLETE ===" -ForegroundColor Green
Write-Host "SPFx project has been upgraded to v1.21.1" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review package.json for any version conflicts" -ForegroundColor White
Write-Host "2. Run 'npm run build' to test the build" -ForegroundColor White
Write-Host "3. Run 'npm run serve' to test the development server" -ForegroundColor White
Write-Host "4. Update any TypeScript/ESLint configuration if needed" -ForegroundColor White

if (-not $SkipBackup) {
    Write-Host "5. Remove backup file if everything works correctly" -ForegroundColor White
}

Write-Host "`nUpgrade script completed successfully!" -ForegroundColor Green
