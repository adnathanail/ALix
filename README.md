# ALix

## Rebuilding

Rebuild `nix-darwin` config
```bash
sudo darwin-rebuild switch --flake ~/.config/nix-darwin
```

## First use

[Install Lix](https://lix.systems/install/#on-any-other-linuxmacos-system)
```bash
curl -sSf -L https://install.lix.systems/lix | sh -s -- install
```

Install XCode dev tools
```bash
xcode-select --install
```

Bootstrap `nix-darwin`
```bash
nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/.config/nix-darwin
```

## Features

### Software

- Claude Code
- VS Code
- 1Password
- PyCharm
    - Disable in-app updater on first launch
    - Set keymap to `ALix keymap`
- Orbstack
- Ghostty

### Configuration/Tools

- git
- Touch ID for sudo
- Window tiling (Rectangle)
- Raycast