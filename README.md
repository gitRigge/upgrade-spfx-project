# upgrade_spfx_v1.21.1.ps1
## Overview

`upgrade_spfx_v1.21.1.ps1` is a PowerShell script designed to automate the upgrade process for SharePoint Framework (SPFx) projects to version 1.21.1. It streamlines dependency updates, configuration changes, and other required steps for a successful migration.

## Features

- Automatically updates SPFx dependencies to v1.21.1
- Checks for outdated packages and suggests updates
- Backs up existing configuration files before modification
- Provides detailed logs of the upgrade process

## Prerequisites

- PowerShell 5.1 or later
- Node.js (LTS version recommended)
- npm installed
- Existing SPFx project

## Usage

1. Open PowerShell and navigate to your project folder.
2. Run the script:

    ```powershell
    .\upgrade_spfx_v1.21.1.ps1
    ```

3. Follow the on-screen instructions.

## Notes

- Review the changes after running the script.
- Test your project thoroughly after the upgrade.
- Refer to the [SPFx release notes](https://docs.microsoft.com/sharepoint/dev/spfx/release-1.21.1) for additional guidance.

## License

This script is provided under the MIT License.