# ALix

[Install Lix](https://lix.systems/install/#on-any-other-linuxmacos-system)
```bash
curl -sSf -L https://install.lix.systems/lix | sh -s -- install
```

Install XCode dev tools
```bash
xcode-select --install
```

Setup the `nix-darwin` config
```bash
sudo darwin-rebuild switch --flake ~/.config/nix-darwin
```

## Features

### Software

- Claude Code
- VS Code
- 1Password
- PyCharm
    - Disable in-app updater on first launch

### Configuration/Tools

- git
- Touch ID for sudo
- Window tiling (Rectangle)