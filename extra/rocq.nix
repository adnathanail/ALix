{ pkgs, ... }: {
  # Coq + std++ + the coq-lsp language server. Installed from the same
  # coqPackages set so they share a Coq version; std++'s user-contrib
  # path is picked up from the Nix user environment. coq-lsp is the
  # server binary the VS Code extension (below) spawns over stdio.
  home.packages = [
    pkgs.coqPackages.coq
    pkgs.coqPackages.stdpp
    pkgs.coqPackages.coq-lsp
  ];

  # VS Code extensions for Coq. None are in the prebuilt nixpkgs set, so
  # they come from the marketplace. Bump version + hash together.
  # - wasm-wasi-core is a runtime dependency declared by coq-lsp; without
  #   it the extension refuses to activate.
  # - vizx is a ZX-calculus visualiser that hooks into coq-lsp.
  programs.vscode.profiles.default.extensions = [
    (pkgs.vscode-utils.extensionFromVscodeMarketplace {
      publisher = "ms-vscode";
      name = "wasm-wasi-core";
      version = "1.0.2";
      sha256 = "sha256-hrzPNPaG8LPNMJq/0uyOS8jfER1Q0CyFlwR42KmTz8g=";
    })
    (pkgs.vscode-utils.extensionFromVscodeMarketplace {
      publisher = "ejgallego";
      name = "coq-lsp";
      version = "0.2.4";
      sha256 = "sha256-s2f2i3sNZ3EdCHDgkYPPiXDp25cViAZy+DpnDxfWaSo=";
    })
    (pkgs.vscode-utils.extensionFromVscodeMarketplace {
      publisher = "inqwire";
      name = "vizx";
      version = "0.2.1";
      sha256 = "sha256-9iqUE/7X9X31j9QqyeKRBi7nuDxkwMAqrdzN440hrag=";
    })
  ];
}
