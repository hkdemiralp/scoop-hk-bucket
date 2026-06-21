param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$PackageName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-OptionalStringProperty {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Object,

        [Parameter(Mandatory)]
        [string]$Name,

        [string]$Default = ""
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $Default
    }

    return [string]$property.Value
}

function Resolve-Template {
    param(
        [Parameter(Mandatory)]
        [string]$Template,

        [Parameter(Mandatory)]
        [hashtable]$Values
    )

    $result = $Template
    foreach ($key in $Values.Keys) {
        $result = $result.Replace("{$key}", [string]$Values[$key])
    }

    return $result
}

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ConfigPath = Join-Path $RepoRoot "scripts/packages.json"

if (-not (Test-Path $ConfigPath)) {
    throw "Package config not found: $ConfigPath"
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

function Get-PackageNames {
    param($ConfigObject)

    $ConfigObject.PSObject.Properties.Name
}

function Update-ScoopManifest {
    param(
        [string]$Name,
        [object]$PackageConfig
    )

    if (-not $PackageConfig.repo) {
        throw "Package '$Name' is missing 'repo' in packages.json"
    }

    if (-not $PackageConfig.manifest) {
        throw "Package '$Name' is missing 'manifest' in packages.json"
    }

    if (-not $PackageConfig.asset_template) {
        throw "Package '$Name' is missing 'asset_template' in packages.json"
    }

    $repo = [string]$PackageConfig.repo
    $manifestRelativePath = [string]$PackageConfig.manifest
    $assetTemplate = [string]$PackageConfig.asset_template
    $tagPrefix = Get-OptionalStringProperty -Object $PackageConfig -Name "tag_prefix" -Default ""
    $versionTemplate = Get-OptionalStringProperty -Object $PackageConfig -Name "version_template" -Default "{tag}"

    $apiUrl = "https://api.github.com/repos/$repo/releases/latest"

    Write-Host "==> $Name"
    Write-Host "Repo: $repo"

    $release = Invoke-RestMethod `
        -Uri $apiUrl `
        -Headers @{
            "Accept" = "application/vnd.github+json"
            "User-Agent" = "scoop-hk-bucket-manifest-updater"
        }

    $rawTag = [string]$release.tag_name
    if (-not $rawTag) {
        throw "Latest release for '$repo' does not include tag_name"
    }

    $tag = $rawTag
    if ($tagPrefix -and $tag.StartsWith($tagPrefix)) {
        $tag = $tag.Substring($tagPrefix.Length)
    }

    $version = Resolve-Template -Template $versionTemplate -Values @{
        tag = $tag
        raw_tag = $rawTag
    }

    $assetName = Resolve-Template -Template $assetTemplate -Values @{
        tag = $tag
        raw_tag = $rawTag
        version = $version
    }
    $asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1

    if (-not $asset) {
        $availableAssets = ($release.assets | ForEach-Object { $_.name }) -join ", "
        throw "Asset '$assetName' not found for '$Name'. Available assets: $availableAssets"
    }

    $downloadUrl = [string]$asset.browser_download_url
    if (-not $downloadUrl) {
        throw "Asset '$assetName' does not include browser_download_url"
    }

    $digest = [string]$asset.digest
    if (-not $digest) {
        throw "Asset '$assetName' does not include digest. Cannot update hash from GitHub asset digest."
    }

    if (-not $digest.StartsWith("sha256:")) {
        throw "Unsupported digest format for '$assetName': $digest"
    }

    $hash = $digest.Substring("sha256:".Length)

    $manifestPath = Join-Path $RepoRoot $manifestRelativePath
    if (-not (Test-Path $manifestPath)) {
        throw "Manifest not found for '$Name': $manifestPath"
    }

    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

    $oldVersion = [string]$manifest.version
    $oldUrl = [string]$manifest.url
    $oldHash = [string]$manifest.hash

    if ($oldVersion -eq $version -and $oldUrl -eq $downloadUrl -and $oldHash -eq $hash) {
        Write-Host "Already up to date: $manifestRelativePath"
        Write-Host "Version: $version"
        Write-Host ""
        return
    }
    
    $manifest.version = $version
    $manifest.url = $downloadUrl
    $manifest.hash = $hash
    
    $json = $manifest | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText(
        (Resolve-Path $manifestPath),
        $json + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host "Updated: $manifestRelativePath"
    Write-Host "Version: $oldVersion -> $version"
    Write-Host "Hash: $hash"
    Write-Host ""
}

if ($PackageName -eq "all-packages") {
    $names = Get-PackageNames -ConfigObject $config
} else {
    $names = @($PackageName)
}

foreach ($name in $names) {
    $packageProperty = $config.PSObject.Properties[$name]

    if (-not $packageProperty) {
        $available = (Get-PackageNames -ConfigObject $config) -join ", "
        throw "Unknown package '$name'. Available packages: $available"
    }

    Update-ScoopManifest -Name $name -PackageConfig $packageProperty.Value
}

Write-Host "Done."
Write-Host ""
git -C $RepoRoot diff -- bucket scripts
