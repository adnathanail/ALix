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
    username = "adnathanail";        # `whoami`
    hostname = "Alexs-MacBook-Pro";  # `scutil --get LocalHostName`

    # Pull specific packages from unstable while keeping everything else on stable.
    unstableOverlay = final: prev:
      let
        unstable = import nixpkgs-unstable {
        inherit (prev) system;
          config.allowUnfree = true;   # claude-code, pycharm are unfree
        };
      in {
        claude-code = unstable.claude-code;
        # Merge so other jetbrains.* attrs keep coming from stable.
        jetbrains = prev.jetbrains // {
          pycharm = unstable.jetbrains.pycharm;
        };
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

          # Enable Touch ID for sudo
          security.pam.services.sudo_local.touchIdAuth = true;

          environment.systemPackages = [ ];
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
