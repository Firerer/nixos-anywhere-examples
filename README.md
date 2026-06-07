# nixos-anywhere-examples

Checkout the [flake.nix](flake.nix) for examples tested on different hosters.

## Contabo VPS

Final thought: NixOS is too complex to maintain and
not widely supported, just use `nix` as a package manager.

See [docs/contabo-static-networking.md](docs/contabo-static-networking.md) for
why Contabo static networking needs extra handling, how to confirm it, and why
`nixos-generate-config`/`nixos-facter` do not preserve the required IP/gateway
state.

Generate `contabo-network.json` from the target while its provider OS/rescue
system still has working networking:

```sh
nix run .#generate-network-facts -- root@YOUR_SERVER_IP ./contabo-network.json
```

Then install:

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake .#contabo \
  --generate-hardware-config nixos-generate-config ./hardware-configuration.nix \
  root@YOUR_SERVER_IP
```

Or use the wrapper:

```sh
./scripts/install-contabo.sh root@YOUR_SERVER_IP
```

The generated JSON is imported by `contabo.nix`, so the server IP/login only
appear in the command line and not in `flake.nix`.
