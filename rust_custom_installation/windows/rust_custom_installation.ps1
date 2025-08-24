<#
.SYNOPSIS
    Installs Rust to a specific custom directory and configures the user environment
    to make it permanently available.

.DESCRIPTION
    This script automates the installation of Rust on Windows to a user-defined path.
    - It sets the RUSTUP_HOME and CARGO_HOME environment variables permanently for the current user.
    - It adds the Cargo bin directory to the user's PATH variable, making `rustc` and `cargo` accessible from any new terminal.
    - It downloads and runs the rustup-init.exe installer non-interactively.
    - It cleans up the installer after completion.

.PARAMETER InstallPath
    The absolute path to the directory where Rust should be installed.
    The script will create .cargo and .rustup subdirectories inside this path.
    Example: 'D:\Development\Rust'

.EXAMPLE
    .\Install-Rust-Custom.ps1 -InstallPath "D:\tools\rust"
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the absolute path for the Rust installation.")]
    [string]$InstallPath
)

# --- 1. Validate Input and Define Paths ---
Write-Host "--- Rust Custom Installation Script ---" -ForegroundColor Yellow

# Resolve the path to ensure it's absolute and clean
$ResolvedPath = Resolve-Path -Path $InstallPath -ErrorAction SilentlyContinue
if (-not $ResolvedPath) {
    Write-Host "Creating installation directory: $InstallPath"
    New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
} else {
    Write-Host "Using existing directory: $ResolvedPath"
}

# Define the paths for Cargo and Rustup
$CargoHome = Join-Path -Path $InstallPath -ChildPath ".cargo"
$RustupHome = Join-Path -Path $InstallPath -ChildPath ".rustup"
$CargoBinPath = Join-Path -Path $CargoHome -ChildPath "bin"

Write-Host "  - Cargo Home will be set to: $CargoHome"
Write-Host "  - Rustup Home will be set to: $RustupHome"


# --- 2. Set Permanent User Environment Variables ---
Write-Host "`nSetting permanent environment variables for your user account..." -ForegroundColor Cyan

try {
    # Set RUSTUP_HOME and CARGO_HOME
    [System.Environment]::SetEnvironmentVariable("RUSTUP_HOME", $RustupHome, "User")
    [System.Environment]::SetEnvironmentVariable("CARGO_HOME", $CargoHome, "User")
    Write-Host "  [v] Set RUSTUP_HOME and CARGO_HOME."

    # Add the cargo bin directory to the user's PATH
    $CurrentUserPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $PathArray = $CurrentUserPath -split ';' -ne '' # Filter out empty entries
    
    if ($PathArray -notcontains $CargoBinPath) {
        $NewPath = "$CargoBinPath;$CurrentUserPath"
        [System.Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
        Write-Host "  [v] Added '$CargoBinPath' to your user PATH."
    } else {
        Write-Host "  [i] Cargo bin directory is already in your user PATH."
    }
} catch {
    Write-Error "Failed to set environment variables. Please run PowerShell as Administrator if you intended to set system-wide variables."
    exit 1
}


# --- 3. Set Session Variables for this Script to Use ---
# This is necessary because the permanent variables are only loaded in new terminals.
$env:RUSTUP_HOME = $RustupHome
$env:CARGO_HOME = $CargoHome
$env:PATH = "$CargoBinPath;" + $env:PATH


# --- 4. Download and Run the Installer ---
$InstallerUrl = "https://win.rustup.rs/x86_64"
$InstallerPath = Join-Path -Path $env:TEMP -ChildPath "rustup-init.exe"

Write-Host "`nDownloading rustup-init.exe from $InstallerUrl..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing
    Write-Host "  [v] Download complete."
} catch {
    Write-Error "Failed to download the installer. Please check your internet connection."
    exit 1
}

Write-Host "`nRunning the Rust installer non-interactively..." -ForegroundColor Cyan
Write-Host "This may take a few minutes..."
try {
    # We use --no-modify-path because we've already manually handled the PATH environment variable.
    # The -y flag accepts all default prompts.
    Start-Process -FilePath $InstallerPath -ArgumentList "-y --no-modify-path" -Wait -NoNewWindow
    Write-Host "  [v] Rust installation successful!" -ForegroundColor Green
} catch {
    Write-Error "The Rust installer failed to run."
    exit 1
} finally {
    # --- 5. Cleanup ---
    if (Test-Path $InstallerPath) {
        Remove-Item -Path $InstallerPath -Force
        Write-Host "`n  [v] Cleaned up installer file."
    }
}


# --- 6. Final Instructions ---
Write-Host "`n--------------------------------------------------" -ForegroundColor Yellow
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "Rust has been installed in: $InstallPath"
Write-Host ""
Write-Host "IMPORTANT: You must restart any open terminals, code editors (like VS Code)," -ForegroundColor Magenta
Write-Host "and log out/in for the new PATH to take full effect everywhere." -ForegroundColor Magenta
Write-Host "--------------------------------------------------"
Write-Host "In a NEW terminal, you can verify the installation by running:"
Write-Host "  rustc --version"
Write-Host "  cargo --version"