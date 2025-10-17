#!/usr/bin/env pwsh
# Windows PowerShell runner for Puppet

param(
    [string]$Action
)

$PULL = '.pull'
$SUB = '.submodules'
$DUMP_DIR = $PSScriptRoot

# Handle clean action
if ($Action -eq 'clean') {
    Write-Host "pull and update submodules"
    Remove-Item -Path $PULL -ErrorAction SilentlyContinue
    Remove-Item -Path $SUB -ErrorAction SilentlyContinue
    exit 0
}

# Check if we need to pull
$pullFile = Join-Path $DUMP_DIR $PULL
$pullNeeded = $false

if (Test-Path $pullFile) {
    $pullAge = (Get-Date) - (Get-Item $pullFile).LastWriteTime
    if ($pullAge.TotalDays -gt 1) {
        $pullNeeded = $true
        Remove-Item $pullFile
    }
} else {
    $pullNeeded = $true
}

if ($pullNeeded) {
    Write-Host "pull latest changes"
    git pull
    New-Item -ItemType File -Path $pullFile -Force | Out-Null
}

# Check if we need to update submodules
$subFile = Join-Path $DUMP_DIR $SUB
$subNeeded = $false

if (Test-Path $subFile) {
    $subAge = (Get-Date) - (Get-Item $subFile).LastWriteTime
    if ($subAge.TotalDays -gt 7) {
        $subNeeded = $true
        Remove-Item $subFile
    }
} else {
    $subNeeded = $true
}

if ($subNeeded) {
    Write-Host "update puppet modules"

    # Install required Puppet modules
    puppet module install puppetlabs-stdlib --force
    puppet module install puppetlabs-vcsrepo --force
    puppet module install puppetlabs-chocolatey --force

    New-Item -ItemType File -Path $subFile -Force | Out-Null
}

# Detect Puppet installation paths
$puppetModules = ""
if (Test-Path "C:\ProgramData\PuppetLabs\code\modules") {
    $puppetModules = ";C:\ProgramData\PuppetLabs\code\modules"
} elseif (Test-Path "$env:ProgramFiles\Puppet Labs\Puppet\puppet\modules") {
    $puppetModules = ";$env:ProgramFiles\Puppet Labs\Puppet\puppet\modules"
}

# Source environment variables if available
$keysEnv = "$env:USERPROFILE\.keys\env"
if (Test-Path $keysEnv) {
    Write-Host "Loading environment from $keysEnv"
    Get-Content $keysEnv | ForEach-Object {
        if ($_ -match '^export\s+(\w+)=(.*)$') {
            $name = $matches[1]
            $value = $matches[2] -replace '^[''"]|[''"]$'
            Set-Item -Path "env:$name" -Value $value
        }
    }
}

# Build the modulepath
$modulePath = Join-Path $PSScriptRoot "modules"
$modulePath = "$modulePath$puppetModules"

# Run puppet apply
Write-Host "Running puppet apply..."
$manifestPath = Join-Path $PSScriptRoot "manifests\hosts.pp"

$puppetArgs = @(
    'apply',
    '-v',
    '--modulepath', $modulePath,
    $manifestPath
)

# Add any additional arguments passed to this script
$puppetArgs += $args

& puppet $puppetArgs
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Host "Puppet apply failed with exit code: $exitCode" -ForegroundColor Red
    exit $exitCode
}

Write-Host "Puppet apply completed successfully!" -ForegroundColor Green
