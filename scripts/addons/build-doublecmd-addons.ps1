$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$SourcesPath = Join-Path $PSScriptRoot "doublecmd-addons.sources.json"
$BuildRoot = Join-Path $RepoRoot "build\doublecmd-addons"
$DownloadRoot = Join-Path $BuildRoot "downloads"
$ExtractRoot = Join-Path $BuildRoot "extract"
$StageRoot = Join-Path $BuildRoot "stage"

function ConvertTo-NormalizedPath {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    return ($Path -replace "/", [System.IO.Path]::DirectorySeparatorChar)
}

function Assert-RequiredFiles {
    param(
        [Parameter(Mandatory)]
        [string] $Root,

        [Parameter(Mandatory)]
        [object[]] $RequiredFiles,

        [Parameter(Mandatory)]
        [string] $SourceName
    )

    foreach ($requiredFile in $RequiredFiles) {
        $relativePath = ConvertTo-NormalizedPath -Path $requiredFile
        $fullPath = Join-Path $Root $relativePath

        if (-not (Test-Path $fullPath)) {
            throw "Missing required file for '$SourceName': $requiredFile"
        }
    }
}

function Copy-SourceToStage {
    param(
        [Parameter(Mandatory)]
        [string] $ExtractedRoot,

        [Parameter(Mandatory)]
        [string] $StageRoot,

        [Parameter(Mandatory)]
        [string] $TargetDir
    )

    $targetPath = Join-Path $StageRoot (ConvertTo-NormalizedPath -Path $TargetDir)

    if (Test-Path $targetPath) {
        Remove-Item $targetPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $targetPath -Force | Out-Null

    Get-ChildItem -Path $ExtractedRoot -Force |
        Copy-Item -Destination $targetPath -Recurse -Force
}

if (-not (Test-Path $SourcesPath)) {
    throw "Sources file not found: $SourcesPath"
}

$sourcesConfig = Get-Content $SourcesPath -Raw | ConvertFrom-Json
$sources = @($sourcesConfig.sources | Where-Object { $_.status -eq "core" })

if ($sources.Count -eq 0) {
    throw "No core addon sources found."
}

Remove-Item $BuildRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $DownloadRoot, $ExtractRoot, $StageRoot -Force | Out-Null

foreach ($source in $sources) {
    Write-Host "==> $($source.name) $($source.version)"

    $downloadPath = Join-Path $DownloadRoot ([System.IO.Path]::GetFileName([uri]$source.url))
    $sourceExtractRoot = Join-Path $ExtractRoot $source.name

    Invoke-WebRequest -Uri $source.url -OutFile $downloadPath

    $actualHash = (Get-FileHash -Path $downloadPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedHash = [string]$source.hash

    if ($actualHash -ne $expectedHash) {
        throw "Hash mismatch for '$($source.name)'. Expected $expectedHash, got $actualHash"
    }

    New-Item -ItemType Directory -Path $sourceExtractRoot -Force | Out-Null
    Expand-Archive -Path $downloadPath -DestinationPath $sourceExtractRoot -Force

    Assert-RequiredFiles `
        -Root $sourceExtractRoot `
        -RequiredFiles @($source.required_files) `
        -SourceName $source.name

    Copy-SourceToStage `
        -ExtractedRoot $sourceExtractRoot `
        -StageRoot $StageRoot `
        -TargetDir $source.target_dir

    Write-Host "Staged: $($source.target_dir)"
}

Write-Host ""
Write-Host "Stage root:"
Write-Host $StageRoot
Write-Host ""

Get-ChildItem -Path $StageRoot -Recurse |
    Select-Object FullName, Length |
    Format-Table -AutoSize
