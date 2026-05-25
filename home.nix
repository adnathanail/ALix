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

  home.packages = [
    pkgs.rectangle
    pkgs.jetbrains.pycharm
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
        "git.autofetch" = true;
        "git.confirmSync" = false;
      };
    };
  };
}
