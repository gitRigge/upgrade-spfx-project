<#
.SYNOPSIS
Upgrades an existing SharePoint Framework (SPFx) project to version 1.22.1
by performing a clean installation of dependencies.

.DESCRIPTION
This script checks for the presence of Node.js v22 and npm, creates a backup
of the package.json file (unless skipped), cleans existing installations,
updates the package.json to set the Node.js engine to v22, and installs the
required SPFx dependencies and dev dependencies for version 1.22.1.
It also attempts to install other existing dependencies and runs an npm audit
to check for vulnerabilities.

.PARAMETER SkipBackup
Specifies whether to skip the backup of the package.json file before making changes.

.EXAMPLE
upgrade_spfx_v1.22.1.ps1 -SkipBackup

.NOTES
Based on https://learn.microsoft.com/en-us/sharepoint/dev/spfx/toolchain/migrate-gulptoolchain-hefttoolchain

.LICENSE
MIT License
Copyright (c) 2026 Roland Rickborn (r_2@gmx.net)

#>

param(
    [switch]$SkipBackup = $false
)

Write-Host "Starting SPFx upgrade to v1.22.1..." -ForegroundColor Green
Write-Host "Working directory: $(Get-Location)" -ForegroundColor Yellow

function Get-ObjectMember {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [PSCustomObject]$obj
    )
    $obj | Get-Member -MemberType NoteProperty | ForEach-Object {
        $key = $_.Name
        [PSCustomObject]@{Key = $key; Value = $obj."$key"}
    }
}

function Add-ObjectMember {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [PSCustomObject]$obj,
        [Parameter(Mandatory=$true)]
        [string]$Key,
        [Parameter(Mandatory=$true)]
        [object]$Value
    )
    process {
        if (-not $obj) { return }
        # If property exists, set it; otherwise add it as a NoteProperty
        if ($obj.PSObject.Properties[$Key]) {
            $obj.$Key = $Value
        } else {
            $obj | Add-Member -NotePropertyName $Key -NotePropertyValue $Value -Force
        }
        # Emit the modified object for pipeline compatibility
        $obj
    }
}

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

# Check if heft is installed
try {
    $heftVersion = "$(npm ls -g | Select-String -Pattern '@rushstack/heft' -CaseSensitive -SimpleMatch)".Trim().Split("@")[-1]
    Write-Host "Using Heft CLI version: $heftVersion" -ForegroundColor Blue
} catch {
    Write-Warning "Heft CLI is not installed globally. Installing heft..."
    npm install -g @rushstack/heft
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install @rushstack/heft. Please install it manually."
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

# Uninstall Gulp toolchain dependencies
Write-Host "Uninstall Gulp toolchain dependencies" -ForegroundColor Green
npm uninstall @microsoft/sp-build-web ajv gulp
npm uninstall @microsoft/rush-stack-compiler-4.7
npm uninstall @microsoft/rush-stack-compiler-5.3

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

# Set SPFx v1.22.1 dependencies
Write-Host "Set SPFx v1.22.1 dependencies..." -ForegroundColor Green

# Set main SPFx dependencies
$spfxDependencies = @(
    "@microsoft/sp-adaptive-card-extension-base",
    "@microsoft/sp-core-library",
    "@microsoft/sp-property-pane"
)

$json.dependencies | Get-ObjectMember | foreach {
    $_key = $_.Key
    if ($spfxDependencies -contains $_.Key) {
        $json.dependencies.$_key = '1.22.1'
    }
}

# Set SPFx dev dependencies
$spfxDevDependencies = @(
    "@microsoft/eslint-config-spfx",
    "@microsoft/eslint-plugin-spfx",
    "@microsoft/sp-module-interfaces"
)

$json.devDependencies | Get-ObjectMember | foreach {
    $_key = $_.Key
    if ($spfxDevDependencies -contains $_.Key) {
        $json.devDependencies.$_key = '1.22.1'
    }
}

# Set Heft toolchain dependencies
Write-Host "Set Heft toolchain dependencies..." -ForegroundColor Green

$newSpfxDevDependencies = @(
    "@microsoft/spfx-web-build-rig@1.22.1",
    "@microsoft/spfx-heft-plugins@1.22.1",
    "@rushstack/heft@1.1.2",
    "@types/heft-jest@1.0.2",
    "@typescript-eslint/parser@8.46.2"
)

foreach ($dependency in $newSpfxDevDependencies) {
    $key = $dependency.Split('@')[0]
    $value = $dependency.Split('@')[1]
    if ($dependency.Split('@').Count -eq 3) {
        $key = "@$($dependency.Split('@')[1])"
        $value = $dependency.Split('@')[2]
    }
    $null = Add-ObjectMember -obj $json.devDependencies -Key $key -Value $value
}

$json.devDependencies.'@rushstack/eslint-config' = '4.5.2'

# Set Typescript dependencies to v5.8
Write-Host "Set Typescript dependencies to v5.8..." -ForegroundColor Green
$json.devDependencies.typescript = '~5.8.0'

# Update npm scripts in package.json
Write-Host "Update npm scripts..." -ForegroundColor Green
$json.scripts.build = "heft build --clean"
$json.scripts.clean = "heft clean"
if ($json.scripts.test -eq "gulp test") {
    $json.scripts.test = "heft test"
}

# Add additional scripts to package.json
Write-Host "Add additional scripts..." -ForegroundColor Green

$additionalScript = @{
    "test-only" = "heft run --only test --"
    "deploy" = "heft dev-deploy"
    "start" = "heft start --clean"
    "build-watch" = "heft build --lite"
    "package-solution" = "heft package-solution"
    "deploy-azure-storage" = "heft deploy-azure-storage"
    "eject-webpack" = "heft eject-webpack"
    "trust-dev-cert" = "heft trust-dev-cert"
    "untrust-dev-cert" = "heft untrust-dev-cert"
}

foreach ($scriptKey in $additionalScript.Keys) {
    $null = Add-ObjectMember -obj $json.scripts -Key $scriptKey -Value $additionalScript[$scriptKey]
}

# Write package.json
Write-Host "Writing package.json..." -ForegroundColor Blue
$json | ConvertTo-Json -Depth 10 | Set-Content "package.json"

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Blue
npm install

# Update the ESLint configuration
if (-not $SkipBackup) {
    Write-Host "Creating backup of .eslintrc.js..." -ForegroundColor Blue
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Copy-Item ".eslintrc.js" ".eslintrc.js.backup_$timestamp"
    Write-Host "Backup created: .eslintrc.js.backup_$timestamp" -ForegroundColor Green
}
Write-Host "Updating ESLint configuration..." -ForegroundColor Blue
$content = Get-Content ".eslintrc.js" -Raw
$tabs = ""
if ($content -match "([\W]*)'@rushstack/hoist-jest-mock': 1,") {
    $tabs = $matches[1]
}
$content = ($content -replace "'@rushstack/hoist-jest-mock': 1,", "'@rushstack/hoist-jest-mock': 1,$tabs// Require chunk names for dynamic imports in SPFx projects. https://www.npmjs.com/package/@rushstack/eslint-plugin$tabs'@rushstack/import-requires-chunk-name': 1,$tabs// Ensure that React components rendered with ReactDOM.render() are unmounted with ReactDOM.unmountComponentAtNode(). https://www.npmjs.com/package/@rushstack/eslint-plugin$tabs'@rushstack/pair-react-dom-render-unmount': 1,")
$content = ($content -replace "'@microsoft/spfx/import-requires-chunk-name': 1,", "")
$content -replace "'@microsoft/spfx/pair-react-dom-render-unmount': 1", "" | Set-Content ".eslintrc.js"
Write-Host "ESLint configuration file updated" -ForegroundColor Green

# Run npm audit to check for vulnerabilities
Write-Host "Running security audit..." -ForegroundColor Blue
npm audit --audit-level=moderate

# Add the SPFx Heft rig
Write-Host "Add the SPFx Heft rig..." -ForegroundColor Blue
$rigJson = @{
    "`$schema" = "https://developer.microsoft.com/json-schemas/rig-package/rig.schema.json"
    "rigPackageName" = "@microsoft/spfx-web-build-rig"
}
$rigJson | ConvertTo-Json | Set-Content "./config/rig.json"

# Replace the Sass configuration
if (-not $SkipBackup) {
    Write-Host "Creating backup of config/sass.json..." -ForegroundColor Blue
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Copy-Item "./config/sass.json" "./config/sass.json.backup_$timestamp"
    Write-Host "Backup created: config/sass.json.backup_$timestamp" -ForegroundColor Green
}
Write-Host "Replace the Sass configuration..." -ForegroundColor Blue
$sassJson = @{
  "`$schema" = "https://developer.microsoft.com/json-schemas/heft/v0/heft-sass-plugin.schema.json"
  "extends" = "@microsoft/spfx-web-build-rig/profiles/default/config/sass.json"
}
$sassJson | ConvertTo-Json | Set-Content "./config/sass.json" -Force

# Add the Heft TypeScript Plugin configuration
Write-Host "Add the Heft TypeScript Plugin configuration..." -ForegroundColor Blue
$typescriptJson = @{
  "extends" = "@microsoft/spfx-web-build-rig/profiles/default/config/typescript.json"
  "staticAssetsToCopy" = @{
    "fileExtensions" = @(".resx", ".jpg", ".png", ".woff", ".eot", ".ttf", ".svg", ".gif")
    "includeGlobs" = @("webparts/*/loc/*.js")
  }
}
$typescriptJson | ConvertTo-Json | Set-Content "./config/typescript.json"

# Replace the TypeScript compiler configuration
if (-not $SkipBackup) {
    Write-Host "Creating backup of tsconfig.json..." -ForegroundColor Blue
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Copy-Item "tsconfig.json" "tsconfig.json.backup_$timestamp"
    Write-Host "Backup created: tsconfig.json.backup_$timestamp" -ForegroundColor Green
}
Write-Host "Replace the TypeScript compiler configuration..." -ForegroundColor Blue
$json = Get-Content "tsconfig.json" | ConvertFrom-Json
$json.extends = "./node_modules/@microsoft/spfx-web-build-rig/profiles/default/tsconfig-base.json"
$json | ConvertTo-Json -Depth 10 | Set-Content "tsconfig.json"

# Delete gulpfile
$gulpFile = Get-Content "gulpfile.js"
if (($gulpFile.Count -eq 16) -and ($gulpFile[-1] -eq "build.initialize(require('gulp'));")) {
    if (-not $SkipBackup) {
        Write-Host "Creating backup of gulpfile.js..." -ForegroundColor Blue
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        Copy-Item "gulpfile.js" "gulpfile.js.backup_$timestamp"
        Write-Host "Backup created: gulpfile.js.backup_$timestamp" -ForegroundColor Green
    }
    Write-Host "Delete gulpfile..." -ForegroundColor Blue
    Remove-Item "gulpfile.js" -Force
}
else {
    Write-Host "gulpfile.js seems to be customized - delete it manually!" -ForegroundColor Red
}

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
Write-Host "SPFx project has been upgraded to v1.22.1 including Heft toolchain" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review package.json for any version conflicts" -ForegroundColor White
Write-Host "2. Run 'heft build --clean' to test the build" -ForegroundColor White
Write-Host "3. Run 'npm run serve' to test the development server" -ForegroundColor White

if (-not $SkipBackup) {
    Write-Host "4. Remove backup file if everything works correctly" -ForegroundColor White
}

Write-Host "`nUpgrade script completed successfully!" -ForegroundColor Green
