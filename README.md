# Keenblade Scoop Bucket

Personal Scoop bucket for Windows packages and portable tools maintained by Hakan Demiralp.

## Add bucket

```powershell
scoop bucket add keenblade https://github.com/hkdemiralp/scoop-hk-bucket
```

## Install packages

```powershell
scoop install keenblade/bettertrumpet
scoop install keenblade/doublecmd-snapshot
```

## Available packages

| Package | Description |
|---|---|
| `bettertrumpet` | BetterTrumpet portable package. |
| `doublecmd-snapshot` | Double Commander snapshot build with persistent settings. |

## Maintenance

This repository includes helper scripts for maintaining package manifests and locally installed Scoop apps.

See:

```text
docs/maintenance-scripts.md
```

## License

This repository is licensed under the MIT License.

Package manifests may refer to third-party software distributed under their own licenses.
