#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ $# -eq 1 ]]; then
  exec "$script_dir/generate-network-facts.sh" "$1" contabo-network.json
fi

exec "$script_dir/generate-network-facts.sh" "$@"
