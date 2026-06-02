def update_one [package_name: string, package: record] {
  if ($package.hash_source != "github_asset_digest") {
    error make {
      msg: $"Unsupported hash_source for ($package_name): ($package.hash_source)"
    }
  }

  let release = http get $"https://api.github.com/repos/($package.repo)/releases/latest"
  let version = ($release.tag_name | str replace --regex $"^($package.tag_prefix)" "")
  let asset_name = ($package.asset_template | str replace "{version}" $version)

  let matching_assets = ($release.assets | where name == $asset_name)

  if (($matching_assets | length) == 0) {
    error make {
      msg: $"Asset not found for ($package_name): ($asset_name)"
    }
  }

  let asset = ($matching_assets | first)
  let hash = ($asset.digest | str replace "sha256:" "")

  let manifest = open $package.manifest

  let updated = (
    $manifest
    | update version $version
    | update url $asset.browser_download_url
    | update hash $hash
  )

  ($updated | to json --indent 2) + "\n" | save --force $package.manifest

  print $"Updated ($package.manifest)"
  print $"Package: ($package_name)"
  print $"Version: ($version)"
  print $"Asset:   ($asset.name)"
  print $"Url:     ($asset.browser_download_url)"
  print $"Hash:    ($hash)"
  print ""
}

def main [target: string] {
  let config_path = "scripts/packages.json"
  let packages = open $config_path

  if ($target == "all-packages") {
    $packages
    | transpose package_name package
    | each {|row|
        update_one $row.package_name $row.package
      }

    git diff -- bucket
  } else {
    let package = ($packages | get --optional $target)

    if ($package == null) {
      error make {
        msg: $"Package not found in ($config_path): ($target)"
      }
    }

    update_one $target $package
    git diff -- $package.manifest
  }
}

