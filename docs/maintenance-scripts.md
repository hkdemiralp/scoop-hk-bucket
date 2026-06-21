# Maintenance Scripts

This document explains the local helper scripts used to maintain package manifests in this Scoop bucket.

## Files

```text
scripts/packages.json
scripts/update-scoop-manifest.ps1
```

## Package update configuration

Package update rules are stored in:

```text
scripts/packages.json
```

Each package entry defines:

- `repo`: GitHub repository used for latest release lookup
- `manifest`: Scoop manifest path
- `asset_template`: release asset filename pattern
- `tag_prefix`: release tag prefix to remove from the version
- `hash_source`: source used for the manifest hash

Current supported hash source:

```text
github_asset_digest
```

This reads the SHA256 digest exposed by GitHub release assets. The script does not download the release zip file.

## Update one package

```powershell
.\scripts\update-scoop-manifest.ps1 bettertrumpet
```

This updates the following fields inside the related Scoop manifest:

- `version`
- `url`
- `hash`

The script then shows a Git diff for review.

## Update all configured packages

```powershell
.\scripts\update-scoop-manifest.ps1 all-packages
```

This updates every package defined in `scripts/packages.json`.

## Commit an update

After reviewing the diff:

```powershell
git add bucket/bettertrumpet.json
git commit -m "build(bettertrumpet): update to 3.0.13"
git push
```

## Design note

The update script intentionally does not commit or push changes automatically.

This keeps the update process reviewable and avoids publishing accidental manifest changes.

## Release update workflow

When a new upstream version is released, update the related manifest with the local helper script.

### Update one package

```powershell
.\scripts\update-scoop-manifest.ps1 bettertrumpet
git diff -- bucket/bettertrumpet.json
git add bucket/bettertrumpet.json
git commit -m "build(bettertrumpet): update to 3.0.13"
git push
scoop update
scoop update bettertrumpet
```

### Update all configured packages

```powershell
.\scripts\update-scoop-manifest.ps1 all-packages
git diff -- bucket
```

Review the diff carefully before committing. The update helper only updates manifest files and shows diffs. It does not run Scoop update commands, commit changes, or push to GitHub.

## Update installed Scoop apps

Use this helper to update Scoop apps installed on the current Windows system:

```powershell
.\scripts\update-installed-scoop-apps.ps1
```

This script is different from `update-scoop-manifest.ps1`.

`update-scoop-manifest.ps1` updates bucket manifest files in this repository.
`update-installed-scoop-apps.ps1` updates apps already installed on the local machine.

For managed GUI or tray apps, the script can close the running process before update and restart it afterwards only if it was already running.

Currently managed apps:

```txt
bettertrumpet
super-productivity
```
