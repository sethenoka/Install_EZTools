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
- .NET install kind: runtime

Use `--sdk` if you need the full SDK instead of the runtime.

## Usage

```bash
chmod +x install_net9.sh
./install_net9.sh
```

The script prints an installation plan and asks for approval before making changes. Confirmation prompts default to yes (`Y/n`). It also asks again before installing missing prerequisites, .NET, and each selected tool unless `--yes` or `-y` is used.

Common examples:

```bash
# Preview without making changes
./install_net9.sh --dry-run

# Install without prompts
./install_net9.sh -y

# Install only selected tools
./install_net9.sh -t mftecmd,pecmd

# Install the full .NET SDK instead of the runtime
./install_net9.sh --sdk

# Try a different .NET channel
./install_net9.sh -c 10.0

# Reinstall even when files are already present
./install_net9.sh --force
```

Run `./install_net9.sh --help` for the full option list.

## Options

| Option | Purpose |
| --- | --- |
| `-t`, `--tools LIST` | Install `all` tools or a comma-separated subset. |
| `-d`, `--dest DIR` | Change the EZ Tools install root. |
| `-c`, `--dotnet-channel CHANNEL` | Change the channel passed to Microsoft's installer, for example `9.0` or `10.0`. |
| `-k`, `--dotnet-kind sdk\|runtime` | Choose full SDK or runtime-only install. |
| `-r`, `--runtime-only` | Shortcut for `--dotnet-kind runtime`. |
| `-s`, `--sdk` | Shortcut for `--dotnet-kind sdk`. |
| `-p`, `--profile FILE` | Update a specific shell profile file. |
| `-n`, `--no-profile` | Skip profile updates. |
| `-w`, `--wrapper-dir DIR` | Change where command wrappers are installed. |
| `-f`, `--force` | Reinstall even when the expected files are already present. |
| `-y`, `--yes` | Accept prompts for unattended runs. |
| `-D`, `--dry-run` | Show the planned commands without changing the system. |
| `-v`, `--verbose` | Show command output instead of suppressing successful command noise. |
| `--skip-dotnet-signature-check` | Skip GPG verification for `dotnet-install.sh`. |
| `--allow-root` | Permit running the whole script as root. Normally avoid this. |

Boolean short flags can be bundled. For example, `-yvf` is equivalent to `-y -v -f`. Short options that take values, such as `-t mftecmd` or `-d /opt/tools`, cannot be bundled.

## Included Tools

The `all` selection installs the net9 CLI/tooling set published on Eric Zimmerman's tools page:

- `amcacheparser`
- `appcompatcacheparser`
- `bstrings`
- `evtxecmd`
- `iisgeolocate`
- `jlecmd`
- `lecmd`
- `mftecmd`
- `pecmd`
- `rbcmd`
- `recentfilecacheparser`
- `recmd`
- `rla`
- `sbecmd`
- `sqlecmd`
- `srumecmd`
- `sumecmd`
- `vscmount`
- `wxtcmd`

GUI/Desktop tools such as Timeline Explorer, Registry Explorer, and EZViewer are not installed by this Linux command-wrapper script.

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

The wrapper command names match the tool keys listed above.

The script updates `~/.bashrc` with a managed block for `DOTNET_ROOT` and `PATH`. Re-running the script replaces that block instead of appending duplicate aliases.

## Safety and Reliability

The installer is designed to be re-runnable:

- Skips prerequisite packages that are already installed
- Checks `~/.dotnet/dotnet` and then `dotnet` on `PATH`; skips .NET when the requested channel/kind is already present, unless `--force` is used
- Skips tools whose expected DLL already exists, unless `--force` is used
- Uses retries and timeouts for downloads
- Verifies Microsoft's `dotnet-install.sh` GPG signature by default
- Validates downloaded ZIP integrity with `unzip -t`
- Runs post-install checks for `.NET`, selected tool DLLs, wrappers, wrapper command `--help` execution, and known runtime/platform failure text

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
8. Validate `.NET`, wrappers, DLL presence, and tool startup through the installed wrapper commands. Validation fails if a tool prints known runtime/platform failure text, even if it exits with status `0`.

The script has inline comments around the parts that are easiest to break later: archive layout handling, managed profile updates, signature verification, and the runtime/SDK detection path.

## Why Not Just Use Get-ZimmermanTools?

`Get-ZimmermanTools` is useful for downloading and updating the tools, but it's a PowerShell script and requires `pwsh` on Linux. It also doesn't install Debian/Ubuntu prerequisites or .NET. This repo is meant to cover the end-to-end Linux bootstrap path.
