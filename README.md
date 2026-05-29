# Install_EZTools

Bash installer for Eric Zimmerman command-line tools on Debian/Ubuntu systems.

The script installs missing prerequisites, installs .NET with Microsoft's `dotnet-install.sh`, downloads selected [EZ Tools](https://ericzimmerman.github.io/#!index.md), creates command wrappers (instead of aliases), and validates the result.

## Supported Systems

Current support is intentionally limited to Debian/Ubuntu systems with `apt-get`.

The script checks `/etc/os-release` and exits on unsupported distros. Support for Fedora, Arch, Kali-specific paths, and other Linux families might be added later.

## Important .NET Limitation

The EZ Tools downloaded by this script are the upstream `net9` builds from Eric Zimmerman's site. The .NET channel is configurable because .NET 9 will reach EOL and because testing runtime/SDK combinations is useful, but the tools themselves still depend on whichever framework version the upstream EZ Tools release targets.

Default behavior:

- EZ Tools: `net9`
- .NET channel: `9.0`
- .NET install kind: full SDK

If testing shows the runtime is enough, use `--runtime-only`.

## Usage

```bash
chmod +x install_net9.sh
./install_net9.sh
```

The script prints an installation plan and asks for approval before making changes. It also asks again before installing missing prerequisites, .NET, and each selected tool unless `--yes` is used.

Common examples:

```bash
# Preview without making changes
./install_net9.sh --dry-run

# Install without prompts
./install_net9.sh --yes

# Install only selected tools
./install_net9.sh --tools mftecmd,pecmd

# Test whether the .NET runtime is sufficient
./install_net9.sh --runtime-only

# Try a different .NET channel
./install_net9.sh --dotnet-channel 10.0

# Reinstall even when files are already present
./install_net9.sh --force
```

Run `./install_net9.sh --help` for the full option list.

## Options

| Option | Purpose |
| --- | --- |
| `--tools LIST` | Install `all` tools or a comma-separated subset: `mftecmd`, `pecmd`, `recmd`, `evtxecmd`. |
| `--dest DIR` | Change the EZ Tools install root. |
| `--dotnet-channel CHANNEL` | Change the channel passed to Microsoft's installer, for example `9.0` or `10.0`. |
| `--dotnet-kind sdk\|runtime` | Choose full SDK or runtime-only install. |
| `--runtime-only` | Shortcut for `--dotnet-kind runtime`. |
| `--sdk` | Shortcut for `--dotnet-kind sdk`. |
| `--profile FILE` | Update a specific shell profile file. |
| `--no-profile` | Skip profile updates. |
| `--wrapper-dir DIR` | Change where command wrappers are installed. |
| `--force` | Reinstall even when the expected files are already present. |
| `--yes` | Accept prompts for unattended runs. |
| `--dry-run` | Show the planned commands without changing the system. |
| `--verbose` | Show command output instead of suppressing successful command noise. |
| `--skip-dotnet-signature-check` | Skip GPG verification for `dotnet-install.sh`. |
| `--allow-root` | Permit running the whole script as root. Normally avoid this. |

## Installed Commands

By default, tools are installed under:

```text
/opt/zimmermantools/net9
```

Wrappers are installed under:

```text
/usr/local/bin
```

Default wrappers:

- `mftecmd`
- `pecmd`
- `recmd`
- `evtxecmd`

The script updates `~/.bashrc` with a managed block for `DOTNET_ROOT` and `PATH`. Re-running the script replaces that block instead of appending duplicate aliases.

## Safety and Reliability

The installer is designed to be re-runnable:

- Skips prerequisite packages that are already installed
- Checks `~/.dotnet/dotnet` and then `dotnet` on `PATH`; skips .NET when the requested channel/kind is already present, unless `--force` is used
- Skips tools whose expected DLL already exists, unless `--force` is used
- Uses retries and timeouts for downloads
- Verifies Microsoft's `dotnet-install.sh` GPG signature by default
- Validates downloaded ZIP integrity with `unzip -t`
- Runs post-install checks for `.NET`, selected tool DLLs, wrappers, and tool `--help` execution

Eric Zimmerman does not publish checksums in the simple direct-download flow used here, so EZ Tool ZIP authenticity still relies on HTTPS and upstream availability. The manifest includes a checksum field so hashes can be added later if upstream publishes them.

## Installer Flow

At a high level, `install_net9.sh` runs these phases:

1. Parse options and validate the requested tool list
2. Confirm the installation plan unless `--yes` or `--dry-run` is used
3. Install missing Debian/Ubuntu prerequisite packages
4. Reuse an existing compatible `.NET` install or install the requested SDK/runtime
5. Download and extract selected EZ Tools from the manifest
6. Create command wrappers
7. Update the shell profile with a managed block, unless disabled
8. Validate `.NET`, wrappers, DLL presence, and tool startup

The script has inline comments around the parts that are easiest to break later: archive layout handling, managed profile updates, signature verification, and the runtime/SDK detection path.

## Why Not Just Use Get-ZimmermanTools?

`Get-ZimmermanTools` is useful for downloading and updating the tools, but it's a PowerShell script and requires `pwsh` on Linux. It also doesn't install Debian/Ubuntu prerequisites or .NET. This repo is meant to cover the end-to-end Linux bootstrap path.
