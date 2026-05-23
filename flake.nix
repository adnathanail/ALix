{
  description = "darwin system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nixpkgs-unstable, home-manager, nix-homebrew }:
  let
    username = "adnathanail";        # `whoami`
    hostname = "Alexs-MacBook-Pro";  # `scutil --get LocalHostName`

    # Pull specific packages from unstable while keeping everything else on stable.
    unstableOverlay = final: prev:
      let
        unstable = import nixpkgs-unstable {
          system = prev.stdenv.hostPlatform.system;
          config.allowUnfree = true;   # claude-code, pycharm are unfree
        };
      in {
        claude-code = unstable.claude-code;
        prek = unstable.prek;
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

          # Hide "Recent applications" section in the Dock.
          system.defaults.dock.show-recents = false;

          # Dock contents: Finder is always pinned leftmost by macOS, so
          # persistent-apps only covers what comes after it.
          system.defaults.dock.persistent-apps = [
            { app = "/Applications/Ghostty.app"; }
            { spacer = { small = true; }; }
            # /Applications/Safari.app is a symlink into the Cryptex sealed
            # system volume, which makes the Dock draw an alias-arrow badge on
            # the icon. Point at the real path to avoid that.
            { app = "/System/Cryptexes/App/System/Applications/Safari.app"; }
            { spacer = { small = false; }; }
          ];

          # Menu-bar clock: 24h time with seconds, no date.
          system.defaults.menuExtraClock = {
            Show24Hour = true;
            ShowSeconds = true;
            ShowDate = 2;            # 0 = when space allows, 1 = always, 2 = never
            ShowDayOfWeek = false;
            ShowDayOfMonth = false;
          };

          # Control Center / menu-bar items.
          system.defaults.controlcenter = {
            BatteryShowPercentage = true;
            Bluetooth = true;
          };

          # Clear the ⌘⇧A hotkey on the "Search man Page Index in Terminal"
          # service — it otherwise hijacks ⌘⇧A system-wide and breaks PyCharm's
          # Find Action. The service itself stays available in the Services menu.
          system.defaults.CustomUserPreferences."pbs" = {
            NSServicesStatus = {
              "com.apple.Terminal - Search man Page Index in Terminal - searchManPages" = {
                key_equivalent = "";
              };
            };
          };

          # Lix installer owns Nix + /etc/nix/nix.conf.
          nix.enable = false;

          users.users.${username}.home = "/Users/${username}";

          # Enable Touch ID for sudo
          security.pam.services.sudo_local.touchIdAuth = true;

          environment.systemPackages = [ ];

          # Homebrew — used only for GUI casks that don't tolerate the
          # Nix store layout (e.g. 1Password's anti-tamper check refuses
          # to run anywhere except /Applications/<app>.app). nix-homebrew
          # installs Homebrew itself; the `homebrew.*` options below
          # declare what gets installed via it.
          homebrew = {
            enable = true;
            onActivation = {
              autoUpdate = false;
              upgrade = true;
              # `cleanup = "zap"` would uninstall anything not declared
              # here. Leave at "none" until everything previously
              # installed by hand is captured in this list.
              cleanup = "none";
            };
            casks = [ "1password" "1password-cli" "orbstack" "raycast" "bartender" "ghostty" ];
          };
        })

        # ── Homebrew (nix-homebrew) ─────────────────────────────
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            user = username;
            # Apple Silicon installs to /opt/homebrew. Set
            # `enableRosetta = true` only if an x86_64-only cask
            # needs to be installed alongside the aarch64 brew.
            enableRosetta = false;
          };
        }

        # ── Home Manager ──────────────────────────
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
