# CLAUDE.md

Context for working on this nix-darwin configuration. Read this before making changes.

## What this is

Declarative macOS system configuration for a single MacBook, managed with a Nix flake
(**nix-darwin** + **Home Manager**). The config lives at `~/.config/nix-darwin/`:

- `flake.nix` — flake inputs, the darwin system module, the HM wiring, and the Homebrew block.
- `home.nix` — the Home Manager user config, imported by the flake.

Machine facts:

- **User:** `adnathanail`
- **Hostname / darwinConfiguration attr:** `Alexs-MacBook-Pro`
- **Platform:** Apple Silicon (`aarch64-darwin`)
- **Nix implementation:** **Lix** (a fork of Nix — *not* upstream Nix), installed via the Lix installer

## Making changes

Custom command
```bash
nix-switch
```

Raw command (backup)
```bash
sudo darwin-rebuild switch --flake ~/.config/nix-darwin
```

**Rule: DO NOT REBUILD — ASK THE USER TO DO SO.**

Activation must run as root. See *Routine maintenance* below for `nix flake update` patterns.

**Rule: Add new software/tools/config to the README.md**

## Key architectural decisions

### Lix instead of upstream Nix
nix-darwin recommends Lix on macOS for its clean uninstaller and survival across macOS upgrades.
Expect harmless `using 'or' as an identifier is deprecated` warnings while Lix evaluates nixpkgs
`lib` — **ignore them**, they're nixpkgs noise.

### `nix.enable = false` — do not change
The Lix installer owns the Nix installation, its daemon, and `/etc/nix/nix.conf`. nix-darwin's
default is to manage all of that too, which collides (`error: Unexpected files in /etc`).
`nix.enable = false` tells nix-darwin to leave Nix alone.

- **Do NOT** rename `/etc/nix/nix.conf` to hand it to nix-darwin — dueling daemons.
- The `nix.*` options (`nix.settings.*`, Linux builder, etc.) are **unavailable**. Extra Nix
  settings (substituters, trusted-users, binary caches) go in `/etc/nix/nix.custom.conf`, which
  the Lix-generated `nix.conf` already `!include`s at the bottom.
- Flakes + `nix-command` are already enabled globally by the installer.

### nixpkgs on stable 26.05; Home Manager matched
- `nixpkgs` is pinned to `nixpkgs-26.05-darwin`.
- `home-manager` **must** track `release-26.05`. Using HM `master` against stable nixpkgs caused
  an eval failure (`lib/services/...: No such file or directory`) because master expects
  *unstable's* `lib`. **HM branch must match the nixpkgs branch.** If nixpkgs ever moves to
  unstable, move HM to `master` at the same time.
- HM release branches get bug fixes but rarely *new modules*. A brand-new HM module may only
  exist on `master` — check before relying on one.

### Selective unstable overlay
Some packages move faster than the stable channel can backport (Claude Code ships ~weekly;
JetBrains IDEs get minor-version bumps every few months that release-25.11 will never see).
`unstableOverlay` pulls **specific** packages from `nixpkgs-unstable`, leaving everything else
on stable. Currently overridden: `claude-code`, `prek`, `jetbrains.pycharm`. For `jetbrains.*`
the override merges (`prev.jetbrains // { … }`) so other JetBrains IDEs would still come from
stable. Reuse this pattern for any package that needs to be fresher than the pin.

### `allowUnfree`
`nixpkgs.config.allowUnfree = true` is required for proprietary packages (`claude-code`,
`vscode`, `jetbrains.pycharm`). Narrow to an `allowUnfreePredicate` if stricter control is wanted.

### Home Manager as a nix-darwin module
HM runs as a darwin module with `useGlobalPkgs = true` (so HM uses the system `pkgs` **with
overlays applied** — this is how VS Code extensions and the unstable overlay reach HM) and
`useUserPackages = true`. `backupFileExtension = "hm-backup"` is set so HM moves pre-existing
non-Nix-managed files aside instead of refusing to activate.

### `nix-homebrew` for signed/path-locked GUI apps
`nix-homebrew` installs and pins Homebrew itself (no manual `curl | bash`); `homebrew.*` in
`flake.nix` then declares casks. On first activation you'll get a `sudo` prompt to take
ownership of `/opt/homebrew`.

Homebrew is used **only** for apps that path-check `/Applications` or require an intact Apple
designated-requirement code signature (Nix's wrap step invalidates the signature; HM lands apps
in `~/Applications/Home Manager Apps/` instead of `/Applications`). Everything else stays on Nix.

Options: `enableRosetta = false`, `onActivation.upgrade = true`, `onActivation.autoUpdate = false`
(activation stays deterministic — bump via `nix flake update nix-homebrew`),
`onActivation.cleanup = "none"`. **Do not flip cleanup to `"zap"`** without first auditing
`brew list` against the config — it silently uninstalls anything not declared.

### Touch ID for sudo
Enabled via `security.pam.services.sudo_local.touchIdAuth = true` — writes `/etc/pam.d/sudo_local`,
which survives macOS updates. Does **not** work inside tmux without the `pam_reattach` module.

## Conventions

These apply to every tool unless its note says otherwise:

- **Never use a tool's self-updater.** The store is read-only. Update via `nix flake update` +
  rebuild (Nix) or via the cask refresh on rebuild (Homebrew). Disable in-app updaters where
  exposed — see *First-use setup → In-app toggles*.
- **GUI apps:** prefer `programs.*` HM modules where they exist (declarative), otherwise Homebrew
  cask. nixpkgs doesn't fully replace Homebrew for signed/path-locked GUI apps.
- **Per-app state** (sign-ins, caches, prefs, licences) lives under `~/Library/...` and is **not
  Nix-managed** unless the per-tool note says otherwise.
- **Compatibility tags** below: `(Nix)` / `(Homebrew)` is the install mechanism;
  `(unstable overlay)` means it's pulled from `nixpkgs-unstable`; `(Nix-managed config)` /
  `(Nix-managed prefs)` / `(Nix-managed plugins)` means that specific piece is declarative and
  in-app edits won't persist.

## Per-tool notes

Only surprising or unique-to-this-config facts. Permissions and sign-ins live in *First-use
setup*; install/update mechanism is captured in the tag.

### Claude Code `(Nix, unstable overlay)`
Installed via `programs.claude-code`. Self-updater disabled via
`home.sessionVariables.DISABLE_AUTOUPDATER = "1"` (it cannot write into the store). The
`claude symlink points to an invalid binary` warning is a harmless false positive — Nix wraps
it as a script rather than the binary the CLI expects. The VS Code extension (see VS Code) and
PyCharm plugin (see PyCharm) are managed separately and update independently of the CLI.

### VS Code `(Nix, Nix-managed config + extensions)`
Managed by `programs.vscode` under `profiles.default`. `settings.json` is Nix-owned — edit
`userSettings` in `home.nix`, not in-app. Extensions come from `pkgs.vscode-extensions` (resolve
as `<publisher>.<name>`, e.g. `anthropic.claude-code`); for extensions not in the overlay set
use `pkgs.vscode-utils.extensionFromVscodeMarketplace` with publisher, name, version, and SRI
hash. The in-app extension updater is disabled declaratively via
`extensions.autoUpdate = false` and `extensions.autoCheckUpdates = false` in `userSettings`
(the store is read-only). App lands at `~/Applications/Home Manager Apps/`; Spotlight and
`open -a` still find it. First eval after adding it is slow because the marketplace overlay set
is enormous; subsequent rebuilds are fine.

### PyCharm Professional `(Nix, unstable overlay, Nix-managed plugins + keymap)`
Pulled from unstable because release-25.11 won't backport JetBrains minor-version bumps. Lands at
`~/Applications/Home Manager Apps/PyCharm Professional Edition.app`.

**Keymap** at `pycharm/custom-keymap.xml` is symlinked into
`~/Library/Application Support/JetBrains/PyCharm2026.1/keymaps/` via `home.file`. Edits inside
PyCharm fail silently (read-only store target) — edit the XML in the repo. The destination path
is **version-pinned**, so after a JetBrains minor-version bump (e.g. `PyCharm2026.1` →
`PyCharm2026.2`) update the path in `home.nix` or the symlink lands in the wrong directory.

Project SDKs, run configs, and JetBrains licence sign-in are **not** Nix-managed.

### Rectangle `(Nix)`
Fetched from the official `.dmg` by nixpkgs. Prefs (keybindings, snap areas, "launch on login")
are **not** Nix-managed; could be promoted via
`system.defaults.CustomUserPreferences."com.knollsoft.Rectangle"` if needed.

### prek `(Nix, unstable overlay)`
Rust reimplementation of `pre-commit`. On unstable because it's a fast-moving 0.x tool the
stable channel lags on (0.2.x on stable vs 0.3.x on unstable at install time). No self-updater.

### git `(Nix)`
`programs.git` manages identity and `~/.gitconfig`. Installing git via Nix sidesteps Apple's
Command Line Tools prompt. CLT is still needed only for build systems that hardcode
`/usr/bin/git` or require Apple SDK headers.

### 1Password + 1Password CLI `(Homebrew)`
`pkgs._1password-gui` fails 1Password's runtime check (refuses to run outside `/Applications`).
`pkgs._1password-cli` runs fine standalone, but the desktop ↔ CLI biometric handshake verifies
AgileBits' code-signature requirement on `op`; Nix's wrap step invalidates that signature, so
*Settings → Developer → Integrate with 1Password CLI* silently fails to unlock via the desktop
app. Homebrew ships both signed binaries as-is.

### OrbStack `(Homebrew)`
Installs a privileged helper (`OrbStackHelper`) and CLI shims (`docker`, `docker compose`,
`orb`, `orbctl`) into `/usr/local/bin`. **Do not also install `pkgs.docker` or
`pkgs.docker-compose`** — PATH conflicts.

### Raycast `(Homebrew)`
Registers a Login Items helper, captures a system-wide hotkey, loads community extensions that
path-check the host bundle. Default hotkey ⌥Space collides with Spotlight — onboarding offers
to disable Spotlight.

### Bartender `(Homebrew)`
Menu-bar organiser. Not in nixpkgs (commercial, closed-source). Without Screen Recording,
hidden icons render as blanks; without Accessibility, clicks pass through to the wrong items.

### Ghostty `(Homebrew, Nix-managed config)`
Terminal emulator. `pkgs.ghostty` on Darwin is historically fragile (needs Swift/Xcode toolchain
nixpkgs can't cleanly reproduce). Config at `~/.config/ghostty/config` is Nix-owned via
`xdg.configFile` (Ghostty reads the XDG path on macOS). `auto-update = off` is set there to
suppress Sparkle's first-launch prompt. Editing config in-app fails silently. If config grows,
consider migrating to the HM `programs.ghostty` module — verify it's on `release-25.11` first.

### Microsoft Outlook `(Homebrew, Nix-managed prefs)`
App-level prefs are Nix-managed via `system.defaults.CustomUserPreferences` on the
`com.microsoft.Outlook` and `com.microsoft.office` domains. This works for a sandboxed app
because Microsoft documents `defaults write com.microsoft.Outlook …` as the supported pref
mechanism — CFPreferences redirects writes through to the container plist
(`~/Library/Group Containers/UBF8T346G9.Office/`). Currently set:
`AutomaticallyDownloadExternalContent = false` (block tracking pixels), `FocusedInbox = false`,
Office-wide `DiagnosticDataTypePreference = "BasicTelemetry"` (lowest level on consumer
accounts; `ZeroTelemetry` is enterprise-only). Add new keys here, not in-app — look them up on
Microsoft Learn under *Set preferences for Outlook for Mac*.

Microsoft AutoUpdate (MAU) is **disabled** declaratively via
`"com.microsoft.autoupdate2".HowToCheck = "Manual"`, so updates flow through the Homebrew cask
refresh on rebuild. The pref applies to any other Office app installed later.

### Slack `(Homebrew)`
Sandboxed bundle. The in-app updater is harmless but disabling it via
*Preferences → Advanced → "Automatically update Slack"* keeps the version in lockstep with the
Nix pin.

### Todoist `(Homebrew)`
Not in nixpkgs. Registers a Login Items helper for "launch at login".

### Fantastical `(Homebrew)`
Calendar app by Flexibits. Not in nixpkgs (commercial, closed-source). Free tier works without
a Flexibits account; sign in for paid features. Registers a menu-bar item.

### Spotify `(Homebrew)`
Sandboxed bundle with a built-in Sparkle updater that can't write into the Nix store. The
Homebrew cask refresh on rebuild keeps it current.

## First-use setup

Run through these on a fresh machine after the first `darwin-rebuild switch`.

### Sign-ins
- **1Password** — account; then *Settings → Developer → Integrate with 1Password CLI*.
- **Microsoft Outlook** — Microsoft 365 account.
- **Slack** — workspaces.
- **Todoist** — Doist account.
- **PyCharm Professional** — JetBrains licence.
- **Fantastical** — Flexibits account (only needed for paid features).
- **Spotify** — Spotify account.

### System permissions (System Settings → Privacy & Security)
- **Accessibility:** Rectangle, Raycast, Bartender.
- **Screen Recording:** Bartender (hidden icons), Slack (huddle screen-share). A logout may be
  required after granting Screen Recording.
- **Input Monitoring:** Raycast.
- **Notifications:** Outlook, Slack, Todoist, Fantastical.
- **Contacts + Calendar:** Outlook, Fantastical.
- **Microphone + Camera:** Slack (huddles).

### In-app one-time toggles
Mostly disabling self-updaters; the read-only store would break them anyway.
- **PyCharm:** *Settings → Appearance & Behavior → System Settings → Updates* → uncheck
  "Check IDE updates for…"; also disable plugin auto-updater.
- **PyCharm:** *Settings → Keymap* → select "Default for macOS copy" (the Nix-managed keymap).
- **Raycast:** set hotkey (onboarding offers to disable Spotlight first).
- **Slack:** *Preferences → Advanced* → uncheck "Automatically update Slack".
- **Todoist:** accept "Launch at login" prompt if you want the menu-bar item to autostart.

## Routine maintenance

- Update one input then rebuild: `nix flake update <input>` (e.g. `nixpkgs-unstable`).
- Update everything then rebuild: `nix flake update`.
- Bump Homebrew itself: `nix flake update nix-homebrew`. Casks refresh on every rebuild
  (`homebrew.onActivation.upgrade = true`).
- After a PyCharm minor-version bump (e.g. `2026.1 → 2026.2`): update the version-pinned keymap
  symlink path in `home.nix`, otherwise the keymap silently lands in the old unused directory.
