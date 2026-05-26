# ALix

## Rebuilding

Rebuild `nix-darwin` config
```bash
nix-switch
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
    - Plugins:
        - Nix IDE
        - Dev Containers
        - Claude Code
- 1Password
- PyCharm
    - *First use*:
        - Disable in-app updater
        - Set keymap to `ALix keymap`
- Orbstack
- Ghostty
- Outlook
- Todoist
- Slack
- Fantastical

### Configuration/Tools

- Touch ID for sudo
- Window tiling (Rectangle)
- Raycast
- Top left hot corner: Show desktop

### CLIs

- git
- prek
- python
- gh
