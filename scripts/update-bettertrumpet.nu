let repo = "xammen/BetterTrumpet"
let manifest_path = "bucket/bettertrumpet.json"

let release = http get $"https://api.github.com/repos/($repo)/releases/latest"
let version = ($release.tag_name | str replace --regex '^v' '')
let asset_name = $"BetterTrumpet-($version)-portable.zip"

let asset = ($release.assets | where name == $asset_name | first)

if ($asset == null) {
  error make {
    msg: $"Asset not found: ($asset_name)"
  }
}

let hash = ($asset.digest | str replace 'sha256:' '')

let manifest = open $manifest_path

let updated = (
  $manifest
  | update version $version
  | update url $asset.browser_download_url
  | update hash $hash
)

($updated | to json --indent 2) + "\n" | save --force $manifest_path

print $"Updated ($manifest_path)"
print $"Version: ($version)"
print $"Asset:   ($asset.name)"
print $"Url:     ($asset.browser_download_url)"
print $"Hash:    ($hash)"

git diff -- $manifest_path
