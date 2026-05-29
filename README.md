# ALix

## Rebuilding

Rebuild `nix-darwin` config
```bash
ns  # alias for nix-switch
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
- VS Code (w/ plugins)
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
- Spotify
- WhatsApp
- Google Drive
- Steam

### Configuration/Tools

- Touch ID for sudo
- Window tiling (Rectangle)
- Raycast
- Top left hot corner: Show desktop
- Bottom left hot corner: Apps (Launchpad)

### CLIs

- git
- prek
- python
- node
- gh (GitHub)
- op (1Password)
- Rocq (with std++ library)