{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkDefault
    mkForce
    mkIf
    mkOption
    optional
    types
    ;

  cfg = config.staticNetworkFromFacts;

  requireFactsFile =
    if cfg.factsFile == null then
      throw ''
        staticNetworkFromFacts.enable is set, but staticNetworkFromFacts.factsFile is null.

        Generate network facts before evaluating this system, for example:
          nix run .#generate-network-facts -- root@YOUR_SERVER_IP ./contabo-network.json
      ''
    else
      cfg.factsFile;

  facts =
    if builtins.pathExists requireFactsFile then
      builtins.fromJSON (builtins.readFile requireFactsFile)
    else
      throw ''
        Missing static network facts file: ${toString requireFactsFile}

        Generate it from the target before running nixos-anywhere, for example:
          nix run .#generate-network-facts -- root@YOUR_SERVER_IP ${toString requireFactsFile}
      '';

  interface = facts.interface or (throw "network facts are missing .interface");
  interfaceName = interface.name or (throw "network facts are missing .interface.name");
  macAddress = interface.macAddress or null;
  hostName = facts.hostName or null;

  ipv4 = facts.ipv4 or null;
  ipv6 = facts.ipv6 or null;

  dns =
    if (facts.dns or [ ]) != [ ] then
      facts.dns
    else
      cfg.defaultDns;

  mkAddress = family: "${family.address}/${toString family.prefixLength}";

  addresses =
    optional (ipv4 != null) (mkAddress ipv4)
    ++ optional (ipv6 != null) (mkAddress ipv6);

  mkGatewayRoute = family: {
    Gateway = family.gateway;
    GatewayOnLink = family.gatewayOnLink or cfg.gatewayOnLink;
  };

  routes =
    optional (ipv4 != null && (ipv4.gateway or null) != null) (mkGatewayRoute ipv4)
    ++ optional (ipv6 != null && (ipv6.gateway or null) != null) (mkGatewayRoute ipv6);

  matchConfig =
    if cfg.matchByMac && macAddress != null then
      { MACAddress = macAddress; }
    else
      { Name = interfaceName; };
in
{
  options.staticNetworkFromFacts = {
    enable = mkEnableOption "static networking from generated network facts";

    factsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = ./network-facts.json;
      description = ''
        JSON file generated from the target's currently-working network state.
        This is intentionally similar to hardware-configuration.nix/facter.json:
        discovery happens before installation, then NixOS consumes the generated facts.
      '';
    };

    networkName = mkOption {
      type = types.str;
      default = "10-static-public";
      description = "Name of the generated systemd-networkd network.";
    };

    defaultDns = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "DNS servers to use when the facts file does not contain DNS.";
    };

    matchByMac = mkOption {
      type = types.bool;
      default = true;
      description = "Match the interface by MAC address when available, otherwise by interface name.";
    };

    setHostName = mkOption {
      type = types.bool;
      default = true;
      description = "Set networking.hostName from the facts file when present.";
    };

    disableDHCP = mkOption {
      type = types.bool;
      default = true;
      description = "Disable NixOS DHCP because the facts provide static addresses.";
    };

    useNetworkd = mkOption {
      type = types.bool;
      default = true;
      description = "Use systemd-networkd for the generated static network.";
    };

    enableResolved = mkOption {
      type = types.bool;
      default = true;
      description = "Enable systemd-resolved.";
    };

    ipv6AcceptRA = mkOption {
      type = types.bool;
      default = false;
      description = "Value for IPv6AcceptRA in the generated network.";
    };

    gatewayOnLink = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Default GatewayOnLink value for generated routes. VPS providers often
        require this, and it is harmless when the gateway is already on-link.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = ipv4 != null || ipv6 != null;
        message = "network facts must contain at least one of .ipv4 or .ipv6";
      }
      {
        assertion = addresses != [ ];
        message = "network facts did not produce any static addresses";
      }
    ];

    networking = {
      hostName = mkIf (cfg.setHostName && hostName != null) (mkDefault hostName);
      useDHCP = mkIf cfg.disableDHCP (mkForce false);
      useNetworkd = mkIf cfg.useNetworkd true;
      nameservers = dns;
    };

    services.resolved.enable = mkIf cfg.enableResolved true;

    systemd.network = {
      enable = cfg.useNetworkd;
      networks.${cfg.networkName} = {
        inherit matchConfig;

        address = addresses;
        inherit dns routes;

        networkConfig = {
          IPv6AcceptRA = cfg.ipv6AcceptRA;
        };
      };
    };
  };
}
