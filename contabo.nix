{ ... }:
{
  imports = [
    ./modules/static-network-from-facts.nix
  ];

  staticNetworkFromFacts = {
    enable = true;
    factsFile = ./contabo-network.json;
    networkName = "10-contabo-public";

    # Fallback only; normally generated facts include DNS from the target.
    defaultDns = [
      "192.0.2.53"
      "192.0.2.54"
      "2001:db8::53"
    ];
  };
}
