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

### Selective unstable overlay for Claude Code
Claude Code ships releases very frequently and the stable channel lags badly. An overlay
(`unstableOverlay`) pulls **only** `claude-code` from `nixpkgs-unstable`, leaving everything else on
stable 25.11. Reuse this same pattern for any other single package that needs to be fresher than the
stable pin.

### `allowUnfree`
`nixpkgs.config.allowUnfree = true` is required for proprietary packages (`claude-code`, `vscode`).
Narrow it to an `allowUnfreePredicate` if stricter control is ever wanted.

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

### VS Code
- Managed by `programs.vscode` (declarative) under `profiles.default`.
- `settings.json` is now **Nix-owned** — editing it in-app won't persist. Change `userSettings` in
  `home.nix` instead.
- Extensions are declared in `profiles.default.extensions` from `pkgs.vscode-extensions`.
- The app installs to `~/Applications/Home Manager Apps/` (not `/Applications`); Spotlight and
  `open -a "Visual Studio Code"` still find it there.
- First eval after adding it is slow/heavy because the Marketplace overlay set is enormous;
  subsequent rebuilds are fine.
- Updates via Nix, not VS Code's own updater.

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

### git
- `programs.git` manages identity and `~/.gitconfig` declaratively. Installing git via Nix avoids
  Apple's Command Line Tools prompt. (CLT is still needed only for build systems that hardcode
  `/usr/bin/git` or require Apple SDK headers.)

## General rules for Nix-installed tools
- **Never** rely on a tool's self-updater — the store is read-only. Update with
  `nix flake update` + rebuild.
- GUI apps: prefer a `programs.*` module where one exists (declarative). Otherwise use Homebrew
  casks for best `/Applications` integration — nixpkgs doesn't fully replace Homebrew for GUI apps.

### Touch ID for sudo
Enabled via `security.pam.services.sudo_local.touchIdAuth = true` — writes `/etc/pam.d/sudo_local`,
which survives macOS updates. Touch ID does **not** work inside tmux without the `pam_reattach`
module; add it there if/when tmux is in use.

## TODO / not yet done
- **Homebrew:** wire up `nix-homebrew` (installs and pins Homebrew itself — no manual curl needed)
  plus the `homebrew.casks` / `homebrew.brews` / `homebrew.masApps` options for GUI apps. Note
  `onActivation.cleanup = "zap"` uninstalls anything not declared, so enable it only once lists are
  complete.