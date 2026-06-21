Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ManagedApps = @{
    "bettertrumpet"      = @{
        ProcessName  = "BetterTrumpet"
        StartCommand = "bettertrumpet"
    }

    "super-productivity" = @{
        ProcessName  = "Super Productivity"
        StartCommand = "$env:SCOOP\apps\super-productivity\current\Super Productivity.exe"
    }
}

function Get-OutdatedScoopApps {
    $statusOutput = scoop status 2>&1 | Out-String

    $apps = @()

    foreach ($line in ($statusOutput -split "`r?`n")) {
        if ($line -match "^\s*$") { continue }
        if ($line -match "^WARN\s+") { continue }
        if ($line -match "^Name\s+") { continue }
        if ($line -match "^-+\s+") { continue }

        $parts = $line -split "\s+"
        if ($parts.Count -ge 3) {
            $apps += $parts[0].ToLowerInvariant()
        }
    }

    return $apps
}

function Stop-ManagedAppIfRunning {
    param(
        [string]$PackageName,
        [hashtable]$AppConfig
    )

    $processName = [string]$AppConfig.ProcessName
    $runningProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue

    if (-not $runningProcesses) {
        Write-Host "$PackageName is not running."
        return $false
    }

    Write-Host "$PackageName is running. Closing before update..."
    $runningProcesses | Stop-Process -Force
    Start-Sleep -Seconds 2

    return $true
}

function Start-ManagedApp {
    param(
        [string]$PackageName,
        [hashtable]$AppConfig
    )

    $startCommand = [string]$AppConfig.StartCommand

    Write-Host "Restarting $PackageName..."
    Start-Process $startCommand
}

Write-Host "Updating Scoop buckets..."
scoop update

Write-Host ""
Write-Host "Checking outdated Scoop apps..."
$outdatedApps = @(Get-OutdatedScoopApps)

if ($outdatedApps.Count -eq 0) {
    Write-Host "All Scoop apps are up to date."
    exit 0
}

Write-Host "Outdated apps:"
$outdatedApps | ForEach-Object { Write-Host "- $_" }

$restartAfterUpdate = @{}

foreach ($packageName in $ManagedApps.Keys) {
    if ($outdatedApps -contains $packageName) {
        $wasRunning = Stop-ManagedAppIfRunning -PackageName $packageName -AppConfig $ManagedApps[$packageName]
        $restartAfterUpdate[$packageName] = $wasRunning

        Write-Host "Updating managed app: $packageName"
        scoop update $packageName
    }
}

$managedNames = @($ManagedApps.Keys)
$remainingApps = @($outdatedApps | Where-Object { $managedNames -notcontains $_ })

if ($remainingApps.Count -gt 0) {
    Write-Host ""
    Write-Host "Updating remaining apps..."

    foreach ($packageName in $remainingApps) {
        Write-Host "Updating app: $packageName"
        scoop update $packageName
    }
}

foreach ($packageName in $restartAfterUpdate.Keys) {
    if ($restartAfterUpdate[$packageName]) {
        Start-ManagedApp -PackageName $packageName -AppConfig $ManagedApps[$packageName]
    }
}

Write-Host ""
Write-Host "Done."
