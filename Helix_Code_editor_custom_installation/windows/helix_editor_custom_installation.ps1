<#
.SYNOPSIS
    Installs the latest version of the Helix editor to a specific custom directory
    and makes it permanently available in the user's PATH.

.DESCRIPTION
    This script automates the installation of Helix on Windows to a user-defined path.
    - It automatically finds the latest version of Helix from the official GitHub releases.
    - It downloads and extracts the editor to a clean 'helix' subdirectory inside your chosen path.
    - It adds this directory to the user's PATH variable, making the `hx` command accessible from any new terminal.
    - It cleans up the downloaded archive after completion.

.PARAMETER InstallPath
    The absolute path to the directory where the 'helix' folder should be created.
    Example: 'D:\Tools' will result in Helix being installed to 'D:\Tools\helix'.

.EXAMPLE
    .\Install-Helix-Custom.ps1 -InstallPath "D:\DevTools"
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the parent directory for the Helix installation.")]
    [string]$InstallPath
)

# --- 1. Initial Setup and Validation ---
Write-Host "--- Helix Custom Installation Script ---" -ForegroundColor Yellow

# Ensure the parent installation directory exists
if (-not (Test-Path -Path $InstallPath -PathType Container)) {
    Write-Host "Creating parent directory: $InstallPath"
    New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
}

# Define the final target directory for Helix
$TargetDir = Join-Path -Path $InstallPath -ChildPath "helix"
Write-Host "Helix will be installed to: $TargetDir"

# Check if Expand-Archive is available
if (-not (Get-Command Expand-Archive -ErrorAction SilentlyContinue)) {
    Write-Error "This script requires PowerShell 5.0 or newer for the 'Expand-Archive' command."
    exit 1
}


# --- 2. Find and Download the Latest Helix Release ---
$ApiUrl = "https://api.github.com/repos/helix-editor/helix/releases/latest"
Write-Host "`nFetching latest release information from GitHub..." -ForegroundColor Cyan

try {
    $releaseInfo = Invoke-RestMethod -Uri $ApiUrl
    $asset = $releaseInfo.assets | Where-Object { $_.name -like '*x86_64-windows.zip' }
    if (-not $asset) {
        throw "Could not find a Windows x86_64 ZIP asset in the latest release."
    }
    $downloadUrl = $asset.browser_download_url
    $fileName = $asset.name
    Write-Host "  [v] Found latest version: $($releaseInfo.tag_name)"
} catch {
    Write-Error "Failed to fetch release information from GitHub. Error: $_"
    exit 1
}

$downloadPath = Join-Path -Path $env:TEMP -ChildPath $fileName
Write-Host "Downloading $fileName..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing
    Write-Host "  [v] Download complete."
} catch {
    Write-Error "Failed to download the Helix archive. Please check your internet connection."
    exit 1
}


# --- 3. Install Helix ---
Write-Host "`nInstalling Helix to $TargetDir..." -ForegroundColor Cyan

# Clean up any previous installation in the target directory for a fresh install
if (Test-Path $TargetDir) {
    Write-Host "  - Removing existing directory for a clean installation..."
    Remove-Item -Path $TargetDir -Recurse -Force
}
New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null

# Extract the archive to a temporary folder first
$tempExtractPath = Join-Path -Path $env:TEMP -ChildPath "helix-extract-temp"
if (Test-Path $tempExtractPath) {
    Remove-Item -Path $tempExtractPath -Recurse -Force
}
Expand-Archive -Path $downloadPath -DestinationPath $tempExtractPath
Write-Host "  [v] Archive extracted."

# The files are inside a versioned subfolder, so we need to move them up
$extractedSubfolder = Get-ChildItem -Path $tempExtractPath | Select-Object -First 1
Move-Item -Path ($extractedSubfolder.FullName + "\*") -Destination $TargetDir
Write-Host "  [v] Files moved to the final destination."


# --- 4. Add to User PATH Environment Variable ---
Write-Host "`nAdding Helix to your permanent user PATH..." -ForegroundColor Cyan
try {
    $CurrentUserPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $PathArray = $CurrentUserPath -split ';' -ne '' # Filter out empty entries
    
    if ($PathArray -notcontains $TargetDir) {
        $NewPath = "$TargetDir;$CurrentUserPath"
        [System.Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
        Write-Host "  [v] Added '$TargetDir' to your user PATH."
    } else {
        Write-Host "  [i] Helix directory is already in your user PATH."
    }
} catch {
    Write-Error "Failed to set the PATH environment variable."
    exit 1
}


# --- 5. Cleanup ---
Write-Host "`nCleaning up temporary files..." -ForegroundColor Cyan
Remove-Item -Path $downloadPath -Force
Remove-Item -Path $tempExtractPath -Recurse -Force
Write-Host "  [v] Cleanup complete."


# --- 6. Final Instructions ---
Write-Host "`n--------------------------------------------------" -ForegroundColor Yellow
Write-Host "Helix Installation Complete!" -ForegroundColor Green
Write-Host "Helix has been installed in: $TargetDir"
Write-Host ""
Write-Host "IMPORTANT: You must restart any open terminals, code editors, and" -ForegroundColor Magenta
Write-Host "other applications for the new PATH to take effect." -ForegroundColor Magenta
Write-Host "--------------------------------------------------"
Write-Host "In a NEW terminal, you can verify the installation by running:"
Write-Host "  hx --version"
Write-Host "  where hx"
Write-Host "To check your environment for language servers, run:"
Write-Host "  hx --health"