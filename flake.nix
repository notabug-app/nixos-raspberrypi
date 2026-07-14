{
  description = "Wrapper over nvmd/nixos-raspberrypi with 7.x kernels";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://notabug.cachix.org"
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "notabug.cachix.org-1:iLePK0RgxY/axZfhjJQJw9VXLg2myZODqkSUUi4jEEE="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-raspberrypi,
    }@inputs:
    let
      lib = nixpkgs.lib;
      systems = [ "aarch64-linux" ];
      forAllSystems = lib.genAttrs systems;
    in
    {
      overlays.default =
        final: prev:
        let
          stripLocalVersion =
            k:
            k.overrideAttrs (old: {
              postConfigure = (old.postConfigure or "") + ''
                sed -i $buildRoot/.config -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=""/'
                sed -i $buildRoot/include/config/auto.conf -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=""/'
              '';
            });
          rpiLinux7_2_rc = stripLocalVersion (
            prev.buildLinux {
              src = prev.fetchFromGitHub {
                owner = "raspberrypi";
                repo = "linux";
                rev = "refs/heads/rpi-7.2.y";
                hash = "sha256-yz5bIjb/yT3TR6lycmfFbRkcz9aJopOhFP3WOduY3BM=";
              };
              version = "7.2.0-rc3";
              modDirVersion = "7.2.0-rc3";
              defconfig = "bcm2712_defconfig";
              autoModules = false;
              ignoreConfigErrors = true;
              features = {
                efiBootStub = false;
              };
            }
          );
          rpiLinux7_1 = stripLocalVersion (
            prev.buildLinux {
              src = prev.fetchFromGitHub {
                owner = "raspberrypi";
                repo = "linux";
                rev = "refs/heads/rpi-7.1.y";
                hash = "sha256-Np+7ujObA3rOBWbKztUCDmKoTbUbDaijDo0ljArXt20=";
              };
              version = "7.1.3";
              modDirVersion = "7.1.3";
              defconfig = "bcm2712_defconfig";
              autoModules = false;
              ignoreConfigErrors = true;
              features = {
                efiBootStub = false;
              };
            }
          );
        in
        {
          linuxPackages_rpi5_7_2_rc = prev.linuxPackagesFor rpiLinux7_2_rc;
          linuxPackages_rpi4_7_2_rc = prev.linuxPackagesFor (
            rpiLinux7_2_rc.override {
              defconfig = "bcm2711_defconfig";
            }
          );
          linuxPackages_rpi5 = prev.linuxPackagesFor rpiLinux7_1;
          linuxPackages_rpi4 = prev.linuxPackagesFor (
            rpiLinux7_1.override {
              defconfig = "bcm2711_defconfig";
            }
          );
        };

      nixosModules.default = { ... }: {
        imports = [ nixos-raspberrypi.nixosModules.default ];
        nixpkgs.overlays = [ self.overlays.default ];
        boot.zfs.forceImportRoot = false;
      };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              self.overlays.default
            ];
          };
        in
        nixos-raspberrypi.packages.${system}
        // {
          # linux_rpi5 = pkgs.linuxPackages_rpi5.kernel;
          linux_rpi4 = pkgs.linuxPackages_rpi4.kernel;
          # linux_rpi5_7_2_rc = pkgs.linuxPackages_rpi5_7_2_rc.kernel;
          linux_rpi4_7_2_rc = pkgs.linuxPackages_rpi4_7_2_rc.kernel;
        }
      );

      nixosConfigurations = builtins.mapAttrs (
        name: config:
        config.extendModules {
          modules = [ { boot.zfs.forceImportRoot = lib.mkForce false; } ];
        }
      ) (nixos-raspberrypi.nixosConfigurations or { });
    }
    // removeAttrs nixos-raspberrypi [
      "packages"
      "overlays"
      "nixosModules"
      "nixosConfigurations"
      "installerImages"
      "outPath"
      "outputs"
      "inputs"
      "rev"
      "sourceInfo"
      "narHash"
      "lastModified"
      "lastModifiedDate"
      "_type"
      "shortRev"
    ];
}
