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
  ];

  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
      ];
      userSettings = {
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
        "git.enableSmartCommit" = true;
      };
    };
  };
}
