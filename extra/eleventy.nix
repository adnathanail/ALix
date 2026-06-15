{ pkgs, ... }: {
  # Nunjucks template language support for Eleventy. Not in the prebuilt
  # nixpkgs extension set, so pulled from the marketplace — bump version +
  # hash together.
  programs.vscode.profiles.default.extensions = [
    (pkgs.vscode-utils.extensionFromVscodeMarketplace {
      publisher = "ronnidc";
      name = "nunjucks";
      version = "0.3.1";
      sha256 = "sha256-7YfmRMhC+HFmYgYtyHWrzSi7PZS3tdDHly9S1kDMmjY=";
    })
  ];
}
