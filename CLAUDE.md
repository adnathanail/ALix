# CLAUDE.md

Context for working on this nix-darwin configuration. Read this before making changes.

## What this is

Declarative macOS system configuration for a single MacBook, managed with a Nix flake
(**nix-darwin** + **Home Manager**). The config lives at `~/.config/nix-darwin/`:

- `flake.nix` — flake inputs, the darwin system module, and the HM wiring.
- `home.nix` — the Home Manager user config, imported by the flake.

Machine facts:

- **User:** `adnathanail`
- **Hostname / darwinConfiguration attr:** `Alexs-MacBook-Pro`
- **Platform:** Apple Silicon (`aarch64-darwin`)
- **Nix implementation:** **Lix** (a fork of Nix — *not* upstream Nix), installed via the Lix installer

## How to apply changes

```bash
sudo darwin-rebuild switch --flake ~/.config/nix-darwin
```

- Activation **must run as root** (`sudo`) — nix-darwin requires it.
- Update **one** input then rebuild: `nix flake update <input>` (e.g. `nixpkgs-unstable`).
- Update **everything**: `nix flake update`.

**Rule: DO NOT REBUILD - ASK THE USER TO DO SO**

## Key decisions and rationale

### Lix instead of upstream Nix
Bootstrapped with the Lix installer, so Lix is the interpreter. nix-darwin recommends the Lix
installer on macOS for its clean uninstaller and ability to survive macOS upgrades. Expect harmless
`using 'or' as an identifier is deprecated` warnings from Lix while it evaluates nixpkgs `lib` —
**ignore them**, they're noise from nixpkgs, not this config.

### `nix.enable = false` — IMPORTANT, do not change
The Lix installer owns the Nix installation, its daemon, and `/etc/nix/nix.conf`. nix-darwin by
default also wants to manage all of that, which collides (`error: Unexpected files in /etc`).
`nix.enable = false` tells nix-darwin to leave Nix alone and only manage macOS/system config.

- **Do NOT** rename `/etc/nix/nix.conf` to hand it to nix-darwin — that produces dueling daemons.
- Consequence: the `nix.*` options (`nix.settings.*`, Linux builder, etc.) are **unavailable**.
  Extra Nix settings (substituters, trusted-users, binary caches) go in `/etc/nix/nix.custom.conf`,
  which the Lix-generated `nix.conf` already `!include`s at the bottom.
- Flakes + `nix-command` are already enabled globally by the installer.

### nixpkgs on stable 25.11; Home Manager matched to `release-25.11`
- `nixpkgs` is pinned to `nixpkgs-25.11-darwin` (stable base).
- `home-manager` **must** track the matching `release-25.11` branch. Using HM `master` against
  stable nixpkgs caused an eval failure (`lib/services/...: No such file or directory`) because
  master expects *unstable's* `lib`. **Rule: HM branch must match the nixpkgs branch.** If nixpkgs
  ever moves to unstable, move HM to `master` at the same time.
- HM release branches get bug fixes but rarely *new modules*, so a brand-new HM module may only
  exist on `master`. Check availability before relying on one.

### Selective unstable overlay
Some packages move faster than the stable channel can backport (Claude Code ships ~weekly;
JetBrains IDEs get minor-version bumps every few months that release-25.11 will never see). An
overlay (`unstableOverlay`) pulls **specific** packages from `nixpkgs-unstable`, leaving everything
else on stable 25.11. Currently overridden: `claude-code`, `prek`, `jetbrains.pycharm`. For
`jetbrains.*` the override merges (`prev.jetbrains // { … }`) so other JetBrains IDEs would still
come from stable. Reuse this pattern for any other single package that needs to be fresher than
the stable pin.

### `allowUnfree`
`nixpkgs.config.allowUnfree = true` is required for proprietary packages (`claude-code`, `vscode`,
`jetbrains.pycharm`). Narrow it to an `allowUnfreePredicate` if stricter control is
ever wanted.

### Home Manager as a nix-darwin module
HM runs as a darwin module with `useGlobalPkgs = true` (so HM uses the system `pkgs` **with overlays
applied** — this is how VS Code extensions and the Claude Code overlay reach HM) and
`useUserPackages = true`. The user environment is built and switched together with the system on
every rebuild. `backupFileExtension = "hm-backup"` is set so HM moves any pre-existing
non-Nix-managed files (e.g. a hand-written VS Code `settings.json`) aside instead of refusing to
activate.

## Per-tool notes

### Claude Code
- Installed via Nix using `programs.claude-code` (overlaid to the unstable build via
  `unstableOverlay`).
- Self-updater disabled via `home.sessionVariables.DISABLE_AUTOUPDATER = "1"` — it cannot write into
  the read-only store. **Update it through Nix**, never its built-in updater.
- The `claude symlink points to an invalid binary` warning is a harmless false positive: Nix wraps
  it as a script rather than the large binary Claude Code expects.
- IDE integrations are also Nix-managed: the **VS Code** extension comes from
  `pkgs.vscode-extensions.anthropic.claude-code` (see the VS Code section); the **PyCharm**
  plugin is wrapped into the IDE bundle via `jetbrains.plugins.addPlugins` (see the PyCharm
  Professional section). Both update independently of the CLI — bumping `claude-code` doesn't
  bump them.

### VS Code
- Managed by `programs.vscode` (declarative) under `profiles.default`.
- `settings.json` is now **Nix-owned** — editing it in-app won't persist. Change `userSettings` in
  `home.nix` instead.
- Extensions are declared in `profiles.default.extensions` from `pkgs.vscode-extensions`.
  The marketplace overlay is large but well-curated — most extensions resolve as
  `<publisher>.<name>` (e.g. `anthropic.claude-code`). If an extension isn't in the overlay
  set, use `pkgs.vscode-utils.extensionFromVscodeMarketplace` with the publisher, name, and
  version + hash. **Disable VS Code's in-app extension updater** for Nix-managed extensions
  — the store is read-only; bump versions through Nix instead.
- The app installs to `~/Applications/Home Manager Apps/` (not `/Applications`); Spotlight and
  `open -a "Visual Studio Code"` still find it there.
- First eval after adding it is slow/heavy because the Marketplace overlay set is enormous;
  subsequent rebuilds are fine.
- Updates via Nix, not VS Code's own updater.

### 1Password
- **Both** the desktop app and the `op` CLI come from Homebrew
  (`homebrew.casks = [ "1password" "1password-cli" ]` in `flake.nix`), not Nix.
- Desktop app: `pkgs._1password-gui` is unusable on macOS — 1Password's runtime
  self-check refuses to run anywhere except `/Applications/1Password.app`, and
  Home Manager apps land in `~/Applications/Home Manager Apps/`. Homebrew installs
  into `/Applications`, which keeps 1Password happy.
- CLI: `pkgs._1password-cli` *runs* fine standalone, but the desktop ↔ CLI biometric
  unlock handshake verifies AgileBits' designated code-signature requirement on the
  `op` binary. Nix's build/wrap step invalidates that signature, so
  *Settings → Developer → Integrate with 1Password CLI* will silently fail to unlock
  via the desktop app. The Homebrew cask ships the upstream signed binary as-is.
- All account state — sign-in, sync, browser extension pairing, SSH agent, biometric
  unlock — is configured inside the 1Password app and persisted under
  `~/Library/Group Containers/` and `~/Library/Containers/`, **not Nix-managed**.
- Enable *Settings → Developer → Integrate with 1Password CLI* in the app once after
  install — that's what wires `op` to Touch ID / desktop unlock.
- Updates: both casks refresh on every `darwin-rebuild` (because
  `homebrew.onActivation.upgrade = true`). Don't use 1Password's in-app updater.

### OrbStack
- Docker Desktop / lightweight Linux-VM app, installed via Homebrew
  (`homebrew.casks` in `flake.nix`), not Nix.
- Why Homebrew: OrbStack installs a privileged helper (`OrbStackHelper`) and
  network components that depend on Apple's designated-requirement code
  signature and on `/Applications/OrbStack.app` being its install path. Nix's
  build/wrap step invalidates the signature, and Home Manager would land it in
  `~/Applications/Home Manager Apps/` — the helper handshake fails in both
  cases. (A `pkgs.orbstack` exists but isn't viable for the same reason
  `pkgs._1password-gui` isn't.)
- First launch: grant the requested permissions (System Settings → Privacy &
  Security) and let it install its CLI shims (`docker`, `docker compose`,
  `orb`, `orbctl`) into `/usr/local/bin`. These come from OrbStack itself —
  do NOT also install `pkgs.docker` or `pkgs.docker-compose`, or you'll get
  PATH conflicts.
- VM state, container images, and settings live under `~/.orbstack/` and
  `~/Library/Group Containers/HUAQ24HBR6.dev.orbstack/`, **not Nix-managed**.
- Updates via Nix activation (`homebrew.onActivation.upgrade = true` refreshes
  the cask). Don't use OrbStack's in-app updater.

### Raycast
- Spotlight replacement / launcher, installed via Homebrew (`homebrew.casks`
  in `flake.nix`), not Nix.
- Why Homebrew: Raycast registers a Login Items helper via Apple's Service
  Management framework, captures a system-wide hotkey, and loads
  community-published extensions that path-check the host bundle. All of this
  is tied to the official code signature and the `/Applications/Raycast.app`
  install path. Nix's wrap step invalidates the signature and HM would land
  it in `~/Applications/Home Manager Apps/`, so the launch-at-login
  registration and several extensions silently fail.
- First launch: grant Accessibility *and* Input Monitoring in
  System Settings → Privacy & Security, then run through Raycast's onboarding
  to set the hotkey (default ⌥Space — collides with Spotlight, which Raycast's
  onboarding offers to disable).
- Account state, installed extensions, snippets, quicklinks, and Raycast Pro
  cloud-sync credentials live under `~/Library/Application Support/com.raycast.macos/`
  and `~/Library/Preferences/com.raycast.macos.plist`, **not Nix-managed**.
- Updates via Nix activation (`homebrew.onActivation.upgrade = true` refreshes
  the cask). Don't use Raycast's in-app updater.

### Bartender
- Menu-bar organizer (hides/groups menu-bar items), installed via Homebrew
  (`homebrew.casks` in `flake.nix`), not Nix (not in nixpkgs anyway — it's
  a commercial, closed-source app).
- Why Homebrew: Bartender uses Screen Recording + Accessibility to read and
  redraw the menu bar, and its entitlements are tied to Apple's
  designated-requirement code signature. Nix's wrap step would invalidate the
  signature, and the macOS TCC database keys permissions to a bundle path +
  signature pair — so even after re-granting, the helper would not be able to
  read the menu bar reliably. Homebrew ships the upstream signed `.app`
  into `/Applications` as-is.
- First launch: grant **Screen Recording** *and* **Accessibility** in System
  Settings → Privacy & Security. Without Screen Recording, hidden icons
  render as blanks; without Accessibility, clicks pass through to the wrong
  menu items. Macs may require a logout after granting Screen Recording.
- Licence/account state lives inside the app and under
  `~/Library/Application Support/com.surteesstudios.Bartender/` and
  `~/Library/Preferences/com.surteesstudios.Bartender.plist`, **not Nix-managed**.
- Updates via Nix activation (`homebrew.onActivation.upgrade = true` refreshes
  the cask). Don't use Bartender's in-app updater.

### Ghostty
- Terminal emulator, installed via Homebrew (`homebrew.casks` in `flake.nix`), not Nix.
- Why Homebrew: `pkgs.ghostty` on Darwin has historically been fragile — Ghostty's macOS build
  requires a Swift/Xcode toolchain that nixpkgs cannot cleanly reproduce, so the Darwin package
  has lagged or broken across releases. The Homebrew cask ships the upstream signed `.app` into
  `/Applications` as-is. (Revisit moving to Nix once `pkgs.ghostty` on `aarch64-darwin` is
  reliable.)
- Configuration: `~/.config/ghostty/config` is **Nix-owned** via `xdg.configFile` in `home.nix`
  (Ghostty reads both the XDG path and `~/Library/Application Support/com.mitchellh.ghostty/config`
  on macOS). Editing the config inside the app will fail silently — change `home.nix` and
  rebuild instead. `auto-update = off` is set there to suppress Sparkle's first-launch prompt;
  updates flow through Homebrew on `darwin-rebuild` instead. If config grows, consider migrating
  to the HM `programs.ghostty` module (lives on HM `master` — verify availability on
  `release-25.11` first).
- Updates via Nix activation (`homebrew.onActivation.upgrade = true` refreshes the cask). Don't
  use Ghostty's in-app updater.

### PyCharm Professional
- Installed via `pkgs.jetbrains.pycharm` in `home.packages`, overlaid to the
  unstable build via `unstableOverlay` because the 25.11 stable channel never backports
  JetBrains minor-version bumps (e.g. 2025.3 → 2026.1). Unstable typically lags JetBrains
  releases by 1–4 weeks.
- Lands at `~/Applications/Home Manager Apps/PyCharm Professional Edition.app`; Spotlight
  finds it.
- **Disable the in-app updater** on first launch: Settings → Appearance & Behavior → System
  Settings → Updates → uncheck "Check IDE updates for…". The store is read-only, so any
  attempt to apply an update will fail. Update via Nix instead.
- Project SDKs and per-project run configs are not Nix-managed — they live under
  `~/Library/Application Support/JetBrains/PyCharm<version>/` and the project's `.idea/`.
- **Plugins are Nix-managed** via `jetbrains.plugins.addPlugins`, which wraps the IDE
  derivation and links plugin contents into its `plugins/` directory at build time. The
  store path of the wrapped IDE changes (becomes `pycharm-with-plugins-…`), so the first
  rebuild after adding/removing a plugin re-links `~/Applications/Home Manager Apps/PyCharm
  Professional Edition.app` — Spotlight may briefly re-index. The wrapper requires a
  **derivation**, not a string ID (the old API was removed); use `pkgs.fetchzip` against
  the JetBrains Marketplace `.zip` URL and pin its SRI hash. Find latest updates and check
  build compatibility (`since`/`until`) via the JSON API at
  `https://plugins.jetbrains.com/api/plugins/<id>/updates`. Update a plugin by bumping
  `url` + `hash` in `home.nix` — **disable the IDE's own plugin auto-updater**, it tries to
  write into the read-only store. Plugins not added through Nix (installed in-IDE) keep
  working and live under `~/Library/Application Support/JetBrains/PyCharm<version>/plugins/`,
  but mixing the two means the in-IDE plugin UI shows Nix-managed plugins as bundled and
  refuses to disable/uninstall them. Currently Nix-managed: **Claude Code** (plugin 27310).
- **Keymap is Nix-managed**: `pycharm/custom-keymap.xml` is symlinked into
  `~/Library/Application Support/JetBrains/PyCharm2026.1/keymaps/` via `home.file` in
  `home.nix`. Two consequences: (1) editing the keymap inside PyCharm fails silently (target is
  read-only in the Nix store) — edit the XML in the repo and rebuild instead; (2) the destination
  path is **version-pinned**, so after a JetBrains minor-version bump (e.g. `PyCharm2026.1` →
  `PyCharm2026.2`) the symlink will silently land in the old, unused dir until you update the
  path in `home.nix`. Select the keymap once in *Settings → Keymap* after first activation —
  it appears under its `name=` attribute ("Default for macOS copy").
- Activation/licence sign-in happens inside the app and is persisted under
  `~/Library/Application Support/JetBrains/`, not Nix-managed.

### Rectangle
- Magnet-style window-snapping app, installed via `pkgs.rectangle` in `home.packages`. The
  nixpkgs package fetches the official .dmg and unpacks `Rectangle.app` into the store; HM
  surfaces it at `~/Applications/Home Manager Apps/Rectangle.app`, where Spotlight finds it.
- Configuration (keybindings, snap areas, "launch on login") lives in Rectangle's own
  preferences UI and is persisted to `~/Library/Preferences/com.knollsoft.Rectangle.plist`,
  which is *not* Nix-managed. If you ever want it declarative, set the matching
  `defaults`-style keys via `system.defaults.CustomUserPreferences."com.knollsoft.Rectangle"`.
- Needs Accessibility permission (System Settings → Privacy & Security → Accessibility) on
  first launch, or it can't move windows.
- Updates via Nix, not Rectangle's own updater.
- Config lives at `~/.config/aerospace/aerospace.toml` and is Nix-owned (symlinked into the
  store). Edits to it won't persist — change `userSettings` in `home.nix` instead.

### prek
- Rust reimplementation of `pre-commit`, installed via `pkgs.prek` in `home.packages`. Overlaid
  to the unstable build via `unstableOverlay` because it's a fast-moving 0.x tool and the stable
  25.11 channel will lag releases (stable was 0.2.17, unstable 0.3.11 at install time).
- Per-repo hook config (`.pre-commit-config.yaml`) is the same format as upstream `pre-commit`
  and lives in each project repo — not Nix-managed.
- Update via Nix (`nix flake update nixpkgs-unstable` + rebuild). No self-updater to disable.

### git
- `programs.git` manages identity and `~/.gitconfig` declaratively. Installing git via Nix avoids
  Apple's Command Line Tools prompt. (CLT is still needed only for build systems that hardcode
  `/usr/bin/git` or require Apple SDK headers.)

### Homebrew (via nix-homebrew)
- `nix-homebrew` installs and pins Homebrew itself (no manual `curl | bash`). The
  `homebrew.*` options in `flake.nix` then declare what gets installed via it. Apple
  Silicon Homebrew lives at `/opt/homebrew`; the module owns it on first activation
  (you'll get a `sudo` prompt to take ownership).
- **Used only** for packages that don't tolerate the Nix store layout — either GUI apps
  that path-check against `/Applications`, or binaries whose Apple code signature must
  be preserved (Nix's build/wrap step invalidates upstream signatures). Currently:
  `1password`, `1password-cli`, `orbstack`, `raycast`, `bartender`, and `ghostty`.
  Everything else stays on Nix.
- `enableRosetta = false`. Flip to `true` only if an x86_64-only cask needs to be
  installed alongside the native aarch64 brew (rare).
- `homebrew.onActivation.upgrade = true`, so casks update on every `darwin-rebuild`.
  `homebrew.onActivation.autoUpdate = false` keeps activation deterministic — Homebrew
  itself isn't refreshed implicitly; `nix flake update nix-homebrew` is the bump knob.
- `homebrew.onActivation.cleanup = "none"` for now. Flipping to `"zap"` would uninstall
  any cask/brew not declared in `flake.nix`. Audit `brew list` against the config before
  changing this — otherwise a rebuild silently nukes hand-installed casks.
- `mutableTaps` is not pinned, so taps stay in their normal Homebrew-managed location
  and `brew tap …` still works ad hoc. Cask/brew declarations stay declarative via
  `homebrew.casks` / `homebrew.brews`.

## General rules for Nix-installed tools
- **Never** rely on a tool's self-updater — the store is read-only. Update with
  `nix flake update` + rebuild.
- GUI apps: prefer a `programs.*` module where one exists (declarative). Otherwise use Homebrew
  casks for best `/Applications` integration — nixpkgs doesn't fully replace Homebrew for GUI apps.

### Touch ID for sudo
Enabled via `security.pam.services.sudo_local.touchIdAuth = true` — writes `/etc/pam.d/sudo_local`,
which survives macOS updates. Touch ID does **not** work inside tmux without the `pam_reattach`
module; add it there if/when tmux is in use.
