{
  description = "darwin system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nixpkgs-unstable, home-manager }:
  let
    username = "adnathanail";        # run `whoami` to confirm
    hostname = "Alexs-MacBook-Pro";

    # Pull claude-code (and ONLY claude-code) from unstable.
    unstableOverlay = final: prev: {
      claude-code = (import nixpkgs-unstable {
        inherit (prev) system;
        config.allowUnfree = true;   # claude-code is proprietary -> unfree
      }).claude-code;
    };
  in {
    darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
      modules = [

        # ── system ──────────────────────────────────────────────
        ({ pkgs, ... }: {
          nixpkgs.hostPlatform = "aarch64-darwin"; # "x86_64-darwin" on Intel
          nixpkgs.overlays = [ unstableOverlay ];
          nixpkgs.config.allowUnfree = true;

          system.stateVersion = 6;
          system.primaryUser = username;

          # Lix installer owns Nix + /etc/nix/nix.conf.
          nix.enable = false;

          users.users.${username}.home = "/Users/${username}";

          environment.systemPackages = [ pkgs.htop ];
        })

        # ── Home Manager + Claude Code ──────────────────────────
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;     # use the overlaid pkgs above
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";

          home-manager.users.${username} = import ./home.nix;
        }
      ];
    };
  };
}
