{ pkgs, ... }: {
  home.stateVersion = "25.11";

  programs.claude-code = {
    enable = true;
    # The module's default package is pkgs.claude-code, which the
    # overlay has swapped for the unstable build. Manage config here:
    # settings = { theme = "dark"; };
  };

  # Stop Claude Code self-updating into the read-only store;
  # you update it via Nix instead.
  home.sessionVariables.DISABLE_AUTOUPDATER = "1";

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Alex Nathanail";
        email = "7809723+adnathanail@users.noreply.github.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  # Rectangle — Magnet-style window snapping. Configure keybindings/snap
  # areas in Rectangle's own preferences UI; it persists them to
  # ~/Library/Preferences/com.knollsoft.Rectangle.plist (not Nix-managed).

  home.packages = let
    # JetBrains plugins are wrapped into the IDE bundle via
    # jetbrains.plugins.addPlugins, which takes a derivation (not a string ID
    # — that API was removed). fetchzip the marketplace .zip directly; bump
    # `url` + `hash` to update. Compatibility starts at build 242.0, so any
    # 2024.2+ IDE works. Find new updates via
    # https://plugins.jetbrains.com/api/plugins/27310/updates
    claude-code-jb = pkgs.fetchzip {
      url = "https://plugins.jetbrains.com/files/27310/907737/claude-code-jetbrains-plugin-0.1.14-beta.zip";
      hash = "sha256-q86soDjURsZ2sNKVUWLiuLA6B2p/HdWVA+J55lV7vrg=";
    };
    pycharmWithPlugins = pkgs.jetbrains.plugins.addPlugins pkgs.jetbrains.pycharm [
      claude-code-jb
    ];
  in [
    pkgs.rectangle
    pycharmWithPlugins
    pkgs.prek
    pkgs.python3
    pkgs.gh
    (pkgs.writeShellScriptBin "nix-switch" ''
      exec sudo darwin-rebuild switch --flake ~/.config/nix-darwin "$@"
    '')
  ];

  # PyCharm keymap. Symlinked into the versioned config dir; bump the path
  # below after a JetBrains minor-version upgrade. Select it in
  # Settings → Keymap on first use; it appears as "Default for macOS copy".
  home.file."Library/Application Support/JetBrains/PyCharm2026.1/keymaps/custom-keymap.xml".source =
    ./pycharm/custom-keymap.xml;

  # Ghostty config. The app itself comes from Homebrew (see flake.nix), but
  # the config file is Nix-owned so the first-launch auto-update prompt is
  # suppressed declaratively. Edits made in the app won't persist — change
  # this block and rebuild.
  xdg.configFile."ghostty/config".text = ''
    auto-update = off
  '';

  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
        ms-vscode-remote.remote-containers
        anthropic.claude-code
      ];
      userSettings = {
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
        "git.enableSmartCommit" = true;
      };
    };
  };
}
